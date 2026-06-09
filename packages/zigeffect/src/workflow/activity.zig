const std = @import("std");
const dep_services = @import("../dependency/services.zig");
const schedule_mod = @import("../effect/schedule.zig");

pub const Allocator = std.mem.Allocator;
pub const Schedule = schedule_mod.Schedule;
pub const ServiceSet = dep_services.ServiceSet;

pub const ActivityMetadata = struct {
    name: []const u8,
    payload_type_name: []const u8,
    success_type_name: []const u8,
    failure_type_name: []const u8,
    env_type_name: []const u8,
    requirement_count: usize,
    has_idempotency_key: bool,
    has_retry_schedule: bool,
    retry_schedule_label: []const u8,
    timeout_ms: ?u64,
    compensation_name: []const u8,
};

pub const ActivityDefinitionError = error{
    MissingActivityIdempotencyKey,
};

fn hasValue(comptime value: anytype) bool {
    return @TypeOf(value) != @TypeOf(null);
}

fn activityIdempotencyKeyFunctionInfo(comptime callback: anytype) std.builtin.Type.Fn {
    return switch (@typeInfo(@TypeOf(callback))) {
        .@"fn" => |fn_info| fn_info,
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => |fn_info| fn_info,
            else => @compileError(
                "zigeffect invalid activity idempotency key callback\n\n" ++
                    "Expected: fn (std.mem.Allocator, Payload) anyerror![]const u8.",
            ),
        },
        else => @compileError(
            "zigeffect invalid activity idempotency key callback\n\n" ++
                "Expected: fn (std.mem.Allocator, Payload) anyerror![]const u8.",
        ),
    };
}

fn assertActivityIdempotencyKeyCallback(comptime Payload: type, comptime callback: anytype) void {
    const fn_info = activityIdempotencyKeyFunctionInfo(callback);
    if (fn_info.params.len != 2) {
        @compileError(
            "zigeffect invalid activity idempotency key callback\n\n" ++
                "Expected exactly two parameters: std.mem.Allocator, Payload.",
        );
    }
    if (fn_info.params[0].type == null or fn_info.params[0].type.? != Allocator) {
        @compileError(
            "zigeffect invalid activity idempotency key callback\n\n" ++
                "First parameter must be std.mem.Allocator.",
        );
    }
    if (fn_info.params[1].type == null or fn_info.params[1].type.? != Payload) {
        @compileError(
            "zigeffect invalid activity idempotency key callback\n\n" ++
                "Second parameter must be " ++ @typeName(Payload) ++ ".",
        );
    }
    const ReturnType = fn_info.return_type orelse @compileError(
        "zigeffect invalid activity idempotency key callback\n\n" ++
            "Expected return type: anyerror![]const u8.",
    );
    switch (@typeInfo(ReturnType)) {
        .error_union => |error_union| {
            if (error_union.payload != []const u8) {
                @compileError(
                    "zigeffect invalid activity idempotency key callback\n\n" ++
                        "Expected return payload: []const u8.",
                );
            }
        },
        else => @compileError(
            "zigeffect invalid activity idempotency key callback\n\n" ++
                "Expected return type: anyerror![]const u8.",
        ),
    }
}

fn retryScheduleLabel(comptime RetrySchedule: anytype) []const u8 {
    if (comptime !hasValue(RetrySchedule)) return "";
    var schedule = RetrySchedule;
    return schedule.labelOrKind();
}

fn timeoutValue(comptime TimeoutMs: anytype) ?u64 {
    if (comptime !hasValue(TimeoutMs)) return null;
    return TimeoutMs;
}

fn compensationValue(comptime CompensationName: anytype) []const u8 {
    if (comptime !hasValue(CompensationName)) return "";
    return CompensationName;
}

