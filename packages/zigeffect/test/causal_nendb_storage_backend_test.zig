const std = @import("std");
const fx = @import("zigeffect");
const conformance = @import("support/causal_backend_conformance.zig");

const FakeNendbWriter = struct {
    allocator: std.mem.Allocator,
    writes: std.ArrayList(fx.CausalNendbWrite) = .empty,
    fail_next: bool = false,
    flush_count: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) FakeNendbWriter {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *FakeNendbWriter) void {
        for (self.writes.items) |*write| {
            fx.deinitCausalNendbWrite(self.allocator, write);
        }
        self.writes.deinit(self.allocator);
    }

    pub fn writer(self: *FakeNendbWriter) fx.CausalNendbGraphWriter {
        return .{
            .state = self,
            .write = writeFakeNendb,
            .flush = flushFakeNendb,
        };
    }
};

fn writeFakeNendb(raw: ?*anyopaque, write: fx.CausalNendbWrite) anyerror!void {
    const state: *FakeNendbWriter = @ptrCast(@alignCast(raw.?));
    if (state.fail_next) {
        state.fail_next = false;
        return error.FakeNendbWriterRejected;
    }

    var cloned = try fx.cloneCausalNendbWrite(state.allocator, write);
    errdefer fx.deinitCausalNendbWrite(state.allocator, &cloned);
    try state.writes.append(state.allocator, cloned);
}

fn flushFakeNendb(raw: ?*anyopaque) anyerror!void {
    const state: *FakeNendbWriter = @ptrCast(@alignCast(raw.?));
    state.flush_count += 1;
}

fn writesContainString(writes: []const fx.CausalNendbWrite, needle: []const u8) bool {
    for (writes) |write| {
        if (std.mem.indexOf(u8, write.node.label, needle) != null) return true;
        if (std.mem.indexOf(u8, write.node.properties, needle) != null) return true;
        if (write.parent_edge) |edge| {
            if (std.mem.indexOf(u8, edge.label, needle) != null) return true;
            if (std.mem.indexOf(u8, edge.properties, needle) != null) return true;
        }
    }
    return false;
}

test "map causal event to deterministic nendb node and parent edge" {
    var write = try fx.mapCausalEventToNendbWrite(std.testing.allocator, .{
        .id = 42,
        .kind = .effect_started,
        .run_id = 7,
        .parent_id = 9,
        .fiber_id = 10,
        .scope_id = 11,
        .layer_id = 12,
        .service_key = "VesselService",
        .resource_id = 13,
        .cause_event_id = 14,
        .schedule_id = 15,
        .artifact_id = "artifact:vessel",
        .domain_entity_ref = "vessel:abc",
        .data_subject_ref = "tenant:acme",
        .schema_ref = "Vessel.v1",
        .trace_id = 12,
        .span_id = 13,
        .label = "load-vessel",
        .type_name = "VesselEffect",
        .status = "running",
        .redacted_detail = "safe detail",
    });
    defer fx.deinitCausalNendbWrite(std.testing.allocator, &write);

    try std.testing.expectEqual(@as(u64, 42), write.node.id);
    try std.testing.expectEqualStrings("causal_event", write.node.label);
    try std.testing.expectEqual(fx.stableCausalNendbLabelId("effect_started"), write.node.kind);
    try std.testing.expect(std.mem.indexOf(u8, write.node.properties, "\"kind\":\"effect_started\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, write.node.properties, "\"event_id\":42") != null);
    try std.testing.expect(std.mem.indexOf(u8, write.node.properties, "\"run_id\":7") != null);
    try std.testing.expect(std.mem.indexOf(u8, write.node.properties, "\"layer_id\":12") != null);
    try std.testing.expect(std.mem.indexOf(u8, write.node.properties, "\"service_key\":\"VesselService\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, write.node.properties, "\"resource_id\":13") != null);
    try std.testing.expect(std.mem.indexOf(u8, write.node.properties, "\"cause_event_id\":14") != null);
    try std.testing.expect(std.mem.indexOf(u8, write.node.properties, "\"schedule_id\":15") != null);
    try std.testing.expect(std.mem.indexOf(u8, write.node.properties, "\"artifact_id\":\"artifact:vessel\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, write.node.properties, "\"domain_entity_ref\":\"vessel:abc\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, write.node.properties, "\"data_subject_ref\":\"tenant:acme\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, write.node.properties, "\"schema_ref\":\"Vessel.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, write.node.properties, "\"label\":\"load-vessel\"") != null);
    try std.testing.expect(write.parent_edge != null);
    try std.testing.expectEqual(@as(u64, 9), write.parent_edge.?.from);
    try std.testing.expectEqual(@as(u64, 42), write.parent_edge.?.to);
    try std.testing.expectEqualStrings("causal_parent", write.parent_edge.?.label);
    try std.testing.expectEqual(fx.stableCausalNendbEdgeLabelId("causal_parent"), write.parent_edge.?.label_id);
    try std.testing.expect(std.mem.indexOf(u8, write.parent_edge.?.properties, "\"from_event_id\":9") != null);
    try std.testing.expect(std.mem.indexOf(u8, write.parent_edge.?.properties, "\"to_event_id\":42") != null);

    var second = try fx.mapCausalEventToNendbWrite(std.testing.allocator, .{
        .id = 43,
        .kind = .effect_started,
        .parent_id = 42,
    });
    defer fx.deinitCausalNendbWrite(std.testing.allocator, &second);
    try std.testing.expectEqual(write.node.kind, second.node.kind);
    try std.testing.expectEqual(write.parent_edge.?.label_id, second.parent_edge.?.label_id);
}

