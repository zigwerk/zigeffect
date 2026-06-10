const std = @import("std");
const local_cluster = @import("local_cluster.zig");
const routing = @import("routing.zig");
const workflow_cluster = @import("workflow_engine.zig");
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

    pub fn rebuildOwned(
        self: *ClusterQueueIndex,
        runner: *LocalClusterRunner,
        journal_store: JournalStore,
    ) !ClusterQueueRebuildReport {
        self.clear();

        var events = try journal_store.readAll(self.allocator);
        defer events.deinit();

        var report = ClusterQueueRebuildReport{};
        for (events.events) |event| {
            const queue_id = event.queue_id orelse continue;
            if (!isQueueEventKind(event.kind)) continue;
            report.scanned += 1;

            const address = workflow_cluster.clusterWorkflowExecutionAddress(event.execution_id);
            const shard_id = try routing.shardIdForAddress(address, runner.shard_count);
            if (!runner.runtime.ownsShard(shard_id)) {
                report.skipped_unowned += 1;
                continue;
            }

            if (event.kind == .queue_offered) {
                if (self.itemIndex(event.workflow_id, event.execution_id, queue_id) == null) {
                    try self.appendOffered(event, shard_id, queue_id);
                    report.indexed += 1;
                    continue;
                }
            }

            if (self.itemIndex(event.workflow_id, event.execution_id, queue_id)) |index| {
                try self.applyQueueEvent(index, event);
            }
        }

        return report;
    }

    fn clear(self: *ClusterQueueIndex) void {
        deinitItems(self.allocator, self.items.items);
        self.items.clearRetainingCapacity();
    }

    fn appendOffered(
        self: *ClusterQueueIndex,
        event: workflow_journal.WorkflowEvent,
        shard_id: ShardId,
        queue_id: QueueId,
    ) Allocator.Error!void {
        const name = try self.allocator.dupe(u8, event.name);
        errdefer self.allocator.free(name);
        const payload = try self.allocator.dupe(u8, event.redacted_detail);
        errdefer self.allocator.free(payload);
        try self.items.append(self.allocator, .{
            .workflow_id = event.workflow_id,
            .execution_id = event.execution_id,
            .queue_id = queue_id,
            .shard_id = shard_id,
            .name = name,
            .payload = payload,
            .status = .offered,
            .attempt = event.attempt,
        });
    }

    fn applyQueueEvent(
        self: *ClusterQueueIndex,
        index: usize,
        event: workflow_journal.WorkflowEvent,
    ) Allocator.Error!void {
        var item = &self.items.items[index];
        switch (event.kind) {
            .queue_offered => {
                item.status = .offered;
            },
            .queue_claimed => {
                item.status = .claimed;
                item.attempt = event.attempt;
                item.claim_sequence = event.sequence;
                item.claim_deadline_ms = parseClaimDeadlineMs(event.redacted_detail);
                try self.replaceClaimWorker(item, parseClaimWorker(event.redacted_detail));
            },
            .queue_retry_scheduled => {
                item.status = .retry_ready;
                item.attempt = event.attempt;
                item.claim_deadline_ms = null;
                item.claim_sequence = null;
                try self.replaceClaimWorker(item, "");
            },
            .queue_completed => item.status = .completed,
            .queue_failed => item.status = .failed,
            .queue_acked => item.status = .acked,
            else => {},
        }
    }

    fn replaceClaimWorker(
        self: *ClusterQueueIndex,
        item: *ClusterQueueItem,
        worker: []const u8,
    ) Allocator.Error!void {
        if (item.claim_worker.len != 0) self.allocator.free(item.claim_worker);
        item.claim_worker = "";
        if (worker.len == 0) return;
        item.claim_worker = try self.allocator.dupe(u8, worker);
    }

    fn itemIndex(
        self: *const ClusterQueueIndex,
        workflow_id: WorkflowId,
        execution_id: ExecutionId,
        queue_id: QueueId,
    ) ?usize {
        for (self.items.items, 0..) |item, index| {
            if (item.workflow_id == workflow_id and
                item.execution_id == execution_id and
                item.queue_id == queue_id)
            {
                return index;
            }
        }
        return null;
    }
};

fn deinitItems(allocator: Allocator, items: []const ClusterQueueItem) void {
    for (items) |item| {
        if (item.name.len != 0) allocator.free(item.name);
        if (item.payload.len != 0) allocator.free(item.payload);
        if (item.claim_worker.len != 0) allocator.free(item.claim_worker);
    }
}

fn isQueueEventKind(kind: workflow_journal.WorkflowEventKind) bool {
    return switch (kind) {
        .queue_offered,
        .queue_claimed,
        .queue_retry_scheduled,
        .queue_completed,
        .queue_failed,
        .queue_acked,
        => true,
        else => false,
    };
}

fn parseClaimWorker(detail: []const u8) []const u8 {
    const prefix = "worker=";
    if (!std.mem.startsWith(u8, detail, prefix)) return "";
    const start = prefix.len;
    const end = std.mem.indexOfScalarPos(u8, detail, start, ' ') orelse detail.len;
    return detail[start..end];
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
