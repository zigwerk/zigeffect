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
    pub fn escapeAlloc(_: Codec, allocator: std.mem.Allocator, value: []const u8) std.mem.Allocator.Error![]const u8 {
        return escapeStringAlloc(allocator, value);
    }

    pub fn objectAlloc(_: Codec, allocator: std.mem.Allocator, fields: []const Field) std.mem.Allocator.Error![]const u8 {
        return objectFromFieldsAlloc(allocator, fields);
    }
};

pub fn ObjectEffect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = []const u8;
        pub const FailureType = std.mem.Allocator.Error;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Codec};

        fields: []const Field,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType![]const u8 {
            const codec = ctx.service(Codec);
            const output = codec.objectAlloc(ctx.allocator, self.fields) catch |err| {
                _ = StdService.recordOperation(ctx, Codec, "object", "failure", "json object");
                return err;
            };
            _ = StdService.recordOperation(ctx, Codec, "object", "success", "json object");
            return output;
        }
    };
}

pub fn objectEffect(comptime EffectEnv: type, fields: []const Field) ObjectEffect(EffectEnv) {
    return .{ .fields = fields };
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

test "Json objectEffect uses Codec service and records causal fact" {
    const zstd = @import("../root.zig");

    var codec = Codec{};
    var provider = zstd.Service.Provider(.{Codec}).init(.{&codec});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{Codec})
        .withCausalStore(&store);

    const fields = [_]Field{
        .{ .name = "status", .value = "ok" },
    };
    const output = try runtime.run(objectEffect(@TypeOf(provider), fields[0..]));
    defer std.testing.allocator.free(output);

    try std.testing.expectEqualStrings("{\"status\":\"ok\"}", output);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(zstd.Service.hasOperation(snapshot, Codec, "object", "success"));
}
