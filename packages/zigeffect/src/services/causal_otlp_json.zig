//! M9.1 — OTLP/JSON serialization for the causal OTel mapping.
//!
//! The `causal_otel_backend` already maps each `CausalEvent` to a
//! `CausalOtelRecord` (trace/span ids, attributes, signal). This module is the
//! missing wire-format piece of "live export": it serializes a batch of those
//! records into canonical OTLP/JSON signal payloads. The serialization is the
//! honest core; transports may split the top-level signal families across the
//! collector's `/v1/traces`, `/v1/logs`, and `/v1/metrics` endpoints without
//! remapping identity or attributes.

const std = @import("std");
const otel = @import("causal_otel_backend.zig");

pub const Allocator = std.mem.Allocator;
pub const CausalOtelRecord = otel.CausalOtelRecord;

pub const OtlpJsonOptions = struct {
    /// `service.name` resource attribute.
    service_name: []const u8 = "zigeffect",
    /// Instrumentation scope name.
    scope_name: []const u8 = "zigeffect.causal",
};

/// Serialize `records` into an OTLP/JSON `resourceLogs` document. Caller owns
/// and frees the returned slice.
pub fn formatOtlpLogs(
    allocator: Allocator,
    records: []const CausalOtelRecord,
    options: OtlpJsonOptions,
) Allocator.Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    try out.appendSlice(allocator, "{\"resourceLogs\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":");
    try appendJsonString(&out, allocator, options.service_name);
    try out.appendSlice(allocator, "}}]},\"scopeLogs\":[{\"scope\":{\"name\":");
    try appendJsonString(&out, allocator, options.scope_name);
    try out.appendSlice(allocator, "},\"logRecords\":[");

    for (records, 0..) |record, i| {
        if (i != 0) try out.append(allocator, ',');
        try appendLogRecord(&out, allocator, record);
    }

    try out.appendSlice(allocator, "]}]}]}");
    return out.toOwnedSlice(allocator);
}

fn appendCountMetric(out: *std.ArrayList(u8), allocator: Allocator, name: []const u8, value: usize) Allocator.Error!void {
    try out.appendSlice(allocator, "{\"name\":");
    try appendJsonString(out, allocator, name);
    try out.print(allocator, ",\"sum\":{{\"aggregationTemporality\":2,\"isMonotonic\":true,\"dataPoints\":[{{\"asInt\":\"{d}\"}}]}}}}", .{value});
}

