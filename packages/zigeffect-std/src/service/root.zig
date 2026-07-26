const std = @import("std");
const fx = @import("zigeffect");

/// Resolve a declared canonical service tag as an effect description.
pub fn access(comptime Tag: type) fx.kernel.Effect(*Tag.API, error{}, .{Tag}) {
    return fx.kernel.Effect(*Tag.API, error{}, .{Tag}).fromFn(struct {
        fn run(ctx: *fx.kernel.ContextView(.{Tag})) error{}!*Tag.API {
            return ctx.service(Tag);
        }
    }.run);
}

pub fn serviceKey(comptime Service: type) []const u8 {
    return if (@hasDecl(Service, "service_key")) Service.service_key else @typeName(Service);
}

/// The argument a delegated operation carries from its caller to its handler.
///
/// A method taking only `self` carries nothing, the common single-argument case
/// carries that value directly, and anything wider carries a tuple. Collapsing
/// the first two cases is what keeps `call(id)` from degrading into
/// `call(.{id})` for the operations applications actually write.
fn DelegateState(comptime params: []const std.builtin.Type.Fn.Param) type {
    return switch (params.len) {
        1 => void,
        2 => params[1].type.?,
        else => state: {
            var fields: [params.len - 1]type = undefined;
            for (params[1..], 0..) |param, index| fields[index] = param.type.?;
            break :state std.meta.Tuple(&fields);
        },
    };
}

/// Describe a service method as a named effect.
///
/// Most operations on a service facade are pure delegation: resolve the tag,
/// call one method, let the runtime record it. Written by hand that costs three
/// type aliases and a wrapper struct per operation, which buries the one line
/// that carries meaning and gives every operation a chance to declare a
/// different label, failure set or requirement than the method it forwards to.
///
/// Deriving all of it from the method's own signature makes the description
/// impossible to get out of step with the implementation:
///
///     pub const Create = zstd.Service.Delegate(TodoService, "create", "TodoService.create");
///     pub const create = Create.call;
///
/// The label is explicit rather than derived because it is the stable identity
/// an agent queries the causal graph by, and it must survive a Zig rename.
/// Operations that are more than delegation should still be written out; this
/// removes ceremony, not the ability to express something real.
pub fn Delegate(
    comptime Tag: type,
    comptime method_name: []const u8,
    comptime label: []const u8,
) type {
    if (!@hasDecl(Tag.API, method_name)) {
        @compileError("service " ++ serviceKey(Tag) ++ " has no method '" ++ method_name ++ "'");
    }
    const method = @field(Tag.API, method_name);
    const info = @typeInfo(@TypeOf(method));
    if (info != .@"fn") @compileError("'" ++ method_name ++ "' is not a method of " ++ serviceKey(Tag));
    const fn_info = info.@"fn";
    if (fn_info.params.len == 0 or fn_info.params[0].type != *Tag.API) {
        @compileError("'" ++ method_name ++ "' must take *" ++ @typeName(Tag.API) ++ " as its first parameter");
    }
    const Return = fn_info.return_type.?;
    const return_info = @typeInfo(Return);
    if (return_info != .error_union) {
        @compileError("'" ++ method_name ++ "' must return an error union so the effect has a typed failure");
    }

    const Success = return_info.error_union.payload;
    const Failure = return_info.error_union.error_set;
    const State = DelegateState(fn_info.params);
    const Program = fx.kernel.Effect(Success, Failure, .{Tag}).Stateful(State);

    return struct {
        pub const Effect = fx.kernel.NamedEffect(Program);
        pub const SuccessType = Success;
        pub const FailureType = Failure;
        pub const StateType = State;
        pub const operation_label = label;

        /// A method taking only `self` is called as `call()`, not `call({})`.
        pub const call = if (State == void) callWithoutState else callWithState;

        fn describe(state: State) Effect {
            return Program.init(state, struct {
                fn run(value: State, ctx: *Program.Context) Failure!Success {
                    const api = ctx.service(Tag);
                    return switch (comptime fn_info.params.len) {
                        1 => @call(.auto, method, .{api}),
                        2 => @call(.auto, method, .{ api, value }),
                        else => @call(.auto, method, .{api} ++ value),
                    };
                }
            }.run).named(label);
        }

        fn callWithoutState() Effect {
            return describe({});
        }

        fn callWithState(state: State) Effect {
            return describe(state);
        }
    };
}

