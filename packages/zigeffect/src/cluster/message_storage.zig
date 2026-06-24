const std = @import("std");
const envelope_mod = @import("envelope.zig");
const routing = @import("routing.zig");
const runner_storage = @import("runner_storage.zig");

pub const Allocator = std.mem.Allocator;
pub const ShardId = routing.ShardId;
pub const MessageId = envelope_mod.MessageId;
pub const MessageCorrelationId = envelope_mod.MessageCorrelationId;
pub const MessageEnvelope = envelope_mod.MessageEnvelope;
pub const MessageDeliveryStatus = envelope_mod.MessageDeliveryStatus;
pub const MessageSubmitResult = envelope_mod.MessageSubmitResult;
pub const ShardLeaseEpoch = runner_storage.ShardLeaseEpoch;

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
    lease_epoch: ?ShardLeaseEpoch = null,

    pub fn deinit(self: *StoredMessageRecord, allocator: Allocator) void {
        envelope_mod.deinitMessageEnvelope(allocator, self.envelope);
    }
};

pub const StoredReplyRecord = struct {
    shard_id: ShardId,
    envelope: MessageEnvelope,
    stored_at_ms: u64,
    lease_epoch: ?ShardLeaseEpoch = null,

    pub fn deinit(self: *StoredReplyRecord, allocator: Allocator) void {
        envelope_mod.deinitMessageEnvelope(allocator, self.envelope);
    }
};

pub const MessageStorageSubmit = struct {
    shard_id: ShardId,
    envelope: MessageEnvelope,
    now_ms: u64 = 0,
    lease_epoch: ?ShardLeaseEpoch = null,
};

pub const MessageStorageClaim = struct {
    shard_id: ShardId,
    message_id: MessageId,
    now_ms: u64 = 0,
    lease_epoch: ?ShardLeaseEpoch = null,
};

pub const MessageStorageAck = struct {
    message_id: MessageId,
    shard_id: ?ShardId = null,
    now_ms: u64 = 0,
    lease_epoch: ?ShardLeaseEpoch = null,
};

