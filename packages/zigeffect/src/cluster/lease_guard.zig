const std = @import("std");
const fencing = @import("fencing.zig");
const mailbox = @import("mailbox.zig");
const message_storage = @import("message_storage.zig");
const runner_storage = @import("runner_storage.zig");
const workflow_store = @import("../workflow/store.zig");

pub const Allocator = std.mem.Allocator;
pub const EntityEnvelope = mailbox.EntityEnvelope;
pub const JournalAppend = workflow_store.JournalAppend;
pub const JournalEventBatch = workflow_store.JournalEventBatch;
pub const JournalSequence = workflow_store.JournalSequence;
pub const JournalStore = workflow_store.JournalStore;
pub const JournalStoreAppendError = workflow_store.JournalStoreAppendError;
pub const JournalStoreReadError = workflow_store.JournalStoreReadError;
pub const JournalStoreReplayError = workflow_store.JournalStoreReplayError;
pub const MessageEnvelope = message_storage.MessageEnvelope;
pub const MessageStorage = message_storage.MessageStorage;
pub const MessageStorageSubmit = message_storage.MessageStorageSubmit;
pub const MessageStorageClaim = message_storage.MessageStorageClaim;
pub const MessageStorageAck = message_storage.MessageStorageAck;
pub const MessageStorageReply = message_storage.MessageStorageReply;
pub const MessageSubmitResult = message_storage.MessageSubmitResult;
pub const RunnerStorage = runner_storage.RunnerStorage;
pub const ShardLeaseEpoch = runner_storage.ShardLeaseEpoch;
pub const ShardLeaseFence = fencing.ShardLeaseFence;
pub const WorkflowReplayState = workflow_store.WorkflowReplayState;

pub const ShardLeaseWriteKind = enum {
    journal,
    mailbox,
    message_submit,
    message_claim,
    message_ack,
    message_reply,
    queue,
    timer,
};

pub const ShardLeaseWriteGuard = struct {
    storage: RunnerStorage,
    fence: ShardLeaseFence,
    kind: ShardLeaseWriteKind,

    pub fn init(storage: RunnerStorage, fence: ShardLeaseFence, kind: ShardLeaseWriteKind) ShardLeaseWriteGuard {
        return .{
            .storage = storage,
            .fence = fence,
            .kind = kind,
        };
    }

    pub fn validate(self: ShardLeaseWriteGuard) !void {
        try fencing.validateShardFence(self.storage, self.fence);
    }

    pub fn epoch(self: ShardLeaseWriteGuard) ShardLeaseEpoch {
        return self.fence.epoch;
    }
};

pub const LeaseGuardedJournalAppend = struct {
    guard: ShardLeaseWriteGuard,
    append: JournalAppend,
};

pub const GuardedMessageSubmit = struct {
    guard: ShardLeaseWriteGuard,
    request: MessageStorageSubmit,
};

pub const GuardedMessageClaim = struct {
    guard: ShardLeaseWriteGuard,
    request: MessageStorageClaim,
};

pub const GuardedMessageAck = struct {
    guard: ShardLeaseWriteGuard,
    request: MessageStorageAck,
};

pub const GuardedMessageReply = struct {
    guard: ShardLeaseWriteGuard,
    request: MessageStorageReply,
};

pub const ShardLeaseGuardedJournalStore = struct {
    allocator: Allocator,
    inner: JournalStore,
    guard: ShardLeaseWriteGuard,

    pub fn init(allocator: Allocator, inner: JournalStore, guard: ShardLeaseWriteGuard) ShardLeaseGuardedJournalStore {
        return .{
            .allocator = allocator,
            .inner = inner,
            .guard = guard,
        };
    }

    pub fn asJournalStore(self: *ShardLeaseGuardedJournalStore) JournalStore {
        return .{
            .context = self,
            .vtable = &guarded_journal_vtable,
        };
    }

    fn appendAdapter(context: *anyopaque, request: JournalAppend) JournalStoreAppendError!JournalSequence {
        const self: *ShardLeaseGuardedJournalStore = @ptrCast(@alignCast(context));
        return guardJournalAppend(self.allocator, self.inner, .{
            .guard = self.guard,
            .append = request,
        });
    }

    fn readAllAdapter(context: *anyopaque, allocator: Allocator) JournalStoreReadError!JournalEventBatch {
        const self: *ShardLeaseGuardedJournalStore = @ptrCast(@alignCast(context));
        return self.inner.readAll(allocator);
    }

    fn readFromSequenceAdapter(context: *anyopaque, allocator: Allocator, sequence: JournalSequence) JournalStoreReadError!JournalEventBatch {
        const self: *ShardLeaseGuardedJournalStore = @ptrCast(@alignCast(context));
        return self.inner.readFromSequence(allocator, sequence);
    }

    fn latestStateAdapter(context: *anyopaque, allocator: Allocator) JournalStoreReplayError!WorkflowReplayState {
        const self: *ShardLeaseGuardedJournalStore = @ptrCast(@alignCast(context));
        return self.inner.latestState(allocator);
    }

    fn resetAdapter(context: *anyopaque) void {
        const self: *ShardLeaseGuardedJournalStore = @ptrCast(@alignCast(context));
        self.inner.reset();
    }
};

