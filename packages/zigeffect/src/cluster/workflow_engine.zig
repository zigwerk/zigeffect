const std = @import("std");
const entity = @import("entity.zig");
const envelope = @import("envelope.zig");
const identity = @import("identity.zig");
const local_cluster = @import("local_cluster.zig");
const routing = @import("routing.zig");
const transport = @import("transport.zig");
const workflow_clock = @import("../workflow/clock.zig");
const workflow_deferred = @import("../workflow/deferred.zig");
const workflow_engine = @import("../workflow/engine.zig");
const journal = @import("../workflow/journal.zig");
const lifecycle = @import("../workflow/lifecycle.zig");
const workflow_queue = @import("../workflow/queue.zig");
const replay = @import("../workflow/replay.zig");
const store = @import("../workflow/store.zig");

pub const Allocator = std.mem.Allocator;
pub const ClusterTransport = transport.ClusterTransport;
pub const EntityAddress = identity.EntityAddress;
pub const EntityEnvelope = entity.EntityEnvelope;
pub const EntityHandlerResult = entity.EntityHandlerResult;
pub const EntityScope = entity.EntityScope;
pub const JournalStore = store.JournalStore;
pub const LocalClusterRunner = local_cluster.LocalClusterRunner;
pub const MessageCorrelationId = envelope.MessageCorrelationId;
pub const MessageEnvelope = envelope.MessageEnvelope;
pub const WorkflowId = journal.WorkflowId;
pub const ExecutionId = journal.ExecutionId;
pub const ActivityId = journal.ActivityId;
pub const TimerId = journal.TimerId;
pub const DeferredId = journal.DeferredId;
pub const QueueId = journal.QueueId;
pub const CompensationId = journal.CompensationId;
pub const JournalSequence = journal.JournalSequence;
pub const WorkflowEventKind = journal.WorkflowEventKind;

pub const cluster_workflow_entity_type = "workflow.execution";
pub const cluster_workflow_command_payload_type = "application/vnd.zigeffect.cluster.workflow-command+json";
pub const cluster_workflow_entity_service_key = "cluster.workflow.entity.services";
pub const cluster_workflow_command_schema = "zigeffect.cluster.workflow-command.v1";
pub const cluster_workflow_command_schema_version: u32 = 1;
pub const cluster_workflow_command_result_schema = "zigeffect.cluster.workflow-command-result.v1";
pub const cluster_workflow_command_result_schema_version: u32 = 1;

pub const ClusterWorkflowCommandError = error{
    CorruptClusterWorkflowCommand,
    IncompatibleClusterWorkflowCommandSchema,
    UnsupportedClusterWorkflowCommand,
    WorkflowExecutionMismatch,
    MissingWorkflowEntityServices,
    MissingWorkflowCommandReply,
};

pub const ClusterWorkflowCommandKind = enum {
    start,
    append_event,
    complete,
    @"suspend",
    @"resume",
    interrupt,
    cancel,
    fire_due_timers,
    complete_deferred,
    fail_deferred,
    cancel_deferred,
    send_signal,
    complete_queue,
    fail_queue,
};

pub const ClusterWorkflowCommand = struct {
    kind: ClusterWorkflowCommandKind,
    event_kind: ?WorkflowEventKind = null,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    workflow_name: []const u8 = "",
    name: []const u8 = "",
    status: []const u8 = "",
    redacted_detail: []const u8 = "",
    idempotency_key: []const u8 = "",
    now_ms: u64 = 0,
    activity_id: ?ActivityId = null,
    timer_id: ?TimerId = null,
    deferred_id: ?DeferredId = null,
    queue_id: ?QueueId = null,
    compensation_id: ?CompensationId = null,
    expected_next_sequence: ?JournalSequence = null,

    pub fn deinit(self: *ClusterWorkflowCommand, allocator: Allocator) void {
        if (self.workflow_name.len > 0) allocator.free(self.workflow_name);
        if (self.name.len > 0) allocator.free(self.name);
        if (self.status.len > 0) allocator.free(self.status);
        if (self.redacted_detail.len > 0) allocator.free(self.redacted_detail);
        if (self.idempotency_key.len > 0) allocator.free(self.idempotency_key);
    }
};

pub const ClusterWorkflowCommandResult = struct {
    kind: ClusterWorkflowCommandKind,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    appended: bool = false,
    sequence: ?JournalSequence = null,
    last_sequence: JournalSequence = 0,
    status: []const u8 = "",
    timers_fired: usize = 0,

    pub fn deinit(self: *ClusterWorkflowCommandResult, allocator: Allocator) void {
        if (self.status.len > 0) allocator.free(self.status);
    }
};

