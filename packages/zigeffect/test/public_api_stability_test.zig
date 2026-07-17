const std = @import("std");
const fx = @import("zigeffect");

test "root facade keeps stable public namespaces" {
    const namespaces = [_][]const u8{
        "core",
        "dependency",
        "effect",
        "runtime",
        "layer",
        "services",
        "testing",
        "traits",
        "data",
        "match",
        "pattern",
        "statechart",
        "workflow",
        "cluster",
        "storage",
        "performance",
    };

    inline for (namespaces) |name| {
        try std.testing.expect(@hasDecl(fx, name));
    }

    try std.testing.expectEqualStrings("workflow", fx.workflow.domain);
    try std.testing.expectEqualStrings("statechart", fx.statechart.domain);
    try std.testing.expectEqualStrings("cluster", fx.cluster.domain);
    try std.testing.expectEqualStrings("performance", fx.performance.domain);
    try std.testing.expect(@hasDecl(fx, "Lineage"));
    try std.testing.expect(@hasDecl(fx.Lineage, "Key"));
    try std.testing.expect(@hasDecl(fx.Lineage, "Set"));
}

test "statechart namespace keeps typed definition exports" {
    const exports = [_][]const u8{
        "Definition",
        "Machine",
        "ConfigurationMachine",
        "Macrostep",
        "ConfigurationMacrostep",
        "Analyzer",
        "Artifacts",
        "Actor",
        "ConfigurationActor",
        "ActorSystem",
        "ConfigurationActorSystem",
        "mapDecisionToCausal",
        "recordDecisionCausal",
        "StateKind",
        "TransitionKind",
        "SnapshotStatus",
        "DecisionOutcome",
        "ActionPhase",
        "StepError",
        "MacrostepError",
        "AnalysisFindingKind",
        "statechart_definition_schema",
        "statechart_snapshot_schema",
        "statechart_execution_schema",
        "statechart_coverage_schema",
        "actor_tree_checkpoint_schema",
        "actor_tree_checkpoint_schema_version",
        "ActorStatus",
        "MailboxOverflowPolicy",
        "ValidationFindingKind",
        "DefinitionBounds",
        "SourceRef",
        "VersionCompatibility",
        "DeploymentStrategy",
        "VersionRisk",
        "VersionSubject",
        "VersionChangeKind",
        "VersionDiff",
        "Simulation",
        "ConfigurationSimulation",
        "ControlOperation",
        "ControlDecision",
        "ControlStatus",
        "InstanceStatus",
        "InstanceHealth",
        "ControlPlane",
        "FleetRegistry",
        "MigrationRegistry",
        "MutationCatalog",
    };

    inline for (exports) |name| {
        try std.testing.expect(@hasDecl(fx.statechart, name));
    }
}

