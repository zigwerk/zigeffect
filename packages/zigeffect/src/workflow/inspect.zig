const std = @import("std");
const journal_mod = @import("journal.zig");
const replay_mod = @import("replay.zig");

pub const Allocator = std.mem.Allocator;
pub const ExecutionId = journal_mod.ExecutionId;
pub const JournalSequence = journal_mod.JournalSequence;
pub const WorkflowEvent = journal_mod.WorkflowEvent;
pub const WorkflowId = journal_mod.WorkflowId;

pub const workflow_inspect_schema = "zigeffect.workflow.inspect.v1";
pub const workflow_replay_schema = "zigeffect.workflow.replay.v1";
pub const workflow_list_schema = "zigeffect.workflow.list.v1";
pub const workflow_report_schema_version: u32 = 1;

pub const WorkflowReportError = error{
    EmptyWorkflowJournal,
    AmbiguousWorkflowExecution,
    UnknownWorkflowExecution,
};

pub const WorkflowReportFormat = enum {
    text,
    json,
};

pub const WorkflowExecutionKey = struct {
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
};

pub const WorkflowExecutionSummary = struct {
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    name: []const u8 = "",
    status: []const u8 = "",
    first_sequence: JournalSequence,
    last_sequence: JournalSequence,
    event_count: usize,
};

pub const WorkflowPendingSummary = struct {
    activities: []replay_mod.ActivityState = &.{},
    timers: []replay_mod.TimerState = &.{},
    deferreds: []replay_mod.DeferredState = &.{},
    queues: []replay_mod.QueueState = &.{},

    pub fn deinit(self: *WorkflowPendingSummary, allocator: Allocator) void {
        for (self.activities) |activity| {
            freeName(allocator, activity.name);
        }
        allocator.free(self.activities);
        for (self.timers) |timer| {
            freeName(allocator, timer.name);
        }
        allocator.free(self.timers);
        for (self.deferreds) |deferred| {
            freeName(allocator, deferred.name);
        }
        allocator.free(self.deferreds);
        for (self.queues) |queue| {
            freeName(allocator, queue.name);
        }
        allocator.free(self.queues);
    }
};

pub const WorkflowInspectionReport = struct {
    allocator: Allocator,
    schema: []const u8,
    schema_version: u32 = workflow_report_schema_version,
    event_count: usize = 0,
    first_sequence: ?JournalSequence = null,
    last_sequence: ?JournalSequence = null,
    executions: []WorkflowExecutionSummary = &.{},
    selected: ?WorkflowExecutionKey = null,
    state: ?replay_mod.WorkflowReplayState = null,
    pending: WorkflowPendingSummary = .{},
    last_failure_detail: []const u8 = "",

    pub fn deinit(self: *WorkflowInspectionReport) void {
        for (self.executions) |summary| {
            freeName(self.allocator, summary.name);
            freeName(self.allocator, summary.status);
        }
        self.allocator.free(self.executions);
        if (self.state) |*state| state.deinit();
        self.pending.deinit(self.allocator);
        freeName(self.allocator, self.last_failure_detail);
    }
};

pub fn listExecutions(
    allocator: Allocator,
    events: []const WorkflowEvent,
) !WorkflowInspectionReport {
    var summaries = std.ArrayList(WorkflowExecutionSummary).empty;
    errdefer deinitSummaries(allocator, summaries.items);

    for (events) |event| {
        const index = findSummaryIndex(summaries.items, event.workflow_id, event.execution_id) orelse blk: {
            try summaries.append(allocator, .{
                .workflow_id = event.workflow_id,
                .execution_id = event.execution_id,
                .first_sequence = event.sequence,
                .last_sequence = event.sequence,
                .event_count = 0,
            });
            break :blk summaries.items.len - 1;
        };
        try updateSummary(allocator, &summaries.items[index], event);
    }

    return .{
        .allocator = allocator,
        .schema = workflow_list_schema,
        .event_count = events.len,
        .first_sequence = firstSequence(events),
        .last_sequence = lastSequence(events),
        .executions = try summaries.toOwnedSlice(allocator),
    };
}

