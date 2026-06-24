const std = @import("std");
const identity = @import("identity.zig");
const mailbox_mod = @import("mailbox.zig");
const runner_storage = @import("runner_storage.zig");

pub const Allocator = std.mem.Allocator;
pub const EntityAddress = identity.EntityAddress;
pub const MessageId = u64;
pub const MessageCorrelationId = u64;
pub const MessageAttempt = u32;

pub const MessageEnvelopeKind = enum {
    tell,
    request,
    reply,
    ack,
    interrupt,
    chunk_reply,
};

pub const MessageDeliveryStatus = enum {
    pending,
    claimed,
    acknowledged,
    replied,
    interrupted,
};

pub const MessageEnvelope = struct {
    id: MessageId = 0,
    kind: MessageEnvelopeKind,
    address: EntityAddress,
    correlation_id: ?MessageCorrelationId = null,
    idempotency_key: []const u8 = "",
    attempt: MessageAttempt = 0,
    trace_id: ?u64 = null,
    span_id: ?u64 = null,
    origin_causal_event_id: ?u64 = null,
    chunk_index: ?u32 = null,
    chunk_count: ?u32 = null,
    lease_epoch: ?runner_storage.ShardLeaseEpoch = null,
    payload_type_name: []const u8 = "",
    payload: []const u8 = "",
    redacted_detail: []const u8 = "",
};

pub const MessageDeliveryError = error{
    MessageNotFound,
    MissingRequest,
    DuplicateReply,
};

pub const MessageSubmitResult = struct {
    envelope: MessageEnvelope,
    duplicate: bool = false,

    pub fn deinit(self: *MessageSubmitResult, allocator: Allocator) void {
        deinitMessageEnvelope(allocator, self.envelope);
    }
};

const StoredMessage = struct {
    envelope: MessageEnvelope,
    status: MessageDeliveryStatus = .pending,
};

pub const MessageDeliveryTracker = struct {
    allocator: Allocator,
    messages: std.ArrayList(StoredMessage) = .empty,
    replies: std.ArrayList(MessageEnvelope) = .empty,

    pub fn init(allocator: Allocator) MessageDeliveryTracker {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *MessageDeliveryTracker) void {
        for (self.messages.items) |stored| {
            deinitMessageEnvelope(self.allocator, stored.envelope);
        }
        self.messages.deinit(self.allocator);
        for (self.replies.items) |reply| {
            deinitMessageEnvelope(self.allocator, reply);
        }
        self.replies.deinit(self.allocator);
    }

    pub fn submit(self: *MessageDeliveryTracker, envelope: MessageEnvelope) Allocator.Error!MessageSubmitResult {
        if (self.findDuplicate(envelope)) |stored| {
            return .{
                .envelope = try cloneMessageEnvelope(self.allocator, stored.envelope),
                .duplicate = true,
            };
        }

        const owned = try self.prepareEnvelope(envelope);
        errdefer deinitMessageEnvelope(self.allocator, owned);
        const returned = try cloneMessageEnvelope(self.allocator, owned);
        errdefer deinitMessageEnvelope(self.allocator, returned);
        try self.messages.append(self.allocator, .{ .envelope = owned });
        return .{ .envelope = returned };
    }

    pub fn claimNext(self: *MessageDeliveryTracker, address: EntityAddress) (Allocator.Error || MessageDeliveryError)!MessageEnvelope {
        for (self.messages.items) |*stored| {
            if (!stored.envelope.address.eql(address)) continue;
            if (stored.status == .acknowledged) continue;
            stored.status = .claimed;
            stored.envelope.attempt += 1;
            return cloneMessageEnvelope(self.allocator, stored.envelope);
        }
        return error.MessageNotFound;
    }

    pub fn ack(self: *MessageDeliveryTracker, message_id: MessageId) MessageDeliveryError!void {
        for (self.messages.items) |*stored| {
            if (stored.envelope.id == message_id) {
                stored.status = .acknowledged;
                return;
            }
        }
        return error.MessageNotFound;
    }

    pub fn storeReply(self: *MessageDeliveryTracker, reply: MessageEnvelope) (Allocator.Error || MessageDeliveryError)!MessageEnvelope {
        const correlation_id = reply.correlation_id orelse return error.MissingRequest;
        if (self.findRequestByCorrelation(correlation_id) == null) return error.MissingRequest;
        if (self.findReplyByCorrelation(correlation_id) != null) return error.DuplicateReply;

        const owned = try self.prepareEnvelope(reply);
        errdefer deinitMessageEnvelope(self.allocator, owned);
        const returned = try cloneMessageEnvelope(self.allocator, owned);
        errdefer deinitMessageEnvelope(self.allocator, returned);
        try self.replies.append(self.allocator, owned);
        return returned;
    }

    pub fn pendingCount(self: *const MessageDeliveryTracker, address: EntityAddress) usize {
        var count: usize = 0;
        for (self.messages.items) |stored| {
            if (!stored.envelope.address.eql(address)) continue;
            if (stored.status == .acknowledged) continue;
            count += 1;
        }
        return count;
    }

    fn findDuplicate(self: *const MessageDeliveryTracker, envelope: MessageEnvelope) ?StoredMessage {
        for (self.messages.items) |stored| {
            if (stored.envelope.kind != envelope.kind) continue;
            if (!stored.envelope.address.eql(envelope.address)) continue;
            if (!std.mem.eql(u8, stored.envelope.idempotency_key, envelope.idempotency_key)) continue;
            return stored;
        }
        return null;
    }

    fn findRequestByCorrelation(self: *const MessageDeliveryTracker, correlation_id: MessageCorrelationId) ?StoredMessage {
        for (self.messages.items) |stored| {
            if (stored.envelope.kind != .request) continue;
            if (stored.envelope.correlation_id == correlation_id) return stored;
        }
        return null;
    }

    fn findReplyByCorrelation(self: *const MessageDeliveryTracker, correlation_id: MessageCorrelationId) ?MessageEnvelope {
        for (self.replies.items) |reply| {
            if (reply.correlation_id == correlation_id) return reply;
        }
        return null;
    }

    fn prepareEnvelope(self: *MessageDeliveryTracker, envelope: MessageEnvelope) Allocator.Error!MessageEnvelope {
        var owned = try cloneMessageEnvelope(self.allocator, envelope);
        owned.id = if (owned.id == 0) computedMessageId(owned) else owned.id;
        if (owned.kind == .request and owned.correlation_id == null) {
            owned.correlation_id = messageCorrelationId(owned.id);
        }
        return owned;
    }
};

