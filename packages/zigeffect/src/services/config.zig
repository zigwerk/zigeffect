const std = @import("std");
const context_mod = @import("../core/context.zig");

pub const Allocator = std.mem.Allocator;
pub const serviceNotFound = context_mod.serviceNotFound;

pub const ConfigError = error{ MissingConfig, InvalidConfigValue };

pub const ConfigEntry = struct {
    key: []const u8,
    value: []const u8,
};

pub const ConfigKind = enum {
    string,
    int,
    boolean,
};

pub fn ConfigDescriptor(comptime Value: type) type {
    return struct {
        const Self = @This();
        pub const ValueType = Value;

        key: []const u8,
        kind: ConfigKind,
        default: ?Value = null,
        redacted: bool = false,

        pub fn withDefault(self: Self, value: Value) Self {
            var descriptor = self;
            descriptor.default = value;
            return descriptor;
        }

        pub fn secret(self: Self) Self {
            var descriptor = self;
            descriptor.redacted = true;
            return descriptor;
        }
    };
}

pub const StringDescriptor = ConfigDescriptor([]const u8);
pub const IntDescriptor = ConfigDescriptor(i64);
pub const BoolDescriptor = ConfigDescriptor(bool);

fn assertConfigSchema(comptime Output: type, comptime descriptors: anytype) void {
    const output_info = switch (@typeInfo(Output)) {
        .@"struct" => |info| info,
        else => @compileError(
            "zigeffect config schema output must be a struct\n\n" ++
                "output type: " ++ @typeName(Output),
        ),
    };

    const DescriptorStruct = @TypeOf(descriptors);
    const descriptor_info = switch (@typeInfo(DescriptorStruct)) {
        .@"struct" => |info| blk: {
            if (info.is_tuple) {
                @compileError(
                    "zigeffect config schema descriptors must be a named struct\n\n" ++
                        "Use .{ .field_name = fx.Config.string(\"key\") } so descriptors map to output fields.",
                );
            }
            break :blk info;
        },
        else => @compileError(
            "zigeffect config schema descriptors must be a named struct\n\n" ++
                "Use .{ .field_name = fx.Config.string(\"key\") }.",
        ),
    };

    inline for (output_info.fields) |field| {
        if (!@hasField(DescriptorStruct, field.name)) {
            @compileError(
                "zigeffect config schema missing descriptor\n\n" ++
                    "field: " ++ field.name ++ "\n" ++
                    "output type: " ++ @typeName(Output),
            );
        }

        const descriptor = @field(descriptors, field.name);
        const Descriptor = @TypeOf(descriptor);
        if (!@hasDecl(Descriptor, "ValueType")) {
            @compileError(
                "zigeffect config schema descriptor must be a ConfigDescriptor\n\n" ++
                    "field: " ++ field.name,
            );
        }
        if (Descriptor.ValueType != field.type) {
            @compileError(
                "zigeffect config schema descriptor type mismatch\n\n" ++
                    "field: " ++ field.name ++ "\n" ++
                    "expected: " ++ @typeName(field.type) ++ "\n" ++
                    "descriptor: " ++ @typeName(Descriptor.ValueType),
            );
        }
    }

    inline for (descriptor_info.fields) |field| {
        if (!@hasField(Output, field.name)) {
            @compileError(
                "zigeffect config schema has descriptor without output field\n\n" ++
                    "field: " ++ field.name ++ "\n" ++
                    "output type: " ++ @typeName(Output),
            );
        }
    }
}

pub fn ConfigSchema(comptime Output: type, comptime schema_descriptors: anytype) type {
    assertConfigSchema(Output, schema_descriptors);

    return struct {
        pub const OutputType = Output;
        pub const Descriptors = schema_descriptors;
    };
}

