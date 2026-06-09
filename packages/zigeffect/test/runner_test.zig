const std = @import("std");
const fx = @import("zigeffect");

test "runner public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "runner"));
    try std.testing.expect(@hasDecl(fx.cluster, "RunnerId"));
    try std.testing.expect(@hasDecl(fx.cluster, "MachineId"));
    try std.testing.expect(@hasDecl(fx.cluster, "RunnerAddress"));
    try std.testing.expect(@hasDecl(fx.cluster, "RunnerHealthState"));
    try std.testing.expect(@hasDecl(fx.cluster, "RunnerRegistration"));
    try std.testing.expect(@hasDecl(fx.cluster, "RunnerHeartbeat"));
    try std.testing.expect(@hasDecl(fx.cluster, "LocalRunnerRegistry"));
    try std.testing.expect(@hasDecl(fx.cluster, "LocalRunnerHealthInspector"));
    try std.testing.expect(@hasDecl(fx, "RunnerAddress"));
}

test "runner ids are stable machine-sensitive and process-sensitive" {
    const machine = fx.machineId("dev-machine");
    const same_machine = fx.machineId("dev-machine");
    const other_machine = fx.machineId("ci-machine");
    const runner = fx.runnerId(machine, "process-a");
    const same_runner = fx.runnerId(machine, "process-a");
    const other_process = fx.runnerId(machine, "process-b");
    const other_machine_runner = fx.runnerId(other_machine, "process-a");

    try std.testing.expectEqual(machine, same_machine);
    try std.testing.expect(machine != other_machine);
    try std.testing.expectEqual(runner, same_runner);
    try std.testing.expect(runner != other_process);
    try std.testing.expect(runner != other_machine_runner);

    const address = fx.runnerAddress("dev-machine", "process-a");
    try std.testing.expect(address.eql(.{ .machine_id = machine, .runner_id = runner }));
}

test "local runner registry persists startup registration and event" {
    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const address = fx.runnerAddress("machine-a", "runner-a");
    const snapshot = try registry.registerRunner(.{
        .address = address,
        .name = "runner-a",
        .started_at_ms = 1_000,
    });

    try std.testing.expectEqual(@as(usize, 1), registry.runnerCount());
    try std.testing.expectEqual(fx.RunnerHealthState.starting, snapshot.state);
    try std.testing.expectEqualStrings("runner-a", snapshot.name);
    try std.testing.expectEqual(@as(usize, 1), try registry.healthEventCount(address));

    const event = (try registry.lastHealthEvent(address)).?;
    try std.testing.expectEqual(@as(?fx.RunnerHealthState, null), event.previous_state);
    try std.testing.expectEqual(fx.RunnerHealthState.starting, event.next_state);
    try std.testing.expectEqual(fx.RunnerHealthReason.startup_registered, event.reason);
    try std.testing.expectEqual(@as(u64, 1_000), event.at_ms);

    try std.testing.expectError(error.DuplicateRunner, registry.registerRunner(.{
        .address = address,
        .name = "duplicate",
        .started_at_ms = 1_100,
    }));
}

test "runner heartbeat records are monotonic and transition to healthy" {
    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const address = fx.runnerAddress("machine-a", "runner-a");
    _ = try registry.registerRunner(.{ .address = address, .name = "runner-a", .started_at_ms = 1_000 });

    const snapshot = try registry.recordHeartbeat(.{
        .address = address,
        .sequence = 1,
        .observed_at_ms = 1_250,
    });

    try std.testing.expectEqual(fx.RunnerHealthState.healthy, snapshot.state);
    try std.testing.expectEqual(@as(usize, 1), try registry.heartbeatCount(address));
    try std.testing.expectEqual(@as(u64, 1_250), snapshot.last_heartbeat_at_ms.?);
    try std.testing.expectEqual(@as(fx.RunnerHeartbeatSequence, 1), snapshot.last_heartbeat_sequence.?);
    try std.testing.expectEqual(@as(usize, 2), try registry.healthEventCount(address));

    const event = (try registry.lastHealthEvent(address)).?;
    try std.testing.expectEqual(fx.RunnerHealthState.starting, event.previous_state.?);
    try std.testing.expectEqual(fx.RunnerHealthState.healthy, event.next_state);
    try std.testing.expectEqual(fx.RunnerHealthReason.heartbeat_recorded, event.reason);

    try std.testing.expectError(error.InvalidHeartbeatSequence, registry.recordHeartbeat(.{
        .address = address,
        .sequence = 1,
        .observed_at_ms = 1_300,
    }));
    try std.testing.expectError(error.RunnerNotFound, registry.recordHeartbeat(.{
        .address = fx.runnerAddress("missing", "runner"),
        .sequence = 1,
        .observed_at_ms = 1_300,
    }));
}
