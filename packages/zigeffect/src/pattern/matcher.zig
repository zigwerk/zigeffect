const std = @import("std");
const traits = @import("../traits/root.zig");

pub const Pattern = union(enum) {
    wildcard,
    bind: [:0]const u8,
    range: Range,
};

pub const RangeMode = enum {
    inclusive,
    exclusive,
    inclusive_min,
    inclusive_max,
};

pub const Range = struct {
    mode: RangeMode,
    min: i128,
    max: i128,
};

const PatternKind = enum {
    predicate,
    some,
    none,
};

pub const any: Pattern = .wildcard;

pub fn bind(comptime name: [:0]const u8) Pattern {
    return .{ .bind = name };
}

pub fn range(comptime mode: RangeMode, min: anytype, max: anytype) Pattern {
    return .{ .range = .{ .mode = mode, .min = @as(i128, min), .max = @as(i128, max) } };
}

pub fn Predicate(comptime F: type) type {
    return struct {
        pub const pattern_kind = PatternKind.predicate;

        f: F,

        pub fn matches(self: @This(), value: anytype) bool {
            return self.f(value);
        }
    };
}

pub fn predicate(comptime f: anytype) Predicate(@TypeOf(f)) {
    return .{ .f = f };
}

pub fn SomePattern(comptime ChildPattern: type) type {
    return struct {
        pub const pattern_kind = PatternKind.some;

        pattern: ChildPattern,
    };
}

pub fn some(pattern: anytype) SomePattern(@TypeOf(pattern)) {
    return .{ .pattern = pattern };
}

pub const none = struct {
    pub const pattern_kind = PatternKind.none;
}{};

pub fn matches(value: anytype, pattern: anytype) bool {
    return matchValue(@TypeOf(value), value, @TypeOf(pattern), pattern);
}

pub fn capture(value: anytype, comptime pattern: anytype) ?CaptureResult(@TypeOf(value), pattern) {
    if (!matches(value, pattern)) return null;
    var result: CaptureResult(@TypeOf(value), pattern) = undefined;
    fillCaptureValues(&result, value, pattern);
    return result;
}

fn matchValue(comptime Value: type, value: Value, comptime PatternType: type, pattern: PatternType) bool {
    if (comptime PatternType == Pattern) {
        return switch (pattern) {
            .wildcard, .bind => true,
            .range => |range_pattern| matchRange(value, range_pattern),
        };
    }

    if (comptime isPredicate(PatternType)) {
        return pattern.matches(value);
    }

    if (comptime isSomePattern(PatternType)) {
        return matchSomePattern(Value, value, pattern);
    }

    if (comptime isNonePattern(PatternType)) {
        return matchNonePattern(Value, value);
    }

    return switch (@typeInfo(PatternType)) {
        .@"struct" => |pattern_struct| matchStructPattern(Value, value, PatternType, pattern, pattern_struct),
        .array => |pattern_array| matchArrayPattern(Value, value, pattern_array, pattern),
        .pointer => |pattern_pointer| matchPointerPattern(Value, value, pattern_pointer, pattern),
        else => matchExact(Value, value, pattern),
    };
}

fn matchSomePattern(comptime Value: type, value: Value, pattern: anytype) bool {
    return switch (@typeInfo(Value)) {
        .optional => |optional| {
            if (value) |inner| {
                return matchValue(optional.child, inner, @TypeOf(pattern.pattern), pattern.pattern);
            }
            return false;
        },
        else => false,
    };
}

fn matchNonePattern(comptime Value: type, value: Value) bool {
    return switch (@typeInfo(Value)) {
        .optional => value == null,
        else => false,
    };
}

fn matchStructPattern(
    comptime Value: type,
    value: Value,
    comptime PatternType: type,
    pattern: PatternType,
    comptime pattern_struct: std.builtin.Type.Struct,
) bool {
    switch (@typeInfo(Value)) {
        .@"struct" => {
            inline for (pattern_struct.fields) |field| {
                if (comptime !hasStructField(Value, field.name)) return false;
                if (!matchValue(
                    structFieldType(Value, field.name),
                    @field(value, field.name),
                    field.type,
                    @field(pattern, field.name),
                )) return false;
            }
            return true;
        },
        else => return matchExact(Value, value, pattern),
    }
}

fn matchArrayPattern(
    comptime Value: type,
    value: Value,
    comptime pattern_array: std.builtin.Type.Array,
    pattern: anytype,
) bool {
    return switch (@typeInfo(Value)) {
        .array => |value_array| {
            if (value_array.len != pattern_array.len) return false;
            for (value, pattern) |value_item, pattern_item| {
                if (!matchValue(@TypeOf(value_item), value_item, @TypeOf(pattern_item), pattern_item)) return false;
            }
            return true;
        },
        else => matchExact(Value, value, pattern),
    };
}