test "nendb storage backend writes conformance events and keeps queryable history" {
    var fake = FakeNendbWriter.init(std.testing.allocator);
    defer fake.deinit();
    var backend_state = fx.CausalNendbStorageBackendState.init(std.testing.allocator, fake.writer(), .{});
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
    try std.testing.expectEqual(@as(usize, 3), fake.writes.items.len);
    try std.testing.expectEqual(ids.started, fake.writes.items[0].node.id);
    try std.testing.expect(fake.writes.items[0].parent_edge == null);
    try std.testing.expectEqual(ids.retained_log, fake.writes.items[1].node.id);
    try std.testing.expectEqual(ids.started, fake.writes.items[1].parent_edge.?.from);
    try std.testing.expectEqual(ids.retained_log, fake.writes.items[1].parent_edge.?.to);
    try std.testing.expectEqual(ids.completed, fake.writes.items[2].node.id);
    try std.testing.expectEqual(ids.started, fake.writes.items[2].parent_edge.?.from);
    try std.testing.expect(writesContainString(fake.writes.items, "raw-secret") == false);
    try std.testing.expect(writesContainString(fake.writes.items, fx.causal_redaction_marker));
    try std.testing.expect(writesContainString(fake.writes.items, fx.causal_truncation_marker));

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
}

test "nendb storage backend filters by run scope and fiber" {
    var fake = FakeNendbWriter.init(std.testing.allocator);
    defer fake.deinit();
    var backend_state = fx.CausalNendbStorageBackendState.init(std.testing.allocator, fake.writer(), .{});
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
        .label = "nendb-storage-run",
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

    var by_fiber = try backend_state.eventsByFiber(std.testing.allocator, 42);
    defer by_fiber.deinit();
    try std.testing.expectEqual(@as(usize, 1), by_fiber.events.len);
    try std.testing.expectEqual(@as(?u64, 42), by_fiber.events[0].fiber_id);
}

