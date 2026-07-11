const std = @import("std");
const journal_mod = @import("journal.zig");
const replay_mod = @import("replay.zig");
const store_mod = @import("store.zig");

pub const Allocator = std.mem.Allocator;
pub const ExecutionId = journal_mod.ExecutionId;
pub const JournalSequence = journal_mod.JournalSequence;
pub const JournalStore = store_mod.JournalStore;
pub const WorkflowId = journal_mod.WorkflowId;
pub const WorkflowStatus = replay_mod.WorkflowStatus;

const LifecycleTerminalAction = enum {
    interrupt,
    cancel,
};

pub const LifecycleActionResult = struct {
    appended: bool,
};

pub const WorkflowLifecycle = struct {
    allocator: Allocator,
    journal_store: JournalStore,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,

    pub fn init(
        allocator: Allocator,
        journal_store: JournalStore,
        workflow_id: WorkflowId,
        execution_id: ExecutionId,
    ) WorkflowLifecycle {
        return .{
            .allocator = allocator,
            .journal_store = journal_store,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
        };
    }

    pub fn suspendWorkflow(self: *WorkflowLifecycle, reason: []const u8) !bool {
        const current_status = try self.currentStatus();
        if (current_status != .running) return false;
        try self.appendLifecycleEvent(.workflow_suspended, "waiting", reason);
        return true;
    }

    pub fn resumeWorkflow(self: *WorkflowLifecycle, reason: []const u8) !bool {
        const current_status = try self.currentStatus();
        if (current_status != .suspended) return false;
        try self.appendLifecycleEvent(.workflow_resumed, "running", reason);
        return true;
    }

    pub fn interrupt(self: *WorkflowLifecycle, reason: []const u8) !bool {
        const current_status = try self.currentStatus();
        if (!isTerminalControllable(current_status)) return false;
        try self.terminatePendingWork(.interrupt, reason);
        const detail = try interruptedDetail(self.allocator, reason);
        defer self.allocator.free(detail);
        try self.appendLifecycleEvent(.workflow_interrupted, "interrupted", detail);
        return true;
    }

    pub fn cancel(self: *WorkflowLifecycle, reason: []const u8) !bool {
        const current_status = try self.currentStatus();
        if (!isTerminalControllable(current_status)) return false;
        try self.terminatePendingWork(.cancel, reason);
        const detail = try cancellationDetail(self.allocator, reason);
        defer self.allocator.free(detail);
        try self.appendLifecycleEvent(.workflow_cancelled, "cancelled", detail);
        return true;
    }

    pub fn inspectStatus(self: *WorkflowLifecycle) !WorkflowStatus {
        return self.currentStatus();
    }

    fn currentStatus(self: *WorkflowLifecycle) !WorkflowStatus {
        var state = try self.journal_store.latestState(self.allocator);
        defer state.deinit();
        return state.workflow_status;
    }

    fn appendLifecycleEvent(
        self: *WorkflowLifecycle,
        kind: journal_mod.WorkflowEventKind,
        status_text: []const u8,
        redacted_detail: []const u8,
    ) !void {
        var events = try self.journal_store.readAll(self.allocator);
        defer events.deinit();
        const sequence = try nextSequence(events.events);
        const idempotency_key = try lifecycleEventIdempotencyKey(self.allocator, kind, self.workflow_id, self.execution_id, sequence);
        defer self.allocator.free(idempotency_key);
        _ = try self.journal_store.append(.{
            .expected_next_sequence = sequence,
            .event = .{
                .sequence = sequence,
                .kind = kind,
                .workflow_id = self.workflow_id,
                .execution_id = self.execution_id,
                .status = status_text,
                .redacted_detail = redacted_detail,
                .idempotency_key = idempotency_key,
            },
        });
    }

    fn terminatePendingWork(
        self: *WorkflowLifecycle,
        action: LifecycleTerminalAction,
        reason: []const u8,
    ) !void {
        var state = try self.journal_store.latestState(self.allocator);
        defer state.deinit();

        var sequence = try sequenceAfter(state.last_sequence);
        const detail = try pendingWorkDetail(self.allocator, action, reason);
        defer self.allocator.free(detail);

        for (state.timers.items) |timer| {
            if (!isPendingTimer(timer.status)) continue;
            try self.appendTimerTerminal(&sequence, timer, detail);
        }
        for (state.deferreds.items) |deferred| {
            if (!isPendingDeferred(deferred.status)) continue;
            try self.appendDeferredTerminal(&sequence, deferred, detail);
        }
        for (state.queues.items) |queue| {
            if (!isPendingQueue(queue.status)) continue;
            try self.appendQueueTerminal(&sequence, queue, detail);
        }
        for (state.activities.items) |activity| {
            if (!isPendingActivity(activity.status)) continue;
            try self.appendActivityTerminal(&sequence, activity, detail);
        }
    }

    fn appendTimerTerminal(
        self: *WorkflowLifecycle,
        sequence: *JournalSequence,
        timer: replay_mod.TimerState,
        redacted_detail: []const u8,
    ) !void {
        const current_sequence = sequence.*;
        const idempotency_key = try targetLifecycleIdempotencyKey(
            self.allocator,
            .timer_cancelled,
            self.workflow_id,
            self.execution_id,
            "timer",
            timer.id,
        );
        defer self.allocator.free(idempotency_key);
        _ = try self.journal_store.append(.{
            .expected_next_sequence = current_sequence,
            .event = .{
                .sequence = current_sequence,
                .kind = .timer_cancelled,
                .workflow_id = self.workflow_id,
                .execution_id = self.execution_id,
                .parent_sequence = timer.last_sequence,
                .timer_id = timer.id,
                .name = timer.name,
                .status = "cancelled",
                .redacted_detail = redacted_detail,
                .idempotency_key = idempotency_key,
            },
        });
        sequence.* = try sequenceAfter(current_sequence);
    }

    fn appendDeferredTerminal(
        self: *WorkflowLifecycle,
        sequence: *JournalSequence,
        deferred: replay_mod.DeferredState,
        redacted_detail: []const u8,
    ) !void {
        const current_sequence = sequence.*;
        const idempotency_key = try targetLifecycleIdempotencyKey(
            self.allocator,
            .deferred_cancelled,
            self.workflow_id,
            self.execution_id,
            "deferred",
            deferred.id,
        );
        defer self.allocator.free(idempotency_key);
        _ = try self.journal_store.append(.{
            .expected_next_sequence = current_sequence,
            .event = .{
                .sequence = current_sequence,
                .kind = .deferred_cancelled,
                .workflow_id = self.workflow_id,
                .execution_id = self.execution_id,
                .parent_sequence = deferred.last_sequence,
                .deferred_id = deferred.id,
                .name = deferred.name,
                .status = "cancelled",
                .redacted_detail = redacted_detail,
                .idempotency_key = idempotency_key,
            },
        });
        sequence.* = try sequenceAfter(current_sequence);
    }

    fn appendQueueTerminal(
        self: *WorkflowLifecycle,
        sequence: *JournalSequence,
        queue: replay_mod.QueueState,
        redacted_detail: []const u8,
    ) !void {
        const current_sequence = sequence.*;
        const idempotency_key = try targetLifecycleIdempotencyKey(
            self.allocator,
            .queue_failed,
            self.workflow_id,
            self.execution_id,
            "queue",
            queue.id,
        );
        defer self.allocator.free(idempotency_key);
        _ = try self.journal_store.append(.{
            .expected_next_sequence = current_sequence,
            .event = .{
                .sequence = current_sequence,
                .kind = .queue_failed,
                .workflow_id = self.workflow_id,
                .execution_id = self.execution_id,
                .parent_sequence = queue.last_sequence,
                .queue_id = queue.id,
                .name = queue.name,
                .status = "failed",
                .redacted_detail = redacted_detail,
                .idempotency_key = idempotency_key,
            },
        });
        sequence.* = try sequenceAfter(current_sequence);
    }

    fn appendActivityTerminal(
        self: *WorkflowLifecycle,
        sequence: *JournalSequence,
        activity: replay_mod.ActivityState,
        redacted_detail: []const u8,
    ) !void {
        const current_sequence = sequence.*;
        const idempotency_key = try targetLifecycleIdempotencyKey(
            self.allocator,
            .activity_failed,
            self.workflow_id,
            self.execution_id,
            "activity",
            activity.id,
        );
        defer self.allocator.free(idempotency_key);
        _ = try self.journal_store.append(.{
            .expected_next_sequence = current_sequence,
            .event = .{
                .sequence = current_sequence,
                .kind = .activity_failed,
                .workflow_id = self.workflow_id,
                .execution_id = self.execution_id,
                .parent_sequence = activity.last_sequence,
                .activity_id = activity.id,
                .attempt = activity.attempt,
                .name = activity.name,
                .status = "failed",
                .redacted_detail = redacted_detail,
                .idempotency_key = idempotency_key,
            },
        });
        sequence.* = try sequenceAfter(current_sequence);
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

fn isTerminalControllable(status: WorkflowStatus) bool {
    return switch (status) {
        .running,
        .suspended,
        => true,
        .pending,
        .completed,
        .failed,
        .interrupted,
        .cancelled,
        .defect,
        => false,
    };
}

fn nextSequence(events: []const journal_mod.WorkflowEvent) store_mod.JournalStoreError!JournalSequence {
    if (events.len == 0) return 1;
    const latest = events[events.len - 1].sequence;
    return sequenceAfter(latest);
}

fn sequenceAfter(latest: JournalSequence) store_mod.JournalStoreError!JournalSequence {
    if (latest == std.math.maxInt(JournalSequence)) return error.SequenceOverflow;
    return latest + 1;
}

fn lifecycleEventIdempotencyKey(
    allocator: Allocator,
    kind: journal_mod.WorkflowEventKind,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    sequence: JournalSequence,
) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "workflow:{d}:{d}:{s}:{d}",
        .{ workflow_id, execution_id, journal_mod.workflowEventKindName(kind), sequence },
    );
}

fn targetLifecycleIdempotencyKey(
    allocator: Allocator,
    kind: journal_mod.WorkflowEventKind,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    target_name: []const u8,
    target_id: u64,
) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "workflow:{d}:{d}:{s}:{s}:{d}",
        .{
            workflow_id,
            execution_id,
            journal_mod.workflowEventKindName(kind),
            target_name,
            target_id,
        },
    );
}

fn pendingWorkDetail(
    allocator: Allocator,
    action: LifecycleTerminalAction,
    reason: []const u8,
) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "lifecycle.{s}:{s}", .{ @tagName(action), reason });
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

fn interruptedDetail(allocator: Allocator, reason: []const u8) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "exit.cause.interrupted:0;reason={s}", .{reason});
}

fn cancellationDetail(allocator: Allocator, reason: []const u8) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "reason={s}", .{reason});
}
