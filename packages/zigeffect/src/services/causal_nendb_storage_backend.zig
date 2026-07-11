const std = @import("std");
const causal = @import("causal.zig");
const causal_backend = @import("causal_backend.zig");

pub const Allocator = std.mem.Allocator;
pub const causal_nendb_node_schema = "zigeffect.causal.nendb_node.v1";
pub const causal_nendb_node_schema_version: u32 = 1;
pub const causal_nendb_edge_schema = "zigeffect.causal.nendb_edge.v1";
pub const causal_nendb_edge_schema_version: u32 = 1;
pub const causal_nendb_retention_report_schema = "zigeffect.causal.nendb-retention-report.v1";
pub const causal_nendb_retention_report_schema_version: u32 = 1;
pub const causal_nendb_durable_history_schema = "zigeffect.causal.nendb-durable-history.v1";
pub const causal_nendb_durable_history_schema_version: u32 = 1;

pub const CausalNendbNode = struct {
    id: u64,
    label: []const u8,
    kind: u8,
    properties: []const u8,
};

pub const CausalNendbEdge = struct {
    from: u64,
    to: u64,
    label: []const u8,
    label_id: u16,
    properties: []const u8,
};

pub const CausalNendbWrite = struct {
    node: CausalNendbNode,
    parent_edge: ?CausalNendbEdge = null,
};

pub const CausalNendbGraphWriter = struct {
    state: ?*anyopaque = null,
    write: *const fn (?*anyopaque, CausalNendbWrite) anyerror!void,
    flush: ?*const fn (?*anyopaque) anyerror!void = null,
};

pub const CausalNendbStorageBackendOptions = struct {
    max_events: ?usize = null,
};

pub const CausalNendbRetentionPolicy = struct {
    max_events: ?usize = null,
    ttl_days: ?u32 = null,
    compaction_trigger_events: ?usize = null,
    compact_to_events: ?usize = null,
    backup_required: bool = false,
    recovery_required: bool = false,
};

pub const CausalNendbRetentionReport = struct {
    schema: []const u8 = causal_nendb_retention_report_schema,
    schema_version: u32 = causal_nendb_retention_report_schema_version,
    retained_events: usize = 0,
    max_events: ?usize = null,
    ttl_days: ?u32 = null,
    compaction_trigger_events: ?usize = null,
    compact_to_events: ?usize = null,
    compaction_required: bool = false,
    backup_required: bool = false,
    recovery_required: bool = false,
    oldest_retained_event_id: ?u64 = null,
    newest_retained_event_id: ?u64 = null,
};

pub const CausalNendbDurableHistoryPolicy = struct {
    max_events: ?usize = null,
    ttl_days: ?u32 = null,
    compaction_trigger_events: ?usize = null,
    compact_to_events: ?usize = null,
    backup_required: bool = false,
    recovery_required: bool = false,
    flush_required: bool = false,
    redaction_required: bool = false,
    lineage_query_required: bool = false,
};

pub const CausalNendbDurableHistoryReport = struct {
    schema: []const u8 = causal_nendb_durable_history_schema,
    schema_version: u32 = causal_nendb_durable_history_schema_version,
    backend_kind: []const u8 = "nendb_graph",
    storage_adapter: []const u8 = "NenDB adapter",
    node_schema: []const u8 = causal_nendb_node_schema,
    edge_schema: []const u8 = causal_nendb_edge_schema,
    retained_events: usize = 0,
    max_events: ?usize = null,
    ttl_days: ?u32 = null,
    compaction_trigger_events: ?usize = null,
    compact_to_events: ?usize = null,
    written_events: u64 = 0,
    failed_events: u64 = 0,
    flushed_count: u64 = 0,
    oldest_retained_event_id: ?u64 = null,
    newest_retained_event_id: ?u64 = null,
    writer_attached: bool = false,
    flush_required: bool = false,
    flush_observed: bool = false,
    redaction_required: bool = false,
    redaction_observed: bool = false,
    lineage_query_required: bool = false,
    lineage_query_supported: bool = true,
    compaction_required: bool = false,
    backup_required: bool = false,
    recovery_required: bool = false,
    live_telemetry_enabled: bool = false,
    network_send_enabled: bool = false,
    durable_write_authority: bool = false,
    nendb_write_authority: bool = false,
    cockroach_adapter_enabled: bool = false,
    mutation_authority: []const u8 = "none",
};

