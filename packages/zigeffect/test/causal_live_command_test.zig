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

test "live command polled batch carries inbox cursor while applying commands" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const policy = (fx.AgentInterventionPolicy{})
        .withApplyEnabled(true)
        .withKindPolicy(.fire_timer, .auto_approve);

    const result = try fx.runCausalLiveCommandPolledBatch(&store, policy, .{
        .next_after = 12,
        .envelopes = &.{
            .{
                .sequence = 12,
                .request = .{
                    .command_id = "cmd-12",
                    .command_kind = "fire_timer",
                    .actor = "agent",
                    .run_id = 1,
                    .schedule_id = 99,
                    .reason = "wake timer",
                },
            },
        },
    });

    try std.testing.expectEqual(@as(u64, 12), result.next_after);
    try std.testing.expectEqual(@as(usize, 1), result.tap.processed);
    try std.testing.expectEqual(@as(usize, 1), result.tap.applied);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 4), snapshot.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.timer_fired, snapshot.events[3].kind);
}

const FakeCommandPoller = struct {
    calls: usize = 0,
    seen_after: [3]u64 = .{ 0, 0, 0 },
    first: [1]fx.CausalLiveCommandEnvelope = .{.{
        .sequence = 1,
        .request = .{
            .command_id = "cmd-1",
            .command_kind = "fire_timer",
            .actor = "agent",
            .run_id = 1,
            .schedule_id = 10,
            .reason = "wake first timer",
        },
    }},
    second: [1]fx.CausalLiveCommandEnvelope = .{.{
        .sequence = 2,
        .request = .{
            .command_id = "cmd-2",
            .command_kind = "fire_timer",
            .actor = "agent",
            .run_id = 1,
            .schedule_id = 11,
            .reason = "wake second timer",
        },
    }},

    fn poll(raw: ?*anyopaque, after: u64) anyerror!fx.CausalLiveCommandPollBatch {
        const self: *FakeCommandPoller = @ptrCast(@alignCast(raw.?));
        self.seen_after[self.calls] = after;
        self.calls += 1;
        return switch (self.calls) {
            1 => .{ .next_after = 1, .envelopes = self.first[0..] },
            2 => .{ .next_after = 2, .envelopes = self.second[0..] },
            else => .{ .next_after = after, .envelopes = &.{} },
        };
    }
};

test "live command poll loop processes bounded batches until empty" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const policy = (fx.AgentInterventionPolicy{})
        .withApplyEnabled(true)
        .withKindPolicy(.fire_timer, .auto_approve);
    var poller_state = FakeCommandPoller{};

    const result = try fx.runCausalLiveCommandPollLoop(&store, policy, .{
        .state = &poller_state,
        .poll = FakeCommandPoller.poll,
    }, .{
        .start_after = 0,
        .max_polls = 5,
    });

    try std.testing.expectEqual(@as(usize, 3), result.polls);
    try std.testing.expectEqual(@as(u64, 2), result.next_after);
    try std.testing.expectEqual(@as(usize, 2), result.tap.processed);
    try std.testing.expectEqual(@as(usize, 2), result.tap.applied);
    try std.testing.expectEqual(@as(u64, 0), poller_state.seen_after[0]);
    try std.testing.expectEqual(@as(u64, 1), poller_state.seen_after[1]);
    try std.testing.expectEqual(@as(u64, 2), poller_state.seen_after[2]);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 8), snapshot.events.len);
}