pub const MessageStorageReply = struct {
    shard_id: ShardId,
    envelope: MessageEnvelope,
    now_ms: u64 = 0,
    lease_epoch: ?ShardLeaseEpoch = null,
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

        var owned = try prepareEnvelope(self.allocator, request.envelope);
        owned.lease_epoch = request.lease_epoch orelse owned.lease_epoch;
        errdefer envelope_mod.deinitMessageEnvelope(self.allocator, owned);
        const returned = try envelope_mod.cloneMessageEnvelope(self.allocator, owned);
        errdefer envelope_mod.deinitMessageEnvelope(self.allocator, returned);
        try self.messages.append(self.allocator, .{
            .shard_id = request.shard_id,
            .envelope = owned,
            .stored_at_ms = request.now_ms,
            .updated_at_ms = request.now_ms,
            .lease_epoch = owned.lease_epoch,
        });
        return .{ .envelope = returned };
    }

    pub fn claim(self: *InMemoryMessageStorage, request: MessageStorageClaim) (Allocator.Error || MessageStorageError)!MessageEnvelope {
        const index = self.findMessageIndex(request.message_id) orelse return error.MessageNotFound;
        var record = &self.messages.items[index];
        if (record.shard_id != request.shard_id) return error.MessageNotFound;
        if (!messageIsUnprocessed(record.status)) return error.MessageNotFound;
        record.status = .claimed;
        record.envelope.attempt += 1;
        record.lease_epoch = request.lease_epoch orelse record.lease_epoch;
        record.envelope.lease_epoch = record.lease_epoch;
        record.updated_at_ms = request.now_ms;
        return envelope_mod.cloneMessageEnvelope(self.allocator, record.envelope);
    }

    pub fn ack(self: *InMemoryMessageStorage, request: MessageStorageAck) MessageStorageError!void {
        const index = self.findMessageIndex(request.message_id) orelse return error.MessageNotFound;
        if (request.shard_id) |shard_id| {
            if (self.messages.items[index].shard_id != shard_id) return error.MessageNotFound;
        }
        self.messages.items[index].status = .acknowledged;
        self.messages.items[index].lease_epoch = request.lease_epoch orelse self.messages.items[index].lease_epoch;
        self.messages.items[index].envelope.lease_epoch = self.messages.items[index].lease_epoch;
        self.messages.items[index].updated_at_ms = request.now_ms;
    }

    pub fn storeReply(self: *InMemoryMessageStorage, request: MessageStorageReply) (Allocator.Error || MessageStorageError)!MessageEnvelope {
        const correlation_id = request.envelope.correlation_id orelse return error.MissingRequest;
        const request_index = self.findRequestIndexByCorrelation(correlation_id) orelse return error.MissingRequest;
        if (self.findReplyIndexByCorrelation(correlation_id) != null) return error.DuplicateReply;

        var owned = try prepareEnvelope(self.allocator, request.envelope);
        owned.lease_epoch = request.lease_epoch orelse owned.lease_epoch;
        errdefer envelope_mod.deinitMessageEnvelope(self.allocator, owned);
        const returned = try envelope_mod.cloneMessageEnvelope(self.allocator, owned);
        errdefer envelope_mod.deinitMessageEnvelope(self.allocator, returned);
        try self.replies.append(self.allocator, .{
            .shard_id = request.shard_id,
            .envelope = owned,
            .stored_at_ms = request.now_ms,
            .lease_epoch = owned.lease_epoch,
        });
        self.messages.items[request_index].status = .replied;
        self.messages.items[request_index].updated_at_ms = request.now_ms;
        return returned;
    }

    pub fn reply(self: *InMemoryMessageStorage, correlation_id: MessageCorrelationId, allocator: Allocator) Allocator.Error!?MessageEnvelope {
        const index = self.findReplyIndexByCorrelation(correlation_id) orelse return null;
        return try envelope_mod.cloneMessageEnvelope(allocator, self.replies.items[index].envelope);
    }

    fn findMessageIndex(self: *const InMemoryMessageStorage, message_id_value: MessageId) ?usize {
        for (self.messages.items, 0..) |record, index| {
            if (record.envelope.id == message_id_value) return index;
        }
        return null;
    }

    fn findRequestIndexByCorrelation(self: *const InMemoryMessageStorage, correlation_id: MessageCorrelationId) ?usize {
        for (self.messages.items, 0..) |record, index| {
            if (record.envelope.kind != .request) continue;
            if (record.envelope.correlation_id == correlation_id) return index;
        }
        return null;
    }

    fn findReplyIndexByCorrelation(self: *const InMemoryMessageStorage, correlation_id: MessageCorrelationId) ?usize {
        for (self.replies.items, 0..) |reply_record, index| {
            if (reply_record.envelope.correlation_id == correlation_id) return index;
        }
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

pub const message_record_schema = "zigeffect.cluster.message-record.v1";
pub const message_record_schema_version: u32 = 1;
pub const message_reply_schema = "zigeffect.cluster.message-reply.v1";
pub const message_reply_schema_version: u32 = 1;

pub const FileMessageStorageOptions = struct {
    message_prefix: []const u8 = "cluster-message-",
    reply_prefix: []const u8 = "cluster-reply-",
    suffix: []const u8 = ".json",
    max_record_bytes: usize = 64 * 1024,
};

pub const FileMessageStorage = struct {
    allocator: Allocator,
    io: std.Io,
    dir: *std.Io.Dir,
    options: FileMessageStorageOptions,

    pub fn open(allocator: Allocator, io: std.Io, dir: *std.Io.Dir, options: FileMessageStorageOptions) !FileMessageStorage {
        return .{
            .allocator = allocator,
            .io = io,
            .dir = dir,
            .options = options,
        };
    }

    pub fn deinit(self: *FileMessageStorage) void {
        _ = self;
    }

    pub fn asMessageStorage(self: *FileMessageStorage) MessageStorage {
        return .{
            .context = self,
            .vtable = &file_vtable,
        };
    }

    pub fn submit(self: *FileMessageStorage, request: MessageStorageSubmit) !MessageSubmitResult {
        if (try self.findDuplicate(request.envelope)) |record| {
            var duplicate_record = record;
            defer duplicate_record.deinit(self.allocator);
            return .{
                .envelope = try envelope_mod.cloneMessageEnvelope(self.allocator, duplicate_record.envelope),
                .duplicate = true,
            };
        }

        var owned = try prepareEnvelope(self.allocator, request.envelope);
        owned.lease_epoch = request.lease_epoch orelse owned.lease_epoch;
        errdefer envelope_mod.deinitMessageEnvelope(self.allocator, owned);
        const returned = try envelope_mod.cloneMessageEnvelope(self.allocator, owned);
        errdefer envelope_mod.deinitMessageEnvelope(self.allocator, returned);
        var record: StoredMessageRecord = .{
            .shard_id = request.shard_id,
            .envelope = owned,
            .stored_at_ms = request.now_ms,
            .updated_at_ms = request.now_ms,
            .lease_epoch = owned.lease_epoch,
        };
        defer record.deinit(self.allocator);
        try self.writeMessageRecord(record);
        return .{ .envelope = returned };
    }

    pub fn claim(self: *FileMessageStorage, request: MessageStorageClaim) !MessageEnvelope {
        const name = try messageRecordFileName(self.allocator, self.options, request.message_id);
        defer self.allocator.free(name);
        var record = (try self.readMessageRecordWithAllocator(name, self.allocator)) orelse return error.MessageNotFound;
        defer record.deinit(self.allocator);

        if (record.shard_id != request.shard_id) return error.MessageNotFound;
        if (!messageIsUnprocessed(record.status)) return error.MessageNotFound;

        record.status = .claimed;
        record.envelope.attempt += 1;
        record.lease_epoch = request.lease_epoch orelse record.lease_epoch;
        record.envelope.lease_epoch = record.lease_epoch;
        record.updated_at_ms = request.now_ms;
        try self.writeMessageRecord(record);
        return envelope_mod.cloneMessageEnvelope(self.allocator, record.envelope);
    }

    pub fn ack(self: *FileMessageStorage, request: MessageStorageAck) !void {
        const name = try messageRecordFileName(self.allocator, self.options, request.message_id);
        defer self.allocator.free(name);
        var record = (try self.readMessageRecordWithAllocator(name, self.allocator)) orelse return error.MessageNotFound;
        defer record.deinit(self.allocator);

        if (request.shard_id) |shard_id| {
            if (record.shard_id != shard_id) return error.MessageNotFound;
        }
        record.status = .acknowledged;
        record.lease_epoch = request.lease_epoch orelse record.lease_epoch;
        record.envelope.lease_epoch = record.lease_epoch;
        record.updated_at_ms = request.now_ms;
        try self.writeMessageRecord(record);
    }

    pub fn storeReply(self: *FileMessageStorage, request: MessageStorageReply) !MessageEnvelope {
        const correlation_id = request.envelope.correlation_id orelse return error.MissingRequest;
        const reply_name = try replyRecordFileName(self.allocator, self.options, correlation_id);
        defer self.allocator.free(reply_name);
        if (try self.readReplyRecordWithAllocator(reply_name, self.allocator)) |duplicate| {
            var duplicate_reply = duplicate;
            defer duplicate_reply.deinit(self.allocator);
            return error.DuplicateReply;
        }

        var request_record = (try self.findRequestRecordByCorrelation(correlation_id)) orelse return error.MissingRequest;
        defer request_record.deinit(self.allocator);

        var owned = try prepareEnvelope(self.allocator, request.envelope);
        owned.lease_epoch = request.lease_epoch orelse owned.lease_epoch;
        errdefer envelope_mod.deinitMessageEnvelope(self.allocator, owned);
        const returned = try envelope_mod.cloneMessageEnvelope(self.allocator, owned);
        errdefer envelope_mod.deinitMessageEnvelope(self.allocator, returned);
        var reply_record: StoredReplyRecord = .{
            .shard_id = request.shard_id,
            .envelope = owned,
            .stored_at_ms = request.now_ms,
            .lease_epoch = owned.lease_epoch,
        };
        defer reply_record.deinit(self.allocator);

        try self.writeReplyRecord(reply_record);
        request_record.status = .replied;
        request_record.updated_at_ms = request.now_ms;
        try self.writeMessageRecord(request_record);
        return returned;
    }

    pub fn reply(self: *FileMessageStorage, correlation_id: MessageCorrelationId, allocator: Allocator) !?MessageEnvelope {
        const name = try replyRecordFileName(self.allocator, self.options, correlation_id);
        defer self.allocator.free(name);
        const record = (try self.readReplyRecordWithAllocator(name, allocator)) orelse return null;
        return record.envelope;
    }

    pub fn unprocessedByShard(self: *FileMessageStorage, shard_id: ShardId, allocator: Allocator) !MessageRecordBatch {
        var output: std.ArrayList(StoredMessageRecord) = .empty;
        errdefer {
            for (output.items) |*record| {
                record.deinit(allocator);
            }
            output.deinit(allocator);
        }

        var iterator = self.dir.iterate();
        while (try iterator.next(self.io)) |entry| {
            if (messageIdFromFileName(self.options, entry.name) == null) continue;
            var record = (try self.readMessageRecordWithAllocator(entry.name, allocator)) orelse continue;
            if (record.shard_id == shard_id and messageIsUnprocessed(record.status)) {
                try output.append(allocator, record);
            } else {
                record.deinit(allocator);
            }
        }

        return .{
            .allocator = allocator,
            .records = try output.toOwnedSlice(allocator),
        };
    }

    pub fn unprocessedById(self: *FileMessageStorage, message_id_value: MessageId, allocator: Allocator) !?StoredMessageRecord {
        const name = try messageRecordFileName(allocator, self.options, message_id_value);
        defer allocator.free(name);
        var record = (try self.readMessageRecordWithAllocator(name, allocator)) orelse return null;
        if (!messageIsUnprocessed(record.status)) {
            record.deinit(allocator);
            return null;
        }
        return record;
    }

    pub fn reset(self: *FileMessageStorage) void {
        var iterator = self.dir.iterate();
        while (iterator.next(self.io) catch null) |entry| {
            if (messageIdFromFileName(self.options, entry.name) == null and replyCorrelationIdFromFileName(self.options, entry.name) == null) continue;
            self.dir.deleteFile(self.io, entry.name) catch {};
        }
    }

    fn findDuplicate(self: *FileMessageStorage, envelope: MessageEnvelope) !?StoredMessageRecord {
        var iterator = self.dir.iterate();
        while (try iterator.next(self.io)) |entry| {
            if (messageIdFromFileName(self.options, entry.name) == null) continue;
            var record = (try self.readMessageRecordWithAllocator(entry.name, self.allocator)) orelse continue;
            if (record.envelope.kind == envelope.kind and
                record.envelope.address.eql(envelope.address) and
                std.mem.eql(u8, record.envelope.idempotency_key, envelope.idempotency_key))
            {
                return record;
            }
            record.deinit(self.allocator);
        }
        return null;
    }

    fn findRequestRecordByCorrelation(self: *FileMessageStorage, correlation_id: MessageCorrelationId) !?StoredMessageRecord {
        var iterator = self.dir.iterate();
        while (try iterator.next(self.io)) |entry| {
            if (messageIdFromFileName(self.options, entry.name) == null) continue;
            var record = (try self.readMessageRecordWithAllocator(entry.name, self.allocator)) orelse continue;
            if (record.envelope.kind == .request and record.envelope.correlation_id == correlation_id) {
                return record;
            }
            record.deinit(self.allocator);
        }
        return null;
    }

    fn writeMessageRecord(self: *FileMessageStorage, record: StoredMessageRecord) !void {
        const name = try messageRecordFileName(self.allocator, self.options, record.envelope.id);
        defer self.allocator.free(name);
        const content = try formatStoredMessageRecordJson(self.allocator, record);
        defer self.allocator.free(content);
        try self.writeAtomicFile(name, content);
    }

    fn writeReplyRecord(self: *FileMessageStorage, record: StoredReplyRecord) !void {
        const correlation_id = record.envelope.correlation_id orelse return error.MissingRequest;
        const name = try replyRecordFileName(self.allocator, self.options, correlation_id);
        defer self.allocator.free(name);
        const content = try formatStoredReplyRecordJson(self.allocator, record);
        defer self.allocator.free(content);
        try self.writeAtomicFile(name, content);
    }

    fn readMessageRecordWithAllocator(self: *FileMessageStorage, name: []const u8, allocator: Allocator) !?StoredMessageRecord {
        const content = self.dir.readFileAlloc(
            self.io,
            name,
            self.allocator,
            std.Io.Limit.limited(self.options.max_record_bytes),
        ) catch |err| switch (err) {
            error.FileNotFound => return null,
            else => return err,
        };
        defer self.allocator.free(content);
        return try parseStoredMessageRecordJson(allocator, content);
    }

    fn readReplyRecordWithAllocator(self: *FileMessageStorage, name: []const u8, allocator: Allocator) !?StoredReplyRecord {
        const content = self.dir.readFileAlloc(
            self.io,
            name,
            self.allocator,
            std.Io.Limit.limited(self.options.max_record_bytes),
        ) catch |err| switch (err) {
            error.FileNotFound => return null,
            else => return err,
        };
        defer self.allocator.free(content);
        return try parseStoredReplyRecordJson(allocator, content);
    }

    fn writeAtomicFile(self: *FileMessageStorage, name: []const u8, content: []const u8) !void {
        var file = try self.dir.createFileAtomic(self.io, name, .{ .replace = true });
        defer file.deinit(self.io);
        try file.file.writeStreamingAll(self.io, content);
        try file.replace(self.io);
    }
};

const StoredMessageRecordJson = struct {
    schema: []const u8,
    schema_version: u32,
    shard_id: ShardId,
    status: []const u8,
    stored_at_ms: u64,
    updated_at_ms: u64,
    id: MessageId,
    kind: []const u8,
    entity_type_name: []const u8,
    entity_id: u64,
    correlation_id: ?MessageCorrelationId = null,
    idempotency_key: []const u8 = "",
    attempt: envelope_mod.MessageAttempt = 0,
    trace_id: ?u64 = null,
    span_id: ?u64 = null,
    origin_causal_event_id: ?u64 = null,
    chunk_index: ?u32 = null,
    chunk_count: ?u32 = null,
    payload_type_name: []const u8 = "",
    payload: []const u8 = "",
    redacted_detail: []const u8 = "",
    lease_epoch: ?ShardLeaseEpoch = null,
};

const StoredReplyRecordJson = struct {
    schema: []const u8,
    schema_version: u32,
    shard_id: ShardId,
    stored_at_ms: u64,
    id: MessageId,
    kind: []const u8,
    entity_type_name: []const u8,
    entity_id: u64,
    correlation_id: ?MessageCorrelationId = null,
    idempotency_key: []const u8 = "",
    attempt: envelope_mod.MessageAttempt = 0,
    trace_id: ?u64 = null,
    span_id: ?u64 = null,
    origin_causal_event_id: ?u64 = null,
    chunk_index: ?u32 = null,
    chunk_count: ?u32 = null,
    payload_type_name: []const u8 = "",
    payload: []const u8 = "",
    redacted_detail: []const u8 = "",
    lease_epoch: ?ShardLeaseEpoch = null,
};

pub fn messageRecordFileName(allocator: Allocator, options: FileMessageStorageOptions, message_id_value: MessageId) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}{d}{s}", .{ options.message_prefix, message_id_value, options.suffix });
}

