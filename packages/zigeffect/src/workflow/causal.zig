const std = @import("std");
const causal_mod = @import("../services/causal.zig");
const journal_mod = @import("journal.zig");

pub const Allocator = std.mem.Allocator;
pub const CausalEvent = causal_mod.CausalEvent;
pub const CausalSnapshot = causal_mod.CausalSnapshot;
pub const CausalStore = causal_mod.CausalStore;
pub const WorkflowEvent = journal_mod.WorkflowEvent;

const WorkflowCausalSequenceId = struct {
    sequence: u64,
    causal_id: u64,
};

pub const WorkflowCausalFindingKind = enum {
    workflow_failure,
    workflow_retry_scheduled,
    workflow_suspended,
    workflow_resumed,
};

pub const WorkflowCausalFinding = struct {
    kind: WorkflowCausalFindingKind,
    event_id: u64,
    run_id: ?u64 = null,
    scope_id: ?u64 = null,
    fiber_id: ?u64 = null,
    sequence: ?u64 = null,
    label: []const u8 = "",
    type_name: []const u8 = "",
    redacted_detail: []const u8 = "",
};

pub const WorkflowCausalFindings = struct {
    allocator: Allocator,
    items: []WorkflowCausalFinding,

    pub fn deinit(self: *WorkflowCausalFindings) void {
        for (self.items) |finding| {
            deinitWorkflowCausalFinding(self.allocator, finding);
        }
        self.allocator.free(self.items);
    }
};

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

pub fn buildWorkflowCausalStore(
    allocator: Allocator,
    events: []const WorkflowEvent,
) Allocator.Error!CausalStore {
    var store = CausalStore.init(allocator);
    errdefer store.deinit();

    var sequence_ids = std.ArrayList(WorkflowCausalSequenceId).empty;
    defer sequence_ids.deinit(allocator);

    for (events) |event| {
        var mapped = try mapWorkflowEventToCausal(allocator, event);
        defer deinitMappedEvent(allocator, mapped);

        if (event.parent_sequence) |parent_sequence| {
            mapped.parent_id = findCausalIdForWorkflowSequence(sequence_ids.items, parent_sequence) orelse parent_sequence;
        }

        const causal_id = try store.record(mapped);
        try sequence_ids.append(allocator, .{ .sequence = event.sequence, .causal_id = causal_id });
    }

    return store;
}

pub fn collectWorkflowCausalFindings(
    allocator: Allocator,
    store: *const CausalStore,
) Allocator.Error!WorkflowCausalFindings {
    var output = std.ArrayList(WorkflowCausalFinding).empty;
    errdefer {
        for (output.items) |finding| deinitWorkflowCausalFinding(allocator, finding);
        output.deinit(allocator);
    }

    for (store.events.items) |event| {
        const kind = workflowCausalFindingKind(event) orelse continue;
        const finding = try cloneWorkflowCausalFinding(allocator, .{
            .kind = kind,
            .event_id = event.id,
            .run_id = event.run_id,
            .scope_id = event.scope_id,
            .fiber_id = event.fiber_id,
            .sequence = event.span_id,
            .label = event.label,
            .type_name = event.type_name,
            .redacted_detail = event.redacted_detail,
        });
        errdefer deinitWorkflowCausalFinding(allocator, finding);
        try output.append(allocator, finding);
    }

    return .{ .allocator = allocator, .items = try output.toOwnedSlice(allocator) };
}

pub fn formatWorkflowCausalReport(
    allocator: Allocator,
    events: []const WorkflowEvent,
) Allocator.Error![]const u8 {
    var store = try buildWorkflowCausalStore(allocator, events);
    defer store.deinit();

    const report = try causal_mod.formatCausalReport(allocator, "workflow", &store);
    defer allocator.free(report);

    var findings = try collectWorkflowCausalFindings(allocator, &store);
    defer findings.deinit();

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, report);
    try appendWorkflowCausalFindingsReport(&output, allocator, findings);

    return output.toOwnedSlice(allocator);
}

pub fn formatWorkflowCausalJson(
    allocator: Allocator,
    events: []const WorkflowEvent,
) Allocator.Error![]const u8 {
    var store = try buildWorkflowCausalStore(allocator, events);
    defer store.deinit();

    return causal_mod.formatCausalJson(allocator, &store);
}

