const std = @import("std");
const causal = @import("causal.zig");

pub const Allocator = std.mem.Allocator;
pub const causal_jsonl_event_schema = "zigeffect.causal.event.v1";
pub const causal_jsonl_event_schema_version: u32 = 1;

fn appendJsonString(output: *std.ArrayList(u8), allocator: Allocator, value: []const u8) Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
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
