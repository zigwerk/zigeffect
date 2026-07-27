//! The connector boundary.
//!
//! One schema and one query surface over several stores, in the shape Prisma
//! uses: a plan is written once, a connector answers it, and what a connector
//! can actually do is *declared* rather than discovered when a query fails.
//!
//! The stores differ in real ways. The embedded causal engine has index columns
//! and CSR adjacency but no vectors and no transactions. CockroachDB has vector
//! distance, full-text ranking, follower reads and transactions, but every
//! traversal is a join it has to plan. Pretending those are the same surface
//! would mean either reducing the query language to their intersection, or
//! letting a query compile and then fail at execution.
//!
//! `Capabilities` is the third option: a plan is checked against the connector
//! *before* execution, and an unsupported feature is a typed error naming the
//! feature and the connector. That turns "this query silently returns nothing on
//! SQLite" into a compile-or-connect-time answer.

const std = @import("std");
const Plan = @import("plan.zig");

pub const Error = error{
    /// The plan asks for something this connector does not implement. The
    /// diagnostic names both, because "unsupported" without either is useless
    /// to whoever has to choose a different store or a different query.
    UnsupportedByBackend,
};

/// What a connector can answer. Additive: a new capability defaults to false so
/// an existing connector cannot silently claim something it has not implemented.
pub const Capabilities = struct {
    /// Filter on indexed node columns.
    predicates: bool = false,
    /// Follow edges one hop.
    traversal: bool = false,
    /// Follow edges to a bounded depth in one step.
    recursive_traversal: bool = false,
    /// Walk edges against their direction.
    reverse_traversal: bool = false,
    /// Rank by full-text relevance.
    text_search: bool = false,
    /// Order by vector distance.
    vector_search: bool = false,
    /// Read at a consistent point in the past.
    time_travel: bool = false,
    /// Group plan execution in a transaction.
    transactions: bool = false,
};

/// The feature a plan needed that a connector lacks. Returned alongside the
/// error so a caller can report precisely what to change.
pub const Unsupported = struct {
    backend: []const u8,
    feature: []const u8,
};

pub const Backend = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    /// Note that a vtable is a compile-time constant, so `capabilities` is too.
    /// That is deliberate rather than incidental: what a store can answer is a
    /// property of the connector, not of a particular connection, and letting it
    /// vary at runtime would make a plan's validity unknowable until execution.
    pub const VTable = struct {
        name: []const u8,
        capabilities: Capabilities,
        execute: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, plan: Plan.Plan) anyerror!Plan.Result,
    };

    pub fn name(self: Backend) []const u8 {
        return self.vtable.name;
    }

    pub fn capabilities(self: Backend) Capabilities {
        return self.vtable.capabilities;
    }

    /// Check a plan against this connector without running it.
    ///
    /// Separate from `execute` on purpose: a caller choosing between connectors,
    /// or validating a stored plan at build time, must be able to ask without
    /// touching a store.
    pub fn check(self: Backend, plan: Plan.Plan) Error!void {
        _ = supportGap(self.vtable.name, self.vtable.capabilities, plan) orelse return;
        return error.UnsupportedByBackend;
    }

    /// The same check, returning what was missing rather than only that
    /// something was.
    pub fn gap(self: Backend, plan: Plan.Plan) ?Unsupported {
        return supportGap(self.vtable.name, self.vtable.capabilities, plan);
    }

    pub fn execute(self: Backend, allocator: std.mem.Allocator, plan: Plan.Plan) !Plan.Result {
        try plan.validate();
        try self.check(plan);
        return self.vtable.execute(self.ptr, allocator, plan);
    }
};

/// A ranking match needs the capability that matches its kind.
///
/// Until this existed, `text_search` and `vector_search` were declared on
/// backends and reachable by no plan node — neither offered nor deniable, which
/// is a capability in name only.
fn rankingGap(backend_name: []const u8, capabilities: Capabilities, predicates: []const Plan.Predicate) ?Unsupported {
    for (predicates) |predicate| switch (predicate.match) {
        .lexical => if (!capabilities.text_search) return .{ .backend = backend_name, .feature = "text_search" },
        .similar => if (!capabilities.vector_search) return .{ .backend = backend_name, .feature = "vector_search" },
        .text, .id => {},
    };
    return null;
}

fn supportGap(backend_name: []const u8, capabilities: Capabilities, plan: Plan.Plan) ?Unsupported {
    const needs_predicates = switch (plan.from) {
        .matching => true,
        .event => false,
    };
    if (needs_predicates and !capabilities.predicates) {
        return .{ .backend = backend_name, .feature = "predicates" };
    }
    // A ranking match needs the capability that matches its kind. Until now
    // `text_search` and `vector_search` were declared on backends and reachable
    // by no plan node, so nothing could request them and nothing could refuse
    // them — a capability that is neither offered nor denied.
    if (rankingGap(backend_name, capabilities, switch (plan.from) {
        .matching => |predicates| predicates,
        .event => &.{},
    })) |gap| return gap;
    for (plan.steps) |step| {
        if (!capabilities.traversal) return .{ .backend = backend_name, .feature = "traversal" };
        if (step.max_depth > 1 and !capabilities.recursive_traversal) {
            return .{ .backend = backend_name, .feature = "recursive_traversal" };
        }
        if (step.direction == .parents and !capabilities.reverse_traversal) {
            return .{ .backend = backend_name, .feature = "reverse_traversal" };
        }
        if (step.where.len != 0 and !capabilities.predicates) {
            return .{ .backend = backend_name, .feature = "predicates" };
        }
        if (rankingGap(backend_name, capabilities, step.where)) |gap| return gap;
    }
    return null;
}

