const std = @import("std");
const Secrets = @import("../secrets/root.zig");
const StdService = @import("../service/root.zig");
const Schema = @import("../schema/root.zig");
const fx = @import("zigeffect");

pub const service_key = "zigeffect/default/ConfigProvider";
pub const ConfigError = error{ MissingValue, ProviderFailure };

pub const Entry = struct {
    key: []const u8,
    value: []const u8,
    secret: bool = false,
};

pub const ProvenanceKind = enum { default_value, file, environment, runtime_override };

pub const Provenance = struct {
    kind: ProvenanceKind,
    source: []const u8,
    priority: u16,
    generation: u64 = 0,
};

pub const ReloadPolicy = enum { never, explicit };

const StoredValue = struct {
    value: []const u8,
    secret: bool,
    provenance: Provenance,
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
            self.allocator.free(entry.value_ptr.provenance.source);
        }
        self.values.deinit();
    }

    pub fn put(
        self: *LayeredConfig,
        key: []const u8,
        value: []const u8,
        secret: bool,
    ) std.mem.Allocator.Error!void {
        return self.putWithProvenance(key, value, secret, .{ .kind = .runtime_override, .source = "runtime", .priority = 400 });
    }

    pub fn putWithProvenance(self: *LayeredConfig, key: []const u8, value: []const u8, secret: bool, provenance_value: Provenance) std.mem.Allocator.Error!void {
        if (self.values.get(key)) |current| {
            if (current.provenance.priority > provenance_value.priority) return;
        }
        if (self.values.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.value);
            self.allocator.free(old.value.provenance.source);
        }
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);
        const owned_source = try self.allocator.dupe(u8, provenance_value.source);
        errdefer self.allocator.free(owned_source);
        try self.values.put(
            owned_key,
            .{
                .value = owned_value,
                .secret = secret,
                .provenance = .{ .kind = provenance_value.kind, .source = owned_source, .priority = provenance_value.priority, .generation = provenance_value.generation },
            },
        );
    }

    pub fn get(self: LayeredConfig, key: []const u8) ?[]const u8 {
        const stored = self.values.get(key) orelse return null;
        return stored.value;
    }

    pub fn getAlloc(self: *LayeredConfig, allocator: std.mem.Allocator, key: []const u8) anyerror![]u8 {
        const value = self.get(key) orelse return error.MissingConfig;
        return allocator.dupe(u8, value);
    }

    pub fn asDefault(self: *LayeredConfig) fx.kernel.ConfigProvider {
        return fx.kernel.ConfigProvider.from(LayeredConfig, self);
    }

    pub fn require(self: LayeredConfig, key: []const u8) ConfigError![]const u8 {
        return self.get(key) orelse ConfigError.MissingValue;
    }

    pub fn provenance(self: LayeredConfig, key: []const u8) ?Provenance {
        return if (self.values.get(key)) |stored| stored.provenance else null;
    }

    pub fn loadEnvironment(self: *LayeredConfig, environ: std.process.Environ, keys: []const Entry, generation: u64) !usize {
        var loaded: usize = 0;
        for (keys) |entry| {
            const value = std.process.Environ.getAlloc(environ, self.allocator, entry.key) catch |err| switch (err) {
                error.EnvironmentVariableMissing => continue,
                else => return err,
            };
            defer self.allocator.free(value);
            try self.putWithProvenance(entry.key, value, entry.secret, .{ .kind = .environment, .source = entry.key, .priority = 300, .generation = generation });
            loaded += 1;
        }
        return loaded;
    }

    pub fn loadJsonFile(self: *LayeredConfig, io: std.Io, dir: *std.Io.Dir, path: []const u8, max_bytes: usize, generation: u64) !usize {
        if (max_bytes == 0) return error.InvalidConfigLimit;
        const content = try dir.readFileAlloc(io, path, self.allocator, .limited(max_bytes));
        defer self.allocator.free(content);
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, content, .{});
        defer parsed.deinit();
        const object = switch (parsed.value) {
            .object => |value| value,
            else => return error.InvalidConfigDocument,
        };
        var loaded: usize = 0;
        var iterator = object.iterator();
        while (iterator.next()) |entry| {
            const encoded = switch (entry.value_ptr.*) {
                .string => |value| try self.allocator.dupe(u8, value),
                else => try std.json.Stringify.valueAlloc(self.allocator, entry.value_ptr.*, .{}),
            };
            defer self.allocator.free(encoded);
            try self.putWithProvenance(entry.key_ptr.*, encoded, false, .{ .kind = .file, .source = path, .priority = 200, .generation = generation });
            loaded += 1;
        }
        return loaded;
    }

    pub fn decodeDetailedAlloc(self: LayeredConfig, allocator: std.mem.Allocator, schema: anytype) !Schema.DecodeResult(@TypeOf(schema).Output) {
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(allocator);
        try output.append(allocator, '{');
        var iterator = self.values.iterator();
        var index: usize = 0;
        while (iterator.next()) |entry| : (index += 1) {
            if (index != 0) try output.append(allocator, ',');
            try appendJsonString(&output, allocator, entry.key_ptr.*);
            try output.append(allocator, ':');
            if (validJsonScalar(allocator, entry.value_ptr.value)) {
                try output.appendSlice(allocator, entry.value_ptr.value);
            } else {
                try appendJsonString(&output, allocator, entry.value_ptr.value);
            }
        }
        try output.append(allocator, '}');
        return Schema.decodeDetailedJsonAlloc(allocator, schema, output.items);
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

fn validJsonScalar(allocator: std.mem.Allocator, value: []const u8) bool {
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, value, .{}) catch return false;
    defer parsed.deinit();
    return switch (parsed.value) {
        .string, .array, .object => false,
        else => true,
    };
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    const encoded = try std.json.Stringify.valueAlloc(allocator, value, .{});
    defer allocator.free(encoded);
    try output.appendSlice(allocator, encoded);
}