test "nendb storage writer failure fails closed without local history" {
    var fake = FakeNendbWriter.init(std.testing.allocator);
    defer fake.deinit();
    fake.fail_next = true;
    var backend_state = fx.CausalNendbStorageBackendState.init(std.testing.allocator, fake.writer(), .{});
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const id = try store.record(.{
        .kind = .run_started,
        .label = "writer-failure",
    });

    try std.testing.expectEqual(@as(u64, 1), id);
    try std.testing.expectEqual(@as(usize, 0), fake.writes.items.len);
    try std.testing.expectEqual(@as(usize, 0), backend_state.eventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.writtenEventCount());
    try std.testing.expectEqual(@as(u64, 1), backend_state.failedEventCount());
    try std.testing.expectEqual(@as(u64, 1), store.backendFailureCount());

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expectEqual(id, snapshot.events[0].id);
}

test "nendb storage max_events fails before writer call" {
    var fake = FakeNendbWriter.init(std.testing.allocator);
    defer fake.deinit();
    var backend_state = fx.CausalNendbStorageBackendState.init(std.testing.allocator, fake.writer(), .{ .max_events = 0 });
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    _ = try store.record(.{
        .kind = .run_started,
        .label = "overflowing-nendb-storage",
    });

    try std.testing.expectEqual(@as(usize, 0), fake.writes.items.len);
    try std.testing.expectEqual(@as(usize, 0), backend_state.eventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.writtenEventCount());
    try std.testing.expectEqual(@as(u64, 1), backend_state.failedEventCount());
    try std.testing.expectEqual(@as(u64, 1), store.backendFailureCount());
}

test "nendb storage backend flush invokes optional writer hook" {
    var fake = FakeNendbWriter.init(std.testing.allocator);
    defer fake.deinit();
    var backend_state = fx.CausalNendbStorageBackendState.init(std.testing.allocator, fake.writer(), .{});
    defer backend_state.deinit();

    try backend_state.flush();
    try std.testing.expectEqual(@as(u64, 1), fake.flush_count);
    try std.testing.expectEqual(@as(u64, 1), backend_state.flushedCount());
}

test "nendb storage retention report derives policy and event bounds" {
    var fake = FakeNendbWriter.init(std.testing.allocator);
    defer fake.deinit();
    var backend_state = fx.CausalNendbStorageBackendState.init(std.testing.allocator, fake.writer(), .{});
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const root = try store.record(.{
        .kind = .run_started,
        .run_id = 7,
        .label = "retained-root",
    });
    const child = try store.record(.{
        .kind = .effect_completed,
        .run_id = 7,
        .parent_id = root,
        .label = "retained-child",
    });

    const report = backend_state.retentionReport(.{
        .max_events = 16,
        .ttl_days = 14,
        .compaction_trigger_events = 1,
        .compact_to_events = 1,
        .backup_required = true,
        .recovery_required = true,
    });

    try std.testing.expectEqualStrings(fx.causal_nendb_retention_report_schema, report.schema);
    try std.testing.expectEqual(@as(u32, 1), report.schema_version);
    try std.testing.expectEqual(@as(usize, 2), report.retained_events);
    try std.testing.expectEqual(@as(?usize, 16), report.max_events);
    try std.testing.expectEqual(@as(?u32, 14), report.ttl_days);
    try std.testing.expectEqual(@as(?usize, 1), report.compaction_trigger_events);
    try std.testing.expectEqual(@as(?usize, 1), report.compact_to_events);
    try std.testing.expectEqual(true, report.compaction_required);
    try std.testing.expectEqual(true, report.backup_required);
    try std.testing.expectEqual(true, report.recovery_required);
    try std.testing.expectEqual(@as(?u64, root), report.oldest_retained_event_id);
    try std.testing.expectEqual(@as(?u64, child), report.newest_retained_event_id);
}

