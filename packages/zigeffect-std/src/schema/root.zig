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
    constraint_failed,
    transform_failed,
    encode_failed,
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
        .{ .name = "message", .value = if (Secrets.containsSecret(issue.message)) Secrets.redacted else issue.message },
    };
    return Json.objectFromFieldsAlloc(allocator, fields[0..]);
}

pub const IssueList = struct {
    allocator: std.mem.Allocator,
    items: std.ArrayList(Issue) = .empty,

    pub fn init(allocator: std.mem.Allocator) IssueList {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *IssueList) void {
        for (self.items.items) |issue| {
            self.allocator.free(issue.path);
            self.allocator.free(issue.expected);
            self.allocator.free(issue.actual);
            self.allocator.free(issue.message);
        }
        self.items.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn len(self: *const IssueList) usize {
        return self.items.items.len;
    }

    pub fn add(self: *IssueList, issue: Issue) std.mem.Allocator.Error!void {
        const path = try self.allocator.dupe(u8, issue.path);
        errdefer self.allocator.free(path);
        const expected = try self.allocator.dupe(u8, issue.expected);
        errdefer self.allocator.free(expected);
        const actual = try self.allocator.dupe(u8, issue.actual);
        errdefer self.allocator.free(actual);
        const message = try self.allocator.dupe(u8, issue.message);
        errdefer self.allocator.free(message);

        try self.items.append(self.allocator, .{
            .path = path,
            .kind = issue.kind,
            .expected = expected,
            .actual = actual,
            .message = message,
        });
    }

    pub fn jsonAlloc(self: *const IssueList, allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
        var output: std.ArrayList(u8) = .empty;
        errdefer output.deinit(allocator);

        try output.append(allocator, '[');
        for (self.items.items, 0..) |issue, index| {
            if (index != 0) try output.append(allocator, ',');
            const issue_json = try issueJsonAlloc(allocator, issue);
            defer allocator.free(issue_json);
            try output.appendSlice(allocator, issue_json);
        }
        try output.append(allocator, ']');
        return output.toOwnedSlice(allocator);
    }

    pub fn firstAsError(self: *const IssueList) SchemaError {
        if (self.items.items.len == 0) return SchemaError.InvalidValue;
        return issueKindError(self.items.items[0].kind);
    }
};

pub const ParseContext = struct {
    allocator: std.mem.Allocator,
    issues: *IssueList,
    path: std.ArrayList(u8) = .empty,

    pub fn init(allocator: std.mem.Allocator, issues: *IssueList) ParseContext {
        return .{
            .allocator = allocator,
            .issues = issues,
        };
    }

    pub fn deinit(self: *ParseContext) void {
        self.path.deinit(self.allocator);
    }

    pub fn currentPath(self: *const ParseContext) []const u8 {
        if (self.path.items.len == 0) return "$";
        return self.path.items;
    }

    pub fn mark(self: *ParseContext) std.mem.Allocator.Error!usize {
        try self.ensureRoot();
        return self.path.items.len;
    }

    pub fn popTo(self: *ParseContext, len: usize) void {
        self.path.items.len = len;
    }

    pub fn pushField(self: *ParseContext, name: []const u8) std.mem.Allocator.Error!usize {
        const previous = try self.mark();
        try self.path.append(self.allocator, '.');
        try self.path.appendSlice(self.allocator, name);
        return previous;
    }

    pub fn pushIndex(self: *ParseContext, index: usize) std.mem.Allocator.Error!usize {
        const previous = try self.mark();
        try self.path.writer(self.allocator).print("[{d}]", .{index});
        return previous;
    }

    pub fn addIssue(
        self: *ParseContext,
        kind: IssueKind,
        expected: []const u8,
        actual: []const u8,
        message: []const u8,
    ) std.mem.Allocator.Error!void {
        try self.ensureRoot();
        try self.issues.add(.{
            .path = self.currentPath(),
            .kind = kind,
            .expected = expected,
            .actual = actual,
            .message = message,
        });
    }

    fn ensureRoot(self: *ParseContext) std.mem.Allocator.Error!void {
        if (self.path.items.len == 0) {
            try self.path.append(self.allocator, '$');
        }
    }
};

pub fn DecodeResult(comptime Output: type) type {
    return struct {
        allocator: std.mem.Allocator,
        value: ?Output = null,
        issues: IssueList,
        parsed: ?std.json.Parsed(std.json.Value) = null,

        pub fn ok(self: @This()) bool {
            return self.value != null and self.issues.len() == 0;
        }

        pub fn deinit(self: *@This()) void {
            if (self.value) |value| freeDetailedDecoded(self.allocator, value);
            if (self.parsed) |*parsed| parsed.deinit();
            self.issues.deinit();
            self.* = undefined;
        }
    };
}

pub const StringSchema = struct {
    pub const Output = []const u8;

    require_non_empty: bool = false,
    min_len: ?usize = null,
    max_len: ?usize = null,
    starts_with: ?[]const u8 = null,
    ends_with: ?[]const u8 = null,
    contains_text: ?[]const u8 = null,

    pub fn nonEmpty(self: StringSchema) StringSchema {
        var next = self;
        next.require_non_empty = true;
        return next;
    }

    pub fn minLen(self: StringSchema, len: usize) StringSchema {
        var next = self;
        next.min_len = len;
        return next;
    }

    pub fn maxLen(self: StringSchema, len: usize) StringSchema {
        var next = self;
        next.max_len = len;
        return next;
    }

    pub fn startsWith(self: StringSchema, prefix: []const u8) StringSchema {
        var next = self;
        next.starts_with = prefix;
        return next;
    }

    pub fn endsWith(self: StringSchema, suffix: []const u8) StringSchema {
        var next = self;
        next.ends_with = suffix;
        return next;
    }

    pub fn contains(self: StringSchema, needle: []const u8) StringSchema {
        var next = self;
        next.contains_text = needle;
        return next;
    }

    pub fn decodeJsonValue(self: StringSchema, value: std.json.Value) SchemaError![]const u8 {
        const text = switch (value) {
            .string => |text| text,
            else => SchemaError.InvalidType,
        };
        try self.validateSimple(text);
        return text;
    }

    pub fn decodeDetailedJsonValue(self: StringSchema, ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)![]const u8 {
        const text = switch (value) {
            .string => |string_value| string_value,
            else => {
                try ctx.addIssue(.invalid_type, "string", valueTypeName(value), "expected JSON string");
                return SchemaError.InvalidType;
            },
        };
        try self.validateDetailed(ctx, text);
        return text;
    }

    pub fn decodeConfigText(self: StringSchema, value: []const u8) SchemaError![]const u8 {
        try self.validateSimple(value);
        return value;
    }

    pub fn decodeDetailedConfigText(self: StringSchema, ctx: *ParseContext, value: []const u8) (SchemaError || std.mem.Allocator.Error)![]const u8 {
        try self.validateDetailed(ctx, value);
        return value;
    }

    pub fn appendJsonValue(self: StringSchema, allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) (SchemaError || std.mem.Allocator.Error)!void {
        try self.validateSimple(value);
        try appendJsonString(output, allocator, value);
    }

    fn validateSimple(self: StringSchema, value: []const u8) SchemaError!void {
        if (self.require_non_empty and value.len == 0) return SchemaError.InvalidValue;
        if (self.min_len) |min_len| if (value.len < min_len) return SchemaError.InvalidValue;
        if (self.max_len) |max_len| if (value.len > max_len) return SchemaError.InvalidValue;
        if (self.starts_with) |prefix| if (!std.mem.startsWith(u8, value, prefix)) return SchemaError.InvalidValue;
        if (self.ends_with) |suffix| if (!std.mem.endsWith(u8, value, suffix)) return SchemaError.InvalidValue;
        if (self.contains_text) |needle| if (std.mem.indexOf(u8, value, needle) == null) return SchemaError.InvalidValue;
    }

    fn validateDetailed(self: StringSchema, ctx: *ParseContext, value: []const u8) (SchemaError || std.mem.Allocator.Error)!void {
        var failed = false;
        if (self.require_non_empty and value.len == 0) {
            try ctx.addIssue(.constraint_failed, "non-empty string", value, "string must not be empty");
            failed = true;
        }
        if (self.min_len) |min_len| {
            if (value.len < min_len) {
                const expected = try std.fmt.allocPrint(ctx.allocator, "min length {d}", .{min_len});
                defer ctx.allocator.free(expected);
                try ctx.addIssue(.constraint_failed, expected, value, "string is shorter than minimum length");
                failed = true;
            }
        }
        if (self.max_len) |max_len| {
            if (value.len > max_len) {
                const expected = try std.fmt.allocPrint(ctx.allocator, "max length {d}", .{max_len});
                defer ctx.allocator.free(expected);
                try ctx.addIssue(.constraint_failed, expected, value, "string is longer than maximum length");
                failed = true;
            }
        }
        if (self.starts_with) |prefix| {
            if (!std.mem.startsWith(u8, value, prefix)) {
                try ctx.addIssue(.constraint_failed, prefix, value, "string must start with expected prefix");
                failed = true;
            }
        }
        if (self.ends_with) |suffix| {
            if (!std.mem.endsWith(u8, value, suffix)) {
                try ctx.addIssue(.constraint_failed, suffix, value, "string must end with expected suffix");
                failed = true;
            }
        }
        if (self.contains_text) |needle| {
            if (std.mem.indexOf(u8, value, needle) == null) {
                try ctx.addIssue(.constraint_failed, needle, value, "string must contain expected text");
                failed = true;
            }
        }
        if (failed) return SchemaError.InvalidValue;
    }
};

pub const IntegerSchema = struct {
    pub const Output = i64;

    min_value: ?i64 = null,
    max_value: ?i64 = null,

    pub fn min(self: IntegerSchema, value: i64) IntegerSchema {
        var next = self;
        next.min_value = value;
        return next;
    }

    pub fn max(self: IntegerSchema, value: i64) IntegerSchema {
        var next = self;
        next.max_value = value;
        return next;
    }

    pub fn decodeJsonValue(self: IntegerSchema, value: std.json.Value) SchemaError!i64 {
        const integer_value = switch (value) {
            .integer => |integer_value| integer_value,
            else => SchemaError.InvalidType,
        };
        try self.validateSimple(integer_value);
        return integer_value;
    }

    pub fn decodeDetailedJsonValue(self: IntegerSchema, ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!i64 {
        const integer_value = switch (value) {
            .integer => |parsed| parsed,
            else => {
                try ctx.addIssue(.invalid_type, "integer", valueTypeName(value), "expected JSON integer");
                return SchemaError.InvalidType;
            },
        };
        try self.validateDetailed(ctx, integer_value);
        return integer_value;
    }

    pub fn decodeConfigText(self: IntegerSchema, value: []const u8) SchemaError!i64 {
        const parsed = std.fmt.parseInt(i64, value, 10) catch return SchemaError.InvalidValue;
        try self.validateSimple(parsed);
        return parsed;
    }

    pub fn decodeDetailedConfigText(self: IntegerSchema, ctx: *ParseContext, value: []const u8) (SchemaError || std.mem.Allocator.Error)!i64 {
        const parsed = std.fmt.parseInt(i64, value, 10) catch {
            try ctx.addIssue(.invalid_value, "integer", value, "config value is not an integer");
            return SchemaError.InvalidValue;
        };
        try self.validateDetailed(ctx, parsed);
        return parsed;
    }

    pub fn appendJsonValue(self: IntegerSchema, allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: i64) (SchemaError || std.mem.Allocator.Error)!void {
        try self.validateSimple(value);
        try output.writer(allocator).print("{d}", .{value});
    }

    fn validateSimple(self: IntegerSchema, value: i64) SchemaError!void {
        if (self.min_value) |minimum| if (value < minimum) return SchemaError.InvalidValue;
        if (self.max_value) |maximum| if (value > maximum) return SchemaError.InvalidValue;
    }

    fn validateDetailed(self: IntegerSchema, ctx: *ParseContext, value: i64) (SchemaError || std.mem.Allocator.Error)!void {
        var failed = false;
        const actual = try std.fmt.allocPrint(ctx.allocator, "{d}", .{value});
        defer ctx.allocator.free(actual);

        if (self.min_value) |minimum| {
            if (value < minimum) {
                const expected = try std.fmt.allocPrint(ctx.allocator, ">= {d}", .{minimum});
                defer ctx.allocator.free(expected);
                try ctx.addIssue(.constraint_failed, expected, actual, "integer is below minimum");
                failed = true;
            }
        }
        if (self.max_value) |maximum| {
            if (value > maximum) {
                const expected = try std.fmt.allocPrint(ctx.allocator, "<= {d}", .{maximum});
                defer ctx.allocator.free(expected);
                try ctx.addIssue(.constraint_failed, expected, actual, "integer is above maximum");
                failed = true;
            }
        }
        if (failed) return SchemaError.InvalidValue;
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

    pub fn decodeDetailedJsonValue(_: BooleanSchema, ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!bool {
        return switch (value) {
            .bool => |bool_value| bool_value,
            else => {
                try ctx.addIssue(.invalid_type, "boolean", valueTypeName(value), "expected JSON boolean");
                return SchemaError.InvalidType;
            },
        };
    }

    pub fn decodeConfigText(_: BooleanSchema, value: []const u8) SchemaError!bool {
        if (std.mem.eql(u8, value, "true")) return true;
        if (std.mem.eql(u8, value, "false")) return false;
        return SchemaError.InvalidValue;
    }

    pub fn decodeDetailedConfigText(_: BooleanSchema, ctx: *ParseContext, value: []const u8) (SchemaError || std.mem.Allocator.Error)!bool {
        if (std.mem.eql(u8, value, "true")) return true;
        if (std.mem.eql(u8, value, "false")) return false;
        try ctx.addIssue(.invalid_value, "boolean", value, "config value must be true or false");
        return SchemaError.InvalidValue;
    }

    pub fn appendJsonValue(_: BooleanSchema, allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: bool) std.mem.Allocator.Error!void {
        try output.appendSlice(allocator, if (value) "true" else "false");
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

        pub fn decodeDetailedJsonValue(self: @This(), ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            return switch (value) {
                .null => null,
                else => try rootDecodeDetailedJsonValue(self.inner, ctx, value),
            };
        }

        pub fn decodeConfigText(self: @This(), value: []const u8) (SchemaError || std.mem.Allocator.Error)!Output {
            if (value.len == 0) return null;
            return try rootDecodeConfigText(self.inner, value);
        }

        pub fn decodeDetailedConfigText(self: @This(), ctx: *ParseContext, value: []const u8) (SchemaError || std.mem.Allocator.Error)!Output {
            if (value.len == 0) return null;
            return try rootDecodeDetailedConfigText(self.inner, ctx, value);
        }

        pub fn appendJsonValue(self: @This(), allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: Output) (SchemaError || std.mem.Allocator.Error)!void {
            if (value) |inner_value| {
                try rootAppendJsonValue(allocator, output, self.inner, inner_value);
            } else {
                try output.appendSlice(allocator, "null");
            }
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

        pub fn appendJsonValue(self: @This(), allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: Output) (SchemaError || std.mem.Allocator.Error)!void {
            try output.append(allocator, '[');
            for (value, 0..) |item, index| {
                if (index != 0) try output.append(allocator, ',');
                try rootAppendJsonValue(allocator, output, self.inner, item);
            }
            try output.append(allocator, ']');
        }

        pub fn decodeDetailedJsonValue(self: @This(), ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            const values = switch (value) {
                .array => |array_value| array_value.items,
                else => {
                    try ctx.addIssue(.invalid_type, "array", valueTypeName(value), "expected JSON array");
                    return SchemaError.InvalidType;
                },
            };
            const decoded = try self.allocator.alloc(Inner.Output, values.len);
            errdefer self.allocator.free(decoded);

            var failed = false;
            for (values, 0..) |item, index| {
                const mark_path = try ctx.pushIndex(index);
                defer ctx.popTo(mark_path);

                const before = ctx.issues.len();
                decoded[index] = rootDecodeDetailedJsonValue(self.inner, ctx, item) catch {
                    failed = true;
                    continue;
                };
                if (ctx.issues.len() > before) failed = true;
            }

            if (failed) {
                self.allocator.free(decoded);
                return SchemaError.InvalidValue;
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

        pub fn appendJsonValue(self: @This(), allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) (SchemaError || std.mem.Allocator.Error)!void {
            _ = try self.decodeJsonValue(.{ .string = value });
            try appendJsonString(output, allocator, value);
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

        pub fn appendJsonValue(_: @This(), _: std.mem.Allocator, _: *std.ArrayList(u8), _: Next) SchemaError!void {
            return SchemaError.InvalidValue;
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

pub fn TransformNamedSchema(
    comptime Inner: type,
    comptime Next: type,
    comptime mapper: *const fn (Inner.Output) SchemaError!Next,
    comptime encoder: *const fn (std.mem.Allocator, Next) anyerror!Inner.Output,
) type {
    return struct {
        pub const Output = Next;
        inner: Inner,
        name: []const u8,

        pub fn decodeJsonValue(self: @This(), value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Next {
            return mapper(try self.inner.decodeJsonValue(value)) catch SchemaError.TransformFailed;
        }

        pub fn decodeDetailedJsonValue(self: @This(), ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Next {
            const source = rootDecodeDetailedJsonValue(self.inner, ctx, value) catch |err| return err;
            return mapper(source) catch {
                try ctx.addIssue(.transform_failed, self.name, valueTypeName(value), "schema transform failed");
                return SchemaError.TransformFailed;
            };
        }

        pub fn decodeConfigText(self: @This(), value: []const u8) (SchemaError || std.mem.Allocator.Error)!Next {
            return mapper(try rootDecodeConfigText(self.inner, value)) catch SchemaError.TransformFailed;
        }

        pub fn appendJsonValue(self: @This(), allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: Next) (SchemaError || std.mem.Allocator.Error)!void {
            const inner_value = encoder(allocator, value) catch return SchemaError.TransformFailed;
            defer freeDecoded(allocator, inner_value);
            try rootAppendJsonValue(allocator, output, self.inner, inner_value);
        }
    };
}

pub fn transformNamed(
    schema: anytype,
    comptime Next: type,
    comptime name: []const u8,
    comptime mapper: *const fn (@TypeOf(schema).Output) SchemaError!Next,
    comptime encoder: *const fn (std.mem.Allocator, Next) anyerror!@TypeOf(schema).Output,
) TransformNamedSchema(@TypeOf(schema), Next, mapper, encoder) {
    return .{ .inner = schema, .name = name };
}

pub fn DefaultSchema(comptime Inner: type, comptime Default: type) type {
    return struct {
        pub const Output = Inner.Output;
        inner: Inner,
        value: Default,

        pub fn decodeJsonValue(self: @This(), value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            return try self.inner.decodeJsonValue(value);
        }

        pub fn decodeDetailedJsonValue(self: @This(), ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            return try rootDecodeDetailedJsonValue(self.inner, ctx, value);
        }

        pub fn decodeConfigText(self: @This(), value: []const u8) (SchemaError || std.mem.Allocator.Error)!Output {
            return try rootDecodeConfigText(self.inner, value);
        }

        pub fn decodeDetailedConfigText(self: @This(), ctx: *ParseContext, value: []const u8) (SchemaError || std.mem.Allocator.Error)!Output {
            return try rootDecodeDetailedConfigText(self.inner, ctx, value);
        }

        pub fn defaultValue(self: @This()) Output {
            return self.value;
        }

        pub fn appendJsonValue(self: @This(), allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: Output) (SchemaError || std.mem.Allocator.Error)!void {
            try rootAppendJsonValue(allocator, output, self.inner, value);
        }
    };
}

pub fn default(schema: anytype, value: anytype) DefaultSchema(@TypeOf(schema), @TypeOf(value)) {
    return .{ .inner = schema, .value = value };
}

pub fn freeDecoded(allocator: std.mem.Allocator, value: anytype) void {
    const Value = @TypeOf(value);
    switch (@typeInfo(Value)) {
        .pointer => |pointer| if (pointer.size == .slice) allocator.free(value),
        else => {},
    }
}

fn freeDetailedDecoded(allocator: std.mem.Allocator, value: anytype) void {
    const Value = @TypeOf(value);
    switch (@typeInfo(Value)) {
        .pointer => |pointer| {
            if (pointer.size == .slice and pointer.child != u8) {
                for (value) |item| freeDetailedDecoded(allocator, item);
                allocator.free(value);
            }
        },
        .optional => {
            if (value) |inner| freeDetailedDecoded(allocator, inner);
        },
        .@"struct" => |struct_info| {
            inline for (struct_info.fields) |field_info| {
                freeDetailedDecoded(allocator, @field(value, field_info.name));
            }
        },
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
                } else if (hasDefault(@TypeOf(field_spec.schema))) {
                    @field(output, Field.Name) = field_spec.schema.defaultValue();
                } else if (comptime isOptional(FieldOutput)) {
                    @field(output, Field.Name) = null;
                } else {
                    return SchemaError.MissingField;
                }
            }
            return output;
        }

        pub fn decodeDetailedJsonValue(self: @This(), ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            const object = switch (value) {
                .object => |object_value| object_value,
                else => {
                    try ctx.addIssue(.invalid_type, "object", valueTypeName(value), "expected JSON object");
                    return SchemaError.InvalidType;
                },
            };

            var output: StructOutput = undefined;
            var failed = false;
            inline for (self.fields) |field_spec| {
                const Field = @TypeOf(field_spec);
                const FieldOutput = Field.Schema.Output;
                {
                    const mark_path = try ctx.pushField(Field.Name);
                    defer ctx.popTo(mark_path);

                    if (object.get(Field.Name)) |field_value| {
                        const before = ctx.issues.len();
                        @field(output, Field.Name) = rootDecodeDetailedJsonValue(field_spec.schema, ctx, field_value) catch {
                            failed = true;
                            continue;
                        };
                        if (ctx.issues.len() > before) failed = true;
                    } else if (hasDefault(@TypeOf(field_spec.schema))) {
                        @field(output, Field.Name) = field_spec.schema.defaultValue();
                    } else if (comptime isOptional(FieldOutput)) {
                        @field(output, Field.Name) = null;
                    } else {
                        try ctx.addIssue(.missing_field, Field.Name, "missing", "required object field is missing");
                        failed = true;
                    }
                }
            }
            if (failed) return SchemaError.InvalidValue;
            return output;
        }

        pub fn appendJsonValue(self: @This(), allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: Output) (SchemaError || std.mem.Allocator.Error)!void {
            try output.append(allocator, '{');
            inline for (self.fields, 0..) |field_spec, index| {
                const Field = @TypeOf(field_spec);
                if (index != 0) try output.append(allocator, ',');
                try appendJsonString(output, allocator, Field.Name);
                try output.append(allocator, ':');
                try rootAppendJsonValue(allocator, output, field_spec.schema, @field(value, Field.Name));
            }
            try output.append(allocator, '}');
        }
    };
}

pub fn structSchema(comptime Output: type, fields: anytype) StructSchema(Output, @TypeOf(fields)) {
    return .{ .fields = fields };
}

pub fn DerivedSchema(comptime StructOutput: type, comptime Overrides: type) type {
    return struct {
        pub const Output = StructOutput;
        overrides: Overrides,

        pub fn decodeJsonValue(self: @This(), value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            const object = switch (value) {
                .object => |object_value| object_value,
                else => return SchemaError.InvalidType,
            };

            var output: StructOutput = undefined;
            const output_info = @typeInfo(StructOutput).@"struct";
            inline for (output_info.fields) |field_info| {
                if (object.get(field_info.name)) |field_value| {
                    if (@hasField(Overrides, field_info.name)) {
                        const field_schema = @field(self.overrides, field_info.name);
                        @field(output, field_info.name) = try field_schema.decodeJsonValue(field_value);
                    } else {
                        @field(output, field_info.name) = try decodeInferredJsonValue(field_info.type, field_value);
                    }
                } else if (comptime overrideHasDefault(Overrides, field_info.name)) {
                    @field(output, field_info.name) = @field(self.overrides, field_info.name).defaultValue();
                } else if (comptime isOptional(field_info.type)) {
                    @field(output, field_info.name) = null;
                } else {
                    return SchemaError.MissingField;
                }
            }
            return output;
        }

        pub fn decodeDetailedJsonValue(self: @This(), ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            const object = switch (value) {
                .object => |object_value| object_value,
                else => {
                    try ctx.addIssue(.invalid_type, "object", valueTypeName(value), "expected JSON object");
                    return SchemaError.InvalidType;
                },
            };

            var output: StructOutput = undefined;
            var failed = false;
            const output_info = @typeInfo(StructOutput).@"struct";
            inline for (output_info.fields) |field_info| {
                {
                    const mark_path = try ctx.pushField(field_info.name);
                    defer ctx.popTo(mark_path);

                    if (object.get(field_info.name)) |field_value| {
                        const before = ctx.issues.len();
                        field_decode: {
                            if (@hasField(Overrides, field_info.name)) {
                                const field_schema = @field(self.overrides, field_info.name);
                                const decoded = rootDecodeDetailedJsonValue(field_schema, ctx, field_value) catch {
                                    failed = true;
                                    break :field_decode;
                                };
                                @field(output, field_info.name) = decoded;
                            } else {
                                const decoded = decodeInferredDetailedJsonValue(field_info.type, ctx, field_value) catch {
                                    failed = true;
                                    break :field_decode;
                                };
                                @field(output, field_info.name) = decoded;
                            }
                            if (ctx.issues.len() > before) {
                                failed = true;
                            }
                        }
                    } else if (comptime overrideHasDefault(Overrides, field_info.name)) {
                        @field(output, field_info.name) = @field(self.overrides, field_info.name).defaultValue();
                    } else if (comptime isOptional(field_info.type)) {
                        @field(output, field_info.name) = null;
                    } else {
                        try ctx.addIssue(.missing_field, field_info.name, "missing", "required object field is missing");
                        failed = true;
                    }
                }
            }
            if (failed) return SchemaError.InvalidValue;
            return output;
        }

        pub fn appendJsonValue(self: @This(), allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: Output) (SchemaError || std.mem.Allocator.Error)!void {
            try output.append(allocator, '{');
            const output_info = @typeInfo(StructOutput).@"struct";
            inline for (output_info.fields, 0..) |field_info, index| {
                if (index != 0) try output.append(allocator, ',');
                try appendJsonString(output, allocator, field_info.name);
                try output.append(allocator, ':');
                if (@hasField(Overrides, field_info.name)) {
                    const field_schema = @field(self.overrides, field_info.name);
                    try rootAppendJsonValue(allocator, output, field_schema, @field(value, field_info.name));
                } else {
                    try appendInferredJsonValue(field_info.type, allocator, output, @field(value, field_info.name));
                }
            }
            try output.append(allocator, '}');
        }
    };
}

pub fn derive(comptime Output: type, overrides: anytype) DerivedSchema(Output, @TypeOf(overrides)) {
    return .{ .overrides = overrides };
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

pub fn decodeDetailedJsonAlloc(
    allocator: std.mem.Allocator,
    schema: anytype,
    json: []const u8,
) !DecodeResult(@TypeOf(schema).Output) {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
    var issues = IssueList.init(allocator);
    errdefer issues.deinit();

    var ctx = ParseContext.init(allocator, &issues);
    defer ctx.deinit();

    const decoded = rootDecodeDetailedJsonValue(schema, &ctx, parsed.value) catch |err| {
        if (issues.len() > 0) {
            parsed.deinit();
            return .{
                .allocator = allocator,
                .value = null,
                .issues = issues,
            };
        }
        parsed.deinit();
        return err;
    };

    if (issues.len() > 0) {
        parsed.deinit();
        return .{
            .allocator = allocator,
            .value = null,
            .issues = issues,
        };
    }

    return .{
        .allocator = allocator,
        .value = decoded,
        .issues = issues,
        .parsed = parsed,
    };
}

pub fn encodeJsonAlloc(
    allocator: std.mem.Allocator,
    schema: anytype,
    value: @TypeOf(schema).Output,
) (SchemaError || std.mem.Allocator.Error)![]const u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try rootAppendJsonValue(allocator, &output, schema, value);
    return output.toOwnedSlice(allocator);
}

pub fn decodeDetailedConfig(
    allocator: std.mem.Allocator,
    config: anytype,
    key: []const u8,
    schema: anytype,
) !DecodeResult(@TypeOf(schema).Output) {
    var issues = IssueList.init(allocator);
    errdefer issues.deinit();

    var ctx = ParseContext.init(allocator, &issues);
    defer ctx.deinit();
    try ctx.path.appendSlice(allocator, key);

    const text = config.require(key) catch {
        try ctx.addIssue(.missing_field, key, "missing", "required config key is missing");
        return .{
            .allocator = allocator,
            .value = null,
            .issues = issues,
        };
    };

    const decoded = rootDecodeDetailedConfigText(schema, &ctx, text) catch |err| {
        if (issues.len() > 0) {
            return .{
                .allocator = allocator,
                .value = null,
                .issues = issues,
            };
        }
        return err;
    };

    if (issues.len() > 0) {
        return .{
            .allocator = allocator,
            .value = null,
            .issues = issues,
        };
    }

    return .{
        .allocator = allocator,
        .value = decoded,
        .issues = issues,
    };
}

pub fn decodeConfig(config: anytype, comptime key: []const u8, schema: anytype) !@TypeOf(schema).Output {
    const text = config.require(key) catch {
        if (comptime isOptional(@TypeOf(schema).Output)) return null;
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

fn rootDecodeDetailedConfigText(
    schema: anytype,
    ctx: *ParseContext,
    value: []const u8,
) (SchemaError || std.mem.Allocator.Error)!@TypeOf(schema).Output {
    if (@hasDecl(@TypeOf(schema), "decodeDetailedConfigText")) {
        return schema.decodeDetailedConfigText(ctx, value);
    }

    return rootDecodeConfigText(schema, value) catch |err| {
        try ctx.addIssue(schemaErrorIssueKind(err), "valid config value", value, @errorName(err));
        return err;
    };
}

fn rootDecodeDetailedJsonValue(
    schema: anytype,
    ctx: *ParseContext,
    value: std.json.Value,
) (SchemaError || std.mem.Allocator.Error)!@TypeOf(schema).Output {
    if (@hasDecl(@TypeOf(schema), "decodeDetailedJsonValue")) {
        return schema.decodeDetailedJsonValue(ctx, value);
    }

    return schema.decodeJsonValue(value) catch |err| {
        try ctx.addIssue(schemaErrorIssueKind(err), "valid value", valueTypeName(value), @errorName(err));
        return err;
    };
}

fn decodeInferredJsonValue(comptime T: type, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!T {
    return switch (@typeInfo(T)) {
        .bool => switch (value) {
            .bool => |bool_value| bool_value,
            else => SchemaError.InvalidType,
        },
        .int => switch (value) {
            .integer => |integer_value| std.math.cast(T, integer_value) orelse SchemaError.InvalidValue,
            else => SchemaError.InvalidType,
        },
        .optional => |optional_info| switch (value) {
            .null => null,
            else => try decodeInferredJsonValue(optional_info.child, value),
        },
        .pointer => |pointer_info| switch (pointer_info.size) {
            .slice => if (pointer_info.child == u8) switch (value) {
                .string => |string_value| string_value,
                else => SchemaError.InvalidType,
            } else SchemaError.InvalidType,
            else => SchemaError.InvalidType,
        },
        else => SchemaError.InvalidType,
    };
}

fn decodeInferredDetailedJsonValue(comptime T: type, ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!T {
    return decodeInferredJsonValue(T, value) catch |err| {
        try ctx.addIssue(schemaErrorIssueKind(err), inferredExpectedName(T), valueTypeName(value), @errorName(err));
        return err;
    };
}

fn appendInferredJsonValue(
    comptime T: type,
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: T,
) (SchemaError || std.mem.Allocator.Error)!void {
    switch (@typeInfo(T)) {
        .bool => try output.appendSlice(allocator, if (value) "true" else "false"),
        .int => try output.writer(allocator).print("{d}", .{value}),
        .optional => |optional_info| {
            if (value) |inner| {
                try appendInferredJsonValue(optional_info.child, allocator, output, inner);
            } else {
                try output.appendSlice(allocator, "null");
            }
        },
        .pointer => |pointer_info| switch (pointer_info.size) {
            .slice => if (pointer_info.child == u8) {
                try appendJsonString(output, allocator, value);
            } else return SchemaError.InvalidValue,
            else => return SchemaError.InvalidValue,
        },
        else => return SchemaError.InvalidValue,
    }
}

fn inferredExpectedName(comptime T: type) []const u8 {
    return switch (@typeInfo(T)) {
        .bool => "boolean",
        .int => "integer",
        .optional => |optional_info| inferredExpectedName(optional_info.child),
        .pointer => |pointer_info| switch (pointer_info.size) {
            .slice => if (pointer_info.child == u8) "string" else "slice",
            else => "pointer",
        },
        else => @typeName(T),
    };
}

fn rootAppendJsonValue(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    schema: anytype,
    value: @TypeOf(schema).Output,
) (SchemaError || std.mem.Allocator.Error)!void {
    if (@hasDecl(@TypeOf(schema), "appendJsonValue")) {
        try schema.appendJsonValue(allocator, output, value);
        return;
    }
    return SchemaError.InvalidValue;
}

fn isOptional(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .optional => true,
        else => false,
    };
}

fn hasDefault(comptime T: type) bool {
    return @hasDecl(T, "defaultValue");
}

fn overrideHasDefault(comptime Overrides: type, comptime field_name: []const u8) bool {
    if (!@hasField(Overrides, field_name)) return false;
    return hasDefault(overrideTypeForField(Overrides, field_name));
}

fn overrideTypeForField(comptime Overrides: type, comptime field_name: []const u8) type {
    inline for (@typeInfo(Overrides).@"struct".fields) |field_info| {
        if (comptime std.mem.eql(u8, field_info.name, field_name)) return field_info.type;
    }
    @compileError("schema override missing for field: " ++ field_name);
}

fn valueTypeName(value: std.json.Value) []const u8 {
    return switch (value) {
        .null => "null",
        .bool => "boolean",
        .integer => "integer",
        .float => "float",
        .number_string => "number",
        .string => "string",
        .array => "array",
        .object => "object",
    };
}

fn schemaErrorIssueKind(err: SchemaError) IssueKind {
    return switch (err) {
        SchemaError.InvalidType => .invalid_type,
        SchemaError.MissingField => .missing_field,
        SchemaError.InvalidValue => .invalid_value,
        SchemaError.UnknownEnum => .unknown_enum,
        SchemaError.TransformFailed => .transform_failed,
    };
}

fn issueKindName(kind: IssueKind) []const u8 {
    return switch (kind) {
        .invalid_type => "invalid_type",
        .missing_field => "missing_field",
        .invalid_value => "invalid_value",
        .unknown_enum => "unknown_enum",
        .constraint_failed => "constraint_failed",
        .transform_failed => "transform_failed",
        .encode_failed => "encode_failed",
    };
}

fn issueKindError(kind: IssueKind) SchemaError {
    return switch (kind) {
        .invalid_type => SchemaError.InvalidType,
        .missing_field => SchemaError.MissingField,
        .invalid_value => SchemaError.InvalidValue,
        .unknown_enum => SchemaError.UnknownEnum,
        .constraint_failed => SchemaError.InvalidValue,
        .transform_failed => SchemaError.TransformFailed,
        .encode_failed => SchemaError.InvalidValue,
    };
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) std.mem.Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |char| {
        switch (char) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            else => try output.append(allocator, char),
        }
    }
    try output.append(allocator, '"');
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

test "Schema IssueList owns issues and renders redacted deterministic JSON" {
    var issues = IssueList.init(std.testing.allocator);
    defer issues.deinit();

    try issues.add(.{
        .path = "$.database.url",
        .kind = .invalid_value,
        .expected = "safe connection string",
        .actual = "postgres://user:pass@localhost/db",
        .message = "bad password=abc123",
    });

    const json = try issues.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);

    try std.testing.expectEqual(@as(usize, 1), issues.len());
    try std.testing.expect(std.mem.indexOf(u8, json, "\"path\":\"$.database.url\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "pass") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "[REDACTED]") != null);
}

test "Schema ParseContext records nested object and array paths" {
    var issues = IssueList.init(std.testing.allocator);
    defer issues.deinit();
    var ctx = ParseContext.init(std.testing.allocator, &issues);
    defer ctx.deinit();

    try ctx.pushField("agents");
    try ctx.pushIndex(2);
    try ctx.pushField("command");
    try ctx.addIssue(.invalid_type, "string", "42", "agent command must be a string");

    try std.testing.expectEqualStrings("$.agents[2].command", issues.items[0].path);
}

test "Schema detailed primitive decode reports all constraint issues with paths" {
    const schema = string().nonEmpty().minLen(4).contains("@");
    var result = try decodeDetailedJsonAlloc(std.testing.allocator, schema, "\"\"");
    defer result.deinit();

    try std.testing.expect(!result.ok());
    try std.testing.expectEqual(@as(usize, 3), result.issues.len());
    try std.testing.expectEqualStrings("$", result.issues.items[0].path);
    try std.testing.expectEqual(IssueKind.constraint_failed, result.issues.items[0].kind);
}

test "Schema integer constraints support min max and simple decode compatibility" {
    const schema = integer().min(1).max(10);
    var invalid = try decodeDetailedJsonAlloc(std.testing.allocator, schema, "42");
    defer invalid.deinit();

    try std.testing.expect(!invalid.ok());
    try std.testing.expectEqual(IssueKind.constraint_failed, invalid.issues.items[0].kind);

    try std.testing.expectEqual(@as(i64, 7), try decodeJsonAlloc(std.testing.allocator, schema, "7"));
    try std.testing.expectError(SchemaError.InvalidValue, decodeJsonAlloc(std.testing.allocator, schema, "42"));
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

fn parsePortText(value: []const u8) SchemaError!u16 {
    const parsed = std.fmt.parseInt(u16, value, 10) catch return SchemaError.InvalidValue;
    if (parsed == 0) return SchemaError.InvalidValue;
    return parsed;
}

fn formatPortText(allocator: std.mem.Allocator, value: u16) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{value});
}

test "Schema decodes enum choices and transform schemas" {
    const mode_schema = stringEnum(&.{ "local", "ci" });
    try std.testing.expectEqualStrings("local", try decodeJsonValue(mode_schema, .{ .string = "local" }));
    try std.testing.expectError(SchemaError.UnknownEnum, decodeJsonValue(mode_schema, .{ .string = "prod" }));

    const length_schema = transform(string(), usize, stringLength);
    try std.testing.expectEqual(@as(usize, 4), try decodeJsonValue(length_schema, .{ .string = "test" }));
}

test "Schema encodes primitives arrays structs and defaults deterministically" {
    const schema = structSchema(ProductionDatabaseConfig, .{
        field("host", string().nonEmpty()),
        field("port", integer().min(1).max(65535)),
        field("pool", default(integer().min(1), 4)),
    });
    const json = try encodeJsonAlloc(std.testing.allocator, schema, .{
        .host = "localhost",
        .port = 5432,
        .pool = 8,
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"host\":\"localhost\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"port\":5432") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"pool\":8") != null);
}

test "Schema named transforms decode and encode when inverse is provided" {
    const schema = transformNamed(string(), u16, "port", parsePortText, formatPortText);
    try std.testing.expectEqual(@as(u16, 5178), try decodeJsonAlloc(std.testing.allocator, schema, "\"5178\""));

    const json = try encodeJsonAlloc(std.testing.allocator, schema, @as(u16, 5178));
    defer std.testing.allocator.free(json);
    try std.testing.expectEqualStrings("\"5178\"", json);
}

const AppConfig = struct {
    name: []const u8,
    port: i64,
    enabled: bool,
    mode: ?[]const u8,
};

const ProductionDatabaseConfig = struct {
    host: []const u8,
    port: i64,
    pool: i64,
};

const ProductionAppConfig = struct {
    name: []const u8,
    database: ProductionDatabaseConfig,
    agents: []const []const u8,
};

const DerivedSchemaConfig = struct {
    name: []const u8,
    port: i64,
    enabled: bool,
    mode: ?[]const u8,
};

fn expectIssuePath(issues: IssueList, path: []const u8, kind: IssueKind) !void {
    for (issues.items.items) |issue| {
        if (std.mem.eql(u8, issue.path, path) and issue.kind == kind) return;
    }
    std.debug.print("missing issue path={s} kind={s}\n", .{ path, issueKindName(kind) });
    return error.TestExpectedEqual;
}

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

test "Schema detailed struct decode accumulates nested object and array issues" {
    const database_schema = structSchema(ProductionDatabaseConfig, .{
        field("host", string().nonEmpty()),
        field("port", integer().min(1).max(65535)),
        field("pool", default(integer().min(1), 4)),
    });
    const schema = structSchema(ProductionAppConfig, .{
        field("name", string().nonEmpty()),
        field("database", database_schema),
        field("agents", array(std.testing.allocator, string().nonEmpty())),
    });

    var result = try decodeDetailedJsonAlloc(std.testing.allocator, schema,
        \\{"name":"","database":{"port":70000,"pool":0},"agents":["codex","",42]}
    );
    defer result.deinit();

    try std.testing.expect(!result.ok());
    try expectIssuePath(result.issues, "$.name", .constraint_failed);
    try expectIssuePath(result.issues, "$.database.host", .missing_field);
    try expectIssuePath(result.issues, "$.database.port", .constraint_failed);
    try expectIssuePath(result.issues, "$.database.pool", .constraint_failed);
    try expectIssuePath(result.issues, "$.agents[1]", .constraint_failed);
    try expectIssuePath(result.issues, "$.agents[2]", .invalid_type);
}

test "Schema defaults apply to missing fields but not invalid provided values" {
    const schema = structSchema(ProductionDatabaseConfig, .{
        field("host", string().nonEmpty()),
        field("port", integer().min(1).max(65535)),
        field("pool", default(integer().min(1), 4)),
    });

    const decoded = try decodeJsonAlloc(std.testing.allocator, schema,
        \\{"host":"localhost","port":5432}
    );
    try std.testing.expectEqual(@as(i64, 4), decoded.pool);

    var invalid = try decodeDetailedJsonAlloc(std.testing.allocator, schema,
        \\{"host":"localhost","port":5432,"pool":0}
    );
    defer invalid.deinit();
    try std.testing.expect(!invalid.ok());
    try expectIssuePath(invalid.issues, "$.pool", .constraint_failed);
}

test "Schema derive decodes common Zig structs with overrides" {
    const schema = derive(DerivedSchemaConfig, .{
        .name = string().nonEmpty(),
        .port = integer().min(1).max(65535),
        .enabled = boolean(),
        .mode = optional(stringEnum(&.{ "local", "ci" })),
    });

    const decoded = try decodeJsonAlloc(std.testing.allocator, schema,
        \\{"name":"local","port":5178,"enabled":true,"mode":"ci"}
    );

    try std.testing.expectEqualStrings("local", decoded.name);
    try std.testing.expectEqual(@as(i64, 5178), decoded.port);
    try std.testing.expectEqual(true, decoded.enabled);
    try std.testing.expectEqualStrings("ci", decoded.mode.?);
}

test "Schema detailed config decode reports missing and invalid keys" {
    var config = @import("../config/root.zig").LayeredConfig.init(std.testing.allocator);
    defer config.deinit();
    try config.put("HTTP_PORT", "99999", false);

    var result = try decodeDetailedConfig(std.testing.allocator, config, "HTTP_PORT", integer().min(1).max(65535));
    defer result.deinit();
    try std.testing.expect(!result.ok());
    try expectIssuePath(result.issues, "HTTP_PORT", .constraint_failed);

    var missing = try decodeDetailedConfig(std.testing.allocator, config, "DATABASE_URL", string().nonEmpty());
    defer missing.deinit();
    try std.testing.expect(!missing.ok());
    try expectIssuePath(missing.issues, "DATABASE_URL", .missing_field);
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