/// Semantic operation identity returned by `beginOperation`. Completion facts
/// point directly at this event, so an application snapshot can reconstruct an
/// external call without log-message correlation.
pub const Operation = struct {
    event_id: ?u64,
    service_key: []const u8,
    label: []const u8,
};

pub fn beginOperation(
    ctx: anytype,
    stable_service_key: []const u8,
    label: []const u8,
    redacted_detail: []const u8,
) Operation {
    return .{
        .event_id = ctx.recordCausal(.{
            .kind = .io_wait_started,
            .service_key = stable_service_key,
            .label = label,
            .status = "running",
            .redacted_detail = redacted_detail,
        }),
        .service_key = stable_service_key,
        .label = label,
    };
}

pub fn completeOperation(
    ctx: anytype,
    operation: Operation,
    status: []const u8,
    redacted_detail: []const u8,
) ?u64 {
    return ctx.recordCausal(.{
        .kind = .io_completed,
        .parent_id = operation.event_id,
        .cause_event_id = if (std.mem.eql(u8, status, "failure")) operation.event_id else null,
        .service_key = operation.service_key,
        .label = operation.label,
        .status = status,
        .redacted_detail = redacted_detail,
    });
}

pub fn recordSemantic(
    ctx: anytype,
    kind: fx.CausalEventKind,
    stable_service_key: []const u8,
    label: []const u8,
    status: []const u8,
    redacted_detail: []const u8,
) ?u64 {
    return ctx.recordCausal(.{
        .kind = kind,
        .service_key = stable_service_key,
        .label = label,
        .status = status,
        .redacted_detail = redacted_detail,
    });
}

pub fn recordRequired(ctx: anytype, comptime Service: type, detail: []const u8) ?u64 {
    return ctx.recordCausal(.{
        .kind = .service_required,
        .service_key = serviceKey(Service),
        .status = "required",
        .redacted_detail = detail,
    });
}

pub fn recordProvided(ctx: anytype, comptime Service: type, detail: []const u8) ?u64 {
    return ctx.recordCausal(.{
        .kind = .service_provided,
        .service_key = serviceKey(Service),
        .status = "provided",
        .redacted_detail = detail,
    });
}

pub fn recordOperation(
    ctx: anytype,
    comptime Service: type,
    operation: []const u8,
    status: []const u8,
    detail: []const u8,
) ?u64 {
    return ctx.recordCausal(.{
        .kind = .span_recorded,
        .service_key = serviceKey(Service),
        .label = operation,
        .status = status,
        .redacted_detail = detail,
    });
}

pub fn findOperation(
    snapshot: anytype,
    comptime Service: type,
    operation: []const u8,
    status: ?[]const u8,
) ?usize {
    for (snapshot.events, 0..) |event, index| {
        if (event.kind != .span_recorded and event.kind != .log_recorded and event.kind != .metric_recorded) continue;
        if (!std.mem.eql(u8, event.service_key, serviceKey(Service))) continue;
        if (!std.mem.eql(u8, event.label, operation)) continue;
        if (status) |expected_status| {
            if (!std.mem.eql(u8, event.status, expected_status)) continue;
        }
        return index;
    }
    return null;
}

pub fn hasOperation(snapshot: anytype, comptime Service: type, operation: []const u8, status: ?[]const u8) bool {
    return findOperation(snapshot, Service, operation, status) != null;
}

const GreetingService = fx.kernel.Service("zigeffect-std/test/Greeting", struct {
    prefix: []const u8,
});

const CounterError = error{ Underflow, Overflow };

