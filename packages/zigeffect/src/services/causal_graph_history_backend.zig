const std = @import("std");
const causal = @import("causal.zig");
const causal_backend = @import("causal_backend.zig");

pub const Allocator = std.mem.Allocator;

pub const CausalGraphHistoryBackendOptions = struct {
    max_events: ?usize = null,
};

pub const CausalGraphHistoryBackendError = error{
    CausalGraphHistoryBackendFull,
};

pub const CausalGraphHistoryBackendState = struct {
    allocator: Allocator,
    events: std.ArrayList(causal.CausalEvent) = .empty,
    max_events: ?usize = null,
    written_event_count: u64 = 0,
    failed_event_count: u64 = 0,

    pub fn init(allocator: Allocator, options: CausalGraphHistoryBackendOptions) CausalGraphHistoryBackendState {
        return .{
            .allocator = allocator,
            .max_events = options.max_events,
        };
    }

    pub fn deinit(self: *CausalGraphHistoryBackendState) void {
        for (self.events.items) |event| {
            deinitEventStrings(self.allocator, event);
        }
        self.events.deinit(self.allocator);
    }

    pub fn backend(self: *CausalGraphHistoryBackendState) causal_backend.CausalBackend {
        return .{
            .kind = .nendb_graph,
            .state = self,
            .record = recordGraphHistoryBackend,
        };
    }

    pub fn eventCount(self: *const CausalGraphHistoryBackendState) usize {
        return self.events.items.len;
    }

    pub fn writtenEventCount(self: *const CausalGraphHistoryBackendState) u64 {
        return self.written_event_count;
    }

    pub fn failedEventCount(self: *const CausalGraphHistoryBackendState) u64 {
        return self.failed_event_count;
    }

    pub fn snapshot(self: *const CausalGraphHistoryBackendState, allocator: Allocator) Allocator.Error!causal.CausalSnapshot {
        return snapshotFromEvents(allocator, self.events.items);
    }

    pub fn cause(self: *const CausalGraphHistoryBackendState, allocator: Allocator, event_id: u64) Allocator.Error!causal.CausalLineage {
        var output = std.ArrayList(causal.CausalEvent).empty;
        errdefer deinitEventList(allocator, &output);

        try self.appendCauseChain(allocator, &output, event_id);

        return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
    }

    pub fn lineage(self: *const CausalGraphHistoryBackendState, allocator: Allocator, event_id: u64) Allocator.Error!causal.CausalLineage {
        var output = std.ArrayList(causal.CausalEvent).empty;
        errdefer deinitEventList(allocator, &output);

        for (self.events.items) |event| {
            if (event.id == event_id or event.parent_id == event_id) {
                try appendClonedEvent(allocator, &output, event);
            }
        }

        return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
    }

    pub fn eventsByKind(self: *const CausalGraphHistoryBackendState, allocator: Allocator, kind: causal.CausalEventKind) Allocator.Error!causal.CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: causal.CausalEvent, expected: causal.CausalEventKind) bool {
                return event.kind == expected;
            }
        }.matches, kind);
    }

    pub fn eventsByRun(self: *const CausalGraphHistoryBackendState, allocator: Allocator, run_id: u64) Allocator.Error!causal.CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: causal.CausalEvent, expected: u64) bool {
                return event.run_id == expected;
            }
        }.matches, run_id);
    }

    pub fn eventsByScope(self: *const CausalGraphHistoryBackendState, allocator: Allocator, scope_id: u64) Allocator.Error!causal.CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: causal.CausalEvent, expected: u64) bool {
                return event.scope_id == expected;
            }
        }.matches, scope_id);
    }

    pub fn eventsByFiber(self: *const CausalGraphHistoryBackendState, allocator: Allocator, fiber_id: u64) Allocator.Error!causal.CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: causal.CausalEvent, expected: u64) bool {
                return event.fiber_id == expected;
            }
        }.matches, fiber_id);
    }

    fn findEvent(self: *const CausalGraphHistoryBackendState, event_id: u64) ?causal.CausalEvent {
        for (self.events.items) |event| {
            if (event.id == event_id) return event;
        }
        return null;
    }

    fn appendCauseChain(
        self: *const CausalGraphHistoryBackendState,
        allocator: Allocator,
        output: *std.ArrayList(causal.CausalEvent),
        event_id: u64,
    ) Allocator.Error!void {
        const event = self.findEvent(event_id) orelse return;
        if (event.parent_id) |parent_id| {
            try self.appendCauseChain(allocator, output, parent_id);
        }
        try appendClonedEvent(allocator, output, event);
    }

    fn filterEvents(
        self: *const CausalGraphHistoryBackendState,
        allocator: Allocator,
        comptime matches: anytype,
        expected: anytype,
    ) Allocator.Error!causal.CausalSnapshot {
        var output = std.ArrayList(causal.CausalEvent).empty;
        errdefer deinitEventList(allocator, &output);

        for (self.events.items) |event| {
            if (matches(event, expected)) {
                try appendClonedEvent(allocator, &output, event);
            }
        }

        return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
    }
};

