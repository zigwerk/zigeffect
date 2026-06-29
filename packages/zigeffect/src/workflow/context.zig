const std = @import("std");
const result_mod = @import("../core/result.zig");
const schedule_mod = @import("../effect/schedule.zig");
const control_mod = @import("../runtime/control.zig");
const causal_mod = @import("../services/causal.zig");
const clock_mod = @import("../services/clock.zig");
const traits_mod = @import("../traits/root.zig");
const deferred_mod = @import("deferred.zig");
const durable_clock_mod = @import("clock.zig");
const journal_mod = @import("journal.zig");
const queue_mod = @import("queue.zig");
const signal_mod = @import("signal.zig");
const store_mod = @import("store.zig");

pub const Allocator = std.mem.Allocator;
pub const CausalStore = causal_mod.CausalStore;
pub const Clock = clock_mod.Clock;
pub const Codec = traits_mod.Codec;
pub const DeferredAwaitResult = deferred_mod.DeferredAwaitResult;
pub const JournalStore = store_mod.JournalStore;
pub const JournalEventBatch = store_mod.JournalEventBatch;
pub const CausalJournalStore = store_mod.CausalJournalStore;
pub const Schedule = schedule_mod.Schedule;
pub const Suspension = control_mod.Suspension;
pub const TimerSleepResult = durable_clock_mod.TimerSleepResult;
pub const SignalWaitResult = signal_mod.SignalWaitResult;
pub const QueueAwaitResult = queue_mod.QueueAwaitResult;
pub const WorkflowId = journal_mod.WorkflowId;
pub const ExecutionId = journal_mod.ExecutionId;
pub const ActivityId = journal_mod.ActivityId;
pub const TimerId = journal_mod.TimerId;
pub const QueueId = journal_mod.QueueId;
pub const CompensationId = journal_mod.CompensationId;
pub const JournalSequence = journal_mod.JournalSequence;
pub const WorkflowStepCause = result_mod.Cause(anyerror);
pub const WorkflowStepExit = result_mod.Exit(void, anyerror);

