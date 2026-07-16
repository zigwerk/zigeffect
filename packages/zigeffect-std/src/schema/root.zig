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
        const segment = try std.fmt.allocPrint(self.allocator, "[{d}]", .{index});
        defer self.allocator.free(segment);
        try self.path.appendSlice(self.allocator, segment);
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
    pub const generator_kind = "string";

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
            else => return SchemaError.InvalidType,
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
    pub const generator_kind = "integer";

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
            else => return SchemaError.InvalidType,
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
        try output.print(allocator, "{d}", .{value});
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
    pub const generator_kind = "boolean";

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

pub const FloatSchema = struct {
    pub const Output = f64;
    pub const generator_kind = "float";
    min_value: ?f64 = null,
    max_value: ?f64 = null,
    finite_only: bool = true,
    pub fn min(self: FloatSchema, value: f64) FloatSchema {
        var next = self;
        next.min_value = value;
        return next;
    }
    pub fn max(self: FloatSchema, value: f64) FloatSchema {
        var next = self;
        next.max_value = value;
        return next;
    }
    fn validate(self: FloatSchema, value: f64) SchemaError!void {
        if (self.finite_only and !std.math.isFinite(value)) return error.InvalidValue;
        if (self.min_value) |minimum| if (value < minimum) return error.InvalidValue;
        if (self.max_value) |maximum| if (value > maximum) return error.InvalidValue;
    }
    pub fn decodeJsonValue(self: FloatSchema, value: std.json.Value) SchemaError!f64 {
        const result: f64 = switch (value) {
            .float => |item| item,
            .integer => |item| @floatFromInt(item),
            .number_string => |item| std.fmt.parseFloat(f64, item) catch return error.InvalidValue,
            else => return error.InvalidType,
        };
        try self.validate(result);
        return result;
    }
    pub fn decodeDetailedJsonValue(self: FloatSchema, ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!f64 {
        const result = self.decodeJsonValue(value) catch |err| {
            try ctx.addIssue(schemaErrorIssueKind(err), "finite number", valueTypeName(value), "expected a bounded floating-point number");
            return err;
        };
        return result;
    }
    pub fn decodeConfigText(self: FloatSchema, value: []const u8) SchemaError!f64 {
        const result = std.fmt.parseFloat(f64, value) catch return error.InvalidValue;
        try self.validate(result);
        return result;
    }
    pub fn appendJsonValue(self: FloatSchema, allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: f64) (SchemaError || std.mem.Allocator.Error)!void {
        try self.validate(value);
        try output.print(allocator, "{d}", .{value});
    }
};

pub const DecimalSchema = struct {
    pub const Output = []const u8;
    pub const generator_kind = "decimal";
    max_digits: usize = 38,
    max_scale: usize = 18,
    fn validate(self: DecimalSchema, value: []const u8) SchemaError!void {
        if (value.len == 0 or value.len > self.max_digits + 2) return error.InvalidValue;
        var digits: usize = 0;
        var scale: usize = 0;
        var decimal_seen = false;
        for (value, 0..) |byte, index| {
            if (byte == '-' and index == 0) continue;
            if (byte == '.' and !decimal_seen) {
                decimal_seen = true;
                continue;
            }
            if (!std.ascii.isDigit(byte)) return error.InvalidValue;
            digits += 1;
            if (decimal_seen) scale += 1;
        }
        if (digits == 0 or digits > self.max_digits or scale > self.max_scale) return error.InvalidValue;
    }
    pub fn decodeJsonValue(self: DecimalSchema, value: std.json.Value) SchemaError![]const u8 {
        const text = switch (value) {
            .string, .number_string => |item| item,
            else => return error.InvalidType,
        };
        try self.validate(text);
        return text;
    }
    pub fn decodeDetailedJsonValue(self: DecimalSchema, ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)![]const u8 {
        return self.decodeJsonValue(value) catch |err| {
            try ctx.addIssue(schemaErrorIssueKind(err), "decimal string", valueTypeName(value), "decimal precision or scale is invalid");
            return err;
        };
    }
    pub fn decodeConfigText(self: DecimalSchema, value: []const u8) SchemaError![]const u8 {
        try self.validate(value);
        return value;
    }
    pub fn appendJsonValue(self: DecimalSchema, allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) (SchemaError || std.mem.Allocator.Error)!void {
        try self.validate(value);
        try appendJsonString(output, allocator, value);
    }
};

pub const BytesSchema = struct {
    pub const Output = []const u8;
    pub const generator_kind = "bytes";
    max_bytes: usize = 1024 * 1024,
    fn validate(self: BytesSchema, encoded: []const u8) SchemaError!void {
        const decoded = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch return error.InvalidValue;
        if (decoded > self.max_bytes) return error.InvalidValue;
    }
    pub fn decodeJsonValue(self: BytesSchema, value: std.json.Value) SchemaError![]const u8 {
        const text = switch (value) {
            .string => |item| item,
            else => return error.InvalidType,
        };
        try self.validate(text);
        return text;
    }
    pub fn decodeDetailedJsonValue(self: BytesSchema, ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)![]const u8 {
        return self.decodeJsonValue(value) catch |err| {
            try ctx.addIssue(schemaErrorIssueKind(err), "base64 bytes", valueTypeName(value), "invalid or oversized base64 data");
            return err;
        };
    }
    pub fn decodeConfigText(self: BytesSchema, value: []const u8) SchemaError![]const u8 {
        try self.validate(value);
        return value;
    }
    pub fn appendJsonValue(self: BytesSchema, allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) (SchemaError || std.mem.Allocator.Error)!void {
        try self.validate(value);
        try appendJsonString(output, allocator, value);
    }
    pub fn decodeBytesAlloc(self: BytesSchema, allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
        try self.validate(encoded);
        const size = try std.base64.standard.Decoder.calcSizeForSlice(encoded);
        const output = try allocator.alloc(u8, size);
        errdefer allocator.free(output);
        try std.base64.standard.Decoder.decode(output, encoded);
        return output;
    }
};

pub const TimeUnit = enum { milliseconds, nanoseconds };
pub const TimeSchema = struct {
    pub const Output = i64;
    pub const generator_kind = "time";
    semantic: enum { timestamp, duration },
    unit: TimeUnit = .milliseconds,
    allow_negative: bool = false,
    pub fn decodeJsonValue(self: TimeSchema, value: std.json.Value) SchemaError!i64 {
        const result = switch (value) {
            .integer => |item| item,
            else => return error.InvalidType,
        };
        if (!self.allow_negative and result < 0) return error.InvalidValue;
        return result;
    }
    pub fn decodeDetailedJsonValue(self: TimeSchema, ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!i64 {
        return self.decodeJsonValue(value) catch |err| {
            try ctx.addIssue(schemaErrorIssueKind(err), @tagName(self.semantic), valueTypeName(value), "invalid timestamp or duration");
            return err;
        };
    }
    pub fn decodeConfigText(self: TimeSchema, value: []const u8) SchemaError!i64 {
        const parsed = std.fmt.parseInt(i64, value, 10) catch return error.InvalidValue;
        return self.decodeJsonValue(.{ .integer = parsed });
    }
    pub fn appendJsonValue(self: TimeSchema, allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: i64) (SchemaError || std.mem.Allocator.Error)!void {
        _ = try self.decodeJsonValue(.{ .integer = value });
        try output.print(allocator, "{d}", .{value});
    }
};

pub fn LiteralSchema(comptime literal_value: []const u8) type {
    return struct {
        pub const Output = []const u8;
        pub const generator_kind = "literal";
        pub const literal = literal_value;
        pub fn decodeJsonValue(_: @This(), value: std.json.Value) SchemaError![]const u8 {
            const text = switch (value) {
                .string => |item| item,
                else => return error.InvalidType,
            };
            if (!std.mem.eql(u8, text, literal_value)) return error.InvalidValue;
            return text;
        }
        pub fn appendJsonValue(self: @This(), allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) (SchemaError || std.mem.Allocator.Error)!void {
            _ = try self.decodeJsonValue(.{ .string = value });
            try appendJsonString(output, allocator, value);
        }
    };
}

pub fn RefinementSchema(comptime Inner: type, comptime predicate: *const fn (Inner.Output) bool, comptime description: []const u8) type {
    return struct {
        pub const Output = Inner.Output;
        pub const generator_kind = "refinement";
        inner: Inner,
        pub fn accepts(_: @This(), value: Output) bool {
            return predicate(value);
        }
        pub fn decodeJsonValue(self: @This(), value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            const decoded = try self.inner.decodeJsonValue(value);
            if (!predicate(decoded)) return error.InvalidValue;
            return decoded;
        }
        pub fn decodeDetailedJsonValue(self: @This(), ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            const decoded = try rootDecodeDetailedJsonValue(self.inner, ctx, value);
            if (!predicate(decoded)) {
                try ctx.addIssue(.constraint_failed, description, valueTypeName(value), "refinement predicate rejected value");
                return error.InvalidValue;
            }
            return decoded;
        }
        pub fn appendJsonValue(self: @This(), allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: Output) (SchemaError || std.mem.Allocator.Error)!void {
            if (!predicate(value)) return error.InvalidValue;
            try rootAppendJsonValue(allocator, output, self.inner, value);
        }
    };
}

pub fn BrandSchema(comptime Inner: type, comptime brand_name: []const u8) type {
    return struct {
        pub const Output = Inner.Output;
        pub const generator_kind = "brand";
        pub const brand = brand_name;
        inner: Inner,
        pub fn decodeJsonValue(self: @This(), value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            return self.inner.decodeJsonValue(value);
        }
        pub fn appendJsonValue(self: @This(), allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: Output) (SchemaError || std.mem.Allocator.Error)!void {
            try rootAppendJsonValue(allocator, output, self.inner, value);
        }
    };
}

pub fn string() StringSchema {
    return .{};
}

pub fn integer() IntegerSchema {
    return .{};
}

pub fn boolean() BooleanSchema {
    return .{};
}

pub fn float() FloatSchema {
    return .{};
}
pub fn decimal() DecimalSchema {
    return .{};
}
pub fn bytes() BytesSchema {
    return .{};
}
pub fn timestampMillis() TimeSchema {
    return .{ .semantic = .timestamp };
}
pub fn durationMillis() TimeSchema {
    return .{ .semantic = .duration };
}
pub fn literal(comptime value: []const u8) LiteralSchema(value) {
    return .{};
}
pub fn refine(schema: anytype, comptime description: []const u8, comptime predicate: *const fn (@TypeOf(schema).Output) bool) RefinementSchema(@TypeOf(schema), predicate, description) {
    return .{ .inner = schema };
}
pub fn brand(schema: anytype, comptime name: []const u8) BrandSchema(@TypeOf(schema), name) {
    return .{ .inner = schema };
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
        pub const generator_kind = "optional";
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
        pub const generator_kind = "array";
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
                return SchemaError.InvalidValue;
            }
            return decoded;
        }
    };
}

