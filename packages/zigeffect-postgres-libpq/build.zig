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

    const module = b.addModule("zigeffect_postgres_libpq", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{.{ .name = "zigeffect_std", .module = zstd }},
    });
    if (target.result.os.tag == .macos) {
        module.addLibraryPath(.{ .cwd_relative = if (target.result.cpu.arch == .aarch64)
            "/opt/homebrew/opt/libpq/lib"
        else
            "/usr/local/opt/libpq/lib" });
    }
    module.linkSystemLibrary("pq", .{});

    const tests = addV2Test(b, runner, .{ .name = "zigeffect-postgres-libpq-tests", .root_module = module });
    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run native libpq adapter tests").dependOn(&run_tests.step);

    const live_database = b.option([]const u8, "live-database", "Database identity for the conformance receipt") orelse "unspecified";
    const live_options = b.addOptions();
    live_options.addOption([]const u8, "database", live_database);
    const live_module = b.createModule(.{
        .root_source_file = b.path("tests/live_conformance.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zigeffect_postgres_libpq", .module = module },
            .{ .name = "live_options", .module = live_options.createModule() },
        },
    });
    const live_tests = addV2Test(b, runner, .{ .name = b.fmt("zigeffect-{s}-live-conformance", .{live_database}), .root_module = live_module });
    const run_live = b.addRunArtifact(live_tests);
    b.step("conformance", "Run required live PostgreSQL conformance").dependOn(&run_live.step);
}
