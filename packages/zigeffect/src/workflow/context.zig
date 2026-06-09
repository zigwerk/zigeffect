const std = @import("std");
const result_mod = @import("../core/result.zig");
const schedule_mod = @import("../effect/schedule.zig");
const causal_mod = @import("../services/causal.zig");
const clock_mod = @import("../services/clock.zig");
const traits_mod = @import("../traits/root.zig");
const journal_mod = @import("journal.zig");
const store_mod = @import("store.zig");

pub const Allocator = std.mem.Allocator;
pub const CausalStore = causal_mod.CausalStore;
pub const Clock = clock_mod.Clock;
pub const Codec = traits_mod.Codec;
pub const JournalStore = store_mod.JournalStore;
pub const JournalEventBatch = store_mod.JournalEventBatch;
pub const Schedule = schedule_mod.Schedule;
pub const WorkflowId = journal_mod.WorkflowId;
pub const ExecutionId = journal_mod.ExecutionId;
pub const ActivityId = journal_mod.ActivityId;
pub const CompensationId = journal_mod.CompensationId;
pub const JournalSequence = journal_mod.JournalSequence;
pub const WorkflowStepCause = result_mod.Cause(anyerror);
pub const WorkflowStepExit = result_mod.Exit(void, anyerror);

pub const WorkflowContextError = error{
    CompensationHandlerNotFound,
    RecordedStepParseFailed,
    RecordedActivityFailureParseFailed,
};

pub const WorkflowContextOptions = struct {
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    clock: ?*Clock = null,
    causal_store: ?*CausalStore = null,
    causal_run_id: ?u64 = null,
};