pub fn array(allocator: std.mem.Allocator, schema: anytype) ArraySchema(@TypeOf(schema)) {
    return .{ .allocator = allocator, .inner = schema };
}

pub fn Tuple2Schema(comptime First: type, comptime Second: type) type {
    return struct {
        pub const Output = struct { first: First.Output, second: Second.Output };
        pub const generator_kind = "tuple";
        first: First,
        second: Second,
        pub fn decodeJsonValue(self: @This(), value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            const items = switch (value) {
                .array => |array_value| array_value.items,
                else => return error.InvalidType,
            };
            if (items.len != 2) return error.InvalidValue;
            return .{ .first = try self.first.decodeJsonValue(items[0]), .second = try self.second.decodeJsonValue(items[1]) };
        }
        pub fn decodeDetailedJsonValue(self: @This(), ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            const items = switch (value) {
                .array => |array_value| array_value.items,
                else => {
                    try ctx.addIssue(.invalid_type, "tuple[2]", valueTypeName(value), "expected two-item JSON array");
                    return error.InvalidType;
                },
            };
            if (items.len != 2) {
                try ctx.addIssue(.invalid_value, "tuple[2]", "array", "tuple length must be exactly two");
                return error.InvalidValue;
            }
            const first_mark = try ctx.pushIndex(0);
            const first_value = rootDecodeDetailedJsonValue(self.first, ctx, items[0]) catch |err| {
                ctx.popTo(first_mark);
                return err;
            };
            ctx.popTo(first_mark);
            const second_mark = try ctx.pushIndex(1);
            defer ctx.popTo(second_mark);
            return .{ .first = first_value, .second = try rootDecodeDetailedJsonValue(self.second, ctx, items[1]) };
        }
        pub fn appendJsonValue(self: @This(), allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: Output) (SchemaError || std.mem.Allocator.Error)!void {
            try output.append(allocator, '[');
            try rootAppendJsonValue(allocator, output, self.first, value.first);
            try output.append(allocator, ',');
            try rootAppendJsonValue(allocator, output, self.second, value.second);
            try output.append(allocator, ']');
        }
    };
}
pub fn tuple2(first: anytype, second: anytype) Tuple2Schema(@TypeOf(first), @TypeOf(second)) {
    return .{ .first = first, .second = second };
}

