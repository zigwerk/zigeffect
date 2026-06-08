const std = @import("std");
const fx = @import("zigeffect");

const JsonLineRow = struct {
    schema: []const u8,
    schema_version: u32,
    event_taxonomy_version: u32,
    id: u64,
    kind: []const u8,
    run_id: ?u64,
    parent_id: ?u64,
    fiber_id: ?u64,
    scope_id: ?u64,
    trace_id: ?u64,
    span_id: ?u64,
    label: []const u8,
    type_name: []const u8,
    status: []const u8,
    redacted_detail: []const u8,
};

fn expectSingleJsonLine(line: []const u8) ![]const u8 {
    try std.testing.expect(line.len > 1);
    try std.testing.expectEqual(@as(u8, '\n'), line[line.len - 1]);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, line, "\n"));
    return line[0 .. line.len - 1];
}

test "formatCausalJsonLine emits schema-tagged escaped row" {
    const line = try fx.formatCausalJsonLine(std.testing.allocator, .{
        .id = 42,
        .kind = .run_started,
        .run_id = 7,
        .parent_id = null,
        .fiber_id = 99,
        .scope_id = 11,
        .trace_id = 101,
        .span_id = 202,
        .label = "quote \" newline\n tab\t slash \\",
        .type_name = "JsonLineFormatter",
        .status = "success",
        .redacted_detail = "detail\rvalue",
    });
    defer std.testing.allocator.free(line);

    const row_json = try expectSingleJsonLine(line);
    var parsed = try std.json.parseFromSlice(JsonLineRow, std.testing.allocator, row_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try std.testing.expectEqualStrings(fx.causal_jsonl_event_schema, parsed.value.schema);
    try std.testing.expectEqual(fx.causal_jsonl_event_schema_version, parsed.value.schema_version);
    try std.testing.expectEqual(fx.causal_event_taxonomy_version, parsed.value.event_taxonomy_version);
    try std.testing.expectEqual(@as(u64, 42), parsed.value.id);
    try std.testing.expectEqualStrings("run_started", parsed.value.kind);
    try std.testing.expectEqual(@as(?u64, 7), parsed.value.run_id);
    try std.testing.expectEqual(@as(?u64, null), parsed.value.parent_id);
    try std.testing.expectEqual(@as(?u64, 99), parsed.value.fiber_id);
    try std.testing.expectEqual(@as(?u64, 11), parsed.value.scope_id);
    try std.testing.expectEqual(@as(?u64, 101), parsed.value.trace_id);
    try std.testing.expectEqual(@as(?u64, 202), parsed.value.span_id);
    try std.testing.expectEqualStrings("quote \" newline\n tab\t slash \\", parsed.value.label);
    try std.testing.expectEqualStrings("JsonLineFormatter", parsed.value.type_name);
    try std.testing.expectEqualStrings("success", parsed.value.status);
    try std.testing.expectEqualStrings("detail\rvalue", parsed.value.redacted_detail);
}
