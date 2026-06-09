const std = @import("std");
const result_mod = @import("../core/result.zig");
const traits_mod = @import("../traits/root.zig");
const journal_mod = @import("journal.zig");
const store_mod = @import("store.zig");

pub const Allocator = std.mem.Allocator;
pub const Codec = traits_mod.Codec;
pub const JournalStore = store_mod.JournalStore;
pub const JournalEventBatch = store_mod.JournalEventBatch;
pub const WorkflowId = journal_mod.WorkflowId;
pub const ExecutionId = journal_mod.ExecutionId;
pub const ActivityId = journal_mod.ActivityId;
pub const JournalSequence = journal_mod.JournalSequence;
pub const WorkflowStepCause = result_mod.Cause(anyerror);
pub const WorkflowStepExit = result_mod.Exit(void, anyerror);

pub const WorkflowContextError = error{
    RecordedStepParseFailed,
    RecordedActivityFailureParseFailed,
};

pub const WorkflowContextOptions = struct {
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
};

pub const WorkflowContext = struct {
    allocator: Allocator,
    journal_store: JournalStore,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
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

        const attempt: u32 = 1;
        try self.appendActivityEvent(.activity_scheduled, id, ActivityType.name, attempt, "scheduled", "");
        try self.appendActivityEvent(.activity_started, id, ActivityType.name, attempt, "running", "");

        const value = run_fn(payload) catch |err| {
            const detail = try workflowFailureDetail(self.allocator, err);
            defer self.allocator.free(detail);
            try self.appendActivityEvent(.activity_failed, id, ActivityType.name, attempt, "failed", detail);
            return err;
        };
        const encoded = try result_codec.encodeValue(self.allocator, value);
        defer self.allocator.free(encoded);
        try self.appendActivityEvent(.activity_completed, id, ActivityType.name, attempt, "completed", encoded);
        return value;
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

fn assertActivityFailureIsErrorSet(comptime Failure: type) void {
    switch (@typeInfo(Failure)) {
        .error_set => {},
        else => @compileError(
            "zigeffect WorkflowContext.activity requires Activity FailureType to be an error set in this milestone.",
        ),
    }
}

fn activityFailureFromDetail(comptime Failure: type, detail: []const u8) ?Failure {
    const prefix = "exit.cause.failure:";
    if (!std.mem.startsWith(u8, detail, prefix)) return null;
    return errorFromName(Failure, detail[prefix.len..]);
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
