const std = @import("std");

pub fn equals(comptime T: type, lhs: T, rhs: T) bool {
    if (comptime hasDecl(T, "equals")) {
        return T.equals(lhs, rhs);
    }

    return switch (@typeInfo(T)) {
        .bool,
        .int,
        .comptime_int,
        .float,
        .comptime_float,
        .@"enum",
        .error_set,
        => lhs == rhs,
        .pointer => |pointer| switch (pointer.size) {
            .one => equals(pointer.child, lhs.*, rhs.*),
            .slice => {
                if (lhs.len != rhs.len) return false;
                for (lhs, rhs) |left, right| {
                    if (!equals(pointer.child, left, right)) return false;
                }
                return true;
            },
            .many, .c => lhs == rhs,
        },
        .array => |array| {
            for (lhs, rhs) |left, right| {
                if (!equals(array.child, left, right)) return false;
            }
            return true;
        },
        .optional => |optional| {
            if (lhs == null and rhs == null) return true;
            if (lhs == null or rhs == null) return false;
            return equals(optional.child, lhs.?, rhs.?);
        },
        .@"struct" => |structure| {
            inline for (structure.fields) |field| {
                if (!equals(field.type, @field(lhs, field.name), @field(rhs, field.name))) return false;
            }
            return true;
        },
        .@"union" => |union_info| {
            if (union_info.tag_type == null) {
                @compileError("zigeffect Equal requires tagged unions");
            }
            if (std.meta.activeTag(lhs) != std.meta.activeTag(rhs)) return false;
            return switch (lhs) {
                inline else => |payload, tag| equals(@TypeOf(payload), payload, @field(rhs, @tagName(tag))),
            };
        },
        .void => true,
        else => @compileError("zigeffect Equal does not support " ++ @typeName(T)),
    };
}

fn hasDecl(comptime T: type, comptime name: []const u8) bool {
    return switch (@typeInfo(T)) {
        .@"struct", .@"union", .@"enum", .@"opaque" => @hasDecl(T, name),
        else => false,
    };
}