pub const Config = struct {
    allocator: Allocator,
    values: std.StringHashMap([]const u8),

    pub fn init(allocator: Allocator) Config {
        return .{
            .allocator = allocator,
            .values = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Config) void {
        var iterator = self.values.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.values.deinit();
    }

    pub fn set(self: *Config, key: []const u8, value: []const u8) Allocator.Error!void {
        if (self.values.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }

        try self.values.put(
            try self.allocator.dupe(u8, key),
            try self.allocator.dupe(u8, value),
        );
    }

    pub fn loadEntries(self: *Config, entries: []const ConfigEntry) Allocator.Error!void {
        for (entries) |entry| {
            try self.set(entry.key, entry.value);
        }
    }

    pub fn loadDotEnv(self: *Config, text: []const u8) (Allocator.Error || ConfigError)!void {
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |raw_line| {
            const line = std.mem.trim(u8, raw_line, " \t\r");
            if (line.len == 0 or line[0] == '#') continue;

            const separator = std.mem.indexOfScalar(u8, line, '=') orelse
                return error.InvalidConfigValue;
            const key = std.mem.trim(u8, line[0..separator], " \t");
            const value = std.mem.trim(u8, line[separator + 1 ..], " \t");
            if (key.len == 0) return error.InvalidConfigValue;

            try self.set(key, value);
        }
    }

    pub fn get(self: *Config, key: []const u8) ?[]const u8 {
        return self.values.get(key);
    }

    pub fn require(self: *Config, key: []const u8) ConfigError![]const u8 {
        return self.get(key) orelse error.MissingConfig;
    }

    pub fn string(key: []const u8) StringDescriptor {
        return .{
            .key = key,
            .kind = .string,
        };
    }

    pub fn int(key: []const u8) IntDescriptor {
        return .{
            .key = key,
            .kind = .int,
        };
    }

    pub fn boolean(key: []const u8) BoolDescriptor {
        return .{
            .key = key,
            .kind = .boolean,
        };
    }

    pub fn schema(comptime Output: type, comptime descriptors: anytype) ConfigSchema(Output, descriptors) {
        return .{};
    }

    pub fn read(self: *Config, descriptor: anytype) ConfigError!@TypeOf(descriptor).ValueType {
        const Descriptor = @TypeOf(descriptor);
        const Value = Descriptor.ValueType;
        const raw = self.get(descriptor.key) orelse {
            if (descriptor.default) |default| return default;
            return error.MissingConfig;
        };

        if (Value == []const u8) return raw;
        if (Value == i64) return std.fmt.parseInt(i64, raw, 10) catch error.InvalidConfigValue;
        if (Value == bool) return parseBool(raw) orelse error.InvalidConfigValue;

        @compileError("zigeffect unsupported config descriptor value type: " ++ @typeName(Value));
    }

    pub fn readSchema(self: *Config, schema_value: anytype) ConfigError!@TypeOf(schema_value).OutputType {
        const Schema = @TypeOf(schema_value);
        var output: Schema.OutputType = undefined;

        inline for (std.meta.fields(Schema.OutputType)) |field| {
            @field(output, field.name) = try self.read(@field(Schema.Descriptors, field.name));
        }

        return output;
    }
};

pub const ConfigEnv = struct {
    config: Config,

    pub fn init(allocator: Allocator) ConfigEnv {
        return .{ .config = Config.init(allocator) };
    }

    pub fn deinit(self: *ConfigEnv) void {
        self.config.deinit();
    }

    pub fn service(self: *ConfigEnv, comptime Service: type) *Service {
        if (Service == Config) return &self.config;
        return serviceNotFound(ConfigEnv, Service);
    }
};

fn parseBool(raw: []const u8) ?bool {
    if (std.mem.eql(u8, raw, "true") or std.mem.eql(u8, raw, "1")) return true;
    if (std.mem.eql(u8, raw, "false") or std.mem.eql(u8, raw, "0")) return false;
    return null;
}

fn kindName(kind: ConfigKind) []const u8 {
    return switch (kind) {
        .string => "string",
        .int => "int",
        .boolean => "boolean",
    };
}

pub fn formatConfigError(allocator: Allocator, descriptor: anytype, err: ConfigError) Allocator.Error![]const u8 {
    const value_note = if (descriptor.redacted)
        "value: redacted\n"
    else
        "";
    const hint = switch (err) {
        error.MissingConfig => "Provide this key or add a descriptor default.",
        error.InvalidConfigValue => if (descriptor.redacted)
            "Check the configured secret value; it was redacted from this report."
        else
            "Check that the configured value matches the descriptor type.",
    };

    return std.fmt.allocPrint(
        allocator,
        "zigeffect config error\nkey: {s}\ntype: {s}\nerror: {s}\n{s}hint: {s}",
        .{ descriptor.key, kindName(descriptor.kind), @errorName(err), value_note, hint },
    );
}
