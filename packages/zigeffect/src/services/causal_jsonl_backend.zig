const std = @import("std");
const causal = @import("causal.zig");
const causal_backend = @import("causal_backend.zig");

pub const Allocator = std.mem.Allocator;
pub const causal_jsonl_event_schema = "zigeffect.causal.event.v1";
pub const causal_jsonl_event_schema_version: u32 = 1;

pub const CausalJsonLinesBackendOptions = struct {
    max_bytes: ?usize = null,
};

pub const CausalJsonLinesBackendError = error{
    CausalJsonLinesBackendFull,
};

pub const CausalJsonLinesBackendState = struct {
    allocator: Allocator,
    output: *std.ArrayList(u8),
    max_bytes: ?usize = null,
    written_event_count: u64 = 0,
    failed_event_count: u64 = 0,

    pub fn init(
        allocator: Allocator,
        output: *std.ArrayList(u8),
        options: CausalJsonLinesBackendOptions,
    ) CausalJsonLinesBackendState {
        return .{
            .allocator = allocator,
            .output = output,
            .max_bytes = options.max_bytes,
        };
    }

    pub fn backend(self: *CausalJsonLinesBackendState) causal_backend.CausalBackend {
        return .{
            .kind = .json_lines,
            .state = self,
            .record = recordJsonLinesBackend,
        };
    }

    pub fn writtenEventCount(self: *const CausalJsonLinesBackendState) u64 {
        return self.written_event_count;
    }

    pub fn failedEventCount(self: *const CausalJsonLinesBackendState) u64 {
        return self.failed_event_count;
    }
};

fn recordJsonLinesBackend(raw: ?*anyopaque, event: causal.CausalEvent) anyerror!void {
    const state: *CausalJsonLinesBackendState = @ptrCast(@alignCast(raw.?));
    const row = formatCausalJsonLine(state.allocator, event) catch |err| {
        state.failed_event_count += 1;
        return err;
    };
    defer state.allocator.free(row);

    if (state.max_bytes) |max_bytes| {
        if (state.output.items.len > max_bytes or row.len > max_bytes - state.output.items.len) {
            state.failed_event_count += 1;
            return error.CausalJsonLinesBackendFull;
        }
    }

    state.output.appendSlice(state.allocator, row) catch |err| {
        state.failed_event_count += 1;
        return err;
    };
    state.written_event_count += 1;
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

pub fn formatCausalJsonLine(allocator: Allocator, event: causal.CausalEvent) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, causal_jsonl_event_schema);
    try output.print(
        allocator,
        ",\"schema_version\":{d},\"event_taxonomy_version\":{d},\"id\":{d},\"kind\":",
        .{ causal_jsonl_event_schema_version, causal.causal_event_taxonomy_version, event.id },
    );
    try appendJsonString(&output, allocator, @tagName(event.kind));
    try output.appendSlice(allocator, ",\"run_id\":");
    try appendOptionalJsonU64(&output, allocator, event.run_id);
    try output.appendSlice(allocator, ",\"parent_id\":");
    try appendOptionalJsonU64(&output, allocator, event.parent_id);
    try output.appendSlice(allocator, ",\"fiber_id\":");
    try appendOptionalJsonU64(&output, allocator, event.fiber_id);
    try output.appendSlice(allocator, ",\"scope_id\":");
    try appendOptionalJsonU64(&output, allocator, event.scope_id);
    try output.appendSlice(allocator, ",\"layer_id\":");
    try appendOptionalJsonU64(&output, allocator, event.layer_id);
    try output.appendSlice(allocator, ",\"layer_name\":");
    try appendJsonString(&output, allocator, event.layer_name);
    try output.appendSlice(allocator, ",\"service_key\":");
    try appendJsonString(&output, allocator, event.service_key);
    try output.appendSlice(allocator, ",\"resource_id\":");
    try appendOptionalJsonU64(&output, allocator, event.resource_id);
    try output.appendSlice(allocator, ",\"cause_event_id\":");
    try appendOptionalJsonU64(&output, allocator, event.cause_event_id);
    try output.appendSlice(allocator, ",\"schedule_id\":");
    try appendOptionalJsonU64(&output, allocator, event.schedule_id);
    try output.appendSlice(allocator, ",\"source_ref_id\":");
    try appendOptionalJsonU64(&output, allocator, event.source_ref_id);
    try output.appendSlice(allocator, ",\"boundary_id\":");
    try appendOptionalJsonU64(&output, allocator, event.boundary_id);
    try output.appendSlice(allocator, ",\"artifact_id\":");
    try appendJsonString(&output, allocator, event.artifact_id);
    try output.appendSlice(allocator, ",\"domain_entity_ref\":");
    try appendJsonString(&output, allocator, event.domain_entity_ref);
    try output.appendSlice(allocator, ",\"data_subject_ref\":");
    try appendJsonString(&output, allocator, event.data_subject_ref);
    try output.appendSlice(allocator, ",\"schema_ref\":");
    try appendJsonString(&output, allocator, event.schema_ref);
    try output.appendSlice(allocator, ",\"trace_id\":");
    try appendOptionalJsonU64(&output, allocator, event.trace_id);
    try output.appendSlice(allocator, ",\"span_id\":");
    try appendOptionalJsonU64(&output, allocator, event.span_id);
    try output.appendSlice(allocator, ",\"label\":");
    try appendJsonString(&output, allocator, event.label);
    try output.appendSlice(allocator, ",\"type_name\":");
    try appendJsonString(&output, allocator, event.type_name);
    try output.appendSlice(allocator, ",\"status\":");
    try appendJsonString(&output, allocator, event.status);
    try output.appendSlice(allocator, ",\"redacted_detail\":");
    try appendJsonString(&output, allocator, event.redacted_detail);
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}
