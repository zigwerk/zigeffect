const std = @import("std");

pub fn exhaustive(comptime Return: type, value: anytype, handlers: anytype) Return {
    const Value = @TypeOf(value);
    const Handlers = @TypeOf(handlers);

    validateTaggedUnion(Value);
    validateHandlersAreStruct(Handlers);
    validateNoUnknownHandlers(Value, Handlers);
    validateAllHandlersPresent(Value, Handlers);

    return switch (value) {
        inline else => |payload, tag| callHandler(Return, @field(handlers, @tagName(tag)), payload),
    };
}

pub fn partial(comptime Return: type, value: anytype, handlers: anytype) ?Return {
    const Value = @TypeOf(value);
    const Handlers = @TypeOf(handlers);

    validateTaggedUnion(Value);
    validateHandlersAreStruct(Handlers);
    validateNoUnknownHandlers(Value, Handlers);

    return switch (value) {
        inline else => |payload, tag| {
            const tag_name = @tagName(tag);
            if (comptime hasStructField(Handlers, tag_name)) {
                return callHandler(Return, @field(handlers, tag_name), payload);
            }
            return null;
        },
    };
}

pub fn orElse(comptime Return: type, value: anytype, handlers: anytype, fallback: Return) Return {
    return partial(Return, value, handlers) orelse fallback;
}

pub fn option(comptime Return: type, value: anytype, handlers: anytype) ?Return {
    return partial(Return, value, handlers);
}

pub fn either(comptime Return: type, comptime Error: type, value: anytype, handlers: anytype) Error!Return {
    return partial(Return, value, handlers) orelse return error.NoMatch;
}

fn validateTaggedUnion(comptime Value: type) void {
    switch (@typeInfo(Value)) {
        .@"union" => |union_info| {
            if (union_info.tag_type == null) {
                @compileError("zigeffect match requires a tagged union(enum), got untagged union " ++ @typeName(Value));
            }
        },
        else => @compileError("zigeffect match requires a tagged union(enum), got " ++ @typeName(Value)),
    }
}

fn validateHandlersAreStruct(comptime Handlers: type) void {
    switch (@typeInfo(Handlers)) {
        .@"struct" => {},
        else => @compileError("zigeffect match handlers must be a struct literal keyed by union tag"),
    }
}

fn validateAllHandlersPresent(comptime Value: type, comptime Handlers: type) void {
    const union_info = @typeInfo(Value).@"union";
    inline for (union_info.fields) |field| {
        if (comptime !hasStructField(Handlers, field.name)) {
            @compileError("zigeffect match exhaustive missing handler for tag '" ++ field.name ++ "'");
        }
    }
}

fn validateNoUnknownHandlers(comptime Value: type, comptime Handlers: type) void {
    const handler_info = @typeInfo(Handlers).@"struct";
    inline for (handler_info.fields) |field| {
        if (comptime !hasUnionField(Value, field.name)) {
            @compileError("zigeffect match handler '" ++ field.name ++ "' is not a tag of " ++ @typeName(Value));
        }
    }
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

fn callHandler(comptime Return: type, handler: anytype, payload: anytype) Return {
    const Handler = @TypeOf(handler);
    return switch (@typeInfo(Handler)) {
        .@"fn" => |function_info| callFunction(Return, handler, function_info, payload),
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => |function_info| callFunction(Return, handler, function_info, payload),
            else => callValueHandler(Return, handler, payload),
        },
        else => callValueHandler(Return, handler, payload),
    };
}

fn callFunction(comptime Return: type, function: anytype, comptime function_info: anytype, payload: anytype) Return {
    validateFunctionReturn(Return, function_info.return_type);
    return switch (function_info.params.len) {
        0 => {
            if (comptime @TypeOf(payload) != void) {
                @compileError("zigeffect match handler payload mismatch: tag carries " ++ @typeName(@TypeOf(payload)) ++ " but handler accepts no arguments");
            }
            return coerceReturn(Return, function());
        },
        1 => {
            validateFunctionPayload(@TypeOf(payload), function_info.params[0].type);
            return coerceReturn(Return, function(payload));
        },
        else => @compileError("zigeffect match handlers must accept zero or one argument"),
    };
}

fn callValueHandler(comptime Return: type, handler: anytype, payload: anytype) Return {
    if (@TypeOf(payload) != void) {
        @compileError("zigeffect match handler for payload tag must be a one-argument function");
    }
    return coerceReturn(Return, handler);
}

fn coerceReturn(comptime Return: type, value: anytype) Return {
    return value;
}

fn validateFunctionReturn(comptime Return: type, comptime actual_return: ?type) void {
    const Actual = actual_return orelse {
        @compileError("zigeffect match handler return mismatch: handler has no concrete return type");
    };
    if (comptime Actual != Return) {
        @compileError("zigeffect match handler return mismatch: expected " ++ @typeName(Return) ++ ", got " ++ @typeName(Actual));
    }
}

fn validateFunctionPayload(comptime Payload: type, comptime expected_payload: ?type) void {
    const Expected = expected_payload orelse return;
    if (comptime Expected != Payload) {
        @compileError("zigeffect match handler payload mismatch: expected " ++ @typeName(Payload) ++ ", handler accepts " ++ @typeName(Expected));
    }
}
