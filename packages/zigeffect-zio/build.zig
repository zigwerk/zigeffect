const std = @import("std");

// Stage 1 scaffold. The adapter module imports the core `zigeffect` package and
// implements its `AsyncBackend` vtable on top of zio. zio is a LAZY dependency:
// `zig build` only fetches it once the backend actually imports it (Stage 1).
// Until then the package builds and the skeleton compiles against zigeffect only.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigeffect = b.dependency("zigeffect", .{}).module("zigeffect");

    const zio_backend = b.addModule("zigeffect_zio", .{
        .root_source_file = b.path("src/zio_backend.zig"),
        .target = target,
        .optimize = optimize,
    });
    zio_backend.addImport("zigeffect", zigeffect);

    // Stage 1: wire zio once fetched.
    //   if (b.lazyDependency("zio", .{ .target = target, .optimize = optimize })) |zio| {
    //       zio_backend.addImport("zio", zio.module("zio"));
    //   }

    const tests = b.addTest(.{
        .root_module = zio_backend,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run zigeffect-zio adapter tests");
    test_step.dependOn(&run_tests.step);
}
