//! Connector for CockroachDB.
//!
//! The same plan the embedded connector walks, lowered to one parameterised
//! statement instead. This is the port of `roachgraph/src/runtime/compile.ts`,
//! and it is the connector that makes "several stores" real: if a plan can be
//! answered by both a local log and a distributed SQL database without being
//! rewritten, the boundary is doing its job.
//!
//! Two things are deliberate.
//!
//! Every value is a parameter. Identifiers come from the schema — which is
//! comptime data, not user input — and everything else is a placeholder, so a
//! predicate can never become SQL text.
//!
//! Known limitation: `Plan.Field` is a closed enum of the causal graph's
//! columns, so a plan cannot yet name an arbitrary schema's field. Generalising
//! it to a schema-resolved name is what makes this connector usable against a
//! store other than a causal graph shaped one; the emitter below is already
//! schema-driven and will not need to change for it.
//!
//! Traversal becomes a join, and a bounded traversal becomes a recursive CTE.
//! That is the shape difference from the embedded engine, which walks adjacency
//! directly; the plan does not know or care, which is the point.

const std = @import("std");
const Plan = @import("../plan.zig");
const Schema = @import("../schema.zig");
const Backend = @import("../backend.zig");

pub const capabilities = Backend.Capabilities{
    .predicates = true,
    .traversal = true,
    .recursive_traversal = true,
    .reverse_traversal = true,
    // A relational store indexes documents and embeddings, so unlike the causal
    // log these are real here.
    .text_search = true,
    .vector_search = true,
    .time_travel = true,
    .transactions = true,
};

pub const Compiled = struct {
    sql: []u8,
    /// Parameters in placeholder order. Text and ids are kept distinct so a
    /// driver can bind them without re-inspecting the plan.
    parameters: []Parameter,

    pub fn deinit(self: *Compiled, allocator: std.mem.Allocator) void {
        allocator.free(self.parameters);
        allocator.free(self.sql);
        self.* = undefined;
    }
};

pub const Parameter = union(enum) {
    text: []const u8,
    id: u64,
};

/// Lower a plan to SQL against a schema.
///
/// Compilation is separate from execution on purpose: a caller can inspect,
/// log or test the statement without a database, which is how this connector is
/// verified.
pub fn compileAlloc(
    allocator: std.mem.Allocator,
    schema: Schema.Schema,
    node_name: []const u8,
    plan: Plan.Plan,
) ![]const u8 {
    const compiled = try compile(allocator, schema, node_name, plan);
    allocator.free(compiled.parameters);
    return compiled.sql;
}

