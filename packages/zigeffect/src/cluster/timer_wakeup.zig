const std = @import("std");
const local_cluster = @import("local_cluster.zig");
const routing = @import("routing.zig");
const workflow_cluster = @import("workflow_engine.zig");
const workflow_journal = @import("../workflow/journal.zig");
const workflow_store = @import("../workflow/store.zig");

pub const Allocator = std.mem.Allocator;
pub const ExecutionId = workflow_journal.ExecutionId;
pub const JournalStore = workflow_store.JournalStore;
pub const LocalClusterRunner = local_cluster.LocalClusterRunner;
pub const ShardId = routing.ShardId;
pub const TimerId = workflow_journal.TimerId;
pub const WorkflowId = workflow_journal.WorkflowId;

pub const ClusterTimerWakeupError = error{
    InvalidTimerFireAtDetail,
};

pub const ClusterTimerWakeup = struct {
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    timer_id: TimerId,
    shard_id: ShardId,
    name: []const u8 = "",
    fire_at_ms: u64,
    late_by_ms: u64 = 0,
};

pub const ClusterTimerWakeupBatch = struct {
    allocator: Allocator,
    wakeups: []ClusterTimerWakeup,

    pub fn deinit(self: *ClusterTimerWakeupBatch) void {
        for (self.wakeups) |wakeup| {
            if (wakeup.name.len != 0) self.allocator.free(wakeup.name);
        }
        self.allocator.free(self.wakeups);
    }
};

pub const ClusterTimerWakeupReport = struct {
    scanned: usize = 0,
    indexed: usize = 0,
    skipped_unowned: usize = 0,
    skipped_terminal: usize = 0,
    skipped_duplicate: usize = 0,
};

pub const ClusterTimerWakeupIndex = struct {
    allocator: Allocator,
    wakeups: std.ArrayList(ClusterTimerWakeup) = .empty,

    pub fn init(allocator: Allocator) ClusterTimerWakeupIndex {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *ClusterTimerWakeupIndex) void {
        self.clear();
        self.wakeups.deinit(self.allocator);
    }

    pub fn rebuildOwned(
        self: *ClusterTimerWakeupIndex,
        runner: *LocalClusterRunner,
        journal_store: JournalStore,
    ) !ClusterTimerWakeupReport {
        self.clear();

        var events = try journal_store.readAll(self.allocator);
        defer events.deinit();

        var report = ClusterTimerWakeupReport{};
        for (events.events) |event| {
            if (event.kind != .timer_scheduled) continue;
            const timer_id = event.timer_id orelse continue;
            report.scanned += 1;

            const address = workflow_cluster.clusterWorkflowExecutionAddress(event.execution_id);
            const shard_id = try routing.shardIdForAddress(address, runner.shard_count);
            if (!runner.runtime.ownsShard(shard_id)) {
                report.skipped_unowned += 1;
                continue;
            }

            if (timerHasTerminalEvent(events.events, event.workflow_id, event.execution_id, timer_id)) {
                report.skipped_terminal += 1;
                continue;
            }

            if (self.hasWakeup(event.workflow_id, event.execution_id, timer_id)) {
                report.skipped_duplicate += 1;
                continue;
            }

            const fire_at_ms = try parseTimerFireAt(event.redacted_detail);
            const name = try self.allocator.dupe(u8, event.name);
            errdefer self.allocator.free(name);
            try self.wakeups.append(self.allocator, .{
                .workflow_id = event.workflow_id,
                .execution_id = event.execution_id,
                .timer_id = timer_id,
                .shard_id = shard_id,
                .name = name,
                .fire_at_ms = fire_at_ms,
            });
            report.indexed += 1;
        }

        return report;
    }

    fn clear(self: *ClusterTimerWakeupIndex) void {
        for (self.wakeups.items) |wakeup| {
            if (wakeup.name.len != 0) self.allocator.free(wakeup.name);
        }
        self.wakeups.clearRetainingCapacity();
    }

    fn hasWakeup(
        self: *const ClusterTimerWakeupIndex,
        workflow_id: WorkflowId,
        execution_id: ExecutionId,
        timer_id: TimerId,
    ) bool {
        for (self.wakeups.items) |wakeup| {
            if (sameTimer(wakeup.workflow_id, wakeup.execution_id, wakeup.timer_id, workflow_id, execution_id, timer_id)) return true;
        }
        return false;
    }
};

fn timerHasTerminalEvent(
    events: []const workflow_journal.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    timer_id: TimerId,
) bool {
    for (events) |event| {
        if (!sameTimer(event.workflow_id, event.execution_id, event.timer_id orelse continue, workflow_id, execution_id, timer_id)) continue;
        switch (event.kind) {
            .timer_fired, .timer_cancelled => return true,
            else => {},
        }
    }
    return false;
}

fn sameTimer(
    left_workflow_id: WorkflowId,
    left_execution_id: ExecutionId,
    left_timer_id: TimerId,
    right_workflow_id: WorkflowId,
    right_execution_id: ExecutionId,
    right_timer_id: TimerId,
) bool {
    return left_workflow_id == right_workflow_id and
        left_execution_id == right_execution_id and
        left_timer_id == right_timer_id;
}

fn parseTimerFireAt(detail: []const u8) ClusterTimerWakeupError!u64 {
    const prefix = "fire_at_ms=";
    if (!std.mem.startsWith(u8, detail, prefix)) return error.InvalidTimerFireAtDetail;
    return std.fmt.parseInt(u64, detail[prefix.len..], 10) catch error.InvalidTimerFireAtDetail;
}
