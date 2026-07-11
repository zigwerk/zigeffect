const std = @import("std");

fn addV2Test(b: *std.Build, runner: std.Build.LazyPath, options: std.Build.TestOptions) *std.Build.Step.Compile {
    var configured = options;
    configured.test_runner = .{ .path = runner, .mode = .server };
    return b.addTest(configured);
}

fn linkLibpq(module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    if (target.result.os.tag == .macos) {
        module.addLibraryPath(.{ .cwd_relative = if (target.result.cpu.arch == .aarch64)
            "/opt/homebrew/opt/libpq/lib"
        else
            "/usr/local/opt/libpq/lib" });
    }
    module.linkSystemLibrary("pq", .{});
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const postgres_dep = b.dependency("zigeffect_postgres_libpq", .{ .target = target, .optimize = optimize });

    const module = b.addModule("zigeffect_storage_postgres", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "zigeffect_postgres_libpq", .module = postgres_dep.module("zigeffect_postgres_libpq") },
        },
    });
    linkLibpq(module, target);

    const runner = b.path("../zigeffect/src/testing/runner.zig");
    const tests = addV2Test(b, runner, .{ .name = "zigeffect-storage-postgres-tests", .root_module = module });
    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run PostgreSQL durable-store tests").dependOn(&run_tests.step);

    const live_database = b.option([]const u8, "live-database", "Database identity for the receipt") orelse "unspecified";
    const live_options = b.addOptions();
    live_options.addOption([]const u8, "database", live_database);
    const live_module = b.createModule(.{
        .root_source_file = b.path("tests/live_conformance.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "zigeffect_storage_postgres", .module = module },
            .{ .name = "zigeffect_postgres_libpq", .module = postgres_dep.module("zigeffect_postgres_libpq") },
            .{ .name = "live_options", .module = live_options.createModule() },
        },
    });
    linkLibpq(live_module, target);
    const live_tests = addV2Test(b, runner, .{ .name = b.fmt("zigeffect-storage-{s}-live-conformance", .{live_database}), .root_module = live_module });
    const run_live = b.addRunArtifact(live_tests);
    b.step("conformance", "Run required live durable-store conformance").dependOn(&run_live.step);

    inline for (.{ "seed", "verify" }) |mode| {
        const restart_options = b.addOptions();
        restart_options.addOption([]const u8, "database", live_database);
        restart_options.addOption([]const u8, "mode", mode);
        const restart_module = b.createModule(.{
            .root_source_file = b.path("tests/restart_conformance.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "zigeffect_storage_postgres", .module = module },
                .{ .name = "zigeffect_postgres_libpq", .module = postgres_dep.module("zigeffect_postgres_libpq") },
                .{ .name = "restart_options", .module = restart_options.createModule() },
            },
        });
        linkLibpq(restart_module, target);
        const restart_tests = addV2Test(b, runner, .{
            .name = b.fmt("zigeffect-storage-{s}-restart-{s}", .{ live_database, mode }),
            .root_module = restart_module,
        });
        const run_restart = b.addRunArtifact(restart_tests);
        b.step(b.fmt("restart-{s}", .{mode}), b.fmt("Run durable-store restart {s} phase", .{mode})).dependOn(&run_restart.step);
    }
}