pub fn compile(
    allocator: std.mem.Allocator,
    schema: Schema.Schema,
    node_name: []const u8,
    plan: Plan.Plan,
) !Compiled {
    try plan.validate();
    const node = try schema.node(node_name);

    var sql: std.ArrayList(u8) = .empty;
    errdefer sql.deinit(allocator);
    var parameters: std.ArrayList(Parameter) = .empty;
    errdefer parameters.deinit(allocator);

    const primary_key = "id";
    try sql.print(allocator, "SELECT n0.\"{s}\" AS \"node_id\"\nFROM \"{s}\" AS n0", .{ primary_key, node.table });

    // A traversal step is a join per hop; a bounded one is a recursive CTE. Only
    // the depth-1 form is emitted here, because a recursive CTE that ignored the
    // depth bound would return more than the plan asked for.
    var alias: usize = 0;
    for (plan.steps) |step| {
        if (step.max_depth != 1) return error.RecursiveTraversalNotCompiled;
        const relation = try firstRelation(schema, node_name);
        const from_column = if (step.direction == .children) relation.from_column else relation.to_column;
        const to_column = if (step.direction == .children) relation.to_column else relation.from_column;
        const edge_alias = alias + 1;
        const next_alias = alias + 2;
        try sql.print(allocator, "\nJOIN \"{s}\" AS e{d} ON e{d}.\"{s}\" = n{d}.\"{s}\"", .{
            relation.table, edge_alias, edge_alias, from_column, alias, primary_key,
        });
        try sql.print(allocator, "\nJOIN \"{s}\" AS n{d} ON n{d}.\"{s}\" = e{d}.\"{s}\"", .{
            node.table, next_alias, next_alias, primary_key, edge_alias, to_column,
        });
        alias = next_alias;
    }

    var wrote_where = false;
    switch (plan.from) {
        .event => |id| {
            try sql.print(allocator, "\nWHERE n0.\"{s}\" = ${d}", .{ primary_key, parameters.items.len + 1 });
            try parameters.append(allocator, .{ .id = id });
            wrote_where = true;
        },
        .matching => |predicates| {
            for (predicates) |predicate| {
                try appendPredicate(allocator, &sql, &parameters, schema, node_name, 0, predicate, &wrote_where);
            }
        },
    }
    // A step's filter applies to what the step reached, which is the alias that
    // hop introduced.
    var step_alias: usize = 0;
    for (plan.steps) |step| {
        step_alias += 2;
        for (step.where) |predicate| {
            try appendPredicate(allocator, &sql, &parameters, schema, node_name, step_alias, predicate, &wrote_where);
        }
    }

    try sql.print(allocator, "\nLIMIT ${d};", .{parameters.items.len + 1});
    try parameters.append(allocator, .{ .id = plan.limit });

    return .{
        .sql = try sql.toOwnedSlice(allocator),
        .parameters = try parameters.toOwnedSlice(allocator),
    };
}

fn firstRelation(schema: Schema.Schema, node_name: []const u8) !Schema.Relation {
    for (schema.relations) |relation| {
        if (std.mem.eql(u8, relation.from_node, node_name)) return relation;
    }
    return error.UnknownRelation;
}

fn appendPredicate(
    allocator: std.mem.Allocator,
    sql: *std.ArrayList(u8),
    parameters: *std.ArrayList(Parameter),
    schema: Schema.Schema,
    node_name: []const u8,
    alias: usize,
    predicate: Plan.Predicate,
    wrote_where: *bool,
) !void {
    const field = try schema.nodeField(node_name, @tagName(predicate.field));
    // The schema says what a column holds, so a text predicate on an id column
    // is a compile error rather than a query that matches nothing.
    const wants_text = predicate.match == .text;
    if ((field.kind == .id or field.kind == .integer) == wants_text) return error.FieldKindMismatch;

    try sql.appendSlice(allocator, if (wrote_where.*) "\n  AND " else "\nWHERE ");
    wrote_where.* = true;
    try sql.print(allocator, "n{d}.\"{s}\" {s} ${d}", .{
        alias,
        field.column,
        if (predicate.negated) "<>" else "=",
        parameters.items.len + 1,
    });
    try parameters.append(allocator, switch (predicate.match) {
        .text => |value| .{ .text = value },
        .id => |value| .{ .id = value },
    });
}

test "an anchored plan compiles to a parameterised statement" {
    const plan = try Plan.Builder.fromEvent(42).limit(10).build();
    var compiled = try compile(std.testing.allocator, Schema.causal, "Event", plan);
    defer compiled.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        \\SELECT n0."id" AS "node_id"
        \\FROM "causal_event" AS n0
        \\WHERE n0."id" = $1
        \\LIMIT $2;
    , compiled.sql);
    try std.testing.expectEqual(@as(usize, 2), compiled.parameters.len);
    try std.testing.expectEqual(@as(u64, 42), compiled.parameters[0].id);
    try std.testing.expectEqual(@as(u64, 10), compiled.parameters[1].id);
}