pub fn TaggedUnion2Schema(comptime First: type, comptime Second: type, comptime first_tag: []const u8, comptime second_tag: []const u8) type {
    return struct {
        pub const Output = union(enum) { first: First.Output, second: Second.Output };
        pub const generator_kind = "tagged_union";
        first: First,
        second: Second,
        pub fn decodeJsonValue(self: @This(), value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            const object = switch (value) {
                .object => |item| item,
                else => return error.InvalidType,
            };
            const tag = switch (object.get("tag") orelse return error.MissingField) {
                .string => |item| item,
                else => return error.InvalidType,
            };
            const payload = object.get("value") orelse return error.MissingField;
            if (std.mem.eql(u8, tag, first_tag)) return .{ .first = try self.first.decodeJsonValue(payload) };
            if (std.mem.eql(u8, tag, second_tag)) return .{ .second = try self.second.decodeJsonValue(payload) };
            return error.UnknownEnum;
        }
        pub fn decodeDetailedJsonValue(self: @This(), ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            return self.decodeJsonValue(value) catch |err| {
                try ctx.addIssue(schemaErrorIssueKind(err), "known tagged-union variant", valueTypeName(value), "invalid tagged union discriminator or payload");
                return err;
            };
        }
        pub fn appendJsonValue(self: @This(), allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: Output) (SchemaError || std.mem.Allocator.Error)!void {
            try output.appendSlice(allocator, "{\"tag\":");
            switch (value) {
                .first => |payload| {
                    try appendJsonString(output, allocator, first_tag);
                    try output.appendSlice(allocator, ",\"value\":");
                    try rootAppendJsonValue(allocator, output, self.first, payload);
                },
                .second => |payload| {
                    try appendJsonString(output, allocator, second_tag);
                    try output.appendSlice(allocator, ",\"value\":");
                    try rootAppendJsonValue(allocator, output, self.second, payload);
                },
            }
            try output.append(allocator, '}');
        }
    };
}
pub fn taggedUnion2(first: anytype, second: anytype, comptime first_tag: []const u8, comptime second_tag: []const u8) TaggedUnion2Schema(@TypeOf(first), @TypeOf(second), first_tag, second_tag) {
    return .{ .first = first, .second = second };
}

pub fn MapSchema(comptime Inner: type) type {
    return struct {
        pub const Entry = struct { key: []const u8, value: Inner.Output };
        pub const Output = []const Entry;
        pub const generator_kind = "map";
        allocator: std.mem.Allocator,
        inner: Inner,
        max_entries: usize = 1024,
        pub fn decodeJsonValue(self: @This(), value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            const object = switch (value) {
                .object => |item| item,
                else => return error.InvalidType,
            };
            if (object.count() > self.max_entries) return error.InvalidValue;
            const output = try self.allocator.alloc(Entry, object.count());
            errdefer self.allocator.free(output);
            var iterator = object.iterator();
            var index: usize = 0;
            while (iterator.next()) |entry| : (index += 1) output[index] = .{ .key = entry.key_ptr.*, .value = try self.inner.decodeJsonValue(entry.value_ptr.*) };
            return output;
        }
        pub fn decodeDetailedJsonValue(self: @This(), ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            const object = switch (value) {
                .object => |item| item,
                else => {
                    try ctx.addIssue(.invalid_type, "object map", valueTypeName(value), "expected JSON object map");
                    return error.InvalidType;
                },
            };
            if (object.count() > self.max_entries) {
                try ctx.addIssue(.constraint_failed, "bounded map", "object", "too many map entries");
                return error.InvalidValue;
            }
            const output = try self.allocator.alloc(Entry, object.count());
            errdefer self.allocator.free(output);
            var iterator = object.iterator();
            var index: usize = 0;
            while (iterator.next()) |entry| : (index += 1) {
                const mark_path = try ctx.pushField(entry.key_ptr.*);
                defer ctx.popTo(mark_path);
                output[index] = .{ .key = entry.key_ptr.*, .value = try rootDecodeDetailedJsonValue(self.inner, ctx, entry.value_ptr.*) };
            }
            return output;
        }
        pub fn appendJsonValue(self: @This(), allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: Output) (SchemaError || std.mem.Allocator.Error)!void {
            if (value.len > self.max_entries) return error.InvalidValue;
            try output.append(allocator, '{');
            for (value, 0..) |entry, index| {
                if (index != 0) try output.append(allocator, ',');
                try appendJsonString(output, allocator, entry.key);
                try output.append(allocator, ':');
                try rootAppendJsonValue(allocator, output, self.inner, entry.value);
            }
            try output.append(allocator, '}');
        }
    };
}
pub fn map(allocator: std.mem.Allocator, inner: anytype) MapSchema(@TypeOf(inner)) {
    return .{ .allocator = allocator, .inner = inner };
}