pub fn formatWorkflowCausalDot(
    allocator: Allocator,
    events: []const WorkflowEvent,
) Allocator.Error![]const u8 {
    var store = try buildWorkflowCausalStore(allocator, events);
    defer store.deinit();

    return causal_mod.formatCausalDot(allocator, &store);
}

fn findCausalIdForWorkflowSequence(sequence_ids: []const WorkflowCausalSequenceId, sequence: u64) ?u64 {
    for (sequence_ids) |entry| {
        if (entry.sequence == sequence) return entry.causal_id;
    }
    return null;
}

fn workflowCausalFindingKind(event: CausalEvent) ?WorkflowCausalFindingKind {
    if (event.kind != .workflow_event_recorded) return null;
    if (std.mem.eql(u8, event.type_name, "workflow.workflow_suspended")) return .workflow_suspended;
    if (std.mem.eql(u8, event.type_name, "workflow.workflow_resumed")) return .workflow_resumed;
    if (std.mem.endsWith(u8, event.type_name, "_retry_scheduled") or std.mem.eql(u8, event.status, "retry")) {
        return .workflow_retry_scheduled;
    }
    if (std.mem.endsWith(u8, event.type_name, "_failed") or std.mem.eql(u8, event.status, "failed")) {
        return .workflow_failure;
    }
    return null;
}

fn workflowCausalFindingKindName(kind: WorkflowCausalFindingKind) []const u8 {
    return switch (kind) {
        .workflow_failure => "workflow_failure",
        .workflow_retry_scheduled => "workflow_retry_scheduled",
        .workflow_suspended => "workflow_suspended",
        .workflow_resumed => "workflow_resumed",
    };
}

fn cloneWorkflowCausalFinding(
    allocator: Allocator,
    finding: WorkflowCausalFinding,
) Allocator.Error!WorkflowCausalFinding {
    var owned = finding;
    owned.label = try cloneText(allocator, finding.label);
    errdefer if (owned.label.len != 0) allocator.free(owned.label);
    owned.type_name = try cloneText(allocator, finding.type_name);
    errdefer if (owned.type_name.len != 0) allocator.free(owned.type_name);
    owned.redacted_detail = try cloneText(allocator, finding.redacted_detail);
    errdefer if (owned.redacted_detail.len != 0) allocator.free(owned.redacted_detail);
    return owned;
}

fn deinitWorkflowCausalFinding(allocator: Allocator, finding: WorkflowCausalFinding) void {
    if (finding.label.len != 0) allocator.free(finding.label);
    if (finding.type_name.len != 0) allocator.free(finding.type_name);
    if (finding.redacted_detail.len != 0) allocator.free(finding.redacted_detail);
}

fn appendOptionalU64(
    output: *std.ArrayList(u8),
    allocator: Allocator,
    label: []const u8,
    value: ?u64,
) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, " {s}={d}", .{ label, number });
    }
}

fn appendWorkflowCausalFindingsReport(
    output: *std.ArrayList(u8),
    allocator: Allocator,
    findings: WorkflowCausalFindings,
) Allocator.Error!void {
    try output.print(allocator, "workflow findings: {d}\n", .{findings.items.len});
    if (findings.items.len == 0) {
        try output.appendSlice(allocator, "- none\n");
        return;
    }

    for (findings.items) |finding| {
        try output.print(
            allocator,
            "- {s} event={d}",
            .{ workflowCausalFindingKindName(finding.kind), finding.event_id },
        );
        try appendOptionalU64(output, allocator, "run", finding.run_id);
        try appendOptionalU64(output, allocator, "scope", finding.scope_id);
        try appendOptionalU64(output, allocator, "fiber", finding.fiber_id);
        try appendOptionalU64(output, allocator, "sequence", finding.sequence);
        if (finding.label.len != 0) try output.print(allocator, " label={s}", .{finding.label});
        if (finding.type_name.len != 0) try output.print(allocator, " type={s}", .{finding.type_name});
        if (finding.redacted_detail.len != 0) try output.print(allocator, " detail={s}", .{finding.redacted_detail});
        try output.append(allocator, '\n');
    }
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

pub fn deinitMappedEvent(allocator: Allocator, event: CausalEvent) void {
    if (event.label.len != 0) allocator.free(event.label);
    if (event.type_name.len != 0) allocator.free(event.type_name);
    if (event.status.len != 0) allocator.free(event.status);
    if (event.redacted_detail.len != 0) allocator.free(event.redacted_detail);
}
