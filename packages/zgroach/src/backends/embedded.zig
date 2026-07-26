//! Connector for the embedded causal graph.
//!
//! This is the local, file-backed store: an append-only log with a derived
//! index and CSR adjacency, all in-process, no daemon and no network. It is the
//! store an agent queries while developing, and the one a service carries with
//! it.
//!
//! What it can and cannot do is a direct consequence of that. Predicates are
//! answered from materialised index columns, traversal from the adjacency the
//! engine builds at open, and both are cheap. Vector distance and full-text
//! ranking are absent because the causal log stores neither — those belong to a
//! connector over a store that indexes documents, not execution events.

const std = @import("std");
const zstd = @import("zigeffect_std");
const Plan = @import("../plan.zig");
const Backend = @import("../backend.zig");

pub const capabilities = Backend.Capabilities{
    .predicates = true,
    .traversal = true,
    .recursive_traversal = true,
    .reverse_traversal = true,
    // The causal log records execution, not documents or embeddings. A
    // connector that claimed these would be claiming data that does not exist.
    .text_search = false,
    .vector_search = false,
    // A snapshot is already a consistent read of one point in the log, so there
    // is no separate time-travel surface to expose.
    .time_travel = false,
    .transactions = false,
};

/// Borrows a snapshot; the caller owns its lifetime. A connector deliberately
/// does not open or close the store, so the same snapshot can serve several
/// queries without re-reading anything.
pub const Connector = struct {
    snapshot: *const zstd.CausalGraph.Snapshot,

    pub fn init(snapshot: *const zstd.CausalGraph.Snapshot) Connector {
        return .{ .snapshot = snapshot };
    }

    pub fn backend(self: *Connector) Backend.Backend {
        return .{
            .ptr = self,
            .vtable = &.{
                .name = "embedded-causal",
                .capabilities = capabilities,
                .execute = execute,
            },
        };
    }

    fn execute(ptr: *anyopaque, allocator: std.mem.Allocator, plan: Plan.Plan) anyerror!Plan.Result {
        const self: *Connector = @ptrCast(@alignCast(ptr));
        return run(self.snapshot, allocator, plan);
    }
};

/// Lower a plan onto the engine's primitives.
///
/// This is the counterpart of roachgraph's SQL compiler. Where that one emits a
/// statement, this one drives two calls: a scan of materialised columns to
/// resolve the root set, and CSR traversal for each step. Nothing decodes a
/// record.
fn run(
    snapshot: *const zstd.CausalGraph.Snapshot,
    allocator: std.mem.Allocator,
    plan: Plan.Plan,
) !Plan.Result {
    var current: std.ArrayList(u64) = .empty;
    defer current.deinit(allocator);
    var scanned: usize = 0;
    var truncated = false;

    switch (plan.from) {
        .event => |id| if (snapshot.topology.contains(id)) try current.append(allocator, id),
        .matching => |predicates| {
            // Resolving a filtered root is the only part that looks at every
            // candidate, so it is the part that carries the scan bound.
            var position: usize = 0;
            while (position < snapshot.nodeCount()) : (position += 1) {
                if (scanned == plan.scan_limit) {
                    truncated = true;
                    break;
                }
                scanned += 1;
                const node = snapshot.nodeAt(position) orelse return error.ColumnsUnavailable;
                if (!matchesAll(node, predicates)) continue;
                if (current.items.len == plan.limit) {
                    truncated = true;
                    break;
                }
                try current.append(allocator, node.durable_event_id);
            }
        },
    }

    var next: std.ArrayList(u64) = .empty;
    defer next.deinit(allocator);
    for (plan.steps) |step| {
        next.clearRetainingCapacity();
        var hit_limit = false;
        for (current.items) |id| {
            var walk = switch (step.direction) {
                .children => try snapshot.descendantsAlloc(allocator, id, .{
                    .max_depth = step.max_depth,
                    .max_results = plan.limit,
                }),
                .parents => try snapshot.ancestorsAlloc(allocator, id, .{
                    .max_depth = step.max_depth,
                    .max_results = plan.limit,
                }),
            };
            defer walk.deinit(allocator);
            if (walk.truncated) truncated = true;

            for (walk.ids) |reached| {
                if (next.items.len == plan.limit) {
                    hit_limit = true;
                    break;
                }
                if (step.where.len != 0) {
                    const position = snapshot.topology.indexOf(reached) orelse continue;
                    const node = snapshot.nodeAt(position) orelse return error.ColumnsUnavailable;
                    if (!matchesAll(node, step.where)) continue;
                }
                // A node reachable by more than one route is one result.
                if (contains(next.items, reached)) continue;
                try next.append(allocator, reached);
            }
            if (hit_limit) break;
        }
        if (hit_limit) truncated = true;
        std.mem.swap(std.ArrayList(u64), &current, &next);
    }

    return .{
        .ids = try current.toOwnedSlice(allocator),
        .scanned = scanned,
        .truncated = truncated,
    };
}

fn contains(ids: []const u64, candidate: u64) bool {
    for (ids) |id| if (id == candidate) return true;
    return false;
}

fn matchesAll(node: zstd.CausalGraph.Snapshot.NodeView, predicates: []const Plan.Predicate) bool {
    for (predicates) |predicate| if (!matches(node, predicate)) return false;
    return true;
}

