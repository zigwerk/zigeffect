const std = @import("std");

fn addV2Test(b: *std.Build, runner: std.Build.LazyPath, options: std.Build.TestOptions) *std.Build.Step.Compile {
    var configured = options;
    configured.test_runner = .{ .path = runner, .mode = .server };
    return b.addTest(configured);
}

// Stage 1 scaffold. The adapter module imports the core `zigeffect` package and
// implements its `AsyncBackend` vtable on top of zio. zio is a LAZY dependency:
// `zig build` only fetches it once the backend actually imports it (Stage 1).
// Until then the package builds and the skeleton compiles against zigeffect only.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigeffect_dependency = b.dependency("zigeffect", .{});
    const zigeffect = zigeffect_dependency.module("zigeffect");
    const testing_runner = zigeffect_dependency.module("zigeffect_test_runner").root_source_file.?;

    const zio_backend = b.addModule("zigeffect_zio", .{
        .root_source_file = b.path("src/zio_backend.zig"),
        .target = target,
        .optimize = optimize,
    });
    zio_backend.addImport("zigeffect", zigeffect);

    if (b.lazyDependency("zio", .{ .target = target, .optimize = optimize })) |zio| {
        zio_backend.addImport("zio", zio.module("zio"));
    }

    const tests = addV2Test(b, testing_runner, .{
        .name = "zigeffect-zio-tests",
        .root_module = zio_backend,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run zigeffect-zio adapter tests");
    test_step.dependOn(&run_tests.step);
}