const CounterService = fx.kernel.Service("zigeffect-std/test/Counter", struct {
    const Api = @This();
    value: i64 = 0,
    limit: i64 = 10,

    pub fn read(self: *Api) CounterError!i64 {
        return self.value;
    }

    pub fn add(self: *Api, amount: i64) CounterError!i64 {
        const next = self.value + amount;
        if (next > self.limit) return error.Overflow;
        self.value = next;
        return next;
    }

    pub fn addTwice(self: *Api, first: i64, second: i64) CounterError!i64 {
        _ = try self.add(first);
        return self.add(second);
    }

    pub fn reset(self: *Api) CounterError!void {
        if (self.value == 0) return error.Underflow;
        self.value = 0;
    }
});

test "Service.Delegate derives a named effect from the method it forwards to" {
    const Read = Delegate(CounterService, "read", "Counter.read");
    const Add = Delegate(CounterService, "add", "Counter.add");
    const AddTwice = Delegate(CounterService, "addTwice", "Counter.addTwice");
    const Reset = Delegate(CounterService, "reset", "Counter.reset");

    // Success, failure and argument types come off the method, so a description
    // cannot drift from the implementation it names.
    try std.testing.expectEqual(i64, Read.SuccessType);
    try std.testing.expectEqual(CounterError, Read.FailureType);
    try std.testing.expectEqual(void, Read.StateType);
    try std.testing.expectEqual(i64, Add.StateType);
    try std.testing.expectEqual(void, Reset.SuccessType);
    try std.testing.expectEqual(std.meta.Tuple(&.{ i64, i64 }), AddTwice.StateType);

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    const layer = fx.kernel.Layer.succeed(CounterService, .{});
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(layer)).make(
        std.testing.allocator,
        layer,
        .{ .causal_store = &store },
    );
    defer runtime.deinit();

    // A method taking only self is invoked without a state argument.
    try std.testing.expectEqual(@as(i64, 0), try runtime.run(Read.call()));
    try std.testing.expectEqual(@as(i64, 3), try runtime.run(Add.call(3)));
    try std.testing.expectEqual(@as(i64, 9), try runtime.run(AddTwice.call(.{ 2, 4 })));
    // Typed failures propagate unchanged rather than being widened.
    try std.testing.expectError(error.Overflow, runtime.run(Add.call(5)));
    try runtime.run(Reset.call());
    try std.testing.expectError(error.Underflow, runtime.run(Reset.call()));

    // The explicit label is what the runtime records, so it stays queryable
    // even though the Zig method name is separate from it.
    var saw_named_success = false;
    var saw_named_failure = false;
    for (store.events.items) |event| {
        if (!std.mem.eql(u8, event.label, "Counter.add")) continue;
        if (std.mem.eql(u8, event.status, "success")) saw_named_success = true;
        if (std.mem.eql(u8, event.status, "failure")) saw_named_failure = true;
    }
    try std.testing.expect(saw_named_success);
    try std.testing.expect(saw_named_failure);
}

test "Service.access resolves a canonical tagged service through ManagedRuntime" {
    const layer = fx.kernel.Layer.succeed(GreetingService, .{ .prefix = "hello" });
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(layer)).make(std.testing.allocator, layer, .{});
    defer runtime.deinit();

    const resolved = try runtime.run(access(GreetingService));
    try std.testing.expectEqualStrings("hello", resolved.prefix);
}

test "Service semantic helpers record through the runtime-owned causal pipeline" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    const layer = fx.kernel.Layer.succeed(GreetingService, .{ .prefix = "hello" });
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(layer)).make(std.testing.allocator, layer, .{
        .causal_store = &store,
    });
    defer runtime.deinit();

    const Emit = fx.kernel.Effect(void, error{}, .{GreetingService});
    try runtime.run(Emit.fromFn(struct {
        fn run(ctx: *Emit.Context) error{}!void {
            _ = recordRequired(ctx, GreetingService, "read greeting");
            _ = recordProvided(ctx, GreetingService, "test layer");
            _ = recordOperation(ctx, GreetingService, "Greeting.read", "success", "bounded metadata");
        }
    }.run));

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(hasOperation(snapshot, GreetingService, "Greeting.read", "success"));
}