pub fn inspectExecution(
    allocator: Allocator,
    events: []const WorkflowEvent,
    selection: ?WorkflowExecutionKey,
) !WorkflowInspectionReport {
    var report = try listExecutions(allocator, events);
    errdefer report.deinit();
    report.schema = workflow_replay_schema;

    const selected = try selectExecution(report.executions, selection);
    report.selected = selected;

    var filtered = std.ArrayList(WorkflowEvent).empty;
    defer filtered.deinit(allocator);
    for (events) |event| {
        if (event.workflow_id == selected.workflow_id and event.execution_id == selected.execution_id) {
            try filtered.append(allocator, event);
        }
    }

    var state = try replay_mod.WorkflowReplayState.fold(allocator, filtered.items);
    errdefer state.deinit();

    report.pending = try pendingSummaryFromState(allocator, &state);
    errdefer report.pending.deinit(allocator);
    report.last_failure_detail = try findLastFailureDetail(allocator, filtered.items);
    report.state = state;

    return report;
}

pub fn formatReplayReportText(
    allocator: Allocator,
    report: *const WorkflowInspectionReport,
) ![]const u8 {
    const selected = report.selected orelse return error.UnknownWorkflowExecution;
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect workflow replay\n");
    try output.print(allocator, "schema: {s}\n", .{report.schema});
    try output.print(allocator, "schema_version: {d}\n", .{report.schema_version});
    try output.print(allocator, "event_count: {d}\n", .{report.event_count});
    try output.print(allocator, "workflow_id: {d}\n", .{selected.workflow_id});
    try output.print(allocator, "execution_id: {d}\n", .{selected.execution_id});
    try output.print(allocator, "status: {s}\n", .{replayStatusText(report)});
    try output.print(allocator, "pending_timers: {d}\n", .{report.pending.timers.len});
    try output.print(allocator, "pending_deferreds: {d}\n", .{report.pending.deferreds.len});
    try output.print(allocator, "pending_queues: {d}\n", .{report.pending.queues.len});
    try output.print(allocator, "pending_activities: {d}\n", .{report.pending.activities.len});
    try output.print(allocator, "last_failure: {s}\n", .{report.last_failure_detail});

    return output.toOwnedSlice(allocator);
}

pub fn formatReplayReportJson(
    allocator: Allocator,
    report: *const WorkflowInspectionReport,
) ![]const u8 {
    const selected = report.selected orelse return error.UnknownWorkflowExecution;
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, workflow_replay_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{workflow_report_schema_version});
    try output.print(allocator, ",\"event_count\":{d}", .{report.event_count});
    try output.appendSlice(allocator, ",\"first_sequence\":");
    try appendOptionalJsonU64(&output, allocator, report.first_sequence);
    try output.appendSlice(allocator, ",\"last_sequence\":");
    try appendOptionalJsonU64(&output, allocator, report.last_sequence);
    try output.print(allocator, ",\"workflow_id\":{d}", .{selected.workflow_id});
    try output.print(allocator, ",\"execution_id\":{d}", .{selected.execution_id});
    try output.appendSlice(allocator, ",\"status\":");
    try appendJsonString(&output, allocator, replayStatusText(report));
    try output.print(allocator, ",\"pending_timers\":{d}", .{report.pending.timers.len});
    try output.print(allocator, ",\"pending_deferreds\":{d}", .{report.pending.deferreds.len});
    try output.print(allocator, ",\"pending_queues\":{d}", .{report.pending.queues.len});
    try output.print(allocator, ",\"pending_activities\":{d}", .{report.pending.activities.len});
    try output.appendSlice(allocator, ",\"last_failure_detail\":");
    try appendJsonString(&output, allocator, report.last_failure_detail);
    try output.append(allocator, '}');

    return output.toOwnedSlice(allocator);
}

pub fn formatListReportText(
    allocator: Allocator,
    report: *const WorkflowInspectionReport,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect workflow list\n");
    try output.print(allocator, "schema: {s}\n", .{workflow_list_schema});
    try output.print(allocator, "schema_version: {d}\n", .{workflow_report_schema_version});
    try output.print(allocator, "event_count: {d}\n", .{report.event_count});
    try output.print(allocator, "executions: {d}\n", .{report.executions.len});
    for (report.executions) |summary| {
        try output.print(
            allocator,
            "- workflow_id: {d} execution_id: {d} status: {s} events: {d}\n",
            .{ summary.workflow_id, summary.execution_id, summary.status, summary.event_count },
        );
    }

    return output.toOwnedSlice(allocator);
}