fn matches(node: zstd.CausalGraph.Snapshot.NodeView, predicate: Plan.Predicate) bool {
    const matched = switch (predicate.match) {
        .text => |wanted| blk: {
            const actual = textColumn(node, predicate.field) orelse break :blk false;
            break :blk std.mem.eql(u8, actual, wanted);
        },
        .id => |wanted| blk: {
            const actual = idColumn(node, predicate.field) orelse break :blk false;
            break :blk actual == wanted;
        },
    };
    return matched != predicate.negated;
}

/// Resolve a schema field name onto this store's materialised columns. A name
/// the causal schema does not declare simply has no column here, and a plan
/// naming one is rejected by `validateAgainst` before reaching this point.
fn textColumn(node: zstd.CausalGraph.Snapshot.NodeView, name: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, name, "label")) return node.label;
    if (std.mem.eql(u8, name, "kind")) return node.kind;
    if (std.mem.eql(u8, name, "status")) return node.status;
    if (std.mem.eql(u8, name, "service_key")) return node.service_key;
    if (std.mem.eql(u8, name, "type_name")) return node.type_name;
    return null;
}

fn idColumn(node: zstd.CausalGraph.Snapshot.NodeView, name: []const u8) ?u64 {
    if (std.mem.eql(u8, name, "requirement_id")) return node.requirement_id;
    if (std.mem.eql(u8, name, "acceptance_check_id")) return node.acceptance_check_id;
    if (std.mem.eql(u8, name, "scenario_id")) return node.scenario_id;
    if (std.mem.eql(u8, name, "run_id")) return node.run_id;
    if (std.mem.eql(u8, name, "session_id")) return node.session_id;
    return null;
}

test "the embedded connector answers plans over a real graph" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // A small causal shape: a run, two operations under it, one of which
    // failed, and a compensating record under the failure. Written through the
    // public store/backend seam an application would use, not an internal one.
    var failure_id: u64 = 0;
    {
        var database = try zstd.CausalGraph.LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
        defer database.deinit();
        var backend = database.storageBackend(std.testing.allocator, 64);
        defer backend.deinit();
        var store = zstd.fx.CausalStore.init(std.testing.allocator);
        defer store.deinit();
        store.attachBackend(backend.backend());

        const run_id = try store.record(.{ .kind = .run_started, .label = "run", .status = "running" });
        _ = try store.record(.{ .kind = .effect_completed, .parent_id = run_id, .label = "Todo.create", .status = "success" });
        failure_id = try store.record(.{ .kind = .effect_completed, .parent_id = run_id, .label = "Todo.create", .status = "failure" });
        _ = try store.record(.{ .kind = .activity_completed, .parent_id = failure_id, .label = "Todo.rollback", .status = "success" });
        try backend.flush();
    }

    var snapshot = try zstd.CausalGraph.Snapshot.open(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer snapshot.deinit();
    var connector = Connector.init(&snapshot);
    const store = connector.backend();

    try std.testing.expectEqualStrings("embedded-causal", store.name());

    // "What did the failure cause?" — anchored root, forward traversal.
    var caused = try store.execute(std.testing.allocator, try Plan.Builder.fromEvent(failure_id)
        .traverse(&.{.{ .direction = .children, .max_depth = 8 }})
        .build());
    defer caused.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), caused.ids.len);

    // "What led to it?" — the same plan inverted.
    var led = try store.execute(std.testing.allocator, try Plan.Builder.fromEvent(failure_id)
        .traverse(&.{.{ .direction = .parents, .max_depth = 8 }})
        .build());
    defer led.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), led.ids.len);

    // A filtered root: every failure, without knowing an id first.
    var failures = try store.execute(std.testing.allocator, try Plan.Builder
        .matching(&.{.{ .field = "status", .match = .{ .text = "failure" } }})
        .build());
    defer failures.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u64, &.{failure_id}, failures.ids);

    // The composed question, which neither primitive answers alone: everything
    // caused by any failure.
    var fallout = try store.execute(std.testing.allocator, try Plan.Builder
        .matching(&.{.{ .field = "status", .match = .{ .text = "failure" } }})
        .traverse(&.{.{ .direction = .children, .max_depth = 8 }})
        .build());
    defer fallout.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), fallout.ids.len);
    // The composed answer is exactly what the anchored one found.
    try std.testing.expectEqualSlices(u64, caused.ids, fallout.ids);

    // Negation is a predicate, not a second operator set.
    var not_failed = try store.execute(std.testing.allocator, try Plan.Builder
        .matching(&.{.{ .field = "label", .match = .{ .text = "Todo.create" } }, .{ .field = "status", .match = .{ .text = "failure" }, .negated = true }})
        .build());
    defer not_failed.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), not_failed.ids.len);
    try std.testing.expect(not_failed.ids[0] != failure_id);
}

test "the embedded connector refuses what the causal log cannot answer" {
    // Declared rather than discovered: a vector query against execution events
    // is rejected by capability, before any store is touched.
    try std.testing.expect(!capabilities.vector_search);
    try std.testing.expect(!capabilities.text_search);
    try std.testing.expect(capabilities.recursive_traversal);
    try std.testing.expect(capabilities.reverse_traversal);
}
