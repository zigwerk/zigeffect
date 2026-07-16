const std = @import("std");
const Capability = @import("../capability/root.zig");
const Clock = @import("../clock/root.zig");
const Stream = @import("../stream/root.zig");
const fx = @import("zigeffect");
const Boundary = @import("../boundary/root.zig");
const External = @import("../external/root.zig");

pub const deterministic_capability = Capability.Descriptor{ .id = "zigeffect-std.broker.memory", .kind = .broker, .maturity = .deterministic_model, .package = "zigeffect-std", .version = "0.1.0", .features = &.{ "publish", "poll", "ack", "nack", "redelivery", "idempotency" }, .side_effects = .modeled };
pub const Message = struct { subject: []const u8, payload: []const u8, idempotency_key: []const u8, headers: []const Header = &.{} };
pub const Header = struct { name: []const u8, value: []const u8 };
pub const Delivery = struct {
    allocator: std.mem.Allocator,
    id: []u8,
    subject: []u8,
    payload: []u8,
    idempotency_key: []u8,
    attempt: u32,
    pub fn deinit(self: *Delivery) void {
        self.allocator.free(self.id);
        self.allocator.free(self.subject);
        self.allocator.free(self.payload);
        self.allocator.free(self.idempotency_key);
        self.* = undefined;
    }
};
pub const Service = struct {
    pub const operations: []const []const u8 = &.{ "Broker.publish", "Broker.poll", "Broker.ack", "Broker.nack" };
    pointer: *anyopaque,
    publish_fn: *const fn (*anyopaque, Message) anyerror!u64,
    poll_fn: *const fn (*anyopaque, std.mem.Allocator, []const u8, []const u8, u64) anyerror!?Delivery,
    ack_fn: *const fn (*anyopaque, []const u8, []const u8) anyerror!void,
    nack_fn: *const fn (*anyopaque, []const u8, []const u8, u64) anyerror!void,
    observer: ?Boundary.Observer = null,
    pub fn from(comptime T: type, pointer: *T) Service {
        return .{ .pointer = pointer, .publish_fn = struct {
            fn call(raw: *anyopaque, message: Message) anyerror!u64 {
                return (@as(*T, @ptrCast(@alignCast(raw)))).publish(message);
            }
        }.call, .poll_fn = struct {
            fn call(raw: *anyopaque, allocator: std.mem.Allocator, subject: []const u8, consumer: []const u8, visibility: u64) anyerror!?Delivery {
                return (@as(*T, @ptrCast(@alignCast(raw)))).pollAlloc(allocator, subject, consumer, visibility);
            }
        }.call, .ack_fn = struct {
            fn call(raw: *anyopaque, id: []const u8, consumer: []const u8) anyerror!void {
                return (@as(*T, @ptrCast(@alignCast(raw)))).ack(id, consumer);
            }
        }.call, .nack_fn = struct {
            fn call(raw: *anyopaque, id: []const u8, consumer: []const u8, delay: u64) anyerror!void {
                return (@as(*T, @ptrCast(@alignCast(raw)))).nack(id, consumer, delay);
            }
        }.call };
    }
    pub fn observed(self: Service, observer: Boundary.Observer) Service {
        var result = self;
        result.observer = observer;
        return result;
    }
    pub fn publish(self: Service, message: Message) !u64 {
        self.emit("publish", .started, message.idempotency_key, null);
        const result = self.publish_fn(self.pointer, message) catch |err| {
            self.emit("publish", .failed, message.idempotency_key, External.classifyError(err));
            return err;
        };
        self.emit("publish", .succeeded, message.idempotency_key, null);
        return result;
    }
    pub fn pollAlloc(self: Service, allocator: std.mem.Allocator, subject: []const u8, consumer: []const u8, visibility: u64) !?Delivery {
        self.emit("poll", .started, subject, null);
        const result = self.poll_fn(self.pointer, allocator, subject, consumer, visibility) catch |err| {
            self.emit("poll", .failed, subject, External.classifyError(err));
            return err;
        };
        self.emit("poll", .succeeded, subject, null);
        return result;
    }
    pub fn ack(self: Service, id: []const u8, consumer: []const u8) !void {
        self.ack_fn(self.pointer, id, consumer) catch |err| {
            self.emit("ack", .failed, id, External.classifyError(err));
            return err;
        };
        self.emit("ack", .succeeded, id, null);
    }
    pub fn nack(self: Service, id: []const u8, consumer: []const u8, delay: u64) !void {
        self.nack_fn(self.pointer, id, consumer, delay) catch |err| {
            self.emit("nack", .failed, id, External.classifyError(err));
            return err;
        };
        self.emit("nack", .succeeded, id, null);
    }
    fn emit(self: Service, operation: []const u8, status: Boundary.Status, key: []const u8, class: ?External.Class) void {
        if (self.observer) |observer| observer.emit(.broker, operation, status, key, class);
    }
};

