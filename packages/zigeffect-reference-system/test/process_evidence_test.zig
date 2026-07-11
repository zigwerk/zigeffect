const std = @import("std");
const zstd = @import("zigeffect_std");

test "separate process reference stack publishes Testing v2 evidence" {
    const verified = try std.process.Environ.getAlloc(std.testing.environ, std.testing.allocator, "ZIGEFFECT_PROCESS_STACK_VERIFIED");
    defer std.testing.allocator.free(verified);
    const scenario = zstd.Testing.Scenario{
        .id = "process-order-stack",
        .label = "API worker collector and infrastructure run as independent processes",
        .requirement = "req-process-stack",
        .acceptance_check = "check-process-stack",
        .component = "api-service",
        .command = "process-evidence",
        .tags = &.{ "live", "process", "tls", "recovery" },
    };
    var context = try zstd.Testing.TestContext.init(std.testing.allocator, .{ .project = "zigeffect-reference-orders", .suite = "process-stack", .scenario = scenario, .seed = 8801 });
    defer context.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&context);
    try assertions.stringEqual(.{ .id = "process-stack-verified", .label = "orchestrator completed", .repair_hint = "replay test/run_process_stack.sh" }, "1", verified);
    try assertions.noFindings(.{ .id = "process-stack-no-findings", .label = "no causal findings" });
    try assertions.noPendingFibers(.{ .id = "process-stack-no-pending-fibers", .label = "all service processes drained" });
    try context.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}
