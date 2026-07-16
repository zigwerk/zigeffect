const std = @import("std");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

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

pub const API = struct {
    pub const operations: []const []const u8 = &.{"Environment.require"};
    map: *EnvMap,

    pub fn require(self: API, name: []const u8) EnvError![]const u8 {
        return self.map.require(name);
    }
};

pub const Environment = fx.kernel.Service("zigeffect/std/Environment", API);

pub fn layer(map: *EnvMap) @TypeOf(fx.kernel.Layer.succeed(Environment, API{ .map = map })) {
    return fx.kernel.Layer.succeed(Environment, .{ .map = map });
}

pub fn require(name: []const u8) fx.kernel.Effect([]const u8, EnvError, .{Environment}).Stateful([]const u8) {
    const Require = fx.kernel.Effect([]const u8, EnvError, .{Environment});
    return Require.fromState([]const u8, name, struct {
        fn run(value: []const u8, ctx: *Require.Context) EnvError![]const u8 {
            const operation = StdService.beginOperation(ctx, Environment.service_key, "Environment.require", value);
            const result = ctx.service(Environment).require(value) catch |failure| {
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.completeOperation(ctx, operation, "success", value);
            return result;
        }
    }.run);
}

test "Env require returns value or MissingVariable" {
    var env = EnvMap.init(std.testing.allocator);
    defer env.deinit();

    try env.put("NAME", "Sean");

    try std.testing.expectEqualStrings("Sean", try env.require("NAME"));
    try std.testing.expectError(EnvError.MissingVariable, env.require("MISSING"));
}

test "Environment.require resolves through a canonical layer and records causal fact" {
    var env_map = EnvMap.init(std.testing.allocator);
    defer env_map.deinit();
    try env_map.put("MODE", "test");
    const root = layer(&env_map);
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{ .causal_store = &store });
    defer runtime.deinit();

    try std.testing.expectEqualStrings("test", try runtime.run(require("MODE")));

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    var saw = false;
    for (snapshot.events) |event| {
        if (event.kind == .io_completed and std.mem.eql(u8, event.service_key, Environment.service_key)) saw = true;
    }
    try std.testing.expect(saw);
}
