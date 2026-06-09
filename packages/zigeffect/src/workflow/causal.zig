const std = @import("std");
const causal_mod = @import("../services/causal.zig");
const journal_mod = @import("journal.zig");

pub const Allocator = std.mem.Allocator;
pub const CausalEvent = causal_mod.CausalEvent;
pub const CausalSnapshot = causal_mod.CausalSnapshot;
pub const WorkflowEvent = journal_mod.WorkflowEvent;

pub fn mapWorkflowEventToCausal(
    allocator: Allocator,
    event: WorkflowEvent,
) Allocator.Error!CausalEvent {
    const kind_name = journal_mod.workflowEventKindName(event.kind);
    const label_source = if (event.name.len != 0) event.name else kind_name;
    const status_source = workflowEventStatus(event);
    return .{
        .kind = .workflow_event_recorded,
        .run_id = event.workflow_id,
        .parent_id = event.parent_sequence,
        .fiber_id = workflowEventFiberId(event),
        .scope_id = event.execution_id,
        .trace_id = event.workflow_id,
        .span_id = event.sequence,
        .label = try cloneText(allocator, label_source),
        .type_name = try std.fmt.allocPrint(allocator, "workflow.{s}", .{kind_name}),
        .status = try cloneText(allocator, status_source),
        .redacted_detail = try cloneText(allocator, event.redacted_detail),
    };
}

pub fn mapWorkflowEventsToCausal(
    allocator: Allocator,
    events: []const WorkflowEvent,
) Allocator.Error!CausalSnapshot {
    var output = std.ArrayList(CausalEvent).empty;
    errdefer {
        for (output.items) |event| deinitMappedEvent(allocator, event);
        output.deinit(allocator);
    }

    for (events) |event| {
        const mapped = try mapWorkflowEventToCausal(allocator, event);
        errdefer deinitMappedEvent(allocator, mapped);
        try output.append(allocator, mapped);
    }

    return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
}

fn workflowEventFiberId(event: WorkflowEvent) ?u64 {
    if (event.activity_id) |id| return id;
    if (event.queue_id) |id| return id;
    if (event.timer_id) |id| return id;
    if (event.deferred_id) |id| return id;
    return null;
}

fn workflowEventStatus(event: WorkflowEvent) []const u8 {
    if (event.status.len != 0) return event.status;
    return switch (event.kind) {
        .workflow_started,
        .workflow_resumed,
        => "running",
        .workflow_suspended => "waiting",
        .workflow_completed => "completed",
        .workflow_failed => "failed",
        .workflow_interrupted => "interrupted",
        .workflow_cancelled => "cancelled",
        .activity_scheduled,
        .timer_scheduled,
        => "scheduled",
        .activity_started,
        .compensation_started,
        => "running",
        .activity_completed,
        .deferred_completed,
        .queue_completed,
        .compensation_completed,
        .step_completed,
        => "completed",
        .activity_retry_scheduled,
        .queue_retry_scheduled,
        => "retry",
        .activity_timed_out => "timed_out",
        .activity_failed,
        .deferred_failed,
        .queue_failed,
        .compensation_failed,
        .step_failed,
        => "failed",
        .timer_fired => "fired",
        .timer_cancelled,
        .deferred_cancelled,
        => "cancelled",
        .deferred_created => "pending",
        .deferred_awaited => "waiting",
        .queue_offered => "offered",
        .queue_claimed => "claimed",
        .queue_acked => "acked",
        .compensation_registered => "registered",
        .step_started => "started",
        .signal_received => "received",
        .signal_consumed => "consumed",
    };
}

fn cloneText(allocator: Allocator, text: []const u8) Allocator.Error![]const u8 {
    if (text.len == 0) return "";
    return allocator.dupe(u8, text);
}

fn deinitMappedEvent(allocator: Allocator, event: CausalEvent) void {
    if (event.label.len != 0) allocator.free(event.label);
    if (event.type_name.len != 0) allocator.free(event.type_name);
    if (event.status.len != 0) allocator.free(event.status);
    if (event.redacted_detail.len != 0) allocator.free(event.redacted_detail);
}
