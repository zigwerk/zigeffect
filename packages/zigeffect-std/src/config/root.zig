const std = @import("std");
const Secrets = @import("../secrets/root.zig");

pub const ConfigError = error{MissingValue};

pub const Entry = struct {
    key: []const u8,
    value: []const u8,
    secret: bool = false,
};

const StoredValue = struct {
    value: []const u8,
    secret: bool,
};

pub const LayeredConfig = struct {
    allocator: std.mem.Allocator,
    values: std.StringHashMap(StoredValue),

    pub fn init(allocator: std.mem.Allocator) LayeredConfig {
        return .{
            .allocator = allocator,
            .values = std.StringHashMap(StoredValue).init(allocator),
        };
    }

    pub fn deinit(self: *LayeredConfig) void {
        var iterator = self.values.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.value);
        }
        self.values.deinit();
    }

    pub fn put(
        self: *LayeredConfig,
        key: []const u8,
        value: []const u8,
        secret: bool,
    ) std.mem.Allocator.Error!void {
        if (self.values.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.value);
        }
        try self.values.put(
            try self.allocator.dupe(u8, key),
            .{
                .value = try self.allocator.dupe(u8, value),
                .secret = secret,
            },
        );
    }

    pub fn get(self: LayeredConfig, key: []const u8) ?[]const u8 {
        const stored = self.values.get(key) orelse return null;
        return stored.value;
    }

    pub fn require(self: LayeredConfig, key: []const u8) ConfigError![]const u8 {
        return self.get(key) orelse ConfigError.MissingValue;
    }

    pub fn displayValueAlloc(
        self: LayeredConfig,
        allocator: std.mem.Allocator,
        key: []const u8,
    ) ![]const u8 {
        const stored = self.values.get(key) orelse return ConfigError.MissingValue;
        if (stored.secret or Secrets.containsSecret(stored.value)) {
            return allocator.dupe(u8, Secrets.redacted);
        }
        return allocator.dupe(u8, stored.value);
    }
};

test "Config resolves layered values and redacts sensitive keys" {
    var config = LayeredConfig.init(std.testing.allocator);
    defer config.deinit();

    try config.put("DATABASE_URL", "postgres://user:pass@localhost/db", true);
    try config.put("MODE", "local", false);

    try std.testing.expectEqualStrings("local", config.require("MODE") catch unreachable);

    const display = try config.displayValueAlloc(std.testing.allocator, "DATABASE_URL");
    defer std.testing.allocator.free(display);
    try std.testing.expectEqualStrings("[REDACTED]", display);

    try std.testing.expectError(ConfigError.MissingValue, config.require("MISSING"));
}
