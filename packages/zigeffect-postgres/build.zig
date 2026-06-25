const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigeffect_std = b.dependency("zigeffect_std", .{}).module("zigeffect_std");

    const zigeffect_postgres = b.addModule("zigeffect_postgres", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    zigeffect_postgres.addImport("zigeffect_std", zigeffect_std);

    const tests = b.addTest(.{
        .name = "zigeffect-postgres-tests",
        .root_module = zigeffect_postgres,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run zigeffect-postgres tests");
    test_step.dependOn(&run_tests.step);
}
