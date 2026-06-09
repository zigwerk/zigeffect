const std = @import("std");
const journal = @import("journal.zig");

pub const WorkflowEvent = journal.WorkflowEvent;
pub const WorkflowId = journal.WorkflowId;
pub const ExecutionId = journal.ExecutionId;
pub const JournalSequence = journal.JournalSequence;

pub const WorkflowStatus = enum {
    pending,
    running,
    suspended,
    completed,
    failed,
    interrupted,
    cancelled,
    defect,
};

pub const ActivityStatus = enum {
    scheduled,
    running,
    completed,
    failed,
    retry_ready,
};

pub const TimerStatus = enum {
    scheduled,
    fired,
    cancelled,
};

pub const DeferredStatus = enum {
    pending,
    completed,
    failed,
    cancelled,
};

pub const QueueStatus = enum {
    offered,
    claimed,
    completed,
    failed,
    acked,
};

pub const ReplayError = error{
    WorkflowNotStarted,
    WorkflowAlreadyStarted,
    WorkflowAlreadyTerminal,
    InvalidWorkflowTransition,
    MissingTargetId,
    DuplicateActivity,
    UnknownActivity,
    DuplicateTimer,
    UnknownTimer,
    DuplicateDeferred,
    UnknownDeferred,
    DuplicateQueue,
    UnknownQueue,
};

pub const ActivityState = struct {
    id: journal.ActivityId,
    status: ActivityStatus,
    last_sequence: JournalSequence,
    name: []const u8 = "",
};

pub const TimerState = struct {
    id: journal.TimerId,
    status: TimerStatus,
    last_sequence: JournalSequence,
    name: []const u8 = "",
};

pub const DeferredState = struct {
    id: journal.DeferredId,
    status: DeferredStatus,
    last_sequence: JournalSequence,
    name: []const u8 = "",
};

pub const QueueState = struct {
    id: journal.QueueId,
    status: QueueStatus,
    last_sequence: JournalSequence,
    name: []const u8 = "",
};

