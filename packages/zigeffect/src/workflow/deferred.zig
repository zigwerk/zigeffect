const std = @import("std");
const result_mod = @import("../core/result.zig");
const journal_mod = @import("journal.zig");
const store_mod = @import("store.zig");

pub const Allocator = std.mem.Allocator;
pub const DeferredId = journal_mod.DeferredId;
pub const ExecutionId = journal_mod.ExecutionId;
pub const JournalStore = store_mod.JournalStore;
pub const WorkflowEvent = journal_mod.WorkflowEvent;
pub const WorkflowId = journal_mod.WorkflowId;
pub const DeferredFailureCause = result_mod.Cause(anyerror);
pub const DeferredFailureExit = result_mod.Exit(void, anyerror);

pub fn DeferredAwaitResult(comptime Success: type, comptime Failure: type) type {
    return union(enum) {
        completed: Success,
        failed: Failure,
        cancelled: []const u8,
        suspended: @import("../runtime/control.zig").Suspension,
    };
}

pub const DurableDeferred = struct {
    allocator: Allocator,
    journal_store: JournalStore,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,

    pub fn init(
        allocator: Allocator,
        journal_store: JournalStore,
        workflow_id: WorkflowId,
        execution_id: ExecutionId,
    ) DurableDeferred {
        return .{
            .allocator = allocator,
            .journal_store = journal_store,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
        };
    }

    pub fn complete(
        self: *DurableDeferred,
        label: []const u8,
        codec: anytype,
        value: @TypeOf(codec).ValueType,
    ) !void {
        const id = deferredId(label);
        if (try self.hasTerminal(id)) return;

        const encoded = try codec.encodeValue(self.allocator, value);
        defer self.allocator.free(encoded);
        try self.appendDeferredEvent(.deferred_completed, id, label, "completed", encoded);
    }

    pub fn fail(self: *DurableDeferred, label: []const u8, err: anyerror) !void {
        const id = deferredId(label);
        if (try self.hasTerminal(id)) return;

        const detail = try deferredFailureDetail(self.allocator, err);
        defer self.allocator.free(detail);
        try self.appendDeferredEvent(.deferred_failed, id, label, "failed", detail);
    }

    pub fn cancel(self: *DurableDeferred, label: []const u8, reason: []const u8) !void {
        const id = deferredId(label);
        if (try self.hasTerminal(id)) return;
        try self.appendDeferredEvent(.deferred_cancelled, id, label, "cancelled", reason);
    }

    fn appendDeferredEvent(
        self: *DurableDeferred,
        kind: journal_mod.WorkflowEventKind,
        id: DeferredId,
        name: []const u8,
        status: []const u8,
        redacted_detail: []const u8,
    ) !void {
        const sequence = try self.nextJournalSequence();
        const idempotency_key = try deferredEventIdempotencyKey(self.allocator, kind, id, sequence);
        defer self.allocator.free(idempotency_key);
        _ = try self.journal_store.append(.{
            .event = .{
                .sequence = sequence,
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
    }

    fn hasTerminal(self: *DurableDeferred, id: DeferredId) !bool {
        var events = try self.journal_store.readAll(self.allocator);
        defer events.deinit();
        for (events.events) |event| {
            if (event.deferred_id != null and
                event.deferred_id.? == id and
                event.workflow_id == self.workflow_id and
                event.execution_id == self.execution_id and
                isDeferredTerminal(event.kind))
            {
                return true;
            }
        }
        return false;
    }

    fn nextJournalSequence(self: *DurableDeferred) !journal_mod.JournalSequence {
        var events = try self.journal_store.readAll(self.allocator);
        defer events.deinit();
        if (events.events.len == 0) return 1;
        return events.events[events.events.len - 1].sequence + 1;
    }
};

pub fn deferredId(label: []const u8) DeferredId {
    return std.hash.Fnv1a_64.hash(label);
}

fn isDeferredTerminal(kind: journal_mod.WorkflowEventKind) bool {
    return switch (kind) {
        .deferred_completed,
        .deferred_failed,
        .deferred_cancelled,
        => true,
        else => false,
    };
}

fn deferredEventIdempotencyKey(
    allocator: Allocator,
    kind: journal_mod.WorkflowEventKind,
    id: DeferredId,
    sequence: journal_mod.JournalSequence,
) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "deferred:{d}:{s}:{d}",
        .{ id, journal_mod.workflowEventKindName(kind), sequence },
    );
}

fn deferredFailureDetail(allocator: Allocator, err: anyerror) Allocator.Error![]const u8 {
    const cause = DeferredFailureCause{ .failure = err };
    const exit = DeferredFailureExit{ .cause = cause };
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
