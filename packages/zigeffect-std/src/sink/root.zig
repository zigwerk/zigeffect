const std = @import("std");
const Json = @import("../json/root.zig");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const SinkError = error{SinkClosed};

pub const LineSink = struct {
    allocator: std.mem.Allocator,
    lines: std.ArrayList([]const u8) = .empty,
    closed: bool = false,

    pub fn init(allocator: std.mem.Allocator) LineSink {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *LineSink) void {
        for (self.lines.items) |line| self.allocator.free(line);
        self.lines.deinit(self.allocator);
    }

    pub fn writeLine(self: *LineSink, line: []const u8) (SinkError || std.mem.Allocator.Error)!void {
        if (self.closed) return SinkError.SinkClosed;
        try self.lines.append(self.allocator, try self.allocator.dupe(u8, line));
    }

    pub fn close(self: *LineSink) void {
        self.closed = true;
    }

    pub fn len(self: *const LineSink) usize {
        return self.lines.items.len;
    }

    pub fn snapshotAlloc(self: *const LineSink, allocator: std.mem.Allocator) std.mem.Allocator.Error![]const []const u8 {
        var output = std.ArrayList([]const u8).empty;
        errdefer {
            for (output.items) |line| allocator.free(line);
            output.deinit(allocator);
        }

        for (self.lines.items) |line| {
            try output.append(allocator, try allocator.dupe(u8, line));
        }

        return output.toOwnedSlice(allocator);
    }

    pub fn receiptJsonlAlloc(self: *const LineSink, allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
        var output = std.ArrayList(u8).empty;
        errdefer output.deinit(allocator);

        for (self.lines.items, 0..) |line, index| {
            const index_text = try std.fmt.allocPrint(allocator, "{d}", .{index});
            defer allocator.free(index_text);

            const fields = [_]Json.Field{
                .{ .name = "index", .value = index_text },
                .{ .name = "line", .value = line },
            };
            const record = try Json.objectFromFieldsAlloc(allocator, fields[0..]);
            defer allocator.free(record);

            try output.appendSlice(allocator, record);
            try output.append(allocator, '\n');
        }

        return output.toOwnedSlice(allocator);
    }
};

pub fn freeLines(allocator: std.mem.Allocator, lines: []const []const u8) void {
    for (lines) |line| allocator.free(line);
    allocator.free(lines);
}

pub fn WriteLineEffect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = void;
        pub const FailureType = SinkError || std.mem.Allocator.Error;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{LineSink};

        line: []const u8,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!void {
            const sink = ctx.service(LineSink);
            sink.writeLine(self.line) catch |err| {
                _ = StdService.recordOperation(ctx, LineSink, "writeLine", "failure", self.line);
                return err;
            };
            _ = StdService.recordOperation(ctx, LineSink, "writeLine", "success", self.line);
        }
    };
}

pub fn writeLineEffect(comptime EffectEnv: type, line: []const u8) WriteLineEffect(EffectEnv) {
    return .{ .line = line };
}

test "Sink memory line sink writes snapshots and redacts JSONL receipts" {
    var sink = LineSink.init(std.testing.allocator);
    defer sink.deinit();

    try sink.writeLine("first");
    try sink.writeLine("token=abc123");

    const snapshot = try sink.snapshotAlloc(std.testing.allocator);
    defer freeLines(std.testing.allocator, snapshot);

    try std.testing.expectEqual(@as(usize, 2), snapshot.len);
    try std.testing.expectEqualStrings("first", snapshot[0]);
    try std.testing.expectEqualStrings("token=abc123", snapshot[1]);

    const receipt = try sink.receiptJsonlAlloc(std.testing.allocator);
    defer std.testing.allocator.free(receipt);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "[REDACTED]") != null);
}

test "Sink writeLineEffect records causal facts" {
    const zstd = @import("../root.zig");

    var sink = LineSink.init(std.testing.allocator);
    defer sink.deinit();
    var provider = zstd.Service.Provider(.{LineSink}).init(.{&sink});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{LineSink})
        .withCausalStore(&store);

    try runtime.run(writeLineEffect(@TypeOf(provider), "line one"));

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(zstd.Service.hasOperation(snapshot, LineSink, "writeLine", "success"));
}
