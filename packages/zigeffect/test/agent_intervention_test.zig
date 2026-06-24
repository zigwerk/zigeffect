const std = @import("std");
const fx = @import("zigeffect");

test "agent intervention policy is record-only by default" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const result = try fx.applyAgentIntervention(&store, .{}, .{
        .kind = .interrupt_fiber,
        .run_id = 1,
        .fiber_id = 7,
        .reason = "hung fiber",
    });

    try std.testing.expectEqual(fx.AgentInterventionDecisionKind.needs_human_review, result.decision);
    try std.testing.expect(!result.applied);
    try std.testing.expect(result.applied_event_id == null);
    try std.testing.expect(result.effect_event_id == null);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 2), snapshot.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.remediation_requested, snapshot.events[0].kind);
    try std.testing.expectEqual(fx.CausalEventKind.remediation_decided, snapshot.events[1].kind);
    try std.testing.expectEqualStrings("needs_human_review", snapshot.events[1].status);
}

test "approved interrupt intervention records apply and fiber interruption facts" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const policy = (fx.AgentInterventionPolicy{})
        .withApplyEnabled(true)
        .withKindPolicy(.interrupt_fiber, .auto_approve);

    const result = try fx.applyAgentIntervention(&store, policy, .{
        .kind = .interrupt_fiber,
        .run_id = 1,
        .scope_id = 2,
        .fiber_id = 7,
        .reason = "hung fiber",
    });

    try std.testing.expectEqual(fx.AgentInterventionDecisionKind.approve, result.decision);
    try std.testing.expect(result.applied);
    try std.testing.expect(result.applied_event_id != null);
    try std.testing.expect(result.effect_event_id != null);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 4), snapshot.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.remediation_requested, snapshot.events[0].kind);
    try std.testing.expectEqual(fx.CausalEventKind.remediation_decided, snapshot.events[1].kind);
    try std.testing.expectEqual(fx.CausalEventKind.remediation_applied, snapshot.events[2].kind);
    try std.testing.expectEqual(fx.CausalEventKind.fiber_interrupted, snapshot.events[3].kind);
    try std.testing.expectEqual(@as(?u64, 7), snapshot.events[3].fiber_id);
    try std.testing.expectEqualStrings("interrupted", snapshot.events[3].status);
}