pub const ClusterWorkflowCommandSubmission = struct {
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    correlation_id: MessageCorrelationId,
    response: transport.ClusterTransportResponse,

    pub fn deinit(self: *ClusterWorkflowCommandSubmission, allocator: Allocator) void {
        self.response.deinit(allocator);
    }
};

pub const ClusterWorkflowEngine = struct {
    allocator: Allocator,
    transport: ClusterTransport,
    next_command_sequence: u64 = 1,

    pub fn init(allocator: Allocator, cluster_transport: ClusterTransport) ClusterWorkflowEngine {
        return .{
            .allocator = allocator,
            .transport = cluster_transport,
        };
    }

    pub fn deinit(self: *ClusterWorkflowEngine) void {
        _ = self;
    }

    pub fn start(self: *ClusterWorkflowEngine, workflow_name: []const u8, idempotency_key: []const u8) !ClusterWorkflowCommandSubmission {
        const workflow_id = workflow_engine.workflowId(workflow_name);
        const execution_id = workflow_engine.executionId(workflow_name, idempotency_key);
        return self.submit(.{
            .kind = .start,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
            .workflow_name = workflow_name,
            .name = workflow_name,
            .status = "running",
            .idempotency_key = idempotency_key,
        });
    }

    pub fn appendEvent(self: *ClusterWorkflowEngine, command: ClusterWorkflowCommand) !ClusterWorkflowCommandSubmission {
        return self.submit(command);
    }

    pub fn complete(self: *ClusterWorkflowEngine, workflow_id: WorkflowId, execution_id: ExecutionId, detail: []const u8) !ClusterWorkflowCommandSubmission {
        return self.submitWithGeneratedKey(.complete, workflow_id, execution_id, "completed", detail);
    }

    pub fn suspendWorkflow(self: *ClusterWorkflowEngine, workflow_id: WorkflowId, execution_id: ExecutionId, reason: []const u8) !ClusterWorkflowCommandSubmission {
        return self.submitWithGeneratedKey(.@"suspend", workflow_id, execution_id, "waiting", reason);
    }

    pub fn resumeWorkflow(self: *ClusterWorkflowEngine, workflow_id: WorkflowId, execution_id: ExecutionId, reason: []const u8) !ClusterWorkflowCommandSubmission {
        return self.submitWithGeneratedKey(.@"resume", workflow_id, execution_id, "running", reason);
    }

    pub fn interrupt(self: *ClusterWorkflowEngine, workflow_id: WorkflowId, execution_id: ExecutionId, reason: []const u8) !ClusterWorkflowCommandSubmission {
        return self.submitWithGeneratedKey(.interrupt, workflow_id, execution_id, "interrupted", reason);
    }

    pub fn cancel(self: *ClusterWorkflowEngine, workflow_id: WorkflowId, execution_id: ExecutionId, reason: []const u8) !ClusterWorkflowCommandSubmission {
        return self.submitWithGeneratedKey(.cancel, workflow_id, execution_id, "cancelled", reason);
    }

    pub fn fireDueTimers(self: *ClusterWorkflowEngine, workflow_id: WorkflowId, execution_id: ExecutionId, now_ms: u64) !ClusterWorkflowCommandSubmission {
        return self.submitWithGeneratedKeyAndIds(.{
            .kind = .fire_due_timers,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
            .status = "running",
            .now_ms = now_ms,
        });
    }

    pub fn completeDeferred(self: *ClusterWorkflowEngine, workflow_id: WorkflowId, execution_id: ExecutionId, label: []const u8, detail: []const u8) !ClusterWorkflowCommandSubmission {
        return self.submitWithGeneratedKeyAndIds(.{
            .kind = .complete_deferred,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
            .name = label,
            .status = "completed",
            .redacted_detail = detail,
            .deferred_id = workflow_deferred.deferredId(label),
        });
    }

    pub fn failDeferred(self: *ClusterWorkflowEngine, workflow_id: WorkflowId, execution_id: ExecutionId, label: []const u8, detail: []const u8) !ClusterWorkflowCommandSubmission {
        return self.submitWithGeneratedKeyAndIds(.{
            .kind = .fail_deferred,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
            .name = label,
            .status = "failed",
            .redacted_detail = detail,
            .deferred_id = workflow_deferred.deferredId(label),
        });
    }

    pub fn cancelDeferred(self: *ClusterWorkflowEngine, workflow_id: WorkflowId, execution_id: ExecutionId, label: []const u8, reason: []const u8) !ClusterWorkflowCommandSubmission {
        return self.submitWithGeneratedKeyAndIds(.{
            .kind = .cancel_deferred,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
            .name = label,
            .status = "cancelled",
            .redacted_detail = reason,
            .deferred_id = workflow_deferred.deferredId(label),
        });
    }

    pub fn sendSignal(
        self: *ClusterWorkflowEngine,
        workflow_id: WorkflowId,
        execution_id: ExecutionId,
        signal_name: []const u8,
        encoded_payload: []const u8,
        external_idempotency_key: []const u8,
    ) !ClusterWorkflowCommandSubmission {
        return self.submit(.{
            .kind = .send_signal,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
            .name = signal_name,
            .status = "received",
            .redacted_detail = encoded_payload,
            .idempotency_key = external_idempotency_key,
        });
    }

    pub fn completeQueue(
        self: *ClusterWorkflowEngine,
        workflow_id: WorkflowId,
        execution_id: ExecutionId,
        queue_name: []const u8,
        queue_id: QueueId,
        detail: []const u8,
    ) !ClusterWorkflowCommandSubmission {
        return self.submitWithGeneratedKeyAndIds(.{
            .kind = .complete_queue,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
            .name = queue_name,
            .status = "completed",
            .redacted_detail = detail,
            .queue_id = queue_id,
        });
    }

    pub fn failQueue(
        self: *ClusterWorkflowEngine,
        workflow_id: WorkflowId,
        execution_id: ExecutionId,
        queue_name: []const u8,
        queue_id: QueueId,
        detail: []const u8,
    ) !ClusterWorkflowCommandSubmission {
        return self.submitWithGeneratedKeyAndIds(.{
            .kind = .fail_queue,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
            .name = queue_name,
            .status = "failed",
            .redacted_detail = detail,
            .queue_id = queue_id,
        });
    }

    fn submitWithGeneratedKey(
        self: *ClusterWorkflowEngine,
        kind: ClusterWorkflowCommandKind,
        workflow_id: WorkflowId,
        execution_id: ExecutionId,
        status: []const u8,
        detail: []const u8,
    ) !ClusterWorkflowCommandSubmission {
        const key = try std.fmt.allocPrint(
            self.allocator,
            "cluster-workflow:{s}:{d}:{d}",
            .{ @tagName(kind), execution_id, self.next_command_sequence },
        );
        defer self.allocator.free(key);
        self.next_command_sequence += 1;
        return self.submit(.{
            .kind = kind,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
            .status = status,
            .redacted_detail = detail,
            .idempotency_key = key,
        });
    }

    fn submitWithGeneratedKeyAndIds(self: *ClusterWorkflowEngine, command: ClusterWorkflowCommand) !ClusterWorkflowCommandSubmission {
        const key = try std.fmt.allocPrint(
            self.allocator,
            "cluster-workflow:{s}:{d}:{d}",
            .{ @tagName(command.kind), command.execution_id, self.next_command_sequence },
        );
        defer self.allocator.free(key);
        self.next_command_sequence += 1;
        var command_with_key = command;
        command_with_key.idempotency_key = key;
        return self.submit(command_with_key);
    }

    fn submit(self: *ClusterWorkflowEngine, command: ClusterWorkflowCommand) !ClusterWorkflowCommandSubmission {
        const payload = try formatClusterWorkflowCommandJson(self.allocator, command);
        defer self.allocator.free(payload);

        var response = try self.transport.send(self.allocator, .{
            .kind = .request,
            .address = clusterWorkflowExecutionAddress(command.execution_id),
            .payload_type_name = cluster_workflow_command_payload_type,
            .payload = payload,
            .redacted_detail = @tagName(command.kind),
            .idempotency_key = command.idempotency_key,
        });
        errdefer response.deinit(self.allocator);

        const correlation_id = response.correlation_id orelse return error.MissingWorkflowCommandReply;
        return .{
            .workflow_id = command.workflow_id,
            .execution_id = command.execution_id,
            .correlation_id = correlation_id,
            .response = response,
        };
    }
};

