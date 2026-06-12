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

    const public_api_stability_test_module = b.createModule(.{
        .root_source_file = b.path("test/public_api_stability_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    public_api_stability_test_module.addImport("zigeffect", zigeffect);

    const public_api_stability_tests = b.addTest(.{
        .name = "zigeffect-public-api-stability-tests",
        .root_module = public_api_stability_test_module,
    });
    const run_public_api_stability_tests = b.addRunArtifact(public_api_stability_tests);
    const public_api_review_step = b.step("public-api-review", "Run public API stability review tests");
    public_api_review_step.dependOn(&run_public_api_stability_tests.step);

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

    const workflow_timer_signal_example_module = b.createModule(.{
        .root_source_file = b.path("examples/workflow_timer_signal.zig"),
        .target = target,
        .optimize = optimize,
    });
    workflow_timer_signal_example_module.addImport("zigeffect", zigeffect);

    const workflow_timer_signal_example = b.addExecutable(.{
        .name = "zigeffect-workflow-timer-signal-example",
        .root_module = workflow_timer_signal_example_module,
    });

    const workflow_timer_signal_example_tests = b.addTest(.{
        .name = "zigeffect-workflow-timer-signal-example-tests",
        .root_module = workflow_timer_signal_example_module,
    });
    const run_workflow_timer_signal_example_tests = b.addRunArtifact(workflow_timer_signal_example_tests);

    const workflow_crash_recovery_example_module = b.createModule(.{
        .root_source_file = b.path("examples/workflow_crash_recovery.zig"),
        .target = target,
        .optimize = optimize,
    });
    workflow_crash_recovery_example_module.addImport("zigeffect", zigeffect);

    const workflow_crash_recovery_example = b.addExecutable(.{
        .name = "zigeffect-workflow-crash-recovery-example",
        .root_module = workflow_crash_recovery_example_module,
    });

    const workflow_crash_recovery_example_tests = b.addTest(.{
        .name = "zigeffect-workflow-crash-recovery-example-tests",
        .root_module = workflow_crash_recovery_example_module,
    });
    const run_workflow_crash_recovery_example_tests = b.addRunArtifact(workflow_crash_recovery_example_tests);

    const local_actor_example_module = b.createModule(.{
        .root_source_file = b.path("examples/local_actor.zig"),
        .target = target,
        .optimize = optimize,
    });
    local_actor_example_module.addImport("zigeffect", zigeffect);

    const local_actor_example = b.addExecutable(.{
        .name = "zigeffect-local-actor-example",
        .root_module = local_actor_example_module,
    });

    const local_actor_example_tests = b.addTest(.{
        .name = "zigeffect-local-actor-example-tests",
        .root_module = local_actor_example_module,
    });
    const run_local_actor_example_tests = b.addRunArtifact(local_actor_example_tests);

    const multi_runner_cluster_example_module = b.createModule(.{
        .root_source_file = b.path("examples/multi_runner_cluster.zig"),
        .target = target,
        .optimize = optimize,
    });
    multi_runner_cluster_example_module.addImport("zigeffect", zigeffect);

    const multi_runner_cluster_example = b.addExecutable(.{
        .name = "zigeffect-multi-runner-cluster-example",
        .root_module = multi_runner_cluster_example_module,
    });

    const multi_runner_cluster_example_tests = b.addTest(.{
        .name = "zigeffect-multi-runner-cluster-example-tests",
        .root_module = multi_runner_cluster_example_module,
    });
    const run_multi_runner_cluster_example_tests = b.addRunArtifact(multi_runner_cluster_example_tests);

    const cluster_workflow_migration_example_module = b.createModule(.{
        .root_source_file = b.path("examples/cluster_workflow_migration.zig"),
        .target = target,
        .optimize = optimize,
    });
    cluster_workflow_migration_example_module.addImport("zigeffect", zigeffect);

    const cluster_workflow_migration_example = b.addExecutable(.{
        .name = "zigeffect-cluster-workflow-migration-example",
        .root_module = cluster_workflow_migration_example_module,
    });

    const cluster_workflow_migration_example_tests = b.addTest(.{
        .name = "zigeffect-cluster-workflow-migration-example-tests",
        .root_module = cluster_workflow_migration_example_module,
    });
    const run_cluster_workflow_migration_example_tests = b.addRunArtifact(cluster_workflow_migration_example_tests);

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

    const cluster_inspect_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/cluster_inspect.zig"),
        .target = target,
        .optimize = optimize,
    });
    cluster_inspect_tool_module.addImport("zigeffect", zigeffect);

    const cluster_inspect_tool = b.addExecutable(.{
        .name = "zigeffect-cluster-inspect",
        .root_module = cluster_inspect_tool_module,
    });
    const run_cluster_inspect_tool = b.addRunArtifact(cluster_inspect_tool);
    if (b.args) |args| run_cluster_inspect_tool.addArgs(args);
    const cluster_inspect_step = b.step("cluster-inspect", "Inspect durable zigeffect cluster storage");
    cluster_inspect_step.dependOn(&run_cluster_inspect_tool.step);

    const cluster_inspect_tool_tests = b.addTest(.{
        .name = "zigeffect-cluster-inspect-tests",
        .root_module = cluster_inspect_tool_module,
    });
    const run_cluster_inspect_tool_tests = b.addRunArtifact(cluster_inspect_tool_tests);

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

    const release_gate_report_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/release_gate_report.zig"),
        .target = target,
        .optimize = optimize,
    });

    const release_gate_report_tool = b.addExecutable(.{
        .name = "zigeffect-release-gate-report",
        .root_module = release_gate_report_tool_module,
    });
    const run_release_gate_report_tool = b.addRunArtifact(release_gate_report_tool);
    const release_gate_report_step = b.step("release-gate-report", "Write zigeffect release gate report artifacts");
    release_gate_report_step.dependOn(&run_release_gate_report_tool.step);

    const release_gate_report_tool_tests = b.addTest(.{
        .name = "zigeffect-release-gate-report-tests",
        .root_module = release_gate_report_tool_module,
    });
    const run_release_gate_report_tool_tests = b.addRunArtifact(release_gate_report_tool_tests);

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

    const causal_app_human_review_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_human_review.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_human_review_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-human-review-tests",
        .root_module = causal_app_human_review_tool_module,
    });
    const run_causal_app_human_review_tool_tests = b.addRunArtifact(causal_app_human_review_tool_tests);

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

    const causal_app_application_readiness_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_application_readiness.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_application_readiness_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-application-readiness-tests",
        .root_module = causal_app_application_readiness_tool_module,
    });
    const run_causal_app_application_readiness_tool_tests = b.addRunArtifact(causal_app_application_readiness_tool_tests);

    const causal_app_apply_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_apply.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_apply_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-apply-tests",
        .root_module = causal_app_apply_tool_module,
    });
    const run_causal_app_apply_tool_tests = b.addRunArtifact(causal_app_apply_tool_tests);

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
    test_step.dependOn(&run_public_api_stability_tests.step);
    test_step.dependOn(&run_causal_jsonl_backend_tests.step);
    test_step.dependOn(&run_causal_dot_backend_tests.step);
    test_step.dependOn(&run_causal_otel_backend_tests.step);
    test_step.dependOn(&run_causal_graph_history_backend_tests.step);
    test_step.dependOn(&run_causal_nendb_storage_backend_tests.step);
    test_step.dependOn(&run_causal_async_stream_backend_tests.step);
    test_step.dependOn(&run_causal_app_runtime_tests.step);
    test_step.dependOn(&run_causal_app_human_review_tool_tests.step);
    test_step.dependOn(&run_causal_app_patch_proposal_tool_tests.step);
    test_step.dependOn(&run_causal_app_application_readiness_tool_tests.step);
    test_step.dependOn(&run_causal_app_apply_tool_tests.step);
    test_step.dependOn(&run_cluster_inspect_tool_tests.step);
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

    const causal_schema_governance_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_schema_governance.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_schema_governance_tool_module.addImport("causal_artifact", causal_artifact_tool_module);

    const causal_schema_governance_tool = b.addExecutable(.{
        .name = "zigeffect-causal-schema-governance",
        .root_module = causal_schema_governance_tool_module,
    });
    const run_causal_schema_governance_tool = b.addRunArtifact(causal_schema_governance_tool);
    if (b.args) |args| run_causal_schema_governance_tool.addArgs(args);
    const causal_schema_governance_step = b.step("causal-schema-governance", "Print causal artifact schema/version governance report");
    causal_schema_governance_step.dependOn(&run_causal_schema_governance_tool.step);

    const causal_schema_governance_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-schema-governance-tests",
        .root_module = causal_schema_governance_tool_module,
    });
    const run_causal_schema_governance_tool_tests = b.addRunArtifact(causal_schema_governance_tool_tests);
    test_step.dependOn(&run_causal_schema_governance_tool_tests.step);

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

    const causal_performance_budget_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_performance_budget.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_performance_budget_tool_module.addImport("zigeffect", zigeffect);
    causal_performance_budget_tool_module.addImport("causal_workbench_session", causal_workbench_session_tool_module);

    const causal_performance_budget_tool = b.addExecutable(.{
        .name = "zigeffect-causal-performance-budget",
        .root_module = causal_performance_budget_tool_module,
    });
    const run_causal_performance_budget_tool = b.addRunArtifact(causal_performance_budget_tool);
    if (b.args) |args| run_causal_performance_budget_tool.addArgs(args);
    const causal_performance_budget_step = b.step("causal-performance-budget", "Print causal instrumentation performance budget report");
    causal_performance_budget_step.dependOn(&run_causal_performance_budget_tool.step);

    const causal_performance_budget_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-performance-budget-tests",
        .root_module = causal_performance_budget_tool_module,
    });
    const run_causal_performance_budget_tool_tests = b.addRunArtifact(causal_performance_budget_tool_tests);
    test_step.dependOn(&run_causal_performance_budget_tool_tests.step);

    const causal_wall_clock_benchmark_baselines_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_wall_clock_benchmark_baselines.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_wall_clock_benchmark_baselines_tool = b.addExecutable(.{
        .name = "zigeffect-causal-wall-clock-benchmark-baselines",
        .root_module = causal_wall_clock_benchmark_baselines_tool_module,
    });
    const run_causal_wall_clock_benchmark_baselines_tool = b.addRunArtifact(causal_wall_clock_benchmark_baselines_tool);
    if (b.args) |args| run_causal_wall_clock_benchmark_baselines_tool.addArgs(args);
    const causal_wall_clock_benchmark_baselines_step = b.step("causal-wall-clock-benchmark-baselines", "Print causal wall-clock benchmark baseline contract");
    causal_wall_clock_benchmark_baselines_step.dependOn(&run_causal_wall_clock_benchmark_baselines_tool.step);

    const causal_wall_clock_benchmark_baselines_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-wall-clock-benchmark-baselines-tests",
        .root_module = causal_wall_clock_benchmark_baselines_tool_module,
    });
    const run_causal_wall_clock_benchmark_baselines_tool_tests = b.addRunArtifact(causal_wall_clock_benchmark_baselines_tool_tests);
    test_step.dependOn(&run_causal_wall_clock_benchmark_baselines_tool_tests.step);

    const causal_production_capacity_planning_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_capacity_planning.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_capacity_planning_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-capacity-planning",
        .root_module = causal_production_capacity_planning_tool_module,
    });
    const run_causal_production_capacity_planning_tool = b.addRunArtifact(causal_production_capacity_planning_tool);
    if (b.args) |args| run_causal_production_capacity_planning_tool.addArgs(args);
    const causal_production_capacity_planning_step = b.step("causal-production-capacity-planning", "Print causal production capacity planning contract");
    causal_production_capacity_planning_step.dependOn(&run_causal_production_capacity_planning_tool.step);

    const causal_production_capacity_planning_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-capacity-planning-tests",
        .root_module = causal_production_capacity_planning_tool_module,
    });
    const run_causal_production_capacity_planning_tool_tests = b.addRunArtifact(causal_production_capacity_planning_tool_tests);
    test_step.dependOn(&run_causal_production_capacity_planning_tool_tests.step);

    const causal_production_hardening_completion_audit_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_hardening_completion_audit.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_hardening_completion_audit_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-hardening-completion-audit",
        .root_module = causal_production_hardening_completion_audit_tool_module,
    });
    const run_causal_production_hardening_completion_audit_tool = b.addRunArtifact(causal_production_hardening_completion_audit_tool);
    if (b.args) |args| run_causal_production_hardening_completion_audit_tool.addArgs(args);
    const causal_production_hardening_completion_audit_step = b.step("causal-production-hardening-completion-audit", "Print causal production-hardening completion audit");
    causal_production_hardening_completion_audit_step.dependOn(&run_causal_production_hardening_completion_audit_tool.step);

    const causal_production_hardening_completion_audit_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-hardening-completion-audit-tests",
        .root_module = causal_production_hardening_completion_audit_tool_module,
    });
    const run_causal_production_hardening_completion_audit_tool_tests = b.addRunArtifact(causal_production_hardening_completion_audit_tool_tests);
    test_step.dependOn(&run_causal_production_hardening_completion_audit_tool_tests.step);

    const causal_load_test_observation_harness_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_load_test_observation_harness.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_load_test_observation_harness_tool = b.addExecutable(.{
        .name = "zigeffect-causal-load-test-observation-harness",
        .root_module = causal_load_test_observation_harness_tool_module,
    });
    const run_causal_load_test_observation_harness_tool = b.addRunArtifact(causal_load_test_observation_harness_tool);
    if (b.args) |args| run_causal_load_test_observation_harness_tool.addArgs(args);
    const causal_load_test_observation_harness_step = b.step("causal-load-test-observation-harness", "Print or run causal load-test observation harness");
    causal_load_test_observation_harness_step.dependOn(&run_causal_load_test_observation_harness_tool.step);

    const causal_load_test_observation_harness_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-load-test-observation-harness-tests",
        .root_module = causal_load_test_observation_harness_tool_module,
    });
    const run_causal_load_test_observation_harness_tool_tests = b.addRunArtifact(causal_load_test_observation_harness_tool_tests);
    test_step.dependOn(&run_causal_load_test_observation_harness_tool_tests.step);

    const causal_production_telemetry_capture_design_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_capture_design.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_capture_design_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-capture-design",
        .root_module = causal_production_telemetry_capture_design_tool_module,
    });
    const run_causal_production_telemetry_capture_design_tool = b.addRunArtifact(causal_production_telemetry_capture_design_tool);
    if (b.args) |args| run_causal_production_telemetry_capture_design_tool.addArgs(args);
    const causal_production_telemetry_capture_design_step = b.step("causal-production-telemetry-capture-design", "Print causal production telemetry capture design report");
    causal_production_telemetry_capture_design_step.dependOn(&run_causal_production_telemetry_capture_design_tool.step);

    const causal_production_telemetry_capture_design_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-capture-design-tests",
        .root_module = causal_production_telemetry_capture_design_tool_module,
    });
    const run_causal_production_telemetry_capture_design_tool_tests = b.addRunArtifact(causal_production_telemetry_capture_design_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_capture_design_tool_tests.step);

    const causal_production_telemetry_capture_fixtures_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_capture_fixtures.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_capture_fixtures_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-capture-fixtures",
        .root_module = causal_production_telemetry_capture_fixtures_tool_module,
    });
    const run_causal_production_telemetry_capture_fixtures_tool = b.addRunArtifact(causal_production_telemetry_capture_fixtures_tool);
    if (b.args) |args| run_causal_production_telemetry_capture_fixtures_tool.addArgs(args);
    const causal_production_telemetry_capture_fixtures_step = b.step("causal-production-telemetry-capture-fixtures", "Print causal production telemetry capture fixture catalog");
    causal_production_telemetry_capture_fixtures_step.dependOn(&run_causal_production_telemetry_capture_fixtures_tool.step);

    const causal_production_telemetry_capture_fixtures_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-capture-fixtures-tests",
        .root_module = causal_production_telemetry_capture_fixtures_tool_module,
    });
    const run_causal_production_telemetry_capture_fixtures_tool_tests = b.addRunArtifact(causal_production_telemetry_capture_fixtures_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_capture_fixtures_tool_tests.step);

    const causal_app_facing_production_integration_fixtures_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_fixtures.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_fixtures_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-fixtures",
        .root_module = causal_app_facing_production_integration_fixtures_tool_module,
    });
    const run_causal_app_facing_production_integration_fixtures_tool = b.addRunArtifact(causal_app_facing_production_integration_fixtures_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_fixtures_tool.addArgs(args);
    const causal_app_facing_production_integration_fixtures_step = b.step("causal-app-facing-production-integration-fixtures", "Print causal app-facing production integration fixture catalog");
    causal_app_facing_production_integration_fixtures_step.dependOn(&run_causal_app_facing_production_integration_fixtures_tool.step);

    const causal_app_facing_production_integration_fixtures_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-fixtures-tests",
        .root_module = causal_app_facing_production_integration_fixtures_tool_module,
    });
    const run_causal_app_facing_production_integration_fixtures_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_fixtures_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_fixtures_tool_tests.step);

    const causal_app_facing_production_integration_readiness_review_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_readiness_review.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_readiness_review_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-readiness-review",
        .root_module = causal_app_facing_production_integration_readiness_review_tool_module,
    });
    const run_causal_app_facing_production_integration_readiness_review_tool = b.addRunArtifact(causal_app_facing_production_integration_readiness_review_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_readiness_review_tool.addArgs(args);
    const causal_app_facing_production_integration_readiness_review_step = b.step("causal-app-facing-production-integration-readiness-review", "Review app-facing production integration fixture readiness");
    causal_app_facing_production_integration_readiness_review_step.dependOn(&run_causal_app_facing_production_integration_readiness_review_tool.step);

    const causal_app_facing_production_integration_readiness_review_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-readiness-review-tests",
        .root_module = causal_app_facing_production_integration_readiness_review_tool_module,
    });
    const run_causal_app_facing_production_integration_readiness_review_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_readiness_review_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_readiness_review_tool_tests.step);

    const causal_app_facing_production_integration_implementation_proposal_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_implementation_proposal.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_implementation_proposal_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-implementation-proposal",
        .root_module = causal_app_facing_production_integration_implementation_proposal_tool_module,
    });
    const run_causal_app_facing_production_integration_implementation_proposal_tool = b.addRunArtifact(causal_app_facing_production_integration_implementation_proposal_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_implementation_proposal_tool.addArgs(args);
    const causal_app_facing_production_integration_implementation_proposal_step = b.step("causal-app-facing-production-integration-implementation-proposal", "Review app-facing production integration implementation proposal");
    causal_app_facing_production_integration_implementation_proposal_step.dependOn(&run_causal_app_facing_production_integration_implementation_proposal_tool.step);

    const causal_app_facing_production_integration_implementation_proposal_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-implementation-proposal-tests",
        .root_module = causal_app_facing_production_integration_implementation_proposal_tool_module,
    });
    const run_causal_app_facing_production_integration_implementation_proposal_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_implementation_proposal_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_implementation_proposal_tool_tests.step);

    const causal_app_facing_production_integration_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-boundary",
        .root_module = causal_app_facing_production_integration_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_boundary_tool = b.addRunArtifact(causal_app_facing_production_integration_boundary_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_boundary_tool.addArgs(args);
    const causal_app_facing_production_integration_boundary_step = b.step("causal-app-facing-production-integration-boundary", "Review app-facing production integration boundary");
    causal_app_facing_production_integration_boundary_step.dependOn(&run_causal_app_facing_production_integration_boundary_tool.step);

    const causal_app_facing_production_integration_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-boundary-tests",
        .root_module = causal_app_facing_production_integration_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_boundary_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_boundary_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_boundary_tool_tests.step);

    const causal_app_facing_production_integration_local_fixtures_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_local_fixtures.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_local_fixtures_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-local-fixtures",
        .root_module = causal_app_facing_production_integration_local_fixtures_tool_module,
    });
    const run_causal_app_facing_production_integration_local_fixtures_tool = b.addRunArtifact(causal_app_facing_production_integration_local_fixtures_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_local_fixtures_tool.addArgs(args);
    const causal_app_facing_production_integration_local_fixtures_step = b.step("causal-app-facing-production-integration-local-fixtures", "Review app-facing production integration local fixtures");
    causal_app_facing_production_integration_local_fixtures_step.dependOn(&run_causal_app_facing_production_integration_local_fixtures_tool.step);

    const causal_app_facing_production_integration_local_fixtures_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-local-fixtures-tests",
        .root_module = causal_app_facing_production_integration_local_fixtures_tool_module,
    });
    const run_causal_app_facing_production_integration_local_fixtures_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_local_fixtures_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_local_fixtures_tool_tests.step);

    const causal_app_facing_production_integration_nendb_handoff_fixtures_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_nendb_handoff_fixtures.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_nendb_handoff_fixtures_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures",
        .root_module = causal_app_facing_production_integration_nendb_handoff_fixtures_tool_module,
    });
    const run_causal_app_facing_production_integration_nendb_handoff_fixtures_tool = b.addRunArtifact(causal_app_facing_production_integration_nendb_handoff_fixtures_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_nendb_handoff_fixtures_tool.addArgs(args);
    const causal_app_facing_production_integration_nendb_handoff_fixtures_step = b.step("causal-app-facing-production-integration-nendb-handoff-fixtures", "Review app-facing production integration NenDB handoff fixtures");
    causal_app_facing_production_integration_nendb_handoff_fixtures_step.dependOn(&run_causal_app_facing_production_integration_nendb_handoff_fixtures_tool.step);

    const causal_app_facing_production_integration_nendb_handoff_fixtures_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures-tests",
        .root_module = causal_app_facing_production_integration_nendb_handoff_fixtures_tool_module,
    });
    const run_causal_app_facing_production_integration_nendb_handoff_fixtures_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_nendb_handoff_fixtures_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_nendb_handoff_fixtures_tool_tests.step);

    const causal_app_facing_production_integration_audit_remediation_bridge_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_audit_remediation_bridge.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_audit_remediation_bridge_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-audit-remediation-bridge",
        .root_module = causal_app_facing_production_integration_audit_remediation_bridge_tool_module,
    });
    const run_causal_app_facing_production_integration_audit_remediation_bridge_tool = b.addRunArtifact(causal_app_facing_production_integration_audit_remediation_bridge_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_audit_remediation_bridge_tool.addArgs(args);
    const causal_app_facing_production_integration_audit_remediation_bridge_step = b.step("causal-app-facing-production-integration-audit-remediation-bridge", "Review app-facing production integration audit/remediation bridge");
    causal_app_facing_production_integration_audit_remediation_bridge_step.dependOn(&run_causal_app_facing_production_integration_audit_remediation_bridge_tool.step);

    const causal_app_facing_production_integration_audit_remediation_bridge_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-audit-remediation-bridge-tests",
        .root_module = causal_app_facing_production_integration_audit_remediation_bridge_tool_module,
    });
    const run_causal_app_facing_production_integration_audit_remediation_bridge_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_audit_remediation_bridge_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_audit_remediation_bridge_tool_tests.step);

    const causal_app_facing_production_integration_solid_webui_readonly_preview_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_solid_webui_readonly_preview.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_solid_webui_readonly_preview_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview",
        .root_module = causal_app_facing_production_integration_solid_webui_readonly_preview_tool_module,
    });
    const run_causal_app_facing_production_integration_solid_webui_readonly_preview_tool = b.addRunArtifact(causal_app_facing_production_integration_solid_webui_readonly_preview_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_solid_webui_readonly_preview_tool.addArgs(args);
    const causal_app_facing_production_integration_solid_webui_readonly_preview_step = b.step("causal-app-facing-production-integration-solid-webui-readonly-preview", "Review app-facing production integration SolidJS read-only preview");
    causal_app_facing_production_integration_solid_webui_readonly_preview_step.dependOn(&run_causal_app_facing_production_integration_solid_webui_readonly_preview_tool.step);

    const causal_app_facing_production_integration_solid_webui_readonly_preview_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview-tests",
        .root_module = causal_app_facing_production_integration_solid_webui_readonly_preview_tool_module,
    });
    const run_causal_app_facing_production_integration_solid_webui_readonly_preview_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_solid_webui_readonly_preview_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_solid_webui_readonly_preview_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report", "Review app-facing production integration CI advisory remediation report");
    causal_app_facing_production_integration_ci_advisory_remediation_report_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary", "Record app-facing CI advisory remediation report application boundary evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy", "Review app-facing CI advisory remediation report publication policy");
    causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness", "Review app-facing CI advisory remediation report consumption readiness");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary", "Record app-facing CI advisory remediation report consumption boundary evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy", "Review app-facing CI advisory remediation report consumption policy");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator", "Evaluate app-facing CI advisory remediation report consumption requests");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report", "Summarize app-facing CI advisory remediation report consumption evaluator evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary", "Record app-facing CI advisory remediation report consumption-report application boundary evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy", "Review app-facing CI advisory remediation report consumption-report policy evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluator_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluator.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluator_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluator_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluator_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluator_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluator_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluator_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator", "Evaluate app-facing CI advisory remediation report consumption-report requests");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluator_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluator_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluator_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluator_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluator_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluator_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluator_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report", "Summarize app-facing CI advisory remediation report consumption-report evaluator evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary", "Record app-facing CI advisory remediation report consumption-report evaluation-report application boundary evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy", "Review app-facing CI advisory remediation report consumption-report evaluation-report application-boundary policy evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator", "Evaluate app-facing CI advisory remediation report consumption-report evaluation-report requests");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report", "Summarize app-facing CI advisory remediation report consumption-report evaluation-report evaluator evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary", "Record app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report application boundary evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy", "Review app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report application-boundary policy evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator", "Evaluate app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report policy evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report", "Summarize app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluator evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "Record app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report application boundary evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy", "Interpret app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report application boundary evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "Evaluate app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report policy evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "Summarize app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluator evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "Record app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report application boundary evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", "Review app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report policy");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "Evaluate app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report policy evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "Summarize app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evaluator evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "Record app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report application boundary evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", "Review app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report policy");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "Evaluate app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report requests");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "Summarize app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluator evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "Record app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report application boundary evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", "Interpret app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report application boundary evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "Evaluate app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report policy evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "Summarize app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluator evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "Record app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report application boundary evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-seven-level-application-boundary-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", "Interpret app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report application boundary evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-seven-level-policy-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "Evaluate app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report policy evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-seven-level-evaluator-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_tool_tests.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool);
    if (b.args) |args| run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool.addArgs(args);
    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_step = b.step("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "Summarize app-facing CI advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluator evidence");
    causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool.step);

    const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-eight-level-report-tests",
        .root_module = causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_module,
    });
    const run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests);
    test_step.dependOn(&run_causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_tool_tests.step);

    const causal_app_facing_eight_level_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_eight_level_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_eight_level_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-eight-level-application-boundary",
        .root_module = causal_app_facing_eight_level_application_boundary_tool_module,
    });
    const run_causal_app_facing_eight_level_application_boundary_tool = b.addRunArtifact(causal_app_facing_eight_level_application_boundary_tool);
    if (b.args) |args| run_causal_app_facing_eight_level_application_boundary_tool.addArgs(args);
    const causal_app_facing_eight_level_application_boundary_step = b.step("causal-app-facing-eight-level-application-boundary", "Record app-facing eight-level application boundary evidence");
    causal_app_facing_eight_level_application_boundary_step.dependOn(&run_causal_app_facing_eight_level_application_boundary_tool.step);

    const causal_app_facing_eight_level_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-eight-level-application-boundary-tests",
        .root_module = causal_app_facing_eight_level_application_boundary_tool_module,
    });
    const run_causal_app_facing_eight_level_application_boundary_tool_tests = b.addRunArtifact(causal_app_facing_eight_level_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_app_facing_eight_level_application_boundary_tool_tests.step);

    const causal_app_facing_eight_level_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_eight_level_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_eight_level_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-eight-level-policy",
        .root_module = causal_app_facing_eight_level_policy_tool_module,
    });
    const run_causal_app_facing_eight_level_policy_tool = b.addRunArtifact(causal_app_facing_eight_level_policy_tool);
    if (b.args) |args| run_causal_app_facing_eight_level_policy_tool.addArgs(args);
    const causal_app_facing_eight_level_policy_step = b.step("causal-app-facing-eight-level-policy", "Record app-facing eight-level policy evidence");
    causal_app_facing_eight_level_policy_step.dependOn(&run_causal_app_facing_eight_level_policy_tool.step);

    const causal_app_facing_eight_level_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-eight-level-policy-tests",
        .root_module = causal_app_facing_eight_level_policy_tool_module,
    });
    const run_causal_app_facing_eight_level_policy_tool_tests = b.addRunArtifact(causal_app_facing_eight_level_policy_tool_tests);
    test_step.dependOn(&run_causal_app_facing_eight_level_policy_tool_tests.step);

    const causal_app_facing_eight_level_evaluator_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_eight_level_evaluator.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_eight_level_evaluator_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-eight-level-evaluator",
        .root_module = causal_app_facing_eight_level_evaluator_tool_module,
    });
    const run_causal_app_facing_eight_level_evaluator_tool = b.addRunArtifact(causal_app_facing_eight_level_evaluator_tool);
    if (b.args) |args| run_causal_app_facing_eight_level_evaluator_tool.addArgs(args);
    const causal_app_facing_eight_level_evaluator_step = b.step("causal-app-facing-eight-level-evaluator", "Evaluate app-facing eight-level policy evidence");
    causal_app_facing_eight_level_evaluator_step.dependOn(&run_causal_app_facing_eight_level_evaluator_tool.step);

    const causal_app_facing_eight_level_evaluator_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-eight-level-evaluator-tests",
        .root_module = causal_app_facing_eight_level_evaluator_tool_module,
    });
    const run_causal_app_facing_eight_level_evaluator_tool_tests = b.addRunArtifact(causal_app_facing_eight_level_evaluator_tool_tests);
    test_step.dependOn(&run_causal_app_facing_eight_level_evaluator_tool_tests.step);

    const causal_app_facing_nine_level_report_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_nine_level_report.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_nine_level_report_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-nine-level-report",
        .root_module = causal_app_facing_nine_level_report_tool_module,
    });
    const run_causal_app_facing_nine_level_report_tool = b.addRunArtifact(causal_app_facing_nine_level_report_tool);
    if (b.args) |args| run_causal_app_facing_nine_level_report_tool.addArgs(args);
    const causal_app_facing_nine_level_report_step = b.step("causal-app-facing-nine-level-report", "Summarize app-facing eight-level evaluator evidence");
    causal_app_facing_nine_level_report_step.dependOn(&run_causal_app_facing_nine_level_report_tool.step);

    const causal_app_facing_nine_level_report_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-nine-level-report-tests",
        .root_module = causal_app_facing_nine_level_report_tool_module,
    });
    const run_causal_app_facing_nine_level_report_tool_tests = b.addRunArtifact(causal_app_facing_nine_level_report_tool_tests);
    test_step.dependOn(&run_causal_app_facing_nine_level_report_tool_tests.step);

    const causal_app_facing_nine_level_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_nine_level_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_nine_level_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-nine-level-application-boundary",
        .root_module = causal_app_facing_nine_level_application_boundary_tool_module,
    });
    const run_causal_app_facing_nine_level_application_boundary_tool = b.addRunArtifact(causal_app_facing_nine_level_application_boundary_tool);
    if (b.args) |args| run_causal_app_facing_nine_level_application_boundary_tool.addArgs(args);
    const causal_app_facing_nine_level_application_boundary_step = b.step("causal-app-facing-nine-level-application-boundary", "Record app-facing nine-level application boundary evidence");
    causal_app_facing_nine_level_application_boundary_step.dependOn(&run_causal_app_facing_nine_level_application_boundary_tool.step);

    const causal_app_facing_nine_level_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-nine-level-application-boundary-tests",
        .root_module = causal_app_facing_nine_level_application_boundary_tool_module,
    });
    const run_causal_app_facing_nine_level_application_boundary_tool_tests = b.addRunArtifact(causal_app_facing_nine_level_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_app_facing_nine_level_application_boundary_tool_tests.step);

    const causal_app_facing_nine_level_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_nine_level_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_nine_level_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-nine-level-policy",
        .root_module = causal_app_facing_nine_level_policy_tool_module,
    });
    const run_causal_app_facing_nine_level_policy_tool = b.addRunArtifact(causal_app_facing_nine_level_policy_tool);
    if (b.args) |args| run_causal_app_facing_nine_level_policy_tool.addArgs(args);
    const causal_app_facing_nine_level_policy_step = b.step("causal-app-facing-nine-level-policy", "Record app-facing nine-level policy evidence");
    causal_app_facing_nine_level_policy_step.dependOn(&run_causal_app_facing_nine_level_policy_tool.step);

    const causal_app_facing_nine_level_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-nine-level-policy-tests",
        .root_module = causal_app_facing_nine_level_policy_tool_module,
    });
    const run_causal_app_facing_nine_level_policy_tool_tests = b.addRunArtifact(causal_app_facing_nine_level_policy_tool_tests);
    test_step.dependOn(&run_causal_app_facing_nine_level_policy_tool_tests.step);

    const causal_app_facing_nine_level_evaluator_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_nine_level_evaluator.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_nine_level_evaluator_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-nine-level-evaluator",
        .root_module = causal_app_facing_nine_level_evaluator_tool_module,
    });
    const run_causal_app_facing_nine_level_evaluator_tool = b.addRunArtifact(causal_app_facing_nine_level_evaluator_tool);
    if (b.args) |args| run_causal_app_facing_nine_level_evaluator_tool.addArgs(args);
    const causal_app_facing_nine_level_evaluator_step = b.step("causal-app-facing-nine-level-evaluator", "Evaluate app-facing nine-level policy evidence");
    causal_app_facing_nine_level_evaluator_step.dependOn(&run_causal_app_facing_nine_level_evaluator_tool.step);

    const causal_app_facing_nine_level_evaluator_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-nine-level-evaluator-tests",
        .root_module = causal_app_facing_nine_level_evaluator_tool_module,
    });
    const run_causal_app_facing_nine_level_evaluator_tool_tests = b.addRunArtifact(causal_app_facing_nine_level_evaluator_tool_tests);
    test_step.dependOn(&run_causal_app_facing_nine_level_evaluator_tool_tests.step);

    const causal_app_facing_ten_level_report_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_ten_level_report.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_ten_level_report_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-ten-level-report",
        .root_module = causal_app_facing_ten_level_report_tool_module,
    });
    const run_causal_app_facing_ten_level_report_tool = b.addRunArtifact(causal_app_facing_ten_level_report_tool);
    if (b.args) |args| run_causal_app_facing_ten_level_report_tool.addArgs(args);
    const causal_app_facing_ten_level_report_step = b.step("causal-app-facing-ten-level-report", "Summarize app-facing nine-level evaluator evidence");
    causal_app_facing_ten_level_report_step.dependOn(&run_causal_app_facing_ten_level_report_tool.step);

    const causal_app_facing_ten_level_report_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-ten-level-report-tests",
        .root_module = causal_app_facing_ten_level_report_tool_module,
    });
    const run_causal_app_facing_ten_level_report_tool_tests = b.addRunArtifact(causal_app_facing_ten_level_report_tool_tests);
    test_step.dependOn(&run_causal_app_facing_ten_level_report_tool_tests.step);

    const causal_app_facing_ten_level_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_ten_level_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_ten_level_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-ten-level-application-boundary",
        .root_module = causal_app_facing_ten_level_application_boundary_tool_module,
    });
    const run_causal_app_facing_ten_level_application_boundary_tool = b.addRunArtifact(causal_app_facing_ten_level_application_boundary_tool);
    if (b.args) |args| run_causal_app_facing_ten_level_application_boundary_tool.addArgs(args);
    const causal_app_facing_ten_level_application_boundary_step = b.step("causal-app-facing-ten-level-application-boundary", "Record app-facing ten-level application boundary evidence");
    causal_app_facing_ten_level_application_boundary_step.dependOn(&run_causal_app_facing_ten_level_application_boundary_tool.step);

    const causal_app_facing_ten_level_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-ten-level-application-boundary-tests",
        .root_module = causal_app_facing_ten_level_application_boundary_tool_module,
    });
    const run_causal_app_facing_ten_level_application_boundary_tool_tests = b.addRunArtifact(causal_app_facing_ten_level_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_app_facing_ten_level_application_boundary_tool_tests.step);

    const causal_app_facing_ten_level_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_ten_level_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_ten_level_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-ten-level-policy",
        .root_module = causal_app_facing_ten_level_policy_tool_module,
    });
    const run_causal_app_facing_ten_level_policy_tool = b.addRunArtifact(causal_app_facing_ten_level_policy_tool);
    if (b.args) |args| run_causal_app_facing_ten_level_policy_tool.addArgs(args);
    const causal_app_facing_ten_level_policy_step = b.step("causal-app-facing-ten-level-policy", "Record app-facing ten-level policy evidence");
    causal_app_facing_ten_level_policy_step.dependOn(&run_causal_app_facing_ten_level_policy_tool.step);

    const causal_app_facing_ten_level_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-ten-level-policy-tests",
        .root_module = causal_app_facing_ten_level_policy_tool_module,
    });
    const run_causal_app_facing_ten_level_policy_tool_tests = b.addRunArtifact(causal_app_facing_ten_level_policy_tool_tests);
    test_step.dependOn(&run_causal_app_facing_ten_level_policy_tool_tests.step);

    const causal_app_facing_ten_level_evaluator_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_ten_level_evaluator.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_ten_level_evaluator_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-ten-level-evaluator",
        .root_module = causal_app_facing_ten_level_evaluator_tool_module,
    });
    const run_causal_app_facing_ten_level_evaluator_tool = b.addRunArtifact(causal_app_facing_ten_level_evaluator_tool);
    if (b.args) |args| run_causal_app_facing_ten_level_evaluator_tool.addArgs(args);
    const causal_app_facing_ten_level_evaluator_step = b.step("causal-app-facing-ten-level-evaluator", "Evaluate app-facing ten-level policy evidence");
    causal_app_facing_ten_level_evaluator_step.dependOn(&run_causal_app_facing_ten_level_evaluator_tool.step);

    const causal_app_facing_ten_level_evaluator_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-ten-level-evaluator-tests",
        .root_module = causal_app_facing_ten_level_evaluator_tool_module,
    });
    const run_causal_app_facing_ten_level_evaluator_tool_tests = b.addRunArtifact(causal_app_facing_ten_level_evaluator_tool_tests);
    test_step.dependOn(&run_causal_app_facing_ten_level_evaluator_tool_tests.step);

    const causal_app_facing_eleven_level_report_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_eleven_level_report.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_eleven_level_report_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-eleven-level-report",
        .root_module = causal_app_facing_eleven_level_report_tool_module,
    });
    const run_causal_app_facing_eleven_level_report_tool = b.addRunArtifact(causal_app_facing_eleven_level_report_tool);
    if (b.args) |args| run_causal_app_facing_eleven_level_report_tool.addArgs(args);
    const causal_app_facing_eleven_level_report_step = b.step("causal-app-facing-eleven-level-report", "Summarize app-facing ten-level evaluator evidence");
    causal_app_facing_eleven_level_report_step.dependOn(&run_causal_app_facing_eleven_level_report_tool.step);

    const causal_app_facing_eleven_level_report_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-eleven-level-report-tests",
        .root_module = causal_app_facing_eleven_level_report_tool_module,
    });
    const run_causal_app_facing_eleven_level_report_tool_tests = b.addRunArtifact(causal_app_facing_eleven_level_report_tool_tests);
    test_step.dependOn(&run_causal_app_facing_eleven_level_report_tool_tests.step);

    const causal_app_facing_eleven_level_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_eleven_level_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_eleven_level_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-eleven-level-application-boundary",
        .root_module = causal_app_facing_eleven_level_application_boundary_tool_module,
    });
    const run_causal_app_facing_eleven_level_application_boundary_tool = b.addRunArtifact(causal_app_facing_eleven_level_application_boundary_tool);
    if (b.args) |args| run_causal_app_facing_eleven_level_application_boundary_tool.addArgs(args);
    const causal_app_facing_eleven_level_application_boundary_step = b.step("causal-app-facing-eleven-level-application-boundary", "Record app-facing eleven-level application boundary evidence");
    causal_app_facing_eleven_level_application_boundary_step.dependOn(&run_causal_app_facing_eleven_level_application_boundary_tool.step);

    const causal_app_facing_eleven_level_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-eleven-level-application-boundary-tests",
        .root_module = causal_app_facing_eleven_level_application_boundary_tool_module,
    });
    const run_causal_app_facing_eleven_level_application_boundary_tool_tests = b.addRunArtifact(causal_app_facing_eleven_level_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_app_facing_eleven_level_application_boundary_tool_tests.step);

    const causal_app_facing_eleven_level_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_eleven_level_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_eleven_level_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-eleven-level-policy",
        .root_module = causal_app_facing_eleven_level_policy_tool_module,
    });
    const run_causal_app_facing_eleven_level_policy_tool = b.addRunArtifact(causal_app_facing_eleven_level_policy_tool);
    if (b.args) |args| run_causal_app_facing_eleven_level_policy_tool.addArgs(args);
    const causal_app_facing_eleven_level_policy_step = b.step("causal-app-facing-eleven-level-policy", "Record app-facing eleven-level policy evidence");
    causal_app_facing_eleven_level_policy_step.dependOn(&run_causal_app_facing_eleven_level_policy_tool.step);

    const causal_app_facing_eleven_level_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-eleven-level-policy-tests",
        .root_module = causal_app_facing_eleven_level_policy_tool_module,
    });
    const run_causal_app_facing_eleven_level_policy_tool_tests = b.addRunArtifact(causal_app_facing_eleven_level_policy_tool_tests);
    test_step.dependOn(&run_causal_app_facing_eleven_level_policy_tool_tests.step);

    const causal_app_facing_eleven_level_evaluator_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_eleven_level_evaluator.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_eleven_level_evaluator_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-eleven-level-evaluator",
        .root_module = causal_app_facing_eleven_level_evaluator_tool_module,
    });
    const run_causal_app_facing_eleven_level_evaluator_tool = b.addRunArtifact(causal_app_facing_eleven_level_evaluator_tool);
    if (b.args) |args| run_causal_app_facing_eleven_level_evaluator_tool.addArgs(args);
    const causal_app_facing_eleven_level_evaluator_step = b.step("causal-app-facing-eleven-level-evaluator", "Evaluate app-facing eleven-level policy evidence");
    causal_app_facing_eleven_level_evaluator_step.dependOn(&run_causal_app_facing_eleven_level_evaluator_tool.step);

    const causal_app_facing_eleven_level_evaluator_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-eleven-level-evaluator-tests",
        .root_module = causal_app_facing_eleven_level_evaluator_tool_module,
    });
    const run_causal_app_facing_eleven_level_evaluator_tool_tests = b.addRunArtifact(causal_app_facing_eleven_level_evaluator_tool_tests);
    test_step.dependOn(&run_causal_app_facing_eleven_level_evaluator_tool_tests.step);

    const causal_app_facing_twelve_level_report_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_twelve_level_report.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_twelve_level_report_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-twelve-level-report",
        .root_module = causal_app_facing_twelve_level_report_tool_module,
    });
    const run_causal_app_facing_twelve_level_report_tool = b.addRunArtifact(causal_app_facing_twelve_level_report_tool);
    if (b.args) |args| run_causal_app_facing_twelve_level_report_tool.addArgs(args);
    const causal_app_facing_twelve_level_report_step = b.step("causal-app-facing-twelve-level-report", "Summarize app-facing eleven-level evaluator evidence");
    causal_app_facing_twelve_level_report_step.dependOn(&run_causal_app_facing_twelve_level_report_tool.step);

    const causal_app_facing_twelve_level_report_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-twelve-level-report-tests",
        .root_module = causal_app_facing_twelve_level_report_tool_module,
    });
    const run_causal_app_facing_twelve_level_report_tool_tests = b.addRunArtifact(causal_app_facing_twelve_level_report_tool_tests);
    test_step.dependOn(&run_causal_app_facing_twelve_level_report_tool_tests.step);

    const causal_app_facing_twelve_level_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_twelve_level_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_twelve_level_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-twelve-level-application-boundary",
        .root_module = causal_app_facing_twelve_level_application_boundary_tool_module,
    });
    const run_causal_app_facing_twelve_level_application_boundary_tool = b.addRunArtifact(causal_app_facing_twelve_level_application_boundary_tool);
    if (b.args) |args| run_causal_app_facing_twelve_level_application_boundary_tool.addArgs(args);
    const causal_app_facing_twelve_level_application_boundary_step = b.step("causal-app-facing-twelve-level-application-boundary", "Record app-facing twelve-level application boundary evidence");
    causal_app_facing_twelve_level_application_boundary_step.dependOn(&run_causal_app_facing_twelve_level_application_boundary_tool.step);

    const causal_app_facing_twelve_level_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-twelve-level-application-boundary-tests",
        .root_module = causal_app_facing_twelve_level_application_boundary_tool_module,
    });
    const run_causal_app_facing_twelve_level_application_boundary_tool_tests = b.addRunArtifact(causal_app_facing_twelve_level_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_app_facing_twelve_level_application_boundary_tool_tests.step);

    const causal_app_facing_twelve_level_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_twelve_level_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_facing_twelve_level_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-facing-twelve-level-policy",
        .root_module = causal_app_facing_twelve_level_policy_tool_module,
    });
    const run_causal_app_facing_twelve_level_policy_tool = b.addRunArtifact(causal_app_facing_twelve_level_policy_tool);
    if (b.args) |args| run_causal_app_facing_twelve_level_policy_tool.addArgs(args);
    const causal_app_facing_twelve_level_policy_step = b.step("causal-app-facing-twelve-level-policy", "Record app-facing twelve-level policy evidence");
    causal_app_facing_twelve_level_policy_step.dependOn(&run_causal_app_facing_twelve_level_policy_tool.step);

    const causal_app_facing_twelve_level_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-facing-twelve-level-policy-tests",
        .root_module = causal_app_facing_twelve_level_policy_tool_module,
    });
    const run_causal_app_facing_twelve_level_policy_tool_tests = b.addRunArtifact(causal_app_facing_twelve_level_policy_tool_tests);
    test_step.dependOn(&run_causal_app_facing_twelve_level_policy_tool_tests.step);

    const causal_production_telemetry_readiness_review_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_readiness_review.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_readiness_review_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-readiness-review",
        .root_module = causal_production_telemetry_readiness_review_tool_module,
    });
    const run_causal_production_telemetry_readiness_review_tool = b.addRunArtifact(causal_production_telemetry_readiness_review_tool);
    if (b.args) |args| run_causal_production_telemetry_readiness_review_tool.addArgs(args);
    const causal_production_telemetry_readiness_review_step = b.step("causal-production-telemetry-readiness-review", "Review production telemetry fixture readiness");
    causal_production_telemetry_readiness_review_step.dependOn(&run_causal_production_telemetry_readiness_review_tool.step);

    const causal_production_telemetry_readiness_review_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-readiness-review-tests",
        .root_module = causal_production_telemetry_readiness_review_tool_module,
    });
    const run_causal_production_telemetry_readiness_review_tool_tests = b.addRunArtifact(causal_production_telemetry_readiness_review_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_readiness_review_tool_tests.step);

    const causal_production_telemetry_implementation_proposal_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_implementation_proposal.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_implementation_proposal_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-implementation-proposal",
        .root_module = causal_production_telemetry_implementation_proposal_tool_module,
    });
    const run_causal_production_telemetry_implementation_proposal_tool = b.addRunArtifact(causal_production_telemetry_implementation_proposal_tool);
    if (b.args) |args| run_causal_production_telemetry_implementation_proposal_tool.addArgs(args);
    const causal_production_telemetry_implementation_proposal_step = b.step("causal-production-telemetry-implementation-proposal", "Review production telemetry implementation proposal");
    causal_production_telemetry_implementation_proposal_step.dependOn(&run_causal_production_telemetry_implementation_proposal_tool.step);

    const causal_production_telemetry_implementation_proposal_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-implementation-proposal-tests",
        .root_module = causal_production_telemetry_implementation_proposal_tool_module,
    });
    const run_causal_production_telemetry_implementation_proposal_tool_tests = b.addRunArtifact(causal_production_telemetry_implementation_proposal_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_implementation_proposal_tool_tests.step);

    const causal_production_telemetry_exporter_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_exporter_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_exporter_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-exporter-boundary",
        .root_module = causal_production_telemetry_exporter_boundary_tool_module,
    });
    const run_causal_production_telemetry_exporter_boundary_tool = b.addRunArtifact(causal_production_telemetry_exporter_boundary_tool);
    if (b.args) |args| run_causal_production_telemetry_exporter_boundary_tool.addArgs(args);
    const causal_production_telemetry_exporter_boundary_step = b.step("causal-production-telemetry-exporter-boundary", "Review production telemetry exporter boundary");
    causal_production_telemetry_exporter_boundary_step.dependOn(&run_causal_production_telemetry_exporter_boundary_tool.step);

    const causal_production_telemetry_exporter_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-exporter-boundary-tests",
        .root_module = causal_production_telemetry_exporter_boundary_tool_module,
    });
    const run_causal_production_telemetry_exporter_boundary_tool_tests = b.addRunArtifact(causal_production_telemetry_exporter_boundary_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_exporter_boundary_tool_tests.step);

    const causal_production_telemetry_local_pipeline_fixtures_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_local_pipeline_fixtures.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_local_pipeline_fixtures_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-local-pipeline-fixtures",
        .root_module = causal_production_telemetry_local_pipeline_fixtures_tool_module,
    });
    const run_causal_production_telemetry_local_pipeline_fixtures_tool = b.addRunArtifact(causal_production_telemetry_local_pipeline_fixtures_tool);
    if (b.args) |args| run_causal_production_telemetry_local_pipeline_fixtures_tool.addArgs(args);
    const causal_production_telemetry_local_pipeline_fixtures_step = b.step("causal-production-telemetry-local-pipeline-fixtures", "Review production telemetry local pipeline fixtures");
    causal_production_telemetry_local_pipeline_fixtures_step.dependOn(&run_causal_production_telemetry_local_pipeline_fixtures_tool.step);

    const causal_production_telemetry_local_pipeline_fixtures_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-local-pipeline-fixtures-tests",
        .root_module = causal_production_telemetry_local_pipeline_fixtures_tool_module,
    });
    const run_causal_production_telemetry_local_pipeline_fixtures_tool_tests = b.addRunArtifact(causal_production_telemetry_local_pipeline_fixtures_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_local_pipeline_fixtures_tool_tests.step);

    const causal_production_telemetry_nendb_retention_fixtures_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_nendb_retention_fixtures.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_nendb_retention_fixtures_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-nendb-retention-fixtures",
        .root_module = causal_production_telemetry_nendb_retention_fixtures_tool_module,
    });
    const run_causal_production_telemetry_nendb_retention_fixtures_tool = b.addRunArtifact(causal_production_telemetry_nendb_retention_fixtures_tool);
    if (b.args) |args| run_causal_production_telemetry_nendb_retention_fixtures_tool.addArgs(args);
    const causal_production_telemetry_nendb_retention_fixtures_step = b.step("causal-production-telemetry-nendb-retention-fixtures", "Review production telemetry NenDB retention fixtures");
    causal_production_telemetry_nendb_retention_fixtures_step.dependOn(&run_causal_production_telemetry_nendb_retention_fixtures_tool.step);

    const causal_production_telemetry_nendb_retention_fixtures_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-nendb-retention-fixtures-tests",
        .root_module = causal_production_telemetry_nendb_retention_fixtures_tool_module,
    });
    const run_causal_production_telemetry_nendb_retention_fixtures_tool_tests = b.addRunArtifact(causal_production_telemetry_nendb_retention_fixtures_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_nendb_retention_fixtures_tool_tests.step);

    const causal_production_telemetry_workbench_readonly_preview_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_workbench_readonly_preview.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_workbench_readonly_preview_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-workbench-readonly-preview",
        .root_module = causal_production_telemetry_workbench_readonly_preview_tool_module,
    });
    const run_causal_production_telemetry_workbench_readonly_preview_tool = b.addRunArtifact(causal_production_telemetry_workbench_readonly_preview_tool);
    if (b.args) |args| run_causal_production_telemetry_workbench_readonly_preview_tool.addArgs(args);
    const causal_production_telemetry_workbench_readonly_preview_step = b.step("causal-production-telemetry-workbench-readonly-preview", "Review production telemetry workbench read-only preview");
    causal_production_telemetry_workbench_readonly_preview_step.dependOn(&run_causal_production_telemetry_workbench_readonly_preview_tool.step);

    const causal_production_telemetry_workbench_readonly_preview_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-workbench-readonly-preview-tests",
        .root_module = causal_production_telemetry_workbench_readonly_preview_tool_module,
    });
    const run_causal_production_telemetry_workbench_readonly_preview_tool_tests = b.addRunArtifact(causal_production_telemetry_workbench_readonly_preview_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_workbench_readonly_preview_tool_tests.step);

    const causal_production_telemetry_ci_artifact_preview_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_artifact_preview.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_artifact_preview_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-artifact-preview",
        .root_module = causal_production_telemetry_ci_artifact_preview_tool_module,
    });
    const run_causal_production_telemetry_ci_artifact_preview_tool = b.addRunArtifact(causal_production_telemetry_ci_artifact_preview_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_artifact_preview_tool.addArgs(args);
    const causal_production_telemetry_ci_artifact_preview_step = b.step("causal-production-telemetry-ci-artifact-preview", "Review production telemetry CI artifact preview");
    causal_production_telemetry_ci_artifact_preview_step.dependOn(&run_causal_production_telemetry_ci_artifact_preview_tool.step);

    const causal_production_telemetry_ci_artifact_preview_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-artifact-preview-tests",
        .root_module = causal_production_telemetry_ci_artifact_preview_tool_module,
    });
    const run_causal_production_telemetry_ci_artifact_preview_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_artifact_preview_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_artifact_preview_tool_tests.step);

    const causal_production_telemetry_ci_harness_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_harness_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_harness_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-harness-boundary",
        .root_module = causal_production_telemetry_ci_harness_boundary_tool_module,
    });
    const run_causal_production_telemetry_ci_harness_boundary_tool = b.addRunArtifact(causal_production_telemetry_ci_harness_boundary_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_harness_boundary_tool.addArgs(args);
    const causal_production_telemetry_ci_harness_boundary_step = b.step("causal-production-telemetry-ci-harness-boundary", "Review production telemetry CI harness boundary");
    causal_production_telemetry_ci_harness_boundary_step.dependOn(&run_causal_production_telemetry_ci_harness_boundary_tool.step);

    const causal_production_telemetry_ci_harness_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-harness-boundary-tests",
        .root_module = causal_production_telemetry_ci_harness_boundary_tool_module,
    });
    const run_causal_production_telemetry_ci_harness_boundary_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_harness_boundary_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_harness_boundary_tool_tests.step);

    const causal_production_telemetry_ci_archive_application_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_archive_application.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_archive_application_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-archive-application",
        .root_module = causal_production_telemetry_ci_archive_application_tool_module,
    });
    const run_causal_production_telemetry_ci_archive_application_tool = b.addRunArtifact(causal_production_telemetry_ci_archive_application_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_archive_application_tool.addArgs(args);
    const causal_production_telemetry_ci_archive_application_step = b.step("causal-production-telemetry-ci-archive-application", "Record production telemetry CI archive application evidence");
    causal_production_telemetry_ci_archive_application_step.dependOn(&run_causal_production_telemetry_ci_archive_application_tool.step);

    const causal_production_telemetry_ci_archive_application_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-archive-application-tests",
        .root_module = causal_production_telemetry_ci_archive_application_tool_module,
    });
    const run_causal_production_telemetry_ci_archive_application_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_archive_application_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_archive_application_tool_tests.step);

    const causal_production_telemetry_ci_archive_evidence_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_archive_evidence_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_archive_evidence_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-archive-evidence-policy",
        .root_module = causal_production_telemetry_ci_archive_evidence_policy_tool_module,
    });
    const run_causal_production_telemetry_ci_archive_evidence_policy_tool = b.addRunArtifact(causal_production_telemetry_ci_archive_evidence_policy_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_archive_evidence_policy_tool.addArgs(args);
    const causal_production_telemetry_ci_archive_evidence_policy_step = b.step("causal-production-telemetry-ci-archive-evidence-policy", "Review production telemetry CI archive evidence policy");
    causal_production_telemetry_ci_archive_evidence_policy_step.dependOn(&run_causal_production_telemetry_ci_archive_evidence_policy_tool.step);

    const causal_production_telemetry_ci_archive_evidence_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-archive-evidence-policy-tests",
        .root_module = causal_production_telemetry_ci_archive_evidence_policy_tool_module,
    });
    const run_causal_production_telemetry_ci_archive_evidence_policy_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_archive_evidence_policy_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_archive_evidence_policy_tool_tests.step);

    const causal_production_telemetry_ci_gate_readiness_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_readiness.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_gate_readiness_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-readiness",
        .root_module = causal_production_telemetry_ci_gate_readiness_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_readiness_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_readiness_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_gate_readiness_tool.addArgs(args);
    const causal_production_telemetry_ci_gate_readiness_step = b.step("causal-production-telemetry-ci-gate-readiness", "Review production telemetry CI gate readiness");
    causal_production_telemetry_ci_gate_readiness_step.dependOn(&run_causal_production_telemetry_ci_gate_readiness_tool.step);

    const causal_production_telemetry_ci_gate_readiness_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-readiness-tests",
        .root_module = causal_production_telemetry_ci_gate_readiness_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_readiness_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_readiness_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_gate_readiness_tool_tests.step);

    const causal_production_telemetry_ci_gate_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_gate_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-application-boundary",
        .root_module = causal_production_telemetry_ci_gate_application_boundary_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_application_boundary_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_application_boundary_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_gate_application_boundary_tool.addArgs(args);
    const causal_production_telemetry_ci_gate_application_boundary_step = b.step("causal-production-telemetry-ci-gate-application-boundary", "Review production telemetry CI gate application boundary");
    causal_production_telemetry_ci_gate_application_boundary_step.dependOn(&run_causal_production_telemetry_ci_gate_application_boundary_tool.step);

    const causal_production_telemetry_ci_gate_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-application-boundary-tests",
        .root_module = causal_production_telemetry_ci_gate_application_boundary_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_application_boundary_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_gate_application_boundary_tool_tests.step);

    const causal_production_telemetry_ci_gate_dry_run_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_dry_run_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_gate_dry_run_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-dry-run-policy",
        .root_module = causal_production_telemetry_ci_gate_dry_run_policy_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_dry_run_policy_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_dry_run_policy_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_gate_dry_run_policy_tool.addArgs(args);
    const causal_production_telemetry_ci_gate_dry_run_policy_step = b.step("causal-production-telemetry-ci-gate-dry-run-policy", "Review production telemetry CI gate dry-run policy");
    causal_production_telemetry_ci_gate_dry_run_policy_step.dependOn(&run_causal_production_telemetry_ci_gate_dry_run_policy_tool.step);

    const causal_production_telemetry_ci_gate_dry_run_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-dry-run-policy-tests",
        .root_module = causal_production_telemetry_ci_gate_dry_run_policy_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_dry_run_policy_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_dry_run_policy_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_gate_dry_run_policy_tool_tests.step);

    const causal_production_telemetry_ci_gate_dry_run_evaluator_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_dry_run_evaluator.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_gate_dry_run_evaluator_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator",
        .root_module = causal_production_telemetry_ci_gate_dry_run_evaluator_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_dry_run_evaluator_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_dry_run_evaluator_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_gate_dry_run_evaluator_tool.addArgs(args);
    const causal_production_telemetry_ci_gate_dry_run_evaluator_step = b.step("causal-production-telemetry-ci-gate-dry-run-evaluator", "Evaluate production telemetry CI gate dry-run evidence");
    causal_production_telemetry_ci_gate_dry_run_evaluator_step.dependOn(&run_causal_production_telemetry_ci_gate_dry_run_evaluator_tool.step);

    const causal_production_telemetry_ci_gate_dry_run_evaluator_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator-tests",
        .root_module = causal_production_telemetry_ci_gate_dry_run_evaluator_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_dry_run_evaluator_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_dry_run_evaluator_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_gate_dry_run_evaluator_tool_tests.step);

    const causal_production_telemetry_ci_gate_advisory_ci_report_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_advisory_ci_report.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_gate_advisory_ci_report_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report",
        .root_module = causal_production_telemetry_ci_gate_advisory_ci_report_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_advisory_ci_report_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_advisory_ci_report_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_gate_advisory_ci_report_tool.addArgs(args);
    const causal_production_telemetry_ci_gate_advisory_ci_report_step = b.step("causal-production-telemetry-ci-gate-advisory-ci-report", "Render production telemetry CI gate advisory CI report");
    causal_production_telemetry_ci_gate_advisory_ci_report_step.dependOn(&run_causal_production_telemetry_ci_gate_advisory_ci_report_tool.step);

    const causal_production_telemetry_ci_gate_advisory_ci_report_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-tests",
        .root_module = causal_production_telemetry_ci_gate_advisory_ci_report_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_advisory_ci_report_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_advisory_ci_report_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_gate_advisory_ci_report_tool_tests.step);

    const causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary",
        .root_module = causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary_tool.addArgs(args);
    const causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary_step = b.step("causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary", "Record production telemetry CI gate advisory CI report application boundary");
    causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary_step.dependOn(&run_causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary_tool.step);

    const causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary-tests",
        .root_module = causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary_tool_tests.step);

    const causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy",
        .root_module = causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy_tool.addArgs(args);
    const causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy_step = b.step("causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy", "Review production telemetry CI gate advisory CI report publication policy");
    causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy_step.dependOn(&run_causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy_tool.step);

    const causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy-tests",
        .root_module = causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy_tool_tests.step);

    const causal_production_telemetry_ci_gate_required_status_check_readiness_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_required_status_check_readiness.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_gate_required_status_check_readiness_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_readiness_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_readiness_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_readiness_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_gate_required_status_check_readiness_tool.addArgs(args);
    const causal_production_telemetry_ci_gate_required_status_check_readiness_step = b.step("causal-production-telemetry-ci-gate-required-status-check-readiness", "Review production telemetry CI gate required status check readiness");
    causal_production_telemetry_ci_gate_required_status_check_readiness_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_readiness_tool.step);

    const causal_production_telemetry_ci_gate_required_status_check_readiness_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness-tests",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_readiness_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_readiness_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_readiness_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_readiness_tool_tests.step);

    const causal_production_telemetry_ci_gate_required_status_check_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_required_status_check_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_gate_required_status_check_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_application_boundary_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_application_boundary_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_application_boundary_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_gate_required_status_check_application_boundary_tool.addArgs(args);
    const causal_production_telemetry_ci_gate_required_status_check_application_boundary_step = b.step("causal-production-telemetry-ci-gate-required-status-check-application-boundary", "Review production telemetry CI gate required status check application boundary");
    causal_production_telemetry_ci_gate_required_status_check_application_boundary_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_application_boundary_tool.step);

    const causal_production_telemetry_ci_gate_required_status_check_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary-tests",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_application_boundary_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_application_boundary_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_application_boundary_tool_tests.step);

    const causal_production_telemetry_ci_gate_required_status_check_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_gate_required_status_check_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_policy_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_policy_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_policy_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_gate_required_status_check_policy_tool.addArgs(args);
    const causal_production_telemetry_ci_gate_required_status_check_policy_step = b.step("causal-production-telemetry-ci-gate-required-status-check-policy", "Review production telemetry CI gate required status check policy");
    causal_production_telemetry_ci_gate_required_status_check_policy_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_policy_tool.step);

    const causal_production_telemetry_ci_gate_required_status_check_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy-tests",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_policy_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_policy_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_policy_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_policy_tool_tests.step);

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness_tool.addArgs(args);
    const causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness_step = b.step("causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness", "Review production telemetry CI gate required status check enforcement readiness");
    causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness_tool.step);

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness-tests",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness_tool_tests.step);

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_tool.addArgs(args);
    const causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_step = b.step("causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary", "Review production telemetry CI gate required status check enforcement application boundary");
    causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_tool.step);

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary-tests",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_tool_tests.step);

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool.addArgs(args);
    const causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_step = b.step("causal-production-telemetry-ci-gate-required-status-check-enforcement-policy", "Review production telemetry CI gate required status check enforcement policy");
    causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool.step);

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy-tests",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool_tests.step);

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_evaluator_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_evaluator.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_evaluator_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_enforcement_evaluator_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_enforcement_evaluator_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_enforcement_evaluator_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_gate_required_status_check_enforcement_evaluator_tool.addArgs(args);
    const causal_production_telemetry_ci_gate_required_status_check_enforcement_evaluator_step = b.step("causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator", "Evaluate production telemetry CI gate required status check enforcement evidence");
    causal_production_telemetry_ci_gate_required_status_check_enforcement_evaluator_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_enforcement_evaluator_tool.step);

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_evaluator_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator-tests",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_enforcement_evaluator_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_enforcement_evaluator_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_enforcement_evaluator_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_enforcement_evaluator_tool_tests.step);

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_report_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_report_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_enforcement_report_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_enforcement_report_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_tool.addArgs(args);
    const causal_production_telemetry_ci_gate_required_status_check_enforcement_report_step = b.step("causal-production-telemetry-ci-gate-required-status-check-enforcement-report", "Render production telemetry CI gate required status check enforcement report");
    causal_production_telemetry_ci_gate_required_status_check_enforcement_report_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_tool.step);

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_report_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-tests",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_enforcement_report_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_enforcement_report_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_tool_tests.step);

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_tool.addArgs(args);
    const causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_step = b.step("causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary", "Record production telemetry CI gate required status check enforcement report application boundary");
    causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_tool.step);

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary-tests",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_tool_tests.step);

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool);
    if (b.args) |args| run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool.addArgs(args);
    const causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_step = b.step("causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy", "Review production telemetry CI gate required status check enforcement report policy");
    causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool.step);

    const causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy-tests",
        .root_module = causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool_module,
    });
    const run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool_tests);
    test_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool_tests.step);

    const causal_m9_completion_audit_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_m9_completion_audit.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_m9_completion_audit_tool = b.addExecutable(.{
        .name = "zigeffect-causal-m9-completion-audit",
        .root_module = causal_m9_completion_audit_tool_module,
    });
    const run_causal_m9_completion_audit_tool = b.addRunArtifact(causal_m9_completion_audit_tool);
    if (b.args) |args| run_causal_m9_completion_audit_tool.addArgs(args);
    const causal_m9_completion_audit_step = b.step("causal-m9-completion-audit", "Print causal M9 operating-model completion audit");
    causal_m9_completion_audit_step.dependOn(&run_causal_m9_completion_audit_tool.step);

    const causal_m9_completion_audit_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-m9-completion-audit-tests",
        .root_module = causal_m9_completion_audit_tool_module,
    });
    const run_causal_m9_completion_audit_tool_tests = b.addRunArtifact(causal_m9_completion_audit_tool_tests);
    test_step.dependOn(&run_causal_m9_completion_audit_tool_tests.step);

    const causal_production_hardening_backlog_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_hardening_backlog.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_hardening_backlog_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-hardening-backlog",
        .root_module = causal_production_hardening_backlog_tool_module,
    });
    const run_causal_production_hardening_backlog_tool = b.addRunArtifact(causal_production_hardening_backlog_tool);
    if (b.args) |args| run_causal_production_hardening_backlog_tool.addArgs(args);
    const causal_production_hardening_backlog_step = b.step("causal-production-hardening-backlog", "Print causal production-hardening backlog report");
    causal_production_hardening_backlog_step.dependOn(&run_causal_production_hardening_backlog_tool.step);

    const causal_production_hardening_backlog_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-hardening-backlog-tests",
        .root_module = causal_production_hardening_backlog_tool_module,
    });
    const run_causal_production_hardening_backlog_tool_tests = b.addRunArtifact(causal_production_hardening_backlog_tool_tests);
    test_step.dependOn(&run_causal_production_hardening_backlog_tool_tests.step);

    const causal_production_hardening_backlog_refresh_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_hardening_backlog_refresh.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_hardening_backlog_refresh_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-hardening-backlog-refresh",
        .root_module = causal_production_hardening_backlog_refresh_tool_module,
    });
    const run_causal_production_hardening_backlog_refresh_tool = b.addRunArtifact(causal_production_hardening_backlog_refresh_tool);
    if (b.args) |args| run_causal_production_hardening_backlog_refresh_tool.addArgs(args);
    const causal_production_hardening_backlog_refresh_step = b.step("causal-production-hardening-backlog-refresh", "Refresh production hardening backlog and select next unresolved branch");
    causal_production_hardening_backlog_refresh_step.dependOn(&run_causal_production_hardening_backlog_refresh_tool.step);

    const causal_production_hardening_backlog_refresh_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-hardening-backlog-refresh-tests",
        .root_module = causal_production_hardening_backlog_refresh_tool_module,
    });
    const run_causal_production_hardening_backlog_refresh_tool_tests = b.addRunArtifact(causal_production_hardening_backlog_refresh_tool_tests);
    test_step.dependOn(&run_causal_production_hardening_backlog_refresh_tool_tests.step);

    const causal_nendb_durable_history_hardening_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_nendb_durable_history_hardening.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_nendb_durable_history_hardening_tool_module.addImport("zigeffect", zigeffect);

    const causal_nendb_durable_history_hardening_tool = b.addExecutable(.{
        .name = "zigeffect-causal-nendb-durable-history-hardening",
        .root_module = causal_nendb_durable_history_hardening_tool_module,
    });
    const run_causal_nendb_durable_history_hardening_tool = b.addRunArtifact(causal_nendb_durable_history_hardening_tool);
    if (b.args) |args| run_causal_nendb_durable_history_hardening_tool.addArgs(args);
    const causal_nendb_durable_history_hardening_step = b.step("causal-nendb-durable-history-hardening", "Emit NenDB durable-history hardening fixture");
    causal_nendb_durable_history_hardening_step.dependOn(&run_causal_nendb_durable_history_hardening_tool.step);

    const causal_nendb_durable_history_hardening_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-nendb-durable-history-hardening-tests",
        .root_module = causal_nendb_durable_history_hardening_tool_module,
    });
    const run_causal_nendb_durable_history_hardening_tool_tests = b.addRunArtifact(causal_nendb_durable_history_hardening_tool_tests);
    test_step.dependOn(&run_causal_nendb_durable_history_hardening_tool_tests.step);

    const causal_production_artifact_aggregation_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_artifact_aggregation.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_artifact_aggregation_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-artifact-aggregation",
        .root_module = causal_production_artifact_aggregation_tool_module,
    });
    const run_causal_production_artifact_aggregation_tool = b.addRunArtifact(causal_production_artifact_aggregation_tool);
    if (b.args) |args| run_causal_production_artifact_aggregation_tool.addArgs(args);
    const causal_production_artifact_aggregation_step = b.step("causal-production-artifact-aggregation", "Print causal production artifact aggregation contract");
    causal_production_artifact_aggregation_step.dependOn(&run_causal_production_artifact_aggregation_tool.step);

    const causal_production_artifact_aggregation_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-artifact-aggregation-tests",
        .root_module = causal_production_artifact_aggregation_tool_module,
    });
    const run_causal_production_artifact_aggregation_tool_tests = b.addRunArtifact(causal_production_artifact_aggregation_tool_tests);
    test_step.dependOn(&run_causal_production_artifact_aggregation_tool_tests.step);

    const causal_durable_production_retention_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_durable_production_retention.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_durable_production_retention_tool = b.addExecutable(.{
        .name = "zigeffect-causal-durable-production-retention",
        .root_module = causal_durable_production_retention_tool_module,
    });
    const run_causal_durable_production_retention_tool = b.addRunArtifact(causal_durable_production_retention_tool);
    if (b.args) |args| run_causal_durable_production_retention_tool.addArgs(args);
    const causal_durable_production_retention_step = b.step("causal-durable-production-retention", "Print causal durable production retention contract");
    causal_durable_production_retention_step.dependOn(&run_causal_durable_production_retention_tool.step);

    const causal_durable_production_retention_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-durable-production-retention-tests",
        .root_module = causal_durable_production_retention_tool_module,
    });
    const run_causal_durable_production_retention_tool_tests = b.addRunArtifact(causal_durable_production_retention_tool_tests);
    test_step.dependOn(&run_causal_durable_production_retention_tool_tests.step);

    const causal_production_deployment_runbooks_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_production_deployment_runbooks.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_production_deployment_runbooks_tool = b.addExecutable(.{
        .name = "zigeffect-causal-production-deployment-runbooks",
        .root_module = causal_production_deployment_runbooks_tool_module,
    });
    const run_causal_production_deployment_runbooks_tool = b.addRunArtifact(causal_production_deployment_runbooks_tool);
    if (b.args) |args| run_causal_production_deployment_runbooks_tool.addArgs(args);
    const causal_production_deployment_runbooks_step = b.step("causal-production-deployment-runbooks", "Print causal production deployment runbooks report");
    causal_production_deployment_runbooks_step.dependOn(&run_causal_production_deployment_runbooks_tool.step);

    const causal_production_deployment_runbooks_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-production-deployment-runbooks-tests",
        .root_module = causal_production_deployment_runbooks_tool_module,
    });
    const run_causal_production_deployment_runbooks_tool_tests = b.addRunArtifact(causal_production_deployment_runbooks_tool_tests);
    test_step.dependOn(&run_causal_production_deployment_runbooks_tool_tests.step);

    const causal_artifact_access_control_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_artifact_access_control.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_artifact_access_control_tool = b.addExecutable(.{
        .name = "zigeffect-causal-artifact-access-control",
        .root_module = causal_artifact_access_control_tool_module,
    });
    const run_causal_artifact_access_control_tool = b.addRunArtifact(causal_artifact_access_control_tool);
    if (b.args) |args| run_causal_artifact_access_control_tool.addArgs(args);
    const causal_artifact_access_control_step = b.step("causal-artifact-access-control", "Print causal artifact access-control report");
    causal_artifact_access_control_step.dependOn(&run_causal_artifact_access_control_tool.step);

    const causal_artifact_access_control_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-artifact-access-control-tests",
        .root_module = causal_artifact_access_control_tool_module,
    });
    const run_causal_artifact_access_control_tool_tests = b.addRunArtifact(causal_artifact_access_control_tool_tests);
    test_step.dependOn(&run_causal_artifact_access_control_tool_tests.step);

    const causal_encryption_at_rest_policy_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_encryption_at_rest_policy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_encryption_at_rest_policy_tool = b.addExecutable(.{
        .name = "zigeffect-causal-encryption-at-rest-policy",
        .root_module = causal_encryption_at_rest_policy_tool_module,
    });
    const run_causal_encryption_at_rest_policy_tool = b.addRunArtifact(causal_encryption_at_rest_policy_tool);
    if (b.args) |args| run_causal_encryption_at_rest_policy_tool.addArgs(args);
    const causal_encryption_at_rest_policy_step = b.step("causal-encryption-at-rest-policy", "Print causal encryption-at-rest policy report");
    causal_encryption_at_rest_policy_step.dependOn(&run_causal_encryption_at_rest_policy_tool.step);

    const causal_encryption_at_rest_policy_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-encryption-at-rest-policy-tests",
        .root_module = causal_encryption_at_rest_policy_tool_module,
    });
    const run_causal_encryption_at_rest_policy_tool_tests = b.addRunArtifact(causal_encryption_at_rest_policy_tool_tests);
    test_step.dependOn(&run_causal_encryption_at_rest_policy_tool_tests.step);

    const causal_alerting_integrations_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_alerting_integrations.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_alerting_integrations_tool = b.addExecutable(.{
        .name = "zigeffect-causal-alerting-integrations",
        .root_module = causal_alerting_integrations_tool_module,
    });
    const run_causal_alerting_integrations_tool = b.addRunArtifact(causal_alerting_integrations_tool);
    if (b.args) |args| run_causal_alerting_integrations_tool.addArgs(args);
    const causal_alerting_integrations_step = b.step("causal-alerting-integrations", "Print causal alerting integrations report");
    causal_alerting_integrations_step.dependOn(&run_causal_alerting_integrations_tool.step);

    const causal_alerting_integrations_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-alerting-integrations-tests",
        .root_module = causal_alerting_integrations_tool_module,
    });
    const run_causal_alerting_integrations_tool_tests = b.addRunArtifact(causal_alerting_integrations_tool_tests);
    test_step.dependOn(&run_causal_alerting_integrations_tool_tests.step);

    const causal_live_dashboard_streaming_workbench_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_live_dashboard_streaming_workbench.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_live_dashboard_streaming_workbench_tool = b.addExecutable(.{
        .name = "zigeffect-causal-live-dashboard-streaming-workbench",
        .root_module = causal_live_dashboard_streaming_workbench_tool_module,
    });
    const run_causal_live_dashboard_streaming_workbench_tool = b.addRunArtifact(causal_live_dashboard_streaming_workbench_tool);
    if (b.args) |args| run_causal_live_dashboard_streaming_workbench_tool.addArgs(args);
    const causal_live_dashboard_streaming_workbench_step = b.step("causal-live-dashboard-streaming-workbench", "Print causal live dashboard streaming workbench report");
    causal_live_dashboard_streaming_workbench_step.dependOn(&run_causal_live_dashboard_streaming_workbench_tool.step);

    const causal_live_dashboard_streaming_workbench_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-live-dashboard-streaming-workbench-tests",
        .root_module = causal_live_dashboard_streaming_workbench_tool_module,
    });
    const run_causal_live_dashboard_streaming_workbench_tool_tests = b.addRunArtifact(causal_live_dashboard_streaming_workbench_tool_tests);
    test_step.dependOn(&run_causal_live_dashboard_streaming_workbench_tool_tests.step);

    const causal_unified_spine_contract_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_unified_spine_contract.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_unified_spine_contract_tool = b.addExecutable(.{
        .name = "zigeffect-causal-unified-spine-contract",
        .root_module = causal_unified_spine_contract_tool_module,
    });
    const run_causal_unified_spine_contract_tool = b.addRunArtifact(causal_unified_spine_contract_tool);
    if (b.args) |args| run_causal_unified_spine_contract_tool.addArgs(args);
    const causal_unified_spine_contract_step = b.step("causal-unified-spine-contract", "Print causal unified spine contract");
    causal_unified_spine_contract_step.dependOn(&run_causal_unified_spine_contract_tool.step);

    const causal_unified_spine_contract_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-unified-spine-contract-tests",
        .root_module = causal_unified_spine_contract_tool_module,
    });
    const run_causal_unified_spine_contract_tool_tests = b.addRunArtifact(causal_unified_spine_contract_tool_tests);
    test_step.dependOn(&run_causal_unified_spine_contract_tool_tests.step);

    const causal_human_agent_feedback_loop_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_human_agent_feedback_loop.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_human_agent_feedback_loop_tool = b.addExecutable(.{
        .name = "zigeffect-causal-human-agent-feedback-loop",
        .root_module = causal_human_agent_feedback_loop_tool_module,
    });
    const run_causal_human_agent_feedback_loop_tool = b.addRunArtifact(causal_human_agent_feedback_loop_tool);
    if (b.args) |args| run_causal_human_agent_feedback_loop_tool.addArgs(args);
    const causal_human_agent_feedback_loop_step = b.step("causal-human-agent-feedback-loop", "Print causal human-agent feedback loop report");
    causal_human_agent_feedback_loop_step.dependOn(&run_causal_human_agent_feedback_loop_tool.step);

    const causal_human_agent_feedback_loop_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-human-agent-feedback-loop-tests",
        .root_module = causal_human_agent_feedback_loop_tool_module,
    });
    const run_causal_human_agent_feedback_loop_tool_tests = b.addRunArtifact(causal_human_agent_feedback_loop_tool_tests);
    test_step.dependOn(&run_causal_human_agent_feedback_loop_tool_tests.step);

    const causal_rollout_automation_guardrails_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_rollout_automation_guardrails.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_rollout_automation_guardrails_tool = b.addExecutable(.{
        .name = "zigeffect-causal-rollout-automation-guardrails",
        .root_module = causal_rollout_automation_guardrails_tool_module,
    });
    const run_causal_rollout_automation_guardrails_tool = b.addRunArtifact(causal_rollout_automation_guardrails_tool);
    if (b.args) |args| run_causal_rollout_automation_guardrails_tool.addArgs(args);
    const causal_rollout_automation_guardrails_step = b.step("causal-rollout-automation-guardrails", "Print causal rollout automation guardrails report");
    causal_rollout_automation_guardrails_step.dependOn(&run_causal_rollout_automation_guardrails_tool.step);

    const causal_rollout_automation_guardrails_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-rollout-automation-guardrails-tests",
        .root_module = causal_rollout_automation_guardrails_tool_module,
    });
    const run_causal_rollout_automation_guardrails_tool_tests = b.addRunArtifact(causal_rollout_automation_guardrails_tool_tests);
    test_step.dependOn(&run_causal_rollout_automation_guardrails_tool_tests.step);

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

    const causal_app_human_review_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-human-review",
        .root_module = causal_app_human_review_tool_module,
    });
    const run_causal_app_human_review_tool = b.addRunArtifact(causal_app_human_review_tool);
    if (b.args) |args| run_causal_app_human_review_tool.addArgs(args);
    const causal_app_human_review_step = b.step("causal-app-human-review", "Write non-mutating app human-review evidence from a high-risk app policy decision");
    causal_app_human_review_step.dependOn(&run_causal_app_human_review_tool.step);

    const causal_app_patch_proposal_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-patch-proposal",
        .root_module = causal_app_patch_proposal_tool_module,
    });
    const run_causal_app_patch_proposal_tool = b.addRunArtifact(causal_app_patch_proposal_tool);
    if (b.args) |args| run_causal_app_patch_proposal_tool.addArgs(args);
    const causal_app_patch_proposal_step = b.step("causal-app-patch-proposal", "Write a non-mutating app patch proposal from an app policy decision");
    causal_app_patch_proposal_step.dependOn(&run_causal_app_patch_proposal_tool.step);

    const causal_app_application_readiness_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-application-readiness",
        .root_module = causal_app_application_readiness_tool_module,
    });
    const run_causal_app_application_readiness_tool = b.addRunArtifact(causal_app_application_readiness_tool);
    if (b.args) |args| run_causal_app_application_readiness_tool.addArgs(args);
    const causal_app_application_readiness_step = b.step("causal-app-application-readiness", "Write non-mutating app application readiness evidence from an app patch proposal");
    causal_app_application_readiness_step.dependOn(&run_causal_app_application_readiness_tool.step);

    const causal_app_apply_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-apply",
        .root_module = causal_app_apply_tool_module,
    });
    const run_causal_app_apply_tool = b.addRunArtifact(causal_app_apply_tool);
    if (b.args) |args| run_causal_app_apply_tool.addArgs(args);
    const causal_app_apply_step = b.step("causal-app-apply", "Record guarded app application evidence from app readiness");
    causal_app_apply_step.dependOn(&run_causal_app_apply_tool.step);

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
    examples_step.dependOn(&workflow_approval_example.step);
    examples_step.dependOn(&run_workflow_approval_example_tests.step);
    examples_step.dependOn(&workflow_queue_worker_example.step);
    examples_step.dependOn(&run_workflow_queue_worker_example_tests.step);
    examples_step.dependOn(&workflow_timer_signal_example.step);
    examples_step.dependOn(&run_workflow_timer_signal_example_tests.step);
    examples_step.dependOn(&workflow_crash_recovery_example.step);
    examples_step.dependOn(&run_workflow_crash_recovery_example_tests.step);
    examples_step.dependOn(&local_actor_example.step);
    examples_step.dependOn(&run_local_actor_example_tests.step);
    examples_step.dependOn(&multi_runner_cluster_example.step);
    examples_step.dependOn(&run_multi_runner_cluster_example_tests.step);
    examples_step.dependOn(&cluster_workflow_migration_example.step);
    examples_step.dependOn(&run_cluster_workflow_migration_example_tests.step);
    examples_step.dependOn(&scaffold_tool.step);
    examples_step.dependOn(&run_scaffold_tool_tests.step);
    examples_step.dependOn(&causal_report_tool.step);
    examples_step.dependOn(&run_causal_report_tool_tests.step);
    examples_step.dependOn(&causal_test_tool.step);
    examples_step.dependOn(&run_causal_test_tool_tests.step);
    examples_step.dependOn(&cluster_runner_tool.step);
    examples_step.dependOn(&run_cluster_runner_tool_tests.step);
    examples_step.dependOn(&cluster_inspect_tool.step);
    examples_step.dependOn(&run_cluster_inspect_tool_tests.step);
    examples_step.dependOn(&storage_migrate_tool.step);
    examples_step.dependOn(&run_storage_migrate_tool_tests.step);
    examples_step.dependOn(&performance_bench_tool.step);
    examples_step.dependOn(&run_performance_bench_tool_tests.step);
    examples_step.dependOn(&release_gate_report_tool.step);
    examples_step.dependOn(&run_release_gate_report_tool_tests.step);
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
    examples_step.dependOn(&causal_schema_governance_tool.step);
    examples_step.dependOn(&run_causal_schema_governance_tool_tests.step);
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
    examples_step.dependOn(&causal_app_human_review_tool.step);
    examples_step.dependOn(&run_causal_app_human_review_tool_tests.step);
    examples_step.dependOn(&causal_app_patch_proposal_tool.step);
    examples_step.dependOn(&run_causal_app_patch_proposal_tool_tests.step);
    examples_step.dependOn(&causal_app_application_readiness_tool.step);
    examples_step.dependOn(&run_causal_app_application_readiness_tool_tests.step);
    examples_step.dependOn(&causal_app_apply_tool.step);
    examples_step.dependOn(&run_causal_app_apply_tool_tests.step);
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
    examples_step.dependOn(&causal_human_agent_feedback_loop_tool.step);
    examples_step.dependOn(&run_causal_human_agent_feedback_loop_tool_tests.step);
    examples_step.dependOn(&causal_rollout_automation_guardrails_tool.step);
    examples_step.dependOn(&run_causal_rollout_automation_guardrails_tool_tests.step);
    examples_step.dependOn(&causal_production_telemetry_capture_design_tool.step);
    examples_step.dependOn(&run_causal_production_telemetry_capture_design_tool_tests.step);
    examples_step.dependOn(&causal_production_telemetry_capture_fixtures_tool.step);
    examples_step.dependOn(&run_causal_production_telemetry_capture_fixtures_tool_tests.step);
    examples_step.dependOn(&causal_production_telemetry_readiness_review_tool.step);
    examples_step.dependOn(&run_causal_production_telemetry_readiness_review_tool_tests.step);
    examples_step.dependOn(&causal_production_telemetry_implementation_proposal_tool.step);
    examples_step.dependOn(&run_causal_production_telemetry_implementation_proposal_tool_tests.step);
    examples_step.dependOn(&causal_production_telemetry_exporter_boundary_tool.step);
    examples_step.dependOn(&run_causal_production_telemetry_exporter_boundary_tool_tests.step);
    examples_step.dependOn(&causal_production_telemetry_local_pipeline_fixtures_tool.step);
    examples_step.dependOn(&run_causal_production_telemetry_local_pipeline_fixtures_tool_tests.step);
    examples_step.dependOn(&causal_production_telemetry_nendb_retention_fixtures_tool.step);
    examples_step.dependOn(&run_causal_production_telemetry_nendb_retention_fixtures_tool_tests.step);
    examples_step.dependOn(&causal_production_telemetry_workbench_readonly_preview_tool.step);
    examples_step.dependOn(&run_causal_production_telemetry_workbench_readonly_preview_tool_tests.step);
    examples_step.dependOn(&causal_production_telemetry_ci_artifact_preview_tool.step);
    examples_step.dependOn(&run_causal_production_telemetry_ci_artifact_preview_tool_tests.step);
    examples_step.dependOn(&causal_production_telemetry_ci_harness_boundary_tool.step);
    examples_step.dependOn(&run_causal_production_telemetry_ci_harness_boundary_tool_tests.step);

    const release_gate_step = b.step("release-gate", "Run complete durable workflow and cluster release gate");
    release_gate_step.dependOn(test_step);
    release_gate_step.dependOn(public_api_review_step);
    release_gate_step.dependOn(storage_conformance_step);
    release_gate_step.dependOn(property_crash_step);
    release_gate_step.dependOn(performance_bounds_step);
    release_gate_step.dependOn(examples_step);
    release_gate_step.dependOn(causal_test_step);
    release_gate_step.dependOn(causal_artifacts_step);
    release_gate_step.dependOn(release_gate_report_step);
    release_gate_step.dependOn(&run_release_gate_report_tool_tests.step);
    release_gate_step.dependOn(&run_workflow_crash_recovery_example_tests.step);
    release_gate_step.dependOn(&run_multi_runner_cluster_example_tests.step);
    release_gate_step.dependOn(&run_cluster_workflow_migration_example_tests.step);
}