test "workflow namespace keeps durable public exports" {
    const exports = [_][]const u8{
        "Workflow",
        "WorkflowMetadata",
        "Activity",
        "ActivityMetadata",
        "WorkflowEvent",
        "WorkflowEventKind",
        "WorkflowEventMigrationRegistry",
        "WorkflowReplayState",
        "JournalStore",
        "CausalJournalStore",
        "JournalAppend",
        "JournalEventBatch",
        "InMemoryJournalStore",
        "FileJournalStore",
        "WorkflowSnapshotFrequency",
        "WorkflowEngine",
        "WorkflowExecution",
        "WorkflowResult",
        "WorkflowBackendRequirement",
        "WorkflowContext",
        "WorkflowContextOptions",
        "DurableClock",
        "TimerSleepResult",
        "DurableDeferred",
        "DeferredAwaitResult",
        "DurableSignal",
        "SignalWaitResult",
        "DurableQueue",
        "QueueAwaitResult",
        "WorkflowScheduler",
        "WorkflowSchedulerTickResult",
        "WorkflowLifecycle",
        "WorkflowInspectionReport",
        "DurableStatechart",
        "DurableConfigurationStatechart",
        "statechart_record_schema",
        "statechart_record_schema_version",
        "mapWorkflowEventsToCausal",
        "cloneWorkflowEvent",
        "deinitWorkflowEventStrings",
    };

    inline for (exports) |name| {
        try std.testing.expect(@hasDecl(fx.workflow, name));
    }

    try std.testing.expect(fx.workflow.WorkflowMetadata == fx.workflow.definition.WorkflowMetadata);
    try std.testing.expect(fx.workflow.ActivityMetadata == fx.workflow.activity.ActivityMetadata);
    try std.testing.expect(fx.workflow.WorkflowEvent == fx.workflow.journal.WorkflowEvent);
    try std.testing.expect(fx.workflow.WorkflowReplayState == fx.workflow.replay.WorkflowReplayState);
    try std.testing.expect(fx.workflow.JournalStore == fx.workflow.store.JournalStore);
    try std.testing.expect(fx.workflow.CausalJournalStore == fx.workflow.store.CausalJournalStore);
    try std.testing.expect(fx.workflow.WorkflowEngine == fx.workflow.engine.WorkflowEngine);
    try std.testing.expect(fx.workflow.WorkflowContext == fx.workflow.context.WorkflowContext);
    try std.testing.expect(fx.workflow.DurableClock == fx.workflow.clock.DurableClock);
    try std.testing.expect(fx.workflow.DurableDeferred == fx.workflow.deferred.DurableDeferred);
    try std.testing.expect(fx.workflow.DurableSignal == fx.workflow.signal.DurableSignal);
    try std.testing.expect(fx.workflow.DurableQueue == fx.workflow.queue.DurableQueue);
    try std.testing.expect(fx.workflow.WorkflowScheduler == fx.workflow.scheduler.WorkflowScheduler);
    try std.testing.expect(fx.workflow.WorkflowLifecycle == fx.workflow.lifecycle.WorkflowLifecycle);
}

test "cluster namespace keeps actor runner storage and transport exports" {
    const exports = [_][]const u8{
        "EntityType",
        "EntityId",
        "EntityAddress",
        "EntityMessageId",
        "EntityEnvelope",
        "EntityAsk",
        "LocalMailboxStore",
        "LocalEntityRuntime",
        "EntityHandlerResult",
        "MessageEnvelope",
        "MessageStorage",
        "InMemoryMessageStorage",
        "FileMessageStorage",
        "RunnerRegistration",
        "RunnerHeartbeat",
        "LocalRunnerRegistry",
        "LocalRunnerHealthInspector",
        "RunnerStorage",
        "InMemoryRunnerStorage",
        "FileRunnerStorage",
        "ShardLease",
        "LocalShardLeaseManager",
        "ShardLeaseFence",
        "ClusterSupervisionPolicy",
        "ClusterSupervisionReport",
        "ClusterRuntime",
        "ClusterEntityRef",
        "ClusterTransport",
        "ClusterTransportAuthMode",
        "ClusterTransportAuth",
        "ClusterTransportLimits",
        "ClusterTransportLifecycleState",
        "ClusterTransportMetricsSnapshot",
        "ClusterTransportFailureReport",
        "InProcessClusterTransport",
        "LoopbackHttpClusterTransport",
        "EncodedInProcessHttpClusterTransport",
        "EncodedInProcessSocketClusterTransport",
        "ProductionHttpClusterTransport",
        "ProductionSocketClusterTransport",
        "chunkedClusterTransportRequest",
        "RealClusterController",
        "RealClusterControllerOptions",
        "ClusterMembershipState",
        "ClusterAdmissionDecision",
        "ClusterPlacementPlan",
        "ClusterRebalancePlan",
        "ClusterInspectionReport",
        "ClusterWorkflowEngine",
        "ClusterWorkflowEntityRegistry",
        "ClusterTimerWakeupIndex",
        "ClusterQueueIndex",
        "LocalClusterRouter",
        "LocalClusterRunner",
        "cloneEntityAddress",
        "deinitEntityAddress",
        "cloneEntityEnvelope",
        "deinitEntityEnvelope",
        "cloneMessageEnvelope",
        "deinitMessageEnvelope",
    };

    inline for (exports) |name| {
        try std.testing.expect(@hasDecl(fx.cluster, name));
    }

    try std.testing.expect(fx.cluster.EntityAddress == fx.cluster.identity.EntityAddress);
    try std.testing.expect(fx.cluster.LocalMailboxStore == fx.cluster.mailbox.LocalMailboxStore);
    try std.testing.expect(fx.cluster.LocalEntityRuntime == fx.cluster.entity.LocalEntityRuntime);
    try std.testing.expect(fx.cluster.MessageStorage == fx.cluster.message_storage.MessageStorage);
    try std.testing.expect(fx.cluster.RunnerStorage == fx.cluster.runner_storage.RunnerStorage);
    try std.testing.expect(fx.cluster.LocalShardLeaseManager == fx.cluster.shard_lease.LocalShardLeaseManager);
    try std.testing.expect(fx.cluster.ClusterRuntime == fx.cluster.runtime.ClusterRuntime);
    try std.testing.expect(fx.cluster.ClusterTransport == fx.cluster.transport.ClusterTransport);
    try std.testing.expect(fx.cluster.EncodedInProcessHttpClusterTransport == fx.cluster.transport.EncodedInProcessHttpClusterTransport);
    try std.testing.expect(fx.cluster.EncodedInProcessSocketClusterTransport == fx.cluster.transport.EncodedInProcessSocketClusterTransport);
    try std.testing.expect(fx.cluster.ProductionHttpClusterTransport == fx.cluster.transport.ProductionHttpClusterTransport);
    try std.testing.expect(fx.cluster.ProductionSocketClusterTransport == fx.cluster.transport.ProductionSocketClusterTransport);
    try std.testing.expect(fx.cluster.RealClusterController == fx.cluster.real_cluster.RealClusterController);
    try std.testing.expect(fx.cluster.ClusterWorkflowEngine == fx.cluster.workflow_engine.ClusterWorkflowEngine);
    try std.testing.expect(fx.cluster.ClusterTimerWakeupIndex == fx.cluster.timer_wakeup.ClusterTimerWakeupIndex);
    try std.testing.expect(fx.cluster.ClusterQueueIndex == fx.cluster.queue.ClusterQueueIndex);
    try std.testing.expect(fx.cluster.LocalClusterRunner == fx.cluster.local_cluster.LocalClusterRunner);
}

