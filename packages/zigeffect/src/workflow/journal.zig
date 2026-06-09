const std = @import("std");

pub const workflow_journal_event_schema = "zigeffect.workflow.journal-event.v1";
pub const workflow_journal_event_schema_version: u32 = 1;

pub const WorkflowId = u64;
pub const ExecutionId = u64;
pub const ActivityId = u64;
pub const TimerId = u64;
pub const DeferredId = u64;
pub const QueueId = u64;
pub const JournalSequence = u64;

pub const WorkflowEventKind = enum {
    workflow_started,
    workflow_suspended,
    workflow_resumed,
    workflow_completed,
    workflow_failed,
    workflow_interrupted,
    workflow_cancelled,
    activity_scheduled,
    activity_started,
    activity_completed,
    activity_failed,
    timer_scheduled,
    timer_fired,
    timer_cancelled,
    deferred_created,
    deferred_awaited,
    deferred_completed,
    deferred_failed,
    deferred_cancelled,
    queue_offered,
    queue_claimed,
    queue_completed,
    queue_failed,
    queue_acked,
    signal_received,
    signal_consumed,
};

pub fn workflowEventKindName(kind: WorkflowEventKind) []const u8 {
    return switch (kind) {
        .workflow_started => "workflow_started",
        .workflow_suspended => "workflow_suspended",
        .workflow_resumed => "workflow_resumed",
        .workflow_completed => "workflow_completed",
        .workflow_failed => "workflow_failed",
        .workflow_interrupted => "workflow_interrupted",
        .workflow_cancelled => "workflow_cancelled",
        .activity_scheduled => "activity_scheduled",
        .activity_started => "activity_started",
        .activity_completed => "activity_completed",
        .activity_failed => "activity_failed",
        .timer_scheduled => "timer_scheduled",
        .timer_fired => "timer_fired",
        .timer_cancelled => "timer_cancelled",
        .deferred_created => "deferred_created",
        .deferred_awaited => "deferred_awaited",
        .deferred_completed => "deferred_completed",
        .deferred_failed => "deferred_failed",
        .deferred_cancelled => "deferred_cancelled",
        .queue_offered => "queue_offered",
        .queue_claimed => "queue_claimed",
        .queue_completed => "queue_completed",
        .queue_failed => "queue_failed",
        .queue_acked => "queue_acked",
        .signal_received => "signal_received",
        .signal_consumed => "signal_consumed",
    };
}

pub const WorkflowEvent = struct {
    sequence: JournalSequence,
    kind: WorkflowEventKind,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    parent_sequence: ?JournalSequence = null,
    activity_id: ?ActivityId = null,
    timer_id: ?TimerId = null,
    deferred_id: ?DeferredId = null,
    queue_id: ?QueueId = null,
    name: []const u8 = "",
    status: []const u8 = "",
    redacted_detail: []const u8 = "",
    idempotency_key: []const u8 = "",
};