pub const WorkflowContextError = error{
    CompensationHandlerNotFound,
    RecordedStepParseFailed,
    RecordedActivityFailureParseFailed,
    SignalConsumptionParseFailed,
    SignalReceivedMissing,
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
    causal_journal_store: ?*CausalJournalStore = null,
    next_sequence: JournalSequence,
    replay_events: JournalEventBatch,

    pub fn init(allocator: Allocator, journal_store: JournalStore, options: WorkflowContextOptions) !WorkflowContext {
        var replay_events = try journal_store.readAll(allocator);
        errdefer replay_events.deinit();

        const next_sequence = if (replay_events.events.len == 0)
            1
        else
            replay_events.events[replay_events.events.len - 1].sequence + 1;

        var context = WorkflowContext{
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
        if (options.causal_store) |causal_store| {
            const causal_journal_store = try allocator.create(CausalJournalStore);
            causal_journal_store.* = CausalJournalStore.init(
                allocator,
                journal_store,
                causal_store,
                options.causal_run_id,
            );
            context.causal_journal_store = causal_journal_store;
            context.journal_store = causal_journal_store.asJournalStore();
        }
        return context;
    }

    pub fn deinit(self: *WorkflowContext) void {
        if (self.causal_journal_store) |causal_journal_store| {
            causal_journal_store.deinit();
            self.allocator.destroy(causal_journal_store);
            self.causal_journal_store = null;
        }
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

    pub fn awaitDeferred(
        self: *WorkflowContext,
        label: []const u8,
        result_codec: anytype,
        comptime Failure: type,
    ) !DeferredAwaitResult(@TypeOf(result_codec).ValueType, Failure) {
        const id = deferred_mod.deferredId(label);
        if (try self.recordedDeferred(label, id, result_codec, Failure)) |recorded| return recorded;
        if (!self.deferredExists(id)) {
            try self.appendDeferredEvent(.deferred_created, id, label, "pending", "");
        }
        try self.appendDeferredEvent(.deferred_awaited, id, label, "waiting", "");
        try self.appendDeferredEvent(.workflow_suspended, id, label, "waiting", "deferred");
        return .{ .suspended = .{
            .kind = .deferred,
            .id = id,
            .label = label,
        } };
    }

    pub fn sleep(self: *WorkflowContext, label: []const u8, delay_ms: u64) !TimerSleepResult {
        const now_ms = if (self.clock) |clock| clock.nowMs() else 0;
        const fire_at_ms = std.math.add(u64, now_ms, delay_ms) catch std.math.maxInt(u64);
        return self.sleepUntil(label, fire_at_ms);
    }

    pub fn sleepUntil(self: *WorkflowContext, label: []const u8, fire_at_ms: u64) !TimerSleepResult {
        const id = durable_clock_mod.timerId(label);
        var events = try self.journal_store.readAll(self.allocator);
        defer events.deinit();

        const replay = timerReplayState(events.events, self.workflow_id, self.execution_id, id);
        if (replay.terminal) |terminal| return terminal;

        if (!replay.scheduled) {
            const detail = try timerFireAtDetail(self.allocator, fire_at_ms);
            defer self.allocator.free(detail);
            try self.appendTimerEvent(.timer_scheduled, id, label, "scheduled", detail);
        }
        if (!replay.suspended) {
            try self.appendTimerEvent(.workflow_suspended, id, label, "waiting", "timer");
        }
        return .{ .suspended = .{
            .kind = .timer,
            .id = id,
            .label = label,
        } };
    }

    pub fn waitForSignal(
        self: *WorkflowContext,
        comptime SignalType: type,
        payload_codec: anytype,
    ) !SignalWaitResult(SignalType.PayloadType) {
        var events = try self.journal_store.readAll(self.allocator);
        defer events.deinit();

        if (signalTimedOut(events.events, self.workflow_id, self.execution_id, SignalType.name)) {
            return .timed_out;
        }

        if (try consumedSignalReceivedSequence(events.events, self.workflow_id, self.execution_id, SignalType.name)) |sequence| {
            const received = findSignalReceivedBySequence(events.events, self.workflow_id, self.execution_id, SignalType.name, sequence) orelse
                return error.SignalReceivedMissing;
            return .{ .received = try payload_codec.decodeValue(self.allocator, received.redacted_detail) };
        }

        if (try firstUnconsumedSignal(events.events, self.workflow_id, self.execution_id, SignalType.name)) |received| {
            try self.cancelSignalTimeoutIfPending(SignalType, events.events);
            try self.appendSignalConsumed(SignalType.name, received.sequence);
            return .{ .received = try payload_codec.decodeValue(self.allocator, received.redacted_detail) };
        }

        if (try self.signalTimeoutFired(SignalType, events.events)) |timer_id| {
            try self.appendSignalTimedOut(SignalType.name, timer_id);
            return .timed_out;
        }

        try self.scheduleSignalTimeoutIfNeeded(SignalType, events.events);
        if (!signalSuspensionExists(events.events, self.workflow_id, self.execution_id, SignalType.name)) {
            try self.appendSignalSuspension(SignalType.name);
        }
        return .{ .suspended = .{
            .kind = .signal,
            .id = signal_mod.signalId(SignalType.name),
            .label = SignalType.name,
        } };
    }

    pub fn queue(
        self: *WorkflowContext,
        comptime QueueType: type,
        payload_codec: anytype,
        result_codec: anytype,
        payload: QueueType.PayloadType,
    ) !QueueAwaitResult(QueueType.SuccessType, QueueType.FailureType) {
        const item_id = try QueueType.deriveItemId(self.allocator, payload);
        var events = try self.journal_store.readAll(self.allocator);
        defer events.deinit();

        if (queueCompletedEvent(events.events, self.workflow_id, self.execution_id, item_id)) |event| {
            if (!queueAcked(events.events, self.workflow_id, self.execution_id, item_id)) {
                try self.appendQueueEvent(.queue_acked, item_id, QueueType.name, "acked", "");
            }
            return .{ .completed = try result_codec.decodeValue(self.allocator, event.redacted_detail) };
        }

        if (queueFailedEvent(events.events, self.workflow_id, self.execution_id, item_id)) |event| {
            if (!queueAcked(events.events, self.workflow_id, self.execution_id, item_id)) {
                try self.appendQueueEvent(.queue_acked, item_id, QueueType.name, "acked", "");
            }
            const failure = activityFailureFromDetail(QueueType.FailureType, event.redacted_detail) orelse
                return error.RecordedActivityFailureParseFailed;
            return .{ .failed = failure };
        }

        if (!queueOffered(events.events, self.workflow_id, self.execution_id, item_id)) {
            const encoded = try payload_codec.encodeValue(self.allocator, payload);
            defer self.allocator.free(encoded);
            try self.appendQueueEvent(.queue_offered, item_id, QueueType.name, "offered", encoded);
        }

        if (!queueSuspensionExists(events.events, self.workflow_id, self.execution_id, item_id)) {
            try self.appendQueueEvent(.workflow_suspended, item_id, QueueType.name, "waiting", "queue");
        }

        return .{ .suspended = .{
            .kind = .queue,
            .id = item_id,
            .label = QueueType.name,
        } };
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

    fn appendDeferredEvent(
        self: *WorkflowContext,
        kind: journal_mod.WorkflowEventKind,
        id: journal_mod.DeferredId,
        name: []const u8,
        status: []const u8,
        redacted_detail: []const u8,
    ) !void {
        const idempotency_key = try deferredEventIdempotencyKey(self.allocator, kind, id, self.next_sequence);
        defer self.allocator.free(idempotency_key);
        _ = try self.journal_store.append(.{
            .event = .{
                .sequence = self.next_sequence,
                .kind = kind,
                .workflow_id = self.workflow_id,
                .execution_id = self.execution_id,
                .deferred_id = id,
                .name = name,
                .status = status,
                .redacted_detail = redacted_detail,
                .idempotency_key = idempotency_key,
            },
        });
        self.next_sequence += 1;
    }

    fn appendTimerEvent(
        self: *WorkflowContext,
        kind: journal_mod.WorkflowEventKind,
        id: TimerId,
        name: []const u8,
        status: []const u8,
        redacted_detail: []const u8,
    ) !void {
        const idempotency_key = try timerEventIdempotencyKey(self.allocator, kind, id, self.next_sequence);
        defer self.allocator.free(idempotency_key);
        _ = try self.journal_store.append(.{
            .event = .{
                .sequence = self.next_sequence,
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
        self.next_sequence += 1;
    }

    fn appendQueueEvent(
        self: *WorkflowContext,
        kind: journal_mod.WorkflowEventKind,
        id: QueueId,
        name: []const u8,
        status: []const u8,
        redacted_detail: []const u8,
    ) !void {
        const idempotency_key = try queueEventIdempotencyKey(self.allocator, kind, id, self.next_sequence);
        defer self.allocator.free(idempotency_key);
        _ = try self.journal_store.append(.{
            .event = .{
                .sequence = self.next_sequence,
                .kind = kind,
                .workflow_id = self.workflow_id,
                .execution_id = self.execution_id,
                .queue_id = id,
                .name = name,
                .status = status,
                .redacted_detail = redacted_detail,
                .idempotency_key = idempotency_key,
            },
        });
        self.next_sequence += 1;
    }

    fn appendSignalSuspension(self: *WorkflowContext, name: []const u8) !void {
        const idempotency_key = try signalEventIdempotencyKey(
            self.allocator,
            .workflow_suspended,
            name,
            self.next_sequence,
        );
        defer self.allocator.free(idempotency_key);
        _ = try self.journal_store.append(.{
            .event = .{
                .sequence = self.next_sequence,
                .kind = .workflow_suspended,
                .workflow_id = self.workflow_id,
                .execution_id = self.execution_id,
                .name = name,
                .status = "waiting",
                .redacted_detail = "signal",
                .idempotency_key = idempotency_key,
            },
        });
        self.next_sequence += 1;
    }

    fn scheduleSignalTimeoutIfNeeded(
        self: *WorkflowContext,
        comptime SignalType: type,
        events: []const journal_mod.WorkflowEvent,
    ) !void {
        const timeout_ms = SignalType.metadata().timeout_ms orelse return;
        const label = try signalTimeoutLabel(self.allocator, SignalType.name);
        defer self.allocator.free(label);

        const id = durable_clock_mod.timerId(label);
        const replay = timerReplayState(events, self.workflow_id, self.execution_id, id);
        if (replay.scheduled or replay.terminal != null) return;

        const now_ms = if (self.clock) |clock| clock.nowMs() else 0;
        const fire_at_ms = std.math.add(u64, now_ms, timeout_ms) catch std.math.maxInt(u64);
        const detail = try timerFireAtDetail(self.allocator, fire_at_ms);
        defer self.allocator.free(detail);
        try self.appendTimerEvent(.timer_scheduled, id, label, "scheduled", detail);
    }

    fn signalTimeoutFired(
        self: *WorkflowContext,
        comptime SignalType: type,
        events: []const journal_mod.WorkflowEvent,
    ) !?TimerId {
        _ = SignalType.metadata().timeout_ms orelse return null;
        const label = try signalTimeoutLabel(self.allocator, SignalType.name);
        defer self.allocator.free(label);

        const id = durable_clock_mod.timerId(label);
        const replay = timerReplayState(events, self.workflow_id, self.execution_id, id);
        if (replay.terminal) |terminal| switch (terminal) {
            .fired => return id,
            .cancelled, .suspended => return null,
        };
        return null;
    }

    fn cancelSignalTimeoutIfPending(
        self: *WorkflowContext,
        comptime SignalType: type,
        events: []const journal_mod.WorkflowEvent,
    ) !void {
        _ = SignalType.metadata().timeout_ms orelse return;
        const label = try signalTimeoutLabel(self.allocator, SignalType.name);
        defer self.allocator.free(label);

        const id = durable_clock_mod.timerId(label);
        const replay = timerReplayState(events, self.workflow_id, self.execution_id, id);
        if (!replay.scheduled or replay.terminal != null) return;
        try self.appendTimerEvent(.timer_cancelled, id, label, "cancelled", "");
    }

    fn appendSignalConsumed(self: *WorkflowContext, name: []const u8, received_sequence: JournalSequence) !void {
        const detail = try receivedSequenceDetail(self.allocator, received_sequence);
        defer self.allocator.free(detail);
        const idempotency_key = try signalConsumedIdempotencyKey(
            self.allocator,
            name,
            received_sequence,
        );
        defer self.allocator.free(idempotency_key);
        _ = try self.journal_store.append(.{
            .event = .{
                .sequence = self.next_sequence,
                .kind = .signal_consumed,
                .workflow_id = self.workflow_id,
                .execution_id = self.execution_id,
                .name = name,
                .status = "received",
                .redacted_detail = detail,
                .idempotency_key = idempotency_key,
            },
        });
        self.next_sequence += 1;
    }

    fn appendSignalTimedOut(self: *WorkflowContext, name: []const u8, timer_id: TimerId) !void {
        const detail = try signalTimeoutDetail(self.allocator, timer_id);
        defer self.allocator.free(detail);
        const idempotency_key = try signalTimedOutIdempotencyKey(
            self.allocator,
            name,
            timer_id,
        );
        defer self.allocator.free(idempotency_key);
        _ = try self.journal_store.append(.{
            .event = .{
                .sequence = self.next_sequence,
                .kind = .signal_consumed,
                .workflow_id = self.workflow_id,
                .execution_id = self.execution_id,
                .name = name,
                .status = "timed_out",
                .redacted_detail = detail,
                .idempotency_key = idempotency_key,
            },
        });
        self.next_sequence += 1;
    }

    fn deferredExists(self: *const WorkflowContext, id: journal_mod.DeferredId) bool {
        for (self.replay_events.events) |event| {
            if (event.deferred_id != null and
                event.deferred_id.? == id and
                event.workflow_id == self.workflow_id and
                event.execution_id == self.execution_id and
                event.kind == .deferred_created)
            {
                return true;
            }
        }
        return false;
    }

    fn recordedDeferred(
        self: *const WorkflowContext,
        label: []const u8,
        id: journal_mod.DeferredId,
        result_codec: anytype,
        comptime Failure: type,
    ) !?DeferredAwaitResult(@TypeOf(result_codec).ValueType, Failure) {
        _ = label;
        var index = self.replay_events.events.len;
        while (index > 0) {
            index -= 1;
            const event = self.replay_events.events[index];
            if (event.deferred_id != null and
                event.deferred_id.? == id and
                event.workflow_id == self.workflow_id and
                event.execution_id == self.execution_id)
            {
                switch (event.kind) {
                    .deferred_completed => return .{
                        .completed = try result_codec.decodeValue(self.allocator, event.redacted_detail),
                    },
                    .deferred_failed => {
                        const failure = activityFailureFromDetail(Failure, event.redacted_detail) orelse
                            return error.RecordedActivityFailureParseFailed;
                        return .{ .failed = failure };
                    },
                    .deferred_cancelled => return .{ .cancelled = event.redacted_detail },
                    else => {},
                }
            }
        }
        return null;
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

fn deferredEventIdempotencyKey(
    allocator: Allocator,
    kind: journal_mod.WorkflowEventKind,
    id: journal_mod.DeferredId,
    sequence: JournalSequence,
) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "deferred:{d}:{s}:{d}",
        .{ id, journal_mod.workflowEventKindName(kind), sequence },
    );
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

fn timerFireAtDetail(allocator: Allocator, fire_at_ms: u64) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "fire_at_ms={d}", .{fire_at_ms});
}

fn queueEventIdempotencyKey(
    allocator: Allocator,
    kind: journal_mod.WorkflowEventKind,
    id: QueueId,
    sequence: JournalSequence,
) Allocator.Error![]const u8 {
    if (kind == .queue_offered) {
        return std.fmt.allocPrint(allocator, "queue:{d}:offered", .{id});
    }
    if (kind == .queue_acked) {
        return std.fmt.allocPrint(allocator, "queue:{d}:acked", .{id});
    }
    return std.fmt.allocPrint(
        allocator,
        "queue:{d}:{s}:{d}",
        .{ id, journal_mod.workflowEventKindName(kind), sequence },
    );
}

fn signalEventIdempotencyKey(
    allocator: Allocator,
    kind: journal_mod.WorkflowEventKind,
    name: []const u8,
    sequence: JournalSequence,
) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "signal:{s}:{s}:{d}",
        .{ name, journal_mod.workflowEventKindName(kind), sequence },
    );
}

fn signalConsumedIdempotencyKey(
    allocator: Allocator,
    name: []const u8,
    received_sequence: JournalSequence,
) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "signal:{s}:consumed:{d}",
        .{ name, received_sequence },
    );
}

fn receivedSequenceDetail(allocator: Allocator, received_sequence: JournalSequence) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "received_sequence={d}", .{received_sequence});
}