fn ActivityDefinition(
    comptime Name: []const u8,
    comptime Payload: type,
    comptime Success: type,
    comptime Failure: type,
    comptime Env: type,
    comptime IdempotencyKeyFn: anytype,
    comptime RetrySchedule: anytype,
    comptime TimeoutMs: anytype,
    comptime CompensationName: anytype,
    comptime Requirements: anytype,
) type {
    dep_services.assertServiceTuple("Activity.requires", Requirements);

    return struct {
        const Self = @This();

        pub const name = Name;
        pub const PayloadType = Payload;
        pub const SuccessType = Success;
        pub const FailureType = Failure;
        pub const EnvType = Env;
        pub const RequiredServices = Requirements;

        pub fn metadata() ActivityMetadata {
            return .{
                .name = Name,
                .payload_type_name = @typeName(Payload),
                .success_type_name = @typeName(Success),
                .failure_type_name = @typeName(Failure),
                .env_type_name = @typeName(Env),
                .requirement_count = Requirements.len,
                .has_idempotency_key = hasValue(IdempotencyKeyFn),
                .has_retry_schedule = hasValue(RetrySchedule),
                .retry_schedule_label = retryScheduleLabel(RetrySchedule),
                .timeout_ms = timeoutValue(TimeoutMs),
                .compensation_name = compensationValue(CompensationName),
            };
        }

        pub fn withIdempotencyKey(comptime callback: anytype) type {
            assertActivityIdempotencyKeyCallback(Payload, callback);
            return ActivityDefinition(Name, Payload, Success, Failure, Env, callback, RetrySchedule, TimeoutMs, CompensationName, Requirements);
        }

        pub fn withRetrySchedule(comptime schedule: Schedule) type {
            return ActivityDefinition(Name, Payload, Success, Failure, Env, IdempotencyKeyFn, schedule, TimeoutMs, CompensationName, Requirements);
        }

        pub fn withTimeoutMs(comptime timeout_ms: u64) type {
            return ActivityDefinition(Name, Payload, Success, Failure, Env, IdempotencyKeyFn, RetrySchedule, timeout_ms, CompensationName, Requirements);
        }

        pub fn withCompensation(comptime compensation_name: []const u8) type {
            return ActivityDefinition(Name, Payload, Success, Failure, Env, IdempotencyKeyFn, RetrySchedule, TimeoutMs, compensation_name, Requirements);
        }

        pub fn requires(comptime services: anytype) type {
            dep_services.assertServiceTuple("Activity.requires", services);
            return ActivityDefinition(Name, Payload, Success, Failure, Env, IdempotencyKeyFn, RetrySchedule, TimeoutMs, CompensationName, services);
        }

        pub fn requiredServices(allocator: Allocator) Allocator.Error!ServiceSet {
            return ServiceSet.fromTypes(allocator, Requirements);
        }

        pub fn idempotencyKey(allocator: Allocator, payload: Payload) ![]const u8 {
            if (comptime !hasValue(IdempotencyKeyFn)) {
                @compileError(
                    "zigeffect activity idempotency key callback missing\n\n" ++
                        "Use Activity(...).withIdempotencyKey(callback).",
                );
            }
            return IdempotencyKeyFn(allocator, payload);
        }

        pub fn retrySchedule() ?Schedule {
            if (comptime !hasValue(RetrySchedule)) return null;
            return RetrySchedule;
        }

        pub fn format(allocator: Allocator) Allocator.Error![]const u8 {
            const meta = Self.metadata();
            var output = std.ArrayList(u8).empty;
            errdefer output.deinit(allocator);

            try output.print(allocator, "activity: {s}\n", .{meta.name});
            try output.print(allocator, "payload: {s}\n", .{meta.payload_type_name});
            try output.print(allocator, "success: {s}\n", .{meta.success_type_name});
            try output.print(allocator, "failure: {s}\n", .{meta.failure_type_name});
            try output.print(allocator, "env: {s}\n", .{meta.env_type_name});
            try output.print(allocator, "requirements: {d}\n", .{meta.requirement_count});
            try output.print(allocator, "idempotency_key: {s}\n", .{if (meta.has_idempotency_key) "configured" else "missing"});
            try output.print(allocator, "retry: {s}\n", .{if (meta.has_retry_schedule) meta.retry_schedule_label else "none"});
            if (meta.timeout_ms) |timeout_ms| {
                try output.print(allocator, "timeout_ms: {d}\n", .{timeout_ms});
            } else {
                try output.appendSlice(allocator, "timeout_ms: none\n");
            }
            try output.print(allocator, "compensation: {s}\n", .{if (meta.compensation_name.len != 0) meta.compensation_name else "none"});

            return output.toOwnedSlice(allocator);
        }
    };
}

pub fn Activity(
    comptime Name: []const u8,
    comptime Payload: type,
    comptime Success: type,
    comptime Failure: type,
    comptime Env: type,
) type {
    return ActivityDefinition(Name, Payload, Success, Failure, Env, null, null, null, null, .{});
}
