const std = @import("std");
const fx = @import("zigeffect");

const sentinel_values = [_][]const u8{
    "sentinel-bearer-token-123",
    "sk-sentinel-api-key-123",
    "sentinel-password-123",
    "sentinel-cookie-123",
    "sentinel-db-password-123",
    "sentinel-owner@example.invalid",
};

const sentinel_detail =
    "Authorization: Bearer sentinel-bearer-token-123 " ++
    "api_key=sk-sentinel-api-key-123 " ++
    "password=sentinel-password-123 " ++
    "Cookie: sid=sentinel-cookie-123; theme=dark " ++
    "database_url=postgresql://owner:sentinel-db-password-123@example.invalid/db " ++
    "owner email 'sentinel-owner@example.invalid'";

fn expectNoSentinels(haystack: []const u8) !void {
    for (sentinel_values) |sentinel| {
        try std.testing.expect(std.mem.indexOf(u8, haystack, sentinel) == null);
    }
}

fn recordsContain(records: []const fx.CausalOtelRecord, needle: []const u8) bool {
    for (records) |record| {
        if (std.mem.indexOf(u8, record.name, needle) != null) return true;
        for (record.attributes) |attribute| {
            if (std.mem.indexOf(u8, attribute.key, needle) != null) return true;
            switch (attribute.value) {
                .string => |value| if (std.mem.indexOf(u8, value, needle) != null) return true,
                else => {},
            }
        }
    }
    return false;
}

fn expectNoOtelSentinels(records: []const fx.CausalOtelRecord) !void {
    for (sentinel_values) |sentinel| {
        try std.testing.expect(!recordsContain(records, sentinel));
    }
}

fn recordSentinelEvent(store: *fx.CausalStore) !void {
    _ = try store.record(.{
        .kind = .log_recorded,
        .run_id = 1,
        .trace_id = 7001,
        .span_id = 7002,
        .label = sentinel_detail,
        .type_name = "postgresql://owner:sentinel-db-password-123@example.invalid/db",
        .status = "x-api-key=sk-sentinel-api-key-123",
        .redacted_detail = sentinel_detail,
    });
}

test "sentinel secrets never appear in causal artifacts or live feed payloads" {
    const allocator = std.testing.allocator;

    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    try recordSentinelEvent(&store);

    var snapshot = try store.snapshot(allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    const event = snapshot.events[0];
    try expectNoSentinels(event.label);
    try expectNoSentinels(event.type_name);
    try expectNoSentinels(event.status);
    try expectNoSentinels(event.redacted_detail);

    const report = try fx.formatCausalReport(allocator, "sentinel-redaction", &store);
    defer allocator.free(report);
    try expectNoSentinels(report);
    try std.testing.expect(std.mem.indexOf(u8, report, fx.causal_redaction_marker) != null);

    const ci_report = try fx.formatCausalCiReport(allocator, "sentinel-redaction", &store);
    defer allocator.free(ci_report);
    try expectNoSentinels(ci_report);

    const json = try fx.formatCausalJson(allocator, &store);
    defer allocator.free(json);
    try expectNoSentinels(json);

    const dot = try fx.formatCausalDot(allocator, &store);
    defer allocator.free(dot);
    try expectNoSentinels(dot);

    var jsonl_output = std.ArrayList(u8).empty;
    defer jsonl_output.deinit(allocator);
    var jsonl_backend = fx.CausalJsonLinesBackendState.init(allocator, &jsonl_output, .{});
    var jsonl_store = fx.CausalStore.init(allocator);
    defer jsonl_store.deinit();
    jsonl_store.attachBackend(jsonl_backend.backend());
    try recordSentinelEvent(&jsonl_store);
    try expectNoSentinels(jsonl_output.items);

    var ndjson_tap = fx.causal_hub_backend.CausalNdjsonTapState.init(allocator);
    defer ndjson_tap.deinit();
    var ndjson_store = fx.CausalStore.init(allocator);
    defer ndjson_store.deinit();
    ndjson_store.attachBackend(ndjson_tap.backend());
    try recordSentinelEvent(&ndjson_store);
    var ndjson = std.ArrayList(u8).empty;
    defer ndjson.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), try ndjson_tap.drain(&ndjson));
    try expectNoSentinels(ndjson.items);

    var otel_backend = fx.CausalOtelBackendState.init(allocator, .{});
    defer otel_backend.deinit();
    var otel_store = fx.CausalStore.init(allocator);
    defer otel_store.deinit();
    otel_store.attachBackend(otel_backend.backend());
    try recordSentinelEvent(&otel_store);
    try expectNoOtelSentinels(otel_backend.recordedRecords());
    const otlp = try fx.formatOtlpLogs(allocator, otel_backend.recordedRecords(), .{ .service_name = "zigeffect-sentinel" });
    defer allocator.free(otlp);
    try expectNoSentinels(otlp);
}
