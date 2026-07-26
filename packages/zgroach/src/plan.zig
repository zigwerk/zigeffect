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

pub const Error = error{
    InvalidPlan,
};

/// The columns a graph node exposes to a predicate. Deliberately a closed set:
/// a backend must be able to answer every one of these from an index, never by
/// decoding a record.
pub const Field = enum {
    label,
    kind,
    status,
    service_key,
    type_name,
    requirement_id,
    acceptance_check_id,
    scenario_id,
    run_id,
    session_id,

    pub fn isText(self: Field) bool {
        return switch (self) {
            .label, .kind, .status, .service_key, .type_name => true,
            .requirement_id, .acceptance_check_id, .scenario_id, .run_id, .session_id => false,
        };
    }
};

pub const Match = union(enum) {
    text: []const u8,
    id: u64,
};

pub const Predicate = struct {
    field: Field,
    match: Match,
    /// Negation is on the predicate rather than a separate operator set so that
    /// "everything that is not a success" stays a single indexed comparison.
    negated: bool = false,

    pub fn validate(self: Predicate) Error!void {
        const text_match = self.match == .text;
        if (self.field.isText() != text_match) return error.InvalidPlan;
        if (text_match and self.match.text.len == 0) return error.InvalidPlan;
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
};

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
        .traverse(&.{.{ .direction = .children, .max_depth = 3, .where = &.{.{ .field = .status, .match = .{ .text = "failure" } }} }})
        .limit(64)
        .build();

    try std.testing.expectEqual(@as(u64, 42), plan.from.event);
    try std.testing.expectEqual(@as(usize, 1), plan.steps.len);
    try std.testing.expectEqual(@as(usize, 3), plan.steps[0].max_depth);
    try std.testing.expectEqual(@as(usize, 64), plan.limit);
}

test "a plan refuses shapes the executor could not honour" {
    // A text column compared against an id, or the reverse, is a plan bug rather
    // than an empty result — catching it here keeps the executor total.
    try std.testing.expectError(error.InvalidPlan, Builder.matching(&.{.{ .field = .status, .match = .{ .id = 7 } }}).build());
    try std.testing.expectError(error.InvalidPlan, Builder.matching(&.{.{ .field = .requirement_id, .match = .{ .text = "x" } }}).build());
    try std.testing.expectError(error.InvalidPlan, Builder.matching(&.{.{ .field = .label, .match = .{ .text = "" } }}).build());

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

test "steps compose forward and backward causality" {
    // "What did the failures for this requirement cause?" is a filtered root
    // followed by a recursive forward step — one plan, two primitives.
    const plan = try Builder.matching(&.{
        .{ .field = .requirement_id, .match = .{ .id = 99 } },
        .{ .field = .status, .match = .{ .text = "failure" } },
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
