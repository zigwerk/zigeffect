const std = @import("std");
const result_mod = @import("../core/result.zig");
const clock_mod = @import("../services/clock.zig");
const journal_mod = @import("journal.zig");
const store_mod = @import("store.zig");

pub const Allocator = std.mem.Allocator;
pub const Clock = clock_mod.Clock;
pub const ExecutionId = journal_mod.ExecutionId;
pub const JournalSequence = journal_mod.JournalSequence;
pub const JournalStore = store_mod.JournalStore;
pub const QueueId = journal_mod.QueueId;
pub const WorkflowId = journal_mod.WorkflowId;
pub const QueueFailureCause = result_mod.Cause(anyerror);
pub const QueueFailureExit = result_mod.Exit(void, anyerror);

pub const QueueMetadata = struct {
    name: []const u8,
    payload_type_name: []const u8,
    success_type_name: []const u8,
    failure_type_name: []const u8,
    has_idempotency_key: bool,
    claim_timeout_ms: ?u64,
    max_concurrency: usize,
};

pub fn QueueClaim(comptime Payload: type) type {
    return struct {
        item_id: QueueId,
        name: []const u8,
        payload: Payload,
        attempt: u32,
    };
}

pub fn QueueAwaitResult(comptime Success: type, comptime Failure: type) type {
    return union(enum) {
        completed: Success,
        failed: Failure,
        suspended: @import("../runtime/control.zig").Suspension,
    };
}

pub const QueueOfferResult = struct {
    item_id: QueueId,
    offered: bool,
};

fn hasValue(comptime value: anytype) bool {
    return @TypeOf(value) != @TypeOf(null);
}

fn idempotencyKeyFunctionInfo(comptime callback: anytype) std.builtin.Type.Fn {
    return switch (@typeInfo(@TypeOf(callback))) {
        .@"fn" => |fn_info| fn_info,
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => |fn_info| fn_info,
            else => @compileError(
                "zigeffect invalid queue idempotency key callback\n\n" ++
                    "Expected: fn (std.mem.Allocator, Payload) anyerror![]const u8.",
            ),
        },
        else => @compileError(
            "zigeffect invalid queue idempotency key callback\n\n" ++
                "Expected: fn (std.mem.Allocator, Payload) anyerror![]const u8.",
        ),
    };
}

fn assertIdempotencyKeyCallback(comptime Payload: type, comptime callback: anytype) void {
    const fn_info = idempotencyKeyFunctionInfo(callback);
    if (fn_info.params.len != 2) {
        @compileError(
            "zigeffect invalid queue idempotency key callback\n\n" ++
                "Expected exactly two parameters: std.mem.Allocator, Payload.",
        );
    }
    if (fn_info.params[0].type == null or fn_info.params[0].type.? != Allocator) {
        @compileError(
            "zigeffect invalid queue idempotency key callback\n\n" ++
                "First parameter must be std.mem.Allocator.",
        );
    }
    if (fn_info.params[1].type == null or fn_info.params[1].type.? != Payload) {
        @compileError(
            "zigeffect invalid queue idempotency key callback\n\n" ++
                "Second parameter must be " ++ @typeName(Payload) ++ ".",
        );
    }
    const ReturnType = fn_info.return_type orelse @compileError(
        "zigeffect invalid queue idempotency key callback\n\n" ++
            "Expected return type: anyerror![]const u8.",
    );
    switch (@typeInfo(ReturnType)) {
        .error_union => |error_union| {
            if (error_union.payload != []const u8) {
                @compileError(
                    "zigeffect invalid queue idempotency key callback\n\n" ++
                        "Expected return payload: []const u8.",
                );
            }
        },
        else => @compileError(
            "zigeffect invalid queue idempotency key callback\n\n" ++
                "Expected return type: anyerror![]const u8.",
        ),
    }
}