test "top level compatibility aliases point at namespace exports" {
    try std.testing.expect(fx.Effect(u8, error{}, fx.TestServices) == fx.effect.Effect(u8, error{}, fx.TestServices));
    try std.testing.expect(fx.Context(fx.TestServices) == fx.core.Context(fx.TestServices));
    try std.testing.expect(fx.Scope == fx.core.Scope);
    try std.testing.expect(fx.Runtime(fx.TestServices) == fx.runtime.Runtime(fx.TestServices));
    try std.testing.expect(fx.Layer(fx.TestServices) == fx.layer.Layer(fx.TestServices));
    try std.testing.expect(fx.Logger == fx.services.Logger);
    try std.testing.expect(fx.TestEnv == fx.testing.TestEnv);
    try std.testing.expect(fx.ClusterRuntime == fx.cluster.ClusterRuntime);
    try std.testing.expect(fx.MessageStorage == fx.cluster.MessageStorage);
    try std.testing.expect(fx.RunnerStorage == fx.cluster.RunnerStorage);
    try std.testing.expect(fx.ClusterTransport == fx.cluster.ClusterTransport);
    try std.testing.expect(fx.EncodedInProcessHttpClusterTransport == fx.cluster.EncodedInProcessHttpClusterTransport);
    try std.testing.expect(fx.EncodedInProcessSocketClusterTransport == fx.cluster.EncodedInProcessSocketClusterTransport);
    try std.testing.expect(fx.ProductionHttpClusterTransport == fx.cluster.ProductionHttpClusterTransport);
    try std.testing.expect(fx.ProductionSocketClusterTransport == fx.cluster.ProductionSocketClusterTransport);
    try std.testing.expect(fx.RealClusterController == fx.cluster.RealClusterController);
    try std.testing.expect(fx.ClusterWorkflowEngine == fx.cluster.ClusterWorkflowEngine);
    try std.testing.expect(fx.PerformanceBenchmarkReport == fx.performance.PerformanceBenchmarkReport);
}

