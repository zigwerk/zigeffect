const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const need_libc: ?bool = if (target.result.os.tag == .windows) null else true;

    const zigeffect_std = b.dependency("zigeffect_std", .{}).module("zigeffect_std");
    const quic_dep = b.dependency("quic", .{ .target = target, .optimize = optimize });

    const zigeffect_quic = b.addModule("zigeffect_quic", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = need_libc,
    });
    zigeffect_quic.addImport("zigeffect_std", zigeffect_std);
    zigeffect_quic.addImport("quic", quic_dep.module("quic"));

    const tests = b.addTest(.{
        .name = "zigeffect-quic-tests",
        .root_module = zigeffect_quic,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run zigeffect-quic tests");
    test_step.dependOn(&run_tests.step);

    const examples_step = b.step("examples", "Build zigeffect-quic examples");
    addExample(b, examples_step, target, optimize, need_libc, zigeffect_quic, "http3-smoke", "examples/http3_smoke.zig");
    addExample(b, examples_step, target, optimize, need_libc, zigeffect_quic, "webtransport-receipt", "examples/webtransport_receipt.zig");
}

fn addExample(
    b: *std.Build,
    examples_step: *std.Build.Step,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    link_libc: ?bool,
    zigeffect_quic: *std.Build.Module,
    name: []const u8,
    path: []const u8,
) void {
    const module = b.createModule(.{
        .root_source_file = b.path(path),
        .target = target,
        .optimize = optimize,
        .link_libc = link_libc,
    });
    module.addImport("zigeffect_quic", zigeffect_quic);

    const executable = b.addExecutable(.{
        .name = b.fmt("zigeffect-quic-{s}", .{name}),
        .root_module = module,
    });
    const tests = b.addTest(.{
        .name = b.fmt("zigeffect-quic-{s}-tests", .{name}),
        .root_module = module,
    });
    const run_tests = b.addRunArtifact(tests);

    examples_step.dependOn(&executable.step);
    examples_step.dependOn(&run_tests.step);
}