pub const CausalNendbStorageBackendError = error{
    CausalNendbStorageBackendFull,
    CausalNendbWriterRejected,
};

pub const CausalNendbStorageBackendState = struct {
    allocator: Allocator,
    writer: CausalNendbGraphWriter,
    events: std.ArrayList(causal.CausalEvent) = .empty,
    max_events: ?usize = null,
    written_event_count: u64 = 0,
    failed_event_count: u64 = 0,
    flushed_count: u64 = 0,
    last_failure: ?anyerror = null,

    pub fn init(
        allocator: Allocator,
        writer: CausalNendbGraphWriter,
        options: CausalNendbStorageBackendOptions,
    ) CausalNendbStorageBackendState {
        return .{
            .allocator = allocator,
            .writer = writer,
            .max_events = options.max_events,
        };
    }

    pub fn deinit(self: *CausalNendbStorageBackendState) void {
        for (self.events.items) |event| {
            deinitEventStrings(self.allocator, event);
        }
        self.events.deinit(self.allocator);
    }

    pub fn backend(self: *CausalNendbStorageBackendState) causal_backend.CausalBackend {
        return .{
            .kind = .nendb_graph,
            .state = self,
            .record = recordNendbStorageBackend,
        };
    }

    pub fn eventCount(self: *const CausalNendbStorageBackendState) usize {
        return self.events.items.len;
    }

    pub fn writtenEventCount(self: *const CausalNendbStorageBackendState) u64 {
        return self.written_event_count;
    }

    pub fn failedEventCount(self: *const CausalNendbStorageBackendState) u64 {
        return self.failed_event_count;
    }

    pub fn lastFailure(self: *const CausalNendbStorageBackendState) ?anyerror {
        return self.last_failure;
    }

    pub fn flushedCount(self: *const CausalNendbStorageBackendState) u64 {
        return self.flushed_count;
    }

    pub fn retentionReport(
        self: *const CausalNendbStorageBackendState,
        policy: CausalNendbRetentionPolicy,
    ) CausalNendbRetentionReport {
        const retained_events = self.events.items.len;
        return .{
            .retained_events = retained_events,
            .max_events = policy.max_events,
            .ttl_days = policy.ttl_days,
            .compaction_trigger_events = policy.compaction_trigger_events,
            .compact_to_events = policy.compact_to_events,
            .compaction_required = isCompactionRequired(retained_events, policy.compaction_trigger_events),
            .backup_required = policy.backup_required,
            .recovery_required = policy.recovery_required,
            .oldest_retained_event_id = self.oldestRetainedEventId(),
            .newest_retained_event_id = self.newestRetainedEventId(),
        };
    }

    pub fn durableHistoryReport(
        self: *const CausalNendbStorageBackendState,
        policy: CausalNendbDurableHistoryPolicy,
    ) CausalNendbDurableHistoryReport {
        const retained_events = self.events.items.len;
        return .{
            .retained_events = retained_events,
            .max_events = policy.max_events,
            .ttl_days = policy.ttl_days,
            .compaction_trigger_events = policy.compaction_trigger_events,
            .compact_to_events = policy.compact_to_events,
            .written_events = self.written_event_count,
            .failed_events = self.failed_event_count,
            .flushed_count = self.flushed_count,
            .oldest_retained_event_id = self.oldestRetainedEventId(),
            .newest_retained_event_id = self.newestRetainedEventId(),
            .writer_attached = true,
            .flush_required = policy.flush_required,
            .flush_observed = !policy.flush_required or self.flushed_count > 0,
            .redaction_required = policy.redaction_required,
            .redaction_observed = !policy.redaction_required or self.hasRedactionEvidence(),
            .lineage_query_required = policy.lineage_query_required,
            .lineage_query_supported = true,
            .compaction_required = isCompactionRequired(retained_events, policy.compaction_trigger_events),
            .backup_required = policy.backup_required,
            .recovery_required = policy.recovery_required,
        };
    }

    pub fn flush(self: *CausalNendbStorageBackendState) anyerror!void {
        if (self.writer.flush) |flush_writer| {
            flush_writer(self.writer.state) catch |err| {
                self.last_failure = err;
                return err;
            };
            self.flushed_count += 1;
        }
    }

    pub fn snapshot(self: *const CausalNendbStorageBackendState, allocator: Allocator) Allocator.Error!causal.CausalSnapshot {
        return snapshotFromEvents(allocator, self.events.items);
    }

    pub fn cause(self: *const CausalNendbStorageBackendState, allocator: Allocator, event_id: u64) Allocator.Error!causal.CausalLineage {
        var output = std.ArrayList(causal.CausalEvent).empty;
        errdefer deinitEventList(allocator, &output);

        try self.appendCauseChain(allocator, &output, event_id);

        return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
    }

    pub fn lineage(self: *const CausalNendbStorageBackendState, allocator: Allocator, event_id: u64) Allocator.Error!causal.CausalLineage {
        var output = std.ArrayList(causal.CausalEvent).empty;
        errdefer deinitEventList(allocator, &output);

        for (self.events.items) |event| {
            if (event.id == event_id or event.parent_id == event_id) {
                try appendClonedEvent(allocator, &output, event);
            }
        }

        return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
    }

    pub fn eventsByKind(self: *const CausalNendbStorageBackendState, allocator: Allocator, kind: causal.CausalEventKind) Allocator.Error!causal.CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: causal.CausalEvent, expected: causal.CausalEventKind) bool {
                return event.kind == expected;
            }
        }.matches, kind);
    }

    pub fn eventsByRun(self: *const CausalNendbStorageBackendState, allocator: Allocator, run_id: u64) Allocator.Error!causal.CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: causal.CausalEvent, expected: u64) bool {
                return event.run_id == expected;
            }
        }.matches, run_id);
    }

    pub fn eventsByScope(self: *const CausalNendbStorageBackendState, allocator: Allocator, scope_id: u64) Allocator.Error!causal.CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: causal.CausalEvent, expected: u64) bool {
                return event.scope_id == expected;
            }
        }.matches, scope_id);
    }

    pub fn eventsByFiber(self: *const CausalNendbStorageBackendState, allocator: Allocator, fiber_id: u64) Allocator.Error!causal.CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: causal.CausalEvent, expected: u64) bool {
                return event.fiber_id == expected;
            }
        }.matches, fiber_id);
    }

    fn findEvent(self: *const CausalNendbStorageBackendState, event_id: u64) ?causal.CausalEvent {
        for (self.events.items) |event| {
            if (event.id == event_id) return event;
        }
        return null;
    }

    fn oldestRetainedEventId(self: *const CausalNendbStorageBackendState) ?u64 {
        if (self.events.items.len == 0) return null;
        return self.events.items[0].id;
    }

    fn newestRetainedEventId(self: *const CausalNendbStorageBackendState) ?u64 {
        if (self.events.items.len == 0) return null;
        return self.events.items[self.events.items.len - 1].id;
    }

    fn hasRedactionEvidence(self: *const CausalNendbStorageBackendState) bool {
        for (self.events.items) |event| {
            if (std.mem.indexOf(u8, event.redacted_detail, causal.causal_redaction_marker) != null) {
                return true;
            }
        }
        return false;
    }

    fn appendCauseChain(
        self: *const CausalNendbStorageBackendState,
        allocator: Allocator,
        output: *std.ArrayList(causal.CausalEvent),
        event_id: u64,
    ) Allocator.Error!void {
        const event = self.findEvent(event_id) orelse return;
        if (event.parent_id) |parent_id| {
            try self.appendCauseChain(allocator, output, parent_id);
        }
        try appendClonedEvent(allocator, output, event);
    }

    fn filterEvents(
        self: *const CausalNendbStorageBackendState,
        allocator: Allocator,
        comptime matches: anytype,
        expected: anytype,
    ) Allocator.Error!causal.CausalSnapshot {
        var output = std.ArrayList(causal.CausalEvent).empty;
        errdefer deinitEventList(allocator, &output);

        for (self.events.items) |event| {
            if (matches(event, expected)) {
                try appendClonedEvent(allocator, &output, event);
            }
        }

        return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
    }
};