pub const BrokerService = fx.kernel.Service("zigeffect/std/Broker", Service);

pub fn serviceLayer(service: Service) @TypeOf(fx.kernel.Layer.succeed(BrokerService, service)) {
    return fx.kernel.Layer.succeed(BrokerService, service);
}

pub fn memoryLayer(memory: *Memory) @TypeOf(serviceLayer(memory.asService())) {
    return serviceLayer(memory.asService());
}

const Publish = fx.kernel.Effect(u64, anyerror, .{BrokerService}).Stateful(Message);
pub fn publish(message: Message) Publish {
    return Publish.init(message, struct {
        fn run(value: Message, ctx: *Publish.Context) anyerror!u64 {
            return ctx.service(BrokerService).publish(value);
        }
    }.run);
}

const PollRequest = struct { subject: []const u8, consumer: []const u8, visibility_ms: u64 };
const Poll = fx.kernel.Effect(?Delivery, anyerror, .{BrokerService}).Stateful(PollRequest);
pub fn poll(subject: []const u8, consumer: []const u8, visibility_ms: u64) Poll {
    return Poll.init(.{ .subject = subject, .consumer = consumer, .visibility_ms = visibility_ms }, struct {
        fn run(request: PollRequest, ctx: *Poll.Context) anyerror!?Delivery {
            return ctx.service(BrokerService).pollAlloc(ctx.allocator(), request.subject, request.consumer, request.visibility_ms);
        }
    }.run);
}

const DeliveryRequest = struct { id: []const u8, consumer: []const u8, delay_ms: u64 = 0 };
const Ack = fx.kernel.Effect(void, anyerror, .{BrokerService}).Stateful(DeliveryRequest);
pub fn ack(id: []const u8, consumer: []const u8) Ack {
    return Ack.init(.{ .id = id, .consumer = consumer }, struct {
        fn run(request: DeliveryRequest, ctx: *Ack.Context) anyerror!void {
            return ctx.service(BrokerService).ack(request.id, request.consumer);
        }
    }.run);
}

const Nack = fx.kernel.Effect(void, anyerror, .{BrokerService}).Stateful(DeliveryRequest);
pub fn nack(id: []const u8, consumer: []const u8, delay_ms: u64) Nack {
    return Nack.init(.{ .id = id, .consumer = consumer, .delay_ms = delay_ms }, struct {
        fn run(request: DeliveryRequest, ctx: *Nack.Context) anyerror!void {
            return ctx.service(BrokerService).nack(request.id, request.consumer, request.delay_ms);
        }
    }.run);
}