pub fn replyRecordFileName(allocator: Allocator, options: FileMessageStorageOptions, correlation_id: MessageCorrelationId) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}{d}{s}", .{ options.reply_prefix, correlation_id, options.suffix });
}

fn messageIdFromFileName(options: FileMessageStorageOptions, name: []const u8) ?MessageId {
    if (!std.mem.startsWith(u8, name, options.message_prefix)) return null;
    if (!std.mem.endsWith(u8, name, options.suffix)) return null;
    const start = options.message_prefix.len;
    const end = name.len - options.suffix.len;
    if (end <= start) return null;
    return std.fmt.parseUnsigned(MessageId, name[start..end], 10) catch null;
}

fn replyCorrelationIdFromFileName(options: FileMessageStorageOptions, name: []const u8) ?MessageCorrelationId {
    if (!std.mem.startsWith(u8, name, options.reply_prefix)) return null;
    if (!std.mem.endsWith(u8, name, options.suffix)) return null;
    const start = options.reply_prefix.len;
    const end = name.len - options.suffix.len;
    if (end <= start) return null;
    return std.fmt.parseUnsigned(MessageCorrelationId, name[start..end], 10) catch null;
}

pub fn formatStoredMessageRecordJson(allocator: Allocator, record: StoredMessageRecord) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, message_record_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{message_record_schema_version});
    try output.print(allocator, ",\"shard_id\":{d}", .{record.shard_id});
    try output.appendSlice(allocator, ",\"status\":");
    try appendJsonString(&output, allocator, @tagName(record.status));
    try output.print(allocator, ",\"stored_at_ms\":{d}", .{record.stored_at_ms});
    try output.print(allocator, ",\"updated_at_ms\":{d}", .{record.updated_at_ms});
    var envelope = record.envelope;
    envelope.lease_epoch = record.lease_epoch orelse envelope.lease_epoch;
    try appendEnvelopeJsonFields(&output, allocator, envelope);
    try output.append(allocator, '}');
    return output.toOwnedSlice(allocator);
}

