const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigeffect = b.dependency("zigeffect", .{}).module("zigeffect");

    const zigeffect_std = b.addModule("zigeffect_std", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    zigeffect_std.addImport("zigeffect", zigeffect);

    const tests = b.addTest(.{
        .name = "zigeffect-std-tests",
        .root_module = zigeffect_std,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run zigeffect-std tests");
    test_step.dependOn(&run_tests.step);

    const examples_step = b.step("examples", "Build zigeffect-std examples");
    addExample(b, examples_step, target, optimize, zigeffect_std, "hello", "examples/hello.zig");
    addExample(b, examples_step, target, optimize, zigeffect_std, "schema-cli", "examples/schema_cli.zig");
    addExample(b, examples_step, target, optimize, zigeffect_std, "workspace-doctor", "examples/workspace_doctor.zig");
    addExample(b, examples_step, target, optimize, zigeffect_std, "agent-dev-session", "examples/agent_dev_session.zig");
    addExample(b, examples_step, target, optimize, zigeffect_std, "http-sql-smoke", "examples/http_sql_smoke.zig");
    addExample(b, examples_step, target, optimize, zigeffect_std, "local-toolbelt", "examples/local_toolbelt.zig");
}

fn addExample(
    b: *std.Build,
    examples_step: *std.Build.Step,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
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
    const tests = b.addTest(.{
        .name = b.fmt("zigeffect-std-{s}-tests", .{name}),
        .root_module = module,
    });
    const run_tests = b.addRunArtifact(tests);

    examples_step.dependOn(&executable.step);
    examples_step.dependOn(&run_tests.step);
}