fn QueueDefinition(
    comptime Name: []const u8,
    comptime Payload: type,
    comptime Success: type,
    comptime Failure: type,
    comptime IdempotencyKeyFn: anytype,
    comptime ClaimTimeoutMs: ?u64,
    comptime MaxConcurrency: usize,
) type {
    return struct {
        const Self = @This();

        pub const name = Name;
        pub const PayloadType = Payload;
        pub const SuccessType = Success;
        pub const FailureType = Failure;

        pub fn metadata() QueueMetadata {
            return .{
                .name = Name,
                .payload_type_name = @typeName(Payload),
                .success_type_name = @typeName(Success),
                .failure_type_name = @typeName(Failure),
                .has_idempotency_key = hasValue(IdempotencyKeyFn),
                .claim_timeout_ms = ClaimTimeoutMs,
                .max_concurrency = MaxConcurrency,
            };
        }

        pub fn withIdempotencyKey(comptime callback: anytype) type {
            assertIdempotencyKeyCallback(Payload, callback);
            return QueueDefinition(Name, Payload, Success, Failure, callback, ClaimTimeoutMs, MaxConcurrency);
        }

        pub fn withClaimTimeoutMs(comptime timeout_ms: u64) type {
            return QueueDefinition(Name, Payload, Success, Failure, IdempotencyKeyFn, timeout_ms, MaxConcurrency);
        }

        pub fn withMaxConcurrency(comptime max_concurrency: usize) type {
            if (max_concurrency == 0) {
                @compileError("zigeffect queue max concurrency must be greater than zero.");
            }
            return QueueDefinition(Name, Payload, Success, Failure, IdempotencyKeyFn, ClaimTimeoutMs, max_concurrency);
        }

        pub fn idempotencyKey(allocator: Allocator, payload: Payload) ![]const u8 {
            if (comptime !hasValue(IdempotencyKeyFn)) {
                @compileError(
                    "zigeffect queue idempotency key callback missing\n\n" ++
                        "Use Queue(...).withIdempotencyKey(callback).",
                );
            }
            return IdempotencyKeyFn(allocator, payload);
        }

        pub fn deriveItemId(allocator: Allocator, payload: Payload) !QueueId {
            const key = try Self.idempotencyKey(allocator, payload);
            defer allocator.free(key);
            return queueItemId(Name, key);
        }
    };
}

pub fn Queue(
    comptime Name: []const u8,
    comptime Payload: type,
    comptime Success: type,
    comptime Failure: type,
) type {
    return QueueDefinition(Name, Payload, Success, Failure, null, null, 1);
}

