//! M14.5 — the closed agent loop, end-to-end, with the REAL structural verifier.
//!
//! Demonstrates the original vision's headline executed by the runtime, not the
//! human: an injected failure → an agent proposes a bounded remediation → the
//! policy engine approves it (under an explicitly operator-enabled posture) →
//! the apply boundary executes the action → the runtime VERIFIES the fix by
//! comparing the re-captured causal trace to a known-good shape via the real
//! `causalStructurallyEquivalent` → and earns `applied=true` only when the proof
//! holds.
//!
//! Two cases prove the loop DISCRIMINATES rather than rubber-stamps:
//!  - a genuine fix (post-action trace matches the good shape) → applied=true,
//!  - a bogus "fix" (post-action trace still broken) → applied_unverified,
//!    status "not_applied" — the runtime refuses to claim a fix it can't prove.

const std = @import("std");
const fx = @import("zigeffect");

/// Capture a "healthy" run: fiber forks, starts, joins successfully.
fn recordHealthyRun(store: *fx.CausalStore) !void {
    const run_id = store.nextRunId();
    const rs = try store.record(.{ .kind = .run_started, .run_id = run_id, .status = "started", .label = "subject" });
    const forked = try store.record(.{ .kind = .fiber_forked, .run_id = run_id, .fiber_id = 1, .parent_id = rs, .status = "pending" });
    const started = try store.record(.{ .kind = .fiber_started, .run_id = run_id, .fiber_id = 1, .parent_id = forked, .status = "running" });
    _ = try store.record(.{ .kind = .fiber_joined, .run_id = run_id, .fiber_id = 1, .parent_id = started, .status = "success" });
    _ = try store.record(.{ .kind = .run_completed, .run_id = run_id, .parent_id = rs, .status = "success" });
}

/// Capture a "still broken" run: the fiber is interrupted and the run fails.
fn recordBrokenRun(store: *fx.CausalStore) !void {
    const run_id = store.nextRunId();
    const rs = try store.record(.{ .kind = .run_started, .run_id = run_id, .status = "started", .label = "subject" });
    const forked = try store.record(.{ .kind = .fiber_forked, .run_id = run_id, .fiber_id = 1, .parent_id = rs, .status = "pending" });
    const started = try store.record(.{ .kind = .fiber_started, .run_id = run_id, .fiber_id = 1, .parent_id = forked, .status = "running" });
    _ = try store.record(.{ .kind = .fiber_interrupted, .run_id = run_id, .fiber_id = 1, .parent_id = started, .status = "interrupted" });
    _ = try store.record(.{ .kind = .exit_recorded, .run_id = run_id, .parent_id = rs, .status = "failure" });
}

const LoopContext = struct {
    allocator: std.mem.Allocator,
    /// Where the post-remediation ("after") run is captured.
    after_store: *fx.CausalStore,
    /// The known-good reference trace the verifier compares against.
    good_events: []const fx.CausalEvent,
    /// Whether the agent's action is a genuine fix (records a healthy run) or a
    /// bogus one (records a still-broken run).
    genuine_fix: bool,
    action_ran: bool = false,

    /// The injected ACTION: perform the remediation. Here it re-runs the subject
    /// in its post-fix state, capturing the resulting trace into `after_store`.
    fn action(ctx: ?*anyopaque, request: fx.RemediationRequest) bool {
        const self: *LoopContext = @ptrCast(@alignCast(ctx.?));
        _ = request;
        self.action_ran = true;
        if (self.genuine_fix) {
            recordHealthyRun(self.after_store) catch return false;
        } else {
            recordBrokenRun(self.after_store) catch return false;
        }
        return true;
    }

    /// The injected VERIFIER: re-capture the post-action trace and prove the fix
    /// by structural equivalence to the known-good shape. This is the runtime
    /// executing the vision's "tell me whether the change improved the causal
    /// structure" — using the real comparator, not a flag.
    fn verify(ctx: ?*anyopaque) bool {
        const self: *LoopContext = @ptrCast(@alignCast(ctx.?));
        var snap = self.after_store.snapshot(self.allocator) catch return false;
        defer snap.deinit();
        return fx.causalStructurallyEquivalent(self.allocator, self.good_events, snap.events) catch false;
    }
};

