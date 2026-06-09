const std = @import("std");
const fx = @import("zigeffect");

test "backend constructors expose async operation capabilities" {
    const deterministic = fx.deterministicBackend();
    try std.testing.expectEqual(fx.BackendKind.deterministic, deterministic.kind);
    try std.testing.expect(!deterministic.can_suspend);
    try std.testing.expect(!deterministic.can_wake);
    try std.testing.expect(!deterministic.can_schedule_timers);
    try std.testing.expect(!deterministic.can_interrupt);
    try std.testing.expect(!deterministic.can_durable_suspend);

    const durable = fx.durableLocalBackend();
    try std.testing.expectEqual(fx.BackendKind.durable_local, durable.kind);
    try std.testing.expect(durable.can_suspend);
    try std.testing.expect(durable.can_wake);
    try std.testing.expect(durable.can_schedule_timers);
    try std.testing.expect(durable.can_interrupt);
    try std.testing.expect(durable.can_durable_suspend);
    try std.testing.expect(!durable.can_interrupt_blocking_io);

    const async_backend = fx.asyncLocalBackend();
    try std.testing.expectEqual(fx.BackendKind.async_local, async_backend.kind);
    try std.testing.expect(async_backend.can_suspend);
    try std.testing.expect(async_backend.can_wake);
    try std.testing.expect(async_backend.can_schedule_timers);
    try std.testing.expect(async_backend.can_interrupt);
    try std.testing.expect(!async_backend.can_durable_suspend);

    const clustered = fx.clusteredBackend();
    try std.testing.expectEqual(fx.BackendKind.clustered, clustered.kind);
    try std.testing.expect(clustered.can_wake);
    try std.testing.expect(clustered.can_schedule_timers);
    try std.testing.expect(clustered.can_interrupt);
    try std.testing.expect(clustered.can_durable_suspend);
}

test "deterministic unsupported async backend rejects suspend wake timer and interrupt" {
    var state = fx.UnsupportedAsyncBackendState.init(fx.deterministicBackend());
    const backend = state.backend();

    try std.testing.expectEqual(fx.BackendKind.deterministic, backend.capabilities.kind);
    try std.testing.expectError(error.UnsupportedBackendCapability, backend.suspendRuntime(.{
        .suspension = .{ .kind = .timer, .id = 1, .label = "wake" },
        .workflow_id = 7,
        .execution_id = 8,
        .reason = "sleep",
    }));
    try std.testing.expectError(error.UnsupportedBackendCapability, backend.wake(.{
        .suspension_id = 1,
        .reason = "timer fired",
    }));
    try std.testing.expectError(error.UnsupportedBackendCapability, backend.scheduleTimer(.{
        .suspension = .{ .kind = .timer, .id = 1, .label = "wake" },
        .due_time_ms = 250,
        .now_ms = 100,
    }));
    try std.testing.expectError(error.UnsupportedBackendCapability, backend.interrupt(.{
        .target_id = 99,
        .reason = "operator",
    }));
}
