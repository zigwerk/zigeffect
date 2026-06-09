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
