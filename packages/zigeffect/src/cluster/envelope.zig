const std = @import("std");
const identity = @import("identity.zig");
const mailbox_mod = @import("mailbox.zig");

pub const Allocator = std.mem.Allocator;
pub const EntityAddress = identity.EntityAddress;
pub const MessageId = u64;
pub const MessageCorrelationId = u64;
pub const MessageAttempt = u32;

pub const MessageEnvelopeKind = enum {
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
    chunk_index: ?u32 = null,
    chunk_count: ?u32 = null,
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

pub const MessageDeliveryTracker = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) MessageDeliveryTracker {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *MessageDeliveryTracker) void {
        _ = self;
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
        "zigeffect message\nid: {d}\nkind: {s}\nentity: {s}/{d}\ncorrelation: {?d}\nattempt: {d}\ntype: {s}\ndetail: {s}",
        .{
            envelope.id,
            @tagName(envelope.kind),
            envelope.address.entity_type.name,
            envelope.address.id,
            envelope.correlation_id,
            envelope.attempt,
            envelope.payload_type_name,
            envelope.redacted_detail,
        },
    );
}