pub fn formatListReportJson(
    allocator: Allocator,
    report: *const WorkflowInspectionReport,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, workflow_list_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{workflow_report_schema_version});
    try output.print(allocator, ",\"event_count\":{d}", .{report.event_count});
    try output.appendSlice(allocator, ",\"executions\":[");
    for (report.executions, 0..) |summary, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.print(
            allocator,
            "{{\"workflow_id\":{d},\"execution_id\":{d},\"first_sequence\":{d},\"last_sequence\":{d},\"event_count\":{d},\"name\":",
            .{ summary.workflow_id, summary.execution_id, summary.first_sequence, summary.last_sequence, summary.event_count },
        );
        try appendJsonString(&output, allocator, summary.name);
        try output.appendSlice(allocator, ",\"status\":");
        try appendJsonString(&output, allocator, summary.status);
        try output.append(allocator, '}');
    }
    try output.appendSlice(allocator, "]}");

    return output.toOwnedSlice(allocator);
}

pub fn formatInspectReportText(
    allocator: Allocator,
    report: *const WorkflowInspectionReport,
    events: []const WorkflowEvent,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect workflow journal inspect\n");
    try output.print(allocator, "schema: {s}\n", .{workflow_inspect_schema});
    try output.print(allocator, "schema_version: {d}\n", .{workflow_report_schema_version});
    try output.print(allocator, "events: {d}\n", .{countSelectedEvents(report, events)});
    for (events) |event| {
        if (!eventMatchesReportSelection(report, event)) continue;
        try output.print(
            allocator,
            "{d} {s} {s} {s}\n",
            .{ event.sequence, journal_mod.workflowEventKindName(event.kind), event.status, event.redacted_detail },
        );
    }

    return output.toOwnedSlice(allocator);
}

pub fn formatInspectReportJson(
    allocator: Allocator,
    report: *const WorkflowInspectionReport,
    events: []const WorkflowEvent,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, workflow_inspect_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{workflow_report_schema_version});
    try output.print(allocator, ",\"event_count\":{d}", .{countSelectedEvents(report, events)});
    if (report.selected) |selected| {
        try output.print(allocator, ",\"workflow_id\":{d},\"execution_id\":{d}", .{ selected.workflow_id, selected.execution_id });
    }
    try output.appendSlice(allocator, ",\"events\":[");
    var emitted: usize = 0;
    for (events) |event| {
        if (!eventMatchesReportSelection(report, event)) continue;
        if (emitted != 0) try output.append(allocator, ',');
        emitted += 1;
        try output.print(
            allocator,
            "{{\"sequence\":{d},\"kind\":",
            .{event.sequence},
        );
        try appendJsonString(&output, allocator, journal_mod.workflowEventKindName(event.kind));
        try output.print(allocator, ",\"workflow_id\":{d},\"execution_id\":{d}", .{ event.workflow_id, event.execution_id });
        try output.appendSlice(allocator, ",\"name\":");
        try appendJsonString(&output, allocator, event.name);
        try output.appendSlice(allocator, ",\"status\":");
        try appendJsonString(&output, allocator, event.status);
        try output.appendSlice(allocator, ",\"redacted_detail\":");
        try appendJsonString(&output, allocator, event.redacted_detail);
        try output.append(allocator, '}');
    }
    try output.appendSlice(allocator, "]}");

    return output.toOwnedSlice(allocator);
}

fn updateSummary(allocator: Allocator, summary: *WorkflowExecutionSummary, event: WorkflowEvent) Allocator.Error!void {
    summary.last_sequence = event.sequence;
    summary.event_count += 1;

    if (event.kind == .workflow_started and event.name.len != 0) {
        try replaceOwnedString(allocator, &summary.name, event.name);
    }
    if (workflowStatusText(event)) |status| {
        try replaceOwnedString(allocator, &summary.status, status);
    }
}

