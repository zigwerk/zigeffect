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
