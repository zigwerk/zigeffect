const std = @import("std");
const fx = @import("zigeffect");

const kernel = fx.kernel;

const EmitContext = kernel.Effect(void, error{}, .{});
const emit_context = EmitContext.fromFn(struct {
    fn run(ctx: *EmitContext.Context) error{}!void {
        _ = ctx.recordCausal(.{
            .kind = .activity_completed,
            .label = "development.change",
            .status = "complete",
        });
    }
}.run);

test "causal context v2 and typed links are bounded and survive every projection" {
    var event = fx.CausalEvent{
        .id = 41,
        .kind = .activity_completed,
        .label = "proof",
        .status = "complete",
        .context = .{
            .runtime_instance_id = 7,
            .graph_session_id = 9,
            .development_task_id = 11,
            .work_packet_id = 12,
            .change_set_id = 13,
            .trace_id_high = 14,
            .trace_id_low = 15,
            .span_id = 16,
        },
    };
    try event.addLink(.{ .kind = .proof, .event_id = 37, .graph_session_id = 9 });
    try event.addLink(.{ .kind = .change, .event_id = 38, .graph_session_id = 9 });
    try std.testing.expectEqual(@as(usize, 2), event.activeLinks().len);

    const jsonl = try fx.formatCausalJsonLine(std.testing.allocator, event);
    defer std.testing.allocator.free(jsonl);
    try std.testing.expect(std.mem.indexOf(u8, jsonl, "\"development_task_id\":11") != null);
    try std.testing.expect(std.mem.indexOf(u8, jsonl, "\"kind\":\"proof\"") != null);

    var nendb = try fx.mapCausalEventToNendbWrite(std.testing.allocator, event);
    defer fx.deinitCausalNendbWrite(std.testing.allocator, &nendb);
    try std.testing.expect(std.mem.indexOf(u8, nendb.node.properties, "\"change_set_id\":13") != null);
    try std.testing.expect(std.mem.indexOf(u8, nendb.node.properties, "\"graph_session_id\":9") != null);

    var otel = try fx.mapCausalEventToOtelRecord(std.testing.allocator, event);
    defer otel.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u64, 11), otel.attribute("zigeffect.causal.development_task_id").?.u64);
    try std.testing.expectEqual(@as(u64, 13), otel.attribute("zigeffect.causal.change_set_id").?.u64);
    try std.testing.expectEqual(@as(u64, 2), otel.attribute("zigeffect.causal.link_count").?.u64);
}

test "managed runtime handles propagate development context to every semantic event" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    const empty = kernel.Layer.empty();
    var runtime = try kernel.ManagedRuntime(@TypeOf(empty)).make(std.testing.allocator, empty, .{
        .causal_store = &store,
        .causal_context = .{ .runtime_instance_id = 101, .graph_session_id = 202 },
    });
    defer runtime.deinit();

    var handle = runtime.handle().withCausalContext(.{
        .development_task_id = 303,
        .work_packet_id = 404,
        .change_set_id = 505,
    });
    try handle.run(emit_context.named("development.context-propagation"));

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    var found = false;
    for (snapshot.events) |event| {
        if (!std.mem.eql(u8, event.label, "development.change")) continue;
        found = true;
        try std.testing.expectEqual(@as(?u64, 101), event.context.runtime_instance_id);
        try std.testing.expectEqual(@as(?u64, 202), event.context.graph_session_id);
        try std.testing.expectEqual(@as(?u64, 303), event.context.development_task_id);
        try std.testing.expectEqual(@as(?u64, 404), event.context.work_packet_id);
        try std.testing.expectEqual(@as(?u64, 505), event.context.change_set_id);
    }
    try std.testing.expect(found);
}

test "canonical OTLP projection emits correlated spans and logs from one causal batch" {
    var span = try fx.mapCausalEventToOtelRecord(std.testing.allocator, .{
        .id = 1,
        .kind = .activity_completed,
        .trace_id = 11,
        .span_id = 12,
        .context = .{ .development_task_id = 13, .graph_session_id = 14 },
        .label = "execute_tool",
        .status = "complete",
    });
    defer span.deinit(std.testing.allocator);
    var log = try fx.mapCausalEventToOtelRecord(std.testing.allocator, .{
        .id = 2,
        .kind = .log_recorded,
        .context = .{ .development_task_id = 13, .graph_session_id = 14 },
        .label = "proof recorded",
        .status = "info",
    });
    defer log.deinit(std.testing.allocator);
    const envelope = try fx.formatOtlpSignals(std.testing.allocator, &.{ span, log }, .{});
    defer std.testing.allocator.free(envelope);
    try std.testing.expect(std.mem.indexOf(u8, envelope, "\"resourceSpans\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, envelope, "\"resourceLogs\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, envelope, "\"resourceMetrics\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, envelope, "zigeffect.causal.events") != null);
    try std.testing.expect(std.mem.indexOf(u8, envelope, "zigeffect.causal.development_task_id") != null);
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, envelope, .{});
    defer parsed.deinit();
}

test "W3C traceparent parses and formats exact 128 bit causal identity" {
    const text = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01";
    const parsed = try fx.parseTraceParent(text);
    const formatted = parsed.format();
    try std.testing.expectEqualStrings(text, &formatted);
    const context = parsed.context();
    try std.testing.expectEqual(@as(?u64, 0x4bf92f3577b34da6), context.trace_id_high);
    try std.testing.expectEqual(@as(?u64, 0xa3ce929d0e0e4736), context.trace_id_low);
    try std.testing.expectEqual(@as(?u64, 0x00f067aa0ba902b7), context.span_id);
    try std.testing.expectError(error.InvalidTraceParent, fx.parseTraceParent("00-00000000000000000000000000000000-0000000000000000-01"));
}
