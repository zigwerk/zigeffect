const std = @import("std");
const Json = @import("../json/root.zig");
const Secrets = @import("../secrets/root.zig");

pub const SchemaError = error{
    InvalidType,
    MissingField,
    InvalidValue,
    UnknownEnum,
    TransformFailed,
};

pub const IssueKind = enum {
    invalid_type,
    missing_field,
    invalid_value,
    unknown_enum,
};

pub const Issue = struct {
    path: []const u8,
    kind: IssueKind,
    expected: []const u8,
    actual: []const u8,
    message: []const u8 = "",
};

pub fn issueJsonAlloc(allocator: std.mem.Allocator, issue: Issue) ![]const u8 {
    const fields = [_]Json.Field{
        .{ .name = "path", .value = issue.path },
        .{ .name = "kind", .value = issueKindName(issue.kind) },
        .{ .name = "expected", .value = issue.expected },
        .{ .name = "actual", .value = if (Secrets.containsSecret(issue.actual)) Secrets.redacted else issue.actual },
        .{ .name = "message", .value = issue.message },
    };
    return Json.objectFromFieldsAlloc(allocator, fields[0..]);
}

pub const StringSchema = struct {
    pub const Output = []const u8;

    pub fn decodeJsonValue(_: StringSchema, value: std.json.Value) SchemaError![]const u8 {
        return switch (value) {
            .string => |text| text,
            else => SchemaError.InvalidType,
        };
    }

    pub fn decodeConfigText(_: StringSchema, value: []const u8) SchemaError![]const u8 {
        return value;
    }
};

pub const IntegerSchema = struct {
    pub const Output = i64;

    pub fn decodeJsonValue(_: IntegerSchema, value: std.json.Value) SchemaError!i64 {
        return switch (value) {
            .integer => |integer_value| integer_value,
            else => SchemaError.InvalidType,
        };
    }

    pub fn decodeConfigText(_: IntegerSchema, value: []const u8) SchemaError!i64 {
        return std.fmt.parseInt(i64, value, 10) catch SchemaError.InvalidValue;
    }
};

pub const BooleanSchema = struct {
    pub const Output = bool;

    pub fn decodeJsonValue(_: BooleanSchema, value: std.json.Value) SchemaError!bool {
        return switch (value) {
            .bool => |bool_value| bool_value,
            else => SchemaError.InvalidType,
        };
    }

    pub fn decodeConfigText(_: BooleanSchema, value: []const u8) SchemaError!bool {
        if (std.mem.eql(u8, value, "true")) return true;
        if (std.mem.eql(u8, value, "false")) return false;
        return SchemaError.InvalidValue;
    }
};

pub fn string() StringSchema {
    return .{};
}

pub fn integer() IntegerSchema {
    return .{};
}

pub fn boolean() BooleanSchema {
    return .{};
}

pub fn decodeJsonValue(
    schema: anytype,
    value: std.json.Value,
) (SchemaError || std.mem.Allocator.Error)!@TypeOf(schema).Output {
    return schema.decodeJsonValue(value);
}

pub fn OptionalSchema(comptime Inner: type) type {
    return struct {
        pub const Output = ?Inner.Output;
        inner: Inner,

        pub fn decodeJsonValue(self: @This(), value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            return switch (value) {
                .null => null,
                else => try self.inner.decodeJsonValue(value),
            };
        }

        pub fn decodeConfigText(self: @This(), value: []const u8) (SchemaError || std.mem.Allocator.Error)!Output {
            if (value.len == 0) return null;
            return try rootDecodeConfigText(self.inner, value);
        }
    };
}

pub fn optional(schema: anytype) OptionalSchema(@TypeOf(schema)) {
    return .{ .inner = schema };
}

pub fn ArraySchema(comptime Inner: type) type {
    return struct {
        pub const Output = []const Inner.Output;
        allocator: std.mem.Allocator,
        inner: Inner,

        pub fn decodeJsonValue(self: @This(), value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            const values = switch (value) {
                .array => |array_value| array_value.items,
                else => return SchemaError.InvalidType,
            };
            const decoded = try self.allocator.alloc(Inner.Output, values.len);
            errdefer self.allocator.free(decoded);
            for (values, 0..) |item, index| {
                decoded[index] = try self.inner.decodeJsonValue(item);
            }
            return decoded;
        }
    };
}

pub fn array(allocator: std.mem.Allocator, schema: anytype) ArraySchema(@TypeOf(schema)) {
    return .{ .allocator = allocator, .inner = schema };
}

