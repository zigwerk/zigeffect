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

fn cloneSlice(allocator: Allocator, value: []const u8) Allocator.Error![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

fn cloneEvent(allocator: Allocator, event: CausalEvent) Allocator.Error!CausalEvent {
    var owned = event;
    owned.label = try cloneSlice(allocator, event.label);
    errdefer if (owned.label.len > 0) allocator.free(owned.label);
    owned.type_name = try cloneSlice(allocator, event.type_name);
    errdefer if (owned.type_name.len > 0) allocator.free(owned.type_name);
    owned.status = try cloneSlice(allocator, event.status);
    errdefer if (owned.status.len > 0) allocator.free(owned.status);
    owned.redacted_detail = try cloneSlice(allocator, event.redacted_detail);
    errdefer if (owned.redacted_detail.len > 0) allocator.free(owned.redacted_detail);
    return owned;
}

fn deinitEventStrings(allocator: Allocator, event: CausalEvent) void {
    if (event.label.len > 0) allocator.free(event.label);
    if (event.type_name.len > 0) allocator.free(event.type_name);
    if (event.status.len > 0) allocator.free(event.status);
    if (event.redacted_detail.len > 0) allocator.free(event.redacted_detail);
}

pub const CausalSnapshot = struct {
    allocator: Allocator,
    events: []CausalEvent,

    pub fn deinit(self: *CausalSnapshot) void {
        for (self.events) |event| {
            deinitEventStrings(self.allocator, event);
        }
        self.allocator.free(self.events);
    }
};

pub const CausalLineage = struct {
    allocator: Allocator,
    events: []CausalEvent,

    pub fn deinit(self: *CausalLineage) void {
        for (self.events) |event| {
            deinitEventStrings(self.allocator, event);
        }
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
        for (self.events.items) |event| {
            deinitEventStrings(self.allocator, event);
        }
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
        var owned = try cloneEvent(self.allocator, event);
        errdefer deinitEventStrings(self.allocator, owned);
        owned.id = self.next_event_id;
        self.next_event_id += 1;
        try self.events.append(self.allocator, owned);
        return owned.id;
    }

    pub fn snapshot(self: *const CausalStore, allocator: Allocator) Allocator.Error!CausalSnapshot {
        const events = try allocator.alloc(CausalEvent, self.events.items.len);
        errdefer allocator.free(events);

        var initialized: usize = 0;
        errdefer {
            for (events[0..initialized]) |event| {
                deinitEventStrings(allocator, event);
            }
        }

        for (self.events.items, 0..) |event, index| {
            events[index] = try cloneEvent(allocator, event);
            initialized += 1;
        }

        return .{ .allocator = allocator, .events = events };
    }

    pub fn lineage(self: *const CausalStore, allocator: Allocator, event_id: u64) Allocator.Error!CausalLineage {
        var output = std.ArrayList(CausalEvent).empty;
        errdefer {
            for (output.items) |event| {
                deinitEventStrings(allocator, event);
            }
            output.deinit(allocator);
        }

        for (self.events.items) |event| {
            if (event.id == event_id or event.parent_id == event_id) {
                {
                    const cloned = try cloneEvent(allocator, event);
                    errdefer deinitEventStrings(allocator, cloned);
                    try output.append(allocator, cloned);
                }
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
