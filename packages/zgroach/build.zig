const std = @import("std");

fn addV2Test(b: *std.Build, runner: std.Build.LazyPath, options: std.Build.TestOptions) *std.Build.Step.Compile {
    var configured = options;
    configured.test_runner = .{ .path = runner, .mode = .server };
    return b.addTest(configured);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
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
        .optimize = optimize,
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
    const source_tests = addV2Test(b, testing_runner, .{
        .name = "zgroach-source-tests",
        .root_module = zgroach,
    });
    const run_source_tests = b.addRunArtifact(source_tests);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run zgroach tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_source_tests.step);
}
