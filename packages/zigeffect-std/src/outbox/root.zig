const std = @import("std");
const Sql = @import("../sql/root.zig");
const Capability = @import("../capability/root.zig");
const External = @import("../external/root.zig");

pub const deterministic_capability = Capability.Descriptor{ .id = "zigeffect-std.outbox.contract", .kind = .message_storage, .maturity = .deterministic_model, .package = "zigeffect-std", .version = "0.1.0", .features = &.{ "transactional-unit-of-work", "outbox", "inbox", "idempotency" }, .side_effects = .modeled };

pub const Enqueue = struct { id: ?u64 = null, topic: []const u8, idempotency_key: []const u8, payload: []const u8, now_ms: u64 };
pub const Message = struct {
    allocator: std.mem.Allocator, id: u64, topic: []const u8, idempotency_key: []const u8, payload: []const u8, attempt: u32, visible_at_ms: u64, duplicate: bool = false,
    pub fn deinit(self: *Message) void { self.allocator.free(self.topic); self.allocator.free(self.idempotency_key); self.allocator.free(self.payload); self.* = undefined; }
};
pub const InboxRecord = struct { consumer: []const u8, idempotency_key: []const u8, payload: []const u8, now_ms: u64 };
pub const InboxOutcome = struct { duplicate: bool = false };

pub const UnitOfWork = struct {
    pointer: *anyopaque,
    execute_fn: *const fn (*anyopaque, std.mem.Allocator, Sql.Statement) anyerror!void,
    enqueue_fn: *const fn (*anyopaque, Enqueue) anyerror!Message,
    inbox_fn: *const fn (*anyopaque, InboxRecord) anyerror!InboxOutcome,
    commit_fn: *const fn (*anyopaque) anyerror!void,
    rollback_fn: *const fn (*anyopaque) anyerror!void,
    deinit_fn: *const fn (*anyopaque) void,
    finished: bool = false,

    pub fn execute(self: *UnitOfWork, allocator: std.mem.Allocator, statement: Sql.Statement) !void { if (self.finished) return error.UnitOfWorkFinished; return self.execute_fn(self.pointer, allocator, statement); }
    pub fn enqueue(self: *UnitOfWork, request: Enqueue) !Message { if (self.finished) return error.UnitOfWorkFinished; return self.enqueue_fn(self.pointer, request); }
    pub fn recordInbox(self: *UnitOfWork, request: InboxRecord) !InboxOutcome { if (self.finished) return error.UnitOfWorkFinished; return self.inbox_fn(self.pointer, request); }
    pub fn commit(self: *UnitOfWork) !void { if (self.finished) return; try self.commit_fn(self.pointer); self.finished = true; }
    pub fn rollback(self: *UnitOfWork) !void { if (self.finished) return; try self.rollback_fn(self.pointer); self.finished = true; }
    pub fn deinit(self: *UnitOfWork) void { if (!self.finished) self.rollback_fn(self.pointer) catch {}; self.deinit_fn(self.pointer); self.* = undefined; }
};

pub const Store = struct {
    pointer: *anyopaque,
    begin_fn: *const fn (*anyopaque, std.mem.Allocator) anyerror!UnitOfWork,
    claim_fn: *const fn (*anyopaque, u64) anyerror!Message,
    delivered_fn: *const fn (*anyopaque, u64, u64) anyerror!void,
    pub fn begin(self: Store, allocator: std.mem.Allocator) !UnitOfWork { return self.begin_fn(self.pointer, allocator); }
    pub fn claimNext(self: Store, now_ms: u64) !Message { return self.claim_fn(self.pointer, now_ms); }
    pub fn markDelivered(self: Store, id: u64, now_ms: u64) !void { return self.delivered_fn(self.pointer, id, now_ms); }
};

pub fn classifyError(err: anyerror) External.Failure {
    return External.Failure.init("outbox", "unit-of-work", switch (err) {
        error.OutboxEmpty => .not_found,
        error.IdempotencyPayloadMismatch, error.InboxConflict => .conflict,
        error.UnitOfWorkFinished, error.InvalidOutboxMessage => .invalid_input,
        error.ConnectionRefused, error.PostgresConnectionFailed => .unavailable,
        else => External.classifyError(err),
    }, @errorName(err), @errorName(err));
}

test "outbox contract classifies idempotency and lifecycle failures" {
    try std.testing.expectEqual(External.Class.conflict, classifyError(error.IdempotencyPayloadMismatch).class);
    try std.testing.expectEqual(External.Class.invalid_input, classifyError(error.UnitOfWorkFinished).class);
}
