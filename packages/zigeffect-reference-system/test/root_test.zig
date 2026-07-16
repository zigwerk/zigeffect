const std = @import("std");
const system = @import("system");
const zstd = @import("zigeffect_std");

test "production system compiles separate API worker and shared contracts" {
    try std.testing.expect(system.productionContract());
}
test "production system emits the manifest-owned local contracts scenario" {
    const scenario = zstd.Testing.Scenario{ .id = "local-contracts", .label = "local service and domain contracts", .requirement = "req-local-contracts", .acceptance_check = "check-local-contracts", .component = "api-service", .command = "test", .default_seed = 1001, .source_roots = &.{ "services/api", "packages/shared", "src", "test" }, .tags = &.{ "acceptance", "deterministic" } };
    var context = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{ .project = "zigeffect-reference-orders", .suite = "production-system", .scenario = scenario, .seed = 1001 });
    defer context.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&context);
    try assertions.boolean(.{ .id = "real-wiring", .label = "all production wiring compiles" }, system.productionContract());
    try context.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}