test "nendb durable history report exposes bounded queryable evidence" {
    var fake = FakeNendbWriter.init(std.testing.allocator);
    defer fake.deinit();
    var backend_state = fx.CausalNendbStorageBackendState.init(std.testing.allocator, fake.writer(), .{ .max_events = 16 });
    defer backend_state.deinit();

    var store = fx.CausalStore.initWithOptions(std.testing.allocator, .{
        .max_events = 1,
    });
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const root = try store.record(.{
        .kind = .run_started,
        .run_id = 77,
        .label = "durable-history-root",
        .redacted_detail = fx.causal_redaction_marker,
    });
    const child = try store.record(.{
        .kind = .log_recorded,
        .run_id = 77,
        .parent_id = root,
        .label = "durable-history-child",
        .redacted_detail = "safe retained detail",
    });
    _ = try store.record(.{
        .kind = .effect_completed,
        .run_id = 77,
        .parent_id = root,
        .label = "durable-history-terminal",
        .redacted_detail = "complete",
    });
    try backend_state.flush();

    var store_cause = try store.cause(std.testing.allocator, child);
    defer store_cause.deinit();
    try std.testing.expectEqual(@as(usize, 0), store_cause.events.len);

    var history_cause = try backend_state.cause(std.testing.allocator, child);
    defer history_cause.deinit();
    try std.testing.expectEqual(@as(usize, 2), history_cause.events.len);
    try std.testing.expectEqual(root, history_cause.events[0].id);
    try std.testing.expectEqual(child, history_cause.events[1].id);

    const report = backend_state.durableHistoryReport(.{
        .max_events = 16,
        .ttl_days = 14,
        .compaction_trigger_events = 2,
        .compact_to_events = 1,
        .backup_required = true,
        .recovery_required = true,
        .flush_required = true,
        .redaction_required = true,
        .lineage_query_required = true,
    });

    try std.testing.expectEqualStrings(fx.causal_nendb_durable_history_schema, report.schema);
    try std.testing.expectEqual(@as(u32, 1), report.schema_version);
    try std.testing.expectEqualStrings("nendb_graph", report.backend_kind);
    try std.testing.expectEqualStrings("NenDB adapter", report.storage_adapter);
    try std.testing.expectEqual(@as(usize, 3), report.retained_events);
    try std.testing.expectEqual(@as(?usize, 16), report.max_events);
    try std.testing.expectEqual(@as(u64, 3), report.written_events);
    try std.testing.expectEqual(@as(u64, 0), report.failed_events);
    try std.testing.expectEqual(@as(u64, 1), report.flushed_count);
    try std.testing.expectEqual(@as(?u64, root), report.oldest_retained_event_id);
    try std.testing.expectEqual(@as(?u64, 3), report.newest_retained_event_id);
    try std.testing.expect(report.writer_attached);
    try std.testing.expect(report.flush_required);
    try std.testing.expect(report.flush_observed);
    try std.testing.expect(report.redaction_required);
    try std.testing.expect(report.redaction_observed);
    try std.testing.expect(report.lineage_query_required);
    try std.testing.expect(report.lineage_query_supported);
    try std.testing.expect(report.compaction_required);
    try std.testing.expect(report.backup_required);
    try std.testing.expect(report.recovery_required);
    try std.testing.expect(!report.live_telemetry_enabled);
    try std.testing.expect(!report.network_send_enabled);
    try std.testing.expect(!report.durable_write_authority);
    try std.testing.expect(!report.nendb_write_authority);
    try std.testing.expect(!report.cockroach_adapter_enabled);
    try std.testing.expectEqualStrings("none", report.mutation_authority);
}

test "nendb durable history report keeps redaction evidence explicit" {
    var fake = FakeNendbWriter.init(std.testing.allocator);
    defer fake.deinit();
    var backend_state = fx.CausalNendbStorageBackendState.init(std.testing.allocator, fake.writer(), .{});
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    _ = try store.record(.{
        .kind = .run_started,
        .label = "no-redaction-marker",
        .redacted_detail = "safe but unmarked",
    });

    const report = backend_state.durableHistoryReport(.{
        .redaction_required = true,
        .lineage_query_required = true,
    });

    try std.testing.expect(report.redaction_required);
    try std.testing.expect(!report.redaction_observed);
    try std.testing.expect(report.lineage_query_supported);
}
