const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zig_webui = b.dependency("zig_webui", .{
        .target = target,
        .optimize = optimize,
        .enable_tls = false,
        .is_static = true,
    });

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
    const raw_test_step = b.step("test-raw", "Run zigeffect tests without causal wrapping");
    raw_test_step.dependOn(&run_unit_tests.step);

    const causal_backend_conformance_test_module = b.createModule(.{
        .root_source_file = b.path("test/causal_backend_conformance_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_backend_conformance_test_module.addImport("zigeffect", zigeffect);

    const causal_backend_conformance_tests = b.addTest(.{
        .name = "zigeffect-causal-backend-conformance-tests",
        .root_module = causal_backend_conformance_test_module,
    });
    const run_causal_backend_conformance_tests = b.addRunArtifact(causal_backend_conformance_tests);
    const causal_backend_conformance_step = b.step("causal-backend-conformance", "Run causal backend conformance contract tests");
    causal_backend_conformance_step.dependOn(&run_causal_backend_conformance_tests.step);

    const causal_jsonl_backend_test_module = b.createModule(.{
        .root_source_file = b.path("test/causal_jsonl_backend_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_jsonl_backend_test_module.addImport("zigeffect", zigeffect);

    const causal_jsonl_backend_tests = b.addTest(.{
        .name = "zigeffect-causal-jsonl-backend-tests",
        .root_module = causal_jsonl_backend_test_module,
    });
    const run_causal_jsonl_backend_tests = b.addRunArtifact(causal_jsonl_backend_tests);
    const causal_jsonl_backend_step = b.step("causal-jsonl-backend", "Run causal JSON Lines backend tests");
    causal_jsonl_backend_step.dependOn(&run_causal_jsonl_backend_tests.step);

    const causal_dot_backend_test_module = b.createModule(.{
        .root_source_file = b.path("test/causal_dot_backend_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_dot_backend_test_module.addImport("zigeffect", zigeffect);

    const causal_dot_backend_tests = b.addTest(.{
        .name = "zigeffect-causal-dot-backend-tests",
        .root_module = causal_dot_backend_test_module,
    });
    const run_causal_dot_backend_tests = b.addRunArtifact(causal_dot_backend_tests);
    const causal_dot_backend_step = b.step("causal-dot-backend", "Run causal DOT backend tests");
    causal_dot_backend_step.dependOn(&run_causal_dot_backend_tests.step);

    const causal_otel_backend_test_module = b.createModule(.{
        .root_source_file = b.path("test/causal_otel_backend_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_otel_backend_test_module.addImport("zigeffect", zigeffect);

    const causal_otel_backend_tests = b.addTest(.{
        .name = "zigeffect-causal-otel-backend-tests",
        .root_module = causal_otel_backend_test_module,
    });
    const run_causal_otel_backend_tests = b.addRunArtifact(causal_otel_backend_tests);
    const causal_otel_backend_step = b.step("causal-otel-backend", "Run causal OpenTelemetry backend tests");
    causal_otel_backend_step.dependOn(&run_causal_otel_backend_tests.step);

    const causal_graph_history_backend_test_module = b.createModule(.{
        .root_source_file = b.path("test/causal_graph_history_backend_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_graph_history_backend_test_module.addImport("zigeffect", zigeffect);

    const causal_graph_history_backend_tests = b.addTest(.{
        .name = "zigeffect-causal-graph-history-backend-tests",
        .root_module = causal_graph_history_backend_test_module,
    });
    const run_causal_graph_history_backend_tests = b.addRunArtifact(causal_graph_history_backend_tests);
    const causal_graph_history_backend_step = b.step("causal-graph-history-backend", "Run causal graph history backend tests");
    causal_graph_history_backend_step.dependOn(&run_causal_graph_history_backend_tests.step);

    const causal_nendb_storage_backend_test_module = b.createModule(.{
        .root_source_file = b.path("test/causal_nendb_storage_backend_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_nendb_storage_backend_test_module.addImport("zigeffect", zigeffect);

    const causal_nendb_storage_backend_tests = b.addTest(.{
        .name = "zigeffect-causal-nendb-storage-backend-tests",
        .root_module = causal_nendb_storage_backend_test_module,
    });
    const run_causal_nendb_storage_backend_tests = b.addRunArtifact(causal_nendb_storage_backend_tests);
    const causal_nendb_storage_backend_step = b.step("causal-nendb-storage-backend", "Run causal NenDB storage backend tests");
    causal_nendb_storage_backend_step.dependOn(&run_causal_nendb_storage_backend_tests.step);

    const causal_async_stream_backend_test_module = b.createModule(.{
        .root_source_file = b.path("test/causal_async_stream_backend_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_async_stream_backend_test_module.addImport("zigeffect", zigeffect);

    const causal_async_stream_backend_tests = b.addTest(.{
        .name = "zigeffect-causal-async-stream-backend-tests",
        .root_module = causal_async_stream_backend_test_module,
    });
    const run_causal_async_stream_backend_tests = b.addRunArtifact(causal_async_stream_backend_tests);
    const causal_async_stream_backend_step = b.step("causal-async-stream-backend", "Run causal async stream backend tests");
    causal_async_stream_backend_step.dependOn(&run_causal_async_stream_backend_tests.step);

    const causal_app_runtime_test_module = b.createModule(.{
        .root_source_file = b.path("test/causal_app_runtime_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_app_runtime_test_module.addImport("zigeffect", zigeffect);

    const causal_app_runtime_tests = b.addTest(.{
        .name = "zigeffect-causal-app-runtime-tests",
        .root_module = causal_app_runtime_test_module,
    });
    const run_causal_app_runtime_tests = b.addRunArtifact(causal_app_runtime_tests);
    const causal_app_runtime_step = b.step("causal-app-runtime", "Run causal app-facing runtime adapter tests");
    causal_app_runtime_step.dependOn(&run_causal_app_runtime_tests.step);

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

    const data_and_matching_example_module = b.createModule(.{
        .root_source_file = b.path("examples/data_and_matching.zig"),
        .target = target,
        .optimize = optimize,
    });
    data_and_matching_example_module.addImport("zigeffect", zigeffect);

    const data_and_matching_example = b.addExecutable(.{
        .name = "zigeffect-data-and-matching-example",
        .root_module = data_and_matching_example_module,
    });

    const data_and_matching_example_tests = b.addTest(.{
        .name = "zigeffect-data-and-matching-example-tests",
        .root_module = data_and_matching_example_module,
    });
    const run_data_and_matching_example_tests = b.addRunArtifact(data_and_matching_example_tests);

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

    const causal_app_request_example_module = b.createModule(.{
        .root_source_file = b.path("examples/causal_app_request.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_app_request_example_module.addImport("zigeffect", zigeffect);

    const causal_app_request_example = b.addExecutable(.{
        .name = "zigeffect-causal-app-request",
        .root_module = causal_app_request_example_module,
    });

    const causal_app_request_example_tests = b.addTest(.{
        .name = "zigeffect-causal-app-request-tests",
        .root_module = causal_app_request_example_module,
    });
    const run_causal_app_request_example_tests = b.addRunArtifact(causal_app_request_example_tests);
    const causal_app_request_example_step = b.step("causal-app-request-example", "Compile and test the causal app request example");
    causal_app_request_example_step.dependOn(&causal_app_request_example.step);
    causal_app_request_example_step.dependOn(&run_causal_app_request_example_tests.step);

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

    const causal_artifact_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_artifact.zig"),
        .target = target,
        .optimize = optimize,
    });
    const causal_artifact_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-artifact-tests",
        .root_module = causal_artifact_tool_module,
    });
    const run_causal_artifact_tool_tests = b.addRunArtifact(causal_artifact_tool_tests);

    const causal_query_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_query.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_query_tool_module.addImport("causal_artifact", causal_artifact_tool_module);

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

    const causal_advice_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_advice.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_advice_tool_module.addImport("causal_artifact", causal_artifact_tool_module);

    const causal_advice_tool = b.addExecutable(.{
        .name = "zigeffect-causal-advice",
        .root_module = causal_advice_tool_module,
    });
    const run_causal_advice_tool = b.addRunArtifact(causal_advice_tool);
    if (b.args) |args| run_causal_advice_tool.addArgs(args);
    const causal_advice_step = b.step("causal-advice", "Suggest deterministic next actions from a saved causal JSON artifact");
    causal_advice_step.dependOn(&run_causal_advice_tool.step);

    const causal_advice_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-advice-tests",
        .root_module = causal_advice_tool_module,
    });
    const run_causal_advice_tool_tests = b.addRunArtifact(causal_advice_tool_tests);

    const causal_app_remediation_audit_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_remediation_audit.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_app_remediation_audit_tool_module.addImport("causal_advice", causal_advice_tool_module);
    causal_app_remediation_audit_tool_module.addImport("causal_artifact", causal_artifact_tool_module);

    const causal_app_remediation_audit_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-remediation-audit-tests",
        .root_module = causal_app_remediation_audit_tool_module,
    });
    const run_causal_app_remediation_audit_tool_tests = b.addRunArtifact(causal_app_remediation_audit_tool_tests);

    const causal_app_policy_decision_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_policy_decision.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_policy_decision_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-policy-decision-tests",
        .root_module = causal_app_policy_decision_tool_module,
    });
    const run_causal_app_policy_decision_tool_tests = b.addRunArtifact(causal_app_policy_decision_tool_tests);

    const causal_app_patch_proposal_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_patch_proposal.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_patch_proposal_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-patch-proposal-tests",
        .root_module = causal_app_patch_proposal_tool_module,
    });
    const run_causal_app_patch_proposal_tool_tests = b.addRunArtifact(causal_app_patch_proposal_tool_tests);

    const causal_compare_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_compare.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_compare_tool_module.addImport("causal_artifact", causal_artifact_tool_module);

    const causal_compare_tool = b.addExecutable(.{
        .name = "zigeffect-causal-compare",
        .root_module = causal_compare_tool_module,
    });
    const run_causal_compare_tool = b.addRunArtifact(causal_compare_tool);
    if (b.args) |args| run_causal_compare_tool.addArgs(args);
    const causal_compare_step = b.step("causal-compare", "Compare two saved causal JSON artifacts");
    causal_compare_step.dependOn(&run_causal_compare_tool.step);

    const causal_compare_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-compare-tests",
        .root_module = causal_compare_tool_module,
    });
    const run_causal_compare_tool_tests = b.addRunArtifact(causal_compare_tool_tests);

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

    const run_causal_package_failure_fixture_tool = b.addRunArtifact(causal_run_tool);
    run_causal_package_failure_fixture_tool.addArg("package-tests-failure-fixture");
    const causal_package_failure_fixture_step = b.step("causal-package-failure-fixture", "Capture causal artifacts for an intentional package-test failure fixture");
    causal_package_failure_fixture_step.dependOn(&run_causal_package_failure_fixture_tool.step);

    const run_causal_package_test_tool = b.addRunArtifact(causal_run_tool);
    run_causal_package_test_tool.addArg("package-tests");
    const test_step = b.step("test", "Run zigeffect tests with causal failure capture");
    test_step.dependOn(&run_causal_package_test_tool.step);
    test_step.dependOn(&run_causal_artifact_tool_tests.step);
    test_step.dependOn(&run_causal_backend_conformance_tests.step);
    test_step.dependOn(&run_causal_jsonl_backend_tests.step);
    test_step.dependOn(&run_causal_dot_backend_tests.step);
    test_step.dependOn(&run_causal_otel_backend_tests.step);
    test_step.dependOn(&run_causal_graph_history_backend_tests.step);
    test_step.dependOn(&run_causal_nendb_storage_backend_tests.step);
    test_step.dependOn(&run_causal_async_stream_backend_tests.step);
    test_step.dependOn(&run_causal_app_runtime_tests.step);
    test_step.dependOn(&run_causal_app_patch_proposal_tool_tests.step);
    const causal_dev_test_step = b.step("causal-dev-test", "Run zigeffect tests with causal failure capture");
    causal_dev_test_step.dependOn(&run_causal_package_test_tool.step);

    const causal_run_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-run-tests",
        .root_module = causal_run_tool_module,
    });
    const run_causal_run_tool_tests = b.addRunArtifact(causal_run_tool_tests);

    const causal_snapshot_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_snapshot.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_snapshot_tool_module.addImport("causal_artifact", causal_artifact_tool_module);
    causal_snapshot_tool_module.addImport("causal_compare", causal_compare_tool_module);
    causal_snapshot_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_snapshot_tool = b.addExecutable(.{
        .name = "zigeffect-causal-snapshot",
        .root_module = causal_snapshot_tool_module,
    });
    const run_causal_snapshot_tool = b.addRunArtifact(causal_snapshot_tool);
    if (b.args) |args| run_causal_snapshot_tool.addArgs(args);
    const causal_snapshot_step = b.step("causal-snapshot", "Format or capture named causal snapshot manifests");
    causal_snapshot_step.dependOn(&run_causal_snapshot_tool.step);

    const causal_snapshot_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-snapshot-tests",
        .root_module = causal_snapshot_tool_module,
    });
    const run_causal_snapshot_tool_tests = b.addRunArtifact(causal_snapshot_tool_tests);

    const causal_test_matrix_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_test_matrix.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_test_matrix_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_test_matrix_tool = b.addExecutable(.{
        .name = "zigeffect-causal-test-matrix",
        .root_module = causal_test_matrix_tool_module,
    });
    const run_causal_test_matrix_tool = b.addRunArtifact(causal_test_matrix_tool);
    const causal_test_matrix_step = b.step("causal-test-matrix", "Print the zigeffect causal scenario coverage matrix");
    causal_test_matrix_step.dependOn(&run_causal_test_matrix_tool.step);

    const causal_test_matrix_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-test-matrix-tests",
        .root_module = causal_test_matrix_tool_module,
    });
    const run_causal_test_matrix_tool_tests = b.addRunArtifact(causal_test_matrix_tool_tests);
    test_step.dependOn(&run_causal_test_matrix_tool_tests.step);

    const causal_artifacts_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_artifacts.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_artifacts_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_artifacts_tool = b.addExecutable(.{
        .name = "zigeffect-causal-artifacts",
        .root_module = causal_artifacts_tool_module,
    });
    const run_causal_artifacts_tool = b.addRunArtifact(causal_artifacts_tool);
    const causal_artifacts_step = b.step("causal-artifacts", "Print causal artifact retention manifest for agents and CI");
    causal_artifacts_step.dependOn(&run_causal_artifacts_tool.step);

    const causal_artifacts_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-artifacts-tests",
        .root_module = causal_artifacts_tool_module,
    });
    const run_causal_artifacts_tool_tests = b.addRunArtifact(causal_artifacts_tool_tests);

    const causal_workbench_session_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_workbench_session.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_workbench_session_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-workbench-session-tests",
        .root_module = causal_workbench_session_tool_module,
    });
    const run_causal_workbench_session_tool_tests = b.addRunArtifact(causal_workbench_session_tool_tests);
    test_step.dependOn(&run_causal_workbench_session_tool_tests.step);

    const causal_workbench_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_workbench.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_workbench_tool_module.addImport("causal_workbench_session", causal_workbench_session_tool_module);
    causal_workbench_tool_module.addImport("webui", zig_webui.module("webui"));

    const causal_workbench_tool = b.addExecutable(.{
        .name = "zigeffect-causal-workbench",
        .root_module = causal_workbench_tool_module,
    });

    const run_causal_workbench_ui_build = b.addSystemCommand(&.{ "bun", "run", "zigeffect:workbench:build" });
    run_causal_workbench_ui_build.setCwd(.{ .cwd_relative = "../.." });
    const causal_workbench_ui_step = b.step("causal-workbench-ui", "Build the Solid causal workbench UI");
    causal_workbench_ui_step.dependOn(&run_causal_workbench_ui_build.step);

    const run_causal_workbench_tool = b.addRunArtifact(causal_workbench_tool);
    run_causal_workbench_tool.step.dependOn(&run_causal_workbench_ui_build.step);
    if (b.args) |args| run_causal_workbench_tool.addArgs(args);
    const causal_workbench_step = b.step("causal-workbench", "Open the read-only Solid causal workbench through zig-webui");
    causal_workbench_step.dependOn(&run_causal_workbench_tool.step);

    const causal_verdict_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_verdict.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_verdict_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-verdict-tests",
        .root_module = causal_verdict_tool_module,
    });
    const run_causal_verdict_tool_tests = b.addRunArtifact(causal_verdict_tool_tests);

    const causal_dev_agent_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_dev_agent.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_dev_agent_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_dev_agent_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-dev-agent-tests",
        .root_module = causal_dev_agent_tool_module,
    });
    const run_causal_dev_agent_tool_tests = b.addRunArtifact(causal_dev_agent_tool_tests);

    const causal_dev_session_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_dev_session.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_dev_session_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_dev_session_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-dev-session-tests",
        .root_module = causal_dev_session_tool_module,
    });
    const run_causal_dev_session_tool_tests = b.addRunArtifact(causal_dev_session_tool_tests);

    const causal_dev_session_tool = b.addExecutable(.{
        .name = "zigeffect-causal-dev-session",
        .root_module = causal_dev_session_tool_module,
    });
    const run_causal_dev_session_tool = b.addRunArtifact(causal_dev_session_tool);
    if (b.args) |args| run_causal_dev_session_tool.addArgs(args);
    const causal_dev_session_step = b.step("causal-dev-session", "Run the local causal development session coordinator");
    causal_dev_session_step.dependOn(&run_causal_dev_session_tool.step);

    const causal_dev_agent_tool = b.addExecutable(.{
        .name = "zigeffect-causal-dev-agent",
        .root_module = causal_dev_agent_tool_module,
    });
    const run_causal_dev_agent_tool = b.addRunArtifact(causal_dev_agent_tool);
    if (b.args) |args| run_causal_dev_agent_tool.addArgs(args);
    const causal_dev_agent_step = b.step("causal-dev-agent", "Read a causal dev-loop verdict and print the next agent inspection plan");
    causal_dev_agent_step.dependOn(&run_causal_dev_agent_tool.step);

    const causal_diagnosis_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_diagnosis.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_diagnosis_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_diagnosis_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-diagnosis-tests",
        .root_module = causal_diagnosis_tool_module,
    });
    const run_causal_diagnosis_tool_tests = b.addRunArtifact(causal_diagnosis_tool_tests);

    const causal_remediation_plan_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_remediation_plan.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_remediation_plan_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_remediation_plan_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-remediation-plan-tests",
        .root_module = causal_remediation_plan_tool_module,
    });
    const run_causal_remediation_plan_tool_tests = b.addRunArtifact(causal_remediation_plan_tool_tests);

    const causal_remediation_audit_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_remediation_audit.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_remediation_audit_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_remediation_audit_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-remediation-audit-tests",
        .root_module = causal_remediation_audit_tool_module,
    });
    const run_causal_remediation_audit_tool_tests = b.addRunArtifact(causal_remediation_audit_tool_tests);

    const causal_remediation_decision_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_remediation_decision.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_remediation_decision_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_remediation_decision_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-remediation-decision-tests",
        .root_module = causal_remediation_decision_tool_module,
    });
    const run_causal_remediation_decision_tool_tests = b.addRunArtifact(causal_remediation_decision_tool_tests);

    const causal_patch_proposal_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_patch_proposal.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_patch_proposal_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_patch_proposal_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-patch-proposal-tests",
        .root_module = causal_patch_proposal_tool_module,
    });
    const run_causal_patch_proposal_tool_tests = b.addRunArtifact(causal_patch_proposal_tool_tests);

    const causal_audit_chain_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_audit_chain.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_audit_chain_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_audit_chain_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-audit-chain-tests",
        .root_module = causal_audit_chain_tool_module,
    });
    const run_causal_audit_chain_tool_tests = b.addRunArtifact(causal_audit_chain_tool_tests);

    const causal_scenario_proposal_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_scenario_proposal.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_scenario_proposal_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_scenario_proposal_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-scenario-proposal-tests",
        .root_module = causal_scenario_proposal_tool_module,
    });
    const run_causal_scenario_proposal_tool_tests = b.addRunArtifact(causal_scenario_proposal_tool_tests);

    const causal_scenario_registry_patch_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_scenario_registry_patch.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_scenario_registry_patch_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_scenario_registry_patch_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-scenario-registry-patch-tests",
        .root_module = causal_scenario_registry_patch_tool_module,
    });
    const run_causal_scenario_registry_patch_tool_tests = b.addRunArtifact(causal_scenario_registry_patch_tool_tests);

    const causal_registry_application_readiness_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_registry_application_readiness.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_registry_application_readiness_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_registry_application_readiness_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-registry-application-readiness-tests",
        .root_module = causal_registry_application_readiness_tool_module,
    });
    const run_causal_registry_application_readiness_tool_tests = b.addRunArtifact(causal_registry_application_readiness_tool_tests);

    const causal_registry_apply_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_registry_apply.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_registry_apply_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_registry_apply_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-registry-apply-tests",
        .root_module = causal_registry_apply_tool_module,
    });
    const run_causal_registry_apply_tool_tests = b.addRunArtifact(causal_registry_apply_tool_tests);
    const causal_policy_decision_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_policy_decision.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_policy_decision_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_policy_decision_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-policy-decision-tests",
        .root_module = causal_policy_decision_tool_module,
    });
    const run_causal_policy_decision_tool_tests = b.addRunArtifact(causal_policy_decision_tool_tests);
    test_step.dependOn(&run_causal_policy_decision_tool_tests.step);

    const causal_diagnosis_tool = b.addExecutable(.{
        .name = "zigeffect-causal-diagnosis",
        .root_module = causal_diagnosis_tool_module,
    });
    const run_causal_diagnosis_tool = b.addRunArtifact(causal_diagnosis_tool);
    if (b.args) |args| run_causal_diagnosis_tool.addArgs(args);
    const causal_diagnosis_step = b.step("causal-diagnosis", "Read local causal dev-loop reports and write a patch-ready diagnosis");
    causal_diagnosis_step.dependOn(&run_causal_diagnosis_tool.step);

    const causal_remediation_plan_tool = b.addExecutable(.{
        .name = "zigeffect-causal-remediation-plan",
        .root_module = causal_remediation_plan_tool_module,
    });
    const run_causal_remediation_plan_tool = b.addRunArtifact(causal_remediation_plan_tool);
    if (b.args) |args| run_causal_remediation_plan_tool.addArgs(args);
    const causal_remediation_plan_step = b.step("causal-remediation-plan", "Write a causal remediation plan from local dev-loop reports");
    causal_remediation_plan_step.dependOn(&run_causal_remediation_plan_tool.step);

    const causal_remediation_audit_tool = b.addExecutable(.{
        .name = "zigeffect-causal-remediation-audit",
        .root_module = causal_remediation_audit_tool_module,
    });
    const run_causal_remediation_audit_tool = b.addRunArtifact(causal_remediation_audit_tool);
    if (b.args) |args| run_causal_remediation_audit_tool.addArgs(args);
    const causal_remediation_audit_step = b.step("causal-remediation-audit", "Write a pending causal remediation audit from local dev-loop reports");
    causal_remediation_audit_step.dependOn(&run_causal_remediation_audit_tool.step);

    const causal_app_remediation_audit_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-remediation-audit",
        .root_module = causal_app_remediation_audit_tool_module,
    });
    const run_causal_app_remediation_audit_tool = b.addRunArtifact(causal_app_remediation_audit_tool);
    if (b.args) |args| run_causal_app_remediation_audit_tool.addArgs(args);
    const causal_app_remediation_audit_step = b.step("causal-app-remediation-audit", "Write a pending app remediation audit from an app causal artifact");
    causal_app_remediation_audit_step.dependOn(&run_causal_app_remediation_audit_tool.step);

    const causal_app_policy_decision_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-policy-decision",
        .root_module = causal_app_policy_decision_tool_module,
    });
    const run_causal_app_policy_decision_tool = b.addRunArtifact(causal_app_policy_decision_tool);
    if (b.args) |args| run_causal_app_policy_decision_tool.addArgs(args);
    const causal_app_policy_decision_step = b.step("causal-app-policy-decision", "Evaluate app remediation audit policy gates");
    causal_app_policy_decision_step.dependOn(&run_causal_app_policy_decision_tool.step);

    const causal_app_patch_proposal_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-patch-proposal",
        .root_module = causal_app_patch_proposal_tool_module,
    });
    const run_causal_app_patch_proposal_tool = b.addRunArtifact(causal_app_patch_proposal_tool);
    if (b.args) |args| run_causal_app_patch_proposal_tool.addArgs(args);
    const causal_app_patch_proposal_step = b.step("causal-app-patch-proposal", "Write a non-mutating app patch proposal from an app policy decision");
    causal_app_patch_proposal_step.dependOn(&run_causal_app_patch_proposal_tool.step);

    const causal_remediation_decision_tool = b.addExecutable(.{
        .name = "zigeffect-causal-remediation-decision",
        .root_module = causal_remediation_decision_tool_module,
    });
    const run_causal_remediation_decision_tool = b.addRunArtifact(causal_remediation_decision_tool);
    if (b.args) |args| run_causal_remediation_decision_tool.addArgs(args);
    const causal_remediation_decision_step = b.step("causal-remediation-decision", "Approve or reject a pending causal remediation audit");
    causal_remediation_decision_step.dependOn(&run_causal_remediation_decision_tool.step);

    const causal_patch_proposal_tool = b.addExecutable(.{
        .name = "zigeffect-causal-patch-proposal",
        .root_module = causal_patch_proposal_tool_module,
    });
    const run_causal_patch_proposal_tool = b.addRunArtifact(causal_patch_proposal_tool);
    if (b.args) |args| run_causal_patch_proposal_tool.addArgs(args);
    const causal_patch_proposal_step = b.step("causal-patch-proposal", "Write a non-mutating causal patch proposal from audit or decision evidence");
    causal_patch_proposal_step.dependOn(&run_causal_patch_proposal_tool.step);

    const causal_audit_chain_tool = b.addExecutable(.{
        .name = "zigeffect-causal-audit-chain",
        .root_module = causal_audit_chain_tool_module,
    });
    const run_causal_audit_chain_tool = b.addRunArtifact(causal_audit_chain_tool);
    if (b.args) |args| run_causal_audit_chain_tool.addArgs(args);
    const causal_audit_chain_step = b.step("causal-audit-chain", "Compare local causal remediation chain evidence before and after a patch");
    causal_audit_chain_step.dependOn(&run_causal_audit_chain_tool.step);

    const causal_scenario_proposal_tool = b.addExecutable(.{
        .name = "zigeffect-causal-scenario-proposal",
        .root_module = causal_scenario_proposal_tool_module,
    });
    const run_causal_scenario_proposal_tool = b.addRunArtifact(causal_scenario_proposal_tool);
    if (b.args) |args| run_causal_scenario_proposal_tool.addArgs(args);
    const causal_scenario_proposal_step = b.step("causal-scenario-proposal", "Write a read-only causal scenario learning proposal");
    causal_scenario_proposal_step.dependOn(&run_causal_scenario_proposal_tool.step);

    const causal_scenario_registry_patch_tool = b.addExecutable(.{
        .name = "zigeffect-causal-scenario-registry-patch",
        .root_module = causal_scenario_registry_patch_tool_module,
    });
    const run_causal_scenario_registry_patch_tool = b.addRunArtifact(causal_scenario_registry_patch_tool);
    if (b.args) |args| run_causal_scenario_registry_patch_tool.addArgs(args);
    const causal_scenario_registry_patch_step = b.step("causal-scenario-registry-patch", "Write a reviewable causal scenario registry patch draft");
    causal_scenario_registry_patch_step.dependOn(&run_causal_scenario_registry_patch_tool.step);

    const causal_registry_application_readiness_tool = b.addExecutable(.{
        .name = "zigeffect-causal-registry-application-readiness",
        .root_module = causal_registry_application_readiness_tool_module,
    });
    const run_causal_registry_application_readiness_tool = b.addRunArtifact(causal_registry_application_readiness_tool);
    if (b.args) |args| run_causal_registry_application_readiness_tool.addArgs(args);
    const causal_registry_application_readiness_step = b.step("causal-registry-application-readiness", "Write a policy-controlled causal registry application readiness report");
    causal_registry_application_readiness_step.dependOn(&run_causal_registry_application_readiness_tool.step);

    const causal_registry_apply_tool = b.addExecutable(.{
        .name = "zigeffect-causal-registry-apply",
        .root_module = causal_registry_apply_tool_module,
    });
    const run_causal_registry_apply_tool = b.addRunArtifact(causal_registry_apply_tool);
    if (b.args) |args| run_causal_registry_apply_tool.addArgs(args);
    const causal_registry_apply_step = b.step("causal-registry-apply", "Write a guarded causal registry application report");
    causal_registry_apply_step.dependOn(&run_causal_registry_apply_tool.step);

    const causal_policy_decision_tool = b.addExecutable(.{
        .name = "zigeffect-causal-policy-decision",
        .root_module = causal_policy_decision_tool_module,
    });
    const run_causal_policy_decision_tool = b.addRunArtifact(causal_policy_decision_tool);
    if (b.args) |args| run_causal_policy_decision_tool.addArgs(args);
    const causal_policy_decision_step = b.step("causal-policy-decision", "Write a deterministic causal policy decision report");
    causal_policy_decision_step.dependOn(&run_causal_policy_decision_tool.step);

    const causal_handoff_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_handoff.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_handoff_tool_module.addImport("causal_run", causal_run_tool_module);
    causal_handoff_tool_module.addImport("causal_advice", causal_advice_tool_module);
    causal_handoff_tool_module.addImport("causal_compare", causal_compare_tool_module);
    causal_handoff_tool_module.addImport("causal_verdict", causal_verdict_tool_module);

    const causal_handoff_tool = b.addExecutable(.{
        .name = "zigeffect-causal-handoff",
        .root_module = causal_handoff_tool_module,
    });
    const run_causal_handoff_tool = b.addRunArtifact(causal_handoff_tool);
    const causal_handoff_step = b.step("causal-ci-handoff", "Write causal CI handoff report for agents");
    causal_handoff_step.dependOn(&run_causal_handoff_tool.step);

    const causal_handoff_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-handoff-tests",
        .root_module = causal_handoff_tool_module,
    });
    const run_causal_handoff_tool_tests = b.addRunArtifact(causal_handoff_tool_tests);

    const causal_loop_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_loop.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_loop_tool_module.addImport("causal_test", causal_test_tool_module);
    causal_loop_tool_module.addImport("causal_compare", causal_compare_tool_module);
    causal_loop_tool_module.addImport("causal_query", causal_query_tool_module);
    causal_loop_tool_module.addImport("causal_advice", causal_advice_tool_module);
    causal_loop_tool_module.addImport("causal_run", causal_run_tool_module);
    causal_loop_tool_module.addImport("causal_artifact", causal_artifact_tool_module);
    causal_loop_tool_module.addImport("causal_verdict", causal_verdict_tool_module);

    const causal_loop_tool = b.addExecutable(.{
        .name = "zigeffect-causal-loop",
        .root_module = causal_loop_tool_module,
    });
    const run_causal_loop_tool = b.addRunArtifact(causal_loop_tool);
    if (b.args) |args| run_causal_loop_tool.addArgs(args);
    const causal_loop_step = b.step("causal-dev-loop", "Run the zigeffect causal development loop");
    causal_loop_step.dependOn(&run_causal_loop_tool.step);

    const causal_loop_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-loop-tests",
        .root_module = causal_loop_tool_module,
    });
    const run_causal_loop_tool_tests = b.addRunArtifact(causal_loop_tool_tests);

    const examples_step = b.step("examples", "Compile and test zigeffect examples");
    examples_step.dependOn(&readiness_example.step);
    examples_step.dependOn(&run_readiness_example_tests.step);
    examples_step.dependOn(&data_and_matching_example.step);
    examples_step.dependOn(&run_data_and_matching_example_tests.step);
    examples_step.dependOn(&causal_readiness_example.step);
    examples_step.dependOn(&run_causal_readiness_example_tests.step);
    examples_step.dependOn(&causal_app_request_example.step);
    examples_step.dependOn(&run_causal_app_request_example_tests.step);
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
    examples_step.dependOn(&run_causal_artifact_tool_tests.step);
    examples_step.dependOn(&causal_query_tool.step);
    examples_step.dependOn(&run_causal_query_tool_tests.step);
    examples_step.dependOn(&causal_advice_tool.step);
    examples_step.dependOn(&run_causal_advice_tool_tests.step);
    examples_step.dependOn(&causal_compare_tool.step);
    examples_step.dependOn(&run_causal_compare_tool_tests.step);
    examples_step.dependOn(&causal_run_tool.step);
    examples_step.dependOn(&run_causal_run_tool_tests.step);
    examples_step.dependOn(&causal_snapshot_tool.step);
    examples_step.dependOn(&run_causal_snapshot_tool_tests.step);
    examples_step.dependOn(&causal_test_matrix_tool.step);
    examples_step.dependOn(&run_causal_test_matrix_tool_tests.step);
    examples_step.dependOn(&causal_artifacts_tool.step);
    examples_step.dependOn(&run_causal_artifacts_tool_tests.step);
    examples_step.dependOn(&run_causal_workbench_session_tool_tests.step);
    examples_step.dependOn(&causal_workbench_tool.step);
    examples_step.dependOn(&run_causal_verdict_tool_tests.step);
    examples_step.dependOn(&causal_dev_agent_tool.step);
    examples_step.dependOn(&run_causal_dev_agent_tool_tests.step);
    examples_step.dependOn(&causal_dev_session_tool.step);
    examples_step.dependOn(&run_causal_dev_session_tool_tests.step);
    examples_step.dependOn(&causal_diagnosis_tool.step);
    examples_step.dependOn(&run_causal_diagnosis_tool_tests.step);
    examples_step.dependOn(&causal_remediation_plan_tool.step);
    examples_step.dependOn(&run_causal_remediation_plan_tool_tests.step);
    examples_step.dependOn(&causal_remediation_audit_tool.step);
    examples_step.dependOn(&run_causal_remediation_audit_tool_tests.step);
    examples_step.dependOn(&causal_app_remediation_audit_tool.step);
    examples_step.dependOn(&run_causal_app_remediation_audit_tool_tests.step);
    examples_step.dependOn(&causal_app_policy_decision_tool.step);
    examples_step.dependOn(&run_causal_app_policy_decision_tool_tests.step);
    examples_step.dependOn(&causal_app_patch_proposal_tool.step);
    examples_step.dependOn(&run_causal_app_patch_proposal_tool_tests.step);
    examples_step.dependOn(&causal_remediation_decision_tool.step);
    examples_step.dependOn(&run_causal_remediation_decision_tool_tests.step);
    examples_step.dependOn(&causal_patch_proposal_tool.step);
    examples_step.dependOn(&run_causal_patch_proposal_tool_tests.step);
    examples_step.dependOn(&causal_audit_chain_tool.step);
    examples_step.dependOn(&run_causal_audit_chain_tool_tests.step);
    examples_step.dependOn(&causal_scenario_proposal_tool.step);
    examples_step.dependOn(&run_causal_scenario_proposal_tool_tests.step);
    examples_step.dependOn(&causal_scenario_registry_patch_tool.step);
    examples_step.dependOn(&run_causal_scenario_registry_patch_tool_tests.step);
    examples_step.dependOn(&causal_registry_application_readiness_tool.step);
    examples_step.dependOn(&run_causal_registry_application_readiness_tool_tests.step);
    examples_step.dependOn(&causal_registry_apply_tool.step);
    examples_step.dependOn(&run_causal_registry_apply_tool_tests.step);
    examples_step.dependOn(&causal_policy_decision_tool.step);
    examples_step.dependOn(&run_causal_policy_decision_tool_tests.step);
    examples_step.dependOn(&causal_handoff_tool.step);
    examples_step.dependOn(&run_causal_handoff_tool_tests.step);
    examples_step.dependOn(&causal_loop_tool.step);
    examples_step.dependOn(&run_causal_loop_tool_tests.step);
}
