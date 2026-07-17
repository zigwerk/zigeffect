const std = @import("std");
const causal_mod = @import("../services/causal.zig");
const workflow_causal = @import("causal.zig");
const journal = @import("journal.zig");
const replay = @import("replay.zig");

const Allocator = std.mem.Allocator;

pub const WorkflowEvent = journal.WorkflowEvent;
pub const JournalSequence = journal.JournalSequence;
pub const WorkflowReplayState = replay.WorkflowReplayState;
pub const CausalStore = causal_mod.CausalStore;

pub const workflow_checkpoint_schema = "zigeffect.workflow.checkpoint.v1";
pub const workflow_checkpoint_schema_version: u32 = 1;

const CausalJournalSequenceId = struct {
    workflow_sequence: JournalSequence,
    causal_id: u64,
};
pub const workflow_snapshot_commit_schema = "zigeffect.workflow.snapshot-commit.v1";
pub const workflow_snapshot_commit_schema_version: u32 = 1;

pub const JournalStoreError = error{
    SequenceConflict,
    DuplicateEvent,
    SequenceOverflow,
    EventLimitExceeded,
};

pub const FileJournalStoreError = error{
    JournalStoreLocked,
    CorruptJournal,
    JournalRequiresNewerRuntime,
};

pub const JournalStoreAppendError = anyerror;
pub const JournalStoreReadError = anyerror;
pub const JournalStoreReplayError = anyerror;

pub const JournalFsyncPolicy = enum {
    never,
    after_append,
    after_recovery,
    always,
};

pub const JournalCorruptionReason = enum {
    invalid_json,
    invalid_schema,
    unknown_kind,
    sequence_conflict,
    duplicate_event,
};

pub const JournalCorruptionReport = struct {
    segment_name: []const u8,
    offset: u64,
    reason: JournalCorruptionReason,
};

pub const JournalAppend = struct {
    expected_next_sequence: ?JournalSequence = null,
    event: WorkflowEvent,
};

pub const JournalEventBatch = struct {
    allocator: Allocator,
    events: []WorkflowEvent,

    pub fn deinit(self: *JournalEventBatch) void {
        for (self.events) |event| {
            journal.deinitWorkflowEventStrings(self.allocator, event);
        }
        self.allocator.free(self.events);
    }
};

pub const JournalCapacityStats = struct {
    event_count: usize = 0,
    max_events: ?usize = null,
    remaining_events: ?usize = null,
};

pub const InMemoryJournalStoreOptions = struct {
    max_events: ?usize = null,
};

pub fn segmentFileName(allocator: Allocator, first_sequence: JournalSequence) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "workflow-{d:0>16}.jsonl", .{first_sequence});
}

pub fn checkpointFileName(allocator: Allocator, last_sequence: JournalSequence) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "workflow-checkpoint-{d:0>16}.json", .{last_sequence});
}

pub fn snapshotCommitFileName(allocator: Allocator, last_sequence: JournalSequence) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "workflow-snapshot-commit-{d:0>16}.json", .{last_sequence});
}

pub fn archiveFileName(allocator: Allocator, first_sequence: JournalSequence, last_sequence: JournalSequence) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "workflow-archive-{d:0>16}-{d:0>16}.jsonl", .{ first_sequence, last_sequence });
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
            0x00...0x08, 0x0b, 0x0c, 0x0e...0x1f => try output.print(allocator, "\\u{x:0>4}", .{byte}),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

fn appendOptionalJsonString(output: *std.ArrayList(u8), allocator: Allocator, value: ?[]const u8) Allocator.Error!void {
    if (value) |text| {
        try appendJsonString(output, allocator, text);
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

fn appendActivityCheckpointRows(output: *std.ArrayList(u8), allocator: Allocator, rows: []const replay.ActivityState) Allocator.Error!void {
    try output.appendSlice(allocator, "\"activities\":[");
    for (rows, 0..) |row, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.print(allocator, "{{\"activity_id\":{d},\"attempt\":{d},\"status\":", .{ row.id, row.attempt });
        try appendJsonString(output, allocator, @tagName(row.status));
        try output.print(allocator, ",\"last_sequence\":{d},\"name\":", .{row.last_sequence});
        try appendJsonString(output, allocator, row.name);
        try output.append(allocator, '}');
    }
    try output.append(allocator, ']');
}

fn appendTimerCheckpointRows(output: *std.ArrayList(u8), allocator: Allocator, rows: []const replay.TimerState) Allocator.Error!void {
    try output.appendSlice(allocator, "\"timers\":[");
    for (rows, 0..) |row, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.print(allocator, "{{\"timer_id\":{d},\"status\":", .{row.id});
        try appendJsonString(output, allocator, @tagName(row.status));
        try output.print(allocator, ",\"last_sequence\":{d},\"name\":", .{row.last_sequence});
        try appendJsonString(output, allocator, row.name);
        try output.append(allocator, '}');
    }
    try output.append(allocator, ']');
}

fn appendDeferredCheckpointRows(output: *std.ArrayList(u8), allocator: Allocator, rows: []const replay.DeferredState) Allocator.Error!void {
    try output.appendSlice(allocator, "\"deferreds\":[");
    for (rows, 0..) |row, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.print(allocator, "{{\"deferred_id\":{d},\"status\":", .{row.id});
        try appendJsonString(output, allocator, @tagName(row.status));
        try output.print(allocator, ",\"last_sequence\":{d},\"name\":", .{row.last_sequence});
        try appendJsonString(output, allocator, row.name);
        try output.append(allocator, '}');
    }
    try output.append(allocator, ']');
}

fn appendQueueCheckpointRows(output: *std.ArrayList(u8), allocator: Allocator, rows: []const replay.QueueState) Allocator.Error!void {
    try output.appendSlice(allocator, "\"queues\":[");
    for (rows, 0..) |row, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.print(allocator, "{{\"queue_id\":{d},\"status\":", .{row.id});
        try appendJsonString(output, allocator, @tagName(row.status));
        try output.print(allocator, ",\"last_sequence\":{d},\"name\":", .{row.last_sequence});
        try appendJsonString(output, allocator, row.name);
        try output.append(allocator, '}');
    }
    try output.append(allocator, ']');
}

