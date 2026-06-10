const std = @import("std");
const fx = @import("zigeffect");

pub const GeneratedWorkflowHistory = struct {
    allocator: std.mem.Allocator,
    seed: u64,
    case_index: usize,
    events: []fx.workflow.WorkflowEvent,
    has_activity: bool = false,
    has_timer: bool = false,
    has_deferred: bool = false,
    has_queue: bool = false,
    has_compensation: bool = false,
    has_terminal: bool = false,

    pub fn deinit(self: *GeneratedWorkflowHistory) void {
        for (self.events) |event| {
            fx.workflow.deinitWorkflowEventStrings(self.allocator, event);
        }
        self.allocator.free(self.events);
    }
};

const EventOptions = struct {
    activity_id: ?fx.workflow.ActivityId = null,
    timer_id: ?fx.workflow.TimerId = null,
    deferred_id: ?fx.workflow.DeferredId = null,
    queue_id: ?fx.workflow.QueueId = null,
    compensation_id: ?fx.workflow.CompensationId = null,
    attempt: u32 = 0,
    status: ?[]const u8 = null,
};

const HistoryBuilder = struct {
    allocator: std.mem.Allocator,
    seed: u64,
    case_index: usize,
    workflow_id: fx.workflow.WorkflowId,
    execution_id: fx.workflow.ExecutionId,
    events: std.ArrayList(fx.workflow.WorkflowEvent) = .empty,
    has_activity: bool = false,
    has_timer: bool = false,
    has_deferred: bool = false,
    has_queue: bool = false,
    has_compensation: bool = false,
    has_terminal: bool = false,

    fn deinitEvents(self: *HistoryBuilder) void {
        for (self.events.items) |event| {
            fx.workflow.deinitWorkflowEventStrings(self.allocator, event);
        }
        self.events.deinit(self.allocator);
    }

    fn nextSequence(self: *const HistoryBuilder) fx.workflow.JournalSequence {
        return @as(fx.workflow.JournalSequence, @intCast(self.events.items.len + 1));
    }

    fn append(self: *HistoryBuilder, kind: fx.workflow.WorkflowEventKind, options: EventOptions) !void {
        const sequence = self.nextSequence();
        const event = fx.workflow.WorkflowEvent{
            .sequence = sequence,
            .kind = kind,
            .workflow_id = self.workflow_id,
            .execution_id = self.execution_id,
            .parent_sequence = if (sequence == 1) null else sequence - 1,
            .activity_id = options.activity_id,
            .timer_id = options.timer_id,
            .deferred_id = options.deferred_id,
            .queue_id = options.queue_id,
            .compensation_id = options.compensation_id,
            .attempt = options.attempt,
            .name = try std.fmt.allocPrint(
                self.allocator,
                "{s}-{d}-{d}",
                .{ fx.workflow.workflowEventKindName(kind), self.seed, self.case_index },
            ),
            .status = try self.allocator.dupe(u8, options.status orelse fx.workflow.workflowEventKindName(kind)),
            .redacted_detail = try std.fmt.allocPrint(
                self.allocator,
                "seed={d};case={d};sequence={d}",
                .{ self.seed, self.case_index, sequence },
            ),
            .idempotency_key = try std.fmt.allocPrint(
                self.allocator,
                "workflow:{d}:{d}:{d}:{s}",
                .{ self.seed, self.case_index, sequence, fx.workflow.workflowEventKindName(kind) },
            ),
        };
        errdefer fx.workflow.deinitWorkflowEventStrings(self.allocator, event);

        try self.events.append(self.allocator, event);
    }

    fn finish(self: *HistoryBuilder) !GeneratedWorkflowHistory {
        return .{
            .allocator = self.allocator,
            .seed = self.seed,
            .case_index = self.case_index,
            .events = try self.events.toOwnedSlice(self.allocator),
            .has_activity = self.has_activity,
            .has_timer = self.has_timer,
            .has_deferred = self.has_deferred,
            .has_queue = self.has_queue,
            .has_compensation = self.has_compensation,
            .has_terminal = self.has_terminal,
        };
    }
};

