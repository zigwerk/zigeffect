const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // Tests default to ReleaseSafe; binaries keep -Doptimize. On this package a
    // bare `zig build test` was 420s and is 4.1s, almost all of it the harness
    // capturing ten stack frames per allocation regardless of optimize mode.
    // -Dtest-optimize=Debug restores those traces, which is the only thing this
    // trades away. Deliberately not preferred_optimize_mode: that leaves the
    // default at Debug and deletes -Doptimize entirely.
    const test_optimize = b.option(
        std.builtin.OptimizeMode,
        "test-optimize",
        "Optimize mode for test artifacts (default ReleaseSafe)",
    ) orelse .ReleaseSafe;
    const zstd_dep = b.dependency("zigeffect_std", .{ .target = target, .optimize = optimize });
    const zstd = zstd_dep.module("zigeffect_std");
    const parser_dep = b.dependency("zigeffect_parser", .{ .target = target, .optimize = optimize });
    const parser = parser_dep.module("zigeffect_parser");
    const zgdb_dep = b.dependency("zgdb", .{ .target = target, .optimize = optimize });
    const zgdb = zgdb_dep.module("zgdb");
    const zgroach_dep = b.dependency("zgroach", .{ .target = target, .optimize = optimize });
    const zgroach = zgroach_dep.module("zgroach");
    const benchmark_assets = b.createModule(.{
        .root_source_file = b.path("benchmarks/embedded.zig"),
        .target = target,
        .optimize = optimize,
    });
    const zgraphy = b.addModule("zgraphy", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    zgraphy.addImport("zigeffect_std", zstd);
    zgraphy.addImport("zigeffect_parser", parser);
    zgraphy.addImport("zgdb", zgdb);
    zgraphy.addImport("zgroach", zgroach);
    zgraphy.addImport("zgraphy_benchmark_assets", benchmark_assets);

    const cli_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    cli_module.addImport("zgraphy", zgraphy);
    cli_module.addImport("zigeffect_std", zstd);
    const executable = b.addExecutable(.{
        .name = "zgraphy",
        .root_module = cli_module,
    });
    b.installArtifact(executable);

    // A parallel dependency graph at test_optimize.
    //
    // Building only the test module at a different optimize mode splits it from
    // the C the zgraphy module links: zgraphy vendors tree-sitter, and a
    // ReleaseSafe Zig module against Debug C objects fails to link with
    // undefined ubsan handlers. The whole chain has to agree, so the test path
    // gets its own instances rather than borrowing the published ones.
    const zstd_test_dep = b.dependency("zigeffect_std", .{ .target = target, .optimize = test_optimize });
    const zstd_test = zstd_test_dep.module("zigeffect_std");
    const parser_test_dep = b.dependency("zigeffect_parser", .{ .target = target, .optimize = test_optimize });
    const parser_test = parser_test_dep.module("zigeffect_parser");
    const zgdb_test_dep = b.dependency("zgdb", .{ .target = target, .optimize = test_optimize });
    const benchmark_assets_test = b.createModule(.{
        .root_source_file = b.path("benchmarks/embedded.zig"),
        .target = target,
        .optimize = test_optimize,
    });
    const zgraphy_test = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = test_optimize,
    });
    zgraphy_test.addImport("zigeffect_std", zstd_test);
    zgraphy_test.addImport("zigeffect_parser", parser_test);
    zgraphy_test.addImport("zgdb", zgdb_test_dep.module("zgdb"));
    const zgroach_test_dep = b.dependency("zgroach", .{ .target = target, .optimize = test_optimize });
    zgraphy_test.addImport("zgroach", zgroach_test_dep.module("zgroach"));
    zgraphy_test.addImport("zgraphy_benchmark_assets", benchmark_assets_test);

    const tests_module = b.createModule(.{
        .root_source_file = b.path("test/all_test.zig"),
        .target = target,
        .optimize = test_optimize,
    });
    tests_module.addImport("zgraphy", zgraphy_test);
    tests_module.addImport("zgroach", zgroach_test_dep.module("zgroach"));
    tests_module.addImport("zigeffect_std", zstd_test);

    // Hand the installed-process test the compiled executable path. Wiring it as
    // a build option makes the test depend on the executable, so `zig build test`
    // builds the real binary before the process-boundary test spawns it.
    const build_options = b.addOptions();
    build_options.addOptionPath("zgraphy_exe", executable.getEmittedBin());
    tests_module.addOptions("build_options", build_options);

    var test_options = std.Build.TestOptions{
        .name = "zgraphy-tests",
        .root_module = tests_module,
        .test_runner = .{
            .path = zstd_dep.module("zigeffect_test_runner").root_source_file.?,
            .mode = .server,
        },
    };
    if (b.option([]const u8, "test-filter", "Compile only matching native tests")) |filter| {
        test_options.filters = &.{filter};
    }
    const tests = b.addTest(test_options);
    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run zgraphy Testing v2 suite").dependOn(&run_tests.step);
}