pub fn stableCausalNendbLabelId(value: []const u8) u8 {
    const hash = stableHash32(value);
    const label_id: u8 = @truncate(hash);
    return if (label_id == 0) 1 else label_id;
}

pub fn stableCausalNendbEdgeLabelId(value: []const u8) u16 {
    const hash = stableHash32(value);
    const label_id: u16 = @truncate(hash);
    return if (label_id == 0) 1 else label_id;
}

pub fn mapCausalEventToNendbWrite(allocator: Allocator, event: causal.CausalEvent) Allocator.Error!CausalNendbWrite {
    const node_label = try cloneSlice(allocator, "causal_event");
    errdefer if (node_label.len > 0) allocator.free(node_label);

    const node_properties = try formatNendbNodeProperties(allocator, event);
    errdefer if (node_properties.len > 0) allocator.free(node_properties);

    var write = CausalNendbWrite{
        .node = .{
            .id = event.id,
            .label = node_label,
            .kind = stableCausalNendbLabelId(@tagName(event.kind)),
            .properties = node_properties,
        },
    };

    if (event.parent_id) |parent_id| {
        const edge_label = try cloneSlice(allocator, "causal_parent");
        errdefer if (edge_label.len > 0) allocator.free(edge_label);
        const edge_properties = try formatNendbEdgeProperties(allocator, event, parent_id);
        errdefer if (edge_properties.len > 0) allocator.free(edge_properties);
        write.parent_edge = .{
            .from = parent_id,
            .to = event.id,
            .label = edge_label,
            .label_id = stableCausalNendbEdgeLabelId("causal_parent"),
            .properties = edge_properties,
        };
    }

    return write;
}

