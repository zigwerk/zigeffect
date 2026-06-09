const std = @import("std");
const envelope_mod = @import("envelope.zig");
const routing = @import("routing.zig");

pub const Allocator = std.mem.Allocator;
pub const ShardId = routing.ShardId;
pub const MessageId = envelope_mod.MessageId;
pub const MessageCorrelationId = envelope_mod.MessageCorrelationId;
pub const MessageEnvelope = envelope_mod.MessageEnvelope;
pub const MessageDeliveryStatus = envelope_mod.MessageDeliveryStatus;
pub const MessageSubmitResult = envelope_mod.MessageSubmitResult;

pub const MessageStorageError = error{
    MessageNotFound,
    MissingRequest,
    DuplicateMessage,
    DuplicateReply,
    CorruptMessageFile,
};

pub const StoredMessageRecord = struct {
    shard_id: ShardId,
    envelope: MessageEnvelope,
    status: MessageDeliveryStatus = .pending,
    stored_at_ms: u64,
    updated_at_ms: u64,

    pub fn deinit(self: *StoredMessageRecord, allocator: Allocator) void {
        envelope_mod.deinitMessageEnvelope(allocator, self.envelope);
    }
};

pub const StoredReplyRecord = struct {
    shard_id: ShardId,
    envelope: MessageEnvelope,
    stored_at_ms: u64,

    pub fn deinit(self: *StoredReplyRecord, allocator: Allocator) void {
        envelope_mod.deinitMessageEnvelope(allocator, self.envelope);
    }
};

pub const MessageStorageSubmit = struct {
    shard_id: ShardId,
    envelope: MessageEnvelope,
    now_ms: u64 = 0,
};

pub const MessageStorageClaim = struct {
    shard_id: ShardId,
    message_id: MessageId,
    now_ms: u64 = 0,
};

pub const MessageStorageAck = struct {
    message_id: MessageId,
    now_ms: u64 = 0,
};

pub const MessageStorageReply = struct {
    shard_id: ShardId,
    envelope: MessageEnvelope,
    now_ms: u64 = 0,
};

pub const MessageRecordBatch = struct {
    allocator: Allocator,
    records: []StoredMessageRecord,

    pub fn deinit(self: *MessageRecordBatch) void {
        for (self.records) |*record| {
            record.deinit(self.allocator);
        }
        self.allocator.free(self.records);
    }
};

pub const MessageStorage = struct {
    context: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        submit: *const fn (*anyopaque, MessageStorageSubmit) anyerror!MessageSubmitResult,
        claim: *const fn (*anyopaque, MessageStorageClaim) anyerror!MessageEnvelope,
        ack: *const fn (*anyopaque, MessageStorageAck) anyerror!void,
        store_reply: *const fn (*anyopaque, MessageStorageReply) anyerror!MessageEnvelope,
        reply: *const fn (*anyopaque, MessageCorrelationId, Allocator) anyerror!?MessageEnvelope,
        unprocessed_by_shard: *const fn (*anyopaque, ShardId, Allocator) anyerror!MessageRecordBatch,
        unprocessed_by_id: *const fn (*anyopaque, MessageId, Allocator) anyerror!?StoredMessageRecord,
        reset: *const fn (*anyopaque) void,
    };

    pub fn submit(self: MessageStorage, request: MessageStorageSubmit) anyerror!MessageSubmitResult {
        return self.vtable.submit(self.context, request);
    }

    pub fn claim(self: MessageStorage, request: MessageStorageClaim) anyerror!MessageEnvelope {
        return self.vtable.claim(self.context, request);
    }

    pub fn ack(self: MessageStorage, request: MessageStorageAck) anyerror!void {
        return self.vtable.ack(self.context, request);
    }

    pub fn storeReply(self: MessageStorage, request: MessageStorageReply) anyerror!MessageEnvelope {
        return self.vtable.store_reply(self.context, request);
    }

    pub fn reply(self: MessageStorage, correlation_id: MessageCorrelationId, allocator: Allocator) anyerror!?MessageEnvelope {
        return self.vtable.reply(self.context, correlation_id, allocator);
    }

    pub fn unprocessedByShard(self: MessageStorage, shard_id: ShardId, allocator: Allocator) anyerror!MessageRecordBatch {
        return self.vtable.unprocessed_by_shard(self.context, shard_id, allocator);
    }

    pub fn unprocessedById(self: MessageStorage, message_id: MessageId, allocator: Allocator) anyerror!?StoredMessageRecord {
        return self.vtable.unprocessed_by_id(self.context, message_id, allocator);
    }

    pub fn reset(self: MessageStorage) void {
        self.vtable.reset(self.context);
    }
};