pub fn generateWorkflowHistory(
    allocator: std.mem.Allocator,
    seed: u64,
    case_index: usize,
) !GeneratedWorkflowHistory {
    const workflow_id = 10_000 + (seed % 10_000) + @as(u64, @intCast(case_index));
    var builder = HistoryBuilder{
        .allocator = allocator,
        .seed = seed,
        .case_index = case_index,
        .workflow_id = workflow_id,
        .execution_id = workflow_id + 1_000_000,
    };
    errdefer builder.deinitEvents();

    try builder.append(.workflow_started, .{ .status = "running" });

    if (choice(seed, case_index, 1, 3) == 0) {
        try builder.append(.workflow_suspended, .{ .status = "waiting" });
        try builder.append(.workflow_resumed, .{ .status = "running" });
    }

    if (choice(seed, case_index, 2, 2) == 0) {
        builder.has_activity = true;
        const id = domainId(seed, case_index, 10);
        try builder.append(.activity_scheduled, .{ .activity_id = id, .attempt = 1, .status = "scheduled" });
        if (choice(seed, case_index, 3, 2) == 0) {
            try builder.append(.activity_started, .{ .activity_id = id, .attempt = 1, .status = "running" });
        }
        switch (choice(seed, case_index, 4, 4)) {
            0 => try builder.append(.activity_completed, .{ .activity_id = id, .attempt = 1, .status = "completed" }),
            1 => try builder.append(.activity_failed, .{ .activity_id = id, .attempt = 1, .status = "failed" }),
            2 => try builder.append(.activity_retry_scheduled, .{ .activity_id = id, .attempt = 2, .status = "retry_ready" }),
            else => try builder.append(.activity_timed_out, .{ .activity_id = id, .attempt = 1, .status = "timed_out" }),
        }
    }

    if (choice(seed, case_index, 5, 2) == 0) {
        builder.has_timer = true;
        const id = domainId(seed, case_index, 20);
        try builder.append(.timer_scheduled, .{ .timer_id = id, .status = "scheduled" });
        if (choice(seed, case_index, 6, 2) == 0) {
            try builder.append(.timer_fired, .{ .timer_id = id, .status = "fired" });
        } else {
            try builder.append(.timer_cancelled, .{ .timer_id = id, .status = "cancelled" });
        }
    }

    if (choice(seed, case_index, 7, 2) == 0) {
        builder.has_deferred = true;
        const id = domainId(seed, case_index, 30);
        try builder.append(.deferred_created, .{ .deferred_id = id, .status = "pending" });
        if (choice(seed, case_index, 8, 2) == 0) {
            try builder.append(.deferred_awaited, .{ .deferred_id = id, .status = "awaiting" });
        }
        switch (choice(seed, case_index, 9, 3)) {
            0 => try builder.append(.deferred_completed, .{ .deferred_id = id, .status = "completed" }),
            1 => try builder.append(.deferred_failed, .{ .deferred_id = id, .status = "failed" }),
            else => try builder.append(.deferred_cancelled, .{ .deferred_id = id, .status = "cancelled" }),
        }
    }

    if (choice(seed, case_index, 10, 2) == 0) {
        builder.has_queue = true;
        const id = domainId(seed, case_index, 40);
        try builder.append(.queue_offered, .{ .queue_id = id, .status = "offered" });
        if (choice(seed, case_index, 11, 2) == 0) {
            try builder.append(.queue_claimed, .{ .queue_id = id, .attempt = 1, .status = "claimed" });
        }
        switch (choice(seed, case_index, 12, 4)) {
            0 => try builder.append(.queue_completed, .{ .queue_id = id, .status = "completed" }),
            1 => try builder.append(.queue_failed, .{ .queue_id = id, .status = "failed" }),
            2 => try builder.append(.queue_retry_scheduled, .{ .queue_id = id, .attempt = 2, .status = "retry_ready" }),
            else => try builder.append(.queue_acked, .{ .queue_id = id, .status = "acked" }),
        }
    }

    if (choice(seed, case_index, 13, 2) == 0) {
        builder.has_compensation = true;
        const id = domainId(seed, case_index, 50);
        try builder.append(.compensation_registered, .{ .compensation_id = id, .status = "registered" });
        if (choice(seed, case_index, 14, 2) == 0) {
            try builder.append(.compensation_started, .{ .compensation_id = id, .status = "running" });
        }
        if (choice(seed, case_index, 15, 2) == 0) {
            try builder.append(.compensation_completed, .{ .compensation_id = id, .status = "completed" });
        } else {
            try builder.append(.compensation_failed, .{ .compensation_id = id, .status = "failed" });
        }
    }

    if (choice(seed, case_index, 16, 3) == 0) {
        try builder.append(.step_started, .{ .status = "running" });
        if (choice(seed, case_index, 17, 2) == 0) {
            try builder.append(.step_completed, .{ .status = "completed" });
        } else {
            try builder.append(.step_failed, .{ .status = "failed" });
        }
    }

    switch (choice(seed, case_index, 18, 5)) {
        0 => {
            builder.has_terminal = true;
            try builder.append(.workflow_completed, .{ .status = "completed" });
        },
        1 => {
            builder.has_terminal = true;
            try builder.append(.workflow_failed, .{ .status = "failed" });
        },
        2 => {
            builder.has_terminal = true;
            try builder.append(.workflow_cancelled, .{ .status = "cancelled" });
        },
        3 => {
            builder.has_terminal = true;
            try builder.append(.workflow_interrupted, .{ .status = "interrupted" });
        },
        else => {},
    }

    return builder.finish();
}

fn domainId(seed: u64, case_index: usize, salt: u64) u64 {
    return 1_000_000 + (mix(seed, @as(u64, @intCast(case_index)), salt) % 1_000_000);
}

fn choice(seed: u64, case_index: usize, salt: u64, modulo: u64) u64 {
    return mix(seed, @as(u64, @intCast(case_index)), salt) % modulo;
}

fn mix(seed: u64, case_index: u64, salt: u64) u64 {
    var value = seed ^ (case_index *% 0x9e3779b97f4a7c15) ^ (salt *% 0xbf58476d1ce4e5b9);
    value = (value ^ (value >> 30)) *% 0xbf58476d1ce4e5b9;
    value = (value ^ (value >> 27)) *% 0x94d049bb133111eb;
    return value ^ (value >> 31);
}
