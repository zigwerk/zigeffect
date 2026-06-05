const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigeffect = b.createModule(.{
        .root_source_file = b.path("../zigeffect/src/zigeffect.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zgroach = b.addModule("zgroach", .{
        .root_source_file = b.path("src/zgroach.zig"),
        .target = target,
        .optimize = optimize,
    });
    zgroach.addImport("zigeffect", zigeffect);

    const tests = b.createModule(.{
        .root_source_file = b.path("test/compiler_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.addImport("zigeffect", zigeffect);
    tests.addImport("zgroach", zgroach);

    const unit_tests = b.addTest(.{
        .name = "zgroach-tests",
        .root_module = tests,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run zgroach tests");
    test_step.dependOn(&run_unit_tests.step);
}