fn matchPointerPattern(
    comptime Value: type,
    value: Value,
    comptime pattern_pointer: std.builtin.Type.Pointer,
    pattern: anytype,
) bool {
    return switch (@typeInfo(Value)) {
        .pointer => |value_pointer| switch (value_pointer.size) {
            .slice => switch (pattern_pointer.size) {
                .slice => {
                    if (value.len != pattern.len) return false;
                    for (value, pattern) |value_item, pattern_item| {
                        if (!matchValue(@TypeOf(value_item), value_item, @TypeOf(pattern_item), pattern_item)) return false;
                    }
                    return true;
                },
                .one => switch (@typeInfo(pattern_pointer.child)) {
                    .array => |pattern_array| {
                        if (value.len != pattern_array.len) return false;
                        for (value, pattern.*) |value_item, pattern_item| {
                            if (!matchValue(@TypeOf(value_item), value_item, @TypeOf(pattern_item), pattern_item)) return false;
                        }
                        return true;
                    },
                    else => matchExact(Value, value, pattern),
                },
                else => matchExact(Value, value, pattern),
            },
            .one => switch (pattern_pointer.size) {
                .one => matchValue(value_pointer.child, value.*, pattern_pointer.child, pattern.*),
                else => matchExact(Value, value, pattern),
            },
            else => matchExact(Value, value, pattern),
        },
        else => matchExact(Value, value, pattern),
    };
}

fn matchExact(comptime Value: type, value: Value, pattern: anytype) bool {
    return traits.equals(Value, value, @as(Value, pattern));
}

fn matchRange(value: anytype, range_pattern: Range) bool {
    const numeric = toI128(value) orelse return false;
    return switch (range_pattern.mode) {
        .inclusive => numeric >= range_pattern.min and numeric <= range_pattern.max,
        .exclusive => numeric > range_pattern.min and numeric < range_pattern.max,
        .inclusive_min => numeric >= range_pattern.min and numeric < range_pattern.max,
        .inclusive_max => numeric > range_pattern.min and numeric <= range_pattern.max,
    };
}

fn toI128(value: anytype) ?i128 {
    return switch (@typeInfo(@TypeOf(value))) {
        .int, .comptime_int => @as(i128, value),
        .@"enum" => @intFromEnum(value),
        else => null,
    };
}

fn CaptureResult(comptime Value: type, comptime pattern: anytype) type {
    validateNoDuplicateCaptures(pattern);
    const count = countCaptures(Value, pattern);
    comptime var field_names: [count][]const u8 = undefined;
    comptime var field_types: [count]type = undefined;
    comptime var field_attrs: [count]std.builtin.Type.StructField.Attributes = undefined;
    comptime var index: usize = 0;
    fillCaptureFields(&field_names, &field_types, &field_attrs, &index, Value, pattern);
    return @Struct(.auto, null, &field_names, &field_types, &field_attrs);
}

fn validateNoDuplicateCaptures(comptime pattern: anytype) void {
    const count = countPatternBinds(pattern);
    comptime var names: [count][]const u8 = undefined;
    comptime var index: usize = 0;
    fillPatternBindNames(&names, &index, pattern);

    inline for (names, 0..) |left, left_index| {
        inline for (names, 0..) |right, right_index| {
            if (comptime right_index > left_index and std.mem.eql(u8, left, right)) {
                @compileError("zigeffect pattern duplicate capture '" ++ left ++ "'");
            }
        }
    }
}

fn countPatternBinds(comptime pattern: anytype) usize {
    const PatternType = @TypeOf(pattern);
    if (PatternType == Pattern) {
        return switch (pattern) {
            .bind => 1,
            else => 0,
        };
    }
    if (comptime isSomePattern(PatternType)) {
        return countPatternBinds(pattern.pattern);
    }
    if (comptime isPredicate(PatternType) or isNonePattern(PatternType)) {
        return 0;
    }

    return switch (@typeInfo(PatternType)) {
        .@"struct" => |structure| {
            comptime var count: usize = 0;
            inline for (structure.fields) |field| {
                count += countPatternBinds(@field(pattern, field.name));
            }
            return count;
        },
        else => 0,
    };
}

fn fillPatternBindNames(comptime names: anytype, comptime index: *usize, comptime pattern: anytype) void {
    const PatternType = @TypeOf(pattern);
    if (PatternType == Pattern) {
        switch (pattern) {
            .bind => |name| {
                names[index.*] = name;
                index.* += 1;
            },
            else => {},
        }
        return;
    }
    if (comptime isSomePattern(PatternType)) {
        fillPatternBindNames(names, index, pattern.pattern);
        return;
    }
    if (comptime isPredicate(PatternType) or isNonePattern(PatternType)) {
        return;
    }

    switch (@typeInfo(PatternType)) {
        .@"struct" => |structure| inline for (structure.fields) |field| {
            fillPatternBindNames(names, index, @field(pattern, field.name));
        },
        else => {},
    }
}

