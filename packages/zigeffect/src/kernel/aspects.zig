const std = @import("std");
const context_mod = @import("context.zig");
const logger_mod = @import("../services/logger.zig");
const metrics_mod = @import("../services/metrics.zig");
const tracing_mod = @import("../services/tracing.zig");
const causal_mod = @import("../services/causal.zig");

pub const Allocator = std.mem.Allocator;
pub const RuntimeAspect = context_mod.RuntimeAspect;
pub const RuntimeEvent = context_mod.RuntimeEvent;

pub const FiberSupervisor = struct {
    state: ?*anyopaque,
    on_event: *const fn (?*anyopaque, RuntimeEvent) ?u64,

    pub fn from(comptime Implementation: type, implementation: *Implementation) FiberSupervisor {
        return .{
            .state = implementation,
            .on_event = struct {
                fn call(raw: ?*anyopaque, event: RuntimeEvent) ?u64 {
                    const typed: *Implementation = @ptrCast(@alignCast(raw.?));
                    const fiber_id = event.fiber_id orelse return null;
                    switch (event.kind) {
                        .fiber_started => typed.onStart(fiber_id, event.label),
                        .fiber_joined, .fiber_interrupted => typed.onEnd(fiber_id, event.status),
                        else => {},
                    }
                    return null;
                }
            }.call,
        };
    }

    pub fn aspect(self: FiberSupervisor) RuntimeAspect {
        return .{ .state = self.state, .on_event = self.on_event };
    }
};

pub const RuntimeObservability = struct {
    logger: ?*logger_mod.Logger = null,
    metrics: ?*metrics_mod.Metrics = null,
    tracer: ?*tracing_mod.Tracing = null,
    supervisor: ?FiberSupervisor = null,

    fn count(self: RuntimeObservability) usize {
        var total: usize = 0;
        if (self.logger != null) total += 1;
        if (self.metrics != null) total += 1;
        if (self.tracer != null) total += 1;
        if (self.supervisor != null) total += 1;
        return total;
    }
};

fn loggerAspect(logger: *logger_mod.Logger) RuntimeAspect {
    return .{
        .state = logger,
        .on_event = struct {
            fn onEvent(raw: ?*anyopaque, event: RuntimeEvent) ?u64 {
                const service: *logger_mod.Logger = @ptrCast(@alignCast(raw.?));
                const fields = [_]logger_mod.LogField{
                    .{ .key = "event.kind", .value = @tagName(event.kind) },
                    .{ .key = "event.status", .value = event.status },
                    .{ .key = "service.key", .value = event.service_key },
                };
                const level: logger_mod.LogLevel = if (std.mem.eql(u8, event.status, "failure")) .err else .info;
                service.logWithContext(level, event.label, &fields, .{}) catch {};
                return null;
            }
        }.onEvent,
        .on_causal_event = struct {
            fn onEvent(raw: ?*anyopaque, event: causal_mod.CausalEvent) ?u64 {
                const service: *logger_mod.Logger = @ptrCast(@alignCast(raw.?));
                const fields = [_]logger_mod.LogField{
                    .{ .key = "causal.kind", .value = @tagName(event.kind) },
                    .{ .key = "event.status", .value = event.status },
                    .{ .key = "service.key", .value = event.service_key },
                };
                const level: logger_mod.LogLevel = if (std.mem.eql(u8, event.status, "failure")) .err else .info;
                service.logWithContext(level, event.label, &fields, .{
                    .trace_id = event.trace_id,
                    .span_id = event.span_id,
                }) catch {};
                return null;
            }
        }.onEvent,
    };
}

fn metricsAspect(metrics: *metrics_mod.Metrics) RuntimeAspect {
    return .{
        .state = metrics,
        .on_event = struct {
            fn onEvent(raw: ?*anyopaque, event: RuntimeEvent) ?u64 {
                const service: *metrics_mod.Metrics = @ptrCast(@alignCast(raw.?));
                service.increment("zigeffect.runtime.events.total", 1) catch {};
                switch (event.kind) {
                    .run_started => service.increment("zigeffect.runtime.runs.started", 1) catch {},
                    .run_completed => service.increment("zigeffect.runtime.runs.completed", 1) catch {},
                    .effect_started => service.increment("zigeffect.runtime.effects.started", 1) catch {},
                    .effect_completed => service.increment("zigeffect.runtime.effects.completed", 1) catch {},
                    .layer_started => service.increment("zigeffect.runtime.layers.started", 1) catch {},
                    .layer_completed => service.increment("zigeffect.runtime.layers.completed", 1) catch {},
                    .scope_opened => service.increment("zigeffect.runtime.scopes.opened", 1) catch {},
                    .scope_closed => service.increment("zigeffect.runtime.scopes.closed", 1) catch {},
                    .resource_acquired => service.increment("zigeffect.runtime.resources.acquired", 1) catch {},
                    .resource_finalized => service.increment("zigeffect.runtime.resources.finalized", 1) catch {},
                    else => {},
                }
                if (std.mem.eql(u8, event.status, "failure")) {
                    service.increment("zigeffect.runtime.failures.total", 1) catch {};
                }
                return null;
            }
        }.onEvent,
        .on_causal_event = struct {
            fn onEvent(raw: ?*anyopaque, event: causal_mod.CausalEvent) ?u64 {
                const service: *metrics_mod.Metrics = @ptrCast(@alignCast(raw.?));
                service.increment("zigeffect.semantic.events.total", 1) catch {};
                if (std.mem.eql(u8, event.status, "failure")) {
                    service.increment("zigeffect.semantic.failures.total", 1) catch {};
                }
                switch (event.kind) {
                    .io_wait_started => service.increment("zigeffect.semantic.io.started", 1) catch {},
                    .io_completed => service.increment("zigeffect.semantic.io.completed", 1) catch {},
                    .timer_scheduled => service.increment("zigeffect.semantic.timers.scheduled", 1) catch {},
                    .timer_fired => service.increment("zigeffect.semantic.timers.fired", 1) catch {},
                    .log_recorded => service.increment("zigeffect.semantic.logs.total", 1) catch {},
                    .span_recorded => service.increment("zigeffect.semantic.spans.total", 1) catch {},
                    else => {},
                }
                return null;
            }
        }.onEvent,
    };
}