pub const ClusterWorkflowEntityServices = struct {
    allocator: Allocator,
    journal_store: JournalStore,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    last_reply_json: []const u8 = "",

    pub fn deinit(self: *ClusterWorkflowEntityServices) void {
        if (self.last_reply_json.len > 0) self.allocator.free(self.last_reply_json);
    }
};

pub const ClusterWorkflowEntityRegistrationResult = struct {
    address: EntityAddress,
    registered: bool = false,
};

pub const ClusterWorkflowRecoveryReport = struct {
    scanned: usize = 0,
    registered: usize = 0,
    skipped: usize = 0,
};

const RecoveredWorkflowExecution = struct {
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
};

pub const ClusterWorkflowEntityRegistry = struct {
    allocator: Allocator,
    services: std.ArrayList(*ClusterWorkflowEntityServices) = .empty,

    pub fn init(allocator: Allocator) ClusterWorkflowEntityRegistry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *ClusterWorkflowEntityRegistry) void {
        for (self.services.items) |services| {
            services.deinit();
            self.allocator.destroy(services);
        }
        self.services.deinit(self.allocator);
    }

    pub fn registerExecution(
        self: *ClusterWorkflowEntityRegistry,
        runner: *LocalClusterRunner,
        journal_store: JournalStore,
        workflow_id: WorkflowId,
        execution_id: ExecutionId,
        now_ms: u64,
    ) !ClusterWorkflowEntityRegistrationResult {
        const address = clusterWorkflowExecutionAddress(execution_id);
        const shard_id = try routing.shardIdForAddress(address, runner.shard_count);
        if (!runner.runtime.ownsShard(shard_id)) return error.ShardNotOwned;

        if (runner.entityScope(address)) |_| {
            return .{ .address = address, .registered = false };
        } else |err| switch (err) {
            error.EntityNotFound => {},
            else => return err,
        }

        _ = try runner.registerEntity(.{ .address = address, .name = cluster_workflow_entity_type }, now_ms);
        const services = try self.allocator.create(ClusterWorkflowEntityServices);
        errdefer self.allocator.destroy(services);
        services.* = .{
            .allocator = self.allocator,
            .journal_store = journal_store,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
        };
        errdefer services.* = undefined;

        const scope = try runner.entityScope(address);
        try scope.provideService(cluster_workflow_entity_service_key, services);
        try self.services.append(self.allocator, services);

        return .{ .address = address, .registered = true };
    }

    pub fn recoverOwnedExecutions(
        self: *ClusterWorkflowEntityRegistry,
        runner: *LocalClusterRunner,
        journal_store: JournalStore,
        now_ms: u64,
    ) !ClusterWorkflowRecoveryReport {
        var events = try journal_store.readAll(self.allocator);
        defer events.deinit();

        var executions = std.ArrayList(RecoveredWorkflowExecution).empty;
        defer executions.deinit(self.allocator);

        for (events.events) |event| {
            if (findRecoveredExecution(executions.items, event.execution_id) != null) continue;
            try executions.append(self.allocator, .{
                .workflow_id = event.workflow_id,
                .execution_id = event.execution_id,
            });
        }

        var report = ClusterWorkflowRecoveryReport{ .scanned = executions.items.len };
        for (executions.items) |execution| {
            const address = clusterWorkflowExecutionAddress(execution.execution_id);
            const shard_id = try routing.shardIdForAddress(address, runner.shard_count);
            if (!runner.runtime.ownsShard(shard_id)) {
                report.skipped += 1;
                continue;
            }
            const registered = try self.registerExecution(
                runner,
                journal_store,
                execution.workflow_id,
                execution.execution_id,
                now_ms,
            );
            if (registered.registered) {
                report.registered += 1;
            } else {
                report.skipped += 1;
            }
        }
        return report;
    }
};
pub const ClusterWorkflowEntityHandler = struct {
    pub fn handle(scope: *EntityScope, entity_envelope: EntityEnvelope) !EntityHandlerResult {
        const raw = (try scope.service(cluster_workflow_entity_service_key)) orelse return error.MissingWorkflowEntityServices;
        const services: *ClusterWorkflowEntityServices = @ptrCast(@alignCast(raw));
        var command = try parseClusterWorkflowCommandJson(scope.allocator, entity_envelope.payload);
        defer command.deinit(scope.allocator);

        if (command.execution_id != entity_envelope.address.id) return error.WorkflowExecutionMismatch;

        var result = try applyClusterWorkflowCommand(scope.allocator, services.journal_store, command);
        defer result.deinit(scope.allocator);

        if (services.last_reply_json.len > 0) {
            services.allocator.free(services.last_reply_json);
            services.last_reply_json = "";
        }
        services.last_reply_json = try formatClusterWorkflowCommandResultJson(services.allocator, result);
        return .{ .reply = services.last_reply_json };
    }
};