fn replayStatusText(report: *const WorkflowInspectionReport) []const u8 {
    if (report.state) |state| return @tagName(state.workflow_status);
    return "";
}

fn countSelectedEvents(report: *const WorkflowInspectionReport, events: []const WorkflowEvent) usize {
    var count: usize = 0;
    for (events) |event| {
        if (eventMatchesReportSelection(report, event)) count += 1;
    }
    return count;
}

fn eventMatchesReportSelection(report: *const WorkflowInspectionReport, event: WorkflowEvent) bool {
    const selected = report.selected orelse return true;
    return event.workflow_id == selected.workflow_id and event.execution_id == selected.execution_id;
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

fn appendOptionalJsonU64(output: *std.ArrayList(u8), allocator: Allocator, value: ?u64) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn workflowStatusText(event: WorkflowEvent) ?[]const u8 {
    return switch (event.kind) {
        .workflow_started => if (event.status.len != 0) event.status else "running",
        .workflow_suspended => "suspended",
        .workflow_resumed => "running",
        .workflow_completed => "completed",
        .workflow_failed => if (std.mem.eql(u8, event.status, "defect")) "defect" else "failed",
        .workflow_interrupted => "interrupted",
        .workflow_cancelled => "cancelled",
        else => null,
    };
}

fn selectExecution(
    summaries: []const WorkflowExecutionSummary,
    selection: ?WorkflowExecutionKey,
) WorkflowReportError!WorkflowExecutionKey {
    if (summaries.len == 0) return error.EmptyWorkflowJournal;
    if (selection) |key| {
        if (findSummaryIndex(summaries, key.workflow_id, key.execution_id) == null) {
            return error.UnknownWorkflowExecution;
        }
        return key;
    }
    if (summaries.len != 1) return error.AmbiguousWorkflowExecution;
    return .{
        .workflow_id = summaries[0].workflow_id,
        .execution_id = summaries[0].execution_id,
    };
}

fn findSummaryIndex(
    summaries: []const WorkflowExecutionSummary,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
) ?usize {
    for (summaries, 0..) |summary, index| {
        if (summary.workflow_id == workflow_id and summary.execution_id == execution_id) return index;
    }
    return null;
}

fn pendingSummaryFromState(
    allocator: Allocator,
    state: *const replay_mod.WorkflowReplayState,
) Allocator.Error!WorkflowPendingSummary {
    return .{
        .activities = try clonePendingActivities(allocator, state.activities.items),
        .timers = try clonePendingTimers(allocator, state.timers.items),
        .deferreds = try clonePendingDeferreds(allocator, state.deferreds.items),
        .queues = try clonePendingQueues(allocator, state.queues.items),
    };
}

fn clonePendingActivities(
    allocator: Allocator,
    rows: []const replay_mod.ActivityState,
) Allocator.Error![]replay_mod.ActivityState {
    var output = std.ArrayList(replay_mod.ActivityState).empty;
    errdefer deinitActivityRows(allocator, output.items);
    for (rows) |row| {
        if (!isPendingActivity(row.status)) continue;
        var cloned = row;
        cloned.name = try cloneName(allocator, row.name);
        errdefer freeName(allocator, cloned.name);
        try output.append(allocator, cloned);
    }
    return output.toOwnedSlice(allocator);
}

fn clonePendingTimers(
    allocator: Allocator,
    rows: []const replay_mod.TimerState,
) Allocator.Error![]replay_mod.TimerState {
    var output = std.ArrayList(replay_mod.TimerState).empty;
    errdefer deinitTimerRows(allocator, output.items);
    for (rows) |row| {
        if (!isPendingTimer(row.status)) continue;
        var cloned = row;
        cloned.name = try cloneName(allocator, row.name);
        errdefer freeName(allocator, cloned.name);
        try output.append(allocator, cloned);
    }
    return output.toOwnedSlice(allocator);
}

fn clonePendingDeferreds(
    allocator: Allocator,
    rows: []const replay_mod.DeferredState,
) Allocator.Error![]replay_mod.DeferredState {
    var output = std.ArrayList(replay_mod.DeferredState).empty;
    errdefer deinitDeferredRows(allocator, output.items);
    for (rows) |row| {
        if (!isPendingDeferred(row.status)) continue;
        var cloned = row;
        cloned.name = try cloneName(allocator, row.name);
        errdefer freeName(allocator, cloned.name);
        try output.append(allocator, cloned);
    }
    return output.toOwnedSlice(allocator);
}

fn clonePendingQueues(
    allocator: Allocator,
    rows: []const replay_mod.QueueState,
) Allocator.Error![]replay_mod.QueueState {
    var output = std.ArrayList(replay_mod.QueueState).empty;
    errdefer deinitQueueRows(allocator, output.items);
    for (rows) |row| {
        if (!isPendingQueue(row.status)) continue;
        var cloned = row;
        cloned.name = try cloneName(allocator, row.name);
        errdefer freeName(allocator, cloned.name);
        try output.append(allocator, cloned);
    }
    return output.toOwnedSlice(allocator);
}

fn findLastFailureDetail(allocator: Allocator, events: []const WorkflowEvent) Allocator.Error![]const u8 {
    var index = events.len;
    while (index > 0) {
        index -= 1;
        const event = events[index];
        if (!isFailureEvent(event.kind)) continue;
        if (event.redacted_detail.len != 0) return cloneName(allocator, event.redacted_detail);
        if (event.status.len != 0) return cloneName(allocator, event.status);
        return cloneName(allocator, journal_mod.workflowEventKindName(event.kind));
    }
    return "";
}

fn isFailureEvent(kind: journal_mod.WorkflowEventKind) bool {
    return switch (kind) {
        .workflow_failed,
        .workflow_interrupted,
        .workflow_cancelled,
        .activity_failed,
        .activity_timed_out,
        .deferred_failed,
        .deferred_cancelled,
        .queue_failed,
        .timer_cancelled,
        .step_failed,
        => true,
        else => false,
    };
}

fn isPendingActivity(status: replay_mod.ActivityStatus) bool {
    return switch (status) {
        .scheduled,
        .running,
        .retry_ready,
        => true,
        .completed,
        .failed,
        => false,
    };
}

fn isPendingTimer(status: replay_mod.TimerStatus) bool {
    return switch (status) {
        .scheduled => true,
        .fired,
        .cancelled,
        => false,
    };
}

fn isPendingDeferred(status: replay_mod.DeferredStatus) bool {
    return switch (status) {
        .pending => true,
        .completed,
        .failed,
        .cancelled,
        => false,
    };
}

fn isPendingQueue(status: replay_mod.QueueStatus) bool {
    return switch (status) {
        .offered,
        .claimed,
        .retry_ready,
        => true,
        .completed,
        .failed,
        .acked,
        => false,
    };
}

fn firstSequence(events: []const WorkflowEvent) ?JournalSequence {
    if (events.len == 0) return null;
    return events[0].sequence;
}

fn lastSequence(events: []const WorkflowEvent) ?JournalSequence {
    if (events.len == 0) return null;
    return events[events.len - 1].sequence;
}

fn replaceOwnedString(allocator: Allocator, destination: *[]const u8, value: []const u8) Allocator.Error!void {
    const cloned = try cloneName(allocator, value);
    freeName(allocator, destination.*);
    destination.* = cloned;
}

fn cloneName(allocator: Allocator, value: []const u8) Allocator.Error![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

fn freeName(allocator: Allocator, value: []const u8) void {
    if (value.len != 0) allocator.free(value);
}

fn deinitSummaries(allocator: Allocator, summaries: []WorkflowExecutionSummary) void {
    for (summaries) |summary| {
        freeName(allocator, summary.name);
        freeName(allocator, summary.status);
    }
}

fn deinitActivityRows(allocator: Allocator, rows: []replay_mod.ActivityState) void {
    for (rows) |row| freeName(allocator, row.name);
}

fn deinitTimerRows(allocator: Allocator, rows: []replay_mod.TimerState) void {
    for (rows) |row| freeName(allocator, row.name);
}

fn deinitDeferredRows(allocator: Allocator, rows: []replay_mod.DeferredState) void {
    for (rows) |row| freeName(allocator, row.name);
}

fn deinitQueueRows(allocator: Allocator, rows: []replay_mod.QueueState) void {
    for (rows) |row| freeName(allocator, row.name);
}