pub fn EnumSchema(comptime choices: []const []const u8) type {
    return struct {
        pub const Output = []const u8;

        pub fn decodeJsonValue(_: @This(), value: std.json.Value) SchemaError![]const u8 {
            const text = switch (value) {
                .string => |string_value| string_value,
                else => return SchemaError.InvalidType,
            };
            inline for (choices) |choice| {
                if (std.mem.eql(u8, text, choice)) return text;
            }
            return SchemaError.UnknownEnum;
        }
    };
}

pub fn stringEnum(comptime choices: []const []const u8) EnumSchema(choices) {
    return .{};
}

pub fn TransformSchema(
    comptime Inner: type,
    comptime Next: type,
    comptime mapper: *const fn (Inner.Output) SchemaError!Next,
) type {
    return struct {
        pub const Output = Next;
        inner: Inner,

        pub fn decodeJsonValue(self: @This(), value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Next {
            return mapper(try self.inner.decodeJsonValue(value)) catch SchemaError.TransformFailed;
        }

        pub fn decodeConfigText(self: @This(), value: []const u8) (SchemaError || std.mem.Allocator.Error)!Next {
            return mapper(try rootDecodeConfigText(self.inner, value)) catch SchemaError.TransformFailed;
        }
    };
}

pub fn transform(
    schema: anytype,
    comptime Next: type,
    comptime mapper: *const fn (@TypeOf(schema).Output) SchemaError!Next,
) TransformSchema(@TypeOf(schema), Next, mapper) {
    return .{ .inner = schema };
}

pub fn freeDecoded(allocator: std.mem.Allocator, value: anytype) void {
    const Value = @TypeOf(value);
    switch (@typeInfo(Value)) {
        .pointer => |pointer| if (pointer.size == .slice) allocator.free(value),
        else => {},
    }
}

pub fn FieldSpec(comptime SchemaType: type, comptime name: []const u8) type {
    return struct {
        pub const Name = name;
        pub const Schema = SchemaType;
        schema: SchemaType,
    };
}

pub fn field(comptime name: []const u8, schema: anytype) FieldSpec(@TypeOf(schema), name) {
    return .{ .schema = schema };
}

pub fn StructSchema(comptime StructOutput: type, comptime Fields: type) type {
    return struct {
        pub const Output = StructOutput;
        fields: Fields,

        pub fn decodeJsonValue(self: @This(), value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            const object = switch (value) {
                .object => |object_value| object_value,
                else => return SchemaError.InvalidType,
            };

            var output: StructOutput = undefined;
            inline for (self.fields) |field_spec| {
                const Field = @TypeOf(field_spec);
                const FieldOutput = Field.Schema.Output;
                if (object.get(Field.Name)) |field_value| {
                    @field(output, Field.Name) = try field_spec.schema.decodeJsonValue(field_value);
                } else if (isOptional(FieldOutput)) {
                    @field(output, Field.Name) = null;
                } else {
                    return SchemaError.MissingField;
                }
            }
            return output;
        }
    };
}

pub fn structSchema(comptime Output: type, fields: anytype) StructSchema(Output, @TypeOf(fields)) {
    return .{ .fields = fields };
}

pub fn decodeJsonAlloc(
    allocator: std.mem.Allocator,
    schema: anytype,
    json: []const u8,
) !@TypeOf(schema).Output {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
    defer parsed.deinit();
    return decodeJsonValue(schema, parsed.value);
}

pub fn decodeConfig(config: anytype, comptime key: []const u8, schema: anytype) !@TypeOf(schema).Output {
    const text = config.require(key) catch {
        if (isOptional(@TypeOf(schema).Output)) return null;
        return SchemaError.MissingField;
    };
    return decodeConfigText(schema, text);
}

fn decodeConfigText(schema: anytype, value: []const u8) !@TypeOf(schema).Output {
    return rootDecodeConfigText(schema, value);
}

fn rootDecodeConfigText(schema: anytype, value: []const u8) !@TypeOf(schema).Output {
    if (@hasDecl(@TypeOf(schema), "decodeConfigText")) {
        return schema.decodeConfigText(value);
    }
    return SchemaError.InvalidType;
}

fn isOptional(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .optional => true,
        else => false,
    };
}

fn issueKindName(kind: IssueKind) []const u8 {
    return switch (kind) {
        .invalid_type => "invalid_type",
        .missing_field => "missing_field",
        .invalid_value => "invalid_value",
        .unknown_enum => "unknown_enum",
    };
}

