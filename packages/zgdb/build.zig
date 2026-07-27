const std = @import("std");

fn addV2Test(b: *std.Build, runner: std.Build.LazyPath, options: std.Build.TestOptions) *std.Build.Step.Compile {
    var configured = options;
    configured.test_runner = .{ .path = runner, .mode = .server };
    return b.addTest(configured);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    // Nothing here is installed — every artifact this package builds is a test or
    // test infrastructure — so the package default is the test default. A bare
    // `zig build test` in Debug spends most of its time in the harness capturing
    // ten stack frames per allocation. `-Doptimize` still works and still means
    // what it says; `-Doptimize=Debug` restores the traces.
    const optimize = b.option(
        std.builtin.OptimizeMode,
        "optimize",
        "Optimize mode (default ReleaseSafe; this package installs nothing)",
    ) orelse .ReleaseSafe;

    // zigeffect is a test-only dependency: the storage engine itself imports
    // nothing but std. Keeping it that way is the point of the package.
    const zigeffect_dependency = b.dependency("zigeffect", .{ .target = target, .optimize = optimize });
    const testing_runner = zigeffect_dependency.module("zigeffect_test_runner").root_source_file.?;

    const zgdb = b.addModule("zgdb", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const source_tests = addV2Test(b, testing_runner, .{
        .name = "zgdb-tests",
        .root_module = zgdb,
    });
    const run_source_tests = b.addRunArtifact(source_tests);
    const test_step = b.step("test", "Run zgdb tests");
    test_step.dependOn(&run_source_tests.step);
}