pub fn parseStoredMessageRecordJson(allocator: Allocator, content: []const u8) (Allocator.Error || MessageStorageError)!StoredMessageRecord {
    var parsed = std.json.parseFromSlice(StoredMessageRecordJson, allocator, content, .{ .ignore_unknown_fields = true }) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.CorruptMessageFile,
    };
    defer parsed.deinit();

    if (!std.mem.eql(u8, parsed.value.schema, message_record_schema)) return error.CorruptMessageFile;
    if (parsed.value.schema_version != message_record_schema_version) return error.CorruptMessageFile;
    const status = std.meta.stringToEnum(MessageDeliveryStatus, parsed.value.status) orelse return error.CorruptMessageFile;
    const kind = std.meta.stringToEnum(envelope_mod.MessageEnvelopeKind, parsed.value.kind) orelse return error.CorruptMessageFile;

    return .{
        .shard_id = parsed.value.shard_id,
        .envelope = try envelopeFromJson(allocator, parsed.value, kind),
        .status = status,
        .stored_at_ms = parsed.value.stored_at_ms,
        .updated_at_ms = parsed.value.updated_at_ms,
        .lease_epoch = parsed.value.lease_epoch,
    };
}

pub fn formatStoredReplyRecordJson(allocator: Allocator, record: StoredReplyRecord) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, message_reply_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{message_reply_schema_version});
    try output.print(allocator, ",\"shard_id\":{d}", .{record.shard_id});
    try output.print(allocator, ",\"stored_at_ms\":{d}", .{record.stored_at_ms});
    var envelope = record.envelope;
    envelope.lease_epoch = record.lease_epoch orelse envelope.lease_epoch;
    try appendEnvelopeJsonFields(&output, allocator, envelope);
    try output.append(allocator, '}');
    return output.toOwnedSlice(allocator);
}