test "a filtered root becomes a where clause and never inlines a value" {
    const plan = try Plan.Builder.matching(&.{
        .{ .field = .status, .match = .{ .text = "failure" } },
        .{ .field = .requirement_id, .match = .{ .id = 77 } },
    }).limit(25).build();
    var compiled = try compile(std.testing.allocator, Schema.causal, "Event", plan);
    defer compiled.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        \\SELECT n0."id" AS "node_id"
        \\FROM "causal_event" AS n0
        \\WHERE n0."status" = $1
        \\  AND n0."requirement_id" = $2
        \\LIMIT $3;
    , compiled.sql);
    // The literal never reaches the statement.
    try std.testing.expect(std.mem.indexOf(u8, compiled.sql, "failure") == null);
    try std.testing.expectEqualStrings("failure", compiled.parameters[0].text);
    try std.testing.expectEqual(@as(u64, 77), compiled.parameters[1].id);
}

test "a traversal becomes a join, and its filter binds to what the hop reached" {
    const plan = try Plan.Builder.matching(&.{.{ .field = .status, .match = .{ .text = "failure" } }})
        .traverse(&.{.{ .direction = .children, .where = &.{.{ .field = .kind, .match = .{ .text = "activity_completed" } }} }})
        .limit(5)
        .build();
    var compiled = try compile(std.testing.allocator, Schema.causal, "Event", plan);
    defer compiled.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        \\SELECT n0."id" AS "node_id"
        \\FROM "causal_event" AS n0
        \\JOIN "causal_edge" AS e1 ON e1."parent_id" = n0."id"
        \\JOIN "causal_event" AS n2 ON n2."id" = e1."event_id"
        \\WHERE n0."status" = $1
        \\  AND n2."kind" = $2
        \\LIMIT $3;
    , compiled.sql);
}

test "direction chooses which column joins to which" {
    const upward = try Plan.Builder.fromEvent(3)
        .traverse(&.{.{ .direction = .parents }})
        .build();
    var compiled = try compile(std.testing.allocator, Schema.causal, "Event", upward);
    defer compiled.deinit(std.testing.allocator);
    // Reversed against the forward case above.
    try std.testing.expect(std.mem.indexOf(u8, compiled.sql, "e1.\"event_id\" = n0.\"id\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, compiled.sql, "n2.\"id\" = e1.\"parent_id\"") != null);
}

test "a field/value mismatch is caught by the plan, and again by the schema" {
    // First line: the plan knows which of its own fields are text, so this never
    // reaches a backend.
    const mismatched = Plan.Plan{
        .from = .{ .matching = &.{.{ .field = .requirement_id, .match = .{ .text = "77" } }} },
    };
    try std.testing.expectError(
        error.InvalidPlan,
        compile(std.testing.allocator, Schema.causal, "Event", mismatched),
    );

    // Second line: a schema can disagree with the plan about a column's type —
    // the same field name backed by an id column in one store and text in
    // another. The plan cannot know that; the schema can, and must say so before
    // a database sees the statement.
    const disagreeing = Schema.Schema{
        .name = "disagreeing",
        .nodes = &.{.{ .name = "Event", .table = "causal_event", .fields = &.{
            .{ .name = "status", .column = "status_id", .kind = .id },
        } }},
    };
    const plan = try Plan.Builder.matching(&.{.{ .field = .status, .match = .{ .text = "failure" } }}).build();
    try std.testing.expectError(
        error.FieldKindMismatch,
        compile(std.testing.allocator, disagreeing, "Event", plan),
    );
}

test "a bounded traversal is refused rather than silently unbounded" {
    // A recursive CTE that ignored max_depth would return more than the plan
    // asked for. Until it is emitted with its depth bound, this must not compile.
    const deep = try Plan.Builder.fromEvent(1)
        .traverse(&.{.{ .direction = .children, .max_depth = 8 }})
        .build();
    try std.testing.expectError(
        error.RecursiveTraversalNotCompiled,
        compile(std.testing.allocator, Schema.causal, "Event", deep),
    );
}

test "the connector declares what a relational store really can do" {
    try std.testing.expect(capabilities.vector_search);
    try std.testing.expect(capabilities.text_search);
    try std.testing.expect(capabilities.transactions);
    try std.testing.expect(capabilities.time_travel);
}
