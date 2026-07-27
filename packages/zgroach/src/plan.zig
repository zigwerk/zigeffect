//! Backend-neutral graph query plan.
//!
//! Ported from `packages/roachgraph`, which proved the shape: a fluent builder
//! produces a **pure data plan**, and a separate compiler lowers that plan onto
//! whatever a backend speaks. There it emits one CockroachDB statement joining
//! traversal, relational predicates, full-text ranking and vector distance.
//!
//! This package keeps the plan and gains a connector boundary, so the same query
//! serves more than one store — the embedded causal engine, CockroachDB, or
//! anything else that can declare what it supports. That is why nothing here
//! names a table, a statement, a file or an index: a plan describes *what* is
//! being asked, never how a particular store would answer it.
//!
//! A textual query language, if one is ever wanted, is a frontend that lowers to
//! this type. It is not a second engine.
//!
//! Everything is bounded by construction. A plan is a value with no allocation
//! and no interior mutability, so it can be built at comptime, stored in a
//! manifest, or shipped across a boundary and validated on arrival.

const std = @import("std");
const Schema = @import("schema.zig");

pub const Error = error{
    InvalidPlan,
};

/// The name of a field on the node being filtered.
///
/// Deliberately a name and not an enum. An enum could only ever list one
/// store's columns, which would make a plan untargetable at any other — the
/// whole point of the plan being backend-neutral. What a name *means* is the
/// schema's job, and a name that does not exist there is rejected before
/// execution rather than matching nothing.
pub const FieldName = []const u8;

pub const Match = union(enum) {
    /// Equality on a text column.
    text: []const u8,
    /// Equality on an identifier or integer column.
    id: u64,
    /// Ranked by lexical relevance over a `.document` column. Requires the
    /// backend's `text_search` capability.
    ///
    /// A separate variant from `.text` on purpose: equality answers "is it this"
    /// and ranking answers "how much is it like this", and a store that can do
    /// the first cannot necessarily do the second. Collapsing them is how a
    /// capability flag ends up declared and unreachable.
    lexical: []const u8,
    /// Ordered by distance from a probe over a `.vector` column. Requires the
    /// backend's `vector_search` capability.
    similar: []const f32,

    /// Whether this match ranks rather than compares. Ranking needs a capability
    /// and produces an order; comparison needs neither.
    pub fn ranks(self: Match) bool {
        return switch (self) {
            .text, .id => false,
            .lexical, .similar => true,
        };
    }
};

pub const Predicate = struct {
    field: FieldName,
    match: Match,
    /// Negation is on the predicate rather than a separate operator set so that
    /// "everything that is not a success" stays a single indexed comparison.
    negated: bool = false,

    /// Structural only. Whether the field exists, and whether its type admits
    /// this value, needs a schema and is checked by `Plan.validateAgainst`.
    pub fn validate(self: Predicate) Error!void {
        if (self.field.len == 0 or self.field.len > max_field_name_bytes) return error.InvalidPlan;
        if (self.match == .text and self.match.text.len == 0) return error.InvalidPlan;
    }
};

pub const Direction = enum {
    /// Follow causality forward: what this event caused.
    children,
    /// Follow causality backward: what led to this event.
    parents,
};

/// One hop, or a bounded run of hops, with an optional filter applied to what it
/// lands on. This is roachgraph's `appendTraversal` plus `withRecursiveTraversal`
/// collapsed into one node, because a depth of 1 is just the non-recursive case.
pub const Step = struct {
    direction: Direction,
    max_depth: usize = 1,
    /// Applied to the nodes this step reaches, not to the nodes it started from.
    where: []const Predicate = &.{},

    pub fn validate(self: Step) Error!void {
        if (self.max_depth == 0 or self.max_depth > max_traversal_depth) return error.InvalidPlan;
        if (self.where.len > max_predicates) return error.InvalidPlan;
        for (self.where) |predicate| try predicate.validate();
    }
};

pub const max_field_name_bytes: usize = 128;
pub const max_predicates: usize = 16;
pub const max_steps: usize = 8;
pub const max_traversal_depth: usize = 4096;
pub const max_limit: usize = 4096;
pub const max_scan: usize = 1 << 20;

