const std = @import("std");
const fx = @import("zigeffect");
const conformance = @import("support/causal_backend_conformance.zig");

test "formatCausalDot emits graph attributes contextual labels and parent edges" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const run_id = store.nextRunId();
    const started = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .label = "readiness \"quoted\"\nnext",
        .type_name = "DotRun",
        .status = "success",
    });
    _ = try store.record(.{
        .kind = .service_required,
        .run_id = run_id,
        .parent_id = started,
        .scope_id = 3,
        .label = "Config",
        .type_name = "ConfigService",
        .status = "missing",
    });

    const dot = try fx.formatCausalDot(std.testing.allocator, &store);
    defer std.testing.allocator.free(dot);

    try std.testing.expect(std.mem.indexOf(u8, dot, "digraph zigeffect_causal {") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "graph [rankdir=\"LR\", labelloc=\"t\", label=\"zigeffect causal graph\"];") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "node [shape=\"box\", style=\"rounded,filled\", fontname=\"Menlo\", fontsize=\"10\"];") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "edge [fontname=\"Menlo\", fontsize=\"9\", color=\"#64748b\"];") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "event_1 [label=\"event 1\\nrun_started\\nreadiness \\\"quoted\\\" next\\nstatus=success\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "tooltip=\"run=1 type=DotRun\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "event_2 [label=\"event 2\\nservice_required\\nConfig\\nstatus=missing\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "tooltip=\"run=1 scope=3 type=ConfigService\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "event_1 -> event_2 [label=\"parent\"];") != null);
    try std.testing.expect(std.mem.endsWith(u8, dot, "}\n"));
}

test "dot backend writes stored sanitized conformance events and finishes graph" {
    var output = std.ArrayList(u8).empty;
    defer output.deinit(std.testing.allocator);

    var backend_state = fx.CausalDotBackendState.init(std.testing.allocator, &output, .{});

    var store = fx.CausalStore.initWithOptions(std.testing.allocator, conformance.standardStoreOptions());
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const ids = try conformance.recordStandardTrace(&store);
    try conformance.expectStandardStorePosture(&store, ids);
    try backend_state.finish();
    try backend_state.finish();

    try std.testing.expectEqual(fx.CausalBackendKind.dot, store.attachedBackendKind().?);
    try std.testing.expectEqual(@as(u64, 3), backend_state.writtenEventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.failedWriteCount());
    try std.testing.expectEqual(@as(u64, 0), store.backendFailureCount());
    try std.testing.expect(backend_state.isFinished());
    try std.testing.expect(std.mem.indexOf(u8, output.items, "digraph zigeffect_causal {") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, "raw-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, fx.causal_redaction_marker) != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, fx.causal_truncation_marker) != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, "event_1 [label=\"event 1\\nrun_started") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, "event_3 [label=\"event 3\\nlog_recorded") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, "event_4 [label=\"event 4\\nrun_completed") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, "event_1 -> event_3 [label=\"parent\"]") != null);
    try std.testing.expect(std.mem.endsWith(u8, output.items, "}\n"));
}

test "formatCausalDotEvent emits one complete event statement group" {
    const dot = try fx.formatCausalDotEvent(std.testing.allocator, .{
        .id = 9,
        .kind = .span_recorded,
        .run_id = 1,
        .parent_id = 4,
        .trace_id = 7,
        .span_id = 8,
        .label = "span\nline",
        .status = "ok",
    });
    defer std.testing.allocator.free(dot);

    try std.testing.expect(std.mem.indexOf(u8, dot, "event_9 [label=\"event 9\\nspan_recorded\\nspan line\\nstatus=ok\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "tooltip=\"run=1 trace=7 span=8\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "event_4 -> event_9 [label=\"parent\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "\nline") == null);
}
