pub const RuntimeEventKind = enum {
    runtime_started,
    runtime_completed,
    run_started,
    run_completed,
    layer_started,
    layer_completed,
    service_provided,
    service_required,
    effect_started,
    effect_completed,
    scope_opened,
    scope_closed,
    resource_acquired,
    resource_finalized,
    fiber_forked,
    fiber_started,
    fiber_joined,
    fiber_interrupted,
};

pub const RuntimeEvent = struct {
    kind: RuntimeEventKind,
    run_id: ?u64 = null,
    parent_id: ?u64 = null,
    fiber_id: ?u64 = null,
    scope_id: ?u64 = null,
    resource_id: ?u64 = null,
    cause_event_id: ?u64 = null,
    trace_id: ?u64 = null,
    span_id: ?u64 = null,
    /// Allocation-free correlation inherited by structural runtime events.
    context: CausalContextV2 = .{},
    label: []const u8 = "",
    service_key: []const u8 = "",
    status: []const u8 = "",
    type_name: []const u8 = "",
    redacted_detail: []const u8 = "",
    layer_id: ?u64 = null,
};

pub const RuntimeAspect = struct {
    state: ?*anyopaque = null,
    /// Returns an event identity when the aspect is the runtime's lineage
    /// recorder. Ordinary observers return null.
    on_event: *const fn (?*anyopaque, RuntimeEvent) ?u64,
    /// Receives semantic application and standard-library facts on the same
    /// fanout path as structural runtime events. Aspects that only supervise
    /// runtime structure can leave this hook unset.
    on_causal_event: ?*const fn (?*anyopaque, CausalEvent) ?u64 = null,
};

/// Heap-stable event sink attached to scopes owned by the canonical runtime.
/// It keeps scope/resource lifecycle on the same aspect path as effects,
/// layers, fibers, logging, metrics, tracing, and causal recording.
pub const RuntimeSignalSink = struct {
    state: *anyopaque,
    emit_event: *const fn (*anyopaque, RuntimeEvent) ?u64,
    next_scope_id: *const fn (*anyopaque) u64,
    next_resource_id: *const fn (*anyopaque) u64,

    pub fn emit(self: RuntimeSignalSink, event: RuntimeEvent) ?u64 {
        return self.emit_event(self.state, event);
    }

    pub fn nextScopeId(self: RuntimeSignalSink) u64 {
        return self.next_scope_id(self.state);
    }

    pub fn nextResourceId(self: RuntimeSignalSink) u64 {
        return self.next_resource_id(self.state);
    }
};
const causal_mod = @import("../services/causal.zig");

pub const CausalEvent = causal_mod.CausalEvent;
pub const CausalContextV2 = causal_mod.CausalContextV2;
