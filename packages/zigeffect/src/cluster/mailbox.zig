const std = @import("std");
const identity = @import("identity.zig");

pub const Allocator = std.mem.Allocator;
pub const EntityAddress = identity.EntityAddress;
pub const EntityMessageId = u64;
pub const EntityCorrelationId = u64;
pub const EntityMessageSequence = u64;

pub const EntityEnvelopeKind = enum { tell, ask, reply, interrupt };

pub const EntityEnvelope = struct {
    id: EntityMessageId = 0,
    sequence: EntityMessageSequence = 0,
    kind: EntityEnvelopeKind,
    address: EntityAddress,
    correlation_id: ?EntityCorrelationId = null,
    payload_type_name: []const u8 = "",
    payload: []const u8 = "",
    redacted_detail: []const u8 = "",
};

pub const EntityAsk = struct {
    envelope: EntityEnvelope,
    correlation_id: EntityCorrelationId,

    pub fn deinit(self: *EntityAsk, allocator: Allocator) void {
        deinitEntityEnvelope(allocator, self.envelope);
    }
};

pub const EntityMailboxError = error{
    MailboxEmpty,
    MailboxFull,
    ReplyNotFound,
};

const Mailbox = struct {
    address: EntityAddress,
    items: std.ArrayList(EntityEnvelope) = .empty,
};

pub const LocalMailboxStoreOptions = struct {
    max_total_pending: ?usize = null,
    max_pending_per_mailbox: ?usize = null,
};

pub const LocalMailboxStats = struct {
    mailbox_count: usize = 0,
    total_pending: usize = 0,
    max_mailbox_pending: usize = 0,
    max_total_pending: ?usize = null,
    max_pending_per_mailbox: ?usize = null,
    backpressured_mailboxes: usize = 0,
};

pub fn cloneEntityAddress(allocator: Allocator, address: EntityAddress) Allocator.Error!EntityAddress {
    return .{
        .entity_type = .{ .name = try allocator.dupe(u8, address.entity_type.name) },
        .id = address.id,
    };
}

pub fn deinitEntityAddress(allocator: Allocator, address: EntityAddress) void {
    if (address.entity_type.name.len > 0) allocator.free(address.entity_type.name);
}

pub fn cloneEntityEnvelope(allocator: Allocator, envelope: EntityEnvelope) Allocator.Error!EntityEnvelope {
    var owned = envelope;
    owned.address = try cloneEntityAddress(allocator, envelope.address);
    errdefer deinitEntityAddress(allocator, owned.address);

    owned.payload_type_name = if (envelope.payload_type_name.len == 0) "" else try allocator.dupe(u8, envelope.payload_type_name);
    errdefer if (owned.payload_type_name.len > 0) allocator.free(owned.payload_type_name);

    owned.payload = if (envelope.payload.len == 0) "" else try allocator.dupe(u8, envelope.payload);
    errdefer if (owned.payload.len > 0) allocator.free(owned.payload);

    owned.redacted_detail = if (envelope.redacted_detail.len == 0) "" else try allocator.dupe(u8, envelope.redacted_detail);
    return owned;
}

pub fn deinitEntityEnvelope(allocator: Allocator, envelope: EntityEnvelope) void {
    deinitEntityAddress(allocator, envelope.address);
    if (envelope.payload_type_name.len > 0) allocator.free(envelope.payload_type_name);
    if (envelope.payload.len > 0) allocator.free(envelope.payload);
    if (envelope.redacted_detail.len > 0) allocator.free(envelope.redacted_detail);
}