fn signalTimedOutIdempotencyKey(
    allocator: Allocator,
    name: []const u8,
    timer_id: TimerId,
) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "signal:{s}:timed_out:{d}",
        .{ name, timer_id },
    );
}

fn signalTimeoutDetail(allocator: Allocator, timer_id: TimerId) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "timer_id={d}", .{timer_id});
}

fn signalTimeoutLabel(allocator: Allocator, name: []const u8) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "signal:{s}:timeout", .{name});
}

const TimerReplay = struct {
    scheduled: bool = false,
    suspended: bool = false,
    terminal: ?TimerSleepResult = null,
};

fn timerReplayState(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    id: TimerId,
) TimerReplay {
    var replay = TimerReplay{};
    for (events) |event| {
        if (event.workflow_id != workflow_id or event.execution_id != execution_id) continue;
        if (event.timer_id == null or event.timer_id.? != id) continue;

        switch (event.kind) {
            .timer_scheduled => replay.scheduled = true,
            .workflow_suspended => replay.suspended = true,
            .timer_fired => replay.terminal = .fired,
            .timer_cancelled => replay.terminal = .cancelled,
            else => {},
        }
    }
    return replay;
}

fn signalSuspensionExists(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    name: []const u8,
) bool {
    var suspended = false;
    for (events) |event| {
        if (event.workflow_id != workflow_id or event.execution_id != execution_id) continue;
        switch (event.kind) {
            .workflow_suspended => {
                if (std.mem.eql(u8, event.name, name) and
                    std.mem.eql(u8, event.redacted_detail, "signal"))
                {
                    suspended = true;
                }
            },
            .workflow_resumed => suspended = false,
            else => {},
        }
    }
    return suspended;
}

