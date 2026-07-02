const std = @import("std");
const causal = @import("causal.zig");
const causal_backend = @import("causal_backend.zig");

pub const Allocator = std.mem.Allocator;

pub const CausalAsyncStreamSink = struct {
    state: ?*anyopaque = null,
    on_event: *const fn (?*anyopaque, causal.CausalEvent) anyerror!void,
    flush: ?*const fn (?*anyopaque) anyerror!void = null,
};

pub const CausalAsyncStreamBackendOptions = struct {
    max_events: ?usize = null,
    sink: ?CausalAsyncStreamSink = null,
};

pub const CausalAsyncStreamBackendError = error{
    CausalAsyncStreamBackendFull,
};

pub const CausalAsyncStreamBackendState = struct {
    allocator: Allocator,
    events: std.ArrayList(causal.CausalEvent) = .empty,
    max_events: ?usize = null,
    sink: ?CausalAsyncStreamSink = null,
    accepted_event_count: u64 = 0,
    drained_event_count: u64 = 0,
    failed_event_count: u64 = 0,
    dropped_event_count: u64 = 0,
    flushed_count: u64 = 0,

    pub fn init(allocator: Allocator, options: CausalAsyncStreamBackendOptions) CausalAsyncStreamBackendState {
        return .{
            .allocator = allocator,
            .max_events = options.max_events,
            .sink = options.sink,
        };
    }

    pub fn deinit(self: *CausalAsyncStreamBackendState) void {
        self.clear();
        self.events.deinit(self.allocator);
    }

    pub fn backend(self: *CausalAsyncStreamBackendState) causal_backend.CausalBackend {
        return .{
            .kind = .async_stream,
            .state = self,
            .record = recordAsyncStreamBackend,
        };
    }

    pub fn eventCount(self: *const CausalAsyncStreamBackendState) usize {
        return self.events.items.len;
    }

    pub fn acceptedEventCount(self: *const CausalAsyncStreamBackendState) u64 {
        return self.accepted_event_count;
    }

    pub fn drainedEventCount(self: *const CausalAsyncStreamBackendState) u64 {
        return self.drained_event_count;
    }

    pub fn failedEventCount(self: *const CausalAsyncStreamBackendState) u64 {
        return self.failed_event_count;
    }

    pub fn droppedEventCount(self: *const CausalAsyncStreamBackendState) u64 {
        return self.dropped_event_count;
    }

    pub fn flushedCount(self: *const CausalAsyncStreamBackendState) u64 {
        return self.flushed_count;
    }

    pub fn peekSnapshot(self: *const CausalAsyncStreamBackendState, allocator: Allocator) Allocator.Error!causal.CausalSnapshot {
        return snapshotFromEvents(allocator, self.events.items);
    }

    pub fn drain(self: *CausalAsyncStreamBackendState, allocator: Allocator) Allocator.Error!causal.CausalSnapshot {
        const snapshot = try snapshotFromEvents(allocator, self.events.items);
        const drained_count = self.events.items.len;
        self.clear();
        self.drained_event_count += drained_count;
        return snapshot;
    }

    pub fn clear(self: *CausalAsyncStreamBackendState) void {
        for (self.events.items) |event| {
            deinitEventStrings(self.allocator, event);
        }
        self.events.clearRetainingCapacity();
    }

    pub fn flush(self: *CausalAsyncStreamBackendState) anyerror!void {
        if (self.sink) |sink| {
            if (sink.flush) |flush_sink| {
                try flush_sink(sink.state);
                self.flushed_count += 1;
            }
        }
    }
};

fn cloneSlice(allocator: Allocator, value: []const u8) Allocator.Error![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

pub fn cloneCausalAsyncStreamEvent(allocator: Allocator, event: causal.CausalEvent) Allocator.Error!causal.CausalEvent {
    var owned = event;
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

pub fn deinitCausalAsyncStreamEvent(allocator: Allocator, event: causal.CausalEvent) void {
    deinitEventStrings(allocator, event);
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
        events[index] = try cloneCausalAsyncStreamEvent(allocator, event);
        initialized += 1;
    }

    return .{ .allocator = allocator, .events = events };
}

fn recordAsyncStreamBackend(raw: ?*anyopaque, event: causal.CausalEvent) anyerror!void {
    const state: *CausalAsyncStreamBackendState = @ptrCast(@alignCast(raw.?));
    if (state.max_events) |max_events| {
        if (state.events.items.len >= max_events) {
            state.failed_event_count += 1;
            state.dropped_event_count += 1;
            return error.CausalAsyncStreamBackendFull;
        }
    }

    state.events.ensureUnusedCapacity(state.allocator, 1) catch |err| {
        state.failed_event_count += 1;
        state.dropped_event_count += 1;
        return err;
    };

    const owned = cloneCausalAsyncStreamEvent(state.allocator, event) catch |err| {
        state.failed_event_count += 1;
        state.dropped_event_count += 1;
        return err;
    };
    errdefer deinitEventStrings(state.allocator, owned);

    if (state.sink) |sink| {
        sink.on_event(sink.state, owned) catch |err| {
            state.failed_event_count += 1;
            state.dropped_event_count += 1;
            return err;
        };
    }

    state.events.appendAssumeCapacity(owned);
    state.accepted_event_count += 1;
}