test "a backend that cannot rank refuses to be asked" {
    // The defect this closes: text_search and vector_search were declared on
    // every backend and requestable by no plan, so a store that could not rank
    // never had to say so — and one that could was never asked.
    const probe = [_]f32{ 0.5, 0.5 };
    const lexical = try Plan.Builder.matching(&.{.{ .field = "bio", .match = .{ .lexical = "checkout" } }}).build();
    const similar = try Plan.Builder.matching(&.{.{ .field = "profile", .match = .{ .similar = &probe } }}).build();

    const cannot = Capabilities{ .predicates = true };
    try std.testing.expectEqualStrings("text_search", supportGap("store", cannot, lexical).?.feature);
    try std.testing.expectEqualStrings("vector_search", supportGap("store", cannot, similar).?.feature);

    const can = Capabilities{ .predicates = true, .text_search = true, .vector_search = true };
    try std.testing.expect(supportGap("store", can, lexical) == null);
    try std.testing.expect(supportGap("store", can, similar) == null);

    // Refused by name and before execution, so a store never partially answers
    // a question it cannot answer.
    const half = Capabilities{ .predicates = true, .text_search = true };
    try std.testing.expectEqualStrings("vector_search", supportGap("store", half, similar).?.feature);
    try std.testing.expect(supportGap("store", half, lexical) == null);
}

const TestBackend = struct {
    calls: usize = 0,

    fn execute(ptr: *anyopaque, allocator: std.mem.Allocator, plan: Plan.Plan) anyerror!Plan.Result {
        const self: *TestBackend = @ptrCast(@alignCast(ptr));
        self.calls += 1;
        _ = plan;
        return .{ .ids = try allocator.alloc(u64, 0), .scanned = 0, .truncated = false };
    }

    fn backend(
        self: *TestBackend,
        comptime backend_name: []const u8,
        comptime declared: Capabilities,
    ) Backend {
        return .{
            .ptr = self,
            .vtable = &.{ .name = backend_name, .capabilities = declared, .execute = execute },
        };
    }
};

test "a connector declares what it can answer and refuses the rest before executing" {
    // A store with traversal but no recursion — the shape of a plain adjacency
    // table, or an engine that only exposes direct edges.
    var shallow = TestBackend{};
    const one_hop = shallow.backend("shallow", .{ .predicates = true, .traversal = true });

    const direct = try Plan.Builder.fromEvent(1)
        .traverse(&.{.{ .direction = .children }})
        .build();
    var result = try one_hop.execute(std.testing.allocator, direct);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), shallow.calls);

    const deep = try Plan.Builder.fromEvent(1)
        .traverse(&.{.{ .direction = .children, .max_depth = 8 }})
        .build();
    try std.testing.expectError(error.UnsupportedByBackend, one_hop.execute(std.testing.allocator, deep));
    // Refused before the connector was reached, not after it failed.
    try std.testing.expectEqual(@as(usize, 1), shallow.calls);

    // The gap names both sides, so a caller can act on it.
    const missing = one_hop.gap(deep).?;
    try std.testing.expectEqualStrings("shallow", missing.backend);
    try std.testing.expectEqualStrings("recursive_traversal", missing.feature);

    const upward = try Plan.Builder.fromEvent(1)
        .traverse(&.{.{ .direction = .parents }})
        .build();
    try std.testing.expectEqualStrings("reverse_traversal", one_hop.gap(upward).?.feature);
}

test "a fully capable connector reports no gap" {
    var full = TestBackend{};
    const backend = full.backend("full", .{
        .predicates = true,
        .traversal = true,
        .recursive_traversal = true,
        .reverse_traversal = true,
    });

    const plan = try Plan.Builder.matching(&.{.{ .field = "status", .match = .{ .text = "failure" } }})
        .traverse(&.{
            .{ .direction = .children, .max_depth = 16 },
            .{ .direction = .parents, .max_depth = 4, .where = &.{.{ .field = "kind", .match = .{ .text = "effect_completed" } }} },
        })
        .build();
    try std.testing.expect(backend.gap(plan) == null);
    try backend.check(plan);
}

test "a connector without predicates cannot answer a filtered root" {
    var traversal_only = TestBackend{};
    const backend = traversal_only.backend("traversal-only", .{ .traversal = true, .recursive_traversal = true });

    const anchored = try Plan.Builder.fromEvent(9).traverse(&.{.{ .direction = .children, .max_depth = 3 }}).build();
    try backend.check(anchored);

    const filtered = try Plan.Builder.matching(&.{.{ .field = "label", .match = .{ .text = "x" } }}).build();
    try std.testing.expectEqualStrings("predicates", backend.gap(filtered).?.feature);
}