pub const DurableQueue = struct {
    allocator: Allocator,
    journal_store: JournalStore,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    clock: ?*Clock = null,

    pub fn init(
        allocator: Allocator,
        journal_store: JournalStore,
        workflow_id: WorkflowId,
        execution_id: ExecutionId,
    ) DurableQueue {
        return .{
            .allocator = allocator,
            .journal_store = journal_store,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
        };
    }

    pub fn initWithClock(
        allocator: Allocator,
        journal_store: JournalStore,
        workflow_id: WorkflowId,
        execution_id: ExecutionId,
        clock: *Clock,
    ) DurableQueue {
        return .{
            .allocator = allocator,
            .journal_store = journal_store,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
            .clock = clock,
        };
    }

    pub fn offer(
        self: *DurableQueue,
        comptime QueueType: type,
        payload_codec: anytype,
        payload: QueueType.PayloadType,
    ) !QueueOfferResult {
        const item_id = try QueueType.deriveItemId(self.allocator, payload);

        var events = try self.journal_store.readAll(self.allocator);
        defer events.deinit();
        if (queueItemOffered(events.events, self.workflow_id, self.execution_id, item_id)) {
            return .{ .item_id = item_id, .offered = false };
        }

        const encoded = try payload_codec.encodeValue(self.allocator, payload);
        defer self.allocator.free(encoded);

        var next_sequence_value = try nextSequence(events.events);
        const appended = try appendQueueEvent(
            self,
            .queue_offered,
            item_id,
            QueueType.name,
            "offered",
            encoded,
            0,
            &next_sequence_value,
        );
        return .{ .item_id = item_id, .offered = appended };
    }

    pub fn claim(
        self: *DurableQueue,
        comptime QueueType: type,
        payload_codec: anytype,
        worker_id: []const u8,
    ) !?QueueClaim(QueueType.PayloadType) {
        var events = try self.journal_store.readAll(self.allocator);
        defer events.deinit();

        if (activeClaimCount(events.events, self.workflow_id, self.execution_id, QueueType.name) >= QueueType.metadata().max_concurrency) {
            return null;
        }

        for (events.events) |event| {
            if (!isQueueEvent(event, self.workflow_id, self.execution_id, QueueType.name)) continue;
            if (event.kind != .queue_offered) continue;
            const item_id = event.queue_id orelse continue;
            const status = latestQueueStatus(events.events, self.workflow_id, self.execution_id, item_id);
            if (status != .offered and status != .retry_ready) continue;

            const attempt = queueClaimAttempt(events.events, self.workflow_id, self.execution_id, item_id) + 1;
            const deadline_ms = claimDeadlineMs(QueueType.metadata().claim_timeout_ms, self.clock);
            const detail = try claimDetail(self.allocator, worker_id, deadline_ms, attempt);
            defer self.allocator.free(detail);

            var next_sequence_value = try nextSequence(events.events);
            _ = try appendQueueEvent(
                self,
                .queue_claimed,
                item_id,
                QueueType.name,
                "claimed",
                detail,
                attempt,
                &next_sequence_value,
            );

            return .{
                .item_id = item_id,
                .name = QueueType.name,
                .payload = try payload_codec.decodeValue(self.allocator, event.redacted_detail),
                .attempt = attempt,
            };
        }

        return null;
    }

    pub fn retryExpiredClaims(self: *DurableQueue, comptime QueueType: type) !usize {
        const clock = self.clock orelse return 0;
        const now_ms = clock.nowMs();

        var events = try self.journal_store.readAll(self.allocator);
        defer events.deinit();

        var next_sequence_value = try nextSequence(events.events);
        var retried: usize = 0;
        for (events.events) |event| {
            if (!isQueueEvent(event, self.workflow_id, self.execution_id, QueueType.name)) continue;
            if (event.kind != .queue_claimed) continue;
            const item_id = event.queue_id.?;
            if (latestQueueStatus(events.events, self.workflow_id, self.execution_id, item_id) != .claimed) continue;
            const deadline_ms = parseClaimDeadlineMs(event.redacted_detail) orelse continue;
            if (deadline_ms > now_ms) continue;

            const detail = try retryDetail(self.allocator, event.sequence, event.attempt);
            defer self.allocator.free(detail);
            _ = try appendQueueEvent(
                self,
                .queue_retry_scheduled,
                item_id,
                QueueType.name,
                "retry_ready",
                detail,
                event.attempt,
                &next_sequence_value,
            );
            retried += 1;
        }
        return retried;
    }

    pub fn complete(
        self: *DurableQueue,
        comptime QueueType: type,
        item_id: QueueId,
        result_codec: anytype,
        value: QueueType.SuccessType,
    ) !void {
        var events = try self.journal_store.readAll(self.allocator);
        defer events.deinit();

        const status = latestQueueStatus(events.events, self.workflow_id, self.execution_id, item_id);
        if (status == .completed or status == .failed or status == .acked) return;

        const encoded = try result_codec.encodeValue(self.allocator, value);
        defer self.allocator.free(encoded);

        var next_sequence_value = try nextSequence(events.events);
        _ = try appendQueueEvent(
            self,
            .queue_completed,
            item_id,
            QueueType.name,
            "completed",
            encoded,
            0,
            &next_sequence_value,
        );

        if (workflowIsSuspended(events.events, self.workflow_id, self.execution_id)) {
            _ = try appendQueueEvent(
                self,
                .workflow_resumed,
                item_id,
                QueueType.name,
                "running",
                "queue",
                0,
                &next_sequence_value,
            );
        }
    }

    pub fn fail(
        self: *DurableQueue,
        comptime QueueType: type,
        item_id: QueueId,
        err: QueueType.FailureType,
    ) !void {
        var events = try self.journal_store.readAll(self.allocator);
        defer events.deinit();

        const status = latestQueueStatus(events.events, self.workflow_id, self.execution_id, item_id);
        if (status == .completed or status == .failed or status == .acked) return;

        const detail = try queueFailureDetail(self.allocator, err);
        defer self.allocator.free(detail);

        var next_sequence_value = try nextSequence(events.events);
        _ = try appendQueueEvent(
            self,
            .queue_failed,
            item_id,
            QueueType.name,
            "failed",
            detail,
            0,
            &next_sequence_value,
        );

        if (workflowIsSuspended(events.events, self.workflow_id, self.execution_id)) {
            _ = try appendQueueEvent(
                self,
                .workflow_resumed,
                item_id,
                QueueType.name,
                "running",
                "queue",
                0,
                &next_sequence_value,
            );
        }
    }
};

pub fn queueItemId(queue_name: []const u8, idempotency_key: []const u8) QueueId {
    var hasher = std.hash.Fnv1a_64.init();
    hasher.update(queue_name);
    hasher.update(":");
    hasher.update(idempotency_key);
    return hasher.final();
}

fn queueItemOffered(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    item_id: QueueId,
) bool {
    for (events) |event| {
        if (event.workflow_id == workflow_id and
            event.execution_id == execution_id and
            event.kind == .queue_offered and
            event.queue_id != null and
            event.queue_id.? == item_id)
        {
            return true;
        }
    }
    return false;
}

const RuntimeQueueStatus = enum {
    offered,
    claimed,
    completed,
    failed,
    retry_ready,
    acked,
};

fn isQueueEvent(
    event: journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    name: []const u8,
) bool {
    return event.workflow_id == workflow_id and
        event.execution_id == execution_id and
        event.queue_id != null and
        std.mem.eql(u8, event.name, name);
}

fn activeClaimCount(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    name: []const u8,
) usize {
    var count: usize = 0;
    for (events) |event| {
        if (!isQueueEvent(event, workflow_id, execution_id, name)) continue;
        if (event.kind != .queue_offered) continue;
        const item_id = event.queue_id.?;
        if (latestQueueStatus(events, workflow_id, execution_id, item_id) == .claimed) {
            count += 1;
        }
    }
    return count;
}

