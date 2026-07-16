const std = @import("std");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");
const Stream = @import("../stream/root.zig");

pub const ParsedLines = struct {
    lines: []const []const u8,
    trailing: []const u8,

    pub fn deinit(self: *ParsedLines, allocator: std.mem.Allocator) void {
        for (self.lines) |line| allocator.free(line);
        allocator.free(self.lines);
        allocator.free(self.trailing);
    }
};

pub fn lineStreamAlloc(allocator: std.mem.Allocator, input: []const u8) !fx.EffectStream([]const u8, anyerror, Stream.EmptyEnv) {
    const Puller = struct {
        allocator: std.mem.Allocator,
        parsed: ParsedLines,
        offset: usize = 0,
        pub fn pull(self: *@This(), _: *fx.Context(Stream.EmptyEnv), output_allocator: std.mem.Allocator, max: usize) anyerror!fx.EffectStream([]const u8, anyerror, Stream.EmptyEnv).Chunk {
            const count = @min(max, self.parsed.lines.len - self.offset);
            const output = try output_allocator.alloc([]const u8, count);
            @memcpy(output, self.parsed.lines[self.offset .. self.offset + count]);
            self.offset += count;
            return .{ .allocator = output_allocator, .items = output, .end = self.offset == self.parsed.lines.len };
        }
        pub fn close(_: *@This(), _: fx.StreamCloseReason) void {}
        pub fn deinit(self: *@This()) void {
            self.parsed.deinit(self.allocator);
        }
    };
    return fx.effectStreamFromOwnedPullerAlloc([]const u8, anyerror, Stream.EmptyEnv, Puller, allocator, .{ .allocator = allocator, .parsed = try parseLinesAlloc(allocator, input) });
}

pub fn appendRecordAlloc(
    allocator: std.mem.Allocator,
    existing: []const u8,
    record_json: []const u8,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, existing);
    try output.appendSlice(allocator, record_json);
    try output.append(allocator, '\n');

    return output.toOwnedSlice(allocator);
}

pub const Codec = struct {
    pub const operations: []const []const u8 = &.{"Jsonl.append"};

    pub fn appendAlloc(
        _: Codec,
        allocator: std.mem.Allocator,
        existing: []const u8,
        record_json: []const u8,
    ) std.mem.Allocator.Error![]const u8 {
        return appendRecordAlloc(allocator, existing, record_json);
    }
};

pub const JsonlCodec = fx.kernel.Service("zigeffect/std/JsonlCodec", Codec);

pub fn codecLayer() @TypeOf(fx.kernel.Layer.succeed(JsonlCodec, Codec{})) {
    return fx.kernel.Layer.succeed(JsonlCodec, .{});
}

const AppendInput = struct { existing: []const u8, record_json: []const u8 };

pub fn append(existing: []const u8, record_json: []const u8) fx.kernel.Effect(
    []const u8,
    std.mem.Allocator.Error,
    .{JsonlCodec},
).Stateful(AppendInput) {
    const Append = fx.kernel.Effect([]const u8, std.mem.Allocator.Error, .{JsonlCodec});
    return Append.fromState(AppendInput, .{ .existing = existing, .record_json = record_json }, struct {
        fn run(input: AppendInput, ctx: *Append.Context) std.mem.Allocator.Error![]const u8 {
            const operation = StdService.beginOperation(ctx, JsonlCodec.service_key, "Jsonl.append", "bounded record");
            const output = ctx.service(JsonlCodec).appendAlloc(ctx.allocator(), input.existing, input.record_json) catch |failure| {
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.completeOperation(ctx, operation, "success", "jsonl record");
            return output;
        }
    }.run);
}

pub fn parseLinesAlloc(allocator: std.mem.Allocator, input: []const u8) !ParsedLines {
    var lines = std.ArrayList([]const u8).empty;
    errdefer {
        for (lines.items) |line| allocator.free(line);
        lines.deinit(allocator);
    }

    var start: usize = 0;
    while (std.mem.indexOfScalarPos(u8, input, start, '\n')) |newline| {
        try lines.append(allocator, try allocator.dupe(u8, input[start..newline]));
        start = newline + 1;
    }

    return .{
        .lines = try lines.toOwnedSlice(allocator),
        .trailing = try allocator.dupe(u8, input[start..]),
    };
}

test "Jsonl appends records and parses complete lines" {
    const feed = try appendRecordAlloc(std.testing.allocator, "", "{\"a\":\"1\"}");
    defer std.testing.allocator.free(feed);

    var parsed = try parseLinesAlloc(std.testing.allocator, feed);
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), parsed.lines.len);
    try std.testing.expectEqualStrings("{\"a\":\"1\"}", parsed.lines[0]);
    try std.testing.expectEqualStrings("", parsed.trailing);
}

test "Jsonl retains trailing partial line" {
    var parsed = try parseLinesAlloc(std.testing.allocator, "{\"a\":\"1\"}\n{\"b\"");
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), parsed.lines.len);
    try std.testing.expectEqualStrings("{\"a\":\"1\"}", parsed.lines[0]);
    try std.testing.expectEqualStrings("{\"b\"", parsed.trailing);
}

test "Jsonl.append uses a canonical codec layer and records causal fact" {
    const root = codecLayer();
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{ .causal_store = &store });
    defer runtime.deinit();

    const output = try runtime.run(append("", "{\"status\":\"ok\"}"));
    defer std.testing.allocator.free(output);

    try std.testing.expectEqualStrings("{\"status\":\"ok\"}\n", output);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    var saw = false;
    for (snapshot.events) |event| {
        if (event.kind == .io_completed and std.mem.eql(u8, event.service_key, JsonlCodec.service_key)) saw = true;
    }
    try std.testing.expect(saw);
}