pub const WorkflowContext = struct {
    allocator: Allocator,
    journal_store: JournalStore,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    clock: ?*Clock,
    causal_store: ?*CausalStore,
    causal_run_id: ?u64,
    next_sequence: JournalSequence,
    replay_events: JournalEventBatch,

    pub fn init(allocator: Allocator, journal_store: JournalStore, options: WorkflowContextOptions) !WorkflowContext {
        var replay_events = try journal_store.readAll(allocator);
        errdefer replay_events.deinit();

        const next_sequence = if (replay_events.events.len == 0)
            1
        else
            replay_events.events[replay_events.events.len - 1].sequence + 1;

        return .{
            .allocator = allocator,
            .journal_store = journal_store,
            .workflow_id = options.workflow_id,
            .execution_id = options.execution_id,
            .clock = options.clock,
            .causal_store = options.causal_store,
            .causal_run_id = options.causal_run_id,
            .next_sequence = next_sequence,
            .replay_events = replay_events,
        };
    }

    pub fn deinit(self: *WorkflowContext) void {
        self.replay_events.deinit();
    }

    pub fn stepU64(self: *WorkflowContext, label: []const u8, comptime run_fn: anytype) !u64 {
        if (try self.recordedStepU64(label)) |value| return value;

        try self.appendStepEvent(.step_started, label, "started", "");
        const value = run_fn() catch |err| {
            const detail = try workflowFailureDetail(self.allocator, err);
            defer self.allocator.free(detail);
            try self.appendStepEvent(.step_failed, label, "failed", detail);
            return err;
        };

        const detail = try std.fmt.allocPrint(self.allocator, "{d}", .{value});
        defer self.allocator.free(detail);
        try self.appendStepEvent(.step_completed, label, "completed", detail);
        return value;
    }

    pub fn activity(
        self: *WorkflowContext,
        comptime ActivityType: type,
        payload: ActivityType.PayloadType,
        result_codec: Codec(ActivityType.SuccessType),
        comptime run_fn: anytype,
    ) !ActivityType.SuccessType {
        assertActivityFailureIsErrorSet(ActivityType.FailureType);

        const logical_key = try ActivityType.idempotencyKey(self.allocator, payload);
        defer self.allocator.free(logical_key);
        const id = activityId(ActivityType.name, logical_key);

        if (try self.recordedActivity(ActivityType, id, result_codec)) |recorded| {
            return switch (recorded) {
                .completed => |value| value,
                .failed => |err| err,
            };
        }

        var attempt: u32 = 1;
        while (true) {
            try self.appendActivityEvent(.activity_scheduled, id, ActivityType.name, attempt, "scheduled", "");
            if (comptime ActivityType.metadata().timeout_ms != null) {
                if (try self.timeoutBeforeStart(ActivityType, id, attempt)) {
                    return activityTimeoutError(ActivityType.FailureType);
                }
            }
            const started_ms = if (self.clock) |clock| clock.nowMs() else null;
            try self.appendActivityEvent(.activity_started, id, ActivityType.name, attempt, "running", "");

            const value = run_fn(payload) catch |err| {
                if (try self.scheduleRetry(ActivityType, id, attempt)) {
                    attempt += 1;
                    continue;
                }
                if (try self.exhaustRetry(ActivityType, id, attempt, err)) return err;

                const detail = try workflowFailureDetail(self.allocator, err);
                defer self.allocator.free(detail);
                try self.appendActivityEvent(.activity_failed, id, ActivityType.name, attempt, "failed", detail);
                return err;
            };
            if (comptime ActivityType.metadata().timeout_ms != null) {
                if (try self.timeoutAfterRun(ActivityType, id, attempt, started_ms)) {
                    return activityTimeoutError(ActivityType.FailureType);
                }
            }
            const encoded = try result_codec.encodeValue(self.allocator, value);
            defer self.allocator.free(encoded);
            try self.appendActivityEvent(.activity_completed, id, ActivityType.name, attempt, "completed", encoded);
            return value;
        }
    }

    pub fn registerCompensation(self: *WorkflowContext, label: []const u8) !void {
        const id = journal_mod.compensationId(label);
        try self.appendCompensationEvent(.compensation_registered, id, label, "registered", "");
    }

    pub fn runCompensations(self: *WorkflowContext, comptime handlers: anytype) !void {
        var events = try self.journal_store.readAll(self.allocator);
        defer events.deinit();

        var index = events.events.len;
        while (index > 0) {
            index -= 1;
            const event = events.events[index];
            if (event.kind != .compensation_registered or
                event.workflow_id != self.workflow_id or
                event.execution_id != self.execution_id)
            {
                continue;
            }

            const id = event.compensation_id orelse continue;
            if (compensationCompleted(events.events, id, self.workflow_id, self.execution_id)) continue;

            try self.appendCompensationEvent(.compensation_started, id, event.name, "running", "");
            runCompensationHandler(handlers, event.name) catch |err| {
                const detail = try workflowFailureDetail(self.allocator, err);
                defer self.allocator.free(detail);
                try self.appendCompensationEvent(.compensation_failed, id, event.name, "failed", detail);
                return err;
            };
            try self.appendCompensationEvent(.compensation_completed, id, event.name, "completed", "");
        }
    }

    fn recordedStepU64(self: *const WorkflowContext, label: []const u8) !?u64 {
        for (self.replay_events.events) |event| {
            if (event.kind == .step_completed and
                event.workflow_id == self.workflow_id and
                event.execution_id == self.execution_id and
                std.mem.eql(u8, event.name, label))
            {
                return std.fmt.parseInt(u64, event.redacted_detail, 10) catch error.RecordedStepParseFailed;
            }
        }
        return null;
    }

    fn appendStepEvent(
        self: *WorkflowContext,
        kind: journal_mod.WorkflowEventKind,
        label: []const u8,
        status: []const u8,
        redacted_detail: []const u8,
    ) !void {
        _ = try self.journal_store.append(.{
            .event = .{
                .sequence = self.next_sequence,
                .kind = kind,
                .workflow_id = self.workflow_id,
                .execution_id = self.execution_id,
                .name = label,
                .status = status,
                .redacted_detail = redacted_detail,
            },
        });
        self.next_sequence += 1;
    }

    fn recordedActivity(
        self: *const WorkflowContext,
        comptime ActivityType: type,
        id: ActivityId,
        result_codec: Codec(ActivityType.SuccessType),
    ) !?ActivityReplay(ActivityType.SuccessType, ActivityType.FailureType) {
        var index = self.replay_events.events.len;
        while (index > 0) {
            index -= 1;
            const event = self.replay_events.events[index];
            if (event.activity_id != null and
                event.activity_id.? == id and
                event.workflow_id == self.workflow_id and
                event.execution_id == self.execution_id)
            {
                switch (event.kind) {
                    .activity_completed => return .{
                        .completed = try result_codec.decodeValue(self.allocator, event.redacted_detail),
                    },
                    .activity_failed => {
                        const failure = activityFailureFromDetail(
                            ActivityType.FailureType,
                            event.redacted_detail,
                        ) orelse return error.RecordedActivityFailureParseFailed;
                        return .{ .failed = failure };
                    },
                    .activity_timed_out => {
                        const failure = activityFailureFromDetail(
                            ActivityType.FailureType,
                            event.redacted_detail,
                        ) orelse return error.RecordedActivityFailureParseFailed;
                        return .{ .failed = failure };
                    },
                    else => {},
                }
            }
        }
        return null;
    }

    fn appendActivityEvent(
        self: *WorkflowContext,
        kind: journal_mod.WorkflowEventKind,
        id: ActivityId,
        name: []const u8,
        attempt: u32,
        status: []const u8,
        redacted_detail: []const u8,
    ) !void {
        const idempotency_key = try activityEventIdempotencyKey(self.allocator, kind, id, attempt);
        defer self.allocator.free(idempotency_key);
        _ = try self.journal_store.append(.{
            .event = .{
                .sequence = self.next_sequence,
                .kind = kind,
                .workflow_id = self.workflow_id,
                .execution_id = self.execution_id,
                .activity_id = id,
                .attempt = attempt,
                .name = name,
                .status = status,
                .redacted_detail = redacted_detail,
                .idempotency_key = idempotency_key,
            },
        });
        self.next_sequence += 1;
    }

    fn appendCompensationEvent(
        self: *WorkflowContext,
        kind: journal_mod.WorkflowEventKind,
        id: CompensationId,
        name: []const u8,
        status: []const u8,
        redacted_detail: []const u8,
    ) !void {
        const idempotency_key = try compensationEventIdempotencyKey(self.allocator, kind, id, self.next_sequence);
        defer self.allocator.free(idempotency_key);
        _ = try self.journal_store.append(.{
            .event = .{
                .sequence = self.next_sequence,
                .kind = kind,
                .workflow_id = self.workflow_id,
                .execution_id = self.execution_id,
                .compensation_id = id,
                .name = name,
                .status = status,
                .redacted_detail = redacted_detail,
                .idempotency_key = idempotency_key,
            },
        });
        self.next_sequence += 1;
    }

    fn scheduleRetry(
        self: *WorkflowContext,
        comptime ActivityType: type,
        id: ActivityId,
        attempt: u32,
    ) !bool {
        var schedule = ActivityType.retrySchedule() orelse return false;
        const schedule_attempt: usize = @intCast(attempt - 1);
        const decision = schedule.decision(schedule_attempt);
        const delay_ms = decision.delay_ms orelse return false;

        const detail = try scheduleDecisionDetail(self.allocator, decision.attempt, delay_ms, "retry");
        defer self.allocator.free(detail);
        try self.appendActivityEvent(.activity_retry_scheduled, id, ActivityType.name, attempt, "retry", detail);
        self.recordCausalScheduleDecision(&schedule, "retry", detail);
        if (self.clock) |clock| clock.sleep(delay_ms);
        return true;
    }

    fn timeoutBeforeStart(
        self: *WorkflowContext,
        comptime ActivityType: type,
        id: ActivityId,
        attempt: u32,
    ) !bool {
        const timeout_ms = ActivityType.metadata().timeout_ms orelse return false;
        if (timeout_ms != 0) return false;
        try self.appendActivityTimeout(ActivityType, id, attempt);
        return true;
    }

    fn timeoutAfterRun(
        self: *WorkflowContext,
        comptime ActivityType: type,
        id: ActivityId,
        attempt: u32,
        started_ms: ?u64,
    ) !bool {
        const timeout_ms = ActivityType.metadata().timeout_ms orelse return false;
        const started = started_ms orelse return false;
        const clock = self.clock orelse return false;
        const now = clock.nowMs();
        const elapsed = if (now >= started) now - started else 0;
        if (elapsed <= timeout_ms) return false;
        try self.appendActivityTimeout(ActivityType, id, attempt);
        return true;
    }

    fn appendActivityTimeout(
        self: *WorkflowContext,
        comptime ActivityType: type,
        id: ActivityId,
        attempt: u32,
    ) !void {
        const detail = try workflowFailureDetail(
            self.allocator,
            activityTimeoutError(ActivityType.FailureType),
        );
        defer self.allocator.free(detail);
        try self.appendActivityEvent(.activity_timed_out, id, ActivityType.name, attempt, "timeout", detail);
    }

    fn exhaustRetry(
        self: *WorkflowContext,
        comptime ActivityType: type,
        id: ActivityId,
        attempt: u32,
        err: anyerror,
    ) !bool {
        var schedule = ActivityType.retrySchedule() orelse return false;
        const schedule_attempt: usize = @intCast(attempt - 1);
        const decision = schedule.decision(schedule_attempt);
        if (decision.delay_ms != null) return false;

        const causal_detail = try scheduleTerminalDecisionDetail(
            self.allocator,
            decision.attempt,
            "exhausted",
        );
        defer self.allocator.free(causal_detail);

        const failure_detail = try workflowFailureDetail(self.allocator, err);
        defer self.allocator.free(failure_detail);
        const journal_detail = try std.fmt.allocPrint(
            self.allocator,
            "{s};{s}",
            .{ causal_detail, failure_detail },
        );
        defer self.allocator.free(journal_detail);

        try self.appendActivityEvent(.activity_failed, id, ActivityType.name, attempt, "exhausted", journal_detail);
        self.recordCausalScheduleDecision(&schedule, "exhausted", causal_detail);
        return true;
    }

    fn recordCausalScheduleDecision(
        self: *WorkflowContext,
        schedule: *Schedule,
        status: []const u8,
        detail: []const u8,
    ) void {
        const store = self.causal_store orelse return;
        _ = store.record(.{
            .kind = .schedule_decision,
            .run_id = self.causal_run_id,
            .label = schedule.labelOrKind(),
            .status = status,
            .redacted_detail = detail,
        }) catch {};
    }
};

