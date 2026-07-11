const std = @import("std");
const system = @import("system");
const zstd = @import("zigeffect_std");

test "production system compiles separate API worker and shared contracts" {
    try std.testing.expect(system.productionContract());
}
test "production system emits a Testing v2 capability scenario" {
    const scenario = zstd.Testing.Scenario{ .id = "bootstrap-boundaries", .label = "production adapters resolve before launch", .requirement = "req-bootstrap", .acceptance_check = "check-bootstrap", .component = "api-service", .command = "test" };
    var context = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{ .project = "zigeffect-reference-orders", .suite = "production-system", .scenario = scenario });
    defer context.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&context);
    try assertions.boolean(.{ .id = "real-wiring", .label = "all production wiring compiles" }, system.productionContract());
    try context.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}