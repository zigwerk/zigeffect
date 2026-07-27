const std = @import("std");

var test_filter_declared = false;
var configured_test_filter: ?[]const u8 = null;

fn addV2Test(b: *std.Build, runner: std.Build.LazyPath, options: std.Build.TestOptions) *std.Build.Step.Compile {
    var configured = options;
    configured.test_runner = .{ .path = runner, .mode = .server };
    if (!test_filter_declared) {
        configured_test_filter = b.option([]const u8, "test-filter", "Compile only native tests whose names contain this text");
        test_filter_declared = true;
    }
    if (configured_test_filter) |filter| configured.filters = &.{filter};
    return b.addTest(configured);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // Tests default to ReleaseSafe; binaries keep -Doptimize. A bare
    // `zig build test` in Debug spends most of its time in the harness, which
    // captures ten stack frames per allocation in every optimize mode.
    // -Dtest-optimize=Debug restores those traces.
    const test_optimize = b.option(
        std.builtin.OptimizeMode,
        "test-optimize",
        "Optimize mode for test artifacts (default ReleaseSafe)",
    ) orelse .ReleaseSafe;
    const zigeffect_std_dependency = b.dependency("zigeffect_std", .{});
    const zigeffect_std = zigeffect_std_dependency.module("zigeffect_std");
    const testing_runner = zigeffect_std_dependency.module("zigeffect_test_runner").root_source_file.?;

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

    const tests = addV2Test(b, testing_runner, .{
        .name = "zigeffect-cli-tests",
        .root_module = cli,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run zigeffect CLI tests");
    test_step.dependOn(&run_tests.step);

    const integration_module = b.createModule(.{
        .root_source_file = b.path("test/generated_projects_test.zig"),
        .target = target,
        .optimize = test_optimize,
    });
    integration_module.addImport("zigeffect_cli", cli);
    const integration_tests = addV2Test(b, testing_runner, .{
        .name = "zigeffect-generated-project-tests",
        .root_module = integration_module,
    });
    const integration_step = b.step("integration-test", "Generate and compile every scaffold kind");
    integration_step.dependOn(&b.addRunArtifact(integration_tests).step);
}