pub fn cloneCausalNendbWrite(allocator: Allocator, write: CausalNendbWrite) Allocator.Error!CausalNendbWrite {
    var cloned = CausalNendbWrite{
        .node = .{
            .id = write.node.id,
            .label = try cloneSlice(allocator, write.node.label),
            .kind = write.node.kind,
            .properties = "",
        },
    };
    errdefer if (cloned.node.label.len > 0) allocator.free(cloned.node.label);

    cloned.node.properties = try cloneSlice(allocator, write.node.properties);
    errdefer if (cloned.node.properties.len > 0) allocator.free(cloned.node.properties);

    if (write.parent_edge) |edge| {
        var cloned_edge = CausalNendbEdge{
            .from = edge.from,
            .to = edge.to,
            .label = try cloneSlice(allocator, edge.label),
            .label_id = edge.label_id,
            .properties = "",
        };
        errdefer if (cloned_edge.label.len > 0) allocator.free(cloned_edge.label);

        cloned_edge.properties = try cloneSlice(allocator, edge.properties);
        errdefer if (cloned_edge.properties.len > 0) allocator.free(cloned_edge.properties);
        cloned.parent_edge = cloned_edge;
    }

    return cloned;
}

pub fn deinitCausalNendbWrite(allocator: Allocator, write: *CausalNendbWrite) void {
    if (write.node.label.len > 0) allocator.free(write.node.label);
    if (write.node.properties.len > 0) allocator.free(write.node.properties);
    if (write.parent_edge) |edge| {
        if (edge.label.len > 0) allocator.free(edge.label);
        if (edge.properties.len > 0) allocator.free(edge.properties);
    }
    write.* = .{
        .node = .{
            .id = 0,
            .label = "",
            .kind = 0,
            .properties = "",
        },
    };
}

fn stableHash32(value: []const u8) u32 {
    var hash: u32 = 2166136261;
    for (value) |byte| {
        hash ^= byte;
        hash *%= 16777619;
    }
    return hash;
}

fn isCompactionRequired(retained_events: usize, trigger: ?usize) bool {
    const threshold = trigger orelse return false;
    return retained_events > threshold;
}