fn latestQueueStatus(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    item_id: QueueId,
) RuntimeQueueStatus {
    var status = RuntimeQueueStatus.offered;
    for (events) |event| {
        if (event.workflow_id != workflow_id or event.execution_id != execution_id) continue;
        if (event.queue_id == null or event.queue_id.? != item_id) continue;
        status = switch (event.kind) {
            .queue_offered => .offered,
            .queue_claimed => .claimed,
            .queue_completed => .completed,
            .queue_failed => .failed,
            .queue_retry_scheduled => .retry_ready,
            .queue_acked => .acked,
            else => status,
        };
    }
    return status;
}

fn queueClaimAttempt(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    item_id: QueueId,
) u32 {
    var attempt: u32 = 0;
    for (events) |event| {
        if (event.workflow_id == workflow_id and
            event.execution_id == execution_id and
            event.queue_id != null and
            event.queue_id.? == item_id and
            event.kind == .queue_claimed and
            event.attempt > attempt)
        {
            attempt = event.attempt;
        }
    }
    return attempt;
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

fn appendQueueEvent(
    self: *DurableQueue,
    kind: journal_mod.WorkflowEventKind,
    item_id: QueueId,
    name: []const u8,
    status: []const u8,
    redacted_detail: []const u8,
    attempt: u32,
    next_sequence_value: *JournalSequence,
) !bool {
    const idempotency_key = try queueEventIdempotencyKey(
        self.allocator,
        kind,
        item_id,
        next_sequence_value.*,
    );
    defer self.allocator.free(idempotency_key);

    _ = self.journal_store.append(.{
        .expected_next_sequence = next_sequence_value.*,
        .event = .{
            .sequence = next_sequence_value.*,
            .kind = kind,
            .workflow_id = self.workflow_id,
            .execution_id = self.execution_id,
            .queue_id = item_id,
            .attempt = attempt,
            .name = name,
            .status = status,
            .redacted_detail = redacted_detail,
            .idempotency_key = idempotency_key,
        },
    }) catch |err| switch (err) {
        error.DuplicateEvent => return false,
        else => return err,
    };
    try advanceSequence(next_sequence_value);
    return true;
}

fn queueEventIdempotencyKey(
    allocator: Allocator,
    kind: journal_mod.WorkflowEventKind,
    item_id: QueueId,
    sequence: JournalSequence,
) Allocator.Error![]const u8 {
    if (kind == .queue_offered) {
        return std.fmt.allocPrint(allocator, "queue:{d}:offered", .{item_id});
    }
    return std.fmt.allocPrint(
        allocator,
        "queue:{d}:{s}:{d}",
        .{ item_id, journal_mod.workflowEventKindName(kind), sequence },
    );
}

fn claimDetail(
    allocator: Allocator,
    worker_id: []const u8,
    claim_deadline_ms: ?u64,
    attempt: u32,
) Allocator.Error![]const u8 {
    if (claim_deadline_ms) |deadline| {
        return std.fmt.allocPrint(
            allocator,
            "worker={s} claim_deadline_ms={d} attempt={d}",
            .{ worker_id, deadline, attempt },
        );
    }
    return std.fmt.allocPrint(
        allocator,
        "worker={s} claim_deadline_ms=null attempt={d}",
        .{ worker_id, attempt },
    );
}

fn retryDetail(
    allocator: Allocator,
    claim_sequence: JournalSequence,
    attempt: u32,
) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "claim_sequence={d} attempt={d}",
        .{ claim_sequence, attempt },
    );
}

fn claimDeadlineMs(timeout_ms: ?u64, maybe_clock: ?*Clock) ?u64 {
    const timeout = timeout_ms orelse return null;
    const clock = maybe_clock orelse return null;
    return std.math.add(u64, clock.nowMs(), timeout) catch std.math.maxInt(u64);
}

fn parseClaimDeadlineMs(detail: []const u8) ?u64 {
    const prefix = "claim_deadline_ms=";
    const start = std.mem.indexOf(u8, detail, prefix) orelse return null;
    const value_start = start + prefix.len;
    const value_end = std.mem.indexOfScalarPos(u8, detail, value_start, ' ') orelse detail.len;
    const value = detail[value_start..value_end];
    if (std.mem.eql(u8, value, "null")) return null;
    return std.fmt.parseInt(u64, value, 10) catch null;
}

fn queueFailureDetail(allocator: Allocator, err: anyerror) Allocator.Error![]const u8 {
    const cause = QueueFailureCause{ .failure = err };
    const exit = QueueFailureExit{ .cause = cause };
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

fn workflowIsSuspended(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
) bool {
    var suspended = false;
    for (events) |event| {
        if (event.workflow_id != workflow_id or event.execution_id != execution_id) continue;
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
