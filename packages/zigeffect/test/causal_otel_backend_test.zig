const std = @import("std");
const fx = @import("zigeffect");
const conformance = @import("support/causal_backend_conformance.zig");

const AttributeExpectationError = error{
    MissingAttribute,
    WrongAttributeKind,
};

fn expectStringAttribute(record: *const fx.CausalOtelRecord, key: []const u8, expected: []const u8) !void {
    const value = record.attribute(key) orelse return AttributeExpectationError.MissingAttribute;
    switch (value) {
        .string => |actual| try std.testing.expectEqualStrings(expected, actual),
        else => return AttributeExpectationError.WrongAttributeKind,
    }
}

fn expectU64Attribute(record: *const fx.CausalOtelRecord, key: []const u8, expected: u64) !void {
    const value = record.attribute(key) orelse return AttributeExpectationError.MissingAttribute;
    switch (value) {
        .u64 => |actual| try std.testing.expectEqual(expected, actual),
        else => return AttributeExpectationError.WrongAttributeKind,
    }
}

fn recordsContainString(records: []const fx.CausalOtelRecord, needle: []const u8) bool {
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

test "causal otel id helpers emit fixed lowercase hex" {
    const trace_id = fx.formatCausalOtelTraceId(0x2a);
    const span_id = fx.formatCausalOtelSpanId(0x2a);

    try std.testing.expectEqual(@as(usize, 32), trace_id.len);
    try std.testing.expectEqual(@as(usize, 16), span_id.len);
    try std.testing.expectEqualStrings("0000000000000000000000000000002a", trace_id[0..]);
    try std.testing.expectEqualStrings("000000000000002a", span_id[0..]);
}

test "mapCausalEventToOtelRecord maps complete trace context to span event" {
    var record = try fx.mapCausalEventToOtelRecord(std.testing.allocator, .{
        .id = 42,
        .kind = .effect_started,
        .run_id = 7,
        .parent_id = 9,
        .fiber_id = 10,
        .scope_id = 11,
        .trace_id = 1,
        .span_id = 2,
        .label = "load-vessel",
        .type_name = "VesselEffect",
        .status = "running",
        .redacted_detail = "safe detail",
    });
    defer record.deinit(std.testing.allocator);

    try std.testing.expectEqual(fx.CausalOtelSignal.span_event, record.signal);
    try std.testing.expectEqualStrings("zigeffect.causal.effect_started", record.name);
    try std.testing.expectEqual(@as(?u64, 1), record.trace_id);
    try std.testing.expectEqual(@as(?u64, 2), record.span_id);
    try std.testing.expectEqualStrings("00000000000000000000000000000001", record.trace_id_hex.?[0..]);
    try std.testing.expectEqualStrings("0000000000000002", record.span_id_hex.?[0..]);
    try expectStringAttribute(&record, "zigeffect.causal.schema", fx.causal_otel_record_schema);
    try expectU64Attribute(&record, "zigeffect.causal.schema_version", fx.causal_otel_record_schema_version);
    try expectU64Attribute(&record, "zigeffect.causal.event_taxonomy_version", fx.causal_event_taxonomy_version);
    try expectU64Attribute(&record, "zigeffect.causal.event_id", 42);
    try expectStringAttribute(&record, "zigeffect.causal.kind", "effect_started");
    try expectStringAttribute(&record, "zigeffect.causal.signal", "span_event");
    try expectU64Attribute(&record, "zigeffect.causal.run_id", 7);
    try expectU64Attribute(&record, "zigeffect.causal.parent_event_id", 9);
    try expectU64Attribute(&record, "zigeffect.causal.fiber_id", 10);
    try expectU64Attribute(&record, "zigeffect.causal.scope_id", 11);
    try expectU64Attribute(&record, "zigeffect.causal.trace_id", 1);
    try expectU64Attribute(&record, "zigeffect.causal.span_id", 2);
    try expectStringAttribute(&record, "zigeffect.causal.label", "load-vessel");
    try expectStringAttribute(&record, "zigeffect.causal.type_name", "VesselEffect");
    try expectStringAttribute(&record, "zigeffect.causal.status", "running");
    try expectStringAttribute(&record, "zigeffect.causal.redacted_detail", "safe detail");
}

test "mapCausalEventToOtelRecord maps missing trace context to log record" {
    var record = try fx.mapCausalEventToOtelRecord(std.testing.allocator, .{
        .id = 5,
        .kind = .log_recorded,
        .label = "startup-log",
    });
    defer record.deinit(std.testing.allocator);

    try std.testing.expectEqual(fx.CausalOtelSignal.log_record, record.signal);
    try std.testing.expectEqualStrings("zigeffect.causal.log_recorded", record.name);
    try std.testing.expectEqual(@as(?u64, null), record.trace_id);
    try std.testing.expectEqual(@as(?u64, null), record.span_id);
    try std.testing.expect(record.trace_id_hex == null);
    try std.testing.expect(record.span_id_hex == null);
    try expectU64Attribute(&record, "zigeffect.causal.event_id", 5);
    try expectStringAttribute(&record, "zigeffect.causal.kind", "log_recorded");
    try expectStringAttribute(&record, "zigeffect.causal.signal", "log_record");
    try expectStringAttribute(&record, "zigeffect.causal.label", "startup-log");
}

test "otel backend records stored sanitized conformance events" {
    var backend_state = fx.CausalOtelBackendState.init(std.testing.allocator, .{});
    defer backend_state.deinit();

    var store = fx.CausalStore.initWithOptions(std.testing.allocator, conformance.standardStoreOptions());
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const ids = try conformance.recordStandardTrace(&store);
    try conformance.expectStandardStorePosture(&store, ids);

    const records = backend_state.recordedRecords();
    try std.testing.expectEqual(fx.CausalBackendKind.opentelemetry, store.attachedBackendKind().?);
    try std.testing.expectEqual(@as(usize, 3), records.len);
    try std.testing.expectEqual(@as(u64, 3), backend_state.writtenRecordCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.failedRecordCount());
    try std.testing.expectEqual(@as(u64, 0), store.backendFailureCount());
    try std.testing.expectEqual(ids.started, records[0].attribute("zigeffect.causal.event_id").?.u64);
    try std.testing.expectEqual(ids.retained_log, records[1].attribute("zigeffect.causal.event_id").?.u64);
    try std.testing.expectEqual(ids.completed, records[2].attribute("zigeffect.causal.event_id").?.u64);
    try std.testing.expectEqual(fx.CausalOtelSignal.log_record, records[0].signal);
    try std.testing.expect(recordsContainString(records, "raw-secret") == false);
    try std.testing.expect(recordsContainString(records, fx.causal_redaction_marker));
    try std.testing.expect(recordsContainString(records, fx.causal_truncation_marker));
}

test "otel backend max_records fails closed without partial records" {
    var backend_state = fx.CausalOtelBackendState.init(std.testing.allocator, .{ .max_records = 0 });
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const id = try store.record(.{
        .kind = .run_started,
        .label = "overflowing-otel-record",
    });

    try std.testing.expectEqual(@as(u64, 1), id);
    try std.testing.expectEqual(@as(usize, 0), backend_state.recordedRecords().len);
    try std.testing.expectEqual(@as(u64, 0), backend_state.writtenRecordCount());
    try std.testing.expectEqual(@as(u64, 1), backend_state.failedRecordCount());
    try std.testing.expectEqual(@as(u64, 1), store.backendFailureCount());

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expectEqual(id, snapshot.events[0].id);
}