const guarded_journal_vtable: JournalStore.VTable = .{
    .append = ShardLeaseGuardedJournalStore.appendAdapter,
    .read_all = ShardLeaseGuardedJournalStore.readAllAdapter,
    .read_from_sequence = ShardLeaseGuardedJournalStore.readFromSequenceAdapter,
    .latest_state = ShardLeaseGuardedJournalStore.latestStateAdapter,
    .reset = ShardLeaseGuardedJournalStore.resetAdapter,
};

pub fn guardMessageSubmit(storage: MessageStorage, request: GuardedMessageSubmit) !MessageSubmitResult {
    try request.guard.validate();
    var submit_request = request.request;
    submit_request.lease_epoch = request.guard.epoch();
    submit_request.envelope.lease_epoch = request.guard.epoch();
    return storage.submit(submit_request);
}

pub fn guardMessageClaim(storage: MessageStorage, request: GuardedMessageClaim) !MessageEnvelope {
    try request.guard.validate();
    var claim_request = request.request;
    claim_request.lease_epoch = request.guard.epoch();
    return storage.claim(claim_request);
}

pub fn guardMessageAck(storage: MessageStorage, request: GuardedMessageAck) !void {
    try request.guard.validate();
    var ack_request = request.request;
    ack_request.shard_id = request.guard.fence.shard_id;
    ack_request.lease_epoch = request.guard.epoch();
    try storage.ack(ack_request);
}

pub fn guardMessageReply(storage: MessageStorage, request: GuardedMessageReply) !MessageEnvelope {
    try request.guard.validate();
    var reply_request = request.request;
    reply_request.lease_epoch = request.guard.epoch();
    reply_request.envelope.lease_epoch = request.guard.epoch();
    return storage.storeReply(reply_request);
}

pub fn guardMailboxOffer(store: *mailbox.LocalMailboxStore, guard: ShardLeaseWriteGuard, envelope: EntityEnvelope) !EntityEnvelope {
    try guard.validate();
    var guarded = envelope;
    guarded.lease_epoch = guard.epoch();
    return store.offer(guarded);
}

pub fn guardMailboxReply(store: *mailbox.LocalMailboxStore, guard: ShardLeaseWriteGuard, envelope: EntityEnvelope) !EntityEnvelope {
    try guard.validate();
    var guarded = envelope;
    guarded.lease_epoch = guard.epoch();
    return store.storeReply(guarded);
}

pub fn guardJournalAppend(allocator: Allocator, store: JournalStore, request: LeaseGuardedJournalAppend) !JournalSequence {
    try request.guard.validate();
    const detail = try appendLeaseEpochDetail(allocator, request.append.event.redacted_detail, request.guard.fence);
    defer allocator.free(detail);

    var append_request = request.append;
    append_request.event.redacted_detail = detail;
    return store.append(append_request);
}

pub fn appendLeaseEpochDetail(allocator: Allocator, detail: []const u8, fence: ShardLeaseFence) Allocator.Error![]const u8 {
    if (leaseEpochFromDetail(detail) != null) return allocator.dupe(u8, detail);
    if (detail.len == 0) {
        return std.fmt.allocPrint(allocator, "lease_epoch={d}", .{fence.epoch});
    }
    return std.fmt.allocPrint(allocator, "{s} lease_epoch={d}", .{ detail, fence.epoch });
}

pub fn leaseEpochFromDetail(detail: []const u8) ?ShardLeaseEpoch {
    const prefix = "lease_epoch=";
    var found: ?ShardLeaseEpoch = null;
    var search_start: usize = 0;
    while (std.mem.indexOfPos(u8, detail, search_start, prefix)) |index| {
        const value_start = index + prefix.len;
        const value_end = std.mem.indexOfScalarPos(u8, detail, value_start, ' ') orelse detail.len;
        found = std.fmt.parseUnsigned(ShardLeaseEpoch, detail[value_start..value_end], 10) catch null;
        search_start = value_end;
        if (search_start >= detail.len) break;
    }
    return found;
}