fn appendCompensationCheckpointRows(output: *std.ArrayList(u8), allocator: Allocator, rows: []const replay.CompensationState) Allocator.Error!void {
    try output.appendSlice(allocator, "\"compensations\":[");
    for (rows, 0..) |row, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.print(allocator, "{{\"compensation_id\":{d},\"status\":", .{row.id});
        try appendJsonString(output, allocator, @tagName(row.status));
        try output.print(allocator, ",\"last_sequence\":{d},\"name\":", .{row.last_sequence});
        try appendJsonString(output, allocator, row.name);
        try output.append(allocator, '}');
    }
    try output.append(allocator, ']');
}

pub fn formatWorkflowCheckpointJson(allocator: Allocator, state: *const WorkflowReplayState) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, workflow_checkpoint_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{workflow_checkpoint_schema_version});
    try output.print(allocator, ",\"last_sequence\":{d}", .{state.last_sequence});
    try output.appendSlice(allocator, ",\"workflow_status\":");
    try appendJsonString(&output, allocator, @tagName(state.workflow_status));
    try output.appendSlice(allocator, ",\"workflow_id\":");
    try appendOptionalJsonU64(&output, allocator, state.workflow_id);
    try output.appendSlice(allocator, ",\"execution_id\":");
    try appendOptionalJsonU64(&output, allocator, state.execution_id);
    try output.append(allocator, ',');
    try appendActivityCheckpointRows(&output, allocator, state.activities.items);
    try output.append(allocator, ',');
    try appendTimerCheckpointRows(&output, allocator, state.timers.items);
    try output.append(allocator, ',');
    try appendDeferredCheckpointRows(&output, allocator, state.deferreds.items);
    try output.append(allocator, ',');
    try appendQueueCheckpointRows(&output, allocator, state.queues.items);
    try output.append(allocator, ',');
    try appendCompensationCheckpointRows(&output, allocator, state.compensations.items);
    try output.append(allocator, '}');

    return output.toOwnedSlice(allocator);
}

pub const WorkflowSnapshotCommit = struct {
    allocator: ?Allocator = null,
    last_sequence: JournalSequence,
    checkpoint_name: []const u8,
    segment_name: []const u8,
    archive_name: ?[]const u8 = null,

    pub fn deinit(self: *WorkflowSnapshotCommit) void {
        const allocator = self.allocator orelse return;
        allocator.free(self.checkpoint_name);
        allocator.free(self.segment_name);
        if (self.archive_name) |name| allocator.free(name);
        self.* = undefined;
    }
};

const WorkflowSnapshotCommitJson = struct {
    schema: []const u8,
    schema_version: u32,
    last_sequence: JournalSequence,
    checkpoint_name: []const u8,
    segment_name: []const u8,
    archive_name: ?[]const u8 = null,
};

pub const WorkflowSnapshotCommitParseError = error{
    InvalidWorkflowSnapshotCommitSchema,
    InvalidWorkflowSnapshotCommitSchemaVersion,
};

pub fn formatWorkflowSnapshotCommitJson(allocator: Allocator, commit: WorkflowSnapshotCommit) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, workflow_snapshot_commit_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{workflow_snapshot_commit_schema_version});
    try output.print(allocator, ",\"last_sequence\":{d}", .{commit.last_sequence});
    try output.appendSlice(allocator, ",\"checkpoint_name\":");
    try appendJsonString(&output, allocator, commit.checkpoint_name);
    try output.appendSlice(allocator, ",\"segment_name\":");
    try appendJsonString(&output, allocator, commit.segment_name);
    try output.appendSlice(allocator, ",\"archive_name\":");
    try appendOptionalJsonString(&output, allocator, commit.archive_name);
    try output.append(allocator, '}');

    return output.toOwnedSlice(allocator);
}