pub const InMemoryMessageStorage = struct {
    allocator: Allocator,
    messages: std.ArrayList(StoredMessageRecord) = .empty,
    replies: std.ArrayList(StoredReplyRecord) = .empty,

    pub fn init(allocator: Allocator) InMemoryMessageStorage {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *InMemoryMessageStorage) void {
        self.reset();
        self.messages.deinit(self.allocator);
        self.replies.deinit(self.allocator);
    }

    pub fn asMessageStorage(self: *InMemoryMessageStorage) MessageStorage {
        return .{
            .context = self,
            .vtable = &in_memory_vtable,
        };
    }

    pub fn submit(self: *InMemoryMessageStorage, request: MessageStorageSubmit) Allocator.Error!MessageSubmitResult {
        if (self.findDuplicate(request.envelope)) |record| {
            return .{
                .envelope = try envelope_mod.cloneMessageEnvelope(self.allocator, record.envelope),
                .duplicate = true,
            };
        }

        const owned = try prepareEnvelope(self.allocator, request.envelope);
        errdefer envelope_mod.deinitMessageEnvelope(self.allocator, owned);
        const returned = try envelope_mod.cloneMessageEnvelope(self.allocator, owned);
        errdefer envelope_mod.deinitMessageEnvelope(self.allocator, returned);
        try self.messages.append(self.allocator, .{
            .shard_id = request.shard_id,
            .envelope = owned,
            .stored_at_ms = request.now_ms,
            .updated_at_ms = request.now_ms,
        });
        return .{ .envelope = returned };
    }

    pub fn claim(self: *InMemoryMessageStorage, request: MessageStorageClaim) MessageStorageError!MessageEnvelope {
        _ = self;
        _ = request;
        return error.MessageNotFound;
    }

    pub fn ack(self: *InMemoryMessageStorage, request: MessageStorageAck) MessageStorageError!void {
        _ = self;
        _ = request;
        return error.MessageNotFound;
    }

    pub fn storeReply(self: *InMemoryMessageStorage, request: MessageStorageReply) MessageStorageError!MessageEnvelope {
        _ = self;
        _ = request;
        return error.MissingRequest;
    }

    pub fn reply(self: *InMemoryMessageStorage, correlation_id: MessageCorrelationId, allocator: Allocator) Allocator.Error!?MessageEnvelope {
        _ = self;
        _ = correlation_id;
        _ = allocator;
        return null;
    }

    pub fn unprocessedByShard(self: *const InMemoryMessageStorage, shard_id: ShardId, allocator: Allocator) Allocator.Error!MessageRecordBatch {
        var output: std.ArrayList(StoredMessageRecord) = .empty;
        errdefer {
            for (output.items) |*record| {
                record.deinit(allocator);
            }
            output.deinit(allocator);
        }

        for (self.messages.items) |record| {
            if (record.shard_id != shard_id) continue;
            if (!messageIsUnprocessed(record.status)) continue;
            try output.append(allocator, try cloneStoredMessageRecord(allocator, record));
        }

        return .{
            .allocator = allocator,
            .records = try output.toOwnedSlice(allocator),
        };
    }

    pub fn unprocessedById(self: *const InMemoryMessageStorage, message_id_value: MessageId, allocator: Allocator) Allocator.Error!?StoredMessageRecord {
        for (self.messages.items) |record| {
            if (record.envelope.id != message_id_value) continue;
            if (!messageIsUnprocessed(record.status)) return null;
            return try cloneStoredMessageRecord(allocator, record);
        }
        return null;
    }

    pub fn reset(self: *InMemoryMessageStorage) void {
        for (self.messages.items) |*record| {
            record.deinit(self.allocator);
        }
        self.messages.clearRetainingCapacity();

        for (self.replies.items) |*reply_record| {
            reply_record.deinit(self.allocator);
        }
        self.replies.clearRetainingCapacity();
    }

    fn findDuplicate(self: *const InMemoryMessageStorage, envelope: MessageEnvelope) ?StoredMessageRecord {
        for (self.messages.items) |record| {
            if (record.envelope.kind != envelope.kind) continue;
            if (!record.envelope.address.eql(envelope.address)) continue;
            if (!std.mem.eql(u8, record.envelope.idempotency_key, envelope.idempotency_key)) continue;
            return record;
        }
        return null;
    }
};