pub fn LazySchema(comptime SchemaType: type, comptime resolve_fn: *const fn () SchemaType) type {
    return struct {
        pub const Output = SchemaType.Output;
        pub const generator_kind = "lazy";
        pub fn resolved(_: @This()) SchemaType {
            return resolve_fn();
        }
        pub fn decodeJsonValue(_: @This(), value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            return resolve_fn().decodeJsonValue(value);
        }
        pub fn decodeDetailedJsonValue(_: @This(), ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            return rootDecodeDetailedJsonValue(resolve_fn(), ctx, value);
        }
        pub fn appendJsonValue(_: @This(), allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: Output) (SchemaError || std.mem.Allocator.Error)!void {
            return rootAppendJsonValue(allocator, output, resolve_fn(), value);
        }
    };
}
pub fn lazy(comptime SchemaType: type, comptime resolve_fn: *const fn () SchemaType) LazySchema(SchemaType, resolve_fn) {
    return .{};
}

pub fn VersionedSchema(comptime Current: type, comptime Legacy: type, comptime migrate_fn: *const fn (Legacy.Output) SchemaError!Current.Output) type {
    return struct {
        pub const Output = Current.Output;
        pub const generator_kind = "versioned";
        current: Current,
        legacy: Legacy,
        current_version: i64,
        legacy_version: i64,
        pub fn decodeJsonValue(self: @This(), value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            const object = switch (value) {
                .object => |item| item,
                else => return error.InvalidType,
            };
            const version = switch (object.get("_version") orelse return error.MissingField) {
                .integer => |item| item,
                else => return error.InvalidType,
            };
            const data = object.get("data") orelse return error.MissingField;
            if (version == self.current_version) return self.current.decodeJsonValue(data);
            if (version == self.legacy_version) return migrate_fn(try self.legacy.decodeJsonValue(data));
            return error.InvalidValue;
        }
        pub fn decodeDetailedJsonValue(self: @This(), ctx: *ParseContext, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!Output {
            return self.decodeJsonValue(value) catch |err| {
                try ctx.addIssue(schemaErrorIssueKind(err), "supported schema version", valueTypeName(value), "version is missing unsupported or migration failed");
                return err;
            };
        }
        pub fn appendJsonValue(self: @This(), allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: Output) (SchemaError || std.mem.Allocator.Error)!void {
            try output.print(allocator, "{{\"_version\":{d},\"data\":", .{self.current_version});
            try rootAppendJsonValue(allocator, output, self.current, value);
            try output.append(allocator, '}');
        }
    };
}
pub fn versioned(current: anytype, legacy: anytype, current_version: i64, legacy_version: i64, comptime migrate_fn: *const fn (@TypeOf(legacy).Output) SchemaError!@TypeOf(current).Output) VersionedSchema(@TypeOf(current), @TypeOf(legacy), migrate_fn) {
    return .{ .current = current, .legacy = legacy, .current_version = current_version, .legacy_version = legacy_version };
}

pub const ProjectionTarget = enum { json_schema, openapi, config, sql, cli };
pub const Projection = struct {
    allocator: std.mem.Allocator,
    document: []const u8,
    losses: []const []const u8,
    pub fn lossless(self: Projection) bool {
        return self.losses.len == 0;
    }
    pub fn deinit(self: *Projection) void {
        self.allocator.free(self.document);
        for (self.losses) |loss| self.allocator.free(loss);
        self.allocator.free(self.losses);
        self.* = undefined;
    }
};

/// Projects a schema to an agent/tooling contract. Supported primitive kinds
/// are lossless; semantic wrappers remain explicit and unsupported constructs
/// produce diagnostics instead of silently weakening validation.
pub fn projectAlloc(allocator: std.mem.Allocator, schema: anytype, target: ProjectionTarget) !Projection {
    var losses = std.ArrayList([]const u8).empty;
    errdefer {
        for (losses.items) |loss| allocator.free(loss);
        losses.deinit(allocator);
    }
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, "{\"schema\":\"zigeffect.schema.projection.v2\",\"target\":");
    try appendJsonString(&output, allocator, @tagName(target));
    try output.appendSlice(allocator, ",\"document\":");
    try appendProjectionSchema(allocator, &output, schema, target, &losses, "$", 0);
    try output.append(allocator, '}');
    const document = try output.toOwnedSlice(allocator);
    return .{ .allocator = allocator, .document = document, .losses = try losses.toOwnedSlice(allocator) };
}

