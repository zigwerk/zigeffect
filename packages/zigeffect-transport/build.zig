const std = @import("std");

fn addV2Test(b: *std.Build, runner: std.Build.LazyPath, options: std.Build.TestOptions) *std.Build.Step.Compile {
    var configured = options;
    configured.test_runner = .{ .path = runner, .mode = .server };
    return b.addTest(configured);
}

fn linkOpenSsl(module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    if (target.result.os.tag == .macos) {
        module.addLibraryPath(.{ .cwd_relative = if (target.result.cpu.arch == .aarch64)
            "/opt/homebrew/opt/openssl@3/lib"
        else
            "/usr/local/opt/openssl@3/lib" });
    }
    module.linkSystemLibrary("ssl", .{});
    module.linkSystemLibrary("crypto", .{});
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
    const zstd_dep = b.dependency("zigeffect_std", .{ .target = target, .optimize = optimize });
    const zstd = zstd_dep.module("zigeffect_std");
    const module = b.addModule("zigeffect_transport", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{.{ .name = "zigeffect_std", .module = zstd }},
    });
    linkOpenSsl(module, target);
    const runner = zstd_dep.module("zigeffect_test_runner").root_source_file.?;
    const tests = addV2Test(b, runner, .{ .name = "zigeffect-transport-tests", .root_module = module });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run real transport tests");
    test_step.dependOn(&run_tests.step);

    const server_module = b.createModule(.{
        .root_source_file = b.path("tests/process_server.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{.{ .name = "zigeffect_transport", .module = module }},
    });
    linkOpenSsl(server_module, target);
    const process_server = b.addExecutable(.{ .name = "zigeffect-transport-process-server", .root_module = server_module });
    const conformance_module = b.createModule(.{
        .root_source_file = b.path("tests/process_conformance.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{.{ .name = "zigeffect_transport", .module = module }},
    });
    linkOpenSsl(conformance_module, target);
    const conformance = b.addExecutable(.{ .name = "zigeffect-transport-process-conformance", .root_module = conformance_module });
    const run_conformance = b.addRunArtifact(conformance);
    run_conformance.addArtifactArg(process_server);
    run_conformance.addFileArg(b.path("../zigeffect-http-tls-openssl/tests/fixtures/cert.pem"));
    run_conformance.addFileArg(b.path("../zigeffect-http-tls-openssl/tests/fixtures/key.pem"));
    test_step.dependOn(&run_conformance.step);
}