fn ActivityReplay(comptime Success: type, comptime Failure: type) type {
    return union(enum) {
        completed: Success,
        failed: Failure,
    };
}

pub fn activityId(activity_name: []const u8, idempotency_key: []const u8) ActivityId {
    var hasher = std.hash.Fnv1a_64.init();
    hasher.update(activity_name);
    hasher.update(":");
    hasher.update(idempotency_key);
    return hasher.final();
}

fn activityEventIdempotencyKey(
    allocator: Allocator,
    kind: journal_mod.WorkflowEventKind,
    id: ActivityId,
    attempt: u32,
) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "activity:{d}:{s}:{d}",
        .{ id, journal_mod.workflowEventKindName(kind), attempt },
    );
}

fn compensationEventIdempotencyKey(
    allocator: Allocator,
    kind: journal_mod.WorkflowEventKind,
    id: CompensationId,
    sequence: JournalSequence,
) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "compensation:{d}:{s}:{d}",
        .{ id, journal_mod.workflowEventKindName(kind), sequence },
    );
}

fn compensationCompleted(
    events: []const journal_mod.WorkflowEvent,
    id: CompensationId,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
) bool {
    for (events) |event| {
        if (event.kind == .compensation_completed and
            event.compensation_id != null and
            event.compensation_id.? == id and
            event.workflow_id == workflow_id and
            event.execution_id == execution_id)
        {
            return true;
        }
    }
    return false;
}

