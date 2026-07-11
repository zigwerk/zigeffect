const std = @import("std");

fn addV2Test(b: *std.Build, runner: std.Build.LazyPath, options: std.Build.TestOptions) *std.Build.Step.Compile {
    var configured = options;
    configured.test_runner = .{ .path = runner, .mode = .server };
    return b.addTest(configured);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigeffect_std_dependency = b.dependency("zigeffect_std", .{});
    const zigeffect_std = zigeffect_std_dependency.module("zigeffect_std");
    const testing_runner = zigeffect_std_dependency.module("zigeffect_test_runner").root_source_file.?;

    const zigeffect_postgres = b.addModule("zigeffect_postgres", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    zigeffect_postgres.addImport("zigeffect_std", zigeffect_std);

    const tests = addV2Test(b, testing_runner, .{
        .name = "zigeffect-postgres-tests",
        .root_module = zigeffect_postgres,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run zigeffect-postgres tests");
    test_step.dependOn(&run_tests.step);

    const examples_step = b.step("examples", "Build zigeffect-postgres examples");
    addExample(b, examples_step, target, optimize, testing_runner, zigeffect_postgres, "migrate", "examples/migrate.zig");
}

fn addExample(
    b: *std.Build,
    examples_step: *std.Build.Step,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    testing_runner: std.Build.LazyPath,
    zigeffect_postgres: *std.Build.Module,
    name: []const u8,
    path: []const u8,
) void {
    const module = b.createModule(.{
        .root_source_file = b.path(path),
        .target = target,
        .optimize = optimize,
    });
    module.addImport("zigeffect_postgres", zigeffect_postgres);

    const executable = b.addExecutable(.{
        .name = b.fmt("zigeffect-postgres-{s}", .{name}),
        .root_module = module,
    });
    const tests = addV2Test(b, testing_runner, .{
        .name = b.fmt("zigeffect-postgres-{s}-tests", .{name}),
        .root_module = module,
    });
    const run_tests = b.addRunArtifact(tests);

    examples_step.dependOn(&executable.step);
    examples_step.dependOn(&run_tests.step);
}