pub fn getAlloc(key: []const u8) fx.kernel.Effect(
    []u8,
    ConfigError || std.mem.Allocator.Error,
    .{},
).Stateful([]const u8) {
    const ConfigEffect = fx.kernel.Effect(
        []u8,
        ConfigError || std.mem.Allocator.Error,
        .{},
    );
    return ConfigEffect.fromState([]const u8, key, struct {
        fn run(name: []const u8, ctx: *fx.kernel.ContextView(.{})) (ConfigError || std.mem.Allocator.Error)![]u8 {
            const value = ctx.configProvider().getAlloc(ctx.allocator(), name) catch |failure| {
                _ = StdService.recordSemantic(
                    ctx,
                    .span_recorded,
                    service_key,
                    "Config.get",
                    "failure",
                    name,
                );
                return switch (failure) {
                    error.OutOfMemory => error.OutOfMemory,
                    error.MissingConfig, error.MissingValue => error.MissingValue,
                    else => error.ProviderFailure,
                };
            };
            _ = StdService.recordSemantic(
                ctx,
                .span_recorded,
                service_key,
                "Config.get",
                "success",
                name,
            );
            return value;
        }
    }.run);
}

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

test "Config precedence provenance and Schema decoding are deterministic" {
    var config = LayeredConfig.init(std.testing.allocator);
    defer config.deinit();
    try config.putWithProvenance("port", "8080", false, .{ .kind = .file, .source = "config.json", .priority = 200 });
    try config.putWithProvenance("port", "9090", false, .{ .kind = .environment, .source = "PORT", .priority = 300 });
    try config.putWithProvenance("port", "7070", false, .{ .kind = .file, .source = "stale.json", .priority = 200 });
    try std.testing.expectEqualStrings("9090", try config.require("port"));
    try std.testing.expectEqual(ProvenanceKind.environment, config.provenance("port").?.kind);
    const PortConfig = struct { port: i64 };
    var decoded = try config.decodeDetailedAlloc(std.testing.allocator, Schema.structSchema(PortConfig, .{Schema.field("port", Schema.integer())}));
    defer decoded.deinit();
    try std.testing.expect(decoded.ok());
    try std.testing.expectEqual(@as(i64, 9090), decoded.value.?.port);
}

test "Config.get resolves through the canonical default service" {
    var config = LayeredConfig.init(std.testing.allocator);
    defer config.deinit();
    try config.put("MODE", "local", false);
    const root = fx.kernel.Layer.empty();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{});
    defer runtime.deinit();

    const value = try runtime.run(getAlloc("MODE").withDefaults(.{ .config_provider = config.asDefault() }));
    defer std.testing.allocator.free(value);
    try std.testing.expectEqualStrings("local", value);
}