fn findRecoveredExecution(executions: []const RecoveredWorkflowExecution, execution_id: ExecutionId) ?usize {
    for (executions, 0..) |execution, index| {
        if (execution.execution_id == execution_id) return index;
    }
    return null;
}

const ClusterWorkflowCommandJson = struct {
    schema: []const u8,
    schema_version: u32,
    kind: []const u8,
    event_kind: ?[]const u8 = null,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    workflow_name: []const u8 = "",
    name: []const u8 = "",
    status: []const u8 = "",
    redacted_detail: []const u8 = "",
    idempotency_key: []const u8 = "",
    now_ms: u64 = 0,
    activity_id: ?ActivityId = null,
    timer_id: ?TimerId = null,
    deferred_id: ?DeferredId = null,
    queue_id: ?QueueId = null,
    compensation_id: ?CompensationId = null,
    expected_next_sequence: ?JournalSequence = null,
};

const ClusterWorkflowCommandResultJson = struct {
    schema: []const u8,
    schema_version: u32,
    kind: []const u8,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    appended: bool,
    sequence: ?JournalSequence = null,
    last_sequence: JournalSequence,
    status: []const u8 = "",
    timers_fired: usize = 0,
};

pub fn clusterWorkflowExecutionAddress(execution_id: ExecutionId) EntityAddress {
    return .{
        .entity_type = .{ .name = cluster_workflow_entity_type },
        .id = execution_id,
    };
}

