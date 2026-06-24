const std = @import("std");
const fx = @import("zigeffect");

test "live command executor applies approved command through intervention policy" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const policy = (fx.AgentInterventionPolicy{})
        .withApplyEnabled(true)
        .withKindPolicy(.interrupt_fiber, .auto_approve);

    const result = try fx.applyCausalLiveCommand(&store, policy, .{
        .command_id = "cmd-1",
        .command_kind = "interrupt_fiber",
        .actor = "agent",
        .run_id = 7,
        .scope_id = 8,
        .fiber_id = 9,
        .reason = "stop hung fiber",
        .redacted_detail = "token=[REDACTED]",
    });

    try std.testing.expect(result.known_kind);
    try std.testing.expect(result.intervention != null);
    try std.testing.expectEqual(fx.AgentInterventionDecisionKind.approve, result.decision);
    try std.testing.expect(result.applied);
    try std.testing.expectEqualStrings("cmd-1", result.command_id);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 4), snapshot.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.fiber_interrupted, snapshot.events[3].kind);
    try std.testing.expectEqual(@as(?u64, 9), snapshot.events[3].fiber_id);
}

test "live command executor rejects unknown commands with alert evidence" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const result = try fx.applyCausalLiveCommand(&store, .{}, .{
        .command_id = "cmd-unknown",
        .command_kind = "rotate_database_root_password",
        .actor = "agent",
        .reason = "not in the bounded command set",
        .redacted_detail = "password=[REDACTED]",
    });

    try std.testing.expect(!result.known_kind);
    try std.testing.expectEqual(fx.AgentInterventionDecisionKind.reject, result.decision);
    try std.testing.expect(!result.applied);
    try std.testing.expect(result.alert_event_id != null);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.alert_emitted, snapshot.events[0].kind);
    try std.testing.expectEqualStrings("unknown-live-command", snapshot.events[0].type_name);
    try std.testing.expect(std.mem.indexOf(u8, snapshot.events[0].redacted_detail, "[REDACTED]") == null);
    try std.testing.expect(std.mem.indexOf(u8, snapshot.events[0].redacted_detail, fx.causal_redaction_marker) != null);
}

test "live command tap batch processes approved and rejected commands" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const policy = (fx.AgentInterventionPolicy{})
        .withApplyEnabled(true)
        .withKindPolicy(.interrupt_fiber, .auto_approve);

    const result = try fx.runCausalLiveCommandTapBatch(&store, policy, &.{
        .{
            .sequence = 1,
            .request = .{
                .command_id = "cmd-1",
                .command_kind = "interrupt_fiber",
                .actor = "agent",
                .fiber_id = 42,
                .reason = "interrupt hung fiber",
            },
        },
        .{
            .sequence = 2,
            .request = .{
                .command_id = "cmd-2",
                .command_kind = "delete_cluster",
                .actor = "agent",
                .reason = "not allowed",
            },
        },
    });

    try std.testing.expectEqual(@as(usize, 2), result.processed);
    try std.testing.expectEqual(@as(usize, 1), result.applied);
    try std.testing.expectEqual(@as(usize, 1), result.rejected);
    try std.testing.expectEqual(@as(usize, 0), result.needs_human_review);
    try std.testing.expectEqual(@as(?u64, 2), result.last_sequence);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 5), snapshot.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.fiber_interrupted, snapshot.events[3].kind);
    try std.testing.expectEqual(fx.CausalEventKind.alert_emitted, snapshot.events[4].kind);
}
