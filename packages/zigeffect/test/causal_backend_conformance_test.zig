const std = @import("std");
const fx = @import("zigeffect");
const conformance = @import("support/causal_backend_conformance.zig");

test "causal backend conformance captures only stored sanitized events" {
    var backend_state = conformance.CaptureBackendState.init(std.testing.allocator);
    defer backend_state.deinit();

    var store = fx.CausalStore.initWithOptions(std.testing.allocator, conformance.standardStoreOptions());
    store.attachBackend(backend_state.backend(.memory));
    defer store.deinit();

    const ids = try conformance.recordStandardTrace(&store);
    try conformance.expectStandardStorePosture(&store, ids);

    try std.testing.expectEqual(@as(usize, 3), backend_state.events.items.len);
    try std.testing.expectEqual(ids.started, backend_state.events.items[0].id);
    try std.testing.expectEqual(ids.retained_log, backend_state.events.items[1].id);
    try std.testing.expectEqual(ids.completed, backend_state.events.items[2].id);
    try std.testing.expectEqual(fx.CausalEventKind.run_started, backend_state.events.items[0].kind);
    try std.testing.expectEqual(fx.CausalEventKind.log_recorded, backend_state.events.items[1].kind);
    try std.testing.expectEqual(fx.CausalEventKind.run_completed, backend_state.events.items[2].kind);
    try std.testing.expect(std.mem.indexOf(u8, backend_state.events.items[0].label, "raw-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, backend_state.events.items[0].label, fx.causal_redaction_marker) != null);
    try std.testing.expect(std.mem.indexOf(u8, backend_state.events.items[0].label, fx.causal_truncation_marker) != null);
    try std.testing.expect(backend_state.events.items[0].label.len <= conformance.standard_max_event_string_bytes);
}

test "causal backend conformance counts backend failures without perturbing store" {
    var backend_state = conformance.FailingBackendState{};

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend(.json_lines));
    defer store.deinit();

    const first = try store.record(.{ .kind = .run_started, .label = "failing-backend" });
    const second = try store.record(.{
        .kind = .run_completed,
        .parent_id = first,
        .label = "failing-backend",
        .status = "success",
    });

    try std.testing.expectEqual(@as(u64, 2), second);
    try std.testing.expectEqual(@as(u64, 2), backend_state.attempted_count);
    try std.testing.expectEqual(@as(u64, 2), store.backendFailureCount());

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 2), snapshot.events.len);
    try std.testing.expectEqual(first, snapshot.events[0].id);
    try std.testing.expectEqual(second, snapshot.events[1].id);

    const report = try fx.formatCausalReport(std.testing.allocator, "backend failure", &store);
    defer std.testing.allocator.free(report);
    try std.testing.expect(std.mem.indexOf(u8, report, "backend: kind=json_lines failed_writes=2") != null);

    const ci_report = try fx.formatCausalCiReport(std.testing.allocator, "backend failure", &store);
    defer std.testing.allocator.free(ci_report);
    try std.testing.expect(std.mem.indexOf(u8, ci_report, "backend: kind=json_lines failed_writes=2") != null);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"backend\": {") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"kind\": \"json_lines\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"failed_writes\": 2") != null);
}

test "causal backend fanout delivers one runtime stream to history live and telemetry adapters" {
    var history = conformance.CaptureBackendState.init(std.testing.allocator);
    defer history.deinit();
    var telemetry = conformance.CaptureBackendState.init(std.testing.allocator);
    defer telemetry.deinit();
    var failing = conformance.FailingBackendState{};

    const backends = [_]fx.CausalBackend{
        history.backend(.nendb_graph),
        failing.backend(.async_stream),
        telemetry.backend(.opentelemetry),
    };
    var fanout = fx.CausalFanoutBackendState.init(&backends);

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    store.attachBackend(fanout.backend());

    _ = try store.record(.{ .kind = .run_started, .label = "fanout" });
    _ = try store.record(.{ .kind = .run_completed, .label = "fanout", .status = "success" });

    try std.testing.expectEqual(fx.CausalBackendKind.fanout, store.attachedBackendKind().?);
    try std.testing.expectEqual(@as(usize, 2), history.events.items.len);
    try std.testing.expectEqual(@as(usize, 2), telemetry.events.items.len);
    try std.testing.expectEqual(@as(u64, 6), fanout.attemptedWriteCount());
    try std.testing.expectEqual(@as(u64, 4), fanout.successfulWriteCount());
    try std.testing.expectEqual(@as(u64, 2), fanout.failedWriteCount());
    // A failed exporter is visible but never perturbs the originating effect or
    // prevents the remaining exporters from receiving the event.
    try std.testing.expectEqual(@as(u64, 2), store.backendFailureCount());
}