/// Serialize the canonical causal batch once into both OTLP signal families.
/// Records classified as span events enter `resourceSpans`; all remaining
/// records enter `resourceLogs`. Both preserve the exact same causal context
/// attributes produced by `mapCausalEventToOtelRecord`.
pub fn formatOtlpSignals(
    allocator: Allocator,
    records: []const CausalOtelRecord,
    options: OtlpJsonOptions,
) Allocator.Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    try out.appendSlice(allocator, "{\"resourceSpans\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":");
    try appendJsonString(&out, allocator, options.service_name);
    try out.appendSlice(allocator, "}}]},\"scopeSpans\":[{\"scope\":{\"name\":");
    try appendJsonString(&out, allocator, options.scope_name);
    try out.appendSlice(allocator, "},\"spans\":[");
    var span_count: usize = 0;
    for (records) |record| {
        if (record.signal != .span_event) continue;
        if (span_count != 0) try out.append(allocator, ',');
        try appendSpanRecord(&out, allocator, record);
        span_count += 1;
    }
    try out.appendSlice(allocator, "]}]}],\"resourceLogs\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":");
    try appendJsonString(&out, allocator, options.service_name);
    try out.appendSlice(allocator, "}}]},\"scopeLogs\":[{\"scope\":{\"name\":");
    try appendJsonString(&out, allocator, options.scope_name);
    try out.appendSlice(allocator, "},\"logRecords\":[");
    var log_count: usize = 0;
    for (records) |record| {
        if (record.signal != .log_record) continue;
        if (log_count != 0) try out.append(allocator, ',');
        try appendLogRecord(&out, allocator, record);
        log_count += 1;
    }
    try out.appendSlice(allocator, "]}]}],\"resourceMetrics\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":");
    try appendJsonString(&out, allocator, options.service_name);
    try out.appendSlice(allocator, "}}]},\"scopeMetrics\":[{\"scope\":{\"name\":");
    try appendJsonString(&out, allocator, options.scope_name);
    try out.appendSlice(allocator, "},\"metrics\":[");
    try appendCountMetric(&out, allocator, "zigeffect.causal.events", records.len);
    try out.append(allocator, ',');
    try appendCountMetric(&out, allocator, "zigeffect.causal.span_events", span_count);
    try out.append(allocator, ',');
    try appendCountMetric(&out, allocator, "zigeffect.causal.log_records", log_count);
    try out.appendSlice(allocator, "]}]}]}");
    return out.toOwnedSlice(allocator);
}

fn appendSpanRecord(out: *std.ArrayList(u8), allocator: Allocator, record: CausalOtelRecord) Allocator.Error!void {
    try out.append(allocator, '{');
    if (record.trace_id_hex) |hex| {
        try out.appendSlice(allocator, "\"traceId\":");
        try appendJsonString(out, allocator, &hex);
    } else {
        try out.appendSlice(allocator, "\"traceId\":\"00000000000000000000000000000000\"");
    }
    try out.appendSlice(allocator, ",\"spanId\":");
    if (record.span_id_hex) |hex| try appendJsonString(out, allocator, &hex) else try appendJsonString(out, allocator, "0000000000000000");
    try out.appendSlice(allocator, ",\"name\":");
    try appendJsonString(out, allocator, record.name);
    try out.appendSlice(allocator, ",\"kind\":1,\"attributes\":[");
    try appendAttributes(out, allocator, record);
    try out.appendSlice(allocator, "],\"status\":{\"code\":1}}");
}

fn appendAttributes(out: *std.ArrayList(u8), allocator: Allocator, record: CausalOtelRecord) Allocator.Error!void {
    for (record.attributes, 0..) |attr, i| {
        if (i != 0) try out.append(allocator, ',');
        try out.appendSlice(allocator, "{\"key\":");
        try appendJsonString(out, allocator, attr.key);
        try out.appendSlice(allocator, ",\"value\":{");
        switch (attr.value) {
            .string => |s| {
                try out.appendSlice(allocator, "\"stringValue\":");
                try appendJsonString(out, allocator, s);
            },
            .u64 => |n| try out.print(allocator, "\"intValue\":\"{d}\"", .{n}),
            .bool => |b| {
                try out.appendSlice(allocator, "\"boolValue\":");
                try out.appendSlice(allocator, if (b) "true" else "false");
            },
        }
        try out.appendSlice(allocator, "}}");
    }
}

fn appendLogRecord(out: *std.ArrayList(u8), allocator: Allocator, record: CausalOtelRecord) Allocator.Error!void {
    try out.appendSlice(allocator, "{\"body\":{\"stringValue\":");
    try appendJsonString(out, allocator, record.name);
    try out.append(allocator, '}');

    if (record.trace_id_hex) |hex| {
        try out.appendSlice(allocator, ",\"traceId\":");
        try appendJsonString(out, allocator, &hex);
    }
    if (record.span_id_hex) |hex| {
        try out.appendSlice(allocator, ",\"spanId\":");
        try appendJsonString(out, allocator, &hex);
    }

    try out.appendSlice(allocator, ",\"attributes\":[");
    try appendAttributes(out, allocator, record);
    try out.appendSlice(allocator, "]}");
}

/// Append a JSON string literal (with surrounding quotes), escaping per RFC 8259.
fn appendJsonString(out: *std.ArrayList(u8), allocator: Allocator, s: []const u8) Allocator.Error!void {
    try out.append(allocator, '"');
    for (s) |c| {
        switch (c) {
            '"' => try out.appendSlice(allocator, "\\\""),
            '\\' => try out.appendSlice(allocator, "\\\\"),
            '\n' => try out.appendSlice(allocator, "\\n"),
            '\r' => try out.appendSlice(allocator, "\\r"),
            '\t' => try out.appendSlice(allocator, "\\t"),
            0x08 => try out.appendSlice(allocator, "\\b"),
            0x0c => try out.appendSlice(allocator, "\\f"),
            0x00...0x07, 0x0b, 0x0e...0x1f => {
                try out.print(allocator, "\\u{x:0>4}", .{c});
            },
            else => try out.append(allocator, c),
        }
    }
    try out.append(allocator, '"');
}