fn appendProjectionSchema(allocator: std.mem.Allocator, output: *std.ArrayList(u8), schema: anytype, target: ProjectionTarget, losses: *std.ArrayList([]const u8), path: []const u8, depth: usize) !void {
    if (depth > 32) {
        try addProjectionLoss(allocator, losses, target, path, "recursive depth exceeds projection bound");
        try output.appendSlice(allocator, "{}");
        return;
    }
    const S = @TypeOf(schema);
    const kind = S.generator_kind;
    if (comptime std.mem.eql(u8, kind, "string")) {
        try output.appendSlice(allocator, "{\"type\":\"string\"");
        if (schema.require_non_empty) try output.appendSlice(allocator, ",\"minLength\":1");
        if (schema.min_len) |value| try output.print(allocator, ",\"minLength\":{d}", .{value});
        if (schema.max_len) |value| try output.print(allocator, ",\"maxLength\":{d}", .{value});
        try output.append(allocator, '}');
        return;
    }
    if (comptime std.mem.eql(u8, kind, "integer")) {
        try output.appendSlice(allocator, "{\"type\":\"integer\"");
        if (schema.min_value) |value| try output.print(allocator, ",\"minimum\":{d}", .{value});
        if (schema.max_value) |value| try output.print(allocator, ",\"maximum\":{d}", .{value});
        try output.append(allocator, '}');
        return;
    }
    if (comptime std.mem.eql(u8, kind, "float")) {
        try output.appendSlice(allocator, "{\"type\":\"number\"");
        if (schema.min_value) |value| try output.print(allocator, ",\"minimum\":{d}", .{value});
        if (schema.max_value) |value| try output.print(allocator, ",\"maximum\":{d}", .{value});
        try output.append(allocator, '}');
        return;
    }
    if (comptime std.mem.eql(u8, kind, "boolean")) {
        try output.appendSlice(allocator, "{\"type\":\"boolean\"}");
        return;
    }
    if (comptime std.mem.eql(u8, kind, "decimal")) {
        try output.print(allocator, "{{\"type\":\"string\",\"format\":\"decimal\",\"x-max-digits\":{d},\"x-max-scale\":{d}}}", .{ schema.max_digits, schema.max_scale });
        return;
    }
    if (comptime std.mem.eql(u8, kind, "bytes")) {
        try output.print(allocator, "{{\"type\":\"string\",\"contentEncoding\":\"base64\",\"x-max-decoded-bytes\":{d}}}", .{schema.max_bytes});
        return;
    }
    if (comptime std.mem.eql(u8, kind, "time")) {
        try output.appendSlice(allocator, "{\"type\":\"integer\",\"format\":");
        try appendJsonString(output, allocator, @tagName(schema.semantic));
        try output.appendSlice(allocator, ",\"x-unit\":");
        try appendJsonString(output, allocator, @tagName(schema.unit));
        try output.append(allocator, '}');
        return;
    }
    if (comptime std.mem.eql(u8, kind, "literal")) {
        try output.appendSlice(allocator, "{\"type\":\"string\",\"const\":");
        try appendJsonString(output, allocator, S.literal);
        try output.append(allocator, '}');
        return;
    }
    if (comptime std.mem.eql(u8, kind, "enum")) {
        try output.appendSlice(allocator, "{\"type\":\"string\",\"enum\":[");
        inline for (S.generator_choices, 0..) |choice, index| {
            if (index != 0) try output.append(allocator, ',');
            try appendJsonString(output, allocator, choice);
        }
        try output.appendSlice(allocator, "]}");
        return;
    }
    if (comptime std.mem.eql(u8, kind, "optional")) {
        try output.appendSlice(allocator, "{\"anyOf\":[");
        try appendProjectionSchema(allocator, output, schema.inner, target, losses, path, depth + 1);
        try output.appendSlice(allocator, ",{\"type\":\"null\"}]}");
        return;
    }
    if (comptime std.mem.eql(u8, kind, "array")) {
        try output.appendSlice(allocator, "{\"type\":\"array\",\"items\":");
        try appendProjectionSchema(allocator, output, schema.inner, target, losses, path, depth + 1);
        try output.append(allocator, '}');
        return;
    }
    if (comptime std.mem.eql(u8, kind, "tuple")) {
        try output.appendSlice(allocator, "{\"type\":\"array\",\"minItems\":2,\"maxItems\":2,\"prefixItems\":[");
        try appendProjectionSchema(allocator, output, schema.first, target, losses, path, depth + 1);
        try output.append(allocator, ',');
        try appendProjectionSchema(allocator, output, schema.second, target, losses, path, depth + 1);
        try output.appendSlice(allocator, "]}");
        return;
    }
    if (comptime std.mem.eql(u8, kind, "map")) {
        try output.appendSlice(allocator, "{\"type\":\"object\",\"additionalProperties\":");
        try appendProjectionSchema(allocator, output, schema.inner, target, losses, path, depth + 1);
        try output.print(allocator, ",\"maxProperties\":{d}}}", .{schema.max_entries});
        return;
    }
    if (comptime std.mem.eql(u8, kind, "struct")) {
        try output.appendSlice(allocator, "{\"type\":\"object\",\"additionalProperties\":false,\"properties\":{");
        inline for (schema.fields, 0..) |field_spec, index| {
            if (index != 0) try output.append(allocator, ',');
            const Field = @TypeOf(field_spec);
            try appendJsonString(output, allocator, Field.Name);
            try output.append(allocator, ':');
            const child_path = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ path, Field.Name });
            defer allocator.free(child_path);
            try appendProjectionSchema(allocator, output, field_spec.schema, target, losses, child_path, depth + 1);
        }
        try output.appendSlice(allocator, "},\"required\":[");
        var first = true;
        inline for (schema.fields) |field_spec| {
            const Field = @TypeOf(field_spec);
            if (!isOptional(Field.Schema.Output) and !hasDefault(Field.Schema)) {
                if (!first) try output.append(allocator, ',');
                first = false;
                try appendJsonString(output, allocator, Field.Name);
            }
        }
        try output.appendSlice(allocator, "]}");
        return;
    }
    if (comptime std.mem.eql(u8, kind, "brand")) {
        try output.appendSlice(allocator, "{\"allOf\":[");
        try appendProjectionSchema(allocator, output, schema.inner, target, losses, path, depth + 1);
        try output.appendSlice(allocator, "],\"x-zigeffect-brand\":");
        try appendJsonString(output, allocator, S.brand);
        try output.append(allocator, '}');
        return;
    }
    if (comptime std.mem.eql(u8, kind, "refinement")) {
        try addProjectionLoss(allocator, losses, target, path, "runtime refinement predicate is not portable");
        try appendProjectionSchema(allocator, output, schema.inner, target, losses, path, depth + 1);
        return;
    }
    if (comptime std.mem.eql(u8, kind, "tagged_union")) {
        try output.appendSlice(allocator, "{\"oneOf\":[{\"type\":\"object\",\"properties\":{\"tag\":{\"const\":\"first\"},\"value\":");
        try appendProjectionSchema(allocator, output, schema.first, target, losses, path, depth + 1);
        try output.appendSlice(allocator, "}},{\"type\":\"object\",\"properties\":{\"tag\":{\"const\":\"second\"},\"value\":");
        try appendProjectionSchema(allocator, output, schema.second, target, losses, path, depth + 1);
        try output.appendSlice(allocator, "}}]}");
        try addProjectionLoss(allocator, losses, target, path, "tag names are represented by stable projection variants");
        return;
    }
    if (comptime std.mem.eql(u8, kind, "lazy")) {
        try appendProjectionSchema(allocator, output, schema.resolved(), target, losses, path, depth + 1);
        return;
    }
    if (comptime std.mem.eql(u8, kind, "versioned")) {
        try output.appendSlice(allocator, "{\"type\":\"object\",\"properties\":{\"_version\":{\"type\":\"integer\"},\"data\":");
        try appendProjectionSchema(allocator, output, schema.current, target, losses, path, depth + 1);
        try output.appendSlice(allocator, "},\"required\":[\"_version\",\"data\"]}");
        try addProjectionLoss(allocator, losses, target, path, "legacy migration function remains runtime-only");
        return;
    }
    try addProjectionLoss(allocator, losses, target, path, "schema construct requires a target-specific adapter");
    try output.appendSlice(allocator, "{}");
}

