const std = @import("std");
const matcher = @import("matcher.zig");

pub fn Arm(comptime PatternType: type, comptime Handler: type) type {
    return struct {
        pub const pattern_arm = true;

        pattern: PatternType,
        handler: Handler,
    };
}

pub fn arm(comptime pattern: anytype, handler: anytype) Arm(@TypeOf(pattern), @TypeOf(handler)) {
    return .{ .pattern = pattern, .handler = handler };
}

pub fn exhaustive(comptime Return: type, value: anytype, arms: anytype) Return {
    const Value = @TypeOf(value);
    const Arms = @TypeOf(arms);

    validateTaggedUnion(Value);
    validateArmsAreStruct(Arms);
    validateNoUnknownArms(Value, Arms);
    validateAllArmsPresent(Value, Arms);

    return partial(Return, value, arms) orelse @panic("zigeffect pattern exhaustive arm did not match active payload");
}

pub fn partial(comptime Return: type, value: anytype, arms: anytype) ?Return {
    const Value = @TypeOf(value);
    const Arms = @TypeOf(arms);

    validateTaggedUnion(Value);
    validateArmsAreStruct(Arms);
    validateNoUnknownArms(Value, Arms);

    return switch (value) {
        inline else => |payload, tag| {
            const tag_name = @tagName(tag);
            if (comptime hasStructField(Arms, tag_name)) {
                const current_arm = @field(arms, tag_name);
                validateArm(@TypeOf(current_arm), tag_name);
                if (!matcher.matches(payload, current_arm.pattern)) return null;
                return callHandler(Return, current_arm.handler, payload);
            }
            return null;
        },
    };
}

fn validateTaggedUnion(comptime Value: type) void {
    switch (@typeInfo(Value)) {
        .@"union" => |union_info| {
            if (union_info.tag_type == null) {
                @compileError("zigeffect pattern arms require a tagged union(enum), got untagged union " ++ @typeName(Value));
            }
        },
        else => @compileError("zigeffect pattern arms require a tagged union(enum), got " ++ @typeName(Value)),
    }
}

fn validateArmsAreStruct(comptime Arms: type) void {
    switch (@typeInfo(Arms)) {
        .@"struct" => {},
        else => @compileError("zigeffect pattern arms must be a struct literal keyed by union tag"),
    }
}

fn validateAllArmsPresent(comptime Value: type, comptime Arms: type) void {
    const union_info = @typeInfo(Value).@"union";
    inline for (union_info.fields) |field| {
        if (comptime !hasStructField(Arms, field.name)) {
            @compileError("zigeffect pattern exhaustive missing arm for tag '" ++ field.name ++ "'");
        }
    }
}

fn validateNoUnknownArms(comptime Value: type, comptime Arms: type) void {
    const arms_info = @typeInfo(Arms).@"struct";
    inline for (arms_info.fields) |field| {
        if (comptime !hasUnionField(Value, field.name)) {
            @compileError("zigeffect pattern arm '" ++ field.name ++ "' is not a tag of " ++ @typeName(Value));
        }
    }
}

fn validateArm(comptime ArmType: type, comptime tag_name: []const u8) void {
    if (comptime !hasDecl(ArmType, "pattern_arm") or !ArmType.pattern_arm) {
        @compileError("zigeffect pattern arm for tag '" ++ tag_name ++ "' must be created with fx.pattern.arm");
    }
}

fn callHandler(comptime Return: type, handler: anytype, payload: anytype) Return {
    const Handler = @TypeOf(handler);
    return switch (@typeInfo(Handler)) {
        .@"fn" => |function_info| callFunction(Return, handler, function_info, payload),
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => |function_info| callFunction(Return, handler, function_info, payload),
            else => @compileError("zigeffect pattern arm handler must be a function"),
        },
        else => @compileError("zigeffect pattern arm handler must be a function"),
    };
}

fn callFunction(comptime Return: type, function: anytype, comptime function_info: anytype, payload: anytype) Return {
    return switch (function_info.params.len) {
        0 => function(),
        1 => @as(Return, function(payload)),
        else => @compileError("zigeffect pattern arm handlers must accept zero or one argument"),
    };
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

fn hasUnionField(comptime T: type, comptime name: []const u8) bool {
    const info = @typeInfo(T).@"union";
    inline for (info.fields) |field| {
        if (std.mem.eql(u8, field.name, name)) return true;
    }
    return false;
}
