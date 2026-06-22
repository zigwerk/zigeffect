//! The self-improving loop, as a runnable example.
//!
//! Demonstrates the vision end-to-end with the public API: a causal graph
//! contains a hung fiber; the RemediationLoop detects it (via the H4 hang
//! finding), derives an interrupt remediation, decides it under policy, applies
//! it, and verifies — all without a human naming the fiber. Two passes show the
//! gate governing execution: record-only by default, executing once enabled.
//!
//! Run: `zig build self-improving-loop-example` (or via `zig build examples`).

const std = @import("std");
const fx = @import("zigeffect");

/// Record a hung fiber so the H4 detector produces a finding.
fn recordHungFiber(store: *fx.CausalStore, fiber_id: u64) !void {
    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const rs = try store.record(.{ .kind = .run_started, .run_id = run_id, .status = "started" });
    const opened = try store.record(.{ .kind = .scope_opened, .run_id = run_id, .scope_id = scope_id, .parent_id = rs, .status = "opened" });
    const forked = try store.record(.{ .kind = .fiber_forked, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = opened, .status = "pending" });
    const started = try store.record(.{ .kind = .fiber_started, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = forked, .status = "running" });
    _ = try store.record(.{ .kind = .fiber_suspended, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = started, .status = "pending" });
}

/// The remediation action + verifier. The action records which fibers it
/// "recovered"; the verifier confirms the targeted fiber was recovered.
const Recoverer = struct {
    recovered: std.AutoHashMap(u64, void),

    fn action(ctx: ?*anyopaque, request: fx.RemediationRequest) bool {
        const self: *Recoverer = @ptrCast(@alignCast(ctx.?));
        self.recovered.put(request.target_fiber_id.?, {}) catch return false;
        return true;
    }
    fn verify(ctx: ?*anyopaque, request: fx.RemediationRequest) bool {
        const self: *Recoverer = @ptrCast(@alignCast(ctx.?));
        return self.recovered.contains(request.target_fiber_id.?);
    }
};

const PassResult = struct { derived: usize, applied: usize, declined: usize };

fn runPass(allocator: std.mem.Allocator, gate_on: bool) !PassResult {
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    // Two hung fibers in the graph.
    try recordHungFiber(&store, 1);
    try recordHungFiber(&store, 2);

    var rec = Recoverer{ .recovered = std.AutoHashMap(u64, void).init(allocator) };
    defer rec.recovered.deinit();

    var engine = fx.PolicyEngine{};
    if (gate_on) engine = engine.withApplyEnabled(true).withKindPolicy(.interrupt, .auto_approve);

    const loop = fx.RemediationLoop{
        .engine = engine,
        .action = Recoverer.action,
        .verify = Recoverer.verify,
        .action_context = &rec,
        .verify_context = &rec,
    };

    const summary = try loop.runOnce(allocator, &store);
    return .{ .derived = summary.requests_derived, .applied = summary.applied, .declined = summary.declined };
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Pass 1 — default record-only posture: the loop detects + proposes but the
    // gate is off, so nothing executes.
    const off = try runPass(allocator, false);
    std.debug.print("gate OFF: derived={d} applied={d} declined={d}\n", .{ off.derived, off.applied, off.declined });

    // Pass 2 — operator enabled interrupt: the loop now recovers the hung fibers
    // and verifies each fix.
    const on = try runPass(allocator, true);
    std.debug.print("gate ON:  derived={d} applied={d} declined={d}\n", .{ on.derived, on.applied, on.declined });
}

test "self-improving loop example: gate governs execution end-to-end" {
    const off = try runPass(std.testing.allocator, false);
    try std.testing.expectEqual(@as(usize, 2), off.derived);
    try std.testing.expectEqual(@as(usize, 0), off.applied);
    try std.testing.expectEqual(@as(usize, 2), off.declined);

    const on = try runPass(std.testing.allocator, true);
    try std.testing.expectEqual(@as(usize, 2), on.derived);
    try std.testing.expectEqual(@as(usize, 2), on.applied);
    try std.testing.expectEqual(@as(usize, 0), on.declined);
}
