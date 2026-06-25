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

    const hello_module = b.createModule(.{
        .root_source_file = b.path("examples/hello.zig"),
        .target = target,
        .optimize = optimize,
    });
    hello_module.addImport("zigeffect_std", zigeffect_std);

    const hello_example = b.addExecutable(.{
        .name = "zigeffect-std-hello",
        .root_module = hello_module,
    });
    const hello_tests = b.addTest(.{
        .name = "zigeffect-std-hello-tests",
        .root_module = hello_module,
    });
    const run_hello_tests = b.addRunArtifact(hello_tests);

    const examples_step = b.step("examples", "Build zigeffect-std examples");
    examples_step.dependOn(&hello_example.step);
    examples_step.dependOn(&run_hello_tests.step);
}