fn cloneSlice(allocator: Allocator, value: []const u8) Allocator.Error![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

fn cloneEvent(allocator: Allocator, event: causal.CausalEvent) Allocator.Error!causal.CausalEvent {
    var owned = event;
    owned.label = try cloneSlice(allocator, event.label);
    errdefer if (owned.label.len > 0) allocator.free(owned.label);
    owned.type_name = try cloneSlice(allocator, event.type_name);
    errdefer if (owned.type_name.len > 0) allocator.free(owned.type_name);
    owned.layer_name = try cloneSlice(allocator, event.layer_name);
    errdefer if (owned.layer_name.len > 0) allocator.free(owned.layer_name);
    owned.service_key = try cloneSlice(allocator, event.service_key);
    errdefer if (owned.service_key.len > 0) allocator.free(owned.service_key);
    owned.artifact_id = try cloneSlice(allocator, event.artifact_id);
    errdefer if (owned.artifact_id.len > 0) allocator.free(owned.artifact_id);
    owned.domain_entity_ref = try cloneSlice(allocator, event.domain_entity_ref);
    errdefer if (owned.domain_entity_ref.len > 0) allocator.free(owned.domain_entity_ref);
    owned.data_subject_ref = try cloneSlice(allocator, event.data_subject_ref);
    errdefer if (owned.data_subject_ref.len > 0) allocator.free(owned.data_subject_ref);
    owned.schema_ref = try cloneSlice(allocator, event.schema_ref);
    errdefer if (owned.schema_ref.len > 0) allocator.free(owned.schema_ref);
    owned.status = try cloneSlice(allocator, event.status);
    errdefer if (owned.status.len > 0) allocator.free(owned.status);
    owned.redacted_detail = try cloneSlice(allocator, event.redacted_detail);
    errdefer if (owned.redacted_detail.len > 0) allocator.free(owned.redacted_detail);
    return owned;
}

fn deinitEventStrings(allocator: Allocator, event: causal.CausalEvent) void {
    if (event.label.len > 0) allocator.free(event.label);
    if (event.type_name.len > 0) allocator.free(event.type_name);
    if (event.layer_name.len > 0) allocator.free(event.layer_name);
    if (event.service_key.len > 0) allocator.free(event.service_key);
    if (event.artifact_id.len > 0) allocator.free(event.artifact_id);
    if (event.domain_entity_ref.len > 0) allocator.free(event.domain_entity_ref);
    if (event.data_subject_ref.len > 0) allocator.free(event.data_subject_ref);
    if (event.schema_ref.len > 0) allocator.free(event.schema_ref);
    if (event.status.len > 0) allocator.free(event.status);
    if (event.redacted_detail.len > 0) allocator.free(event.redacted_detail);
}

fn deinitEventList(allocator: Allocator, events: *std.ArrayList(causal.CausalEvent)) void {
    for (events.items) |event| {
        deinitEventStrings(allocator, event);
    }
    events.deinit(allocator);
}

fn appendClonedEvent(allocator: Allocator, output: *std.ArrayList(causal.CausalEvent), event: causal.CausalEvent) Allocator.Error!void {
    const cloned = try cloneEvent(allocator, event);
    errdefer deinitEventStrings(allocator, cloned);
    try output.append(allocator, cloned);
}

fn snapshotFromEvents(allocator: Allocator, source: []const causal.CausalEvent) Allocator.Error!causal.CausalSnapshot {
    const events = try allocator.alloc(causal.CausalEvent, source.len);
    errdefer allocator.free(events);

    var initialized: usize = 0;
    errdefer {
        for (events[0..initialized]) |event| {
            deinitEventStrings(allocator, event);
        }
    }

    for (source, 0..) |event, index| {
        events[index] = try cloneEvent(allocator, event);
        initialized += 1;
    }

    return .{ .allocator = allocator, .events = events };
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: Allocator, value: []const u8) Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            0x00...0x08, 0x0b, 0x0c, 0x0e...0x1f => try output.print(allocator, "\\u{x:0>4}", .{byte}),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

fn appendOptionalJsonU64(output: *std.ArrayList(u8), allocator: Allocator, value: ?u64) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendNodeCommonProperties(output: *std.ArrayList(u8), allocator: Allocator, event: causal.CausalEvent) Allocator.Error!void {
    try output.appendSlice(allocator, "\"event_id\":");
    try output.print(allocator, "{d}", .{event.id});
    try output.appendSlice(allocator, ",\"kind\":");
    try appendJsonString(output, allocator, @tagName(event.kind));
    try output.appendSlice(allocator, ",\"run_id\":");
    try appendOptionalJsonU64(output, allocator, event.run_id);
    try output.appendSlice(allocator, ",\"parent_id\":");
    try appendOptionalJsonU64(output, allocator, event.parent_id);
    try output.appendSlice(allocator, ",\"fiber_id\":");
    try appendOptionalJsonU64(output, allocator, event.fiber_id);
    try output.appendSlice(allocator, ",\"scope_id\":");
    try appendOptionalJsonU64(output, allocator, event.scope_id);
    try output.appendSlice(allocator, ",\"layer_id\":");
    try appendOptionalJsonU64(output, allocator, event.layer_id);
    try output.appendSlice(allocator, ",\"layer_name\":");
    try appendJsonString(output, allocator, event.layer_name);
    try output.appendSlice(allocator, ",\"service_key\":");
    try appendJsonString(output, allocator, event.service_key);
    try output.appendSlice(allocator, ",\"resource_id\":");
    try appendOptionalJsonU64(output, allocator, event.resource_id);
    try output.appendSlice(allocator, ",\"cause_event_id\":");
    try appendOptionalJsonU64(output, allocator, event.cause_event_id);
    try output.appendSlice(allocator, ",\"schedule_id\":");
    try appendOptionalJsonU64(output, allocator, event.schedule_id);
    try output.appendSlice(allocator, ",\"boundary_id\":");
    try appendOptionalJsonU64(output, allocator, event.boundary_id);
    try output.appendSlice(allocator, ",\"artifact_id\":");
    try appendJsonString(output, allocator, event.artifact_id);
    try output.appendSlice(allocator, ",\"domain_entity_ref\":");
    try appendJsonString(output, allocator, event.domain_entity_ref);
    try output.appendSlice(allocator, ",\"data_subject_ref\":");
    try appendJsonString(output, allocator, event.data_subject_ref);
    try output.appendSlice(allocator, ",\"schema_ref\":");
    try appendJsonString(output, allocator, event.schema_ref);
    try output.appendSlice(allocator, ",\"trace_id\":");
    try appendOptionalJsonU64(output, allocator, event.trace_id);
    try output.appendSlice(allocator, ",\"span_id\":");
    try appendOptionalJsonU64(output, allocator, event.span_id);
    try output.appendSlice(allocator, ",\"label\":");
    try appendJsonString(output, allocator, event.label);
    try output.appendSlice(allocator, ",\"type_name\":");
    try appendJsonString(output, allocator, event.type_name);
    try output.appendSlice(allocator, ",\"status\":");
    try appendJsonString(output, allocator, event.status);
    try output.appendSlice(allocator, ",\"redacted_detail\":");
    try appendJsonString(output, allocator, event.redacted_detail);
}

fn formatNendbNodeProperties(allocator: Allocator, event: causal.CausalEvent) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, causal_nendb_node_schema);
    try output.print(
        allocator,
        ",\"schema_version\":{d},\"event_taxonomy_version\":{d},",
        .{ causal_nendb_node_schema_version, causal.causal_event_taxonomy_version },
    );
    try appendNodeCommonProperties(&output, allocator, event);
    try output.appendSlice(allocator, "}");

    return output.toOwnedSlice(allocator);
}

