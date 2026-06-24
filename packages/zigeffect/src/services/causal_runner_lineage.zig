const std = @import("std");
const causal = @import("causal.zig");

pub const Allocator = std.mem.Allocator;
pub const CausalEvent = causal.CausalEvent;

pub const CausalRunnerTrace = struct {
    runner_id: []const u8,
    events: []const CausalEvent,
};

pub const CausalRunnerLineageEdge = struct {
    from_runner_id: []const u8,
    to_runner_id: []const u8,
    from_event_id: u64,
    to_event_id: u64,
    edge_kind: []const u8,
};

pub const CausalRunnerLineage = struct {
    allocator: Allocator,
    events: []CausalEvent,
    cross_runner_edges: []CausalRunnerLineageEdge,

    pub fn deinit(self: *CausalRunnerLineage) void {
        for (self.events) |event| {
            deinitEventStrings(self.allocator, event);
        }
        self.allocator.free(self.events);
        for (self.cross_runner_edges) |edge| {
            if (edge.from_runner_id.len > 0) self.allocator.free(edge.from_runner_id);
            if (edge.to_runner_id.len > 0) self.allocator.free(edge.to_runner_id);
        }
        self.allocator.free(self.cross_runner_edges);
        self.* = .{
            .allocator = self.allocator,
            .events = &.{},
            .cross_runner_edges = &.{},
        };
    }
};

pub fn stitchCausalRunnerLineage(
    allocator: Allocator,
    traces: []const CausalRunnerTrace,
) Allocator.Error!CausalRunnerLineage {
    const event_count = countEvents(traces);
    var events = try allocator.alloc(CausalEvent, event_count);
    errdefer allocator.free(events);

    var initialized: usize = 0;
    errdefer {
        for (events[0..initialized]) |event| {
            deinitEventStrings(allocator, event);
        }
    }

    for (traces) |trace| {
        for (trace.events) |event| {
            events[initialized] = try cloneEvent(allocator, event);
            initialized += 1;
        }
    }

    var edges = std.ArrayList(CausalRunnerLineageEdge).empty;
    errdefer deinitEdges(allocator, &edges);

    for (traces, 0..) |trace, trace_index| {
        for (trace.events) |event| {
            const cause_event_id = event.cause_event_id orelse continue;
            const source = findRunnerForEvent(traces, cause_event_id) orelse continue;
            if (source.trace_index == trace_index) continue;
            try edges.append(allocator, .{
                .from_runner_id = try cloneSlice(allocator, source.runner_id),
                .to_runner_id = try cloneSlice(allocator, trace.runner_id),
                .from_event_id = cause_event_id,
                .to_event_id = event.id,
                .edge_kind = "cause_event_id",
            });
        }
    }

    return .{
        .allocator = allocator,
        .events = events,
        .cross_runner_edges = try edges.toOwnedSlice(allocator),
    };
}

fn countEvents(traces: []const CausalRunnerTrace) usize {
    var total: usize = 0;
    for (traces) |trace| {
        total += trace.events.len;
    }
    return total;
}

const RunnerLookup = struct {
    trace_index: usize,
    runner_id: []const u8,
};

fn findRunnerForEvent(traces: []const CausalRunnerTrace, event_id: u64) ?RunnerLookup {
    for (traces, 0..) |trace, trace_index| {
        for (trace.events) |event| {
            if (event.id == event_id) {
                return .{
                    .trace_index = trace_index,
                    .runner_id = trace.runner_id,
                };
            }
        }
    }
    return null;
}

fn cloneSlice(allocator: Allocator, value: []const u8) Allocator.Error![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

fn cloneEvent(allocator: Allocator, event: CausalEvent) Allocator.Error!CausalEvent {
    var owned = event;
    owned.label = try cloneSlice(allocator, event.label);
    errdefer if (owned.label.len > 0) allocator.free(owned.label);
    owned.type_name = try cloneSlice(allocator, event.type_name);
    errdefer if (owned.type_name.len > 0) allocator.free(owned.type_name);
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

fn deinitEventStrings(allocator: Allocator, event: CausalEvent) void {
    if (event.label.len > 0) allocator.free(event.label);
    if (event.type_name.len > 0) allocator.free(event.type_name);
    if (event.service_key.len > 0) allocator.free(event.service_key);
    if (event.artifact_id.len > 0) allocator.free(event.artifact_id);
    if (event.domain_entity_ref.len > 0) allocator.free(event.domain_entity_ref);
    if (event.data_subject_ref.len > 0) allocator.free(event.data_subject_ref);
    if (event.schema_ref.len > 0) allocator.free(event.schema_ref);
    if (event.status.len > 0) allocator.free(event.status);
    if (event.redacted_detail.len > 0) allocator.free(event.redacted_detail);
}

fn deinitEdges(allocator: Allocator, edges: *std.ArrayList(CausalRunnerLineageEdge)) void {
    for (edges.items) |edge| {
        if (edge.from_runner_id.len > 0) allocator.free(edge.from_runner_id);
        if (edge.to_runner_id.len > 0) allocator.free(edge.to_runner_id);
    }
    edges.deinit(allocator);
}