fn queueOffered(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    id: QueueId,
) bool {
    for (events) |event| {
        if (event.workflow_id == workflow_id and
            event.execution_id == execution_id and
            event.kind == .queue_offered and
            event.queue_id != null and
            event.queue_id.? == id)
        {
            return true;
        }
    }
    return false;
}

fn queueCompletedEvent(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    id: QueueId,
) ?journal_mod.WorkflowEvent {
    var completed: ?journal_mod.WorkflowEvent = null;
    for (events) |event| {
        if (event.workflow_id == workflow_id and
            event.execution_id == execution_id and
            event.kind == .queue_completed and
            event.queue_id != null and
            event.queue_id.? == id)
        {
            completed = event;
        }
    }
    return completed;
}

fn queueFailedEvent(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    id: QueueId,
) ?journal_mod.WorkflowEvent {
    var failed: ?journal_mod.WorkflowEvent = null;
    for (events) |event| {
        if (event.workflow_id == workflow_id and
            event.execution_id == execution_id and
            event.kind == .queue_failed and
            event.queue_id != null and
            event.queue_id.? == id)
        {
            failed = event;
        }
    }
    return failed;
}

fn queueAcked(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    id: QueueId,
) bool {
    for (events) |event| {
        if (event.workflow_id == workflow_id and
            event.execution_id == execution_id and
            event.kind == .queue_acked and
            event.queue_id != null and
            event.queue_id.? == id)
        {
            return true;
        }
    }
    return false;
}

