const std = @import("std");
const zstd = @import("zigeffect_std");
const shared = @import("shared");
const ModelClock = @import("model_clock.zig");

const StoredOrder = struct { id: []u8, idempotency_key: []u8, attachment_key: []u8, status: shared.OrderStatus, version: u64 };
const Outbox = struct { order_id: []u8, key: []u8, dispatched: bool = false };
pub const CrashPoint = enum { none, before_order_commit, after_order_commit, after_publish_before_mark };

pub const Model = struct {
    allocator: std.mem.Allocator,
    clock: *zstd.Clock.FakeClock,
    cache: zstd.Cache.Memory,
    broker: zstd.Broker.Memory,
    objects: zstd.ObjectStorage.Memory,
    orders: std.StringHashMap(StoredOrder),
    idempotency: std.StringHashMap([]const u8),
    outbox: std.ArrayList(Outbox) = .empty,

    pub fn init(allocator: std.mem.Allocator) !Model {
        const clock = try ModelClock.initAlloc(allocator); errdefer ModelClock.deinit(allocator, clock);
        return .{ .allocator = allocator, .clock = clock, .cache = zstd.Cache.Memory.init(allocator, clock.asService()), .broker = zstd.Broker.Memory.init(allocator, clock.asService()), .objects = zstd.ObjectStorage.Memory.init(allocator), .orders = .init(allocator), .idempotency = .init(allocator) };
    }
    pub fn deinit(self: *Model) void { var orders = self.orders.iterator(); while (orders.next()) |entry| { self.allocator.free(entry.key_ptr.*); self.freeOrder(entry.value_ptr.*); } self.orders.deinit(); var idem = self.idempotency.keyIterator(); while (idem.next()) |key| self.allocator.free(key.*); self.idempotency.deinit(); for (self.outbox.items) |entry| { self.allocator.free(entry.order_id); self.allocator.free(entry.key); } self.outbox.deinit(self.allocator); self.objects.deinit(); self.broker.deinit(); self.cache.deinit(); ModelClock.deinit(self.allocator, self.clock); }
    pub fn create(self: *Model, command: shared.CreateOrder, crash: CrashPoint) !shared.Order {
        try shared.validateCreate(command);
        if (self.idempotency.get(command.idempotency_key)) |existing_id| { if (!std.mem.eql(u8, existing_id, command.id)) return error.IdempotencyMismatch; return self.read(existing_id) orelse error.OrderNotFound; }
        if (crash == .before_order_commit) return error.InjectedCrash;
        _ = try self.objects.put(command.attachment_key, command.attachment, .{ .expected_sha256 = zstd.ObjectStorage.sha256(command.attachment) });
        var committed = false;
        errdefer { if (!committed) _ = self.objects.delete(command.attachment_key) catch false; }
        const map_key = try self.duplicate(command.id); errdefer if (!committed) self.allocator.free(map_key);
        const order = try self.cloneOrder(command); errdefer if (!committed) self.freeOrder(order);
        const idem_key = try self.duplicate(command.idempotency_key); errdefer if (!committed) self.allocator.free(idem_key);
        const outbox_id = try self.duplicate(command.id); errdefer if (!committed) self.allocator.free(outbox_id);
        const outbox_key = try self.duplicate(command.idempotency_key); errdefer if (!committed) self.allocator.free(outbox_key);
        try self.orders.ensureUnusedCapacity(1);
        try self.idempotency.ensureUnusedCapacity(1);
        try self.outbox.ensureUnusedCapacity(self.allocator, 1);
        self.orders.putAssumeCapacity(map_key, order);
        self.idempotency.putAssumeCapacity(idem_key, order.id);
        self.outbox.appendAssumeCapacity(.{ .order_id = outbox_id, .key = outbox_key });
        committed = true;
        if (crash == .after_order_commit) return error.InjectedCrash;
        try self.dispatchOutbox(crash);
        return self.read(command.id).?;
    }
    pub fn dispatchOutbox(self: *Model, crash: CrashPoint) !void { for (self.outbox.items) |*entry| { if (entry.dispatched) continue; _ = try self.broker.publish(.{ .subject = "orders", .payload = entry.order_id, .idempotency_key = entry.key }); if (crash == .after_publish_before_mark) return error.InjectedCrash; entry.dispatched = true; } }
    pub fn processOne(self: *Model) !bool { var delivery = (try self.broker.pollAlloc(self.allocator, "orders", "worker", 100)) orelse return false; defer delivery.deinit(); const order = self.orders.getPtr(delivery.payload) orelse return error.OrderNotFound; order.status = try shared.advance(order.status, .claim); order.version += 1; order.status = try shared.advance(order.status, .complete); order.version += 1; try self.broker.ack(delivery.id, "worker"); _ = try self.cache.set(order.id, "completed", .{ .ttl_ms = 60_000 }); return true; }
    pub fn read(self: *Model, id: []const u8) ?shared.Order { const order = self.orders.get(id) orelse return null; return .{ .id = order.id, .idempotency_key = order.idempotency_key, .attachment_key = order.attachment_key, .status = order.status, .version = order.version }; }
    fn cloneOrder(self: *Model, command: shared.CreateOrder) !StoredOrder { const id = try self.duplicate(command.id); errdefer self.allocator.free(id); const idem = try self.duplicate(command.idempotency_key); errdefer self.allocator.free(idem); const attachment = try self.duplicate(command.attachment_key); return .{ .id = id, .idempotency_key = idem, .attachment_key = attachment, .status = .pending, .version = 1 }; }
    fn duplicate(self: *Model, bytes: []const u8) ![]u8 { return self.allocator.dupe(u8, bytes); }
    fn freeOrder(self: *Model, order: StoredOrder) void { self.allocator.free(order.id); self.allocator.free(order.idempotency_key); self.allocator.free(order.attachment_key); }
};

test "reference model survives outbox crash windows duplicate commands and replay" { var model = try Model.init(std.testing.allocator); defer model.deinit(); const command = shared.CreateOrder{ .id = "order-1", .idempotency_key = "0123456789abcdef", .attachment_key = "orders/order-1.txt", .attachment = "receipt" }; try std.testing.expectError(error.InjectedCrash, model.create(command, .after_publish_before_mark)); try model.dispatchOutbox(.none); try std.testing.expect(try model.processOne()); const order = model.read("order-1").?; try std.testing.expectEqual(shared.OrderStatus.completed, order.status); try std.testing.expectEqual(@as(u64, 3), order.version); const duplicate = try model.create(command, .none); try std.testing.expectEqual(shared.OrderStatus.completed, duplicate.status); try std.testing.expectError(error.IdempotencyMismatch, model.create(.{ .id = "order-2", .idempotency_key = "0123456789abcdef", .attachment_key = "orders/order-2.txt", .attachment = "other" }, .none)); }

test "reference model creation is allocation-failure safe" {
    const Harness = struct { fn run(allocator: std.mem.Allocator) !void { var model = try Model.init(allocator); defer model.deinit(); _ = try model.create(.{ .id = "allocation-order", .idempotency_key = "allocation-0123456789abcdef", .attachment_key = "orders/allocation.txt", .attachment = "receipt" }, .none); } };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}