pub const FileMessageStorage = struct {};

fn prepareEnvelope(allocator: Allocator, envelope: MessageEnvelope) Allocator.Error!MessageEnvelope {
    var owned = try envelope_mod.cloneMessageEnvelope(allocator, envelope);
    owned.id = if (owned.id == 0) computedMessageId(owned) else owned.id;
    if (owned.kind == .request and owned.correlation_id == null) {
        owned.correlation_id = envelope_mod.messageCorrelationId(owned.id);
    }
    return owned;
}

fn computedMessageId(envelope: MessageEnvelope) MessageId {
    var key_buf: [20]u8 = undefined;
    const key = if (envelope.idempotency_key.len > 0)
        envelope.idempotency_key
    else if (envelope.correlation_id) |correlation_id|
        std.fmt.bufPrint(&key_buf, "{d}", .{correlation_id}) catch unreachable
    else
        "";
    return envelope_mod.messageId(envelope.address, envelope.kind, key);
}

fn messageIsUnprocessed(status: MessageDeliveryStatus) bool {
    return switch (status) {
        .pending, .claimed => true,
        .acknowledged, .replied, .interrupted => false,
    };
}

fn cloneStoredMessageRecord(allocator: Allocator, record: StoredMessageRecord) Allocator.Error!StoredMessageRecord {
    return .{
        .shard_id = record.shard_id,
        .envelope = try envelope_mod.cloneMessageEnvelope(allocator, record.envelope),
        .status = record.status,
        .stored_at_ms = record.stored_at_ms,
        .updated_at_ms = record.updated_at_ms,
    };
}

fn inMemorySubmit(context: *anyopaque, request: MessageStorageSubmit) anyerror!MessageSubmitResult {
    const storage: *InMemoryMessageStorage = @ptrCast(@alignCast(context));
    return storage.submit(request);
}

fn inMemoryClaim(context: *anyopaque, request: MessageStorageClaim) anyerror!MessageEnvelope {
    const storage: *InMemoryMessageStorage = @ptrCast(@alignCast(context));
    return storage.claim(request);
}

fn inMemoryAck(context: *anyopaque, request: MessageStorageAck) anyerror!void {
    const storage: *InMemoryMessageStorage = @ptrCast(@alignCast(context));
    return storage.ack(request);
}

fn inMemoryStoreReply(context: *anyopaque, request: MessageStorageReply) anyerror!MessageEnvelope {
    const storage: *InMemoryMessageStorage = @ptrCast(@alignCast(context));
    return storage.storeReply(request);
}

fn inMemoryReply(context: *anyopaque, correlation_id: MessageCorrelationId, allocator: Allocator) anyerror!?MessageEnvelope {
    const storage: *InMemoryMessageStorage = @ptrCast(@alignCast(context));
    return storage.reply(correlation_id, allocator);
}

fn inMemoryUnprocessedByShard(context: *anyopaque, shard_id: ShardId, allocator: Allocator) anyerror!MessageRecordBatch {
    const storage: *InMemoryMessageStorage = @ptrCast(@alignCast(context));
    return storage.unprocessedByShard(shard_id, allocator);
}

fn inMemoryUnprocessedById(context: *anyopaque, message_id_value: MessageId, allocator: Allocator) anyerror!?StoredMessageRecord {
    const storage: *InMemoryMessageStorage = @ptrCast(@alignCast(context));
    return storage.unprocessedById(message_id_value, allocator);
}

fn inMemoryReset(context: *anyopaque) void {
    const storage: *InMemoryMessageStorage = @ptrCast(@alignCast(context));
    storage.reset();
}

const in_memory_vtable: MessageStorage.VTable = .{
    .submit = inMemorySubmit,
    .claim = inMemoryClaim,
    .ack = inMemoryAck,
    .store_reply = inMemoryStoreReply,
    .reply = inMemoryReply,
    .unprocessed_by_shard = inMemoryUnprocessedByShard,
    .unprocessed_by_id = inMemoryUnprocessedById,
    .reset = inMemoryReset,
};