pub fn deliveryStreamAlloc(allocator: std.mem.Allocator, service: Service, subject: []const u8, consumer: []const u8, visibility_ms: u64) !fx.EffectStream(Delivery, anyerror, Stream.EmptyEnv) {
    const Puller = struct {
        allocator: std.mem.Allocator,
        service: Service,
        subject: []u8,
        consumer: []u8,
        visibility_ms: u64,
        closed: bool = false,
        pub fn pull(self: *@This(), _: *fx.Context(Stream.EmptyEnv), output_allocator: std.mem.Allocator, max: usize) anyerror!fx.EffectStream(Delivery, anyerror, Stream.EmptyEnv).Chunk {
            var output = std.ArrayList(Delivery).empty;
            errdefer {
                for (output.items) |*delivery| delivery.deinit();
                output.deinit(output_allocator);
            }
            while (output.items.len < max) {
                const delivery = try self.service.poll_fn(self.service.pointer, output_allocator, self.subject, self.consumer, self.visibility_ms) orelse break;
                try output.append(output_allocator, delivery);
            }
            return .{ .allocator = output_allocator, .items = try output.toOwnedSlice(output_allocator), .end = false };
        }
        pub fn close(self: *@This(), _: fx.StreamCloseReason) void {
            self.closed = true;
        }
        pub fn deinit(self: *@This()) void {
            self.allocator.free(self.subject);
            self.allocator.free(self.consumer);
        }
    };
    const owned_subject = try allocator.dupe(u8, subject);
    errdefer allocator.free(owned_subject);
    const owned_consumer = try allocator.dupe(u8, consumer);
    errdefer allocator.free(owned_consumer);
    return fx.effectStreamFromOwnedPullerAlloc(Delivery, anyerror, Stream.EmptyEnv, Puller, allocator, .{ .allocator = allocator, .service = service, .subject = owned_subject, .consumer = owned_consumer, .visibility_ms = visibility_ms });
}
const Stored = struct { id: u64, subject: []u8, payload: []u8, key: []u8, state: enum { available, claimed, acked } = .available, consumer: ?[]u8 = null, visible_at_ms: u64, attempt: u32 = 0 };
pub const Memory = struct {
    allocator: std.mem.Allocator,
    clock: Clock.Service,
    messages: std.ArrayList(Stored) = .empty,
    idempotency: std.StringHashMap(u64),
    next_id: u64 = 1,
    mutex: std.atomic.Mutex = .unlocked,
    pub fn init(allocator: std.mem.Allocator, clock: Clock.Service) Memory {
        return .{ .allocator = allocator, .clock = clock, .idempotency = .init(allocator) };
    }
    pub fn deinit(self: *Memory) void {
        for (self.messages.items) |item| {
            self.allocator.free(item.subject);
            self.allocator.free(item.payload);
            self.allocator.free(item.key);
            if (item.consumer) |consumer| self.allocator.free(consumer);
        }
        self.messages.deinit(self.allocator);
        var keys = self.idempotency.keyIterator();
        while (keys.next()) |key| self.allocator.free(key.*);
        self.idempotency.deinit();
    }
    pub fn asService(self: *Memory) Service {
        return Service.from(Memory, self);
    }
    pub fn publish(self: *Memory, message: Message) !u64 {
        try validateMessage(message);
        self.lock();
        defer self.mutex.unlock();
        if (self.idempotency.get(message.idempotency_key)) |existing| return existing;
        const id = self.next_id;
        self.next_id += 1;
        const subject = try self.allocator.dupe(u8, message.subject);
        errdefer self.allocator.free(subject);
        const payload = try self.allocator.dupe(u8, message.payload);
        errdefer self.allocator.free(payload);
        const key = try self.allocator.dupe(u8, message.idempotency_key);
        errdefer self.allocator.free(key);
        const index_key = try self.allocator.dupe(u8, message.idempotency_key);
        errdefer self.allocator.free(index_key);
        try self.messages.append(self.allocator, .{ .id = id, .subject = subject, .payload = payload, .key = key, .visible_at_ms = self.now() });
        errdefer _ = self.messages.pop();
        try self.idempotency.put(index_key, id);
        return id;
    }
    pub fn pollAlloc(self: *Memory, allocator: std.mem.Allocator, subject: []const u8, consumer: []const u8, visibility_ms: u64) !?Delivery {
        if (subject.len == 0 or consumer.len == 0 or visibility_ms == 0) return error.InvalidConsumeRequest;
        self.lock();
        defer self.mutex.unlock();
        const current_ms = self.now();
        for (self.messages.items) |*item| {
            if (item.state == .acked or !std.mem.eql(u8, item.subject, subject)) continue;
            if (item.state == .claimed and item.visible_at_ms > current_ms) continue;
            if (item.consumer) |old| self.allocator.free(old);
            item.consumer = try self.allocator.dupe(u8, consumer);
            item.state = .claimed;
            item.visible_at_ms = current_ms +| visibility_ms;
            item.attempt += 1;
            const id = try std.fmt.allocPrint(allocator, "{d}", .{item.id});
            errdefer allocator.free(id);
            const owned_subject = try allocator.dupe(u8, item.subject);
            errdefer allocator.free(owned_subject);
            const payload = try allocator.dupe(u8, item.payload);
            errdefer allocator.free(payload);
            const key = try allocator.dupe(u8, item.key);
            return .{ .allocator = allocator, .id = id, .subject = owned_subject, .payload = payload, .idempotency_key = key, .attempt = item.attempt };
        }
        return null;
    }
    pub fn ack(self: *Memory, opaque_id: []const u8, consumer: []const u8) !void {
        const id = std.fmt.parseUnsigned(u64, opaque_id, 10) catch return error.DeliveryNotFound;
        self.lock();
        defer self.mutex.unlock();
        const item = self.find(id) orelse return error.DeliveryNotFound;
        if (item.state != .claimed or item.consumer == null or !std.mem.eql(u8, item.consumer.?, consumer)) return error.DeliveryOwnershipLost;
        item.state = .acked;
    }
    pub fn nack(self: *Memory, opaque_id: []const u8, consumer: []const u8, delay_ms: u64) !void {
        const id = std.fmt.parseUnsigned(u64, opaque_id, 10) catch return error.DeliveryNotFound;
        self.lock();
        defer self.mutex.unlock();
        const item = self.find(id) orelse return error.DeliveryNotFound;
        if (item.state != .claimed or item.consumer == null or !std.mem.eql(u8, item.consumer.?, consumer)) return error.DeliveryOwnershipLost;
        item.state = .available;
        item.visible_at_ms = self.now() +| delay_ms;
    }
    fn find(self: *Memory, id: u64) ?*Stored {
        for (self.messages.items) |*item| if (item.id == id) return item;
        return null;
    }
    fn now(self: *Memory) u64 {
        return self.clock.snapshot().wall_millis;
    }
    fn lock(self: *Memory) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
    }
};
fn validateMessage(message: Message) !void {
    if (message.subject.len == 0 or message.subject.len > 512 or message.idempotency_key.len == 0 or message.idempotency_key.len > 1024) return error.InvalidMessage;
    if (message.payload.len > 16 * 1024 * 1024 or message.headers.len > 128) return error.MessageTooLarge;
}
pub fn conform(service: Service, allocator: std.mem.Allocator) !void {
    const id = try service.publish(.{ .subject = "orders", .payload = "created", .idempotency_key = "order-1" });
    try std.testing.expectEqual(id, try service.publish(.{ .subject = "orders", .payload = "created", .idempotency_key = "order-1" }));
    var first = (try service.pollAlloc(allocator, "orders", "worker-a", 10)).?;
    defer first.deinit();
    try std.testing.expectEqual(@as(u32, 1), first.attempt);
    try service.nack(first.id, "worker-a", 0);
    var second = (try service.pollAlloc(allocator, "orders", "worker-b", 10)).?;
    defer second.deinit();
    try std.testing.expectEqual(@as(u32, 2), second.attempt);
    try service.ack(second.id, "worker-b");
    try std.testing.expect((try service.pollAlloc(allocator, "orders", "worker-b", 10)) == null);
}
test "deterministic broker satisfies dedupe ack nack redelivery and causal conformance" {
    var clock = Clock.FakeClock.init(0);
    var broker = Memory.init(std.testing.allocator, clock.asService());
    defer broker.deinit();
    var evidence = Boundary.Recorder.init(std.testing.allocator);
    defer evidence.deinit();
    try conform(broker.asService().observed(evidence.asObserver()), std.testing.allocator);
    try std.testing.expect(evidence.facts.items.len >= 8);
}
