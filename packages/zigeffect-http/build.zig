const std = @import("std");

fn addV2Test(b: *std.Build, runner: std.Build.LazyPath, options: std.Build.TestOptions) *std.Build.Step.Compile {
    var configured = options;
    configured.test_runner = .{ .path = runner, .mode = .server };
    return b.addTest(configured);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const zstd_dependency = b.dependency("zigeffect_std", .{ .target = target, .optimize = optimize });
    const zstd = zstd_dependency.module("zigeffect_std");
    const runner = zstd_dependency.module("zigeffect_test_runner").root_source_file.?;

    const module = b.addModule("zigeffect_http", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    module.addImport("zigeffect_std", zstd);

    const tests = addV2Test(b, runner, .{ .name = "zigeffect-http-tests", .root_module = module });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run zigeffect-http tests");
    test_step.dependOn(&run_tests.step);

    const server_module = b.createModule(.{
        .root_source_file = b.path("tests/process_server.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zigeffect_http", .module = module }},
    });
    const process_server = b.addExecutable(.{ .name = "zigeffect-http-process-server", .root_module = server_module });
    const conformance = b.addExecutable(.{
        .name = "zigeffect-http-process-conformance",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/process_conformance.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_conformance = b.addRunArtifact(conformance);
    run_conformance.addArtifactArg(process_server);
    test_step.dependOn(&run_conformance.step);
}