pub fn parseWorkflowSnapshotCommitJson(allocator: Allocator, commit_json: []const u8) !WorkflowSnapshotCommit {
    var parsed = try std.json.parseFromSlice(WorkflowSnapshotCommitJson, allocator, commit_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    if (!std.mem.eql(u8, parsed.value.schema, workflow_snapshot_commit_schema)) {
        return error.InvalidWorkflowSnapshotCommitSchema;
    }
    if (parsed.value.schema_version != workflow_snapshot_commit_schema_version) {
        return error.InvalidWorkflowSnapshotCommitSchemaVersion;
    }

    const checkpoint_name = try allocator.dupe(u8, parsed.value.checkpoint_name);
    errdefer allocator.free(checkpoint_name);
    const segment_name = try allocator.dupe(u8, parsed.value.segment_name);
    errdefer allocator.free(segment_name);
    const archive_name = if (parsed.value.archive_name) |name| try allocator.dupe(u8, name) else null;
    errdefer if (archive_name) |name| allocator.free(name);

    return .{
        .allocator = allocator,
        .last_sequence = parsed.value.last_sequence,
        .checkpoint_name = checkpoint_name,
        .segment_name = segment_name,
        .archive_name = archive_name,
    };
}

pub const WorkflowCheckpointParseError = error{
    InvalidWorkflowCheckpointSchema,
    InvalidWorkflowCheckpointSchemaVersion,
    UnknownWorkflowCheckpointStatus,
    UnknownActivityCheckpointStatus,
    UnknownTimerCheckpointStatus,
    UnknownDeferredCheckpointStatus,
    UnknownQueueCheckpointStatus,
    UnknownCompensationCheckpointStatus,
};

const ActivityCheckpointRow = struct {
    activity_id: journal.ActivityId,
    attempt: u32 = 0,
    status: []const u8,
    last_sequence: JournalSequence,
    name: []const u8 = "",
};

const TimerCheckpointRow = struct {
    timer_id: journal.TimerId,
    status: []const u8,
    last_sequence: JournalSequence,
    name: []const u8 = "",
};

const DeferredCheckpointRow = struct {
    deferred_id: journal.DeferredId,
    status: []const u8,
    last_sequence: JournalSequence,
    name: []const u8 = "",
};

const QueueCheckpointRow = struct {
    queue_id: journal.QueueId,
    status: []const u8,
    last_sequence: JournalSequence,
    name: []const u8 = "",
};

const CompensationCheckpointRow = struct {
    compensation_id: journal.CompensationId,
    status: []const u8,
    last_sequence: JournalSequence,
    name: []const u8 = "",
};

const WorkflowCheckpointJson = struct {
    schema: []const u8,
    schema_version: u32,
    last_sequence: JournalSequence,
    workflow_status: []const u8,
    workflow_id: ?journal.WorkflowId = null,
    execution_id: ?journal.ExecutionId = null,
    activities: []ActivityCheckpointRow,
    timers: []TimerCheckpointRow,
    deferreds: []DeferredCheckpointRow,
    queues: []QueueCheckpointRow,
    compensations: []CompensationCheckpointRow,
};

fn cloneCheckpointName(allocator: Allocator, name: []const u8) Allocator.Error![]const u8 {
    if (name.len == 0) return "";
    return allocator.dupe(u8, name);
}

fn freeCheckpointName(allocator: Allocator, name: []const u8) void {
    if (name.len != 0) allocator.free(name);
}

pub fn parseWorkflowCheckpointJson(allocator: Allocator, checkpoint_json: []const u8) !WorkflowReplayState {
    var parsed = try std.json.parseFromSlice(WorkflowCheckpointJson, allocator, checkpoint_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    if (!std.mem.eql(u8, parsed.value.schema, workflow_checkpoint_schema)) {
        return error.InvalidWorkflowCheckpointSchema;
    }
    if (parsed.value.schema_version != workflow_checkpoint_schema_version) {
        return error.InvalidWorkflowCheckpointSchemaVersion;
    }

    var state = WorkflowReplayState.init(allocator);
    errdefer state.deinit();

    state.workflow_status = std.meta.stringToEnum(replay.WorkflowStatus, parsed.value.workflow_status) orelse
        return error.UnknownWorkflowCheckpointStatus;
    state.workflow_id = parsed.value.workflow_id;
    state.execution_id = parsed.value.execution_id;
    state.last_sequence = parsed.value.last_sequence;

    for (parsed.value.activities) |row| {
        const status = std.meta.stringToEnum(replay.ActivityStatus, row.status) orelse
            return error.UnknownActivityCheckpointStatus;
        {
            const name = try cloneCheckpointName(allocator, row.name);
            errdefer freeCheckpointName(allocator, name);
            try state.activities.append(allocator, .{
                .id = row.activity_id,
                .status = status,
                .last_sequence = row.last_sequence,
                .attempt = row.attempt,
                .name = name,
            });
        }
    }

    for (parsed.value.timers) |row| {
        const status = std.meta.stringToEnum(replay.TimerStatus, row.status) orelse
            return error.UnknownTimerCheckpointStatus;
        {
            const name = try cloneCheckpointName(allocator, row.name);
            errdefer freeCheckpointName(allocator, name);
            try state.timers.append(allocator, .{
                .id = row.timer_id,
                .status = status,
                .last_sequence = row.last_sequence,
                .name = name,
            });
        }
    }

    for (parsed.value.deferreds) |row| {
        const status = std.meta.stringToEnum(replay.DeferredStatus, row.status) orelse
            return error.UnknownDeferredCheckpointStatus;
        {
            const name = try cloneCheckpointName(allocator, row.name);
            errdefer freeCheckpointName(allocator, name);
            try state.deferreds.append(allocator, .{
                .id = row.deferred_id,
                .status = status,
                .last_sequence = row.last_sequence,
                .name = name,
            });
        }
    }

    for (parsed.value.queues) |row| {
        const status = std.meta.stringToEnum(replay.QueueStatus, row.status) orelse
            return error.UnknownQueueCheckpointStatus;
        {
            const name = try cloneCheckpointName(allocator, row.name);
            errdefer freeCheckpointName(allocator, name);
            try state.queues.append(allocator, .{
                .id = row.queue_id,
                .status = status,
                .last_sequence = row.last_sequence,
                .name = name,
            });
        }
    }

    for (parsed.value.compensations) |row| {
        const status = std.meta.stringToEnum(replay.CompensationStatus, row.status) orelse
            return error.UnknownCompensationCheckpointStatus;
        {
            const name = try cloneCheckpointName(allocator, row.name);
            errdefer freeCheckpointName(allocator, name);
            try state.compensations.append(allocator, .{
                .id = row.compensation_id,
                .status = status,
                .last_sequence = row.last_sequence,
                .name = name,
            });
        }
    }

    return state;
}

pub const JournalStore = struct {
    context: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        append: *const fn (*anyopaque, JournalAppend) JournalStoreAppendError!JournalSequence,
        read_all: *const fn (*anyopaque, Allocator) JournalStoreReadError!JournalEventBatch,
        read_from_sequence: *const fn (*anyopaque, Allocator, JournalSequence) JournalStoreReadError!JournalEventBatch,
        latest_state: *const fn (*anyopaque, Allocator) JournalStoreReplayError!WorkflowReplayState,
        reset: *const fn (*anyopaque) void,
    };

    pub fn append(self: JournalStore, request: JournalAppend) JournalStoreAppendError!JournalSequence {
        return self.vtable.append(self.context, request);
    }

    pub fn readAll(self: JournalStore, allocator: Allocator) JournalStoreReadError!JournalEventBatch {
        return self.vtable.read_all(self.context, allocator);
    }

    pub fn readFromSequence(self: JournalStore, allocator: Allocator, sequence: JournalSequence) JournalStoreReadError!JournalEventBatch {
        return self.vtable.read_from_sequence(self.context, allocator, sequence);
    }

    pub fn latestState(self: JournalStore, allocator: Allocator) JournalStoreReplayError!WorkflowReplayState {
        return self.vtable.latest_state(self.context, allocator);
    }

    pub fn reset(self: JournalStore) void {
        self.vtable.reset(self.context);
    }
};

pub const CausalJournalStore = struct {
    allocator: Allocator,
    inner: JournalStore,
    causal_recorder: causal_mod.CausalRecorder,
    run_id: ?u64 = null,
    sequence_ids: std.ArrayList(CausalJournalSequenceId) = .empty,

    pub fn init(
        allocator: Allocator,
        inner: JournalStore,
        causal_store: *CausalStore,
        run_id: ?u64,
    ) CausalJournalStore {
        return initRecorder(allocator, inner, causal_mod.CausalRecorder.fromStore(causal_store), run_id);
    }

    pub fn initRecorder(
        allocator: Allocator,
        inner: JournalStore,
        causal_recorder: causal_mod.CausalRecorder,
        run_id: ?u64,
    ) CausalJournalStore {
        return .{
            .allocator = allocator,
            .inner = inner,
            .causal_recorder = causal_recorder,
            .run_id = run_id,
        };
    }

    pub fn deinit(self: *CausalJournalStore) void {
        self.sequence_ids.deinit(self.allocator);
    }

    pub fn asJournalStore(self: *CausalJournalStore) JournalStore {
        return .{
            .context = self,
            .vtable = &causal_journal_vtable,
        };
    }

    /// The most recent durable workflow event mirrored into the causal store.
    /// Statechart interpreters use this as the parent of the decision produced
    /// from that activity result, joining both execution models into one graph.
    pub fn latestCausalId(self: *const CausalJournalStore) ?u64 {
        if (self.sequence_ids.items.len == 0) return null;
        return self.sequence_ids.items[self.sequence_ids.items.len - 1].causal_id;
    }

    fn appendAdapter(context: *anyopaque, request: JournalAppend) JournalStoreAppendError!JournalSequence {
        const self: *CausalJournalStore = @ptrCast(@alignCast(context));
        const sequence = try self.inner.append(request);
        self.recordWorkflowEvent(request.event) catch {};
        return sequence;
    }

    fn readAllAdapter(context: *anyopaque, allocator: Allocator) JournalStoreReadError!JournalEventBatch {
        const self: *CausalJournalStore = @ptrCast(@alignCast(context));
        return self.inner.readAll(allocator);
    }

    fn readFromSequenceAdapter(context: *anyopaque, allocator: Allocator, sequence: JournalSequence) JournalStoreReadError!JournalEventBatch {
        const self: *CausalJournalStore = @ptrCast(@alignCast(context));
        return self.inner.readFromSequence(allocator, sequence);
    }

    fn latestStateAdapter(context: *anyopaque, allocator: Allocator) JournalStoreReplayError!WorkflowReplayState {
        const self: *CausalJournalStore = @ptrCast(@alignCast(context));
        return self.inner.latestState(allocator);
    }

    fn resetAdapter(context: *anyopaque) void {
        const self: *CausalJournalStore = @ptrCast(@alignCast(context));
        self.inner.reset();
        self.sequence_ids.clearRetainingCapacity();
    }

    fn recordWorkflowEvent(self: *CausalJournalStore, event: WorkflowEvent) Allocator.Error!void {
        try self.sequence_ids.ensureUnusedCapacity(self.allocator, 1);
        var mapped = try workflow_causal.mapWorkflowEventToCausal(self.allocator, event);
        defer workflow_causal.deinitMappedEvent(self.allocator, mapped);
        if (self.run_id) |run_id| mapped.run_id = run_id;
        if (event.parent_sequence) |parent_sequence| {
            mapped.parent_id = self.causalIdForSequence(parent_sequence) orelse parent_sequence;
        }
        const causal_id = try self.causal_recorder.record(mapped);
        self.sequence_ids.appendAssumeCapacity(.{
            .workflow_sequence = event.sequence,
            .causal_id = causal_id,
        });
    }

    fn causalIdForSequence(self: *const CausalJournalStore, sequence: JournalSequence) ?u64 {
        for (self.sequence_ids.items) |entry| {
            if (entry.workflow_sequence == sequence) return entry.causal_id;
        }
        return null;
    }
};

const causal_journal_vtable: JournalStore.VTable = .{
    .append = CausalJournalStore.appendAdapter,
    .read_all = CausalJournalStore.readAllAdapter,
    .read_from_sequence = CausalJournalStore.readFromSequenceAdapter,
    .latest_state = CausalJournalStore.latestStateAdapter,
    .reset = CausalJournalStore.resetAdapter,
};

pub const InMemoryJournalStore = struct {
    allocator: Allocator,
    options: InMemoryJournalStoreOptions = .{},
    events: std.ArrayList(WorkflowEvent) = .empty,
    base_sequence: JournalSequence = 0,

    pub fn init(allocator: Allocator) InMemoryJournalStore {
        return initBounded(allocator, .{});
    }

    pub fn initBounded(allocator: Allocator, options: InMemoryJournalStoreOptions) InMemoryJournalStore {
        return .{
            .allocator = allocator,
            .options = options,
        };
    }

    pub fn deinit(self: *InMemoryJournalStore) void {
        self.reset();
        self.events.deinit(self.allocator);
    }

    pub fn asJournalStore(self: *InMemoryJournalStore) JournalStore {
        return .{
            .context = self,
            .vtable = &in_memory_vtable,
        };
    }

    pub fn append(self: *InMemoryJournalStore, request: JournalAppend) JournalStoreAppendError!JournalSequence {
        try self.validateAppend(request);

        const owned = try journal.cloneWorkflowEvent(self.allocator, request.event);
        errdefer journal.deinitWorkflowEventStrings(self.allocator, owned);
        try self.events.append(self.allocator, owned);

        return owned.sequence;
    }

    pub fn validateAppend(self: *const InMemoryJournalStore, request: JournalAppend) JournalStoreError!void {
        const next_sequence = try self.nextSequence();
        if (request.expected_next_sequence) |expected| {
            if (expected != next_sequence) return error.SequenceConflict;
        }
        if (request.event.sequence != next_sequence) return error.SequenceConflict;
        if (self.hasIdempotencyKey(request.event.idempotency_key)) return error.DuplicateEvent;
        if (self.options.max_events) |max_events| {
            if (self.events.items.len >= max_events) return error.EventLimitExceeded;
        }
    }

    pub fn readAll(self: *const InMemoryJournalStore, allocator: Allocator) JournalStoreReadError!JournalEventBatch {
        return self.readFromSequence(allocator, 1);
    }

    pub fn readFromSequence(self: *const InMemoryJournalStore, allocator: Allocator, sequence: JournalSequence) JournalStoreReadError!JournalEventBatch {
        var output = std.ArrayList(WorkflowEvent).empty;
        errdefer {
            for (output.items) |event| {
                journal.deinitWorkflowEventStrings(allocator, event);
            }
            output.deinit(allocator);
        }

        for (self.events.items) |event| {
            if (event.sequence >= sequence) {
                {
                    const cloned = try journal.cloneWorkflowEvent(allocator, event);
                    errdefer journal.deinitWorkflowEventStrings(allocator, cloned);
                    try output.append(allocator, cloned);
                }
            }
        }

        return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
    }

    pub fn latestState(self: *const InMemoryJournalStore, allocator: Allocator) JournalStoreReplayError!WorkflowReplayState {
        var events = try self.readAll(allocator);
        defer events.deinit();
        return WorkflowReplayState.fold(allocator, events.events);
    }

    pub fn reset(self: *InMemoryJournalStore) void {
        for (self.events.items) |event| {
            journal.deinitWorkflowEventStrings(self.allocator, event);
        }
        self.events.clearRetainingCapacity();
        self.base_sequence = 0;
    }

    pub fn resetFromSequence(self: *InMemoryJournalStore, sequence: JournalSequence) void {
        self.reset();
        self.base_sequence = sequence;
    }

    pub fn capacityStats(self: *const InMemoryJournalStore) JournalCapacityStats {
        const event_count = self.events.items.len;
        return .{
            .event_count = event_count,
            .max_events = self.options.max_events,
            .remaining_events = if (self.options.max_events) |max_events|
                if (event_count >= max_events) 0 else max_events - event_count
            else
                null,
        };
    }

    fn nextSequence(self: *const InMemoryJournalStore) JournalStoreError!JournalSequence {
        if (self.events.items.len == 0) {
            if (self.base_sequence == std.math.maxInt(JournalSequence)) return error.SequenceOverflow;
            return self.base_sequence + 1;
        }
        const latest = self.events.items[self.events.items.len - 1].sequence;
        if (latest == std.math.maxInt(JournalSequence)) return error.SequenceOverflow;
        return latest + 1;
    }

    fn hasIdempotencyKey(self: *const InMemoryJournalStore, key: []const u8) bool {
        if (key.len == 0) return false;
        for (self.events.items) |event| {
            if (std.mem.eql(u8, event.idempotency_key, key)) return true;
        }
        return false;
    }

    fn appendAdapter(context: *anyopaque, request: JournalAppend) JournalStoreAppendError!JournalSequence {
        const self: *InMemoryJournalStore = @ptrCast(@alignCast(context));
        return self.append(request);
    }

    fn readAllAdapter(context: *anyopaque, allocator: Allocator) JournalStoreReadError!JournalEventBatch {
        const self: *InMemoryJournalStore = @ptrCast(@alignCast(context));
        return self.readAll(allocator);
    }

    fn readFromSequenceAdapter(context: *anyopaque, allocator: Allocator, sequence: JournalSequence) JournalStoreReadError!JournalEventBatch {
        const self: *InMemoryJournalStore = @ptrCast(@alignCast(context));
        return self.readFromSequence(allocator, sequence);
    }

    fn latestStateAdapter(context: *anyopaque, allocator: Allocator) JournalStoreReplayError!WorkflowReplayState {
        const self: *InMemoryJournalStore = @ptrCast(@alignCast(context));
        return self.latestState(allocator);
    }

    fn resetAdapter(context: *anyopaque) void {
        const self: *InMemoryJournalStore = @ptrCast(@alignCast(context));
        self.reset();
    }
};

const in_memory_vtable: JournalStore.VTable = .{
    .append = InMemoryJournalStore.appendAdapter,
    .read_all = InMemoryJournalStore.readAllAdapter,
    .read_from_sequence = InMemoryJournalStore.readFromSequenceAdapter,
    .latest_state = InMemoryJournalStore.latestStateAdapter,
    .reset = InMemoryJournalStore.resetAdapter,
};

pub const WorkflowCompletedRetentionPolicy = enum {
    keep_all,
    archive_then_compact_completed,
    checkpoint_only_completed,
};

pub const WorkflowRetentionPolicy = struct {
    completed: WorkflowCompletedRetentionPolicy = .keep_all,
};

pub const WorkflowSnapshotFrequency = struct {
    every_events: ?JournalSequence = null,

    pub fn shouldSnapshot(self: WorkflowSnapshotFrequency, last_sequence: JournalSequence, base_sequence: JournalSequence) bool {
        const every_events = self.every_events orelse return false;
        if (every_events == 0) return false;
        if (last_sequence <= base_sequence) return false;
        return last_sequence - base_sequence >= every_events;
    }
};

pub const FileJournalStoreOptions = struct {
    fsync_policy: JournalFsyncPolicy = .never,
    segment_first_sequence: JournalSequence = 1,
    lock_name: []const u8 = "workflow.lock",
    owner_id: []const u8 = "zigeffect-local",
    max_segment_bytes: usize = 16 * 1024 * 1024,
    max_in_memory_events: ?usize = null,
    snapshot_frequency: WorkflowSnapshotFrequency = .{},
    retention_policy: WorkflowRetentionPolicy = .{},
};

pub const WorkflowSnapshotPublication = struct {
    last_sequence: JournalSequence,
    checkpoint_name: []const u8,
    commit_name: []const u8,
    archive_name: ?[]const u8 = null,

    pub fn deinit(self: *const WorkflowSnapshotPublication, allocator: Allocator) void {
        allocator.free(self.checkpoint_name);
        allocator.free(self.commit_name);
        if (self.archive_name) |name| allocator.free(name);
    }
};

pub const WorkflowArchiveExport = struct {
    archive_name: []const u8,
    first_sequence: JournalSequence,
    last_sequence: JournalSequence,
    event_count: usize,
    byte_count: usize,

    pub fn deinit(self: *const WorkflowArchiveExport, allocator: Allocator) void {
        allocator.free(self.archive_name);
    }
};

pub const WorkflowCompactionOptions = struct {
    export_archive: bool = true,
};

pub const WorkflowCompactionResult = struct {
    compacted: bool,
    last_sequence: ?JournalSequence = null,
    checkpoint_name: ?[]const u8 = null,
    commit_name: ?[]const u8 = null,
    archive_name: ?[]const u8 = null,
    archived_event_count: usize = 0,

    pub fn deinit(self: *const WorkflowCompactionResult, allocator: Allocator) void {
        if (self.checkpoint_name) |name| allocator.free(name);
        if (self.commit_name) |name| allocator.free(name);
        if (self.archive_name) |name| allocator.free(name);
    }
};

pub const FileJournalStore = struct {
    allocator: Allocator,
    io: std.Io,
    dir: *std.Io.Dir,
    options: FileJournalStoreOptions,
    segment_name: []const u8,
    memory: InMemoryJournalStore,
    base_state: ?WorkflowReplayState = null,
    lock_acquired: bool = false,
    sync_count: u64 = 0,
    recovered_partial_bytes: u64 = 0,
    last_corruption_report: ?JournalCorruptionReport = null,

    pub fn open(allocator: Allocator, io: std.Io, dir: *std.Io.Dir, options: FileJournalStoreOptions) !FileJournalStore {
        var store = try FileJournalStore.init(allocator, io, dir, options);
        errdefer store.deinit();

        try store.acquireLock();
        try store.recover();

        return store;
    }

    pub fn init(allocator: Allocator, io: std.Io, dir: *std.Io.Dir, options: FileJournalStoreOptions) Allocator.Error!FileJournalStore {
        return .{
            .allocator = allocator,
            .io = io,
            .dir = dir,
            .options = options,
            .segment_name = try segmentFileName(allocator, options.segment_first_sequence),
            .memory = InMemoryJournalStore.initBounded(allocator, .{ .max_events = options.max_in_memory_events }),
        };
    }

    pub fn deinit(self: *FileJournalStore) void {
        if (self.lock_acquired) {
            self.dir.deleteFile(self.io, self.options.lock_name) catch {};
            self.lock_acquired = false;
        }
        if (self.base_state) |*state| {
            state.deinit();
            self.base_state = null;
        }
        self.memory.deinit();
        self.allocator.free(self.segment_name);
    }

    pub fn asJournalStore(self: *FileJournalStore) JournalStore {
        return .{
            .context = self,
            .vtable = &file_vtable,
        };
    }

    pub fn append(self: *FileJournalStore, request: JournalAppend) JournalStoreAppendError!JournalSequence {
        try self.memory.validateAppend(request);

        const row = try journal.formatWorkflowEventJson(self.allocator, request.event);
        defer self.allocator.free(row);

        var file = try self.dir.openFile(self.io, self.segment_name, .{ .mode = .read_write });
        defer file.close(self.io);
        const offset = try file.length(self.io);
        try file.writePositionalAll(self.io, row, offset);
        try file.writePositionalAll(self.io, "\n", offset + row.len);
        try self.syncFile(&file, .after_append);

        return self.memory.append(request);
    }

    pub fn readAll(self: *const FileJournalStore, allocator: Allocator) JournalStoreReadError!JournalEventBatch {
        return self.memory.readAll(allocator);
    }

    pub fn readFromSequence(self: *const FileJournalStore, allocator: Allocator, sequence: JournalSequence) JournalStoreReadError!JournalEventBatch {
        return self.memory.readFromSequence(allocator, sequence);
    }

    pub fn latestState(self: *const FileJournalStore, allocator: Allocator) JournalStoreReplayError!WorkflowReplayState {
        if (self.base_state) |*base| {
            var state = try base.clone(allocator);
            errdefer state.deinit();
            for (self.memory.events.items) |event| {
                try state.apply(event);
            }
            return state;
        }
        return self.memory.latestState(allocator);
    }

    pub fn reset(self: *FileJournalStore) void {
        if (self.base_state) |*state| {
            state.deinit();
            self.base_state = null;
        }
        self.memory.reset();
        const file = self.dir.createFile(self.io, self.segment_name, .{ .truncate = true }) catch return;
        file.close(self.io);
    }

    pub fn writeReplaySnapshot(self: *FileJournalStore, archive_name: ?[]const u8) !WorkflowSnapshotPublication {
        var state = try self.latestState(self.allocator);
        defer state.deinit();

        const checkpoint_name = try checkpointFileName(self.allocator, state.last_sequence);
        errdefer self.allocator.free(checkpoint_name);
        const commit_name = try snapshotCommitFileName(self.allocator, state.last_sequence);
        errdefer self.allocator.free(commit_name);
        const owned_archive_name = if (archive_name) |name| try self.allocator.dupe(u8, name) else null;
        errdefer if (owned_archive_name) |name| self.allocator.free(name);

        const checkpoint_json = try formatWorkflowCheckpointJson(self.allocator, &state);
        defer self.allocator.free(checkpoint_json);
        try self.writeAtomicFile(checkpoint_name, checkpoint_json);

        const commit_json = try formatWorkflowSnapshotCommitJson(self.allocator, .{
            .last_sequence = state.last_sequence,
            .checkpoint_name = checkpoint_name,
            .segment_name = self.segment_name,
            .archive_name = owned_archive_name,
        });
        defer self.allocator.free(commit_json);
        try self.writeAtomicFile(commit_name, commit_json);

        return .{
            .last_sequence = state.last_sequence,
            .checkpoint_name = checkpoint_name,
            .commit_name = commit_name,
            .archive_name = owned_archive_name,
        };
    }

    pub fn exportArchive(self: *FileJournalStore, first_sequence: JournalSequence, last_sequence: JournalSequence) !WorkflowArchiveExport {
        const archive_name = try archiveFileName(self.allocator, first_sequence, last_sequence);
        errdefer self.allocator.free(archive_name);

        var output = std.ArrayList(u8).empty;
        defer output.deinit(self.allocator);

        var event_count: usize = 0;
        for (self.memory.events.items) |event| {
            if (event.sequence < first_sequence or event.sequence > last_sequence) continue;
            const row = try journal.formatWorkflowEventJson(self.allocator, event);
            defer self.allocator.free(row);
            try output.appendSlice(self.allocator, row);
            try output.append(self.allocator, '\n');
            event_count += 1;
        }

        try self.writeAtomicFile(archive_name, output.items);

        return .{
            .archive_name = archive_name,
            .first_sequence = first_sequence,
            .last_sequence = last_sequence,
            .event_count = event_count,
            .byte_count = output.items.len,
        };
    }

    pub fn compactCompleted(self: *FileJournalStore, options: WorkflowCompactionOptions) !WorkflowCompactionResult {
        var state = try self.latestState(self.allocator);
        defer state.deinit();

        if (!replay.workflowStatusIsTerminal(state.workflow_status)) {
            return .{ .compacted = false };
        }

        var exported_archive: ?WorkflowArchiveExport = null;
        errdefer if (exported_archive) |*exported| exported.deinit(self.allocator);
        var archived_event_count: usize = 0;
        if (options.export_archive) {
            const first_sequence = self.archiveFirstSequence();
            exported_archive = try self.exportArchive(first_sequence, state.last_sequence);
            archived_event_count = exported_archive.?.event_count;
        }

        const archive_name_for_commit = if (exported_archive) |exported| exported.archive_name else null;
        var publication = try self.writeReplaySnapshot(archive_name_for_commit);
        errdefer publication.deinit(self.allocator);

        if (exported_archive) |*exported| {
            exported.deinit(self.allocator);
            exported_archive = null;
        }

        try self.truncateActiveSegment();

        var base_state = try state.clone(self.allocator);
        errdefer base_state.deinit();
        if (self.base_state) |*old_state| {
            old_state.deinit();
        }
        self.base_state = base_state;
        self.memory.resetFromSequence(state.last_sequence);

        return .{
            .compacted = true,
            .last_sequence = state.last_sequence,
            .checkpoint_name = publication.checkpoint_name,
            .commit_name = publication.commit_name,
            .archive_name = publication.archive_name,
            .archived_event_count = archived_event_count,
        };
    }

    pub fn applyRetentionPolicy(self: *FileJournalStore) !WorkflowCompactionResult {
        return switch (self.options.retention_policy.completed) {
            .keep_all => .{ .compacted = false },
            .archive_then_compact_completed => try self.compactCompleted(.{ .export_archive = true }),
            .checkpoint_only_completed => try self.compactCompleted(.{ .export_archive = false }),
        };
    }

    pub fn snapshotDue(self: *const FileJournalStore) bool {
        return self.options.snapshot_frequency.shouldSnapshot(self.latestSequence(), self.baseSequence());
    }

    pub fn writeReplaySnapshotIfDue(self: *FileJournalStore) !?WorkflowSnapshotPublication {
        if (!self.snapshotDue()) return null;

        var publication = try self.writeReplaySnapshot(null);
        errdefer publication.deinit(self.allocator);

        var state = try self.latestState(self.allocator);
        errdefer state.deinit();
        if (self.base_state) |*old_state| {
            old_state.deinit();
        }
        self.base_state = state;
        self.memory.resetFromSequence(state.last_sequence);

        return publication;
    }

    pub fn syncCount(self: *const FileJournalStore) u64 {
        return self.sync_count;
    }

    pub fn recoveredPartialBytes(self: *const FileJournalStore) u64 {
        return self.recovered_partial_bytes;
    }

    pub fn lastCorruption(self: *const FileJournalStore) ?JournalCorruptionReport {
        return self.last_corruption_report;
    }

    pub fn acquireLock(self: *FileJournalStore) !void {
        if (self.lock_acquired) return;
        const file = self.dir.createFile(self.io, self.options.lock_name, .{ .exclusive = true }) catch |err| switch (err) {
            error.PathAlreadyExists => return error.JournalStoreLocked,
            else => return err,
        };
        defer file.close(self.io);
        try file.writeStreamingAll(self.io, self.options.owner_id);
        self.lock_acquired = true;
    }

    pub fn recover(self: *FileJournalStore) !void {
        try self.recoverLatestCommittedSnapshot();

        const file = self.dir.openFile(self.io, self.segment_name, .{ .mode = .read_write }) catch |err| switch (err) {
            error.FileNotFound => {
                const created = try self.dir.createFile(self.io, self.segment_name, .{ .read = true });
                created.close(self.io);
                return;
            },
            else => return err,
        };
        defer file.close(self.io);

        const content = try self.dir.readFileAlloc(
            self.io,
            self.segment_name,
            self.allocator,
            std.Io.Limit.limited(self.options.max_segment_bytes),
        );
        defer self.allocator.free(content);

        var line_start: usize = 0;
        var last_complete_offset: usize = 0;
        while (std.mem.indexOfScalarPos(u8, content, line_start, '\n')) |newline_index| {
            const line = content[line_start..newline_index];
            if (line.len != 0) {
                const event = journal.parseWorkflowEventJson(self.allocator, line) catch |err| {
                    if (err == error.FutureWorkflowEventSchemaVersion) {
                        return error.JournalRequiresNewerRuntime;
                    }
                    self.recordCorruption(line_start, corruptionReasonFromError(err));
                    return error.CorruptJournal;
                };
                defer journal.deinitWorkflowEventStrings(self.allocator, event);

                if (event.sequence <= self.baseSequence()) {
                    line_start = newline_index + 1;
                    last_complete_offset = line_start;
                    continue;
                }

                _ = self.memory.append(.{ .event = event }) catch |err| {
                    self.recordCorruption(line_start, corruptionReasonFromError(err));
                    return error.CorruptJournal;
                };
            }
            line_start = newline_index + 1;
            last_complete_offset = line_start;
        }

        if (last_complete_offset < content.len) {
            self.recovered_partial_bytes += content.len - last_complete_offset;
            try file.setLength(self.io, last_complete_offset);
            try self.syncFile(&file, .after_recovery);
        }
    }

    fn writeAtomicFile(self: *FileJournalStore, name: []const u8, content: []const u8) !void {
        var file = try self.dir.createFileAtomic(self.io, name, .{ .replace = true });
        defer file.deinit(self.io);
        try file.file.writeStreamingAll(self.io, content);
        try file.replace(self.io);
    }

    fn truncateActiveSegment(self: *FileJournalStore) !void {
        const file = try self.dir.createFile(self.io, self.segment_name, .{ .truncate = true });
        file.close(self.io);
    }

    fn archiveFirstSequence(self: *const FileJournalStore) JournalSequence {
        if (self.base_state) |state| {
            if (state.last_sequence == std.math.maxInt(JournalSequence)) return state.last_sequence;
            return state.last_sequence + 1;
        }
        return self.options.segment_first_sequence;
    }

    fn baseSequence(self: *const FileJournalStore) JournalSequence {
        if (self.base_state) |state| return state.last_sequence;
        return 0;
    }

    fn latestSequence(self: *const FileJournalStore) JournalSequence {
        if (self.memory.events.items.len != 0) {
            return self.memory.events.items[self.memory.events.items.len - 1].sequence;
        }
        return self.baseSequence();
    }

    fn recoverLatestCommittedSnapshot(self: *FileJournalStore) !void {
        const latest_sequence = try self.latestSnapshotCommitSequence() orelse return;
        const commit_name = try snapshotCommitFileName(self.allocator, latest_sequence);
        defer self.allocator.free(commit_name);

        const commit_content = self.dir.readFileAlloc(
            self.io,
            commit_name,
            self.allocator,
            std.Io.Limit.limited(16 * 1024),
        ) catch return;
        defer self.allocator.free(commit_content);

        var commit = parseWorkflowSnapshotCommitJson(self.allocator, commit_content) catch return;
        defer commit.deinit();

        if (!std.mem.eql(u8, commit.segment_name, self.segment_name)) return;

        const checkpoint_content = self.dir.readFileAlloc(
            self.io,
            commit.checkpoint_name,
            self.allocator,
            std.Io.Limit.limited(self.options.max_segment_bytes),
        ) catch return;
        defer self.allocator.free(checkpoint_content);

        var state = parseWorkflowCheckpointJson(self.allocator, checkpoint_content) catch return;
        errdefer state.deinit();
        if (state.last_sequence != commit.last_sequence) {
            state.deinit();
            return;
        }

        if (self.base_state) |*old_state| {
            old_state.deinit();
        }
        self.base_state = state;
        self.memory.resetFromSequence(state.last_sequence);
    }

    fn latestSnapshotCommitSequence(self: *FileJournalStore) !?JournalSequence {
        var iterator = self.dir.iterate();
        var latest: ?JournalSequence = null;
        while (try iterator.next(self.io)) |entry| {
            const sequence = snapshotCommitSequenceFromFileName(entry.name) orelse continue;
            if (latest == null or sequence > latest.?) {
                latest = sequence;
            }
        }
        return latest;
    }

    fn recordCorruption(self: *FileJournalStore, offset: usize, reason: JournalCorruptionReason) void {
        self.last_corruption_report = .{
            .segment_name = self.segment_name,
            .offset = @as(u64, @intCast(offset)),
            .reason = reason,
        };
    }

    fn syncFile(self: *FileJournalStore, file: *const std.Io.File, trigger: JournalFsyncPolicy) !void {
        const should_sync = switch (self.options.fsync_policy) {
            .never => false,
            .always => true,
            .after_append => trigger == .after_append,
            .after_recovery => trigger == .after_recovery,
        };
        if (should_sync) {
            try file.sync(self.io);
            self.sync_count += 1;
        }
    }

    fn appendAdapter(context: *anyopaque, request: JournalAppend) JournalStoreAppendError!JournalSequence {
        const self: *FileJournalStore = @ptrCast(@alignCast(context));
        return self.append(request);
    }

    fn readAllAdapter(context: *anyopaque, allocator: Allocator) JournalStoreReadError!JournalEventBatch {
        const self: *FileJournalStore = @ptrCast(@alignCast(context));
        return self.readAll(allocator);
    }

    fn readFromSequenceAdapter(context: *anyopaque, allocator: Allocator, sequence: JournalSequence) JournalStoreReadError!JournalEventBatch {
        const self: *FileJournalStore = @ptrCast(@alignCast(context));
        return self.readFromSequence(allocator, sequence);
    }

    fn latestStateAdapter(context: *anyopaque, allocator: Allocator) JournalStoreReplayError!WorkflowReplayState {
        const self: *FileJournalStore = @ptrCast(@alignCast(context));
        return self.latestState(allocator);
    }

    fn resetAdapter(context: *anyopaque) void {
        const self: *FileJournalStore = @ptrCast(@alignCast(context));
        self.reset();
    }
};

fn corruptionReasonFromError(err: anyerror) JournalCorruptionReason {
    return switch (err) {
        error.InvalidWorkflowEventSchema,
        error.InvalidWorkflowEventSchemaVersion,
        => .invalid_schema,
        error.UnknownWorkflowEventKind => .unknown_kind,
        error.SequenceConflict,
        error.SequenceOverflow,
        => .sequence_conflict,
        error.DuplicateEvent => .duplicate_event,
        else => .invalid_json,
    };
}

fn snapshotCommitSequenceFromFileName(name: []const u8) ?JournalSequence {
    const prefix = "workflow-snapshot-commit-";
    const suffix = ".json";
    if (!std.mem.startsWith(u8, name, prefix)) return null;
    if (!std.mem.endsWith(u8, name, suffix)) return null;
    const digits = name[prefix.len .. name.len - suffix.len];
    if (digits.len != 16) return null;
    return std.fmt.parseInt(JournalSequence, digits, 10) catch null;
}

const file_vtable: JournalStore.VTable = .{
    .append = FileJournalStore.appendAdapter,
    .read_all = FileJournalStore.readAllAdapter,
    .read_from_sequence = FileJournalStore.readFromSequenceAdapter,
    .latest_state = FileJournalStore.latestStateAdapter,
    .reset = FileJournalStore.resetAdapter,
};