pub fn parseStoredReplyRecordJson(allocator: Allocator, content: []const u8) (Allocator.Error || MessageStorageError)!StoredReplyRecord {
    var parsed = std.json.parseFromSlice(StoredReplyRecordJson, allocator, content, .{ .ignore_unknown_fields = true }) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.CorruptMessageFile,
    };
    defer parsed.deinit();

    if (!std.mem.eql(u8, parsed.value.schema, message_reply_schema)) return error.CorruptMessageFile;
    if (parsed.value.schema_version != message_reply_schema_version) return error.CorruptMessageFile;
    const kind = std.meta.stringToEnum(envelope_mod.MessageEnvelopeKind, parsed.value.kind) orelse return error.CorruptMessageFile;

    return .{
        .shard_id = parsed.value.shard_id,
        .envelope = try envelopeFromJson(allocator, parsed.value, kind),
        .stored_at_ms = parsed.value.stored_at_ms,
        .lease_epoch = parsed.value.lease_epoch,
    };
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: Allocator, value: []const u8) Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

fn appendOptionalJsonU64(output: *std.ArrayList(u8), allocator: Allocator, value: ?u64) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendEnvelopeJsonFields(output: *std.ArrayList(u8), allocator: Allocator, envelope: MessageEnvelope) Allocator.Error!void {
    try output.print(allocator, ",\"id\":{d}", .{envelope.id});
    try output.appendSlice(allocator, ",\"kind\":");
    try appendJsonString(output, allocator, @tagName(envelope.kind));
    try output.appendSlice(allocator, ",\"entity_type_name\":");
    try appendJsonString(output, allocator, envelope.address.entity_type.name);
    try output.print(allocator, ",\"entity_id\":{d}", .{envelope.address.id});
    try output.appendSlice(allocator, ",\"correlation_id\":");
    try appendOptionalJsonU64(output, allocator, envelope.correlation_id);
    try output.appendSlice(allocator, ",\"idempotency_key\":");
    try appendJsonString(output, allocator, envelope.idempotency_key);
    try output.print(allocator, ",\"attempt\":{d}", .{envelope.attempt});
    try output.appendSlice(allocator, ",\"trace_id\":");
    try appendOptionalJsonU64(output, allocator, envelope.trace_id);
    try output.appendSlice(allocator, ",\"span_id\":");
    try appendOptionalJsonU64(output, allocator, envelope.span_id);
    try output.appendSlice(allocator, ",\"origin_causal_event_id\":");
    try appendOptionalJsonU64(output, allocator, envelope.origin_causal_event_id);
    try output.appendSlice(allocator, ",\"chunk_index\":");
    try appendOptionalJsonU64(output, allocator, if (envelope.chunk_index) |index| @as(u64, index) else null);
    try output.appendSlice(allocator, ",\"chunk_count\":");
    try appendOptionalJsonU64(output, allocator, if (envelope.chunk_count) |count| @as(u64, count) else null);
    try output.appendSlice(allocator, ",\"lease_epoch\":");
    try appendOptionalJsonU64(output, allocator, envelope.lease_epoch);
    try output.appendSlice(allocator, ",\"payload_type_name\":");
    try appendJsonString(output, allocator, envelope.payload_type_name);
    try output.appendSlice(allocator, ",\"payload\":");
    try appendJsonString(output, allocator, envelope.payload);
    try output.appendSlice(allocator, ",\"redacted_detail\":");
    try appendJsonString(output, allocator, envelope.redacted_detail);
}

