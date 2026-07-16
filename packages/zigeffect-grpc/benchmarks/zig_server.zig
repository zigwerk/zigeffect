const std = @import("std");
const zgrpc = @import("zigeffect_grpc");
const zstd = @import("zigeffect_std");

const proto = zgrpc.ConformanceProto;
const Service = proto.ConformanceService(void, anyerror);

const CountingAllocator = struct {
    backing: std.mem.Allocator,
    allocations: std.atomic.Value(usize) = .init(0),
    frees: std.atomic.Value(usize) = .init(0),
    allocated_bytes: std.atomic.Value(usize) = .init(0),
    live_bytes: std.atomic.Value(usize) = .init(0),
    peak_live_bytes: std.atomic.Value(usize) = .init(0),

    fn allocator(self: *@This()) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn observePeak(self: *@This(), value: usize) void {
        var peak = self.peak_live_bytes.load(.monotonic);
        while (value > peak) {
            peak = self.peak_live_bytes.cmpxchgWeak(peak, value, .monotonic, .monotonic) orelse return;
        }
    }

    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, return_address: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(raw));
        const memory = self.backing.rawAlloc(len, alignment, return_address) orelse return null;
        _ = self.allocations.fetchAdd(1, .monotonic);
        _ = self.allocated_bytes.fetchAdd(len, .monotonic);
        self.observePeak(self.live_bytes.fetchAdd(len, .monotonic) + len);
        return memory;
    }

    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) bool {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (!self.backing.rawResize(memory, alignment, new_len, return_address)) return false;
        if (new_len > memory.len) {
            const growth = new_len - memory.len;
            _ = self.allocated_bytes.fetchAdd(growth, .monotonic);
            self.observePeak(self.live_bytes.fetchAdd(growth, .monotonic) + growth);
        } else {
            _ = self.live_bytes.fetchSub(memory.len - new_len, .monotonic);
        }
        return true;
    }

    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(raw));
        const result = self.backing.rawRemap(memory, alignment, new_len, return_address) orelse return null;
        if (new_len > memory.len) {
            const growth = new_len - memory.len;
            _ = self.allocated_bytes.fetchAdd(growth, .monotonic);
            self.observePeak(self.live_bytes.fetchAdd(growth, .monotonic) + growth);
        } else {
            _ = self.live_bytes.fetchSub(memory.len - new_len, .monotonic);
        }
        return result;
    }

    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, return_address: usize) void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.backing.rawFree(memory, alignment, return_address);
        _ = self.frees.fetchAdd(1, .monotonic);
        _ = self.live_bytes.fetchSub(memory.len, .monotonic);
    }

    const vtable = std.mem.Allocator.VTable{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };
};

const ConformanceService = struct {
    pub fn Unary(_: *@This(), request: proto.UnaryRequest) !proto.UnaryResponse {
        return .{ .id = request.id, .accepted_sequence = request.sequence };
    }

    pub fn ClientStream(_: *@This(), stream: *zgrpc.Typed.Stream(proto.ClientStreamRequest, proto.ClientStreamResponse)) !zgrpc.Grpc.Status {
        var count: i64 = 0;
        while (try stream.receive()) |owned_value| {
            var owned = owned_value;
            defer owned.deinit();
            count += 1;
        }
        try stream.send(.{ .accepted_count = count });
        return .ok();
    }

    pub fn ServerStream(_: *@This(), stream: *zgrpc.Typed.Stream(proto.ServerStreamRequest, proto.ServerStreamResponse)) !zgrpc.Grpc.Status {
        var request = (try stream.receive()) orelse return .{ .code = .invalid_argument, .message = "request required" };
        defer request.deinit();
        var sequence: i64 = 0;
        while (sequence < request.value.count) : (sequence += 1) try stream.send(.{ .sequence = sequence });
        return .ok();
    }

    pub fn BidiStream(_: *@This(), stream: *zgrpc.Typed.Stream(proto.BidiStreamRequest, proto.BidiStreamResponse)) !zgrpc.Grpc.Status {
        while (try stream.receive()) |owned_value| {
            var owned = owned_value;
            defer owned.deinit();
            try stream.send(.{ .sequence = owned.value.sequence });
        }
        return .ok();
    }
};