pub fn formatClusterWorkflowCommandJson(allocator: Allocator, command: ClusterWorkflowCommand) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, cluster_workflow_command_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{cluster_workflow_command_schema_version});
    try output.appendSlice(allocator, ",\"kind\":");
    try appendJsonString(&output, allocator, @tagName(command.kind));
    try output.appendSlice(allocator, ",\"event_kind\":");
    try appendOptionalWorkflowEventKind(&output, allocator, command.event_kind);
    try output.print(allocator, ",\"workflow_id\":{d}", .{command.workflow_id});
    try output.print(allocator, ",\"execution_id\":{d}", .{command.execution_id});
    try output.appendSlice(allocator, ",\"workflow_name\":");
    try appendJsonString(&output, allocator, command.workflow_name);
    try output.appendSlice(allocator, ",\"name\":");
    try appendJsonString(&output, allocator, command.name);
    try output.appendSlice(allocator, ",\"status\":");
    try appendJsonString(&output, allocator, command.status);
    try output.appendSlice(allocator, ",\"redacted_detail\":");
    try appendJsonString(&output, allocator, command.redacted_detail);
    try output.appendSlice(allocator, ",\"idempotency_key\":");
    try appendJsonString(&output, allocator, command.idempotency_key);
    try output.print(allocator, ",\"now_ms\":{d}", .{command.now_ms});
    try output.appendSlice(allocator, ",\"activity_id\":");
    try appendOptionalJsonU64(&output, allocator, command.activity_id);
    try output.appendSlice(allocator, ",\"timer_id\":");
    try appendOptionalJsonU64(&output, allocator, command.timer_id);
    try output.appendSlice(allocator, ",\"deferred_id\":");
    try appendOptionalJsonU64(&output, allocator, command.deferred_id);
    try output.appendSlice(allocator, ",\"queue_id\":");
    try appendOptionalJsonU64(&output, allocator, command.queue_id);
    try output.appendSlice(allocator, ",\"compensation_id\":");
    try appendOptionalJsonU64(&output, allocator, command.compensation_id);
    try output.appendSlice(allocator, ",\"expected_next_sequence\":");
    try appendOptionalJsonU64(&output, allocator, command.expected_next_sequence);
    try output.append(allocator, '}');
    return output.toOwnedSlice(allocator);
}

pub fn parseClusterWorkflowCommandJson(allocator: Allocator, content: []const u8) (Allocator.Error || ClusterWorkflowCommandError)!ClusterWorkflowCommand {
    var parsed = std.json.parseFromSlice(ClusterWorkflowCommandJson, allocator, content, .{ .ignore_unknown_fields = true }) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.CorruptClusterWorkflowCommand,
    };
    defer parsed.deinit();

    if (!std.mem.eql(u8, parsed.value.schema, cluster_workflow_command_schema)) return error.IncompatibleClusterWorkflowCommandSchema;
    if (parsed.value.schema_version != cluster_workflow_command_schema_version) return error.IncompatibleClusterWorkflowCommandSchema;

    const kind = std.meta.stringToEnum(ClusterWorkflowCommandKind, parsed.value.kind) orelse return error.CorruptClusterWorkflowCommand;
    const event_kind = if (parsed.value.event_kind) |name|
        journal.workflowEventKindFromName(name) orelse return error.CorruptClusterWorkflowCommand
    else
        null;

    return .{
        .kind = kind,
        .event_kind = event_kind,
        .workflow_id = parsed.value.workflow_id,
        .execution_id = parsed.value.execution_id,
        .workflow_name = try dupeOrEmpty(allocator, parsed.value.workflow_name),
        .name = try dupeOrEmpty(allocator, parsed.value.name),
        .status = try dupeOrEmpty(allocator, parsed.value.status),
        .redacted_detail = try dupeOrEmpty(allocator, parsed.value.redacted_detail),
        .idempotency_key = try dupeOrEmpty(allocator, parsed.value.idempotency_key),
        .now_ms = parsed.value.now_ms,
        .activity_id = parsed.value.activity_id,
        .timer_id = parsed.value.timer_id,
        .deferred_id = parsed.value.deferred_id,
        .queue_id = parsed.value.queue_id,
        .compensation_id = parsed.value.compensation_id,
        .expected_next_sequence = parsed.value.expected_next_sequence,
    };
}

