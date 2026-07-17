const std = @import("std");
const causal = @import("causal.zig");
const causal_backend = @import("causal_backend.zig");

pub const Allocator = std.mem.Allocator;
pub const causal_otel_record_schema = "zigeffect.causal.otel_record.v1";
pub const causal_otel_record_schema_version: u32 = 1;

pub const CausalOtelSignal = enum {
    span_event,
    log_record,
};

pub const CausalOtelAttributeValue = union(enum) {
    string: []const u8,
    u64: u64,
    bool: bool,
};

pub const CausalOtelAttribute = struct {
    key: []const u8,
    value: CausalOtelAttributeValue,
};

pub const CausalOtelRecord = struct {
    signal: CausalOtelSignal,
    name: []const u8,
    trace_id: ?u64 = null,
    span_id: ?u64 = null,
    trace_id_hex: ?[32]u8 = null,
    span_id_hex: ?[16]u8 = null,
    attributes: []CausalOtelAttribute = &.{},

    pub fn deinit(self: *CausalOtelRecord, allocator: Allocator) void {
        if (self.name.len > 0) allocator.free(self.name);
        for (self.attributes) |item| {
            if (item.key.len > 0) allocator.free(item.key);
            switch (item.value) {
                .string => |value| if (value.len > 0) allocator.free(value),
                else => {},
            }
        }
        if (self.attributes.len > 0) allocator.free(self.attributes);
        self.* = .{
            .signal = .log_record,
            .name = "",
        };
    }

    pub fn attribute(self: *const CausalOtelRecord, key: []const u8) ?CausalOtelAttributeValue {
        for (self.attributes) |candidate| {
            if (std.mem.eql(u8, candidate.key, key)) return candidate.value;
        }
        return null;
    }
};

pub const CausalOtelBackendOptions = struct {
    max_records: ?usize = null,
};

pub const CausalOtelBackendError = error{
    CausalOtelBackendFull,
};

pub const CausalOtelBackendState = struct {
    allocator: Allocator,
    records: std.ArrayList(CausalOtelRecord) = .empty,
    max_records: ?usize = null,
    written_record_count: u64 = 0,
    failed_record_count: u64 = 0,

    pub fn init(allocator: Allocator, options: CausalOtelBackendOptions) CausalOtelBackendState {
        return .{
            .allocator = allocator,
            .max_records = options.max_records,
        };
    }

    pub fn deinit(self: *CausalOtelBackendState) void {
        for (self.records.items) |*record| {
            record.deinit(self.allocator);
        }
        self.records.deinit(self.allocator);
    }

    pub fn backend(self: *CausalOtelBackendState) causal_backend.CausalBackend {
        return .{
            .kind = .opentelemetry,
            .state = self,
            .record = recordOtelBackend,
        };
    }

    pub fn recordedRecords(self: *const CausalOtelBackendState) []const CausalOtelRecord {
        return self.records.items;
    }

    pub fn writtenRecordCount(self: *const CausalOtelBackendState) u64 {
        return self.written_record_count;
    }

    pub fn failedRecordCount(self: *const CausalOtelBackendState) u64 {
        return self.failed_record_count;
    }
};

pub fn classifyCausalOtelSignal(event: causal.CausalEvent) CausalOtelSignal {
    if ((event.trace_id != null or event.context.trace_id_low != null) and
        (event.span_id != null or event.context.span_id != null)) return .span_event;
    return .log_record;
}

pub fn formatCausalOtelTraceId(trace_id: u64) [32]u8 {
    var output: [32]u8 = undefined;
    @memcpy(output[0..16], "0000000000000000");
    _ = std.fmt.bufPrint(output[16..], "{x:0>16}", .{trace_id}) catch unreachable;
    return output;
}

pub fn formatCausalOtelTraceId128(high: u64, low: u64) [32]u8 {
    var output: [32]u8 = undefined;
    _ = std.fmt.bufPrint(output[0..16], "{x:0>16}", .{high}) catch unreachable;
    _ = std.fmt.bufPrint(output[16..32], "{x:0>16}", .{low}) catch unreachable;
    return output;
}

pub fn formatCausalOtelSpanId(span_id: u64) [16]u8 {
    var output: [16]u8 = undefined;
    _ = std.fmt.bufPrint(output[0..], "{x:0>16}", .{span_id}) catch unreachable;
    return output;
}