fn queueSuspensionExists(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    id: QueueId,
) bool {
    var suspended = false;
    for (events) |event| {
        if (event.workflow_id != workflow_id or event.execution_id != execution_id) continue;
        switch (event.kind) {
            .workflow_suspended => {
                if (event.queue_id != null and
                    event.queue_id.? == id and
                    std.mem.eql(u8, event.redacted_detail, "queue"))
                {
                    suspended = true;
                }
            },
            .workflow_resumed => suspended = false,
            else => {},
        }
    }
    return suspended;
}

fn consumedSignalReceivedSequence(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    name: []const u8,
) !?JournalSequence {
    var consumed_sequence: ?JournalSequence = null;
    for (events) |event| {
        if (event.workflow_id != workflow_id or event.execution_id != execution_id) continue;
        if (event.kind != .signal_consumed or !std.mem.eql(u8, event.name, name)) continue;
        if (!std.mem.eql(u8, event.status, "received")) continue;
        consumed_sequence = parseReceivedSequence(event.redacted_detail) catch
            return error.SignalConsumptionParseFailed;
    }
    return consumed_sequence;
}

fn signalTimedOut(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    name: []const u8,
) bool {
    for (events) |event| {
        if (event.workflow_id == workflow_id and
            event.execution_id == execution_id and
            event.kind == .signal_consumed and
            std.mem.eql(u8, event.name, name) and
            std.mem.eql(u8, event.status, "timed_out"))
        {
            return true;
        }
    }
    return false;
}

