const std = @import("std");
const StdService = @import("../service/root.zig");

pub const EnvError = error{
    MissingVariable,
};

pub const EnvMap = struct {
    allocator: std.mem.Allocator,
    values: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) EnvMap {
        return .{
            .allocator = allocator,
            .values = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *EnvMap) void {
        var iterator = self.values.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.values.deinit();
    }

    pub fn put(self: *EnvMap, name: []const u8, value: []const u8) std.mem.Allocator.Error!void {
        if (self.values.fetchRemove(name)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        try self.values.put(
            try self.allocator.dupe(u8, name),
            try self.allocator.dupe(u8, value),
        );
    }

    pub fn get(self: EnvMap, name: []const u8) ?[]const u8 {
        return self.values.get(name);
    }

    pub fn require(self: EnvMap, name: []const u8) EnvError![]const u8 {
        return self.get(name) orelse EnvError.MissingVariable;
    }
};

pub fn RequireEffect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = []const u8;
        pub const FailureType = EnvError;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{EnvMap};

        name: []const u8,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!@import("zigeffect").ServiceSet {
            return @import("zigeffect").ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *@import("zigeffect").Context(EffectEnv)) EnvError![]const u8 {
            const env = ctx.service(EnvMap);
            const value = env.require(self.name) catch |err| {
                _ = StdService.recordOperation(ctx, EnvMap, "require", "failure", self.name);
                return err;
            };
            _ = StdService.recordOperation(ctx, EnvMap, "require", "success", self.name);
            return value;
        }
    };
}

pub fn requireEffect(comptime EffectEnv: type, name: []const u8) RequireEffect(EffectEnv) {
    return .{ .name = name };
}

test "Env require returns value or MissingVariable" {
    var env = EnvMap.init(std.testing.allocator);
    defer env.deinit();

    try env.put("NAME", "Sean");

    try std.testing.expectEqualStrings("Sean", try env.require("NAME"));
    try std.testing.expectError(EnvError.MissingVariable, env.require("MISSING"));
}

test "Env requireEffect resolves through runtime services and records causal fact" {
    const zstd = @import("../root.zig");

    var env_map = EnvMap.init(std.testing.allocator);
    defer env_map.deinit();
    try env_map.put("MODE", "test");

    var provider = zstd.Service.Provider(.{EnvMap}).init(.{&env_map});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{EnvMap})
        .withCausalStore(&store);

    try std.testing.expectEqualStrings("test", try runtime.run(requireEffect(@TypeOf(provider), "MODE")));

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expectEqual(zstd.fx.CausalEventKind.span_recorded, snapshot.events[0].kind);
    try std.testing.expectEqualStrings(@typeName(EnvMap), snapshot.events[0].service_key);
    try std.testing.expectEqualStrings("require", snapshot.events[0].label);
}
