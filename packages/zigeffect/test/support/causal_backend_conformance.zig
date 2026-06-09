const std = @import("std");
const fx = @import("zigeffect");

pub const standard_max_event_string_bytes: usize = 32;

pub const StandardTraceIds = struct {
    started: u64,
    sampled_log: u64,
    retained_log: u64,
    completed: u64,
};

pub fn standardStoreOptions() fx.CausalStoreOptions {
    return .{
        .max_events = 1,
        .sampling = .{ .log_every_n = 2 },
        .max_event_string_bytes = standard_max_event_string_bytes,
    };
}

fn cloneSlice(allocator: std.mem.Allocator, value: []const u8) ![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

fn cloneEvent(allocator: std.mem.Allocator, event: fx.CausalEvent) !fx.CausalEvent {
    var owned = event;
    owned.label = try cloneSlice(allocator, event.label);
    errdefer if (owned.label.len > 0) allocator.free(owned.label);
    owned.type_name = try cloneSlice(allocator, event.type_name);
    errdefer if (owned.type_name.len > 0) allocator.free(owned.type_name);
    owned.service_key = try cloneSlice(allocator, event.service_key);
    errdefer if (owned.service_key.len > 0) allocator.free(owned.service_key);
    owned.status = try cloneSlice(allocator, event.status);
    errdefer if (owned.status.len > 0) allocator.free(owned.status);
    owned.redacted_detail = try cloneSlice(allocator, event.redacted_detail);
    errdefer if (owned.redacted_detail.len > 0) allocator.free(owned.redacted_detail);
    return owned;
}

fn deinitEventStrings(allocator: std.mem.Allocator, event: fx.CausalEvent) void {
    if (event.label.len > 0) allocator.free(event.label);
    if (event.type_name.len > 0) allocator.free(event.type_name);
    if (event.service_key.len > 0) allocator.free(event.service_key);
    if (event.status.len > 0) allocator.free(event.status);
    if (event.redacted_detail.len > 0) allocator.free(event.redacted_detail);
}

pub const CaptureBackendState = struct {
    allocator: std.mem.Allocator,
    events: std.ArrayList(fx.CausalEvent) = .empty,

    pub fn init(allocator: std.mem.Allocator) CaptureBackendState {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *CaptureBackendState) void {
        for (self.events.items) |event| {
            deinitEventStrings(self.allocator, event);
        }
        self.events.deinit(self.allocator);
    }

    pub fn backend(self: *CaptureBackendState, kind: fx.CausalBackendKind) fx.CausalBackend {
        return .{
            .kind = kind,
            .state = self,
            .record = recordCaptureBackend,
        };
    }
};

fn recordCaptureBackend(raw: ?*anyopaque, event: fx.CausalEvent) anyerror!void {
    const state: *CaptureBackendState = @ptrCast(@alignCast(raw.?));
    const owned = try cloneEvent(state.allocator, event);
    errdefer deinitEventStrings(state.allocator, owned);
    try state.events.append(state.allocator, owned);
}

pub const FailingBackendState = struct {
    attempted_count: u64 = 0,

    pub fn backend(self: *FailingBackendState, kind: fx.CausalBackendKind) fx.CausalBackend {
        return .{
            .kind = kind,
            .state = self,
            .record = recordFailingBackend,
        };
    }
};

fn recordFailingBackend(raw: ?*anyopaque, event: fx.CausalEvent) anyerror!void {
    _ = event;
    const state: *FailingBackendState = @ptrCast(@alignCast(raw.?));
    state.attempted_count += 1;
    return error.CausalBackendWriteFailed;
}

pub fn recordStandardTrace(store: *fx.CausalStore) !StandardTraceIds {
    const run_id = store.nextRunId();
    const started = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .label = "token=raw-secret safe-context-safe-context-safe-context",
        .type_name = "BackendConformanceRun",
    });
    const sampled_log = try store.record(.{
        .kind = .log_recorded,
        .run_id = run_id,
        .parent_id = started,
        .label = "sampled-out-log",
    });
    const retained_log = try store.record(.{
        .kind = .log_recorded,
        .run_id = run_id,
        .parent_id = started,
        .label = "retained-log",
    });
    const completed = try store.record(.{
        .kind = .run_completed,
        .run_id = run_id,
        .parent_id = started,
        .label = "backend-conformance-completed",
        .status = "success",
    });

    return .{
        .started = started,
        .sampled_log = sampled_log,
        .retained_log = retained_log,
        .completed = completed,
    };
}

pub fn expectStandardStorePosture(store: *const fx.CausalStore, ids: StandardTraceIds) !void {
    try std.testing.expectEqual(@as(u64, 2), store.droppedEventCount());
    try std.testing.expectEqual(@as(u64, 1), store.sampledEventCount());
    try std.testing.expectEqual(@as(u64, 1), store.truncatedFieldCount());
    try std.testing.expectEqual(@as(u64, 0), store.backendFailureCount());
    try std.testing.expectEqual(@as(?u64, ids.completed), store.oldestRetainedEventId());
    try std.testing.expectEqual(ids.started + 1, ids.sampled_log);
    try std.testing.expectEqual(ids.started + 2, ids.retained_log);
    try std.testing.expectEqual(ids.started + 3, ids.completed);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expectEqual(ids.completed, snapshot.events[0].id);
}