fn envelopeFromJson(allocator: Allocator, value: anytype, kind: envelope_mod.MessageEnvelopeKind) Allocator.Error!MessageEnvelope {
    const entity_type_name = try allocator.dupe(u8, value.entity_type_name);
    errdefer allocator.free(entity_type_name);
    const idempotency_key = if (value.idempotency_key.len == 0) "" else try allocator.dupe(u8, value.idempotency_key);
    errdefer if (idempotency_key.len > 0) allocator.free(idempotency_key);
    const payload_type_name = if (value.payload_type_name.len == 0) "" else try allocator.dupe(u8, value.payload_type_name);
    errdefer if (payload_type_name.len > 0) allocator.free(payload_type_name);
    const payload = if (value.payload.len == 0) "" else try allocator.dupe(u8, value.payload);
    errdefer if (payload.len > 0) allocator.free(payload);
    const redacted_detail = if (value.redacted_detail.len == 0) "" else try allocator.dupe(u8, value.redacted_detail);
    errdefer if (redacted_detail.len > 0) allocator.free(redacted_detail);

    return .{
        .id = value.id,
        .kind = kind,
        .address = .{
            .entity_type = .{ .name = entity_type_name },
            .id = value.entity_id,
        },
        .correlation_id = value.correlation_id,
        .idempotency_key = idempotency_key,
        .attempt = value.attempt,
        .trace_id = value.trace_id,
        .span_id = value.span_id,
        .origin_causal_event_id = value.origin_causal_event_id,
        .chunk_index = value.chunk_index,
        .chunk_count = value.chunk_count,
        .lease_epoch = value.lease_epoch,
        .payload_type_name = payload_type_name,
        .payload = payload,
        .redacted_detail = redacted_detail,
    };
}

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
        .lease_epoch = record.lease_epoch,
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

