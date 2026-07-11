const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const zigeffect_std_dependency = b.dependency("zigeffect_std", .{ .target = target, .optimize = optimize });
    const zigeffect_std = zigeffect_std_dependency.module("zigeffect_std");
    const testing_runner = zigeffect_std_dependency.module("zigeffect_test_runner").root_source_file.?;
    const zigeffect_http = b.dependency("zigeffect_http", .{ .target = target, .optimize = optimize }).module("zigeffect_http");
    const zigeffect_postgres_libpq = b.dependency("zigeffect_postgres_libpq", .{ .target = target, .optimize = optimize }).module("zigeffect_postgres_libpq");
    const zigeffect_otel = b.dependency("zigeffect_otel", .{ .target = target, .optimize = optimize }).module("zigeffect_otel");
    const zigeffect_redis = b.dependency("zigeffect_redis", .{ .target = target, .optimize = optimize }).module("zigeffect_redis");
    const zigeffect_transport = b.dependency("zigeffect_transport", .{ .target = target, .optimize = optimize }).module("zigeffect_transport");
    const zigeffect_storage_postgres = b.dependency("zigeffect_storage_postgres", .{ .target = target, .optimize = optimize }).module("zigeffect_storage_postgres");
    const shared = b.dependency("shared", .{ .target = target, .optimize = optimize }).module("shared");
    const app = b.addModule("app", .{
        .root_source_file = b.path("src/app.zig"),
        .target = target,
        .optimize = optimize,
    });
    app.addImport("zigeffect_std", zigeffect_std);
    app.addImport("zigeffect_http", zigeffect_http);
    app.addImport("zigeffect_postgres_libpq", zigeffect_postgres_libpq);
    app.addImport("zigeffect_otel", zigeffect_otel);
    app.addImport("zigeffect_redis", zigeffect_redis);
    app.addImport("zigeffect_transport", zigeffect_transport);
    app.addImport("zigeffect_storage_postgres", zigeffect_storage_postgres);
    app.addImport("shared", shared);
    const main_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    main_module.addImport("app", app);
    const executable = b.addExecutable(.{ .name = "worker", .root_module = main_module });
    b.installArtifact(executable);

    const run = b.addRunArtifact(executable);
    if (b.args) |args| run.addArgs(args);
    const run_step = b.step("run", "Run worker locally");
    run_step.dependOn(&run.step);

    const test_module = b.createModule(.{
        .root_source_file = b.path("test/root_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_module.addImport("app", app);
    test_module.addImport("zigeffect_std", zigeffect_std);
    const tests = b.addTest(.{ .name = "worker-tests", .root_module = test_module, .test_runner = .{ .path = testing_runner, .mode = .server } });
    const test_step = b.step("test", "Run worker tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
