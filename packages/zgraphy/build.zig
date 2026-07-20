const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const zstd_dep = b.dependency("zigeffect_std", .{ .target = target, .optimize = optimize });
    const zstd = zstd_dep.module("zigeffect_std");
    const parser_dep = b.dependency("zigeffect_parser", .{ .target = target, .optimize = optimize });
    const parser = parser_dep.module("zigeffect_parser");
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

    const tests_module = b.createModule(.{
        .root_source_file = b.path("test/all_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests_module.addImport("zgraphy", zgraphy);
    tests_module.addImport("zigeffect_std", zstd);

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
