const std = @import("std");

pub const Allocator = std.mem.Allocator;

pub const CausalEventKind = enum {
    run_started,
    run_completed,
    effect_started,
    effect_completed,
    layer_started,
    layer_completed,
    service_required,
    service_provided,
    service_replaced,
    scope_opened,
    scope_closed,
    resource_acquired,
    resource_finalized,
    fiber_forked,
    fiber_started,
    fiber_joined,
    fiber_interrupted,
    schedule_decision,
    exit_recorded,
    log_recorded,
    metric_recorded,
    span_recorded,
    assertion_recorded,
};

pub const CausalEvent = struct {
    id: u64 = 0,
    kind: CausalEventKind,
    run_id: ?u64 = null,
    parent_id: ?u64 = null,
    fiber_id: ?u64 = null,
    scope_id: ?u64 = null,
    trace_id: ?u64 = null,
    span_id: ?u64 = null,
    label: []const u8 = "",
    type_name: []const u8 = "",
    status: []const u8 = "",
    redacted_detail: []const u8 = "",
};

pub const CausalSnapshot = struct {
    allocator: Allocator,
    events: []CausalEvent,

    pub fn deinit(self: *CausalSnapshot) void {
        self.allocator.free(self.events);
    }
};

pub const CausalLineage = struct {
    allocator: Allocator,
    events: []CausalEvent,

    pub fn deinit(self: *CausalLineage) void {
        self.allocator.free(self.events);
    }
};

pub const CausalStore = struct {
    allocator: Allocator,
    next_event_id: u64 = 1,
    next_run_id_value: u64 = 1,
    next_scope_id_value: u64 = 1,
    events: std.ArrayList(CausalEvent) = .empty,

    pub fn init(allocator: Allocator) CausalStore {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *CausalStore) void {
        self.events.deinit(self.allocator);
    }

    pub fn nextRunId(self: *CausalStore) u64 {
        const id = self.next_run_id_value;
        self.next_run_id_value += 1;
        return id;
    }

    pub fn nextScopeId(self: *CausalStore) u64 {
        const id = self.next_scope_id_value;
        self.next_scope_id_value += 1;
        return id;
    }

    pub fn record(self: *CausalStore, event: CausalEvent) Allocator.Error!u64 {
        var owned = event;
        owned.id = self.next_event_id;
        self.next_event_id += 1;
        try self.events.append(self.allocator, owned);
        return owned.id;
    }

    pub fn snapshot(self: *const CausalStore, allocator: Allocator) Allocator.Error!CausalSnapshot {
        const events = try allocator.dupe(CausalEvent, self.events.items);
        return .{ .allocator = allocator, .events = events };
    }

    pub fn lineage(self: *const CausalStore, allocator: Allocator, event_id: u64) Allocator.Error!CausalLineage {
        var output = std.ArrayList(CausalEvent).empty;
        errdefer output.deinit(allocator);

        for (self.events.items) |event| {
            if (event.id == event_id or event.parent_id == event_id) {
                try output.append(allocator, event);
            }
        }

        return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
    }
};

fn appendOptionalU64(output: *std.ArrayList(u8), allocator: Allocator, value: ?u64) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

pub fn formatCausalReport(
    allocator: Allocator,
    label: []const u8,
    store: *const CausalStore,
) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.print(allocator, "zigeffect causal report\nprogram: {s}\n", .{label});
    try output.print(allocator, "events: {d}\n", .{store.events.items.len});

    for (store.events.items) |event| {
        try output.print(
            allocator,
            "event: id={d} kind={s} run=",
            .{ event.id, @tagName(event.kind) },
        );
        try appendOptionalU64(&output, allocator, event.run_id);
        try output.appendSlice(allocator, " parent=");
        try appendOptionalU64(&output, allocator, event.parent_id);
        if (event.fiber_id != null) {
            try output.appendSlice(allocator, " fiber=");
            try appendOptionalU64(&output, allocator, event.fiber_id);
        }
        if (event.scope_id != null) {
            try output.appendSlice(allocator, " scope=");
            try appendOptionalU64(&output, allocator, event.scope_id);
        }
        if (event.trace_id != null) {
            try output.appendSlice(allocator, " trace=");
            try appendOptionalU64(&output, allocator, event.trace_id);
        }
        if (event.span_id != null) {
            try output.appendSlice(allocator, " span=");
            try appendOptionalU64(&output, allocator, event.span_id);
        }
        if (event.label.len > 0) try output.print(allocator, " label={s}", .{event.label});
        if (event.type_name.len > 0) try output.print(allocator, " type={s}", .{event.type_name});
        if (event.status.len > 0) try output.print(allocator, " status={s}", .{event.status});
        if (event.redacted_detail.len > 0) try output.print(allocator, " detail={s}", .{event.redacted_detail});
        try output.appendSlice(allocator, "\n");
    }

    return output.toOwnedSlice(allocator);
}
