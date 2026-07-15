const std = @import("std");
const zstd = @import("zigeffect_std");

pub const Grpc = zstd.Grpc;

pub const OwnedMessage = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,

    pub fn initAlloc(allocator: std.mem.Allocator, bytes: []const u8) !OwnedMessage {
        return .{ .allocator = allocator, .bytes = try allocator.dupe(u8, bytes) };
    }

    pub fn deinit(self: *OwnedMessage) void {
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

/// A fixed-capacity message channel. `send` blocks when the channel is full,
/// so a slow consumer propagates backpressure to the producer without growing
/// an unbounded buffer.
pub const Pipe = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    storage: []OwnedMessage,
    queue: std.Io.Queue(OwnedMessage),
    closed: std.atomic.Value(bool) = .init(false),

    pub fn init(allocator: std.mem.Allocator, io: std.Io, capacity: usize) !Pipe {
        if (capacity == 0) return error.InvalidLimits;
        const storage = try allocator.alloc(OwnedMessage, capacity);
        return .{
            .allocator = allocator,
            .io = io,
            .storage = storage,
            .queue = std.Io.Queue(OwnedMessage).init(storage),
        };
    }

    pub fn deinit(self: *Pipe) void {
        self.close();
        var items: [16]OwnedMessage = undefined;
        while (true) {
            const count = self.queue.getUncancelable(self.io, &items, 0) catch break;
            if (count == 0) break;
            for (items[0..count]) |*item| item.deinit();
        }
        self.allocator.free(self.storage);
        self.* = undefined;
    }

    pub fn sendAlloc(self: *Pipe, allocator: std.mem.Allocator, bytes: []const u8) !void {
        var message = try OwnedMessage.initAlloc(allocator, bytes);
        errdefer message.deinit();
        try self.queue.putOne(self.io, message);
    }

    pub fn send(self: *Pipe, message: OwnedMessage) !void {
        try self.queue.putOne(self.io, message);
    }

    pub fn trySend(self: *Pipe, message: OwnedMessage) !bool {
        return try self.queue.put(self.io, &.{message}, 0) == 1;
    }

    pub fn receive(self: *Pipe) !?OwnedMessage {
        return self.queue.getOne(self.io) catch |err| switch (err) {
            error.Closed => null,
            else => return err,
        };
    }

    pub fn tryReceive(self: *Pipe) !?OwnedMessage {
        var item: [1]OwnedMessage = undefined;
        const count = self.queue.get(self.io, &item, 0) catch |err| switch (err) {
            error.Closed => return null,
            else => return err,
        };
        return if (count == 0) null else item[0];
    }

    pub fn close(self: *Pipe) void {
        if (!self.closed.swap(true, .acq_rel)) self.queue.close(self.io);
    }

    pub fn isClosed(self: *const Pipe) bool {
        return self.closed.load(.acquire);
    }
};

