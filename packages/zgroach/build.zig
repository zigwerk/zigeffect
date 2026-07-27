const std = @import("std");

fn addV2Test(b: *std.Build, runner: std.Build.LazyPath, options: std.Build.TestOptions) *std.Build.Step.Compile {
    var configured = options;
    configured.test_runner = .{ .path = runner, .mode = .server };
    return b.addTest(configured);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // Tests default to ReleaseSafe; binaries keep -Doptimize.
    //
    // A bare `zig build test` in Debug spends most of its time in the harness:
    // std.testing.allocator captures ten stack frames per allocation regardless
    // of optimize mode, and on this platform each frame costs a dyld lookup and
    // a global mutex. Measured on zgraphy, 420s against 4.1s.
    //
    // Deliberately NOT `preferred_optimize_mode`: that returns Debug unless
    // -Drelease is passed, so the default does not change, and it removes
    // -Doptimize entirely — which breaks every command in this repository
    // including the manifest's own check-safe and production-check. Both were
    // verified the hard way.
    //
    // -Dtest-optimize=Debug restores allocator stack traces, which is the one
    // thing this trades away and the reason to keep the escape hatch.
    const test_optimize = b.option(
        std.builtin.OptimizeMode,
        "test-optimize",
        "Optimize mode for test artifacts (default ReleaseSafe)",
    ) orelse .ReleaseSafe;
    const zigeffect_dependency = b.dependency("zigeffect", .{ .target = target, .optimize = optimize });
    const zigeffect = zigeffect_dependency.module("zigeffect");
    const zigeffect_std_dependency = b.dependency("zigeffect_std", .{ .target = target, .optimize = optimize });
    const zigeffect_std = zigeffect_std_dependency.module("zigeffect_std");
    const testing_runner = zigeffect_dependency.module("zigeffect_test_runner").root_source_file.?;

    const zgroach = b.addModule("zgroach", .{
        .root_source_file = b.path("src/zgroach.zig"),
        .target = target,
        .optimize = optimize,
    });
    zgroach.addImport("zigeffect", zigeffect);
    zgroach.addImport("zigeffect_std", zigeffect_std);

    const tests = b.createModule(.{
        .root_source_file = b.path("test/compiler_test.zig"),
        .target = target,
        .optimize = test_optimize,
    });
    tests.addImport("zigeffect", zigeffect);
    tests.addImport("zigeffect_std", zigeffect_std);
    tests.addImport("zgroach", zgroach);

    const unit_tests = addV2Test(b, testing_runner, .{
        .name = "zgroach-tests",
        .root_module = tests,
    });

    // The source module is a dependency of the test module, and Zig only
    // collects tests from the module under test — so without its own artifact
    // every test inside src/ would compile and never run.
    // Its own module rather than the published one: the public `zgroach` module
    // follows -Doptimize because applications link it, while this artifact is a
    // test and follows -Dtest-optimize like every other test. Sharing the module
    // left a bare `zig build test` running one artifact ReleaseSafe and the other
    // Debug, which is the sort of split nobody notices until a timing looks odd.
    const source_test_module = b.createModule(.{
        .root_source_file = b.path("src/zgroach.zig"),
        .target = target,
        .optimize = test_optimize,
    });
    source_test_module.addImport("zigeffect", zigeffect);
    source_test_module.addImport("zigeffect_std", zigeffect_std);
    const source_tests = addV2Test(b, testing_runner, .{
        .name = "zgroach-source-tests",
        .root_module = source_test_module,
    });
    const run_source_tests = b.addRunArtifact(source_tests);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run zgroach tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_source_tests.step);
}