pub fn formatClusterWorkflowCommandResultJson(allocator: Allocator, result: ClusterWorkflowCommandResult) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, cluster_workflow_command_result_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{cluster_workflow_command_result_schema_version});
    try output.appendSlice(allocator, ",\"kind\":");
    try appendJsonString(&output, allocator, @tagName(result.kind));
    try output.print(allocator, ",\"workflow_id\":{d}", .{result.workflow_id});
    try output.print(allocator, ",\"execution_id\":{d}", .{result.execution_id});
    try output.print(allocator, ",\"appended\":{}", .{result.appended});
    try output.appendSlice(allocator, ",\"sequence\":");
    try appendOptionalJsonU64(&output, allocator, result.sequence);
    try output.print(allocator, ",\"last_sequence\":{d}", .{result.last_sequence});
    try output.appendSlice(allocator, ",\"status\":");
    try appendJsonString(&output, allocator, result.status);
    try output.print(allocator, ",\"timers_fired\":{d}", .{result.timers_fired});
    try output.append(allocator, '}');
    return output.toOwnedSlice(allocator);
}

pub fn parseClusterWorkflowCommandResultJson(allocator: Allocator, content: []const u8) (Allocator.Error || ClusterWorkflowCommandError)!ClusterWorkflowCommandResult {
    var parsed = std.json.parseFromSlice(ClusterWorkflowCommandResultJson, allocator, content, .{ .ignore_unknown_fields = true }) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.CorruptClusterWorkflowCommand,
    };
    defer parsed.deinit();

    if (!std.mem.eql(u8, parsed.value.schema, cluster_workflow_command_result_schema)) return error.IncompatibleClusterWorkflowCommandSchema;
    if (parsed.value.schema_version != cluster_workflow_command_result_schema_version) return error.IncompatibleClusterWorkflowCommandSchema;
    const kind = std.meta.stringToEnum(ClusterWorkflowCommandKind, parsed.value.kind) orelse return error.CorruptClusterWorkflowCommand;

    return .{
        .kind = kind,
        .workflow_id = parsed.value.workflow_id,
        .execution_id = parsed.value.execution_id,
        .appended = parsed.value.appended,
        .sequence = parsed.value.sequence,
        .last_sequence = parsed.value.last_sequence,
        .status = try dupeOrEmpty(allocator, parsed.value.status),
        .timers_fired = parsed.value.timers_fired,
    };
}

pub fn parseClusterWorkflowCommandResultFromReply(allocator: Allocator, reply: MessageEnvelope) !ClusterWorkflowCommandResult {
    return parseClusterWorkflowCommandResultJson(allocator, reply.payload);
}

