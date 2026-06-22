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
    fn verify(ctx: ?*anyopaque, request: fx.RemediationRequest) bool {
        _ = request;
        const self: *LoopContext = @ptrCast(@alignCast(ctx.?));
        var snap = self.after_store.snapshot(self.allocator) catch return false;
        defer snap.deinit();
        // OOM → "not equivalent" is the CONSERVATIVE direction: under memory
        // pressure a genuine fix is reported applied_unverified rather than
        // over-claiming applied=true. The verifier never errs toward applying.
        return fx.causalStructurallyEquivalent(self.allocator, self.good_events, snap.events) catch false;
    }
};

fn appliedStatus(snap: *fx.CausalSnapshot) ?[]const u8 {
    for (snap.events) |e| if (e.kind == .remediation_applied) return e.status;
    return null;
}

/// Build a scenario with a hung fiber (suspended, never resumed) so the H4 hang
/// detector produces a `fiber_suspended_without_resume` finding.
fn recordHungFiber(store: *fx.CausalStore, fiber_id: u64) !void {
    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const rs = try store.record(.{ .kind = .run_started, .run_id = run_id, .status = "started" });
    const opened = try store.record(.{ .kind = .scope_opened, .run_id = run_id, .scope_id = scope_id, .parent_id = rs, .status = "opened" });
    const forked = try store.record(.{ .kind = .fiber_forked, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = opened, .status = "pending" });
    const started = try store.record(.{ .kind = .fiber_started, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = forked, .status = "running" });
    _ = try store.record(.{ .kind = .fiber_suspended, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = started, .status = "pending" });
    // No fiber_resumed / fiber_joined — the fiber is hung.
}

test "M8.1 autonomous: a remediation request is DERIVED from a causal-graph finding (no human names the fiber)" {
    const allocator = std.testing.allocator;
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    try recordHungFiber(&store, 17);

    // The agent reads findings out of the causal graph — it is not told which
    // fiber is hung.
    var findings = try store.findings(allocator);
    defer findings.deinit();

    var derived: ?fx.RemediationRequest = null;
    for (findings.items) |f| {
        if (fx.remediationFromFinding(f)) |request| derived = request;
    }

    // A request was derived, targeting the hung fiber, with kind=interrupt.
    try std.testing.expect(derived != null);
    try std.testing.expectEqual(fx.RemediationKind.interrupt, derived.?.kind);
    try std.testing.expectEqual(@as(?u64, 17), derived.?.target_fiber_id);
}

test "M8.1 autonomous: findings with no safe auto-remediation derive no request" {
    // A scope-less assertion finding etc. should not auto-propose an action.
    const allocator = std.testing.allocator;
    const finding = fx.CausalFinding{ .kind = .retry_budget_exhausted, .event_id = 1, .fiber_id = 9 };
    try std.testing.expect(fx.remediationFromFinding(finding) == null);
    _ = allocator;
}

// ── M8.1 loop runner ──

/// An action+verify pair for the loop: it "fixes" each targeted fiber by
/// recording its id, and verifies by checking the id was recorded. Shared
/// context; action runs before verify within each apply().
const LoopRunnerCtx = struct {
    fixed: std.AutoHashMap(u64, void),
    fail_action: bool = false,
    fail_verify: bool = false,

    fn action(ctx: ?*anyopaque, request: fx.RemediationRequest) bool {
        const self: *LoopRunnerCtx = @ptrCast(@alignCast(ctx.?));
        if (self.fail_action) return false;
        self.fixed.put(request.target_fiber_id.?, {}) catch return false;
        return true;
    }
    fn verify(ctx: ?*anyopaque, request: fx.RemediationRequest) bool {
        const self: *LoopRunnerCtx = @ptrCast(@alignCast(ctx.?));
        if (self.fail_verify) return false;
        return self.fixed.contains(request.target_fiber_id.?);
    }
};

test "M8.1 loop runner: two hung fibers, gate ON → both detected, remediated, verified" {
    const allocator = std.testing.allocator;
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    try recordHungFiber(&store, 1);
    try recordHungFiber(&store, 2);

    var ctx = LoopRunnerCtx{ .fixed = std.AutoHashMap(u64, void).init(allocator) };
    defer ctx.fixed.deinit();

    const loop = fx.RemediationLoop{
        .engine = (fx.PolicyEngine{}).withApplyEnabled(true).withKindPolicy(.interrupt, .auto_approve),
        .action = LoopRunnerCtx.action,
        .verify = LoopRunnerCtx.verify,
        .action_context = &ctx,
        .verify_context = &ctx,
    };

    const summary = try loop.runOnce(allocator, &store);

    try std.testing.expectEqual(@as(usize, 2), summary.requests_derived);
    try std.testing.expectEqual(@as(usize, 2), summary.applied);
    try std.testing.expectEqual(@as(usize, 0), summary.declined);
    // Both fibers were actually targeted.
    try std.testing.expect(ctx.fixed.contains(1));
    try std.testing.expect(ctx.fixed.contains(2));
}

test "M8.1 loop runner: gate OFF (default) → findings detected but ALL declined, nothing executes" {
    const allocator = std.testing.allocator;
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    try recordHungFiber(&store, 1);
    try recordHungFiber(&store, 2);

    var ctx = LoopRunnerCtx{ .fixed = std.AutoHashMap(u64, void).init(allocator) };
    defer ctx.fixed.deinit();

    const loop = fx.RemediationLoop{
        .engine = fx.PolicyEngine{}, // gate OFF
        .action = LoopRunnerCtx.action,
        .verify = LoopRunnerCtx.verify,
        .action_context = &ctx,
        .verify_context = &ctx,
    };

    const summary = try loop.runOnce(allocator, &store);

    try std.testing.expectEqual(@as(usize, 2), summary.requests_derived);
    try std.testing.expectEqual(@as(usize, 0), summary.applied);
    try std.testing.expectEqual(@as(usize, 2), summary.declined);
    // The record-only posture means NO fiber was touched.
    try std.testing.expectEqual(@as(usize, 0), ctx.fixed.count());
}

test "M8.1 loop runner: verify-false → applied_unverified (the loop refuses to claim unproven fixes)" {
    const allocator = std.testing.allocator;
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    try recordHungFiber(&store, 1);

    var ctx = LoopRunnerCtx{ .fixed = std.AutoHashMap(u64, void).init(allocator), .fail_verify = true };
    defer ctx.fixed.deinit();

    const loop = fx.RemediationLoop{
        .engine = (fx.PolicyEngine{}).withApplyEnabled(true).withKindPolicy(.interrupt, .auto_approve),
        .action = LoopRunnerCtx.action,
        .verify = LoopRunnerCtx.verify,
        .action_context = &ctx,
        .verify_context = &ctx,
    };

    const summary = try loop.runOnce(allocator, &store);
    try std.testing.expectEqual(@as(usize, 1), summary.requests_derived);
    try std.testing.expectEqual(@as(usize, 0), summary.applied);
    try std.testing.expectEqual(@as(usize, 1), summary.applied_unverified);
}

test "M14.5 closed loop: a GENUINE fix is structurally proven → applied=true earned" {
    const allocator = std.testing.allocator;

    // The known-good reference shape (what a healthy run looks like).
    // good_snap MUST outlive boundary.apply(...): LoopContext.good_events borrows
    // good_snap.events, which the verifier reads during apply(). Safe here via
    // LIFO defer ordering (apply runs before any defer fires).
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