fn appliedStatus(snap: *fx.CausalSnapshot) ?[]const u8 {
    for (snap.events) |e| if (e.kind == .remediation_applied) return e.status;
    return null;
}

test "M14.5 closed loop: a GENUINE fix is structurally proven → applied=true earned" {
    const allocator = std.testing.allocator;

    // The known-good reference shape (what a healthy run looks like).
    var good_store = fx.CausalStore.init(allocator);
    defer good_store.deinit();
    try recordHealthyRun(&good_store);
    var good_snap = try good_store.snapshot(allocator);
    defer good_snap.deinit();

    // The loop's audit store (where requested→decided→applied are recorded).
    var audit_store = fx.CausalStore.init(allocator);
    defer audit_store.deinit();

    // Where the post-remediation run is captured.
    var after_store = fx.CausalStore.init(allocator);
    defer after_store.deinit();

    var ctx = LoopContext{
        .allocator = allocator,
        .after_store = &after_store,
        .good_events = good_snap.events,
        .genuine_fix = true,
    };

    // The agent's proposal + the operator-enabled posture (gate ON, retry opted in).
    const engine = (fx.PolicyEngine{}).withApplyEnabled(true).withKindPolicy(.retry, .auto_approve);
    const boundary = fx.ApplyBoundary{
        .engine = engine,
        .action = LoopContext.action,
        .verify = LoopContext.verify,
        .action_context = &ctx,
        .verify_context = &ctx,
    };

    const result = boundary.apply(&audit_store, .{ .kind = .retry, .target_fiber_id = 1, .reason = "fiber failed; retry under fix" });

    // The loop closed: the runtime applied the fix AND proved it.
    try std.testing.expect(ctx.action_ran);
    try std.testing.expectEqual(fx.ApplyOutcome.applied, result.outcome);
    try std.testing.expect(result.isApplied());

    var audit_snap = try audit_store.snapshot(allocator);
    defer audit_snap.deinit();
    try std.testing.expectEqualStrings("applied", appliedStatus(&audit_snap).?);
}

test "M14.5 closed loop: a BOGUS fix fails structural proof → applied_unverified (runtime refuses to claim it)" {
    const allocator = std.testing.allocator;

    var good_store = fx.CausalStore.init(allocator);
    defer good_store.deinit();
    try recordHealthyRun(&good_store);
    var good_snap = try good_store.snapshot(allocator);
    defer good_snap.deinit();

    var audit_store = fx.CausalStore.init(allocator);
    defer audit_store.deinit();
    var after_store = fx.CausalStore.init(allocator);
    defer after_store.deinit();

    var ctx = LoopContext{
        .allocator = allocator,
        .after_store = &after_store,
        .good_events = good_snap.events,
        .genuine_fix = false, // the "fix" leaves the subject broken
    };

    const engine = (fx.PolicyEngine{}).withApplyEnabled(true).withKindPolicy(.retry, .auto_approve);
    const boundary = fx.ApplyBoundary{
        .engine = engine,
        .action = LoopContext.action,
        .verify = LoopContext.verify,
        .action_context = &ctx,
        .verify_context = &ctx,
    };

    const result = boundary.apply(&audit_store, .{ .kind = .retry, .target_fiber_id = 1, .reason = "fiber failed; retry under (bad) fix" });

    // The action ran, but the re-captured trace did NOT match the healthy shape,
    // so the runtime refuses to earn applied=true. This is the whole point: the
    // verification is real, structural, and discriminating.
    try std.testing.expect(ctx.action_ran);
    try std.testing.expectEqual(fx.ApplyOutcome.applied_unverified, result.outcome);
    try std.testing.expect(!result.isApplied());

    var audit_snap = try audit_store.snapshot(allocator);
    defer audit_snap.deinit();
    try std.testing.expectEqualStrings("not_applied", appliedStatus(&audit_snap).?);
}