pub const WorkflowReplayState = struct {
    allocator: std.mem.Allocator,
    workflow_status: WorkflowStatus = .pending,
    workflow_id: ?WorkflowId = null,
    execution_id: ?ExecutionId = null,
    last_sequence: JournalSequence = 0,
    activities: std.ArrayList(ActivityState) = .empty,
    timers: std.ArrayList(TimerState) = .empty,
    deferreds: std.ArrayList(DeferredState) = .empty,
    queues: std.ArrayList(QueueState) = .empty,

    pub fn init(allocator: std.mem.Allocator) WorkflowReplayState {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *WorkflowReplayState) void {
        for (self.queues.items) |queue| {
            self.freeName(queue.name);
        }
        self.queues.deinit(self.allocator);
        for (self.deferreds.items) |deferred| {
            self.freeName(deferred.name);
        }
        self.deferreds.deinit(self.allocator);
        for (self.timers.items) |timer| {
            self.freeName(timer.name);
        }
        self.timers.deinit(self.allocator);
        for (self.activities.items) |activity| {
            self.freeName(activity.name);
        }
        self.activities.deinit(self.allocator);
    }

    pub fn fold(allocator: std.mem.Allocator, events: []const WorkflowEvent) (std.mem.Allocator.Error || ReplayError)!WorkflowReplayState {
        var state = WorkflowReplayState.init(allocator);
        errdefer state.deinit();

        for (events) |event| {
            try state.apply(event);
        }

        return state;
    }

    pub fn apply(self: *WorkflowReplayState, event: WorkflowEvent) (std.mem.Allocator.Error || ReplayError)!void {
        try self.ensureCanApply(event);
        switch (event.kind) {
            .workflow_started => try self.applyWorkflowStarted(event),
            .workflow_suspended => try self.applyWorkflowSuspended(event),
            .workflow_resumed => try self.applyWorkflowResumed(event),
            .workflow_completed => self.workflow_status = .completed,
            .workflow_failed => self.workflow_status = workflowFailureStatus(event),
            .workflow_interrupted => self.workflow_status = .interrupted,
            .workflow_cancelled => self.workflow_status = .cancelled,
            .activity_scheduled => try self.applyActivityScheduled(event),
            .activity_started => try self.updateActivity(event, .running),
            .activity_completed => try self.updateActivity(event, .completed),
            .activity_failed => try self.updateActivity(event, activityFailureStatus(event)),
            .timer_scheduled => try self.applyTimerScheduled(event),
            .timer_fired => try self.updateTimer(event, .fired),
            .timer_cancelled => try self.updateTimer(event, .cancelled),
            .deferred_created => try self.applyDeferredCreated(event),
            .deferred_awaited => try self.touchDeferred(event),
            .deferred_completed => try self.updateDeferred(event, .completed),
            .deferred_failed => try self.updateDeferred(event, .failed),
            .deferred_cancelled => try self.updateDeferred(event, .cancelled),
            .queue_offered => try self.applyQueueOffered(event),
            .queue_claimed => try self.updateQueue(event, .claimed),
            .queue_completed => try self.updateQueue(event, .completed),
            .queue_failed => try self.updateQueue(event, .failed),
            .queue_acked => try self.updateQueue(event, .acked),
            else => {},
        }
        self.last_sequence = event.sequence;
    }

    fn ensureCanApply(self: *const WorkflowReplayState, event: WorkflowEvent) ReplayError!void {
        if (event.kind == .workflow_started) {
            if (self.workflow_status != .pending) return error.WorkflowAlreadyStarted;
            return;
        }
        if (self.workflow_status == .pending) return error.WorkflowNotStarted;
        if (isTerminal(self.workflow_status)) return error.WorkflowAlreadyTerminal;
    }

    fn applyWorkflowStarted(self: *WorkflowReplayState, event: WorkflowEvent) ReplayError!void {
        self.workflow_status = .running;
        self.workflow_id = event.workflow_id;
        self.execution_id = event.execution_id;
    }

    fn applyWorkflowSuspended(self: *WorkflowReplayState, event: WorkflowEvent) ReplayError!void {
        _ = event;
        if (self.workflow_status != .running) return error.InvalidWorkflowTransition;
        self.workflow_status = .suspended;
    }

    fn applyWorkflowResumed(self: *WorkflowReplayState, event: WorkflowEvent) ReplayError!void {
        _ = event;
        if (self.workflow_status != .suspended) return error.InvalidWorkflowTransition;
        self.workflow_status = .running;
    }

    fn applyActivityScheduled(self: *WorkflowReplayState, event: WorkflowEvent) (std.mem.Allocator.Error || ReplayError)!void {
        const id = try requireActivityId(event);
        if (self.findActivityIndex(id) != null) return error.DuplicateActivity;
        const name = try self.cloneName(event.name);
        errdefer self.freeName(name);
        try self.activities.append(self.allocator, .{
            .id = id,
            .status = .scheduled,
            .last_sequence = event.sequence,
            .name = name,
        });
    }

    fn updateActivity(self: *WorkflowReplayState, event: WorkflowEvent, status: ActivityStatus) (std.mem.Allocator.Error || ReplayError)!void {
        const id = try requireActivityId(event);
        const index = self.findActivityIndex(id) orelse return error.UnknownActivity;
        const name_update = try self.prepareNameUpdate(event.name);
        errdefer if (name_update) |name| self.freeName(name);
        const activity = &self.activities.items[index];
        activity.status = status;
        activity.last_sequence = event.sequence;
        self.commitNameUpdate(&activity.name, name_update);
    }

    fn applyTimerScheduled(self: *WorkflowReplayState, event: WorkflowEvent) (std.mem.Allocator.Error || ReplayError)!void {
        const id = try requireTimerId(event);
        if (self.findTimerIndex(id) != null) return error.DuplicateTimer;
        const name = try self.cloneName(event.name);
        errdefer self.freeName(name);
        try self.timers.append(self.allocator, .{
            .id = id,
            .status = .scheduled,
            .last_sequence = event.sequence,
            .name = name,
        });
    }

    fn updateTimer(self: *WorkflowReplayState, event: WorkflowEvent, status: TimerStatus) (std.mem.Allocator.Error || ReplayError)!void {
        const id = try requireTimerId(event);
        const index = self.findTimerIndex(id) orelse return error.UnknownTimer;
        const name_update = try self.prepareNameUpdate(event.name);
        errdefer if (name_update) |name| self.freeName(name);
        const timer = &self.timers.items[index];
        timer.status = status;
        timer.last_sequence = event.sequence;
        self.commitNameUpdate(&timer.name, name_update);
    }

    fn applyDeferredCreated(self: *WorkflowReplayState, event: WorkflowEvent) (std.mem.Allocator.Error || ReplayError)!void {
        const id = try requireDeferredId(event);
        if (self.findDeferredIndex(id) != null) return error.DuplicateDeferred;
        const name = try self.cloneName(event.name);
        errdefer self.freeName(name);
        try self.deferreds.append(self.allocator, .{
            .id = id,
            .status = .pending,
            .last_sequence = event.sequence,
            .name = name,
        });
    }

    fn touchDeferred(self: *WorkflowReplayState, event: WorkflowEvent) (std.mem.Allocator.Error || ReplayError)!void {
        const id = try requireDeferredId(event);
        const index = self.findDeferredIndex(id) orelse return error.UnknownDeferred;
        const name_update = try self.prepareNameUpdate(event.name);
        errdefer if (name_update) |name| self.freeName(name);
        const deferred = &self.deferreds.items[index];
        deferred.last_sequence = event.sequence;
        self.commitNameUpdate(&deferred.name, name_update);
    }

    fn updateDeferred(self: *WorkflowReplayState, event: WorkflowEvent, status: DeferredStatus) (std.mem.Allocator.Error || ReplayError)!void {
        const id = try requireDeferredId(event);
        const index = self.findDeferredIndex(id) orelse return error.UnknownDeferred;
        const name_update = try self.prepareNameUpdate(event.name);
        errdefer if (name_update) |name| self.freeName(name);
        const deferred = &self.deferreds.items[index];
        deferred.status = status;
        deferred.last_sequence = event.sequence;
        self.commitNameUpdate(&deferred.name, name_update);
    }

    fn applyQueueOffered(self: *WorkflowReplayState, event: WorkflowEvent) (std.mem.Allocator.Error || ReplayError)!void {
        const id = try requireQueueId(event);
        if (self.findQueueIndex(id) != null) return error.DuplicateQueue;
        const name = try self.cloneName(event.name);
        errdefer self.freeName(name);
        try self.queues.append(self.allocator, .{
            .id = id,
            .status = .offered,
            .last_sequence = event.sequence,
            .name = name,
        });
    }

    fn updateQueue(self: *WorkflowReplayState, event: WorkflowEvent, status: QueueStatus) (std.mem.Allocator.Error || ReplayError)!void {
        const id = try requireQueueId(event);
        const index = self.findQueueIndex(id) orelse return error.UnknownQueue;
        const name_update = try self.prepareNameUpdate(event.name);
        errdefer if (name_update) |name| self.freeName(name);
        const queue = &self.queues.items[index];
        queue.status = status;
        queue.last_sequence = event.sequence;
        self.commitNameUpdate(&queue.name, name_update);
    }

    fn findActivityIndex(self: *const WorkflowReplayState, id: journal.ActivityId) ?usize {
        for (self.activities.items, 0..) |activity, index| {
            if (activity.id == id) return index;
        }
        return null;
    }

    fn findTimerIndex(self: *const WorkflowReplayState, id: journal.TimerId) ?usize {
        for (self.timers.items, 0..) |timer, index| {
            if (timer.id == id) return index;
        }
        return null;
    }

    fn findDeferredIndex(self: *const WorkflowReplayState, id: journal.DeferredId) ?usize {
        for (self.deferreds.items, 0..) |deferred, index| {
            if (deferred.id == id) return index;
        }
        return null;
    }

    fn findQueueIndex(self: *const WorkflowReplayState, id: journal.QueueId) ?usize {
        for (self.queues.items, 0..) |queue, index| {
            if (queue.id == id) return index;
        }
        return null;
    }

    fn cloneName(self: *WorkflowReplayState, name: []const u8) std.mem.Allocator.Error![]const u8 {
        if (name.len == 0) return "";
        return self.allocator.dupe(u8, name);
    }

    fn freeName(self: *WorkflowReplayState, name: []const u8) void {
        if (name.len != 0) self.allocator.free(name);
    }

    fn prepareNameUpdate(self: *WorkflowReplayState, name: []const u8) std.mem.Allocator.Error!?[]const u8 {
        if (name.len == 0) return null;
        return try self.cloneName(name);
    }

    fn commitNameUpdate(self: *WorkflowReplayState, current: *[]const u8, name_update: ?[]const u8) void {
        if (name_update) |name| {
            self.freeName(current.*);
            current.* = name;
        }
    }
};

fn isTerminal(status: WorkflowStatus) bool {
    return switch (status) {
        .completed,
        .failed,
        .interrupted,
        .cancelled,
        .defect,
        => true,
        .pending,
        .running,
        .suspended,
        => false,
    };
}

fn requireActivityId(event: WorkflowEvent) ReplayError!journal.ActivityId {
    return event.activity_id orelse error.MissingTargetId;
}

fn requireTimerId(event: WorkflowEvent) ReplayError!journal.TimerId {
    return event.timer_id orelse error.MissingTargetId;
}

fn requireDeferredId(event: WorkflowEvent) ReplayError!journal.DeferredId {
    return event.deferred_id orelse error.MissingTargetId;
}

fn requireQueueId(event: WorkflowEvent) ReplayError!journal.QueueId {
    return event.queue_id orelse error.MissingTargetId;
}

fn workflowFailureStatus(event: WorkflowEvent) WorkflowStatus {
    if (std.mem.eql(u8, event.status, "defect")) return .defect;
    return .failed;
}

fn activityFailureStatus(event: WorkflowEvent) ActivityStatus {
    if (std.mem.eql(u8, event.status, "retry_ready")) return .retry_ready;
    return .failed;
}