/// Where a query starts.
///
/// Either one known event, or every event matching a filter. Anchoring at a
/// single event is the common agent case — "what did *this* failure cause" —
/// and it costs a binary search rather than a scan.
pub const Root = union(enum) {
    event: u64,
    matching: []const Predicate,
};

pub const Plan = struct {
    from: Root,
    steps: []const Step = &.{},
    /// Maximum results returned.
    limit: usize = 256,
    /// Maximum index entries examined while resolving a `matching` root. A
    /// selective query over a large graph must be able to stop rather than walk
    /// everything, and the result reports when it did.
    scan_limit: usize = 4096,

    pub fn validate(self: Plan) Error!void {
        if (self.limit == 0 or self.limit > max_limit) return error.InvalidPlan;
        if (self.scan_limit == 0 or self.scan_limit > max_scan) return error.InvalidPlan;
        if (self.steps.len > max_steps) return error.InvalidPlan;
        switch (self.from) {
            .event => |id| if (id == 0) return error.InvalidPlan,
            .matching => |predicates| {
                if (predicates.len == 0 or predicates.len > max_predicates) return error.InvalidPlan;
                for (predicates) |predicate| try predicate.validate();
            },
        }
        for (self.steps) |step| try step.validate();
    }

    /// Semantic validation: every field named must exist on the node, and its
    /// declared type must admit the value compared against it.
    ///
    /// Separate from `validate` because a plan is meaningful without a schema —
    /// it can be built, stored and shipped — but cannot be *executed* until one
    /// says what its names mean. Running this before a connector is reached
    /// turns "returns nothing" into "that field does not exist".
    pub fn validateAgainst(self: Plan, schema: Schema.Schema, node_name: []const u8) !void {
        try self.validate();
        const node = try schema.node(node_name);
        switch (self.from) {
            .event => {},
            .matching => |predicates| for (predicates) |predicate| try checkField(node, predicate),
        }
        for (self.steps) |step| {
            for (step.where) |predicate| try checkField(node, predicate);
        }
    }
};

fn checkField(node: Schema.Node, predicate: Predicate) !void {
    const field = try node.field(predicate.field);
    // Answer the question per kind rather than inferring it from whether the
    // column holds a number. `FieldKind` has five variants and the boolean had
    // room for two, so `.document` and `.vector` fell through: neither holds a
    // number, so a text-equality predicate on an embedding validated cleanly.
    //
    // A document is ranked by relevance and a vector is ordered by distance.
    // Neither answers "is it equal to this", which is the only question a
    // `Predicate` can ask today. Refusing them here is what keeps the capability
    // flags honest — when a ranking operator exists it will be a different node,
    // not an equality predicate that happens to be pointed at a ranked column.
    const accepts: bool = switch (field.kind) {
        .text => predicate.match == .text,
        .integer, .id => predicate.match == .id,
        // Ranked columns answer a ranking operator and nothing else. Equality on
        // an embedding is not a cheap approximation of similarity, it is a
        // different question with no useful answer.
        .document => predicate.match == .lexical,
        .vector => predicate.match == .similar,
    };
    if (!accepts) return error.FieldKindMismatch;
}

/// What a plan produced, and whether any bound cut it short.
///
/// `truncated` is reported for the same reason traversal reports it: a partial
/// causal answer read as a complete one is worse than no answer.
pub const Result = struct {
    ids: []u64,
    scanned: usize,
    truncated: bool,

    pub fn deinit(self: *Result, allocator: std.mem.Allocator) void {
        allocator.free(self.ids);
        self.* = undefined;
    }
};

