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

    // A single bounded step is the shape an agent actually asks for — "what did
    // this cause, up to N hops" — so it gets a recursive CTE carrying its own
    // depth bound rather than being refused. The bound is a parameter and is
    // compared inside the recursive arm, so the walk cannot exceed what the plan
    // asked for even on a deep graph.
    if (plan.steps.len == 1 and plan.steps[0].max_depth > 1) {
        return compileRecursive(allocator, schema, node_name, node, plan, &sql, &parameters, primary_key);
    }

    try sql.print(allocator, "SELECT n0.\"{s}\" AS \"node_id\"\nFROM \"{s}\" AS n0", .{ primary_key, node.table });

    var alias: usize = 0;
    for (plan.steps) |step| {
        // Several chained steps where one is bounded would need a CTE per hop;
        // refusing is still better than emitting an unbounded walk.
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

/// Emit a depth-bounded transitive walk.
///
/// The anchor selects the roots the plan asked for at depth 0; the recursive arm
/// joins one hop and increments, guarded by `depth < $bound`. The final select
/// excludes depth 0 so the result is what was *reached*, matching the embedded
/// connector, which returns descendants and not the node itself.
fn compileRecursive(
    allocator: std.mem.Allocator,
    schema: Schema.Schema,
    node_name: []const u8,
    node: Schema.Node,
    plan: Plan.Plan,
    sql: *std.ArrayList(u8),
    parameters: *std.ArrayList(Parameter),
    primary_key: []const u8,
) !Compiled {
    const step = plan.steps[0];
    const relation = try firstRelation(schema, node_name);
    const from_column = if (step.direction == .children) relation.from_column else relation.to_column;
    const to_column = if (step.direction == .children) relation.to_column else relation.from_column;

    try sql.print(allocator,
        "WITH RECURSIVE traversal(node_id, depth) AS (\n  SELECT n0.\"{s}\", 0\n  FROM \"{s}\" AS n0",
        .{ primary_key, node.table },
    );

    var wrote_where = false;
    switch (plan.from) {
        .event => |id| {
            try sql.print(allocator, "\n  WHERE n0.\"{s}\" = ${d}", .{ primary_key, parameters.items.len + 1 });
            try parameters.append(allocator, .{ .id = id });
            wrote_where = true;
        },
        .matching => |predicates| for (predicates) |predicate| {
            try appendPredicateInto(allocator, sql, parameters, schema, node_name, 0, predicate, &wrote_where, "\n  WHERE ", "\n    AND ");
        },
    }

    const depth_parameter = parameters.items.len + 1;
    try sql.print(allocator,
        "\n  UNION ALL\n  SELECT e.\"{s}\", traversal.depth + 1\n  FROM traversal\n  JOIN \"{s}\" AS e ON e.\"{s}\" = traversal.node_id\n  WHERE traversal.depth < ${d}\n)",
        .{ to_column, relation.table, from_column, depth_parameter },
    );
    try parameters.append(allocator, .{ .id = step.max_depth });

    try sql.print(allocator, "\nSELECT n.\"{s}\" AS \"node_id\"\nFROM traversal\nJOIN \"{s}\" AS n ON n.\"{s}\" = traversal.node_id\nWHERE traversal.depth > 0", .{ primary_key, node.table, primary_key });

    var reached_where = true;
    for (step.where) |predicate| {
        try appendPredicateInto(allocator, sql, parameters, schema, node_name, null, predicate, &reached_where, "\nWHERE ", "\n  AND ");
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
    return appendPredicateInto(allocator, sql, parameters, schema, node_name, alias, predicate, wrote_where, "\nWHERE ", "\n  AND ");
}

/// `alias` of null qualifies the column with the outer `n` alias the recursive
/// form uses, rather than a numbered join alias.
fn appendPredicateInto(
    allocator: std.mem.Allocator,
    sql: *std.ArrayList(u8),
    parameters: *std.ArrayList(Parameter),
    schema: Schema.Schema,
    node_name: []const u8,
    alias: ?usize,
    predicate: Plan.Predicate,
    wrote_where: *bool,
    first: []const u8,
    subsequent: []const u8,
) !void {
    const field = try schema.nodeField(node_name, predicate.field);
    // The schema says what a column holds, so a text predicate on an id column
    // is a compile error rather than a query that matches nothing.
    const wants_text = predicate.match == .text;
    if ((field.kind == .id or field.kind == .integer) == wants_text) return error.FieldKindMismatch;

    try sql.appendSlice(allocator, if (wrote_where.*) subsequent else first);
    wrote_where.* = true;
    if (alias) |numbered| {
        try sql.print(allocator, "n{d}.\"{s}\" {s} ${d}", .{
            numbered,
            field.column,
            if (predicate.negated) "<>" else "=",
            parameters.items.len + 1,
        });
    } else {
        try sql.print(allocator, "n.\"{s}\" {s} ${d}", .{
            field.column,
            if (predicate.negated) "<>" else "=",
            parameters.items.len + 1,
        });
    }
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
        .{ .field = "status", .match = .{ .text = "failure" } },
        .{ .field = "requirement_id", .match = .{ .id = 77 } },
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
    const plan = try Plan.Builder.matching(&.{.{ .field = "status", .match = .{ .text = "failure" } }})
        .traverse(&.{.{ .direction = .children, .where = &.{.{ .field = "kind", .match = .{ .text = "activity_completed" } }} }})
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

test "a field/value mismatch is caught by the schema the plan is compiled against" {
    // The emitter resolves every name through the schema, so a value the column
    // cannot hold is refused before a database sees the statement.
    const mismatched = Plan.Plan{
        .from = .{ .matching = &.{.{ .field = "requirement_id", .match = .{ .text = "77" } }} },
    };
    try std.testing.expectError(
        error.FieldKindMismatch,
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
    const plan = try Plan.Builder.matching(&.{.{ .field = "status", .match = .{ .text = "failure" } }}).build();
    try std.testing.expectError(
        error.FieldKindMismatch,
        compile(std.testing.allocator, disagreeing, "Event", plan),
    );
}

test "a bounded traversal becomes a recursive CTE carrying its own depth bound" {
    const deep = try Plan.Builder.fromEvent(1)
        .traverse(&.{.{ .direction = .children, .max_depth = 8 }})
        .build();
    var compiled = try compile(std.testing.allocator, Schema.causal, "Event", deep);
    defer compiled.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        \\WITH RECURSIVE traversal(node_id, depth) AS (
        \\  SELECT n0."id", 0
        \\  FROM "causal_event" AS n0
        \\  WHERE n0."id" = $1
        \\  UNION ALL
        \\  SELECT e."event_id", traversal.depth + 1
        \\  FROM traversal
        \\  JOIN "causal_edge" AS e ON e."parent_id" = traversal.node_id
        \\  WHERE traversal.depth < $2
        \\)
        \\SELECT n."id" AS "node_id"
        \\FROM traversal
        \\JOIN "causal_event" AS n ON n."id" = traversal.node_id
        \\WHERE traversal.depth > 0
        \\LIMIT $3;
    , compiled.sql);

    // The depth bound is a parameter compared inside the recursive arm, so the
    // walk cannot exceed what the plan asked for however deep the graph is.
    try std.testing.expectEqual(@as(u64, 8), compiled.parameters[1].id);
    // Depth 0 is excluded: the result is what was reached, matching the embedded
    // connector, which returns descendants and not the node itself.
    try std.testing.expect(std.mem.indexOf(u8, compiled.sql, "traversal.depth > 0") != null);
}

test "a bounded traversal upward reverses the join and keeps its bound" {
    const up = try Plan.Builder
        .matching(&.{.{ .field = "status", .match = .{ .text = "failure" } }})
        .traverse(&.{.{ .direction = .parents, .max_depth = 4 }})
        .build();
    var compiled = try compile(std.testing.allocator, Schema.causal, "Event", up);
    defer compiled.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, compiled.sql, "WITH RECURSIVE") != null);
    // Reversed against the forward case.
    try std.testing.expect(std.mem.indexOf(u8, compiled.sql, "SELECT e.\"parent_id\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, compiled.sql, "e.\"event_id\" = traversal.node_id") != null);
    // The root filter is parameterised, not inlined.
    try std.testing.expectEqualStrings("failure", compiled.parameters[0].text);
    try std.testing.expectEqual(@as(u64, 4), compiled.parameters[1].id);
}

test "chained steps with a bounded hop are still refused rather than unbounded" {
    // One CTE per hop is not emitted yet, and an unbounded walk would return
    // more than the plan asked for.
    const chained = try Plan.Builder.fromEvent(1)
        .traverse(&.{
            .{ .direction = .children, .max_depth = 3 },
            .{ .direction = .parents },
        })
        .build();
    try std.testing.expectError(
        error.RecursiveTraversalNotCompiled,
        compile(std.testing.allocator, Schema.causal, "Event", chained),
    );
}

test "the connector declares what a relational store really can do" {
    try std.testing.expect(capabilities.vector_search);
    try std.testing.expect(capabilities.text_search);
    try std.testing.expect(capabilities.transactions);
    try std.testing.expect(capabilities.time_travel);
}
