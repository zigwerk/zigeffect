const std = @import("std");
const fx = @import("zigeffect");

const baseline = [_]fx.CausalEvent{
    .{ .id = 1, .kind = .run_started, .run_id = 1, .status = "started" },
    .{ .id = 2, .kind = .fiber_suspended, .run_id = 1, .fiber_id = 9, .status = "suspended", .label = "await io" },
};

test "agent eval passes when intervention improves findings and satisfies invariants" {
    const policy = (fx.AgentInterventionPolicy{})
        .withApplyEnabled(true)
        .withKindPolicy(.interrupt_fiber, .auto_approve);
    const invariants = fx.CausalInvariantBuilder.init().requireSuspendedFibersResolve();

    const result = try fx.runAgentEval(std.testing.allocator, .{
        .name = "interrupt hung fiber",
        .baseline = &baseline,
        .policy = policy,
        .request = .{
            .kind = .interrupt_fiber,
            .run_id = 1,
            .fiber_id = 9,
            .reason = "eval interrupt",
        },
        .invariants = invariants,
        .expect_improvement = true,
    });

    try std.testing.expect(result.passed);
    try std.testing.expect(result.counterfactual.improved);
    try std.testing.expectEqual(@as(usize, 1), result.diff_summary.resolved_findings);
    try std.testing.expectEqual(@as(usize, 0), result.invariant_violations);
}

test "agent eval fails when policy leaves the intervention record-only" {
    const invariants = fx.CausalInvariantBuilder.init().requireSuspendedFibersResolve();

    const result = try fx.runAgentEval(std.testing.allocator, .{
        .name = "denied interrupt",
        .baseline = &baseline,
        .policy = .{},
        .request = .{
            .kind = .interrupt_fiber,
            .run_id = 1,
            .fiber_id = 9,
            .reason = "eval interrupt",
        },
        .invariants = invariants,
        .expect_improvement = true,
    });

    try std.testing.expect(!result.passed);
    try std.testing.expect(!result.counterfactual.intervention.applied);
}

test "agent eval emits semantic diff artifact linked to remediation events" {
    const policy = (fx.AgentInterventionPolicy{})
        .withApplyEnabled(true)
        .withKindPolicy(.interrupt_fiber, .auto_approve);
    const invariants = fx.CausalInvariantBuilder.init().requireSuspendedFibersResolve();

    var artifact = try fx.runAgentEvalWithDiffArtifact(std.testing.allocator, .{
        .name = "interrupt hung fiber",
        .baseline = &baseline,
        .policy = policy,
        .request = .{
            .kind = .interrupt_fiber,
            .run_id = 1,
            .fiber_id = 9,
            .reason = "eval interrupt",
        },
        .invariants = invariants,
        .expect_improvement = true,
    }, "baseline", "after-interrupt");
    defer artifact.deinit();

    try std.testing.expect(artifact.result.passed);
    try std.testing.expect(std.mem.indexOf(u8, artifact.json, "\"schema\":\"zigeffect.causal.agent-eval-diff.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifact.json, "\"semantic_diff\":{\"schema\":\"zigeffect.causal.semantic-diff.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifact.json, "\"resolved_findings\":1") != null);

    var requested_buf: [64]u8 = undefined;
    const requested = try std.fmt.bufPrint(&requested_buf, "\"requested\":{d}", .{artifact.result.counterfactual.intervention.requested_event_id.?});
    try std.testing.expect(std.mem.indexOf(u8, artifact.json, requested) != null);
}
