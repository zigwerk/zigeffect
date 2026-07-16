const std = @import("std");
const causal_mod = @import("../services/causal.zig");
const topology_mod = @import("topology.zig");

pub const Allocator = std.mem.Allocator;
pub const application_snapshot_schema = "zigeffect.application_snapshot.v1";
pub const application_snapshot_schema_version: u32 = 1;

pub const ApplicationStatus = enum {
    ready,
};

pub const InspectOptions = struct {
    max_recent_events: usize = 128,
};

pub const ApplicationSnapshot = struct {
    allocator: Allocator,
    schema: []const u8 = application_snapshot_schema,
    schema_version: u32 = application_snapshot_schema_version,
    status: ApplicationStatus = .ready,
    root_layer_type: []const u8,
    layers: []topology_mod.LayerNode,
    services: []topology_mod.ServiceNode,
    edges: []topology_mod.DependencyEdge,
    causal: causal_mod.CausalInspection,

    pub fn capture(
        allocator: Allocator,
        topology: *const topology_mod.Topology,
        root_layer_type: []const u8,
        store: *causal_mod.CausalStore,
        options: InspectOptions,
    ) Allocator.Error!ApplicationSnapshot {
        var topology_snapshot = try topology.snapshot(allocator);
        errdefer topology_snapshot.deinit();
        const causal = try store.inspect(allocator, .{ .max_recent_events = options.max_recent_events });

        return .{
            .allocator = allocator,
            .root_layer_type = root_layer_type,
            .layers = topology_snapshot.layers,
            .services = topology_snapshot.services,
            .edges = topology_snapshot.edges,
            .causal = causal,
        };
    }

    pub fn deinit(self: *ApplicationSnapshot) void {
        self.allocator.free(self.layers);
        self.allocator.free(self.services);
        self.allocator.free(self.edges);
        self.causal.deinit();
        self.* = undefined;
    }

    pub fn jsonAlloc(self: *const ApplicationSnapshot, allocator: Allocator) Allocator.Error![]u8 {
        var output = std.ArrayList(u8).empty;
        errdefer output.deinit(allocator);

        try output.appendSlice(allocator, "{\"schema\":");
        try appendJsonString(&output, allocator, self.schema);
        try output.print(allocator, ",\"schema_version\":{d},\"status\":", .{self.schema_version});
        try appendJsonString(&output, allocator, @tagName(self.status));
        try output.appendSlice(allocator, ",\"root_layer_type\":");
        try appendJsonString(&output, allocator, self.root_layer_type);

        try output.appendSlice(allocator, ",\"services\":[");
        for (self.services, 0..) |service, index| {
            if (index != 0) try output.append(allocator, ',');
            try output.appendSlice(allocator, "{\"key\":");
            try appendJsonString(&output, allocator, service.key);
            try output.appendSlice(allocator, ",\"api_type\":");
            try appendJsonString(&output, allocator, service.api_type);
            try output.print(allocator, ",\"provider_layer_id\":{d},\"exposed\":{},\"operations\":[", .{ service.provider_layer_id, service.exposed });
            for (service.operations, 0..) |operation, operation_index| {
                if (operation_index != 0) try output.append(allocator, ',');
                try appendJsonString(&output, allocator, operation);
            }
            try output.appendSlice(allocator, "]}");
        }
        try output.appendSlice(allocator, "],\"layers\":[");
        for (self.layers, 0..) |layer, index| {
            if (index != 0) try output.append(allocator, ',');
            try output.print(allocator, "{{\"id\":{d},\"kind\":", .{layer.id});
            try appendJsonString(&output, allocator, @tagName(layer.kind));
            try output.appendSlice(allocator, ",\"status\":");
            try appendJsonString(&output, allocator, @tagName(layer.status));
            try output.appendSlice(allocator, ",\"name\":");
            try appendJsonString(&output, allocator, layer.name);
            try output.appendSlice(allocator, ",\"provided_service_key\":");
            try appendJsonString(&output, allocator, layer.provided_service_key);
            try output.appendSlice(allocator, ",\"provided_api_type\":");
            try appendJsonString(&output, allocator, layer.provided_api_type);
            try output.appendSlice(allocator, ",\"operations\":[");
            for (layer.operations, 0..) |operation, operation_index| {
                if (operation_index != 0) try output.append(allocator, ',');
                try appendJsonString(&output, allocator, operation);
            }
            try output.print(allocator, "],\"memoized_reuses\":{d}}}", .{layer.memoized_reuses});
        }
        try output.appendSlice(allocator, "],\"edges\":[");
        for (self.edges, 0..) |edge, index| {
            if (index != 0) try output.append(allocator, ',');
            try output.print(allocator, "{{\"provider_layer_id\":{d},\"consumer_layer_id\":{d},\"service_key\":", .{ edge.provider_layer_id, edge.consumer_layer_id });
            try appendJsonString(&output, allocator, edge.service_key);
            try output.append(allocator, '}');
        }

        try output.appendSlice(allocator, "],\"causal\":{");
        try output.print(
            allocator,
            "\"retained_events\":{d},\"dropped_events\":{d},\"sampled_events\":{d},\"truncated_fields\":{d},\"backend_failures\":{d},\"oldest_retained_event_id\":",
            .{
                self.causal.retained_events,
                self.causal.dropped_events,
                self.causal.sampled_events,
                self.causal.truncated_fields,
                self.causal.backend_failures,
            },
        );
        try appendOptionalU64(&output, allocator, self.causal.oldest_retained_event_id);
        try output.appendSlice(allocator, ",\"latest_retained_event_id\":");
        try appendOptionalU64(&output, allocator, self.causal.latest_retained_event_id);

        try output.appendSlice(allocator, ",\"findings\":[");
        for (self.causal.findings, 0..) |finding, index| {
            if (index != 0) try output.append(allocator, ',');
            try output.appendSlice(allocator, "{\"kind\":");
            try appendJsonString(&output, allocator, @tagName(finding.kind));
            try output.print(allocator, ",\"event_id\":{d},\"label\":", .{finding.event_id});
            try appendJsonString(&output, allocator, finding.label);
            try output.append(allocator, '}');
        }
        try output.appendSlice(allocator, "],\"fibers\":[");
        for (self.causal.fiber_states, 0..) |fiber, index| {
            if (index != 0) try output.append(allocator, ',');
            try output.print(
                allocator,
                "{{\"fiber_id\":{d},\"latest_event_id\":{d},\"latest_kind\":",
                .{ fiber.fiber_id, fiber.latest_event_id },
            );
            try appendJsonString(&output, allocator, @tagName(fiber.latest_kind));
            try output.print(allocator, ",\"resolved\":{},\"parked\":{}}}", .{ fiber.resolved, fiber.parked });
        }
        try output.appendSlice(allocator, "],\"recent_events\":[");
        for (self.causal.recent_events, 0..) |event, index| {
            if (index != 0) try output.append(allocator, ',');
            try output.print(allocator, "{{\"id\":{d},\"kind\":", .{event.id});
            try appendJsonString(&output, allocator, @tagName(event.kind));
            try output.appendSlice(allocator, ",\"run_id\":");
            try appendOptionalU64(&output, allocator, event.run_id);
            try output.appendSlice(allocator, ",\"parent_id\":");
            try appendOptionalU64(&output, allocator, event.parent_id);
            try output.appendSlice(allocator, ",\"fiber_id\":");
            try appendOptionalU64(&output, allocator, event.fiber_id);
            try output.appendSlice(allocator, ",\"scope_id\":");
            try appendOptionalU64(&output, allocator, event.scope_id);
            try output.appendSlice(allocator, ",\"layer_id\":");
            try appendOptionalU64(&output, allocator, event.layer_id);
            try output.appendSlice(allocator, ",\"resource_id\":");
            try appendOptionalU64(&output, allocator, event.resource_id);
            try output.appendSlice(allocator, ",\"cause_event_id\":");
            try appendOptionalU64(&output, allocator, event.cause_event_id);
            try output.appendSlice(allocator, ",\"schedule_id\":");
            try appendOptionalU64(&output, allocator, event.schedule_id);
            try output.appendSlice(allocator, ",\"boundary_id\":");
            try appendOptionalU64(&output, allocator, event.boundary_id);
            try output.appendSlice(allocator, ",\"service_key\":");
            try appendJsonString(&output, allocator, event.service_key);
            try output.appendSlice(allocator, ",\"artifact_id\":");
            try appendJsonString(&output, allocator, event.artifact_id);
            try output.appendSlice(allocator, ",\"domain_entity_ref\":");
            try appendJsonString(&output, allocator, event.domain_entity_ref);
            try output.appendSlice(allocator, ",\"data_subject_ref\":");
            try appendJsonString(&output, allocator, event.data_subject_ref);
            try output.appendSlice(allocator, ",\"schema_ref\":");
            try appendJsonString(&output, allocator, event.schema_ref);
            try output.appendSlice(allocator, ",\"trace_id\":");
            try appendOptionalU64(&output, allocator, event.trace_id);
            try output.appendSlice(allocator, ",\"span_id\":");
            try appendOptionalU64(&output, allocator, event.span_id);
            try output.appendSlice(allocator, ",\"label\":");
            try appendJsonString(&output, allocator, event.label);
            try output.appendSlice(allocator, ",\"type_name\":");
            try appendJsonString(&output, allocator, event.type_name);
            try output.appendSlice(allocator, ",\"status\":");
            try appendJsonString(&output, allocator, event.status);
            try output.appendSlice(allocator, ",\"redacted_detail\":");
            try appendJsonString(&output, allocator, event.redacted_detail);
            try output.append(allocator, '}');
        }
        try output.appendSlice(allocator, "]}}");
        return output.toOwnedSlice(allocator);
    }
};

fn appendJsonString(output: *std.ArrayList(u8), allocator: Allocator, value: []const u8) Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| switch (byte) {
        '"' => try output.appendSlice(allocator, "\\\""),
        '\\' => try output.appendSlice(allocator, "\\\\"),
        '\n' => try output.appendSlice(allocator, "\\n"),
        '\r' => try output.appendSlice(allocator, "\\r"),
        '\t' => try output.appendSlice(allocator, "\\t"),
        0x00...0x08, 0x0b, 0x0c, 0x0e...0x1f => try output.print(allocator, "\\u{x:0>4}", .{byte}),
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}

fn appendOptionalU64(output: *std.ArrayList(u8), allocator: Allocator, value: ?u64) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}
