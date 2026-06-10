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

    const storage_conformance_test_module = b.createModule(.{
        .root_source_file = b.path("test/storage_conformance_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    storage_conformance_test_module.addImport("zigeffect", zigeffect);

    const storage_conformance_tests = b.addTest(.{
        .name = "zigeffect-storage-conformance-tests",
        .root_module = storage_conformance_test_module,
    });
    const run_storage_conformance_tests = b.addRunArtifact(storage_conformance_tests);
    const storage_conformance_step = b.step("storage-conformance", "Run workflow and cluster storage conformance contract tests");
    storage_conformance_step.dependOn(&run_storage_conformance_tests.step);

    const property_history_test_module = b.createModule(.{
        .root_source_file = b.path("test/property_history_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    property_history_test_module.addImport("zigeffect", zigeffect);

    const property_history_tests = b.addTest(.{
        .name = "zigeffect-property-history-tests",
        .root_module = property_history_test_module,
    });
    const run_property_history_tests = b.addRunArtifact(property_history_tests);

    const crash_recovery_property_test_module = b.createModule(.{
        .root_source_file = b.path("test/crash_recovery_property_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    crash_recovery_property_test_module.addImport("zigeffect", zigeffect);

    const crash_recovery_property_tests = b.addTest(.{
        .name = "zigeffect-crash-recovery-property-tests",
        .root_module = crash_recovery_property_test_module,
    });
    const run_crash_recovery_property_tests = b.addRunArtifact(crash_recovery_property_tests);

    const message_history_property_test_module = b.createModule(.{
        .root_source_file = b.path("test/message_history_property_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    message_history_property_test_module.addImport("zigeffect", zigeffect);

    const message_history_property_tests = b.addTest(.{
        .name = "zigeffect-message-history-property-tests",
        .root_module = message_history_property_test_module,
    });
    const run_message_history_property_tests = b.addRunArtifact(message_history_property_tests);

    const scheduler_fairness_property_test_module = b.createModule(.{
        .root_source_file = b.path("test/scheduler_fairness_property_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    scheduler_fairness_property_test_module.addImport("zigeffect", zigeffect);

    const scheduler_fairness_property_tests = b.addTest(.{
        .name = "zigeffect-scheduler-fairness-property-tests",
        .root_module = scheduler_fairness_property_test_module,
    });
    const run_scheduler_fairness_property_tests = b.addRunArtifact(scheduler_fairness_property_tests);

    const property_crash_step = b.step("property-crash", "Run generated workflow, message, crash, and scheduler property tests");
    property_crash_step.dependOn(&run_property_history_tests.step);
    property_crash_step.dependOn(&run_crash_recovery_property_tests.step);
    property_crash_step.dependOn(&run_message_history_property_tests.step);
    property_crash_step.dependOn(&run_scheduler_fairness_property_tests.step);

    const performance_benchmark_test_module = b.createModule(.{
        .root_source_file = b.path("test/performance_benchmark_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    performance_benchmark_test_module.addImport("zigeffect", zigeffect);

    const performance_benchmark_tests = b.addTest(.{
        .name = "zigeffect-performance-benchmark-tests",
        .root_module = performance_benchmark_test_module,
    });
    const run_performance_benchmark_tests = b.addRunArtifact(performance_benchmark_tests);

    const resource_bounds_test_module = b.createModule(.{
        .root_source_file = b.path("test/resource_bounds_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    resource_bounds_test_module.addImport("zigeffect", zigeffect);

    const resource_bounds_tests = b.addTest(.{
        .name = "zigeffect-resource-bounds-tests",
        .root_module = resource_bounds_test_module,
    });
    const run_resource_bounds_tests = b.addRunArtifact(resource_bounds_tests);

    const workflow_snapshot_frequency_test_module = b.createModule(.{
        .root_source_file = b.path("test/workflow_snapshot_frequency_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    workflow_snapshot_frequency_test_module.addImport("zigeffect", zigeffect);

    const workflow_snapshot_frequency_tests = b.addTest(.{
        .name = "zigeffect-workflow-snapshot-frequency-tests",
        .root_module = workflow_snapshot_frequency_test_module,
    });
    const run_workflow_snapshot_frequency_tests = b.addRunArtifact(workflow_snapshot_frequency_tests);

    const cluster_observability_test_module = b.createModule(.{
        .root_source_file = b.path("test/cluster_observability_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    cluster_observability_test_module.addImport("zigeffect", zigeffect);

    const cluster_observability_tests = b.addTest(.{
        .name = "zigeffect-cluster-observability-tests",
        .root_module = cluster_observability_test_module,
    });
    const run_cluster_observability_tests = b.addRunArtifact(cluster_observability_tests);

    const performance_bounds_step = b.step("performance-bounds", "Run performance benchmark and bounded resource tests");
    performance_bounds_step.dependOn(&run_performance_benchmark_tests.step);
    performance_bounds_step.dependOn(&run_resource_bounds_tests.step);
    performance_bounds_step.dependOn(&run_workflow_snapshot_frequency_tests.step);
    performance_bounds_step.dependOn(&run_cluster_observability_tests.step);

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

    const workflow_approval_example_module = b.createModule(.{
        .root_source_file = b.path("examples/workflow_approval.zig"),
        .target = target,
        .optimize = optimize,
    });
    workflow_approval_example_module.addImport("zigeffect", zigeffect);

    const workflow_approval_example = b.addExecutable(.{
        .name = "zigeffect-workflow-approval-example",
        .root_module = workflow_approval_example_module,
    });

    const workflow_approval_example_tests = b.addTest(.{
        .name = "zigeffect-workflow-approval-example-tests",
        .root_module = workflow_approval_example_module,
    });
    const run_workflow_approval_example_tests = b.addRunArtifact(workflow_approval_example_tests);

    const workflow_queue_worker_example_module = b.createModule(.{
        .root_source_file = b.path("examples/workflow_queue_worker.zig"),
        .target = target,
        .optimize = optimize,
    });
    workflow_queue_worker_example_module.addImport("zigeffect", zigeffect);

    const workflow_queue_worker_example = b.addExecutable(.{
        .name = "zigeffect-workflow-queue-worker-example",
        .root_module = workflow_queue_worker_example_module,
    });

    const workflow_queue_worker_example_tests = b.addTest(.{
        .name = "zigeffect-workflow-queue-worker-example-tests",
        .root_module = workflow_queue_worker_example_module,
    });
    const run_workflow_queue_worker_example_tests = b.addRunArtifact(workflow_queue_worker_example_tests);

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

    const cluster_runner_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/cluster_runner.zig"),
        .target = target,
        .optimize = optimize,
    });
    cluster_runner_tool_module.addImport("zigeffect", zigeffect);

    const cluster_runner_tool = b.addExecutable(.{
        .name = "zigeffect-cluster-runner",
        .root_module = cluster_runner_tool_module,
    });
    const run_cluster_runner_tool = b.addRunArtifact(cluster_runner_tool);
    if (b.args) |args| run_cluster_runner_tool.addArgs(args);
    const cluster_runner_step = b.step("cluster-runner", "Run a local zigeffect cluster runner");
    cluster_runner_step.dependOn(&run_cluster_runner_tool.step);

    const cluster_runner_tool_tests = b.addTest(.{
        .name = "zigeffect-cluster-runner-tests",
        .root_module = cluster_runner_tool_module,
    });
    const run_cluster_runner_tool_tests = b.addRunArtifact(cluster_runner_tool_tests);

    const storage_migrate_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/storage_migrate.zig"),
        .target = target,
        .optimize = optimize,
    });
    storage_migrate_tool_module.addImport("zigeffect", zigeffect);

    const storage_migrate_tool = b.addExecutable(.{
        .name = "zigeffect-storage-migrate",
        .root_module = storage_migrate_tool_module,
    });
    const run_storage_migrate_tool = b.addRunArtifact(storage_migrate_tool);
    if (b.args) |args| run_storage_migrate_tool.addArgs(args);
    const storage_migrate_step = b.step("storage-migrate", "Print zigeffect storage schema and SQL migration plans");
    storage_migrate_step.dependOn(&run_storage_migrate_tool.step);

    const storage_migrate_tool_tests = b.addTest(.{
        .name = "zigeffect-storage-migrate-tests",
        .root_module = storage_migrate_tool_module,
    });
    const run_storage_migrate_tool_tests = b.addRunArtifact(storage_migrate_tool_tests);

    const performance_bench_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/performance_bench.zig"),
        .target = target,
        .optimize = optimize,
    });
    performance_bench_tool_module.addImport("zigeffect", zigeffect);

    const performance_bench_tool = b.addExecutable(.{
        .name = "zigeffect-performance-bench",
        .root_module = performance_bench_tool_module,
    });
    const run_performance_bench_tool = b.addRunArtifact(performance_bench_tool);
    if (b.args) |args| run_performance_bench_tool.addArgs(args);
    const performance_bench_step = b.step("performance-bench", "Print deterministic zigeffect performance benchmark report");
    performance_bench_step.dependOn(&run_performance_bench_tool.step);

    const performance_bench_tool_tests = b.addTest(.{
        .name = "zigeffect-performance-bench-tests",
        .root_module = performance_bench_tool_module,
    });
    const run_performance_bench_tool_tests = b.addRunArtifact(performance_bench_tool_tests);

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

    const workflow_tool_support_module = b.createModule(.{
        .root_source_file = b.path("tools/workflow_tool_support.zig"),
        .target = target,
        .optimize = optimize,
    });
    workflow_tool_support_module.addImport("zigeffect", zigeffect);

    const workflow_tool_support_tests = b.addTest(.{
        .name = "zigeffect-workflow-tool-support-tests",
        .root_module = workflow_tool_support_module,
    });
    const run_workflow_tool_support_tests = b.addRunArtifact(workflow_tool_support_tests);

    const workflow_list_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/workflow_list.zig"),
        .target = target,
        .optimize = optimize,
    });
    workflow_list_tool_module.addImport("zigeffect", zigeffect);
    workflow_list_tool_module.addImport("workflow_tool_support", workflow_tool_support_module);

    const workflow_list_tool = b.addExecutable(.{
        .name = "zigeffect-workflow-list",
        .root_module = workflow_list_tool_module,
    });
    const run_workflow_list_tool = b.addRunArtifact(workflow_list_tool);
    if (b.args) |args| run_workflow_list_tool.addArgs(args);
    const workflow_list_step = b.step("workflow-list", "List durable workflow executions from a workflow journal");
    workflow_list_step.dependOn(&run_workflow_list_tool.step);

    const workflow_list_tool_tests = b.addTest(.{
        .name = "zigeffect-workflow-list-tests",
        .root_module = workflow_list_tool_module,
    });
    const run_workflow_list_tool_tests = b.addRunArtifact(workflow_list_tool_tests);

    const workflow_replay_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/workflow_replay.zig"),
        .target = target,
        .optimize = optimize,
    });
    workflow_replay_tool_module.addImport("zigeffect", zigeffect);
    workflow_replay_tool_module.addImport("workflow_tool_support", workflow_tool_support_module);

    const workflow_replay_tool = b.addExecutable(.{
        .name = "zigeffect-workflow-replay",
        .root_module = workflow_replay_tool_module,
    });
    const run_workflow_replay_tool = b.addRunArtifact(workflow_replay_tool);
    if (b.args) |args| run_workflow_replay_tool.addArgs(args);
    const workflow_replay_step = b.step("workflow-replay", "Replay durable workflow state from a workflow journal");
    workflow_replay_step.dependOn(&run_workflow_replay_tool.step);

    const workflow_replay_tool_tests = b.addTest(.{
        .name = "zigeffect-workflow-replay-tests",
        .root_module = workflow_replay_tool_module,
    });
    const run_workflow_replay_tool_tests = b.addRunArtifact(workflow_replay_tool_tests);

    const workflow_journal_inspect_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/workflow_journal_inspect.zig"),
        .target = target,
        .optimize = optimize,
    });
    workflow_journal_inspect_tool_module.addImport("zigeffect", zigeffect);
    workflow_journal_inspect_tool_module.addImport("workflow_tool_support", workflow_tool_support_module);

    const workflow_journal_inspect_tool = b.addExecutable(.{
        .name = "zigeffect-workflow-journal-inspect",
        .root_module = workflow_journal_inspect_tool_module,
    });
    const run_workflow_journal_inspect_tool = b.addRunArtifact(workflow_journal_inspect_tool);
    if (b.args) |args| run_workflow_journal_inspect_tool.addArgs(args);
    const workflow_journal_inspect_step = b.step("workflow-journal-inspect", "Inspect durable workflow journal events");
    workflow_journal_inspect_step.dependOn(&run_workflow_journal_inspect_tool.step);

    const workflow_journal_inspect_tool_tests = b.addTest(.{
        .name = "zigeffect-workflow-journal-inspect-tests",
        .root_module = workflow_journal_inspect_tool_module,
    });
    const run_workflow_journal_inspect_tool_tests = b.addRunArtifact(workflow_journal_inspect_tool_tests);

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
    test_step.dependOn(&run_storage_conformance_tests.step);
    test_step.dependOn(&run_property_history_tests.step);
    test_step.dependOn(&run_crash_recovery_property_tests.step);
    test_step.dependOn(&run_message_history_property_tests.step);
    test_step.dependOn(&run_scheduler_fairness_property_tests.step);
    test_step.dependOn(&run_performance_benchmark_tests.step);
    test_step.dependOn(&run_resource_bounds_tests.step);
    test_step.dependOn(&run_workflow_snapshot_frequency_tests.step);
    test_step.dependOn(&run_cluster_observability_tests.step);
    test_step.dependOn(&run_causal_jsonl_backend_tests.step);
    test_step.dependOn(&run_causal_dot_backend_tests.step);
    test_step.dependOn(&run_causal_otel_backend_tests.step);
    test_step.dependOn(&run_causal_graph_history_backend_tests.step);
    test_step.dependOn(&run_causal_nendb_storage_backend_tests.step);
    test_step.dependOn(&run_causal_async_stream_backend_tests.step);
    test_step.dependOn(&run_storage_migrate_tool_tests.step);
    test_step.dependOn(&run_performance_bench_tool_tests.step);
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
    examples_step.dependOn(&causal_missing_config_example.step);
    examples_step.dependOn(&run_causal_missing_config_example_tests.step);
    examples_step.dependOn(&causal_cleanup_failure_example.step);
    examples_step.dependOn(&run_causal_cleanup_failure_example_tests.step);
    examples_step.dependOn(&causal_scoped_fiber_example.step);
    examples_step.dependOn(&run_causal_scoped_fiber_example_tests.step);
    examples_step.dependOn(&causal_retry_exhaustion_example.step);
    examples_step.dependOn(&run_causal_retry_exhaustion_example_tests.step);
    examples_step.dependOn(&workflow_approval_example.step);
    examples_step.dependOn(&run_workflow_approval_example_tests.step);
    examples_step.dependOn(&workflow_queue_worker_example.step);
    examples_step.dependOn(&run_workflow_queue_worker_example_tests.step);
    examples_step.dependOn(&scaffold_tool.step);
    examples_step.dependOn(&run_scaffold_tool_tests.step);
    examples_step.dependOn(&causal_report_tool.step);
    examples_step.dependOn(&run_causal_report_tool_tests.step);
    examples_step.dependOn(&causal_test_tool.step);
    examples_step.dependOn(&run_causal_test_tool_tests.step);
    examples_step.dependOn(&cluster_runner_tool.step);
    examples_step.dependOn(&run_cluster_runner_tool_tests.step);
    examples_step.dependOn(&storage_migrate_tool.step);
    examples_step.dependOn(&run_storage_migrate_tool_tests.step);
    examples_step.dependOn(&performance_bench_tool.step);
    examples_step.dependOn(&run_performance_bench_tool_tests.step);
    examples_step.dependOn(&run_causal_artifact_tool_tests.step);
    examples_step.dependOn(&run_workflow_tool_support_tests.step);
    examples_step.dependOn(&workflow_list_tool.step);
    examples_step.dependOn(&run_workflow_list_tool_tests.step);
    examples_step.dependOn(&workflow_replay_tool.step);
    examples_step.dependOn(&run_workflow_replay_tool_tests.step);
    examples_step.dependOn(&workflow_journal_inspect_tool.step);
    examples_step.dependOn(&run_workflow_journal_inspect_tool_tests.step);
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
