const std = @import("std");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const ParsedLines = struct {
    lines: []const []const u8,
    trailing: []const u8,

    pub fn deinit(self: *ParsedLines, allocator: std.mem.Allocator) void {
        for (self.lines) |line| allocator.free(line);
        allocator.free(self.lines);
        allocator.free(self.trailing);
    }
};

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
    pub fn appendAlloc(
        _: Codec,
        allocator: std.mem.Allocator,
        existing: []const u8,
        record_json: []const u8,
    ) std.mem.Allocator.Error![]const u8 {
        return appendRecordAlloc(allocator, existing, record_json);
    }
};

pub fn AppendEffect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = []const u8;
        pub const FailureType = std.mem.Allocator.Error;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Codec};

        existing: []const u8,
        record_json: []const u8,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType![]const u8 {
            const codec = ctx.service(Codec);
            const output = codec.appendAlloc(ctx.allocator, self.existing, self.record_json) catch |err| {
                _ = StdService.recordOperation(ctx, Codec, "append", "failure", "jsonl record");
                return err;
            };
            _ = StdService.recordOperation(ctx, Codec, "append", "success", "jsonl record");
            return output;
        }
    };
}

pub fn appendEffect(
    comptime EffectEnv: type,
    existing: []const u8,
    record_json: []const u8,
) AppendEffect(EffectEnv) {
    return .{ .existing = existing, .record_json = record_json };
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

test "Jsonl appendEffect uses Codec service and records causal fact" {
    const zstd = @import("../root.zig");

    var codec = Codec{};
    var provider = zstd.Service.Provider(.{Codec}).init(.{&codec});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{Codec})
        .withCausalStore(&store);

    const output = try runtime.run(appendEffect(@TypeOf(provider), "", "{\"status\":\"ok\"}"));
    defer std.testing.allocator.free(output);

    try std.testing.expectEqualStrings("{\"status\":\"ok\"}\n", output);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expectEqual(zstd.fx.CausalEventKind.span_recorded, snapshot.events[0].kind);
    try std.testing.expectEqualStrings(@typeName(Codec), snapshot.events[0].service_key);
    try std.testing.expectEqualStrings("append", snapshot.events[0].label);
}
