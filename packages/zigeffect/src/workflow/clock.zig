const std = @import("std");
const journal_mod = @import("journal.zig");
const store_mod = @import("store.zig");

pub const Allocator = std.mem.Allocator;
pub const ExecutionId = journal_mod.ExecutionId;
pub const JournalSequence = journal_mod.JournalSequence;
pub const JournalStore = store_mod.JournalStore;
pub const TimerId = journal_mod.TimerId;
pub const WorkflowId = journal_mod.WorkflowId;

pub const DurableClockError = error{
    InvalidTimerFireAtDetail,
};

pub const TimerSleepResult = union(enum) {
    fired,
    cancelled,
    suspended: @import("../runtime/control.zig").Suspension,
};

pub const DueTimer = struct {
    timer_id: TimerId,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    name: []const u8,
    fire_at_ms: u64,
};

pub const DueTimerList = struct {
    allocator: Allocator,
    timers: []DueTimer,

    pub fn deinit(self: *DueTimerList) void {
        for (self.timers) |timer| {
            if (timer.name.len != 0) self.allocator.free(timer.name);
        }
        self.allocator.free(self.timers);
    }
};

pub const DurableClock = struct {
    allocator: Allocator,
    journal_store: JournalStore,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,

    pub fn init(
        allocator: Allocator,
        journal_store: JournalStore,
        workflow_id: WorkflowId,
        execution_id: ExecutionId,
    ) DurableClock {
        return .{
            .allocator = allocator,
            .journal_store = journal_store,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
        };
    }

    pub fn dueTimers(self: *const DurableClock, now_ms: u64) !DueTimerList {
        var events = try self.journal_store.readAll(self.allocator);
        defer events.deinit();

        var timers = std.ArrayList(DueTimer).empty;
        errdefer deinitDueTimerItems(self.allocator, timers.items);
        errdefer timers.deinit(self.allocator);

        for (events.events) |event| {
            if (!isWorkflowEvent(event, self.workflow_id, self.execution_id)) continue;
            if (event.kind != .timer_scheduled) continue;
            const id = event.timer_id orelse continue;
            if (timerHasTerminalEvent(events.events, self.workflow_id, self.execution_id, id)) continue;

            const fire_at_ms = try parseTimerFireAt(event.redacted_detail);
            if (fire_at_ms > now_ms) continue;

            const name = try cloneTimerName(self.allocator, event.name);
            errdefer freeTimerName(self.allocator, name);
            try timers.append(self.allocator, .{
                .timer_id = id,
                .workflow_id = event.workflow_id,
                .execution_id = event.execution_id,
                .name = name,
                .fire_at_ms = fire_at_ms,
            });
        }

        return .{
            .allocator = self.allocator,
            .timers = try timers.toOwnedSlice(self.allocator),
        };
    }

    pub fn pendingTimers(self: *const DurableClock) !DueTimerList {
        var events = try self.journal_store.readAll(self.allocator);
        defer events.deinit();

        var timers = std.ArrayList(DueTimer).empty;
        errdefer deinitDueTimerItems(self.allocator, timers.items);
        errdefer timers.deinit(self.allocator);

        for (events.events) |event| {
            if (!isWorkflowEvent(event, self.workflow_id, self.execution_id)) continue;
            if (event.kind != .timer_scheduled) continue;
            const id = event.timer_id orelse continue;
            if (timerHasTerminalEvent(events.events, self.workflow_id, self.execution_id, id)) continue;

            const fire_at_ms = try parseTimerFireAt(event.redacted_detail);
            const name = try cloneTimerName(self.allocator, event.name);
            errdefer freeTimerName(self.allocator, name);
            try timers.append(self.allocator, .{
                .timer_id = id,
                .workflow_id = event.workflow_id,
                .execution_id = event.execution_id,
                .name = name,
                .fire_at_ms = fire_at_ms,
            });
        }

        return .{
            .allocator = self.allocator,
            .timers = try timers.toOwnedSlice(self.allocator),
        };
    }

    pub fn fireDueTimers(self: *const DurableClock, now_ms: u64) !usize {
        var events = try self.journal_store.readAll(self.allocator);
        defer events.deinit();

        var next_sequence = try nextSequence(events.events);
        var fired_count: usize = 0;
        var resumed = !workflowIsSuspended(events.events, self.workflow_id, self.execution_id);

        for (events.events) |event| {
            if (!isWorkflowEvent(event, self.workflow_id, self.execution_id)) continue;
            if (event.kind != .timer_scheduled) continue;
            const id = event.timer_id orelse continue;
            if (timerHasTerminalEvent(events.events, self.workflow_id, self.execution_id, id)) continue;

            const fire_at_ms = try parseTimerFireAt(event.redacted_detail);
            if (fire_at_ms > now_ms) continue;

            try appendTimerEvent(self, .timer_fired, id, event.name, "fired", "", &next_sequence);
            fired_count += 1;
            if (!resumed) {
                try appendTimerEvent(self, .workflow_resumed, id, event.name, "running", "timer", &next_sequence);
                resumed = true;
            }
        }

        return fired_count;
    }

    pub fn cancel(self: *const DurableClock, label: []const u8) !bool {
        const id = timerId(label);
        var events = try self.journal_store.readAll(self.allocator);
        defer events.deinit();

        if (!timerIsScheduled(events.events, self.workflow_id, self.execution_id, id)) return false;
        if (timerHasTerminalEvent(events.events, self.workflow_id, self.execution_id, id)) return false;

        var next_sequence_value = try nextSequence(events.events);
        try appendTimerEvent(self, .timer_cancelled, id, label, "cancelled", "", &next_sequence_value);
        if (workflowIsSuspended(events.events, self.workflow_id, self.execution_id)) {
            try appendTimerEvent(self, .workflow_resumed, id, label, "running", "timer", &next_sequence_value);
        }
        return true;
    }
};