fn formatNendbEdgeProperties(allocator: Allocator, event: causal.CausalEvent, parent_id: u64) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, causal_nendb_edge_schema);
    try output.print(
        allocator,
        ",\"schema_version\":{d},\"from_event_id\":{d},\"to_event_id\":{d},\"kind\":",
        .{ causal_nendb_edge_schema_version, parent_id, event.id },
    );
    try appendJsonString(&output, allocator, @tagName(event.kind));
    try output.appendSlice(allocator, ",\"run_id\":");
    try appendOptionalJsonU64(&output, allocator, event.run_id);
    try output.appendSlice(allocator, "}");

    return output.toOwnedSlice(allocator);
}

fn recordNendbStorageBackend(raw: ?*anyopaque, event: causal.CausalEvent) anyerror!void {
    const state: *CausalNendbStorageBackendState = @ptrCast(@alignCast(raw.?));
    if (state.max_events) |max_events| {
        if (state.events.items.len >= max_events) {
            state.failed_event_count += 1;
            state.last_failure = error.CausalNendbStorageBackendFull;
            return state.last_failure.?;
        }
    }

    state.events.ensureUnusedCapacity(state.allocator, 1) catch |err| {
        state.failed_event_count += 1;
        state.last_failure = err;
        return err;
    };

    const owned_event = cloneEvent(state.allocator, event) catch |err| {
        state.failed_event_count += 1;
        state.last_failure = err;
        return err;
    };
    errdefer deinitEventStrings(state.allocator, owned_event);

    var write = mapCausalEventToNendbWrite(state.allocator, event) catch |err| {
        state.failed_event_count += 1;
        state.last_failure = err;
        return err;
    };
    defer deinitCausalNendbWrite(state.allocator, &write);

    state.writer.write(state.writer.state, write) catch |err| {
        state.failed_event_count += 1;
        state.last_failure = err;
        return err;
    };

    state.events.appendAssumeCapacity(owned_event);
    state.written_event_count += 1;
}
