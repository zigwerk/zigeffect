const std = @import("std");
const local_cluster = @import("local_cluster.zig");
const routing = @import("routing.zig");
const workflow_journal = @import("../workflow/journal.zig");
const workflow_store = @import("../workflow/store.zig");

pub const Allocator = std.mem.Allocator;
pub const ExecutionId = workflow_journal.ExecutionId;
pub const JournalStore = workflow_store.JournalStore;
pub const LocalClusterRunner = local_cluster.LocalClusterRunner;
pub const ShardId = routing.ShardId;
pub const TimerId = workflow_journal.TimerId;
pub const WorkflowId = workflow_journal.WorkflowId;

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

    fn clear(self: *ClusterTimerWakeupIndex) void {
        for (self.wakeups.items) |wakeup| {
            if (wakeup.name.len != 0) self.allocator.free(wakeup.name);
        }
        self.wakeups.clearRetainingCapacity();
    }
};
