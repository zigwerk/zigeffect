const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const api = b.dependency("api", .{ .target = target, .optimize = optimize }).module("app");
    const worker = b.dependency("worker", .{ .target = target, .optimize = optimize }).module("app");
    const shared = b.dependency("shared", .{ .target = target, .optimize = optimize }).module("shared");
    const zigeffect_std_dependency = b.dependency("zigeffect_std", .{ .target = target, .optimize = optimize });
    const zigeffect_std = zigeffect_std_dependency.module("zigeffect_std");
    const testing_runner = zigeffect_std_dependency.module("zigeffect_test_runner").root_source_file.?;
    const system = b.addModule("system", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    system.addImport("api", api);
    system.addImport("worker", worker);
    system.addImport("shared", shared);
    system.addImport("zigeffect_std", zigeffect_std);
    const test_module = b.createModule(.{
        .root_source_file = b.path("test/root_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_module.addImport("system", system);
    test_module.addImport("zigeffect_std", zigeffect_std);
    const tests = b.addTest(.{ .name = "zigeffect-reference-orders-tests", .root_module = test_module, .test_runner = .{ .path = testing_runner, .mode = .server } });
    const test_step = b.step("test", "Run all local system components");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    const postgres = b.dependency("zigeffect_postgres_libpq", .{ .target = target, .optimize = optimize }).module("zigeffect_postgres_libpq");
    const redis = b.dependency("zigeffect_redis", .{ .target = target, .optimize = optimize }).module("zigeffect_redis");
    const s3 = b.dependency("zigeffect_s3", .{ .target = target, .optimize = optimize }).module("zigeffect_s3");
    const redis_port = b.option(u16, "redis-port", "Redis port") orelse 19379;
    const s3_port = b.option(u16, "s3-port", "S3 port") orelse 19001;
    const live_options = b.addOptions();
    live_options.addOption(u16, "redis_port", redis_port);
    live_options.addOption(u16, "s3_port", s3_port);
    const live_module = b.createModule(.{ .root_source_file = b.path("test/live_stack_test.zig"), .target = target, .optimize = optimize, .imports = &.{
        .{ .name = "system", .module = system }, .{ .name = "zigeffect_std", .module = zigeffect_std },
        .{ .name = "zigeffect_postgres_libpq", .module = postgres }, .{ .name = "zigeffect_redis", .module = redis }, .{ .name = "zigeffect_s3", .module = s3 },
        .{ .name = "live_options", .module = live_options.createModule() },
    } });
    const live_tests = b.addTest(.{ .name = "zigeffect-reference-live", .root_module = live_module, .test_runner = .{ .path = testing_runner, .mode = .server } });
    b.step("live-conformance", "Run the real reference stack conformance").dependOn(&b.addRunArtifact(live_tests).step);

    const collector = b.addExecutable(.{ .name = "reference-otlp-collector", .root_module = b.createModule(.{ .root_source_file = b.path("test/otlp_collector.zig"), .target = target, .optimize = optimize }) });
    b.installArtifact(collector);

    const process_evidence_module = b.createModule(.{ .root_source_file = b.path("test/process_evidence_test.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "zigeffect_std", .module = zigeffect_std }} });
    const process_evidence_tests = b.addTest(.{ .name = "zigeffect-reference-process-evidence", .root_module = process_evidence_module, .test_runner = .{ .path = testing_runner, .mode = .server } });
    b.step("process-evidence", "Publish evidence after the independent process stack passes").dependOn(&b.addRunArtifact(process_evidence_tests).step);

    const fault_module = b.createModule(.{ .root_source_file = b.path("test/fault_matrix_test.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "system", .module = system }, .{ .name = "zigeffect_std", .module = zigeffect_std } } });
    const fault_tests = b.addTest(.{ .name = "zigeffect-reference-fault-matrix", .root_module = fault_module, .test_runner = .{ .path = testing_runner, .mode = .server } });
    b.step("fault-matrix", "Run provider fault differential schedule and mutation evidence").dependOn(&b.addRunArtifact(fault_tests).step);
}
