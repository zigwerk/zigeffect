//! M8.3 + M14.1 — engine-side remediation policy tests.

const std = @import("std");
const fx = @import("zigeffect");

fn req(kind: fx.RemediationKind) fx.RemediationRequest {
    return .{ .kind = kind, .target_fiber_id = 7, .reason = "test" };
}

test "default policy: every kind is record-only (needs_human_review)" {
    const engine = fx.PolicyEngine{}; // master gate OFF, all kinds default
    inline for (.{ .retry, .interrupt, .replace_provider, .replay_scenario }) |kind| {
        const d = engine.decide(req(kind));
        try std.testing.expectEqual(fx.PolicyDecision.needs_human_review, d.decision);
        try std.testing.expectEqual(kind, d.kind);
    }
}

test "always_reject overrides the master gate (explicit deny even when apply disabled)" {
    const engine = (fx.PolicyEngine{})
        .withKindPolicy(.interrupt, .always_reject);
    const d = engine.decide(req(.interrupt));
    try std.testing.expectEqual(fx.PolicyDecision.reject, d.decision);
}

test "gate ON + auto_approve → approve" {
    const engine = (fx.PolicyEngine{})
        .withApplyEnabled(true)
        .withKindPolicy(.retry, .auto_approve);
    const d = engine.decide(req(.retry));
    try std.testing.expectEqual(fx.PolicyDecision.approve, d.decision);
}

test "gate ON + needs_human_review (unconfigured kind) → needs_human_review" {
    const engine = (fx.PolicyEngine{})
        .withApplyEnabled(true)
        .withKindPolicy(.retry, .auto_approve); // only retry opted in
    // interrupt was never opted in → still needs review even with gate on.
    const d = engine.decide(req(.interrupt));
    try std.testing.expectEqual(fx.PolicyDecision.needs_human_review, d.decision);
}

test "SAFETY: master gate OFF dominates an auto_approve kind (record-only is enforced)" {
    // An operator opted `retry` into auto_approve, but forgot to flip the
    // master gate. The engine MUST still refuse to auto-approve — this is the
    // load-bearing Working-Default-#1 safety property.
    const engine = (fx.PolicyEngine{})
        .withKindPolicy(.retry, .auto_approve); // apply_enabled stays false
    const d = engine.decide(req(.retry));
    try std.testing.expectEqual(fx.PolicyDecision.needs_human_review, d.decision);
}

test "always_reject still rejects even with the master gate ON" {
    const engine = (fx.PolicyEngine{})
        .withApplyEnabled(true)
        .withKindPolicy(.replace_provider, .always_reject);
    const d = engine.decide(req(.replace_provider));
    try std.testing.expectEqual(fx.PolicyDecision.reject, d.decision);
}

test "decideAndRecord records remediation_requested → remediation_decided with the verdict + cause edge" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const engine = (fx.PolicyEngine{}); // default → needs_human_review
    const decision = engine.decideAndRecord(&store, .{
        .kind = .interrupt,
        .target_fiber_id = 42,
        .reason = "fiber wedged on a 10s sleep",
    });
    try std.testing.expectEqual(fx.PolicyDecision.needs_human_review, decision.decision);

    var snap = try store.snapshot(std.testing.allocator);
    defer snap.deinit();

    var requested: ?fx.CausalEvent = null;
    var decided: ?fx.CausalEvent = null;
    for (snap.events) |e| {
        if (e.kind == .remediation_requested) requested = e;
        if (e.kind == .remediation_decided) decided = e;
    }
    try std.testing.expect(requested != null);
    try std.testing.expect(decided != null);
    // The load-bearing cause edge.
    try std.testing.expectEqual(requested.?.id, decided.?.cause_event_id.?);
    // The decision's verdict is the recorded status.
    try std.testing.expectEqualStrings("needs_human_review", decided.?.status);
    // The remediation kind is the type_name on both events.
    try std.testing.expectEqualStrings("interrupt", requested.?.type_name);
    // The targeted fiber id is carried through.
    try std.testing.expectEqual(@as(?u64, 42), decided.?.fiber_id);
}

// ── M8.13 apply boundary ──

/// Injectable action/verifier that record whether they were called and return
/// a configurable result.
const Probe = struct {
    action_called: bool = false,
    verify_called: bool = false,
    action_result: bool = true,
    verify_result: bool = true,

    fn action(ctx: ?*anyopaque, request: fx.RemediationRequest) bool {
        const self: *Probe = @ptrCast(@alignCast(ctx.?));
        _ = request;
        self.action_called = true;
        return self.action_result;
    }
    fn verify(ctx: ?*anyopaque) bool {
        const self: *Probe = @ptrCast(@alignCast(ctx.?));
        self.verify_called = true;
        return self.verify_result;
    }
};

fn boundaryWith(engine: fx.PolicyEngine, probe: *Probe) fx.ApplyBoundary {
    return .{
        .engine = engine,
        .action = Probe.action,
        .verify = Probe.verify,
        .action_context = probe,
        .verify_context = probe,
    };
}

fn appliedEventStatus(snap: *fx.CausalSnapshot) ?[]const u8 {
    for (snap.events) |e| if (e.kind == .remediation_applied) return e.status;
    return null;
}

