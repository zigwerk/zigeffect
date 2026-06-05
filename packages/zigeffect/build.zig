const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigeffect = b.addModule("zigeffect", .{
        .root_source_file = b.path("src/zigeffect.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.createModule(.{
        .root_source_file = b.path("test/all_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.addImport("zigeffect", zigeffect);

    const unit_tests = b.addTest(.{
        .name = "zigeffect-tests",
        .root_module = tests,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run zigeffect tests");
    test_step.dependOn(&run_unit_tests.step);

    const readiness_example_module = b.createModule(.{
        .root_source_file = b.path("examples/readiness.zig"),
        .target = target,
        .optimize = optimize,
    });
    readiness_example_module.addImport("zigeffect", zigeffect);

    const readiness_example = b.addExecutable(.{
        .name = "zigeffect-readiness-example",
        .root_module = readiness_example_module,
    });

    const readiness_example_tests = b.addTest(.{
        .name = "zigeffect-readiness-example-tests",
        .root_module = readiness_example_module,
    });
    const run_readiness_example_tests = b.addRunArtifact(readiness_example_tests);

    const scaffold_module = b.createModule(.{
        .root_source_file = b.path("tools/scaffold_module.zig"),
        .target = target,
        .optimize = optimize,
    });

    const scaffold_tool = b.addExecutable(.{
        .name = "zigeffect-scaffold-module",
        .root_module = scaffold_module,
    });

    const scaffold_tool_tests = b.addTest(.{
        .name = "zigeffect-scaffold-module-tests",
        .root_module = scaffold_module,
    });
    const run_scaffold_tool_tests = b.addRunArtifact(scaffold_tool_tests);

    const examples_step = b.step("examples", "Compile and test zigeffect examples");
    examples_step.dependOn(&readiness_example.step);
    examples_step.dependOn(&run_readiness_example_tests.step);
    examples_step.dependOn(&scaffold_tool.step);
    examples_step.dependOn(&run_scaffold_tool_tests.step);
}
