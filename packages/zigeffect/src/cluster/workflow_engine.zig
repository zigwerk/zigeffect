const std = @import("std");
const identity = @import("identity.zig");
const local_cluster = @import("local_cluster.zig");
const routing = @import("routing.zig");
const journal = @import("../workflow/journal.zig");
const store = @import("../workflow/store.zig");

pub const Allocator = std.mem.Allocator;
pub const EntityAddress = identity.EntityAddress;
pub const JournalStore = store.JournalStore;
pub const LocalClusterRunner = local_cluster.LocalClusterRunner;
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

pub const ClusterWorkflowEngine = struct {};

pub const ClusterWorkflowEntityServices = struct {
    journal_store: JournalStore,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
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
pub const ClusterWorkflowEntityHandler = struct {};

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