fn addProjectionLoss(allocator: std.mem.Allocator, losses: *std.ArrayList([]const u8), target: ProjectionTarget, path: []const u8, detail: []const u8) !void {
    try losses.append(allocator, try std.fmt.allocPrint(allocator, "{s} {s}: {s}", .{ @tagName(target), path, detail }));
}

pub fn EnumSchema(comptime choices: []const []const u8) type {
    return struct {
        pub const Output = []const u8;
        pub const generator_kind = "enum";
        pub const generator_choices = choices;

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
        pub const generator_kind = "transform";
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
        pub const generator_kind = "transform";
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
        pub const generator_kind = "default";
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

pub fn default(schema: anytype, value: @TypeOf(schema).Output) DefaultSchema(@TypeOf(schema), @TypeOf(schema).Output) {
    return .{ .inner = schema, .value = value };
}

pub fn freeDecoded(allocator: std.mem.Allocator, value: anytype) void {
    const Value = @TypeOf(value);
    switch (@typeInfo(Value)) {
        .pointer => |pointer| if (pointer.size == .slice) allocator.free(value),
        else => {},
    }
}

pub fn freeOwnedDecoded(allocator: std.mem.Allocator, value: anytype) void {
    const Value = @TypeOf(value);
    switch (@typeInfo(Value)) {
        .pointer => |pointer| if (pointer.size == .slice) {
            if (pointer.child != u8) for (value) |item| freeOwnedDecoded(allocator, item);
            allocator.free(value);
        },
        .optional => if (value) |inner| freeOwnedDecoded(allocator, inner),
        .@"struct" => |struct_info| inline for (struct_info.fields) |field_info| {
            freeOwnedDecoded(allocator, @field(value, field_info.name));
        },
        .@"union" => |union_info| if (union_info.tag_type) |Tag| {
            const active = std.meta.activeTag(value);
            inline for (union_info.fields) |field_info| if (active == @field(Tag, field_info.name)) freeOwnedDecoded(allocator, @field(value, field_info.name));
        },
        else => {},
    }
}

fn cloneOwnedDecoded(allocator: std.mem.Allocator, value: anytype) !@TypeOf(value) {
    const Value = @TypeOf(value);
    return switch (@typeInfo(Value)) {
        .pointer => |pointer| clone: {
            if (pointer.size != .slice) break :clone value;
            if (pointer.child == u8) break :clone try allocator.dupe(u8, value);
            const output = try allocator.alloc(pointer.child, value.len);
            errdefer allocator.free(output);
            var initialized: usize = 0;
            errdefer for (output[0..initialized]) |item| freeOwnedDecoded(allocator, item);
            for (value, 0..) |item, index| {
                output[index] = try cloneOwnedDecoded(allocator, item);
                initialized += 1;
            }
            break :clone output;
        },
        .optional => if (value) |inner| try cloneOwnedDecoded(allocator, inner) else null,
        .@"struct" => |struct_info| clone: {
            var output: Value = undefined;
            var initialized: usize = 0;
            errdefer {
                inline for (struct_info.fields, 0..) |field_info, index| {
                    if (index < initialized) freeOwnedDecoded(allocator, @field(output, field_info.name));
                }
            }
            inline for (struct_info.fields) |field_info| {
                @field(output, field_info.name) = try cloneOwnedDecoded(allocator, @field(value, field_info.name));
                initialized += 1;
            }
            break :clone output;
        },
        .@"union" => |union_info| clone: {
            const Tag = union_info.tag_type orelse break :clone value;
            const active = std.meta.activeTag(value);
            inline for (union_info.fields) |field_info| {
                if (active == @field(Tag, field_info.name)) break :clone @unionInit(Value, field_info.name, try cloneOwnedDecoded(allocator, @field(value, field_info.name)));
            }
            unreachable;
        },
        else => value,
    };
}

fn freeDecodedContainers(allocator: std.mem.Allocator, value: anytype) void {
    const Value = @TypeOf(value);
    switch (@typeInfo(Value)) {
        .pointer => |pointer| if (pointer.size == .slice and pointer.child != u8) {
            for (value) |item| freeDecodedContainers(allocator, item);
            allocator.free(value);
        },
        .optional => if (value) |inner| freeDecodedContainers(allocator, inner),
        .@"struct" => |struct_info| inline for (struct_info.fields) |field_info| {
            freeDecodedContainers(allocator, @field(value, field_info.name));
        },
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
        .@"union" => |union_info| if (union_info.tag_type) |Tag| {
            const active = std.meta.activeTag(value);
            inline for (union_info.fields) |field_info| if (active == @field(Tag, field_info.name)) freeDetailedDecoded(allocator, @field(value, field_info.name));
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
        pub const generator_kind = "struct";
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
                    @field(output, Field.Name) = try coerceSchemaValue(@TypeOf(@field(output, Field.Name)), try field_spec.schema.decodeJsonValue(field_value));
                } else if (comptime hasDefault(@TypeOf(field_spec.schema))) {
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
                        if (rootDecodeDetailedJsonValue(field_spec.schema, ctx, field_value)) |decoded| {
                            if (coerceSchemaValue(@TypeOf(@field(output, Field.Name)), decoded)) |coerced| {
                                @field(output, Field.Name) = coerced;
                            } else |_| {
                                try ctx.addIssue(.invalid_value, @typeName(@TypeOf(@field(output, Field.Name))), valueTypeName(field_value), "decoded number is outside the destination field range");
                                failed = true;
                            }
                            if (ctx.issues.len() > before) failed = true;
                        } else |_| {
                            failed = true;
                        }
                    } else if (comptime hasDefault(@TypeOf(field_spec.schema))) {
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
                try rootAppendJsonValue(allocator, output, field_spec.schema, try coerceSchemaValue(Field.Schema.Output, @field(value, Field.Name)));
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
        pub const generator_kind = "derived";
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
    const decoded = try decodeJsonValue(schema, parsed.value);
    defer freeDecodedContainers(allocator, decoded);
    return cloneOwnedDecoded(allocator, decoded);
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
        .float => switch (value) {
            .float => |float_value| @as(T, @floatCast(float_value)),
            .integer => |integer_value| @as(T, @floatFromInt(integer_value)),
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
        if (err == error.OutOfMemory) return error.OutOfMemory;
        const schema_error: SchemaError = @errorCast(err);
        try ctx.addIssue(schemaErrorIssueKind(schema_error), inferredExpectedName(T), valueTypeName(value), @errorName(schema_error));
        return schema_error;
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
        .int, .float => try output.print(allocator, "{d}", .{value}),
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
        .float => "number",
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

fn coerceSchemaValue(comptime Target: type, value: anytype) SchemaError!Target {
    const Source = @TypeOf(value);
    if (Target == Source) return value;
    return switch (@typeInfo(Target)) {
        .int => switch (@typeInfo(Source)) {
            .int, .comptime_int => std.math.cast(Target, value) orelse SchemaError.InvalidValue,
            else => SchemaError.InvalidType,
        },
        .float => switch (@typeInfo(Source)) {
            .float, .comptime_float => @floatCast(value),
            .int, .comptime_int => @floatFromInt(value),
            else => SchemaError.InvalidType,
        },
        .optional => |target_optional| switch (@typeInfo(Source)) {
            .optional => if (value) |inner| try coerceSchemaValue(target_optional.child, inner) else null,
            else => try coerceSchemaValue(target_optional.child, value),
        },
        else => SchemaError.InvalidType,
    };
}

test "struct Schema safely coerces bounded integers into production field widths" {
    const Settings = struct { port: u16, attempts: usize, optional_limit: ?u32 };
    const schema_value = structSchema(Settings, .{
        field("port", integer().min(1).max(65535)),
        field("attempts", integer().min(1)),
        field("optional_limit", optional(integer().min(1))),
    });
    var decoded = try decodeDetailedJsonAlloc(std.testing.allocator, schema_value, "{\"port\":8080,\"attempts\":3,\"optional_limit\":9}");
    defer decoded.deinit();
    try std.testing.expect(decoded.ok());
    try std.testing.expectEqual(@as(u16, 8080), decoded.value.?.port);
    try std.testing.expectEqual(@as(?u32, 9), decoded.value.?.optional_limit);
    const encoded = try encodeJsonAlloc(std.testing.allocator, schema_value, decoded.value.?);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"port\":8080") != null);
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

fn positiveFloat(value: f64) bool {
    return value > 0;
}
fn migrateInteger(value: i64) SchemaError!i64 {
    return value + 1;
}

test "production schemas cover numbers bytes time tuple map union refinement and versions" {
    try std.testing.expectEqual(@as(f64, 1.5), try float().min(1).decodeJsonValue(.{ .float = 1.5 }));
    try std.testing.expectEqualStrings("123.45", try decimal().decodeJsonValue(.{ .string = "123.45" }));
    const encoded = "aGVsbG8=";
    const raw = try bytes().decodeBytesAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(raw);
    try std.testing.expectEqualStrings("hello", raw);
    try std.testing.expectEqual(@as(i64, 100), try timestampMillis().decodeJsonValue(.{ .integer = 100 }));
    const tuple_schema = tuple2(string(), integer());
    const tuple_value = try decodeJsonAlloc(std.testing.allocator, tuple_schema, "[\"item\",2]");
    defer freeOwnedDecoded(std.testing.allocator, tuple_value);
    try std.testing.expectEqualStrings("item", tuple_value.first);
    const map_schema = map(std.testing.allocator, integer());
    const map_value = try decodeJsonAlloc(std.testing.allocator, map_schema, "{\"one\":1,\"two\":2}");
    defer freeOwnedDecoded(std.testing.allocator, map_value);
    try std.testing.expectEqual(@as(usize, 2), map_value.len);
    const union_schema = taggedUnion2(string(), integer(), "text", "count");
    const union_value = try decodeJsonAlloc(std.testing.allocator, union_schema, "{\"tag\":\"text\",\"value\":\"ready\"}");
    defer freeOwnedDecoded(std.testing.allocator, union_value);
    try std.testing.expectEqualStrings("ready", union_value.first);
    try std.testing.expectEqual(@as(f64, 2.0), try refine(float(), "positive", positiveFloat).decodeJsonValue(.{ .float = 2.0 }));
    const version_schema = versioned(integer(), integer(), 2, 1, migrateInteger);
    var version_json = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "{\"_version\":1,\"data\":41}", .{});
    defer version_json.deinit();
    try std.testing.expectEqual(@as(i64, 42), try version_schema.decodeJsonValue(version_json.value));
    var projection = try projectAlloc(std.testing.allocator, decimal(), .openapi);
    defer projection.deinit();
    try std.testing.expect(projection.lossless());
    var lossy = try projectAlloc(std.testing.allocator, refine(float(), "positive", positiveFloat), .json_schema);
    defer lossy.deinit();
    try std.testing.expect(!lossy.lossless());
}

test "production projection matches compatibility snapshot and survives allocation failures" {
    const Input = struct { name: []const u8, age: i64, roles: []const []const u8 };
    const schema_value = structSchema(Input, .{ field("name", string().nonEmpty().maxLen(32)), field("age", integer().min(0)), field("roles", array(std.testing.allocator, stringEnum(&.{ "reader", "writer" }))) });
    var projection = try projectAlloc(std.testing.allocator, schema_value, .openapi);
    defer projection.deinit();
    const snapshot = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "src/schema/snapshots/production-projection.v2.json", std.testing.allocator, .limited(64 * 1024));
    defer std.testing.allocator.free(snapshot);
    try std.testing.expectEqualStrings(std.mem.trimEnd(u8, snapshot, "\r\n"), projection.document);
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const Local = struct { name: []const u8, age: i64 };
            const local_schema = structSchema(Local, .{ field("name", string().nonEmpty()), field("age", integer().min(0)) });
            var result = try projectAlloc(allocator, local_schema, .json_schema);
            result.deinit();
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
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

    _ = try ctx.pushField("agents");
    _ = try ctx.pushIndex(2);
    _ = try ctx.pushField("command");
    try ctx.addIssue(.invalid_type, "string", "42", "agent command must be a string");

    try std.testing.expectEqualStrings("$.agents[2].command", issues.items.items[0].path);
}

test "Schema detailed primitive decode reports all constraint issues with paths" {
    const schema = string().nonEmpty().minLen(4).contains("@");
    var result = try decodeDetailedJsonAlloc(std.testing.allocator, schema, "\"\"");
    defer result.deinit();

    try std.testing.expect(!result.ok());
    try std.testing.expectEqual(@as(usize, 3), result.issues.len());
    try std.testing.expectEqualStrings("$", result.issues.items.items[0].path);
    try std.testing.expectEqual(IssueKind.constraint_failed, result.issues.items.items[0].kind);
}

test "Schema integer constraints support min max and simple decode compatibility" {
    const schema = integer().min(1).max(10);
    var invalid = try decodeDetailedJsonAlloc(std.testing.allocator, schema, "42");
    defer invalid.deinit();

    try std.testing.expect(!invalid.ok());
    try std.testing.expectEqual(IssueKind.constraint_failed, invalid.issues.items.items[0].kind);

    try std.testing.expectEqual(@as(i64, 7), try decodeJsonAlloc(std.testing.allocator, schema, "7"));
    try std.testing.expectError(SchemaError.InvalidValue, decodeJsonAlloc(std.testing.allocator, schema, "42"));
}

test "Schema decodes optional and array JSON values" {
    try std.testing.expectEqual(@as(?[]const u8, null), try decodeJsonValue(optional(string()), .null));
    try std.testing.expectEqualStrings("value", (try decodeJsonValue(optional(string()), .{ .string = "value" })).?);

    var parsed_array = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "[1,2,3]", .{});
    defer parsed_array.deinit();
    const decoded = try decodeJsonValue(array(std.testing.allocator, integer()), parsed_array.value);
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
    defer freeOwnedDecoded(std.testing.allocator, decoded);
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
    defer freeOwnedDecoded(std.testing.allocator, decoded);

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
    defer freeOwnedDecoded(std.testing.allocator, decoded);

    try std.testing.expectEqualStrings("json", decoded.name);
    try std.testing.expectEqual(@as(i64, 3000), decoded.port);
    try std.testing.expectEqual(false, decoded.enabled);
    try std.testing.expectEqualStrings("dev", decoded.mode.?);

    var config = @import("../config/root.zig").LayeredConfig.init(std.testing.allocator);
    defer config.deinit();
    try config.put("HTTP_PORT", "5178", false);

    try std.testing.expectEqual(@as(i64, 5178), try decodeConfig(config, "HTTP_PORT", integer()));
}

test "Schema derived integer rejects a non-integer value" {
    const Input = struct { port: i64 };
    const schema = derive(Input, .{ .port = integer().min(1).max(65535) });

    try std.testing.expectError(
        SchemaError.InvalidType,
        decodeJsonAlloc(std.testing.allocator, schema, "{\"port\":\"5178\"}"),
    );
}