/// Fluent construction, mirroring roachgraph's builder so the two stay legible
/// against each other. Returns plain data; nothing is executed here.
pub const Builder = struct {
    plan: Plan,

    pub fn fromEvent(durable_event_id: u64) Builder {
        return .{ .plan = .{ .from = .{ .event = durable_event_id } } };
    }

    pub fn matching(predicates: []const Predicate) Builder {
        return .{ .plan = .{ .from = .{ .matching = predicates } } };
    }

    pub fn traverse(self: Builder, steps: []const Step) Builder {
        var next = self;
        next.plan.steps = steps;
        return next;
    }

    pub fn limit(self: Builder, value: usize) Builder {
        var next = self;
        next.plan.limit = value;
        return next;
    }

    pub fn scanLimit(self: Builder, value: usize) Builder {
        var next = self;
        next.plan.scan_limit = value;
        return next;
    }

    pub fn build(self: Builder) Error!Plan {
        try self.plan.validate();
        return self.plan;
    }
};

test "a plan is data and validates its own bounds" {
    const plan = try Builder.fromEvent(42)
        .traverse(&.{.{ .direction = .children, .max_depth = 3, .where = &.{.{ .field = "status", .match = .{ .text = "failure" } }} }})
        .limit(64)
        .build();

    try std.testing.expectEqual(@as(u64, 42), plan.from.event);
    try std.testing.expectEqual(@as(usize, 1), plan.steps.len);
    try std.testing.expectEqual(@as(usize, 3), plan.steps[0].max_depth);
    try std.testing.expectEqual(@as(usize, 64), plan.limit);
}

test "a plan refuses shapes the executor could not honour" {
    // A field name is structural: empty or absurdly long is a plan bug.
    try std.testing.expectError(error.InvalidPlan, Builder.matching(&.{.{ .field = "", .match = .{ .id = 7 } }}).build());
    try std.testing.expectError(error.InvalidPlan, Builder.matching(&.{.{ .field = "label", .match = .{ .text = "" } }}).build());

    // An unanchored, unfiltered root would be a full scan wearing a query's
    // clothes; `since` already does that far more cheaply.
    try std.testing.expectError(error.InvalidPlan, Builder.matching(&.{}).build());
    try std.testing.expectError(error.InvalidPlan, Builder.fromEvent(0).build());

    try std.testing.expectError(error.InvalidPlan, Builder.fromEvent(1).limit(0).build());
    try std.testing.expectError(error.InvalidPlan, Builder.fromEvent(1).limit(max_limit + 1).build());
    try std.testing.expectError(
        error.InvalidPlan,
        Builder.fromEvent(1).traverse(&.{.{ .direction = .children, .max_depth = 0 }}).build(),
    );
}

test "a ranking match is a different question from an equality one" {
    const commerce = Schema.Schema{
        .name = "commerce",
        .nodes = &.{.{ .name = "User", .table = "user", .fields = &.{
            .{ .name = "id", .column = "id", .kind = .id },
            .{ .name = "bio", .column = "bio_search", .kind = .document },
            .{ .name = "profile", .column = "embedding", .kind = .vector },
        } }},
        .relations = &.{},
    };

    // A document ranks lexically and a vector ranks by distance. Each accepts
    // exactly one operator, and the schema is what says which.
    const lexical = try Builder.matching(&.{.{ .field = "bio", .match = .{ .lexical = "checkout" } }}).build();
    try lexical.validateAgainst(commerce, "User");

    const probe = [_]f32{ 0.1, 0.2, 0.3 };
    const similar = try Builder.matching(&.{.{ .field = "profile", .match = .{ .similar = &probe } }}).build();
    try similar.validateAgainst(commerce, "User");

    // Crossed over, they are refused: ranking a vector lexically is not a
    // degraded answer, it is a different question with no answer.
    const crossed = try Builder.matching(&.{.{ .field = "profile", .match = .{ .lexical = "checkout" } }}).build();
    try std.testing.expectError(error.FieldKindMismatch, crossed.validateAgainst(commerce, "User"));

    // And ranking is distinguishable from comparison without inspecting the tag.
    try std.testing.expect((Match{ .lexical = "x" }).ranks());
    try std.testing.expect((Match{ .similar = &probe }).ranks());
    try std.testing.expect(!(Match{ .text = "x" }).ranks());
    try std.testing.expect(!(Match{ .id = 1 }).ranks());
}