fn appendVarint(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value_arg: usize) !void {
    var value = value_arg;
    while (value >= 0x80) {
        try output.append(allocator, @as(u8, @truncate(value)) | 0x80);
        value >>= 7;
    }
    try output.append(allocator, @intCast(value));
}

fn appendVarintField(output: *std.ArrayList(u8), allocator: std.mem.Allocator, field: u8, value: usize) !void {
    try output.append(allocator, field << 3);
    try appendVarint(output, allocator, value);
}

const StatsHandler = struct {
    counter: *CountingAllocator,

    pub fn invoke(self: *@This(), allocator: std.mem.Allocator, _: zgrpc.Grpc.UnaryRequest) !zgrpc.Grpc.UnaryResponse {
        const allocations = self.counter.allocations.load(.monotonic);
        const frees = self.counter.frees.load(.monotonic);
        const allocated_bytes = self.counter.allocated_bytes.load(.monotonic);
        const live_bytes = self.counter.live_bytes.load(.monotonic);
        const peak_live_bytes = self.counter.peak_live_bytes.load(.monotonic);
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(allocator);
        try appendVarintField(&output, allocator, 1, allocations);
        try appendVarintField(&output, allocator, 2, frees);
        try appendVarintField(&output, allocator, 3, allocated_bytes);
        try appendVarintField(&output, allocator, 4, live_bytes);
        try appendVarintField(&output, allocator, 5, peak_live_bytes);
        return zgrpc.Grpc.UnaryResponse.initAlloc(allocator, output.items, .ok());
    }
};

const ServeContext = struct {
    server: *zgrpc.NativeServer,
    result: ?anyerror = null,

    fn run(self: *@This()) void {
        _ = self.server.serve() catch |err| {
            if (self.server.ready()) self.result = err;
            return;
        };
    }
};

pub fn main(init: std.process.Init) !void {
    const port = try std.fmt.parseInt(u16, init.environ_map.get("PORT") orelse "8080", 10);
    const handler_workers = try std.fmt.parseInt(usize, init.environ_map.get("HANDLER_WORKERS") orelse "8", 10);
    var counter = CountingAllocator{ .backing = std.heap.smp_allocator };
    const allocator = counter.allocator();
    var service = ConformanceService{};
    var unary = zgrpc.Grpc.Registry.init(allocator);
    defer unary.deinit();
    var incremental = zgrpc.Incremental.Registry.init(allocator);
    defer incremental.deinit();
    var generated = zgrpc.Typed.GeneratedDriverBinding(Service, ConformanceService).init(allocator, &service);
    try generated.registerAll(&unary, &incremental);
    var stats = StatsHandler{ .counter = &counter };
    try unary.register(.{
        .service = "zigeffect.benchmark.v1.Stats",
        .method = "Snapshot",
        .handler = zgrpc.Grpc.UnaryHandler.from(StatsHandler, &stats),
    });

    var server = try zgrpc.NativeServer.init(allocator, init.io, .{
        .host = "0.0.0.0",
        .port = port,
        .max_connections = 80,
        .max_calls_per_connection = 1_000_000,
        .handler_worker_count = handler_workers,
        .handler_queue_capacity = @max(1024, handler_workers),
        .connection_idle_timeout_millis = null,
        .connection_max_age_millis = null,
    }, &unary);
    defer server.deinit();
    try server.installIncremental(&incremental);
    var signals = try zstd.Application.Lifecycle.SignalRegistration.install();
    defer signals.deinit();
    var serving = ServeContext{ .server = &server };
    const thread = try std.Thread.spawn(.{}, ServeContext.run, .{&serving});
    while (zstd.Application.Lifecycle.requestedSignal() == .none and serving.result == null) {
        init.io.sleep(.fromMilliseconds(25), .awake) catch break;
    }
    _ = try server.shutdown(.{ .deadline_ms = 25_000 });
    thread.join();
    if (serving.result) |err| return err;
}