pub const Call = struct {
    context: Context,
    inbound: *Pipe,
    outbound: *Pipe,
    notify_pointer: *anyopaque,
    notify_fn: *const fn (*anyopaque) void,
    metadata_pointer: ?*anyopaque = null,
    set_initial_metadata_fn: ?*const fn (*anyopaque, []const Grpc.Metadata) anyerror!void = null,
    set_trailing_metadata_fn: ?*const fn (*anyopaque, []const Grpc.Metadata) anyerror!void = null,
    set_final_status_fn: ?*const fn (*anyopaque, Grpc.Status) anyerror!void = null,

    pub fn receive(self: *Call) !?OwnedMessage {
        const message = try self.inbound.receive();
        if (message != null) self.notify_fn(self.notify_pointer);
        return message;
    }

    pub fn sendAlloc(self: *Call, allocator: std.mem.Allocator, bytes: []const u8) !void {
        try self.outbound.sendAlloc(allocator, bytes);
        self.notify_fn(self.notify_pointer);
    }

    /// Commits initial response metadata. It must be called at most once and
    /// before the first response message is observed by the transport.
    pub fn sendHeaders(self: *Call, metadata: []const Grpc.Metadata) !void {
        const setter = self.set_initial_metadata_fn orelse return error.ResponseMetadataUnsupported;
        try setter(self.metadata_pointer.?, metadata);
        self.notify_fn(self.notify_pointer);
    }

    /// Sets final response metadata for gRPC trailers or the Connect
    /// EndStreamResponse. It may be called at most once before completion.
    pub fn setTrailers(self: *Call, metadata: []const Grpc.Metadata) !void {
        const setter = self.set_trailing_metadata_fn orelse return error.ResponseMetadataUnsupported;
        try setter(self.metadata_pointer.?, metadata);
    }

    /// Copies a dynamically constructed final status into call-owned storage.
    /// Use this before returning when the message or details borrow decoded
    /// request memory that will be released by handler cleanup.
    pub fn setFinalStatus(self: *Call, status: Grpc.Status) !void {
        const setter = self.set_final_status_fn orelse return error.ResponseStatusUnsupported;
        try setter(self.metadata_pointer.?, status);
    }

    pub fn isCancelled(self: *const Call) bool {
        // A closed inbound pipe is the normal HTTP/2 half-close after the
        // client finishes its request. Cancellation closes the response side.
        return self.outbound.isClosed();
    }

    pub fn sleep(self: *const Call, milliseconds: u64) !void {
        var elapsed: u64 = 0;
        while (elapsed < milliseconds) {
            if (self.isCancelled()) return error.CallCancelled;
            const step = @min(milliseconds - elapsed, 10);
            try (std.Io.Clock.Duration{
                .raw = .fromMilliseconds(@intCast(step)),
                .clock = .awake,
            }).sleep(self.inbound.io);
            elapsed += step;
        }
        if (self.isCancelled()) return error.CallCancelled;
    }
};

pub const Context = struct {
    authority: []const u8,
    scheme: []const u8 = "https",
    service: []const u8,
    method: []const u8,
    shape: Grpc.CallShape,
    timeout_millis: u64,
    metadata: []const Grpc.Metadata = &.{},
};

pub const Handler = struct {
    pointer: *anyopaque,
    run_fn: *const fn (*anyopaque, *Call) anyerror!Grpc.Status,

    pub fn from(comptime Target: type, target: *Target) Handler {
        return .{
            .pointer = target,
            .run_fn = struct {
                fn run(pointer: *anyopaque, call: *Call) anyerror!Grpc.Status {
                    return (@as(*Target, @ptrCast(@alignCast(pointer)))).runIncremental(call);
                }
            }.run,
        };
    }
};

pub const Registry = struct {
    const Entry = struct {
        service: []u8,
        method: []u8,
        shape: Grpc.CallShape,
        handler: Handler,
    };

    allocator: std.mem.Allocator,
    entries: std.ArrayList(Entry) = .empty,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Registry) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry.service);
            self.allocator.free(entry.method);
        }
        self.entries.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn register(self: *Registry, service: []const u8, method: []const u8, shape: Grpc.CallShape, handler: Handler) !void {
        if (shape == .unary) return error.InvalidCallShape;
        try (Grpc.Method{ .service = service, .method = method, .shape = shape }).validate();
        if (self.find(service, method) != null) return error.DuplicateMethod;
        const owned_service = try self.allocator.dupe(u8, service);
        errdefer self.allocator.free(owned_service);
        const owned_method = try self.allocator.dupe(u8, method);
        errdefer self.allocator.free(owned_method);
        try self.entries.append(self.allocator, .{
            .service = owned_service,
            .method = owned_method,
            .shape = shape,
            .handler = handler,
        });
    }

    pub fn find(self: *const Registry, service: []const u8, method: []const u8) ?struct { shape: Grpc.CallShape, handler: Handler } {
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.service, service) and std.mem.eql(u8, entry.method, method)) {
                return .{ .shape = entry.shape, .handler = entry.handler };
            }
        }
        return null;
    }
};

test "bounded incremental pipe refuses an immediate write when full" {
    var pipe = try Pipe.init(std.testing.allocator, std.testing.io, 1);
    defer pipe.deinit();
    try pipe.sendAlloc(std.testing.allocator, "one");
    var second = try OwnedMessage.initAlloc(std.testing.allocator, "two");
    if (!try pipe.trySend(second)) second.deinit();
    var first = (try pipe.receive()).?;
    defer first.deinit();
    try std.testing.expectEqualStrings("one", first.bytes);
    try std.testing.expect(try pipe.tryReceive() == null);
}