test "agent safety kernel keeps stable public exports" {
    const exports = [_][]const u8{
        "SourceMap",
        "SourceRef",
        "SourceRefInput",
        "resolveEventSource",
        "ResourceHandle",
        "ResourceTable",
        "isAgentSendable",
        "assertAgentSendable",
        "TrackedAllocator",
        "MemorySafetySnapshot",
        "ScheduleExplorerOptions",
        "ScheduleExplorationReport",
        "exploreSchedules",
        "replaySchedule",
    };
    inline for (exports) |name| try std.testing.expect(@hasDecl(fx, name));
    try std.testing.expectEqualStrings("zigeffect.source-map.v1", fx.source_map_schema);
    try std.testing.expectEqualStrings("zigeffect.schedule-exploration.v1", fx.schedule_exploration_schema);
}

test "public durable schema constants stay at version one" {
    try std.testing.expectEqualStrings("zigeffect.workflow.journal-event.v1", fx.workflow.workflow_journal_event_schema);
    try std.testing.expectEqual(@as(u32, 1), fx.workflow.workflow_journal_event_schema_version);
    try std.testing.expectEqualStrings("zigeffect.workflow.checkpoint.v1", fx.workflow.workflow_checkpoint_schema);
    try std.testing.expectEqual(@as(u32, 1), fx.workflow.workflow_checkpoint_schema_version);
    try std.testing.expectEqualStrings("zigeffect.workflow.snapshot-commit.v1", fx.workflow.workflow_snapshot_commit_schema);
    try std.testing.expectEqual(@as(u32, 1), fx.workflow.workflow_snapshot_commit_schema_version);
    try std.testing.expectEqualStrings("zigeffect.workflow.inspect.v1", fx.workflow.workflow_inspect_schema);
    try std.testing.expectEqualStrings("zigeffect.workflow.replay.v1", fx.workflow.workflow_replay_schema);
    try std.testing.expectEqualStrings("zigeffect.workflow.list.v1", fx.workflow.workflow_list_schema);
    try std.testing.expectEqual(@as(u32, 1), fx.workflow.workflow_report_schema_version);

    try std.testing.expectEqualStrings("zigeffect.cluster.runner-lease.v1", fx.cluster.runner_lease_schema);
    try std.testing.expectEqual(@as(u32, 1), fx.cluster.runner_lease_schema_version);
    try std.testing.expectEqualStrings("zigeffect.cluster.message-record.v1", fx.cluster.message_record_schema);
    try std.testing.expectEqual(@as(u32, 1), fx.cluster.message_record_schema_version);
    try std.testing.expectEqualStrings("zigeffect.cluster.message-reply.v1", fx.cluster.message_reply_schema);
    try std.testing.expectEqual(@as(u32, 1), fx.cluster.message_reply_schema_version);
    try std.testing.expectEqualStrings("zigeffect.cluster.transport.request.v1", fx.cluster.transport_request_schema);
    try std.testing.expectEqual(@as(u32, 1), fx.cluster.transport_request_schema_version);
    try std.testing.expectEqualStrings("zigeffect.cluster.transport.response.v1", fx.cluster.transport_response_schema);
    try std.testing.expectEqual(@as(u32, 1), fx.cluster.transport_response_schema_version);
    try std.testing.expectEqualStrings("zigeffect.cluster.workflow-command.v1", fx.cluster.cluster_workflow_command_schema);
    try std.testing.expectEqual(@as(u32, 1), fx.cluster.cluster_workflow_command_schema_version);
    try std.testing.expectEqualStrings("zigeffect.cluster.workflow-command-result.v1", fx.cluster.cluster_workflow_command_result_schema);
    try std.testing.expectEqual(@as(u32, 1), fx.cluster.cluster_workflow_command_result_schema_version);

    try std.testing.expectEqualStrings("zigeffect.storage.catalog.v1", fx.storage.storage_catalog_schema);
    try std.testing.expectEqual(@as(u32, 1), fx.storage.storage_catalog_schema_version);
    try std.testing.expectEqualStrings("zigeffect.storage.sql-plan.v1", fx.storage.storage_sql_plan_schema);
    try std.testing.expectEqual(@as(u32, 1), fx.storage.storage_sql_plan_schema_version);

    try std.testing.expectEqualStrings("zigeffect.performance.benchmark.v1", fx.performance.performance_benchmark_schema);
    try std.testing.expectEqual(@as(u32, 1), fx.performance.performance_benchmark_schema_version);
}