test "apply boundary: declined (gate off) runs NO action and records not_applied" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var probe = Probe{};
    const boundary = boundaryWith(fx.PolicyEngine{}, &probe); // gate OFF

    const result = boundary.apply(&store, req(.interrupt));

    try std.testing.expectEqual(fx.ApplyOutcome.declined, result.outcome);
    try std.testing.expect(!result.isApplied());
    // The action and verifier were never invoked — record-only is enforced.
    try std.testing.expect(!probe.action_called);
    try std.testing.expect(!probe.verify_called);

    var snap = try store.snapshot(std.testing.allocator);
    defer snap.deinit();
    try std.testing.expectEqualStrings("not_applied", appliedEventStatus(&snap).?);
}

test "apply boundary: approved + action ok + verify true → applied=true" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var probe = Probe{ .action_result = true, .verify_result = true };
    const engine = (fx.PolicyEngine{}).withApplyEnabled(true).withKindPolicy(.interrupt, .auto_approve);
    const boundary = boundaryWith(engine, &probe);

    const result = boundary.apply(&store, req(.interrupt));

    try std.testing.expectEqual(fx.ApplyOutcome.applied, result.outcome);
    try std.testing.expect(result.isApplied());
    try std.testing.expect(probe.action_called);
    try std.testing.expect(probe.verify_called);

    var snap = try store.snapshot(std.testing.allocator);
    defer snap.deinit();
    try std.testing.expectEqualStrings("applied", appliedEventStatus(&snap).?);
}

test "SAFETY: approved + action ok but verify FALSE → applied_unverified (applied=true NOT earned)" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var probe = Probe{ .action_result = true, .verify_result = false }; // fix not proven
    const engine = (fx.PolicyEngine{}).withApplyEnabled(true).withKindPolicy(.retry, .auto_approve);
    const boundary = boundaryWith(engine, &probe);

    const result = boundary.apply(&store, req(.retry));

    // The action ran, but the fix wasn't structurally proven — applied=true is
    // NOT earned. This is the load-bearing property of the apply boundary.
    try std.testing.expectEqual(fx.ApplyOutcome.applied_unverified, result.outcome);
    try std.testing.expect(!result.isApplied());
    try std.testing.expect(probe.action_called);
    try std.testing.expect(probe.verify_called);

    var snap = try store.snapshot(std.testing.allocator);
    defer snap.deinit();
    try std.testing.expectEqualStrings("not_applied", appliedEventStatus(&snap).?);
}

test "apply boundary: approved but action fails → action_failed, verify never runs" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var probe = Probe{ .action_result = false }; // action itself fails
    const engine = (fx.PolicyEngine{}).withApplyEnabled(true).withKindPolicy(.interrupt, .auto_approve);
    const boundary = boundaryWith(engine, &probe);

    const result = boundary.apply(&store, req(.interrupt));

    try std.testing.expectEqual(fx.ApplyOutcome.action_failed, result.outcome);
    try std.testing.expect(!result.isApplied());
    try std.testing.expect(probe.action_called);
    // Verification is skipped when the action itself failed.
    try std.testing.expect(!probe.verify_called);

    var snap = try store.snapshot(std.testing.allocator);
    defer snap.deinit();
    try std.testing.expectEqualStrings("not_applied", appliedEventStatus(&snap).?);
}

test "apply boundary records the full remediation chain: requested → decided → applied" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var probe = Probe{ .action_result = true, .verify_result = true };
    const engine = (fx.PolicyEngine{}).withApplyEnabled(true).withKindPolicy(.replay_scenario, .auto_approve);
    const boundary = boundaryWith(engine, &probe);

    _ = boundary.apply(&store, req(.replay_scenario));

    var snap = try store.snapshot(std.testing.allocator);
    defer snap.deinit();

    var requested: ?fx.CausalEvent = null;
    var decided: ?fx.CausalEvent = null;
    var applied: ?fx.CausalEvent = null;
    for (snap.events) |e| {
        if (e.kind == .remediation_requested) requested = e;
        if (e.kind == .remediation_decided) decided = e;
        if (e.kind == .remediation_applied) applied = e;
    }
    try std.testing.expect(requested != null and decided != null and applied != null);
    // The chain: applied.cause -> decided.cause -> requested.
    try std.testing.expectEqual(requested.?.id, decided.?.cause_event_id.?);
    try std.testing.expectEqual(decided.?.id, applied.?.cause_event_id.?);
}

test "per-kind policies are independent (one auto_approve doesn't leak to siblings)" {
    const engine = (fx.PolicyEngine{})
        .withApplyEnabled(true)
        .withKindPolicy(.replay_scenario, .auto_approve);
    try std.testing.expectEqual(fx.PolicyDecision.approve, engine.decide(req(.replay_scenario)).decision);
    // The other three remain at the default needs_human_review.
    try std.testing.expectEqual(fx.PolicyDecision.needs_human_review, engine.decide(req(.retry)).decision);
    try std.testing.expectEqual(fx.PolicyDecision.needs_human_review, engine.decide(req(.interrupt)).decision);
    try std.testing.expectEqual(fx.PolicyDecision.needs_human_review, engine.decide(req(.replace_provider)).decision);
}