fn runCompensationHandler(comptime handlers: anytype, label: []const u8) !void {
    inline for (handlers) |handler| {
        if (std.mem.eql(u8, handler.label, label)) return handler.run();
    }
    return error.CompensationHandlerNotFound;
}

fn scheduleDecisionDetail(
    allocator: Allocator,
    schedule_attempt: usize,
    delay_ms: u64,
    decision: []const u8,
) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "attempt={d} delay_ms={d} decision={s}",
        .{ schedule_attempt, delay_ms, decision },
    );
}

fn scheduleTerminalDecisionDetail(
    allocator: Allocator,
    schedule_attempt: usize,
    decision: []const u8,
) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "attempt={d} delay_ms=null decision={s}",
        .{ schedule_attempt, decision },
    );
}

fn assertActivityFailureIsErrorSet(comptime Failure: type) void {
    switch (@typeInfo(Failure)) {
        .error_set => {},
        else => @compileError(
            "zigeffect WorkflowContext.activity requires Activity FailureType to be an error set in this milestone.",
        ),
    }
}

fn activityTimeoutError(comptime Failure: type) Failure {
    switch (@typeInfo(Failure)) {
        .error_set => |maybe_errors| {
            const errors = maybe_errors orelse @compileError(
                "zigeffect timed activities require a concrete activity error set.",
            );
            inline for (errors) |err| {
                if (comptime std.mem.eql(u8, err.name, "ActivityTimeout")) {
                    return @field(anyerror, err.name);
                }
            }
            @compileError(
                "zigeffect timed activities require Activity FailureType to include error.ActivityTimeout.",
            );
        },
        else => @compileError(
            "zigeffect timed activities require Activity FailureType to be an error set.",
        ),
    }
}

fn activityFailureFromDetail(comptime Failure: type, detail: []const u8) ?Failure {
    const prefix = "exit.cause.failure:";
    const start = std.mem.indexOf(u8, detail, prefix) orelse return null;
    return errorFromName(Failure, detail[start + prefix.len ..]);
}

fn errorFromName(comptime ErrorSet: type, name: []const u8) ?ErrorSet {
    switch (@typeInfo(ErrorSet)) {
        .error_set => |maybe_errors| {
            const errors = maybe_errors orelse return null;
            inline for (errors) |err| {
                if (std.mem.eql(u8, err.name, name)) return @field(anyerror, err.name);
            }
            return null;
        },
        else => return null,
    }
}

fn workflowFailureDetail(allocator: Allocator, err: anyerror) Allocator.Error![]const u8 {
    const cause = WorkflowStepCause{ .failure = err };
    const exit = WorkflowStepExit{ .cause = cause };
    return switch (exit) {
        .cause => |recorded_cause| switch (recorded_cause) {
            .failure => |failure| std.fmt.allocPrint(
                allocator,
                "exit.cause.failure:{s}",
                .{@errorName(failure)},
            ),
            else => unreachable,
        },
        else => unreachable,
    };
}
