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

    const examples_step = b.step("examples", "Build zigeffect-postgres examples");
    addExample(b, examples_step, target, optimize, zigeffect_postgres, "migrate", "examples/migrate.zig");
}

fn addExample(
    b: *std.Build,
    examples_step: *std.Build.Step,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
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
    const tests = b.addTest(.{
        .name = b.fmt("zigeffect-postgres-{s}-tests", .{name}),
        .root_module = module,
    });
    const run_tests = b.addRunArtifact(tests);

    examples_step.dependOn(&executable.step);
    examples_step.dependOn(&run_tests.step);
}
