const std = @import("std");

fn linkTls(module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    module.link_libc = true;
    if (target.result.os.tag == .macos) {
        if (target.result.cpu.arch == .aarch64) {
            module.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
            module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
            module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/openssl@3/lib" });
        } else {
            module.addIncludePath(.{ .cwd_relative = "/usr/local/include" });
            module.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
            module.addLibraryPath(.{ .cwd_relative = "/usr/local/opt/openssl@3/lib" });
        }
    }
    module.linkSystemLibrary("ssl", .{});
    module.linkSystemLibrary("crypto", .{});
}

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
    const zstd_dep = b.dependency("zigeffect_std", .{ .target = target, .optimize = optimize });
    const zstd = zstd_dep.module("zigeffect_std");
    const module = b.addModule("zigeffect_otel", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zigeffect_std", .module = zstd }},
    });
    linkTls(module, target);
    const tests = addV2Test(b, zstd_dep.module("zigeffect_test_runner").root_source_file.?, .{
        .name = "zigeffect-otel-tests",
        .root_module = module,
    });
    const test_step = b.step("test", "Run OTLP exporter tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
    const collector = b.addExecutable(.{ .name = "zigeffect-otel-process-collector", .root_module = b.createModule(.{ .root_source_file = b.path("tests/process_collector.zig"), .target = target, .optimize = optimize }) });
    const process_module = b.createModule(.{ .root_source_file = b.path("tests/process_conformance.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "zigeffect_otel", .module = module }} });
    const process = b.addExecutable(.{ .name = "zigeffect-otel-process-conformance", .root_module = process_module });
    const run_process = b.addRunArtifact(process);
    run_process.addArtifactArg(collector);
    test_step.dependOn(&run_process.step);
}
