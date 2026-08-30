const std = @import("std");

fn addV2Test(b: *std.Build, runner: std.Build.LazyPath, options: std.Build.TestOptions) *std.Build.Step.Compile {
    var configured = options;
    configured.test_runner = .{ .path = runner, .mode = .server };
    return b.addTest(configured);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.option(
        std.builtin.OptimizeMode,
        "optimize",
        "Optimize mode (default ReleaseSafe; this package installs nothing)",
    ) orelse .ReleaseSafe;
    const http = b.dependency("zigeffect_http", .{ .target = target, .optimize = optimize }).module("zigeffect_http");
    const zstd_dependency = b.dependency("zigeffect_std", .{ .target = target, .optimize = optimize });
    const zstd = zstd_dependency.module("zigeffect_std");
    const runner = zstd_dependency.module("zigeffect_test_runner").root_source_file.?;

    const zigtls = b.createModule(.{
        .root_source_file = b.path("vendor/zigtls/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const adapter = b.addModule("zigeffect_http_tls_zigtls", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zigeffect_http", .module = http },
            .{ .name = "zigeffect_std", .module = zstd },
            .{ .name = "zigtls", .module = zigtls },
        },
    });
    const test_module = b.createModule(.{
        .root_source_file = b.path("test/all_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "adapter", .module = adapter },
            .{ .name = "zigeffect_http", .module = http },
            .{ .name = "zigeffect_std", .module = zstd },
        },
    });
    const tests = addV2Test(b, runner, .{
        .name = "zigeffect-http-tls-zigtls-tests",
        .root_module = test_module,
    });
    const run_tests = b.addRunArtifact(tests);
    const vendor_tests = addV2Test(b, runner, .{
        .name = "zigeffect-http-tls-zigtls-vendor-tests",
        .root_module = zigtls,
    });
    const run_vendor_tests = b.addRunArtifact(vendor_tests);
    const test_step = b.step("test", "Run ZigTLS HTTP provider and vendored runtime tests");
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&run_vendor_tests.step);
}
