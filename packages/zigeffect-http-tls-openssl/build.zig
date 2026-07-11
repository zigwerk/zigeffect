const std = @import("std");

fn addV2Test(b: *std.Build, runner: std.Build.LazyPath, options: std.Build.TestOptions) *std.Build.Step.Compile {
    var configured = options;
    configured.test_runner = .{ .path = runner, .mode = .server };
    return b.addTest(configured);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const http = b.dependency("zigeffect_http", .{ .target = target, .optimize = optimize }).module("zigeffect_http");
    const zstd_dependency = b.dependency("zigeffect_std", .{ .target = target, .optimize = optimize });
    const zstd = zstd_dependency.module("zigeffect_std");
    const runner = zstd_dependency.module("zigeffect_test_runner").root_source_file.?;

    const module = b.addModule("zigeffect_http_tls_openssl", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "zigeffect_http", .module = http },
            .{ .name = "zigeffect_std", .module = zstd },
        },
    });
    if (target.result.os.tag == .macos) {
        module.addLibraryPath(.{ .cwd_relative = if (target.result.cpu.arch == .aarch64)
            "/opt/homebrew/opt/openssl@3/lib"
        else
            "/usr/local/opt/openssl@3/lib" });
    }
    module.linkSystemLibrary("ssl", .{});
    module.linkSystemLibrary("crypto", .{});

    const tests = addV2Test(b, runner, .{ .name = "zigeffect-http-tls-openssl-tests", .root_module = module });
    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run live OpenSSL TLS provider tests").dependOn(&run_tests.step);
}
