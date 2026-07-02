const std = @import("std");
const fx = @import("zigeffect");
const conformance = @import("support/causal_backend_conformance.zig");

const JsonLineRow = struct {
    schema: []const u8,
    schema_version: u32,
    event_taxonomy_version: u32,
    id: u64,
    kind: []const u8,
    run_id: ?u64,
    parent_id: ?u64,
    fiber_id: ?u64,
    scope_id: ?u64,
    layer_id: ?u64,
    layer_name: []const u8,
    service_key: []const u8,
    resource_id: ?u64,
    cause_event_id: ?u64,
    schedule_id: ?u64,
    artifact_id: []const u8,
    domain_entity_ref: []const u8,
    data_subject_ref: []const u8,
    schema_ref: []const u8,
    trace_id: ?u64,
    span_id: ?u64,
    label: []const u8,
    type_name: []const u8,
    status: []const u8,
    redacted_detail: []const u8,
};

fn expectSingleJsonLine(line: []const u8) ![]const u8 {
    try std.testing.expect(line.len > 1);
    try std.testing.expectEqual(@as(u8, '\n'), line[line.len - 1]);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, line, "\n"));
    return line[0 .. line.len - 1];
}

fn parseJsonLine(row_json: []const u8) !std.json.Parsed(JsonLineRow) {
    return std.json.parseFromSlice(JsonLineRow, std.testing.allocator, row_json, .{ .ignore_unknown_fields = true });
}