fn fileSubmit(context: *anyopaque, request: MessageStorageSubmit) anyerror!MessageSubmitResult {
    const storage: *FileMessageStorage = @ptrCast(@alignCast(context));
    return storage.submit(request);
}

fn fileClaim(context: *anyopaque, request: MessageStorageClaim) anyerror!MessageEnvelope {
    const storage: *FileMessageStorage = @ptrCast(@alignCast(context));
    return storage.claim(request);
}

fn fileAck(context: *anyopaque, request: MessageStorageAck) anyerror!void {
    const storage: *FileMessageStorage = @ptrCast(@alignCast(context));
    return storage.ack(request);
}

fn fileStoreReply(context: *anyopaque, request: MessageStorageReply) anyerror!MessageEnvelope {
    const storage: *FileMessageStorage = @ptrCast(@alignCast(context));
    return storage.storeReply(request);
}

fn fileReply(context: *anyopaque, correlation_id: MessageCorrelationId, allocator: Allocator) anyerror!?MessageEnvelope {
    const storage: *FileMessageStorage = @ptrCast(@alignCast(context));
    return storage.reply(correlation_id, allocator);
}

fn fileUnprocessedByShard(context: *anyopaque, shard_id: ShardId, allocator: Allocator) anyerror!MessageRecordBatch {
    const storage: *FileMessageStorage = @ptrCast(@alignCast(context));
    return storage.unprocessedByShard(shard_id, allocator);
}

fn fileUnprocessedById(context: *anyopaque, message_id_value: MessageId, allocator: Allocator) anyerror!?StoredMessageRecord {
    const storage: *FileMessageStorage = @ptrCast(@alignCast(context));
    return storage.unprocessedById(message_id_value, allocator);
}

fn fileReset(context: *anyopaque) void {
    const storage: *FileMessageStorage = @ptrCast(@alignCast(context));
    storage.reset();
}

const file_vtable: MessageStorage.VTable = .{
    .submit = fileSubmit,
    .claim = fileClaim,
    .ack = fileAck,
    .store_reply = fileStoreReply,
    .reply = fileReply,
    .unprocessed_by_shard = fileUnprocessedByShard,
    .unprocessed_by_id = fileUnprocessedById,
    .reset = fileReset,
};
