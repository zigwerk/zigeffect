const std = @import("std");
const result_mod = @import("../core/result.zig");
const journal_mod = @import("journal.zig");
const store_mod = @import("store.zig");

pub const Allocator = std.mem.Allocator;
pub const JournalStore = store_mod.JournalStore;
pub const JournalEventBatch = store_mod.JournalEventBatch;
pub const WorkflowId = journal_mod.WorkflowId;
pub const ExecutionId = journal_mod.ExecutionId;
pub const JournalSequence = journal_mod.JournalSequence;
pub const WorkflowStepCause = result_mod.Cause(anyerror);
pub const WorkflowStepExit = result_mod.Exit(void, anyerror);

pub const WorkflowContextError = error{
    RecordedStepParseFailed,
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
            const detail = try workflowStepFailureDetail(self.allocator, err);
            defer self.allocator.free(detail);
            try self.appendStepEvent(.step_failed, label, "failed", detail);
            return err;
        };

        const detail = try std.fmt.allocPrint(self.allocator, "{d}", .{value});
        defer self.allocator.free(detail);
        try self.appendStepEvent(.step_completed, label, "completed", detail);
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
};

fn workflowStepFailureDetail(allocator: Allocator, err: anyerror) Allocator.Error![]const u8 {
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