test "equality is refused on columns that are ranked, not compared" {
    // FieldKind has five variants and the check collapsed them to one boolean:
    // "does this hold a number". A vector is ordered by distance and a document
    // is ranked by relevance, so neither answers an equality predicate — but
    // neither holds a number either, so both validated cleanly.
    const commerce = Schema.Schema{
        .name = "commerce",
        .nodes = &.{.{ .name = "User", .table = "user", .fields = &.{
            .{ .name = "id", .column = "id", .kind = .id },
            .{ .name = "status", .column = "status" },
            .{ .name = "bio", .column = "bio_search", .kind = .document },
            .{ .name = "profile", .column = "embedding", .kind = .vector },
        } }},
        .relations = &.{},
    };

    const text_on_vector = try Builder.matching(&.{.{ .field = "profile", .match = .{ .text = "x" } }}).build();
    try std.testing.expectError(error.FieldKindMismatch, text_on_vector.validateAgainst(commerce, "User"));

    const text_on_document = try Builder.matching(&.{.{ .field = "bio", .match = .{ .text = "x" } }}).build();
    try std.testing.expectError(error.FieldKindMismatch, text_on_document.validateAgainst(commerce, "User"));

    // Both remain refused for id matching too, which the old rule happened to
    // get right by the same accident that made it wrong above.
    const id_on_vector = try Builder.matching(&.{.{ .field = "profile", .match = .{ .id = 1 } }}).build();
    try std.testing.expectError(error.FieldKindMismatch, id_on_vector.validateAgainst(commerce, "User"));

    // And the ordinary columns still work.
    const fine = try Builder.matching(&.{
        .{ .field = "status", .match = .{ .text = "active" } },
        .{ .field = "id", .match = .{ .id = 9 } },
    }).build();
    try fine.validateAgainst(commerce, "User");
}

test "a plan is only meaningful once a schema says what its names are" {
    // Structurally fine, and deliberately so: a plan can be built and stored
    // without a schema. What the names mean is checked when one is supplied.
    const typed_wrong = try Builder.matching(&.{.{ .field = "status", .match = .{ .id = 7 } }}).build();
    try typed_wrong.validate();
    try std.testing.expectError(error.FieldKindMismatch, typed_wrong.validateAgainst(Schema.causal, "Event"));

    const reversed = try Builder.matching(&.{.{ .field = "requirement_id", .match = .{ .text = "x" } }}).build();
    try std.testing.expectError(error.FieldKindMismatch, reversed.validateAgainst(Schema.causal, "Event"));

    // A name the schema does not declare is named as such, rather than matching
    // nothing at execution time.
    const unknown = try Builder.matching(&.{.{ .field = "not_a_column", .match = .{ .text = "x" } }}).build();
    try std.testing.expectError(error.UnknownField, unknown.validateAgainst(Schema.causal, "Event"));

    // A step's filter is checked too, not only the root's.
    const bad_step = try Builder.fromEvent(1)
        .traverse(&.{.{ .direction = .children, .where = &.{.{ .field = "nope", .match = .{ .text = "x" } }} }})
        .build();
    try std.testing.expectError(error.UnknownField, bad_step.validateAgainst(Schema.causal, "Event"));

    // And the well-formed case passes both layers.
    const good = try Builder.matching(&.{
        .{ .field = "status", .match = .{ .text = "failure" } },
        .{ .field = "requirement_id", .match = .{ .id = 42 } },
    }).build();
    try good.validateAgainst(Schema.causal, "Event");
}

test "steps compose forward and backward causality" {
    // "What did the failures for this requirement cause?" is a filtered root
    // followed by a recursive forward step — one plan, two primitives.
    const plan = try Builder.matching(&.{
        .{ .field = "requirement_id", .match = .{ .id = 99 } },
        .{ .field = "status", .match = .{ .text = "failure" } },
    })
        .traverse(&.{.{ .direction = .children, .max_depth = 16 }})
        .build();
    try std.testing.expectEqual(@as(usize, 2), plan.from.matching.len);

    // And the mirror question, "what led to this?", is the same plan inverted.
    const upward = try Builder.fromEvent(7)
        .traverse(&.{.{ .direction = .parents, .max_depth = 32 }})
        .build();
    try std.testing.expectEqual(Direction.parents, upward.steps[0].direction);
}