fn cloneString(allocator: Allocator, value: []const u8) Allocator.Error![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

fn appendStringAttribute(
    allocator: Allocator,
    attributes: *std.ArrayList(CausalOtelAttribute),
    key: []const u8,
    value: []const u8,
) Allocator.Error!void {
    const owned_key = try cloneString(allocator, key);
    errdefer if (owned_key.len > 0) allocator.free(owned_key);
    const owned_value = try cloneString(allocator, value);
    errdefer if (owned_value.len > 0) allocator.free(owned_value);
    try attributes.append(allocator, .{
        .key = owned_key,
        .value = .{ .string = owned_value },
    });
}

fn appendU64Attribute(
    allocator: Allocator,
    attributes: *std.ArrayList(CausalOtelAttribute),
    key: []const u8,
    value: u64,
) Allocator.Error!void {
    const owned_key = try cloneString(allocator, key);
    errdefer if (owned_key.len > 0) allocator.free(owned_key);
    try attributes.append(allocator, .{
        .key = owned_key,
        .value = .{ .u64 = value },
    });
}

fn appendOptionalU64Attribute(
    allocator: Allocator,
    attributes: *std.ArrayList(CausalOtelAttribute),
    key: []const u8,
    value: ?u64,
) Allocator.Error!void {
    if (value) |number| {
        try appendU64Attribute(allocator, attributes, key, number);
    }
}

fn appendBoolAttribute(
    allocator: Allocator,
    attributes: *std.ArrayList(CausalOtelAttribute),
    key: []const u8,
    value: bool,
) Allocator.Error!void {
    const owned_key = try cloneString(allocator, key);
    errdefer if (owned_key.len > 0) allocator.free(owned_key);
    try attributes.append(allocator, .{
        .key = owned_key,
        .value = .{ .bool = value },
    });
}

fn appendOptionalStringAttribute(
    allocator: Allocator,
    attributes: *std.ArrayList(CausalOtelAttribute),
    key: []const u8,
    value: []const u8,
) Allocator.Error!void {
    if (value.len > 0) {
        try appendStringAttribute(allocator, attributes, key, value);
    }
}

pub fn mapCausalEventToOtelRecord(allocator: Allocator, event: causal.CausalEvent) Allocator.Error!CausalOtelRecord {
    const signal = classifyCausalOtelSignal(event);
    var attributes = std.ArrayList(CausalOtelAttribute).empty;
    errdefer {
        for (attributes.items) |item| {
            if (item.key.len > 0) allocator.free(item.key);
            switch (item.value) {
                .string => |value| if (value.len > 0) allocator.free(value),
                else => {},
            }
        }
        attributes.deinit(allocator);
    }

    const name = try std.fmt.allocPrint(allocator, "zigeffect.causal.{s}", .{@tagName(event.kind)});
    errdefer allocator.free(name);

    try appendStringAttribute(allocator, &attributes, "zigeffect.causal.schema", causal_otel_record_schema);
    try appendU64Attribute(allocator, &attributes, "zigeffect.causal.schema_version", causal_otel_record_schema_version);
    try appendU64Attribute(allocator, &attributes, "zigeffect.causal.event_taxonomy_version", causal.causal_event_taxonomy_version);
    try appendU64Attribute(allocator, &attributes, "zigeffect.causal.event_id", event.id);
    try appendStringAttribute(allocator, &attributes, "zigeffect.causal.kind", @tagName(event.kind));
    try appendStringAttribute(allocator, &attributes, "zigeffect.causal.signal", @tagName(signal));
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.run_id", event.run_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.parent_event_id", event.parent_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.fiber_id", event.fiber_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.scope_id", event.scope_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.layer_id", event.layer_id);
    try appendOptionalStringAttribute(allocator, &attributes, "zigeffect.causal.layer_name", event.layer_name);
    try appendOptionalStringAttribute(allocator, &attributes, "zigeffect.causal.service_key", event.service_key);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.resource_id", event.resource_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.cause_event_id", event.cause_event_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.schedule_id", event.schedule_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.boundary_id", event.boundary_id);
    try appendOptionalStringAttribute(allocator, &attributes, "zigeffect.causal.artifact_id", event.artifact_id);
    try appendOptionalStringAttribute(allocator, &attributes, "zigeffect.causal.domain_entity_ref", event.domain_entity_ref);
    try appendOptionalStringAttribute(allocator, &attributes, "zigeffect.causal.data_subject_ref", event.data_subject_ref);
    try appendOptionalStringAttribute(allocator, &attributes, "zigeffect.causal.schema_ref", event.schema_ref);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.trace_id", event.trace_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.span_id", event.span_id);
    try appendU64Attribute(allocator, &attributes, "zigeffect.causal.context_schema_version", event.context.schema_version);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.runtime_instance_id", event.context.runtime_instance_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.graph_session_id", event.context.graph_session_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.workspace_id", event.context.workspace_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.project_id", event.context.project_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.component_id", event.context.component_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.requirement_id", event.context.requirement_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.acceptance_check_id", event.context.acceptance_check_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.scenario_id", event.context.scenario_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.agent_id", event.context.agent_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.agent_attempt", event.context.agent_attempt);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.development_task_id", event.context.development_task_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.work_packet_id", event.context.work_packet_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.change_set_id", event.context.change_set_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.source_revision_id", event.context.source_revision_id);
    const telemetry_lineage_count = event.context.lineage.telemetryCount();
    if (telemetry_lineage_count != 0) {
        try appendU64Attribute(allocator, &attributes, "zigeffect.lineage.count", telemetry_lineage_count);
        try appendU64Attribute(allocator, &attributes, "zigeffect.lineage.exported_count", telemetry_lineage_count);
        try appendBoolAttribute(allocator, &attributes, "zigeffect.lineage.truncated", event.context.lineage.truncated);
        var exported_index: usize = 0;
        for (event.context.lineage.active()) |reference| {
            if (reference.export_policy != .otel) continue;
            var key_buffer: [64]u8 = undefined;
            const key_id_key = std.fmt.bufPrint(&key_buffer, "zigeffect.lineage.{d}.key_id", .{exported_index}) catch unreachable;
            try appendU64Attribute(allocator, &attributes, key_id_key, reference.key_id);
            const high_key = std.fmt.bufPrint(&key_buffer, "zigeffect.lineage.{d}.value_id_high", .{exported_index}) catch unreachable;
            try appendU64Attribute(allocator, &attributes, high_key, reference.value_id_high);
            const low_key = std.fmt.bufPrint(&key_buffer, "zigeffect.lineage.{d}.value_id_low", .{exported_index}) catch unreachable;
            try appendU64Attribute(allocator, &attributes, low_key, reference.value_id_low);
            const privacy_key = std.fmt.bufPrint(&key_buffer, "zigeffect.lineage.{d}.privacy", .{exported_index}) catch unreachable;
            try appendStringAttribute(allocator, &attributes, privacy_key, @tagName(reference.privacy));
            const propagation_key = std.fmt.bufPrint(&key_buffer, "zigeffect.lineage.{d}.propagation", .{exported_index}) catch unreachable;
            try appendStringAttribute(allocator, &attributes, propagation_key, @tagName(reference.propagation));
            exported_index += 1;
        }
    }
    try appendU64Attribute(allocator, &attributes, "zigeffect.causal.link_count", event.activeLinks().len);
    for (event.activeLinks(), 0..) |link, index| {
        const kind_key = try std.fmt.allocPrint(allocator, "zigeffect.causal.link.{d}.kind", .{index});
        defer allocator.free(kind_key);
        try appendStringAttribute(allocator, &attributes, kind_key, @tagName(link.kind));
        const event_key = try std.fmt.allocPrint(allocator, "zigeffect.causal.link.{d}.event_id", .{index});
        defer allocator.free(event_key);
        try appendU64Attribute(allocator, &attributes, event_key, link.event_id);
    }
    try appendOptionalStringAttribute(allocator, &attributes, "zigeffect.causal.label", event.label);
    try appendOptionalStringAttribute(allocator, &attributes, "zigeffect.causal.type_name", event.type_name);
    try appendOptionalStringAttribute(allocator, &attributes, "zigeffect.causal.status", event.status);
    try appendOptionalStringAttribute(allocator, &attributes, "zigeffect.causal.redacted_detail", event.redacted_detail);

    return .{
        .signal = signal,
        .name = name,
        .trace_id = event.trace_id orelse event.context.trace_id_low,
        .span_id = event.span_id orelse event.context.span_id,
        .trace_id_hex = if (event.context.trace_id_low) |low|
            formatCausalOtelTraceId128(event.context.trace_id_high orelse 0, low)
        else if (event.trace_id) |trace_id|
            formatCausalOtelTraceId(trace_id)
        else
            null,
        .span_id_hex = if (event.context.span_id orelse event.span_id) |span_id| formatCausalOtelSpanId(span_id) else null,
        .attributes = try attributes.toOwnedSlice(allocator),
    };
}

fn recordOtelBackend(raw: ?*anyopaque, event: causal.CausalEvent) anyerror!void {
    const state: *CausalOtelBackendState = @ptrCast(@alignCast(raw.?));
    if (state.max_records) |max_records| {
        if (state.records.items.len >= max_records) {
            state.failed_record_count += 1;
            return error.CausalOtelBackendFull;
        }
    }

    var record = mapCausalEventToOtelRecord(state.allocator, event) catch |err| {
        state.failed_record_count += 1;
        return err;
    };
    errdefer record.deinit(state.allocator);

    state.records.append(state.allocator, record) catch |err| {
        state.failed_record_count += 1;
        return err;
    };
    state.written_record_count += 1;
}