test "formatCausalJsonLine emits schema-tagged escaped row" {
    const line = try fx.formatCausalJsonLine(std.testing.allocator, .{
        .id = 42,
        .kind = .run_started,
        .run_id = 7,
        .parent_id = null,
        .fiber_id = 99,
        .scope_id = 11,
        .layer_id = 12,
        .layer_name = "persistence",
        .service_key = "Logger",
        .resource_id = 13,
        .cause_event_id = 41,
        .schedule_id = 14,
        .artifact_id = "artifact:health",
        .domain_entity_ref = "project:123",
        .data_subject_ref = "tenant:acme",
        .schema_ref = "Project.v1",
        .trace_id = 101,
        .span_id = 202,
        .label = "quote \" newline\n tab\t slash \\",
        .type_name = "JsonLineFormatter",
        .status = "success",
        .redacted_detail = "detail\rvalue",
    });
    defer std.testing.allocator.free(line);

    const row_json = try expectSingleJsonLine(line);
    var parsed = try std.json.parseFromSlice(JsonLineRow, std.testing.allocator, row_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try std.testing.expectEqualStrings(fx.causal_jsonl_event_schema, parsed.value.schema);
    try std.testing.expectEqual(fx.causal_jsonl_event_schema_version, parsed.value.schema_version);
    try std.testing.expectEqual(fx.causal_event_taxonomy_version, parsed.value.event_taxonomy_version);
    try std.testing.expectEqual(@as(u64, 42), parsed.value.id);
    try std.testing.expectEqualStrings("run_started", parsed.value.kind);
    try std.testing.expectEqual(@as(?u64, 7), parsed.value.run_id);
    try std.testing.expectEqual(@as(?u64, null), parsed.value.parent_id);
    try std.testing.expectEqual(@as(?u64, 99), parsed.value.fiber_id);
    try std.testing.expectEqual(@as(?u64, 11), parsed.value.scope_id);
    try std.testing.expectEqual(@as(?u64, 12), parsed.value.layer_id);
    try std.testing.expectEqualStrings("persistence", parsed.value.layer_name);
    try std.testing.expectEqualStrings("Logger", parsed.value.service_key);
    try std.testing.expectEqual(@as(?u64, 13), parsed.value.resource_id);
    try std.testing.expectEqual(@as(?u64, 41), parsed.value.cause_event_id);
    try std.testing.expectEqual(@as(?u64, 14), parsed.value.schedule_id);
    try std.testing.expectEqualStrings("artifact:health", parsed.value.artifact_id);
    try std.testing.expectEqualStrings("project:123", parsed.value.domain_entity_ref);
    try std.testing.expectEqualStrings("tenant:acme", parsed.value.data_subject_ref);
    try std.testing.expectEqualStrings("Project.v1", parsed.value.schema_ref);
    try std.testing.expectEqual(@as(?u64, 101), parsed.value.trace_id);
    try std.testing.expectEqual(@as(?u64, 202), parsed.value.span_id);
    try std.testing.expectEqualStrings("quote \" newline\n tab\t slash \\", parsed.value.label);
    try std.testing.expectEqualStrings("JsonLineFormatter", parsed.value.type_name);
    try std.testing.expectEqualStrings("success", parsed.value.status);
    try std.testing.expectEqualStrings("detail\rvalue", parsed.value.redacted_detail);
}

test "json lines backend writes stored sanitized conformance events" {
    var output = std.ArrayList(u8).empty;
    defer output.deinit(std.testing.allocator);

    var backend_state = fx.CausalJsonLinesBackendState.init(std.testing.allocator, &output, .{});

    var store = fx.CausalStore.initWithOptions(std.testing.allocator, conformance.standardStoreOptions());
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const ids = try conformance.recordStandardTrace(&store);
    try conformance.expectStandardStorePosture(&store, ids);

    try std.testing.expectEqual(fx.CausalBackendKind.json_lines, store.attachedBackendKind().?);
    try std.testing.expectEqual(@as(u64, 3), backend_state.writtenEventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.failedEventCount());
    try std.testing.expectEqual(@as(u64, 0), store.backendFailureCount());
    try std.testing.expect(std.mem.indexOf(u8, output.items, "raw-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, fx.causal_redaction_marker) != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, fx.causal_truncation_marker) != null);

    var lines = std.mem.tokenizeScalar(u8, output.items, '\n');
    const first_line = lines.next().?;
    const second_line = lines.next().?;
    const third_line = lines.next().?;
    try std.testing.expect(lines.next() == null);

    var first = try parseJsonLine(first_line);
    defer first.deinit();
    var second = try parseJsonLine(second_line);
    defer second.deinit();
    var third = try parseJsonLine(third_line);
    defer third.deinit();

    try std.testing.expectEqual(ids.started, first.value.id);
    try std.testing.expectEqualStrings("run_started", first.value.kind);
    try std.testing.expect(first.value.label.len <= conformance.standard_max_event_string_bytes);
    try std.testing.expectEqual(ids.retained_log, second.value.id);
    try std.testing.expectEqualStrings("log_recorded", second.value.kind);
    try std.testing.expectEqual(ids.completed, third.value.id);
    try std.testing.expectEqualStrings("run_completed", third.value.kind);
}

test "json lines backend escapes control bytes into parseable rows" {
    var output = std.ArrayList(u8).empty;
    defer output.deinit(std.testing.allocator);

    var backend_state = fx.CausalJsonLinesBackendState.init(std.testing.allocator, &output, .{});

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    _ = try store.record(.{
        .kind = .run_started,
        .layer_name = "layer\x08name",
        .label = "ansi \x1b[31mred\x1b[0m label",
    });

    try std.testing.expectEqual(@as(u64, 1), backend_state.writtenEventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.failedEventCount());

    const row_json = try expectSingleJsonLine(output.items);
    try std.testing.expect(std.mem.indexOf(u8, row_json, "\\u001b") != null);
    try std.testing.expect(std.mem.indexOf(u8, row_json, "\\u0008") != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, row_json, 0x1b) == null);
    try std.testing.expect(std.mem.indexOfScalar(u8, row_json, 0x08) == null);

    var parsed = try parseJsonLine(row_json);
    defer parsed.deinit();
    try std.testing.expectEqualStrings("ansi \x1b[31mred\x1b[0m label", parsed.value.label);
    try std.testing.expectEqualStrings("layer\x08name", parsed.value.layer_name);
}

test "json lines backend max_bytes fails closed without partial rows" {
    var output = std.ArrayList(u8).empty;
    defer output.deinit(std.testing.allocator);

    var backend_state = fx.CausalJsonLinesBackendState.init(std.testing.allocator, &output, .{ .max_bytes = 1 });

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const id = try store.record(.{
        .kind = .run_started,
        .label = "overflowing-jsonl-row",
    });

    try std.testing.expectEqual(@as(u64, 1), id);
    try std.testing.expectEqual(@as(usize, 0), output.items.len);
    try std.testing.expectEqual(@as(u64, 0), backend_state.writtenEventCount());
    try std.testing.expectEqual(@as(u64, 1), backend_state.failedEventCount());
    try std.testing.expectEqual(@as(u64, 1), store.backendFailureCount());

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expectEqual(id, snapshot.events[0].id);
}