fn countCaptures(comptime Value: type, comptime pattern: anytype) usize {
    const PatternType = @TypeOf(pattern);
    if (PatternType == Pattern) {
        return switch (pattern) {
            .bind => 1,
            else => 0,
        };
    }

    if (comptime isSomePattern(PatternType)) {
        return switch (@typeInfo(Value)) {
            .optional => |optional| countCaptures(optional.child, pattern.pattern),
            else => 0,
        };
    }

    return switch (@typeInfo(PatternType)) {
        .@"struct" => |pattern_struct| switch (@typeInfo(Value)) {
            .@"struct" => {
                comptime var count: usize = 0;
                inline for (pattern_struct.fields) |field| {
                    if (comptime hasStructField(Value, field.name)) {
                        count += countCaptures(structFieldType(Value, field.name), @field(pattern, field.name));
                    }
                }
                return count;
            },
            else => 0,
        },
        else => 0,
    };
}

fn fillCaptureFields(
    comptime field_names: anytype,
    comptime field_types: anytype,
    comptime field_attrs: anytype,
    comptime index: *usize,
    comptime Value: type,
    comptime pattern: anytype,
) void {
    const PatternType = @TypeOf(pattern);
    if (PatternType == Pattern) {
        switch (pattern) {
            .bind => |name| {
                field_names[index.*] = name;
                field_types[index.*] = Value;
                field_attrs[index.*] = .{};
                index.* += 1;
            },
            else => {},
        }
        return;
    }

    if (comptime isSomePattern(PatternType)) {
        switch (@typeInfo(Value)) {
            .optional => |optional| fillCaptureFields(field_names, field_types, field_attrs, index, optional.child, pattern.pattern),
            else => {},
        }
        return;
    }

    switch (@typeInfo(PatternType)) {
        .@"struct" => |pattern_struct| switch (@typeInfo(Value)) {
            .@"struct" => inline for (pattern_struct.fields) |field| {
                if (comptime hasStructField(Value, field.name)) {
                    fillCaptureFields(field_names, field_types, field_attrs, index, structFieldType(Value, field.name), @field(pattern, field.name));
                }
            },
            else => {},
        },
        else => {},
    }
}

fn fillCaptureValues(result: anytype, value: anytype, comptime pattern: anytype) void {
    const PatternType = @TypeOf(pattern);
    if (PatternType == Pattern) {
        switch (pattern) {
            .bind => |name| @field(result.*, name) = value,
            else => {},
        }
        return;
    }

    if (comptime isSomePattern(PatternType)) {
        switch (@typeInfo(@TypeOf(value))) {
            .optional => {
                if (value) |inner| fillCaptureValues(result, inner, pattern.pattern);
            },
            else => {},
        }
        return;
    }

    switch (@typeInfo(PatternType)) {
        .@"struct" => |pattern_struct| switch (@typeInfo(@TypeOf(value))) {
            .@"struct" => inline for (pattern_struct.fields) |field| {
                if (comptime hasStructField(@TypeOf(value), field.name)) {
                    fillCaptureValues(result, @field(value, field.name), @field(pattern, field.name));
                }
            },
            else => {},
        },
        else => {},
    }
}

fn isPredicate(comptime T: type) bool {
    return hasDecl(T, "pattern_kind") and T.pattern_kind == PatternKind.predicate;
}

fn isSomePattern(comptime T: type) bool {
    return hasDecl(T, "pattern_kind") and T.pattern_kind == PatternKind.some;
}

fn isNonePattern(comptime T: type) bool {
    return hasDecl(T, "pattern_kind") and T.pattern_kind == PatternKind.none;
}

fn hasDecl(comptime T: type, comptime name: []const u8) bool {
    return switch (@typeInfo(T)) {
        .@"struct", .@"union", .@"enum", .@"opaque" => @hasDecl(T, name),
        else => false,
    };
}

fn hasStructField(comptime T: type, comptime name: []const u8) bool {
    const info = @typeInfo(T).@"struct";
    inline for (info.fields) |field| {
        if (std.mem.eql(u8, field.name, name)) return true;
    }
    return false;
}

fn structFieldType(comptime T: type, comptime name: []const u8) type {
    const info = @typeInfo(T).@"struct";
    inline for (info.fields) |field| {
        if (std.mem.eql(u8, field.name, name)) return field.type;
    }
    @compileError("zigeffect pattern unknown struct field '" ++ name ++ "' on " ++ @typeName(T));
}
