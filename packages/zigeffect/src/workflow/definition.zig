const std = @import("std");
const dep_services = @import("../dependency/services.zig");

pub const Allocator = std.mem.Allocator;
pub const ServiceSet = dep_services.ServiceSet;

pub const WorkflowMetadata = struct {
    name: []const u8,
    payload_type_name: []const u8,
    success_type_name: []const u8,
    failure_type_name: []const u8,
    env_type_name: []const u8,
    requirement_count: usize,
    has_idempotency_key: bool,
};

pub const WorkflowDefinitionError = error{
    MissingWorkflowIdempotencyKey,
};

fn hasIdempotencyKeyCallback(comptime callback: anytype) bool {
    return @TypeOf(callback) != @TypeOf(null);
}

fn idempotencyKeyFunctionInfo(comptime callback: anytype) std.builtin.Type.Fn {
    return switch (@typeInfo(@TypeOf(callback))) {
        .@"fn" => |fn_info| fn_info,
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => |fn_info| fn_info,
            else => @compileError(
                "zigeffect invalid workflow idempotency key callback\n\n" ++
                    "Expected: fn (std.mem.Allocator, Payload) anyerror![]const u8.",
            ),
        },
        else => @compileError(
            "zigeffect invalid workflow idempotency key callback\n\n" ++
                "Expected: fn (std.mem.Allocator, Payload) anyerror![]const u8.",
        ),
    };
}

fn assertIdempotencyKeyCallback(comptime Payload: type, comptime callback: anytype) void {
    const fn_info = idempotencyKeyFunctionInfo(callback);
    if (fn_info.params.len != 2) {
        @compileError(
            "zigeffect invalid workflow idempotency key callback\n\n" ++
                "Expected exactly two parameters: std.mem.Allocator, Payload.",
        );
    }
    if (fn_info.params[0].type == null or fn_info.params[0].type.? != Allocator) {
        @compileError(
            "zigeffect invalid workflow idempotency key callback\n\n" ++
                "First parameter must be std.mem.Allocator.",
        );
    }
    if (fn_info.params[1].type == null or fn_info.params[1].type.? != Payload) {
        @compileError(
            "zigeffect invalid workflow idempotency key callback\n\n" ++
                "Second parameter must be " ++ @typeName(Payload) ++ ".",
        );
    }
    const ReturnType = fn_info.return_type orelse @compileError(
        "zigeffect invalid workflow idempotency key callback\n\n" ++
            "Expected return type: anyerror![]const u8.",
    );
    switch (@typeInfo(ReturnType)) {
        .error_union => |error_union| {
            if (error_union.payload != []const u8) {
                @compileError(
                    "zigeffect invalid workflow idempotency key callback\n\n" ++
                        "Expected return payload: []const u8.",
                );
            }
        },
        else => @compileError(
            "zigeffect invalid workflow idempotency key callback\n\n" ++
                "Expected return type: anyerror![]const u8.",
        ),
    }
}

fn WorkflowDefinition(
    comptime Name: []const u8,
    comptime Payload: type,
    comptime Success: type,
    comptime Failure: type,
    comptime Env: type,
    comptime IdempotencyKeyFn: anytype,
    comptime Requirements: anytype,
) type {
    dep_services.assertServiceTuple("Workflow.requires", Requirements);

    return struct {
        const Self = @This();

        pub const name = Name;
        pub const PayloadType = Payload;
        pub const SuccessType = Success;
        pub const FailureType = Failure;
        pub const EnvType = Env;
        pub const RequiredServices = Requirements;

        pub fn metadata() WorkflowMetadata {
            return .{
                .name = Name,
                .payload_type_name = @typeName(Payload),
                .success_type_name = @typeName(Success),
                .failure_type_name = @typeName(Failure),
                .env_type_name = @typeName(Env),
                .requirement_count = Requirements.len,
                .has_idempotency_key = hasIdempotencyKeyCallback(IdempotencyKeyFn),
            };
        }

        pub fn withIdempotencyKey(comptime callback: anytype) type {
            assertIdempotencyKeyCallback(Payload, callback);
            return WorkflowDefinition(Name, Payload, Success, Failure, Env, callback, Requirements);
        }

        pub fn requires(comptime services: anytype) type {
            dep_services.assertServiceTuple("Workflow.requires", services);
            return WorkflowDefinition(Name, Payload, Success, Failure, Env, IdempotencyKeyFn, services);
        }

        pub fn requiredServices(allocator: Allocator) Allocator.Error!ServiceSet {
            return ServiceSet.fromTypes(allocator, Requirements);
        }

        pub fn idempotencyKey(allocator: Allocator, payload: Payload) ![]const u8 {
            if (comptime !hasIdempotencyKeyCallback(IdempotencyKeyFn)) {
                @compileError(
                    "zigeffect workflow idempotency key callback missing\n\n" ++
                        "Use Workflow(...).withIdempotencyKey(callback).",
                );
            }
            return IdempotencyKeyFn(allocator, payload);
        }

        pub fn deriveExecutionId(allocator: Allocator, payload: Payload) !u64 {
            const key = try Self.idempotencyKey(allocator, payload);
            defer allocator.free(key);

            var hasher = std.hash.Fnv1a_64.init();
            hasher.update(Name);
            hasher.update(":");
            hasher.update(key);
            return hasher.final();
        }
    };
}

pub fn Workflow(
    comptime Name: []const u8,
    comptime Payload: type,
    comptime Success: type,
    comptime Failure: type,
    comptime Env: type,
) type {
    return WorkflowDefinition(Name, Payload, Success, Failure, Env, null, .{});
}
