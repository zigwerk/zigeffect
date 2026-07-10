const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const zigeffect_std = b.dependency("zigeffect_std", .{}).module("zigeffect_std");

    const cli = b.addModule("zigeffect_cli", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    cli.addImport("zigeffect_std", zigeffect_std);

    const executable_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    executable_module.addImport("zigeffect_cli", cli);
    const executable = b.addExecutable(.{
        .name = "zigeffect",
        .root_module = executable_module,
    });
    b.installArtifact(executable);
    const run = b.addRunArtifact(executable);
    if (b.args) |args| run.addArgs(args);
    const run_step = b.step("run", "Run the zigeffect CLI");
    run_step.dependOn(&run.step);

    const tests = b.addTest(.{
        .name = "zigeffect-cli-tests",
        .root_module = cli,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run zigeffect CLI tests");
    test_step.dependOn(&run_tests.step);

    const integration_module = b.createModule(.{
        .root_source_file = b.path("test/generated_projects_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    integration_module.addImport("zigeffect_cli", cli);
    const integration_tests = b.addTest(.{
        .name = "zigeffect-generated-project-tests",
        .root_module = integration_module,
    });
    const integration_step = b.step("integration-test", "Generate and compile every scaffold kind");
    integration_step.dependOn(&b.addRunArtifact(integration_tests).step);
}
