const std = @import("std");
const Secrets = @import("../secrets/root.zig");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const Field = struct {
    name: []const u8,
    value: []const u8,
    redact: bool = false,
};

pub fn escapeStringAlloc(allocator: std.mem.Allocator, value: []const u8) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    for (value) |byte| {
        switch (byte) {
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '"' => try output.appendSlice(allocator, "\\\""),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            else => try output.append(allocator, byte),
        }
    }

    return output.toOwnedSlice(allocator);
}

pub fn objectFromFieldsAlloc(allocator: std.mem.Allocator, fields: []const Field) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.append(allocator, '{');
    for (fields, 0..) |field, index| {
        if (index != 0) try output.append(allocator, ',');

        const escaped_name = try escapeStringAlloc(allocator, field.name);
        defer allocator.free(escaped_name);
        const raw_value = if (field.redact or Secrets.containsSecret(field.value))
            Secrets.redacted
        else
            field.value;
        const escaped_value = try escapeStringAlloc(allocator, raw_value);
        defer allocator.free(escaped_value);

        try output.print(allocator, "\"{s}\":\"{s}\"", .{ escaped_name, escaped_value });
    }
    try output.append(allocator, '}');

    return output.toOwnedSlice(allocator);
}

pub const Codec = struct {
    pub const operations: []const []const u8 = &.{"Json.object"};

    pub fn escapeAlloc(_: Codec, allocator: std.mem.Allocator, value: []const u8) std.mem.Allocator.Error![]const u8 {
        return escapeStringAlloc(allocator, value);
    }

    pub fn objectAlloc(_: Codec, allocator: std.mem.Allocator, fields: []const Field) std.mem.Allocator.Error![]const u8 {
        return objectFromFieldsAlloc(allocator, fields);
    }
};

pub const JsonCodec = fx.kernel.Service("zigeffect/std/JsonCodec", Codec);

pub fn codecLayer() @TypeOf(fx.kernel.Layer.succeed(JsonCodec, Codec{})) {
    return fx.kernel.Layer.succeed(JsonCodec, .{});
}

pub fn object(fields: []const Field) fx.kernel.Effect(
    []const u8,
    std.mem.Allocator.Error,
    .{JsonCodec},
).Stateful([]const Field) {
    const Object = fx.kernel.Effect([]const u8, std.mem.Allocator.Error, .{JsonCodec});
    return Object.fromState([]const Field, fields, struct {
        fn run(value: []const Field, ctx: *Object.Context) std.mem.Allocator.Error![]const u8 {
            const operation = StdService.beginOperation(ctx, JsonCodec.service_key, "Json.object", "bounded fields");
            const output = ctx.service(JsonCodec).objectAlloc(ctx.allocator(), value) catch |failure| {
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.completeOperation(ctx, operation, "success", "json object");
            return output;
        }
    }.run);
}

test "Json writes stable redacted object fields" {
    const fields = [_]Field{
        .{ .name = "command", .value = "zg hello" },
        .{ .name = "token", .value = "token=abc123" },
    };

    const json = try objectFromFieldsAlloc(std.testing.allocator, fields[0..]);
    defer std.testing.allocator.free(json);

    try std.testing.expectEqualStrings(
        "{\"command\":\"zg hello\",\"token\":\"[REDACTED]\"}",
        json,
    );
}

test "Json escapes strings deterministically" {
    const escaped = try escapeStringAlloc(std.testing.allocator, "line\n\"quoted\"\\tail");
    defer std.testing.allocator.free(escaped);

    try std.testing.expectEqualStrings("line\\n\\\"quoted\\\"\\\\tail", escaped);
}

test "Json.object uses a canonical codec layer and records causal fact" {
    const root = codecLayer();
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{ .causal_store = &store });
    defer runtime.deinit();

    const fields = [_]Field{
        .{ .name = "status", .value = "ok" },
    };
    const output = try runtime.run(object(fields[0..]));
    defer std.testing.allocator.free(output);

    try std.testing.expectEqualStrings("{\"status\":\"ok\"}", output);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    var saw = false;
    for (snapshot.events) |event| {
        if (event.kind == .io_completed and std.mem.eql(u8, event.service_key, JsonCodec.service_key)) saw = true;
    }
    try std.testing.expect(saw);
}
