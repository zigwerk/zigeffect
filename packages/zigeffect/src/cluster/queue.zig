const std = @import("std");
const local_cluster = @import("local_cluster.zig");
const routing = @import("routing.zig");
const workflow_journal = @import("../workflow/journal.zig");
const workflow_store = @import("../workflow/store.zig");

pub const Allocator = std.mem.Allocator;
pub const ExecutionId = workflow_journal.ExecutionId;
pub const JournalSequence = workflow_journal.JournalSequence;
pub const JournalStore = workflow_store.JournalStore;
pub const LocalClusterRunner = local_cluster.LocalClusterRunner;
pub const QueueId = workflow_journal.QueueId;
pub const ShardId = routing.ShardId;
pub const WorkflowId = workflow_journal.WorkflowId;

pub const ClusterQueueStatus = enum {
    offered,
    claimed,
    retry_ready,
    completed,
    failed,
    acked,
};

pub const ClusterQueueItem = struct {
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    queue_id: QueueId,
    shard_id: ShardId,
    name: []const u8 = "",
    payload: []const u8 = "",
    status: ClusterQueueStatus = .offered,
    attempt: u32 = 0,
    claim_worker: []const u8 = "",
    claim_deadline_ms: ?u64 = null,
    claim_sequence: ?JournalSequence = null,
};

pub const ClusterQueueBatch = struct {
    allocator: Allocator,
    items: []ClusterQueueItem,

    pub fn deinit(self: *ClusterQueueBatch) void {
        deinitItems(self.allocator, self.items);
        self.allocator.free(self.items);
    }
};

pub const ClusterQueueRebuildReport = struct {
    scanned: usize = 0,
    indexed: usize = 0,
    skipped_unowned: usize = 0,
};

pub const ClusterQueueClaimLimits = struct {
    max_per_runner: usize = std.math.maxInt(usize),
    max_per_queue: usize = std.math.maxInt(usize),
};

pub const ClusterQueueIndex = struct {
    allocator: Allocator,
    items: std.ArrayList(ClusterQueueItem) = .empty,

    pub fn init(allocator: Allocator) ClusterQueueIndex {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *ClusterQueueIndex) void {
        self.clear();
        self.items.deinit(self.allocator);
    }

    fn clear(self: *ClusterQueueIndex) void {
        deinitItems(self.allocator, self.items.items);
        self.items.clearRetainingCapacity();
    }
};

fn deinitItems(allocator: Allocator, items: []const ClusterQueueItem) void {
    for (items) |item| {
        if (item.name.len != 0) allocator.free(item.name);
        if (item.payload.len != 0) allocator.free(item.payload);
        if (item.claim_worker.len != 0) allocator.free(item.claim_worker);
    }
}