test "public error sets keep documented members" {
    const journal_sequence_conflict: fx.workflow.JournalStoreError = error.SequenceConflict;
    const journal_duplicate_event: fx.workflow.JournalStoreError = error.DuplicateEvent;
    const journal_newer_runtime: fx.workflow.FileJournalStoreError = error.JournalRequiresNewerRuntime;
    const workflow_missing: fx.workflow.WorkflowEngineError = error.WorkflowNotRegistered;
    const workflow_backend: fx.workflow.WorkflowEngineError = error.UnsupportedBackendCapability;
    const context_signal_missing: fx.workflow.WorkflowContextError = error.SignalReceivedMissing;
    const replay_duplicate_queue: fx.workflow.ReplayError = error.DuplicateQueue;

    const mailbox_full: fx.cluster.EntityMailboxError = error.MailboxFull;
    const duplicate_entity: fx.cluster.EntityRuntimeError = error.DuplicateEntity;
    const duplicate_message: fx.cluster.MessageStorageError = error.DuplicateMessage;
    const missing_message: fx.cluster.MessageStorageError = error.MessageNotFound;
    const lease_conflict: fx.cluster.RunnerStorageError = error.LeaseConflict;
    const stale_fence: fx.cluster.ClusterRuntimeError = error.StaleShardFence;
    const shard_not_owned: fx.cluster.ClusterRuntimeError = error.ShardNotOwned;
    const transport_unavailable: fx.cluster.ClusterTransportError = error.TransportUnavailable;
    const transport_unauthorized: fx.cluster.ClusterTransportError = error.TransportUnauthorized;
    const transport_payload_too_large: fx.cluster.ClusterTransportError = error.TransportPayloadTooLarge;
    const transport_backpressured: fx.cluster.ClusterTransportError = error.TransportBackpressured;
    const invalid_transport_limits: fx.cluster.ClusterTransportError = error.InvalidTransportLimits;
    const no_active_cluster_members: fx.cluster.RealClusterError = error.NoActiveClusterMembers;
    const local_invalid_runner: fx.cluster.LocalClusterError = error.InvalidRunnerIndex;

    const backend_missing: fx.BackendCapabilityError = error.UnsupportedBackendCapability;

    try std.testing.expect(journal_sequence_conflict == error.SequenceConflict);
    try std.testing.expect(journal_duplicate_event == error.DuplicateEvent);
    try std.testing.expect(journal_newer_runtime == error.JournalRequiresNewerRuntime);
    try std.testing.expect(workflow_missing == error.WorkflowNotRegistered);
    try std.testing.expect(workflow_backend == error.UnsupportedBackendCapability);
    try std.testing.expect(context_signal_missing == error.SignalReceivedMissing);
    try std.testing.expect(replay_duplicate_queue == error.DuplicateQueue);
    try std.testing.expect(mailbox_full == error.MailboxFull);
    try std.testing.expect(duplicate_entity == error.DuplicateEntity);
    try std.testing.expect(duplicate_message == error.DuplicateMessage);
    try std.testing.expect(missing_message == error.MessageNotFound);
    try std.testing.expect(lease_conflict == error.LeaseConflict);
    try std.testing.expect(stale_fence == error.StaleShardFence);
    try std.testing.expect(shard_not_owned == error.ShardNotOwned);
    try std.testing.expect(transport_unavailable == error.TransportUnavailable);
    try std.testing.expect(transport_unauthorized == error.TransportUnauthorized);
    try std.testing.expect(transport_payload_too_large == error.TransportPayloadTooLarge);
    try std.testing.expect(transport_backpressured == error.TransportBackpressured);
    try std.testing.expect(invalid_transport_limits == error.InvalidTransportLimits);
    try std.testing.expect(no_active_cluster_members == error.NoActiveClusterMembers);
    try std.testing.expect(local_invalid_runner == error.InvalidRunnerIndex);
    try std.testing.expect(backend_missing == error.UnsupportedBackendCapability);
}