fn tracerAspect(tracer: *tracing_mod.Tracing) RuntimeAspect {
    return .{
        .state = tracer,
        .on_event = struct {
            fn onEvent(raw: ?*anyopaque, event: RuntimeEvent) ?u64 {
                const service: *tracing_mod.Tracing = @ptrCast(@alignCast(raw.?));
                service.event(@tagName(event.kind)) catch {};
                return null;
            }
        }.onEvent,
        .on_causal_event = struct {
            fn onEvent(raw: ?*anyopaque, event: causal_mod.CausalEvent) ?u64 {
                const service: *tracing_mod.Tracing = @ptrCast(@alignCast(raw.?));
                var buffer: [128]u8 = undefined;
                const name = std.fmt.bufPrint(&buffer, "semantic:{s}", .{@tagName(event.kind)}) catch "semantic";
                service.event(name) catch {};
                return null;
            }
        }.onEvent,
    };
}

fn causalKind(kind: context_mod.RuntimeEventKind) causal_mod.CausalEventKind {
    return switch (kind) {
        .runtime_started, .run_started => .run_started,
        .runtime_completed, .run_completed => .run_completed,
        .layer_started => .layer_started,
        .layer_completed => .layer_completed,
        .service_provided => .service_provided,
        .service_required => .service_required,
        .effect_started => .effect_started,
        .effect_completed => .effect_completed,
        .scope_opened => .scope_opened,
        .scope_closed => .scope_closed,
        .resource_acquired => .resource_acquired,
        .resource_finalized => .resource_finalized,
        .fiber_forked => .fiber_forked,
        .fiber_started => .fiber_started,
        .fiber_joined => .fiber_joined,
        .fiber_interrupted => .fiber_interrupted,
    };
}

fn causalAspect(store: *causal_mod.CausalStore) RuntimeAspect {
    return .{
        .state = store,
        .on_event = struct {
            fn onEvent(raw: ?*anyopaque, event: RuntimeEvent) ?u64 {
                const service: *causal_mod.CausalStore = @ptrCast(@alignCast(raw.?));
                return service.record(.{
                    .kind = causalKind(event.kind),
                    .run_id = event.run_id,
                    .parent_id = event.parent_id,
                    .fiber_id = event.fiber_id,
                    .scope_id = event.scope_id,
                    .resource_id = event.resource_id,
                    .cause_event_id = event.cause_event_id,
                    .layer_id = event.layer_id,
                    .layer_name = if (event.kind == .layer_started or event.kind == .layer_completed) event.label else "",
                    .service_key = event.service_key,
                    .label = event.label,
                    .type_name = event.type_name,
                    .status = event.status,
                    .redacted_detail = event.redacted_detail,
                }) catch null;
            }
        }.onEvent,
        .on_causal_event = struct {
            fn onEvent(raw: ?*anyopaque, event: causal_mod.CausalEvent) ?u64 {
                const service: *causal_mod.CausalStore = @ptrCast(@alignCast(raw.?));
                return service.record(event) catch null;
            }
        }.onEvent,
    };
}

pub fn assemble(
    allocator: Allocator,
    custom: []const RuntimeAspect,
    observability: RuntimeObservability,
    causal_store: ?*causal_mod.CausalStore,
) Allocator.Error![]RuntimeAspect {
    const aspects = try allocator.alloc(
        RuntimeAspect,
        custom.len + observability.count() + @as(usize, @intFromBool(causal_store != null)),
    );
    @memcpy(aspects[0..custom.len], custom);

    var index = custom.len;
    if (observability.logger) |logger| {
        aspects[index] = loggerAspect(logger);
        index += 1;
    }
    if (observability.metrics) |metrics| {
        aspects[index] = metricsAspect(metrics);
        index += 1;
    }
    if (observability.tracer) |tracer| {
        aspects[index] = tracerAspect(tracer);
        index += 1;
    }
    if (observability.supervisor) |supervisor| {
        aspects[index] = supervisor.aspect();
        index += 1;
    }
    if (causal_store) |store| {
        aspects[index] = causalAspect(store);
    }
    return aspects;
}