fn applyClusterWorkflowCommand(
    allocator: Allocator,
    journal_store: JournalStore,
    command: ClusterWorkflowCommand,
) !ClusterWorkflowCommandResult {
    return switch (command.kind) {
        .start => appendWorkflowCommandEvent(allocator, journal_store, command, .workflow_started, "running"),
        .append_event => appendWorkflowCommandEvent(
            allocator,
            journal_store,
            command,
            command.event_kind orelse return error.CorruptClusterWorkflowCommand,
            command.status,
        ),
        .complete => appendWorkflowCommandEvent(allocator, journal_store, command, .workflow_completed, "completed"),
        .@"suspend" => applyLifecycleCommand(allocator, journal_store, command, .workflow_suspended, "waiting"),
        .@"resume" => applyLifecycleCommand(allocator, journal_store, command, .workflow_resumed, "running"),
        .interrupt => applyLifecycleCommand(allocator, journal_store, command, .workflow_interrupted, "interrupted"),
        .cancel => applyLifecycleCommand(allocator, journal_store, command, .workflow_cancelled, "cancelled"),
        .fire_due_timers => applyFireDueTimersCommand(allocator, journal_store, command),
        .complete_deferred => appendHelperEventAndResume(allocator, journal_store, command, .deferred_completed, command.deferred_id orelse return error.CorruptClusterWorkflowCommand, "completed"),
        .fail_deferred => appendHelperEventAndResume(allocator, journal_store, command, .deferred_failed, command.deferred_id orelse return error.CorruptClusterWorkflowCommand, "failed"),
        .cancel_deferred => appendHelperEventAndResume(allocator, journal_store, command, .deferred_cancelled, command.deferred_id orelse return error.CorruptClusterWorkflowCommand, "cancelled"),
        .send_signal => appendHelperEventAndResume(allocator, journal_store, command, .signal_received, null, "received"),
        .complete_queue => appendHelperEventAndResume(allocator, journal_store, command, .queue_completed, command.queue_id orelse return error.CorruptClusterWorkflowCommand, "completed"),
        .fail_queue => appendHelperEventAndResume(allocator, journal_store, command, .queue_failed, command.queue_id orelse return error.CorruptClusterWorkflowCommand, "failed"),
    };
}

fn appendWorkflowCommandEvent(
    allocator: Allocator,
    journal_store: JournalStore,
    command: ClusterWorkflowCommand,
    event_kind: WorkflowEventKind,
    default_status: []const u8,
) !ClusterWorkflowCommandResult {
    const sequence = command.expected_next_sequence orelse try nextJournalSequence(allocator, journal_store);
    const status = if (command.status.len == 0) default_status else command.status;
    const event_name = if (command.name.len != 0) command.name else command.workflow_name;

    _ = journal_store.append(.{
        .expected_next_sequence = sequence,
        .event = .{
            .sequence = sequence,
            .kind = event_kind,
            .workflow_id = command.workflow_id,
            .execution_id = command.execution_id,
            .activity_id = command.activity_id,
            .timer_id = command.timer_id,
            .deferred_id = command.deferred_id,
            .queue_id = command.queue_id,
            .compensation_id = command.compensation_id,
            .name = event_name,
            .status = status,
            .redacted_detail = command.redacted_detail,
            .idempotency_key = command.idempotency_key,
        },
    }) catch |err| switch (err) {
        error.DuplicateEvent => return commandResultFromJournal(allocator, journal_store, command, false, null, status, 0),
        else => return err,
    };

    return commandResultFromJournal(allocator, journal_store, command, true, sequence, status, 0);
}

fn applyLifecycleCommand(
    allocator: Allocator,
    journal_store: JournalStore,
    command: ClusterWorkflowCommand,
    event_kind: WorkflowEventKind,
    status: []const u8,
) !ClusterWorkflowCommandResult {
    var workflow_lifecycle = lifecycle.WorkflowLifecycle.init(allocator, journal_store, command.workflow_id, command.execution_id);
    const appended = switch (event_kind) {
        .workflow_suspended => try workflow_lifecycle.suspendWorkflow(command.redacted_detail),
        .workflow_resumed => try workflow_lifecycle.resumeWorkflow(command.redacted_detail),
        .workflow_interrupted => try workflow_lifecycle.interrupt(command.redacted_detail),
        .workflow_cancelled => try workflow_lifecycle.cancel(command.redacted_detail),
        else => unreachable,
    };
    const sequence = if (appended) try latestJournalSequence(allocator, journal_store) else null;
    return commandResultFromJournal(allocator, journal_store, command, appended, sequence, status, 0);
}

fn applyFireDueTimersCommand(
    allocator: Allocator,
    journal_store: JournalStore,
    command: ClusterWorkflowCommand,
) !ClusterWorkflowCommandResult {
    var durable_clock = workflow_clock.DurableClock.init(allocator, journal_store, command.workflow_id, command.execution_id);
    const fired = try durable_clock.fireDueTimers(command.now_ms);
    const sequence = if (fired > 0) try latestJournalSequence(allocator, journal_store) else null;
    return commandResultFromJournal(allocator, journal_store, command, fired > 0, sequence, "running", fired);
}