pub const LocalMailboxStore = struct {
    allocator: Allocator,
    options: LocalMailboxStoreOptions = .{},
    mailboxes: std.ArrayList(Mailbox) = .empty,
    replies: std.ArrayList(EntityEnvelope) = .empty,
    next_message_id: EntityMessageId = 1,
    next_sequence: EntityMessageSequence = 1,
    next_correlation_id: EntityCorrelationId = 1,
    total_pending: usize = 0,

    pub fn init(allocator: Allocator) LocalMailboxStore {
        return initBounded(allocator, .{});
    }

    pub fn initBounded(allocator: Allocator, options: LocalMailboxStoreOptions) LocalMailboxStore {
        return .{
            .allocator = allocator,
            .options = options,
        };
    }

    pub fn deinit(self: *LocalMailboxStore) void {
        for (self.mailboxes.items) |*mailbox| {
            for (mailbox.items.items) |item| {
                deinitEntityEnvelope(self.allocator, item);
            }
            mailbox.items.deinit(self.allocator);
            deinitEntityAddress(self.allocator, mailbox.address);
        }
        self.mailboxes.deinit(self.allocator);

        for (self.replies.items) |reply| {
            deinitEntityEnvelope(self.allocator, reply);
        }
        self.replies.deinit(self.allocator);
    }

    pub fn offer(self: *LocalMailboxStore, envelope: EntityEnvelope) (Allocator.Error || EntityMailboxError)!EntityEnvelope {
        try self.ensureCanOffer(envelope.address);

        const owned = try self.prepareEnvelope(envelope);
        errdefer deinitEntityEnvelope(self.allocator, owned);

        const returned = try cloneEntityEnvelope(self.allocator, owned);
        errdefer deinitEntityEnvelope(self.allocator, returned);

        const mailbox = try self.mailboxFor(owned.address);
        try mailbox.items.append(self.allocator, owned);
        self.total_pending += 1;
        return returned;
    }

    pub fn take(self: *LocalMailboxStore, address: EntityAddress) (Allocator.Error || EntityMailboxError)!EntityEnvelope {
        const mailbox = self.findMailbox(address) orelse return error.MailboxEmpty;
        if (mailbox.items.items.len == 0) return error.MailboxEmpty;
        self.total_pending -= 1;
        return mailbox.items.orderedRemove(0);
    }

    pub fn pendingCount(self: *const LocalMailboxStore, address: EntityAddress) usize {
        const mailbox = self.findMailboxConst(address) orelse return 0;
        return mailbox.items.items.len;
    }

    pub fn storeReply(self: *LocalMailboxStore, envelope: EntityEnvelope) Allocator.Error!EntityEnvelope {
        const owned = try self.prepareEnvelope(envelope);
        errdefer deinitEntityEnvelope(self.allocator, owned);

        const returned = try cloneEntityEnvelope(self.allocator, owned);
        errdefer deinitEntityEnvelope(self.allocator, returned);

        try self.replies.append(self.allocator, owned);
        return returned;
    }

    pub fn takeReply(self: *LocalMailboxStore, correlation_id: EntityCorrelationId) (Allocator.Error || EntityMailboxError)!EntityEnvelope {
        for (self.replies.items, 0..) |reply, index| {
            if (reply.correlation_id == correlation_id) return self.replies.orderedRemove(index);
        }
        return error.ReplyNotFound;
    }

    pub fn stats(self: *const LocalMailboxStore) LocalMailboxStats {
        var max_mailbox_pending: usize = 0;
        var backpressured_mailboxes: usize = 0;
        const total_full = if (self.options.max_total_pending) |max_total| self.total_pending >= max_total else false;
        for (self.mailboxes.items) |mailbox| {
            const pending = mailbox.items.items.len;
            max_mailbox_pending = @max(max_mailbox_pending, pending);
            const mailbox_full = if (self.options.max_pending_per_mailbox) |max_pending| pending >= max_pending else false;
            if (total_full or mailbox_full) backpressured_mailboxes += 1;
        }
        return .{
            .mailbox_count = self.mailboxes.items.len,
            .total_pending = self.total_pending,
            .max_mailbox_pending = max_mailbox_pending,
            .max_total_pending = self.options.max_total_pending,
            .max_pending_per_mailbox = self.options.max_pending_per_mailbox,
            .backpressured_mailboxes = backpressured_mailboxes,
        };
    }

    fn ensureCanOffer(self: *const LocalMailboxStore, address: EntityAddress) EntityMailboxError!void {
        if (self.options.max_total_pending) |max_total| {
            if (self.total_pending >= max_total) return error.MailboxFull;
        }
        if (self.options.max_pending_per_mailbox) |max_pending| {
            const pending = if (self.findMailboxConst(address)) |mailbox| mailbox.items.items.len else 0;
            if (pending >= max_pending) return error.MailboxFull;
        }
    }

    fn prepareEnvelope(self: *LocalMailboxStore, envelope: EntityEnvelope) Allocator.Error!EntityEnvelope {
        var owned = try cloneEntityEnvelope(self.allocator, envelope);
        owned.id = if (owned.id == 0) self.nextMessageId() else owned.id;
        owned.sequence = if (owned.sequence == 0) self.nextSequence() else owned.sequence;
        if (owned.kind == .ask and owned.correlation_id == null) owned.correlation_id = self.nextCorrelationId();
        return owned;
    }

    fn nextMessageId(self: *LocalMailboxStore) EntityMessageId {
        const id = self.next_message_id;
        self.next_message_id += 1;
        return id;
    }

    fn nextSequence(self: *LocalMailboxStore) EntityMessageSequence {
        const sequence = self.next_sequence;
        self.next_sequence += 1;
        return sequence;
    }

    fn nextCorrelationId(self: *LocalMailboxStore) EntityCorrelationId {
        const id = self.next_correlation_id;
        self.next_correlation_id += 1;
        return id;
    }

    fn mailboxFor(self: *LocalMailboxStore, address: EntityAddress) Allocator.Error!*Mailbox {
        if (self.findMailbox(address)) |mailbox| return mailbox;
        try self.mailboxes.append(self.allocator, .{
            .address = try cloneEntityAddress(self.allocator, address),
        });
        return &self.mailboxes.items[self.mailboxes.items.len - 1];
    }

    fn findMailbox(self: *LocalMailboxStore, address: EntityAddress) ?*Mailbox {
        for (self.mailboxes.items) |*mailbox| {
            if (mailbox.address.eql(address)) return mailbox;
        }
        return null;
    }

    fn findMailboxConst(self: *const LocalMailboxStore, address: EntityAddress) ?*const Mailbox {
        for (self.mailboxes.items) |*mailbox| {
            if (mailbox.address.eql(address)) return mailbox;
        }
        return null;
    }
};
