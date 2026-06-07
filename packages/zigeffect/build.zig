const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigeffect = b.addModule("zigeffect", .{
        .root_source_file = b.path("src/zigeffect.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.createModule(.{
        .root_source_file = b.path("test/all_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.addImport("zigeffect", zigeffect);

    const unit_tests = b.addTest(.{
        .name = "zigeffect-tests",
        .root_module = tests,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run zigeffect tests");
    test_step.dependOn(&run_unit_tests.step);

    const readiness_example_module = b.createModule(.{
        .root_source_file = b.path("examples/readiness.zig"),
        .target = target,
        .optimize = optimize,
    });
    readiness_example_module.addImport("zigeffect", zigeffect);

    const readiness_example = b.addExecutable(.{
        .name = "zigeffect-readiness-example",
        .root_module = readiness_example_module,
    });

    const readiness_example_tests = b.addTest(.{
        .name = "zigeffect-readiness-example-tests",
        .root_module = readiness_example_module,
    });
    const run_readiness_example_tests = b.addRunArtifact(readiness_example_tests);

    const causal_readiness_example_module = b.createModule(.{
        .root_source_file = b.path("examples/causal_readiness.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_readiness_example_module.addImport("zigeffect", zigeffect);

    const causal_readiness_example = b.addExecutable(.{
        .name = "zigeffect-causal-readiness-example",
        .root_module = causal_readiness_example_module,
    });

    const causal_readiness_example_tests = b.addTest(.{
        .name = "zigeffect-causal-readiness-example-tests",
        .root_module = causal_readiness_example_module,
    });
    const run_causal_readiness_example_tests = b.addRunArtifact(causal_readiness_example_tests);

    const causal_missing_config_example_module = b.createModule(.{
        .root_source_file = b.path("examples/causal_missing_config.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_missing_config_example_module.addImport("zigeffect", zigeffect);

    const causal_missing_config_example = b.addExecutable(.{
        .name = "zigeffect-causal-missing-config",
        .root_module = causal_missing_config_example_module,
    });

    const causal_missing_config_example_tests = b.addTest(.{
        .name = "zigeffect-causal-missing-config-tests",
        .root_module = causal_missing_config_example_module,
    });
    const run_causal_missing_config_example_tests = b.addRunArtifact(causal_missing_config_example_tests);

    const causal_cleanup_failure_example_module = b.createModule(.{
        .root_source_file = b.path("examples/causal_cleanup_failure.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_cleanup_failure_example_module.addImport("zigeffect", zigeffect);

    const causal_cleanup_failure_example = b.addExecutable(.{
        .name = "zigeffect-causal-cleanup-failure",
        .root_module = causal_cleanup_failure_example_module,
    });

    const causal_cleanup_failure_example_tests = b.addTest(.{
        .name = "zigeffect-causal-cleanup-failure-tests",
        .root_module = causal_cleanup_failure_example_module,
    });
    const run_causal_cleanup_failure_example_tests = b.addRunArtifact(causal_cleanup_failure_example_tests);

    const causal_scoped_fiber_example_module = b.createModule(.{
        .root_source_file = b.path("examples/causal_scoped_fiber.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_scoped_fiber_example_module.addImport("zigeffect", zigeffect);

    const causal_scoped_fiber_example = b.addExecutable(.{
        .name = "zigeffect-causal-scoped-fiber",
        .root_module = causal_scoped_fiber_example_module,
    });

    const causal_scoped_fiber_example_tests = b.addTest(.{
        .name = "zigeffect-causal-scoped-fiber-tests",
        .root_module = causal_scoped_fiber_example_module,
    });
    const run_causal_scoped_fiber_example_tests = b.addRunArtifact(causal_scoped_fiber_example_tests);

    const causal_retry_exhaustion_example_module = b.createModule(.{
        .root_source_file = b.path("examples/causal_retry_exhaustion.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_retry_exhaustion_example_module.addImport("zigeffect", zigeffect);

    const causal_retry_exhaustion_example = b.addExecutable(.{
        .name = "zigeffect-causal-retry-exhaustion",
        .root_module = causal_retry_exhaustion_example_module,
    });

    const causal_retry_exhaustion_example_tests = b.addTest(.{
        .name = "zigeffect-causal-retry-exhaustion-tests",
        .root_module = causal_retry_exhaustion_example_module,
    });
    const run_causal_retry_exhaustion_example_tests = b.addRunArtifact(causal_retry_exhaustion_example_tests);

    const scaffold_module = b.createModule(.{
        .root_source_file = b.path("tools/scaffold_module.zig"),
        .target = target,
        .optimize = optimize,
    });

    const scaffold_tool = b.addExecutable(.{
        .name = "zigeffect-scaffold-module",
        .root_module = scaffold_module,
    });

    const scaffold_tool_tests = b.addTest(.{
        .name = "zigeffect-scaffold-module-tests",
        .root_module = scaffold_module,
    });
    const run_scaffold_tool_tests = b.addRunArtifact(scaffold_tool_tests);

    const causal_report_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_report.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_report_tool_module.addImport("zigeffect", zigeffect);

    const causal_report_tool = b.addExecutable(.{
        .name = "zigeffect-causal-report",
        .root_module = causal_report_tool_module,
    });
    const run_causal_report_tool = b.addRunArtifact(causal_report_tool);
    const causal_report_step = b.step("causal-report", "Print a sample causal CI report");
    causal_report_step.dependOn(&run_causal_report_tool.step);

    const causal_report_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-report-tests",
        .root_module = causal_report_tool_module,
    });
    const run_causal_report_tool_tests = b.addRunArtifact(causal_report_tool_tests);

    const causal_test_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_test_tool_module.addImport("zigeffect", zigeffect);

    const causal_test_tool = b.addExecutable(.{
        .name = "zigeffect-causal-test",
        .root_module = causal_test_tool_module,
    });
    const run_causal_test_tool = b.addRunArtifact(causal_test_tool);
    if (b.args) |args| run_causal_test_tool.addArgs(args);
    const causal_test_step = b.step("causal-test", "Run dogfood causal test harness and write artifacts");
    causal_test_step.dependOn(&run_causal_test_tool.step);

    const run_causal_check_tool = b.addRunArtifact(causal_test_tool);
    run_causal_check_tool.addArg("--fail-on-findings");
    const causal_check_step = b.step("causal-check", "Run dogfood causal check and fail when findings exist");
    causal_check_step.dependOn(&run_causal_check_tool.step);

    const causal_test_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-test-tests",
        .root_module = causal_test_tool_module,
    });
    const run_causal_test_tool_tests = b.addRunArtifact(causal_test_tool_tests);

    const causal_query_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_query.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_query_tool = b.addExecutable(.{
        .name = "zigeffect-causal-query",
        .root_module = causal_query_tool_module,
    });
    const run_causal_query_tool = b.addRunArtifact(causal_query_tool);
    if (b.args) |args| run_causal_query_tool.addArgs(args);
    const causal_query_step = b.step("causal-query", "Query a saved causal JSON artifact");
    causal_query_step.dependOn(&run_causal_query_tool.step);

    const causal_query_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-query-tests",
        .root_module = causal_query_tool_module,
    });
    const run_causal_query_tool_tests = b.addRunArtifact(causal_query_tool_tests);

    const causal_run_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_run.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_run_tool_module.addImport("zigeffect", zigeffect);

    const causal_run_tool = b.addExecutable(.{
        .name = "zigeffect-causal-run",
        .root_module = causal_run_tool_module,
    });
    const run_causal_run_tool = b.addRunArtifact(causal_run_tool);
    if (b.args) |args| run_causal_run_tool.addArgs(args);
    const causal_run_step = b.step("causal-run", "Run a zigeffect command with causal failure capture");
    causal_run_step.dependOn(&run_causal_run_tool.step);

    const run_causal_catalog_tool = b.addRunArtifact(causal_run_tool);
    run_causal_catalog_tool.addArg("catalog");
    const causal_catalog_step = b.step("causal-catalog", "Print the zigeffect causal scenario registry and invariant catalog");
    causal_catalog_step.dependOn(&run_causal_catalog_tool.step);

    const run_causal_capture_missing_service_tool = b.addRunArtifact(causal_run_tool);
    run_causal_capture_missing_service_tool.addArg("missing-service-compile-fail");
    const causal_capture_missing_service_step = b.step("causal-capture-missing-service", "Capture causal artifacts for the missing-service compile-fail scenario");
    causal_capture_missing_service_step.dependOn(&run_causal_capture_missing_service_tool.step);

    const run_causal_dev_test_tool = b.addRunArtifact(causal_run_tool);
    run_causal_dev_test_tool.addArg("package-tests");
    const causal_dev_test_step = b.step("causal-dev-test", "Run zigeffect tests with causal failure capture");
    causal_dev_test_step.dependOn(&run_causal_dev_test_tool.step);

    const causal_run_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-run-tests",
        .root_module = causal_run_tool_module,
    });
    const run_causal_run_tool_tests = b.addRunArtifact(causal_run_tool_tests);

    const examples_step = b.step("examples", "Compile and test zigeffect examples");
    examples_step.dependOn(&readiness_example.step);
    examples_step.dependOn(&run_readiness_example_tests.step);
    examples_step.dependOn(&causal_readiness_example.step);
    examples_step.dependOn(&run_causal_readiness_example_tests.step);
    examples_step.dependOn(&causal_missing_config_example.step);
    examples_step.dependOn(&run_causal_missing_config_example_tests.step);
    examples_step.dependOn(&causal_cleanup_failure_example.step);
    examples_step.dependOn(&run_causal_cleanup_failure_example_tests.step);
    examples_step.dependOn(&causal_scoped_fiber_example.step);
    examples_step.dependOn(&run_causal_scoped_fiber_example_tests.step);
    examples_step.dependOn(&causal_retry_exhaustion_example.step);
    examples_step.dependOn(&run_causal_retry_exhaustion_example_tests.step);
    examples_step.dependOn(&scaffold_tool.step);
    examples_step.dependOn(&run_scaffold_tool_tests.step);
    examples_step.dependOn(&causal_report_tool.step);
    examples_step.dependOn(&run_causal_report_tool_tests.step);
    examples_step.dependOn(&causal_test_tool.step);
    examples_step.dependOn(&run_causal_test_tool_tests.step);
    examples_step.dependOn(&causal_query_tool.step);
    examples_step.dependOn(&run_causal_query_tool_tests.step);
    examples_step.dependOn(&causal_run_tool.step);
    examples_step.dependOn(&run_causal_run_tool_tests.step);
}
