//! M9.1 — OTLP/JSON serialization tests.

const std = @import("std");
const fx = @import("zigeffect");
const otel_mod = fx.services.causal_otel_backend;
const otlp = fx.causal_otlp_json;

fn recordFor(allocator: std.mem.Allocator, event: fx.CausalEvent) !otel_mod.CausalOtelRecord {
    return fx.mapCausalEventToOtelRecord(allocator, event);
}

test "formatOtlpLogs emits a valid OTLP/JSON resourceLogs document that re-parses" {
    const allocator = std.testing.allocator;

    var r0 = try recordFor(allocator, .{ .kind = .run_started, .status = "started", .label = "boot", .trace_id = 0x1234, .span_id = 0xabcd });
    defer r0.deinit(allocator);
    var r1 = try recordFor(allocator, .{ .kind = .metric_recorded, .status = "ready", .label = "m\"q\"" }); // embedded quotes → escaping
    defer r1.deinit(allocator);

    const records = [_]otel_mod.CausalOtelRecord{ r0, r1 };
    const json = try otlp.formatOtlpLogs(allocator, &records, .{ .service_name = "court-series" });
    defer allocator.free(json);

    // Shape markers present.
    try std.testing.expect(std.mem.indexOf(u8, json, "\"resourceLogs\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"service.name\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"court-series\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"scopeLogs\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"logRecords\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"body\":{\"stringValue\":") != null);
    // The trace/span ids were rendered as hex strings.
    try std.testing.expect(std.mem.indexOf(u8, json, "\"traceId\":") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"spanId\":") != null);
    // The embedded quote was escaped (no raw unescaped m"q").
    try std.testing.expect(std.mem.indexOf(u8, json, "m\\\"q\\\"") != null);

    // The whole thing is VALID JSON — re-parse it.
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
    defer parsed.deinit();
    const root = parsed.value.object;
    const resource_logs = root.get("resourceLogs").?.array;
    try std.testing.expectEqual(@as(usize, 1), resource_logs.items.len);
    const scope_logs = resource_logs.items[0].object.get("scopeLogs").?.array;
    const log_records = scope_logs.items[0].object.get("logRecords").?.array;
    try std.testing.expectEqual(@as(usize, 2), log_records.items.len);
}

test "formatOtlpLogs encodes integer + bool attributes per OTLP (intValue stringified, boolValue literal)" {
    const allocator = std.testing.allocator;

    // An event with a fiber_id → produces a u64 attribute in the OTel mapping.
    var r = try recordFor(allocator, .{ .kind = .fiber_started, .fiber_id = 99, .status = "running" });
    defer r.deinit(allocator);

    const records = [_]otel_mod.CausalOtelRecord{r};
    const json = try otlp.formatOtlpLogs(allocator, &records, .{});
    defer allocator.free(json);

    // OTLP integers are stringified decimals under intValue.
    try std.testing.expect(std.mem.indexOf(u8, json, "\"intValue\":\"99\"") != null);

    // Valid JSON.
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
    defer parsed.deinit();
}

test "formatOtlpLogs with no records emits an empty-but-valid logRecords array" {
    const allocator = std.testing.allocator;
    const json = try otlp.formatOtlpLogs(allocator, &.{}, .{});
    defer allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"logRecords\":[]") != null);
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
    defer parsed.deinit();
}