pub fn timerId(label: []const u8) TimerId {
    return std.hash.Fnv1a_64.hash(label);
}

fn isWorkflowEvent(event: journal_mod.WorkflowEvent, workflow_id: WorkflowId, execution_id: ExecutionId) bool {
    return event.workflow_id == workflow_id and event.execution_id == execution_id;
}

fn timerHasTerminalEvent(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    id: TimerId,
) bool {
    for (events) |event| {
        if (!isWorkflowEvent(event, workflow_id, execution_id)) continue;
        if (event.timer_id == null or event.timer_id.? != id) continue;
        switch (event.kind) {
            .timer_fired, .timer_cancelled => return true,
            else => {},
        }
    }
    return false;
}

fn timerIsScheduled(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    id: TimerId,
) bool {
    for (events) |event| {
        if (!isWorkflowEvent(event, workflow_id, execution_id)) continue;
        if (event.timer_id == null or event.timer_id.? != id) continue;
        if (event.kind == .timer_scheduled) return true;
    }
    return false;
}

fn workflowIsSuspended(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
) bool {
    var suspended = false;
    for (events) |event| {
        if (!isWorkflowEvent(event, workflow_id, execution_id)) continue;
        switch (event.kind) {
            .workflow_started, .workflow_resumed => suspended = false,
            .workflow_suspended => suspended = true,
            .workflow_completed,
            .workflow_failed,
            .workflow_interrupted,
            .workflow_cancelled,
            => suspended = false,
            else => {},
        }
    }
    return suspended;
}

fn parseTimerFireAt(detail: []const u8) DurableClockError!u64 {
    const prefix = "fire_at_ms=";
    if (!std.mem.startsWith(u8, detail, prefix)) return error.InvalidTimerFireAtDetail;
    return std.fmt.parseInt(u64, detail[prefix.len..], 10) catch error.InvalidTimerFireAtDetail;
}

fn nextSequence(events: []const journal_mod.WorkflowEvent) store_mod.JournalStoreError!JournalSequence {
    if (events.len == 0) return 1;
    const latest = events[events.len - 1].sequence;
    if (latest == std.math.maxInt(JournalSequence)) return error.SequenceOverflow;
    return latest + 1;
}

fn advanceSequence(sequence: *JournalSequence) store_mod.JournalStoreError!void {
    if (sequence.* == std.math.maxInt(JournalSequence)) return error.SequenceOverflow;
    sequence.* += 1;
}

fn appendTimerEvent(
    self: *const DurableClock,
    kind: journal_mod.WorkflowEventKind,
    id: TimerId,
    name: []const u8,
    status: []const u8,
    redacted_detail: []const u8,
    next_sequence_value: *JournalSequence,
) !void {
    const idempotency_key = try timerEventIdempotencyKey(self.allocator, kind, id, next_sequence_value.*);
    defer self.allocator.free(idempotency_key);
    _ = try self.journal_store.append(.{
        .expected_next_sequence = next_sequence_value.*,
        .event = .{
            .sequence = next_sequence_value.*,
            .kind = kind,
            .workflow_id = self.workflow_id,
            .execution_id = self.execution_id,
            .timer_id = id,
            .name = name,
            .status = status,
            .redacted_detail = redacted_detail,
            .idempotency_key = idempotency_key,
        },
    });
    try advanceSequence(next_sequence_value);
}

fn timerEventIdempotencyKey(
    allocator: Allocator,
    kind: journal_mod.WorkflowEventKind,
    id: TimerId,
    sequence: JournalSequence,
) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "timer:{d}:{s}:{d}",
        .{ id, journal_mod.workflowEventKindName(kind), sequence },
    );
}

fn cloneTimerName(allocator: Allocator, name: []const u8) Allocator.Error![]const u8 {
    if (name.len == 0) return "";
    return allocator.dupe(u8, name);
}

fn freeTimerName(allocator: Allocator, name: []const u8) void {
    if (name.len != 0) allocator.free(name);
}

fn deinitDueTimerItems(allocator: Allocator, timers: []DueTimer) void {
    for (timers) |timer| {
        freeTimerName(allocator, timer.name);
    }
}
