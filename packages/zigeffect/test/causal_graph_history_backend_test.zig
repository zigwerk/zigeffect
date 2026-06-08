const std = @import("std");
const fx = @import("zigeffect");
const conformance = @import("support/causal_backend_conformance.zig");

fn eventsContainString(events: []const fx.CausalEvent, needle: []const u8) bool {
    for (events) |event| {
        if (std.mem.indexOf(u8, event.label, needle) != null) return true;
        if (std.mem.indexOf(u8, event.type_name, needle) != null) return true;
        if (std.mem.indexOf(u8, event.status, needle) != null) return true;
        if (std.mem.indexOf(u8, event.redacted_detail, needle) != null) return true;
    }
    return false;
}

test "graph history backend preserves queryable history beyond store retention" {
    var backend_state = fx.CausalGraphHistoryBackendState.init(std.testing.allocator, .{});
    defer backend_state.deinit();

    var store = fx.CausalStore.initWithOptions(std.testing.allocator, conformance.standardStoreOptions());
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const ids = try conformance.recordStandardTrace(&store);
    try conformance.expectStandardStorePosture(&store, ids);

    try std.testing.expectEqual(fx.CausalBackendKind.nendb_graph, store.attachedBackendKind().?);
    try std.testing.expectEqual(@as(usize, 3), backend_state.eventCount());
    try std.testing.expectEqual(@as(u64, 3), backend_state.writtenEventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.failedEventCount());
    try std.testing.expectEqual(@as(u64, 0), store.backendFailureCount());

    var store_cause = try store.cause(std.testing.allocator, ids.retained_log);
    defer store_cause.deinit();
    try std.testing.expectEqual(@as(usize, 0), store_cause.events.len);

    var history_cause = try backend_state.cause(std.testing.allocator, ids.retained_log);
    defer history_cause.deinit();
    try std.testing.expectEqual(@as(usize, 2), history_cause.events.len);
    try std.testing.expectEqual(ids.started, history_cause.events[0].id);
    try std.testing.expectEqual(ids.retained_log, history_cause.events[1].id);

    var history_lineage = try backend_state.lineage(std.testing.allocator, ids.started);
    defer history_lineage.deinit();
    try std.testing.expectEqual(@as(usize, 3), history_lineage.events.len);
    try std.testing.expectEqual(ids.started, history_lineage.events[0].id);
    try std.testing.expectEqual(ids.retained_log, history_lineage.events[1].id);
    try std.testing.expectEqual(ids.completed, history_lineage.events[2].id);

    var logs = try backend_state.eventsByKind(std.testing.allocator, .log_recorded);
    defer logs.deinit();
    try std.testing.expectEqual(@as(usize, 1), logs.events.len);
    try std.testing.expectEqual(ids.retained_log, logs.events[0].id);

    var snapshot = try backend_state.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 3), snapshot.events.len);
    try std.testing.expect(eventsContainString(snapshot.events, "raw-secret") == false);
    try std.testing.expect(eventsContainString(snapshot.events, fx.causal_redaction_marker));
    try std.testing.expect(eventsContainString(snapshot.events, fx.causal_truncation_marker));
}

test "graph history backend filters by run scope and fiber" {
    var backend_state = fx.CausalGraphHistoryBackendState.init(std.testing.allocator, .{});
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const run_id = store.nextRunId();
    const other_run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const root = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .label = "graph-history-run",
    });
    _ = try store.record(.{
        .kind = .scope_opened,
        .run_id = run_id,
        .parent_id = root,
        .scope_id = scope_id,
        .status = "opened",
    });
    _ = try store.record(.{
        .kind = .fiber_forked,
        .run_id = run_id,
        .parent_id = root,
        .scope_id = scope_id,
        .fiber_id = 42,
        .status = "pending",
    });
    _ = try store.record(.{
        .kind = .run_started,
        .run_id = other_run_id,
        .label = "other-run",
    });

    var by_run = try backend_state.eventsByRun(std.testing.allocator, run_id);
    defer by_run.deinit();
    try std.testing.expectEqual(@as(usize, 3), by_run.events.len);

    var by_scope = try backend_state.eventsByScope(std.testing.allocator, scope_id);
    defer by_scope.deinit();
    try std.testing.expectEqual(@as(usize, 2), by_scope.events.len);
    try std.testing.expectEqual(scope_id, by_scope.events[0].scope_id.?);
    try std.testing.expectEqual(scope_id, by_scope.events[1].scope_id.?);

    var by_fiber = try backend_state.eventsByFiber(std.testing.allocator, 42);
    defer by_fiber.deinit();
    try std.testing.expectEqual(@as(usize, 1), by_fiber.events.len);
    try std.testing.expectEqual(@as(?u64, 42), by_fiber.events[0].fiber_id);
}

test "graph history backend max_events fails closed without partial history" {
    var backend_state = fx.CausalGraphHistoryBackendState.init(std.testing.allocator, .{ .max_events = 0 });
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const id = try store.record(.{
        .kind = .run_started,
        .label = "overflowing-graph-history",
    });

    try std.testing.expectEqual(@as(u64, 1), id);
    try std.testing.expectEqual(@as(usize, 0), backend_state.eventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.writtenEventCount());
    try std.testing.expectEqual(@as(u64, 1), backend_state.failedEventCount());
    try std.testing.expectEqual(@as(u64, 1), store.backendFailureCount());

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expectEqual(id, snapshot.events[0].id);
}