fn cloneSlice(allocator: Allocator, value: []const u8) Allocator.Error![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

fn cloneEvent(allocator: Allocator, event: causal.CausalEvent) Allocator.Error!causal.CausalEvent {
    var owned = event;
    owned._owned_text = &.{};
    owned.label = try cloneSlice(allocator, event.label);
    errdefer if (owned.label.len > 0) allocator.free(owned.label);
    owned.type_name = try cloneSlice(allocator, event.type_name);
    errdefer if (owned.type_name.len > 0) allocator.free(owned.type_name);
    owned.layer_name = try cloneSlice(allocator, event.layer_name);
    errdefer if (owned.layer_name.len > 0) allocator.free(owned.layer_name);
    owned.service_key = try cloneSlice(allocator, event.service_key);
    errdefer if (owned.service_key.len > 0) allocator.free(owned.service_key);
    owned.artifact_id = try cloneSlice(allocator, event.artifact_id);
    errdefer if (owned.artifact_id.len > 0) allocator.free(owned.artifact_id);
    owned.domain_entity_ref = try cloneSlice(allocator, event.domain_entity_ref);
    errdefer if (owned.domain_entity_ref.len > 0) allocator.free(owned.domain_entity_ref);
    owned.data_subject_ref = try cloneSlice(allocator, event.data_subject_ref);
    errdefer if (owned.data_subject_ref.len > 0) allocator.free(owned.data_subject_ref);
    owned.schema_ref = try cloneSlice(allocator, event.schema_ref);
    errdefer if (owned.schema_ref.len > 0) allocator.free(owned.schema_ref);
    owned.status = try cloneSlice(allocator, event.status);
    errdefer if (owned.status.len > 0) allocator.free(owned.status);
    owned.redacted_detail = try cloneSlice(allocator, event.redacted_detail);
    errdefer if (owned.redacted_detail.len > 0) allocator.free(owned.redacted_detail);
    return owned;
}

fn deinitEventStrings(allocator: Allocator, event: causal.CausalEvent) void {
    if (event.label.len > 0) allocator.free(event.label);
    if (event.type_name.len > 0) allocator.free(event.type_name);
    if (event.layer_name.len > 0) allocator.free(event.layer_name);
    if (event.service_key.len > 0) allocator.free(event.service_key);
    if (event.artifact_id.len > 0) allocator.free(event.artifact_id);
    if (event.domain_entity_ref.len > 0) allocator.free(event.domain_entity_ref);
    if (event.data_subject_ref.len > 0) allocator.free(event.data_subject_ref);
    if (event.schema_ref.len > 0) allocator.free(event.schema_ref);
    if (event.status.len > 0) allocator.free(event.status);
    if (event.redacted_detail.len > 0) allocator.free(event.redacted_detail);
}

fn deinitEventList(allocator: Allocator, events: *std.ArrayList(causal.CausalEvent)) void {
    for (events.items) |event| {
        deinitEventStrings(allocator, event);
    }
    events.deinit(allocator);
}

fn appendClonedEvent(allocator: Allocator, output: *std.ArrayList(causal.CausalEvent), event: causal.CausalEvent) Allocator.Error!void {
    const cloned = try cloneEvent(allocator, event);
    errdefer deinitEventStrings(allocator, cloned);
    try output.append(allocator, cloned);
}

fn snapshotFromEvents(allocator: Allocator, source: []const causal.CausalEvent) Allocator.Error!causal.CausalSnapshot {
    const events = try allocator.alloc(causal.CausalEvent, source.len);
    errdefer allocator.free(events);

    var initialized: usize = 0;
    errdefer {
        for (events[0..initialized]) |event| {
            deinitEventStrings(allocator, event);
        }
    }

    for (source, 0..) |event, index| {
        events[index] = try cloneEvent(allocator, event);
        initialized += 1;
    }

    return .{ .allocator = allocator, .events = events };
}

fn recordGraphHistoryBackend(raw: ?*anyopaque, event: causal.CausalEvent) anyerror!void {
    const state: *CausalGraphHistoryBackendState = @ptrCast(@alignCast(raw.?));
    if (state.max_events) |max_events| {
        if (state.events.items.len >= max_events) {
            state.failed_event_count += 1;
            return error.CausalGraphHistoryBackendFull;
        }
    }

    const owned = cloneEvent(state.allocator, event) catch |err| {
        state.failed_event_count += 1;
        return err;
    };
    errdefer deinitEventStrings(state.allocator, owned);

    state.events.append(state.allocator, owned) catch |err| {
        state.failed_event_count += 1;
        return err;
    };
    state.written_event_count += 1;
}