fn firstUnconsumedSignal(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    name: []const u8,
) !?journal_mod.WorkflowEvent {
    for (events) |event| {
        if (event.workflow_id != workflow_id or event.execution_id != execution_id) continue;
        if (event.kind != .signal_received or !std.mem.eql(u8, event.name, name)) continue;
        if (!try signalReceivedSequenceConsumed(events, workflow_id, execution_id, name, event.sequence)) {
            return event;
        }
    }
    return null;
}

fn signalReceivedSequenceConsumed(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    name: []const u8,
    received_sequence: JournalSequence,
) !bool {
    for (events) |event| {
        if (event.workflow_id != workflow_id or event.execution_id != execution_id) continue;
        if (event.kind != .signal_consumed or !std.mem.eql(u8, event.name, name)) continue;
        if (!std.mem.eql(u8, event.status, "received")) continue;
        const consumed_sequence = parseReceivedSequence(event.redacted_detail) catch
            return error.SignalConsumptionParseFailed;
        if (consumed_sequence == received_sequence) return true;
    }
    return false;
}

fn findSignalReceivedBySequence(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    name: []const u8,
    received_sequence: JournalSequence,
) ?journal_mod.WorkflowEvent {
    for (events) |event| {
        if (event.workflow_id == workflow_id and
            event.execution_id == execution_id and
            event.sequence == received_sequence and
            event.kind == .signal_received and
            std.mem.eql(u8, event.name, name))
        {
            return event;
        }
    }
    return null;
}

fn parseReceivedSequence(detail: []const u8) !JournalSequence {
    const prefix = "received_sequence=";
    if (!std.mem.startsWith(u8, detail, prefix)) return error.SignalConsumptionParseFailed;
    return std.fmt.parseInt(JournalSequence, detail[prefix.len..], 10) catch
        error.SignalConsumptionParseFailed;
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