fn cloneSlice(allocator: std.mem.Allocator, value: []const u8) std.mem.Allocator.Error![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

pub fn cloneWorkflowEvent(allocator: std.mem.Allocator, event: WorkflowEvent) std.mem.Allocator.Error!WorkflowEvent {
    var owned = event;
    owned.name = try cloneSlice(allocator, event.name);
    errdefer if (owned.name.len > 0) allocator.free(owned.name);
    owned.status = try cloneSlice(allocator, event.status);
    errdefer if (owned.status.len > 0) allocator.free(owned.status);
    owned.redacted_detail = try cloneSlice(allocator, event.redacted_detail);
    errdefer if (owned.redacted_detail.len > 0) allocator.free(owned.redacted_detail);
    owned.idempotency_key = try cloneSlice(allocator, event.idempotency_key);
    errdefer if (owned.idempotency_key.len > 0) allocator.free(owned.idempotency_key);
    return owned;
}

pub fn deinitWorkflowEventStrings(allocator: std.mem.Allocator, event: WorkflowEvent) void {
    if (event.name.len > 0) allocator.free(event.name);
    if (event.status.len > 0) allocator.free(event.status);
    if (event.redacted_detail.len > 0) allocator.free(event.redacted_detail);
    if (event.idempotency_key.len > 0) allocator.free(event.idempotency_key);
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
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

fn appendOptionalJsonU64(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: ?u64) !void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendOptionalTextU64(output: *std.ArrayList(u8), allocator: std.mem.Allocator, label: []const u8, value: ?u64) !void {
    if (value) |number| {
        try output.print(allocator, "{s}: {d}\n", .{ label, number });
    } else {
        try output.print(allocator, "{s}: null\n", .{label});
    }
}

pub fn formatWorkflowEventJson(allocator: std.mem.Allocator, event: WorkflowEvent) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, workflow_journal_event_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{workflow_journal_event_schema_version});
    try output.print(allocator, ",\"sequence\":{d}", .{event.sequence});
    try output.appendSlice(allocator, ",\"kind\":");
    try appendJsonString(&output, allocator, workflowEventKindName(event.kind));
    try output.print(allocator, ",\"workflow_id\":{d}", .{event.workflow_id});
    try output.print(allocator, ",\"execution_id\":{d}", .{event.execution_id});
    try output.appendSlice(allocator, ",\"parent_sequence\":");
    try appendOptionalJsonU64(&output, allocator, event.parent_sequence);
    try output.appendSlice(allocator, ",\"activity_id\":");
    try appendOptionalJsonU64(&output, allocator, event.activity_id);
    try output.appendSlice(allocator, ",\"timer_id\":");
    try appendOptionalJsonU64(&output, allocator, event.timer_id);
    try output.appendSlice(allocator, ",\"deferred_id\":");
    try appendOptionalJsonU64(&output, allocator, event.deferred_id);
    try output.appendSlice(allocator, ",\"queue_id\":");
    try appendOptionalJsonU64(&output, allocator, event.queue_id);
    try output.appendSlice(allocator, ",\"name\":");
    try appendJsonString(&output, allocator, event.name);
    try output.appendSlice(allocator, ",\"status\":");
    try appendJsonString(&output, allocator, event.status);
    try output.appendSlice(allocator, ",\"redacted_detail\":");
    try appendJsonString(&output, allocator, event.redacted_detail);
    try output.appendSlice(allocator, ",\"idempotency_key\":");
    try appendJsonString(&output, allocator, event.idempotency_key);
    try output.append(allocator, '}');

    return output.toOwnedSlice(allocator);
}

pub fn formatWorkflowEventText(allocator: std.mem.Allocator, event: WorkflowEvent) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect workflow journal event\n");
    try output.print(allocator, "schema: {s}\n", .{workflow_journal_event_schema});
    try output.print(allocator, "schema version: {d}\n", .{workflow_journal_event_schema_version});
    try output.print(allocator, "sequence: {d}\n", .{event.sequence});
    try output.print(allocator, "kind: {s}\n", .{workflowEventKindName(event.kind)});
    try output.print(allocator, "workflow_id: {d}\n", .{event.workflow_id});
    try output.print(allocator, "execution_id: {d}\n", .{event.execution_id});
    try appendOptionalTextU64(&output, allocator, "parent_sequence", event.parent_sequence);
    try appendOptionalTextU64(&output, allocator, "activity_id", event.activity_id);
    try appendOptionalTextU64(&output, allocator, "timer_id", event.timer_id);
    try appendOptionalTextU64(&output, allocator, "deferred_id", event.deferred_id);
    try appendOptionalTextU64(&output, allocator, "queue_id", event.queue_id);
    try output.print(allocator, "name: {s}\n", .{event.name});
    try output.print(allocator, "status: {s}\n", .{event.status});
    try output.print(allocator, "redacted_detail: {s}\n", .{event.redacted_detail});
    try output.print(allocator, "idempotency_key: {s}\n", .{event.idempotency_key});

    return output.toOwnedSlice(allocator);
}
