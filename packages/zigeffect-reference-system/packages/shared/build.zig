const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const zigeffect_std_dependency = b.dependency("zigeffect_std", .{ .target = target, .optimize = optimize });
    const zigeffect_std = zigeffect_std_dependency.module("zigeffect_std");
    const testing_runner = zigeffect_std_dependency.module("zigeffect_test_runner").root_source_file.?;
    const library = b.addModule("shared", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    library.addImport("zigeffect_std", zigeffect_std);
    const test_module = b.createModule(.{
        .root_source_file = b.path("test/root_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_module.addImport("library", library);
    test_module.addImport("zigeffect_std", zigeffect_std);
    const tests = b.addTest(.{ .name = "shared-tests", .root_module = test_module, .test_runner = .{ .path = testing_runner, .mode = .server } });
    const test_step = b.step("test", "Run shared tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}