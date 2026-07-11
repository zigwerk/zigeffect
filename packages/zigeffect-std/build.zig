const std = @import("std");

fn addV2Test(b: *std.Build, runner: std.Build.LazyPath, options: std.Build.TestOptions) *std.Build.Step.Compile {
    var configured = options;
    configured.test_runner = .{ .path = runner, .mode = .server };
    return b.addTest(configured);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigeffect_dependency = b.dependency("zigeffect", .{});
    const zigeffect = zigeffect_dependency.module("zigeffect");
    const testing_runner = zigeffect_dependency.module("zigeffect_test_runner").root_source_file.?;
    _ = b.addModule("zigeffect_test_runner", .{
        .root_source_file = testing_runner,
        .target = target,
        .optimize = optimize,
    });

    const zigeffect_std = b.addModule("zigeffect_std", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    zigeffect_std.addImport("zigeffect", zigeffect);

    const tests = addV2Test(b, testing_runner, .{
        .name = "zigeffect-std-tests",
        .root_module = zigeffect_std,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run zigeffect-std tests");
    test_step.dependOn(&run_tests.step);

    const statechart_test_module = b.createModule(.{
        .root_source_file = b.path("src/statechart_test_root.zig"),
        .target = target,
        .optimize = optimize,
    });
    statechart_test_module.addImport("zigeffect", zigeffect);
    const statechart_tests = addV2Test(b, testing_runner, .{
        .name = "zigeffect-std-statechart-tests",
        .root_module = statechart_test_module,
    });
    const run_statechart_tests = b.addRunArtifact(statechart_tests);
    const statechart_test_step = b.step("statechart-test", "Run ZigEffect statechart standard-library tests");
    statechart_test_step.dependOn(&run_statechart_tests.step);

    const examples_step = b.step("examples", "Build zigeffect-std examples");
    addExample(b, examples_step, target, optimize, testing_runner, zigeffect_std, "hello", "examples/hello.zig");
    addExample(b, examples_step, target, optimize, testing_runner, zigeffect_std, "schema-cli", "examples/schema_cli.zig");
    addExample(b, examples_step, target, optimize, testing_runner, zigeffect_std, "workspace-doctor", "examples/workspace_doctor.zig");
    addExample(b, examples_step, target, optimize, testing_runner, zigeffect_std, "agent-dev-session", "examples/agent_dev_session.zig");
    addExample(b, examples_step, target, optimize, testing_runner, zigeffect_std, "agent-supervisor", "examples/agent_supervisor.zig");
    addExample(b, examples_step, target, optimize, testing_runner, zigeffect_std, "http-router", "examples/http_router.zig");
    addExample(b, examples_step, target, optimize, testing_runner, zigeffect_std, "http-sql-smoke", "examples/http_sql_smoke.zig");
    addExample(b, examples_step, target, optimize, testing_runner, zigeffect_std, "local-toolbelt", "examples/local_toolbelt.zig");
    addExample(b, examples_step, target, optimize, testing_runner, zigeffect_std, "causal-graph", "examples/causal_graph.zig");
    addExample(b, examples_step, target, optimize, testing_runner, zigeffect_std, "agent-workflow-studio", "examples/agent_workflow_studio.zig");
}

fn addExample(
    b: *std.Build,
    examples_step: *std.Build.Step,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    testing_runner: std.Build.LazyPath,
    zigeffect_std: *std.Build.Module,
    name: []const u8,
    path: []const u8,
) void {
    const module = b.createModule(.{
        .root_source_file = b.path(path),
        .target = target,
        .optimize = optimize,
    });
    module.addImport("zigeffect_std", zigeffect_std);

    const executable = b.addExecutable(.{
        .name = b.fmt("zigeffect-std-{s}", .{name}),
        .root_module = module,
    });
    const tests = addV2Test(b, testing_runner, .{
        .name = b.fmt("zigeffect-std-{s}-tests", .{name}),
        .root_module = module,
    });
    const run_tests = b.addRunArtifact(tests);

    examples_step.dependOn(&executable.step);
    examples_step.dependOn(&run_tests.step);
}