test "Schema decodes primitive JSON values" {
    try std.testing.expectEqualStrings(
        "hello",
        try decodeJsonValue(string(), .{ .string = "hello" }),
    );
    try std.testing.expectEqual(@as(i64, 42), try decodeJsonValue(integer(), .{ .integer = 42 }));
    try std.testing.expectEqual(true, try decodeJsonValue(boolean(), .{ .bool = true }));
}

test "Schema returns structured redacted issue for invalid primitive" {
    try std.testing.expectError(
        SchemaError.InvalidType,
        decodeJsonValue(integer(), .{ .string = "not-an-int" }),
    );

    const json = try issueJsonAlloc(std.testing.allocator, .{
        .path = "DATABASE_URL",
        .kind = .invalid_value,
        .expected = "safe-url",
        .actual = "postgres://user:pass@localhost/db",
        .message = "connection string is not allowed here",
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "pass") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "[REDACTED]") != null);
}

test "Schema decodes optional and array JSON values" {
    try std.testing.expectEqual(@as(?[]const u8, null), try decodeJsonValue(optional(string()), .null));
    try std.testing.expectEqualStrings("value", (try decodeJsonValue(optional(string()), .{ .string = "value" })).?);

    const values = [_]std.json.Value{
        .{ .integer = 1 },
        .{ .integer = 2 },
        .{ .integer = 3 },
    };
    const decoded = try decodeJsonValue(array(std.testing.allocator, integer()), .{ .array = .{ .items = values[0..] } });
    defer freeDecoded(std.testing.allocator, decoded);

    try std.testing.expectEqual(@as(usize, 3), decoded.len);
    try std.testing.expectEqual(@as(i64, 1), decoded[0]);
    try std.testing.expectEqual(@as(i64, 3), decoded[2]);
}

fn stringLength(value: []const u8) SchemaError!usize {
    return value.len;
}

test "Schema decodes enum choices and transform schemas" {
    const mode_schema = stringEnum(&.{ "local", "ci" });
    try std.testing.expectEqualStrings("local", try decodeJsonValue(mode_schema, .{ .string = "local" }));
    try std.testing.expectError(SchemaError.UnknownEnum, decodeJsonValue(mode_schema, .{ .string = "prod" }));

    const length_schema = transform(string(), usize, stringLength);
    try std.testing.expectEqual(@as(usize, 4), try decodeJsonValue(length_schema, .{ .string = "test" }));
}

const AppConfig = struct {
    name: []const u8,
    port: i64,
    enabled: bool,
    mode: ?[]const u8,
};

test "Schema decodes struct fields from JSON object" {
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator,
        \\{"name":"yachdee","port":8080,"enabled":true,"mode":null}
    , .{});
    defer parsed.deinit();

    const app_schema = structSchema(AppConfig, .{
        field("name", string()),
        field("port", integer()),
        field("enabled", boolean()),
        field("mode", optional(string())),
    });

    const decoded = try decodeJsonValue(app_schema, parsed.value);

    try std.testing.expectEqualStrings("yachdee", decoded.name);
    try std.testing.expectEqual(@as(i64, 8080), decoded.port);
    try std.testing.expectEqual(true, decoded.enabled);
    try std.testing.expectEqual(@as(?[]const u8, null), decoded.mode);

    var missing = try std.json.parseFromSlice(std.json.Value, std.testing.allocator,
        \\{"name":"yachdee"}
    , .{});
    defer missing.deinit();

    try std.testing.expectError(SchemaError.MissingField, decodeJsonValue(app_schema, missing.value));
}

test "Schema decodes JSON text and config entries" {
    const app_schema = structSchema(AppConfig, .{
        field("name", string()),
        field("port", integer()),
        field("enabled", boolean()),
        field("mode", optional(string())),
    });

    const decoded = try decodeJsonAlloc(std.testing.allocator, app_schema,
        \\{"name":"json","port":3000,"enabled":false,"mode":"dev"}
    );

    try std.testing.expectEqualStrings("json", decoded.name);
    try std.testing.expectEqual(@as(i64, 3000), decoded.port);
    try std.testing.expectEqual(false, decoded.enabled);
    try std.testing.expectEqualStrings("dev", decoded.mode.?);

    var config = @import("../config/root.zig").LayeredConfig.init(std.testing.allocator);
    defer config.deinit();
    try config.put("HTTP_PORT", "5178", false);

    try std.testing.expectEqual(@as(i64, 5178), try decodeConfig(config, "HTTP_PORT", integer()));
}
