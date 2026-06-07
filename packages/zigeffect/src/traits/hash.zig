const std = @import("std");

const offset: u64 = 0xcbf29ce484222325;
const prime: u64 = 0x100000001b3;

pub fn hash(comptime T: type, value: T) u64 {
    if (comptime hasDecl(T, "hash")) {
        return value.hash();
    }

    return hashWithSeed(T, value, offset);
}

fn hashBytes(seed: u64, bytes: []const u8) u64 {
    var result = seed;
    for (bytes) |byte| {
        result ^= byte;
        result *%= prime;
    }
    return result;
}

fn mix(seed: u64, next: u64) u64 {
    var result = seed ^ next;
    result *%= prime;
    return result;
}

fn hashWithSeed(comptime T: type, value: T, seed: u64) u64 {
    return switch (@typeInfo(T)) {
        .bool,
        .int,
        .comptime_int,
        .float,
        .comptime_float,
        .@"enum",
        .error_set,
        => hashBytes(seed, std.mem.asBytes(&value)),
        .pointer => |pointer| switch (pointer.size) {
            .one => hashWithSeed(pointer.child, value.*, seed),
            .slice => {
                var result = mix(seed, value.len);
                for (value) |item| {
                    result = mix(result, hashWithSeed(pointer.child, item, offset));
                }
                return result;
            },
            .many, .c => hashBytes(seed, std.mem.asBytes(&value)),
        },
        .array => |array| {
            var result = mix(seed, value.len);
            for (value) |item| {
                result = mix(result, hashWithSeed(array.child, item, offset));
            }
            return result;
        },
        .optional => |optional| {
            if (value) |inner| return mix(seed, hashWithSeed(optional.child, inner, offset));
            return mix(seed, 0);
        },
        .@"struct" => |structure| {
            var result = seed;
            inline for (structure.fields) |field| {
                result = mix(result, hashBytes(offset, field.name));
                result = mix(result, hashWithSeed(field.type, @field(value, field.name), offset));
            }
            return result;
        },
        .@"union" => |union_info| {
            if (union_info.tag_type == null) {
                @compileError("zigeffect Hash requires tagged unions");
            }
            var result = mix(seed, @intFromEnum(std.meta.activeTag(value)));
            result = switch (value) {
                inline else => |payload| mix(result, hashWithSeed(@TypeOf(payload), payload, offset)),
            };
            return result;
        },
        .void => seed,
        else => @compileError("zigeffect Hash does not support " ++ @typeName(T)),
    };
}

fn hasDecl(comptime T: type, comptime name: []const u8) bool {
    return switch (@typeInfo(T)) {
        .@"struct", .@"union", .@"enum", .@"opaque" => @hasDecl(T, name),
        else => false,
    };
}