pub fn messageId(address: EntityAddress, kind: MessageEnvelopeKind, idempotency_key: []const u8) MessageId {
    var hasher = std.hash.Fnv1a_64.init();
    var id_buf: [20]u8 = undefined;
    const id_text = std.fmt.bufPrint(&id_buf, "{d}", .{address.id}) catch unreachable;
    hasher.update(address.entity_type.name);
    hasher.update(":");
    hasher.update(id_text);
    hasher.update(":");
    hasher.update(@tagName(kind));
    hasher.update(":");
    hasher.update(idempotency_key);
    return hasher.final();
}

pub fn messageCorrelationId(message_id: MessageId) MessageCorrelationId {
    return message_id;
}

fn computedMessageId(envelope: MessageEnvelope) MessageId {
    var key_buf: [20]u8 = undefined;
    const key = if (envelope.idempotency_key.len > 0)
        envelope.idempotency_key
    else if (envelope.correlation_id) |correlation_id|
        std.fmt.bufPrint(&key_buf, "{d}", .{correlation_id}) catch unreachable
    else
        "";
    return messageId(envelope.address, envelope.kind, key);
}

pub fn cloneMessageEnvelope(allocator: Allocator, envelope: MessageEnvelope) Allocator.Error!MessageEnvelope {
    var owned = envelope;
    owned.address = try mailbox_mod.cloneEntityAddress(allocator, envelope.address);
    errdefer mailbox_mod.deinitEntityAddress(allocator, owned.address);

    owned.idempotency_key = if (envelope.idempotency_key.len == 0) "" else try allocator.dupe(u8, envelope.idempotency_key);
    errdefer if (owned.idempotency_key.len > 0) allocator.free(owned.idempotency_key);

    owned.payload_type_name = if (envelope.payload_type_name.len == 0) "" else try allocator.dupe(u8, envelope.payload_type_name);
    errdefer if (owned.payload_type_name.len > 0) allocator.free(owned.payload_type_name);

    owned.payload = if (envelope.payload.len == 0) "" else try allocator.dupe(u8, envelope.payload);
    errdefer if (owned.payload.len > 0) allocator.free(owned.payload);

    owned.redacted_detail = if (envelope.redacted_detail.len == 0) "" else try allocator.dupe(u8, envelope.redacted_detail);
    return owned;
}

pub fn deinitMessageEnvelope(allocator: Allocator, envelope: MessageEnvelope) void {
    mailbox_mod.deinitEntityAddress(allocator, envelope.address);
    if (envelope.idempotency_key.len > 0) allocator.free(envelope.idempotency_key);
    if (envelope.payload_type_name.len > 0) allocator.free(envelope.payload_type_name);
    if (envelope.payload.len > 0) allocator.free(envelope.payload);
    if (envelope.redacted_detail.len > 0) allocator.free(envelope.redacted_detail);
}

pub fn formatMessageDiagnostic(allocator: Allocator, envelope: MessageEnvelope) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "zigeffect message\nid: {d}\nkind: {s}\nentity: {s}/{d}\ncorrelation: {?d}\nattempt: {d}\norigin_causal_event_id: {?d}\nchunk: {d}/{d}\ntype: {s}\ndetail: {s}",
        .{
            envelope.id,
            @tagName(envelope.kind),
            envelope.address.entity_type.name,
            envelope.address.id,
            envelope.correlation_id,
            envelope.attempt,
            envelope.origin_causal_event_id,
            envelope.chunk_index orelse 0,
            envelope.chunk_count orelse 0,
            envelope.payload_type_name,
            envelope.redacted_detail,
        },
    );
}