fn appendHelperEventAndResume(
    allocator: Allocator,
    journal_store: JournalStore,
    command: ClusterWorkflowCommand,
    event_kind: WorkflowEventKind,
    id: ?u64,
    default_status: []const u8,
) !ClusterWorkflowCommandResult {
    const was_suspended = try workflowIsSuspended(allocator, journal_store);
    var sequence = try nextJournalSequence(allocator, journal_store);
    const terminal_sequence = sequence;
    const status = if (command.status.len == 0) default_status else command.status;

    _ = journal_store.append(.{
        .expected_next_sequence = terminal_sequence,
        .event = helperWorkflowEvent(command, event_kind, id, terminal_sequence, status),
    }) catch |err| switch (err) {
        error.DuplicateEvent => return commandResultFromJournal(allocator, journal_store, command, false, null, status, 0),
        else => return err,
    };
    sequence = try sequenceAfter(terminal_sequence);

    if (was_suspended) {
        const resume_key = try std.fmt.allocPrint(
            allocator,
            "cluster-workflow:resume:{s}:{d}:{d}",
            .{ @tagName(command.kind), command.execution_id, sequence },
        );
        defer allocator.free(resume_key);
        _ = try journal_store.append(.{
            .expected_next_sequence = sequence,
            .event = .{
                .sequence = sequence,
                .kind = .workflow_resumed,
                .workflow_id = command.workflow_id,
                .execution_id = command.execution_id,
                .name = command.name,
                .status = "running",
                .redacted_detail = @tagName(command.kind),
                .idempotency_key = resume_key,
            },
        });
    }

    return commandResultFromJournal(allocator, journal_store, command, true, terminal_sequence, status, 0);
}

fn helperWorkflowEvent(
    command: ClusterWorkflowCommand,
    event_kind: WorkflowEventKind,
    id: ?u64,
    sequence: JournalSequence,
    status: []const u8,
) journal.WorkflowEvent {
    var event = journal.WorkflowEvent{
        .sequence = sequence,
        .kind = event_kind,
        .workflow_id = command.workflow_id,
        .execution_id = command.execution_id,
        .name = command.name,
        .status = status,
        .redacted_detail = command.redacted_detail,
        .idempotency_key = command.idempotency_key,
    };
    switch (event_kind) {
        .deferred_completed, .deferred_failed, .deferred_cancelled => event.deferred_id = id,
        .queue_completed, .queue_failed => event.queue_id = id,
        else => {},
    }
    return event;
}

fn commandResultFromJournal(
    allocator: Allocator,
    journal_store: JournalStore,
    command: ClusterWorkflowCommand,
    appended: bool,
    sequence: ?JournalSequence,
    fallback_status: []const u8,
    timers_fired: usize,
) !ClusterWorkflowCommandResult {
    var state = journal_store.latestState(allocator) catch |err| switch (err) {
        error.EmptyWorkflowJournal => replay.WorkflowReplayState.init(allocator),
        else => return err,
    };
    defer state.deinit();

    const status = if (state.workflow_id == command.workflow_id and state.execution_id == command.execution_id)
        @tagName(state.workflow_status)
    else
        fallback_status;
    return .{
        .kind = command.kind,
        .workflow_id = command.workflow_id,
        .execution_id = command.execution_id,
        .appended = appended,
        .sequence = sequence,
        .last_sequence = state.last_sequence,
        .status = try dupeOrEmpty(allocator, status),
        .timers_fired = timers_fired,
    };
}

fn nextJournalSequence(allocator: Allocator, journal_store: JournalStore) !JournalSequence {
    const latest = try latestJournalSequence(allocator, journal_store);
    if (latest == std.math.maxInt(JournalSequence)) return error.SequenceOverflow;
    return latest + 1;
}

fn sequenceAfter(sequence: JournalSequence) !JournalSequence {
    if (sequence == std.math.maxInt(JournalSequence)) return error.SequenceOverflow;
    return sequence + 1;
}

fn workflowIsSuspended(allocator: Allocator, journal_store: JournalStore) !bool {
    var state = try journal_store.latestState(allocator);
    defer state.deinit();
    return state.workflow_status == .suspended;
}

fn latestJournalSequence(allocator: Allocator, journal_store: JournalStore) !JournalSequence {
    var events = try journal_store.readAll(allocator);
    defer events.deinit();
    if (events.events.len == 0) return 0;
    return events.events[events.events.len - 1].sequence;
}

fn dupeOrEmpty(allocator: Allocator, value: []const u8) Allocator.Error![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: Allocator, value: []const u8) Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

fn appendOptionalWorkflowEventKind(output: *std.ArrayList(u8), allocator: Allocator, event_kind: ?WorkflowEventKind) Allocator.Error!void {
    if (event_kind) |kind| {
        try appendJsonString(output, allocator, journal.workflowEventKindName(kind));
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendOptionalJsonU64(output: *std.ArrayList(u8), allocator: Allocator, value: ?u64) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}
