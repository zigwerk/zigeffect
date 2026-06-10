const std = @import("std");
const fx = @import("zigeffect");
const support = @import("workflow_tool_support");

pub fn runList(
    allocator: std.mem.Allocator,
    io: std.Io,
    args: []const []const u8,
) ![]const u8 {
    const parsed = try support.parseArgs(allocator, args);
    var events = try support.loadEvents(allocator, io, parsed.input);
    defer events.deinit();

    var report = try fx.workflow.listExecutions(allocator, events.events);
    defer report.deinit();

    return switch (parsed.format) {
        .text => fx.workflow.formatListReportText(allocator, &report),
        .json => fx.workflow.formatListReportJson(allocator, &report),
    };
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const report = try runList(init.gpa, init.io, args[1..]);
    defer init.gpa.free(report);
    std.debug.print("{s}", .{report});
}

test "workflow list tool module loads" {
    try std.testing.expectEqualStrings("zigeffect.workflow.list.v1", fx.workflow.workflow_list_schema);
}

test "workflow list formats fixture text and json output" {
    const text_args = [_][]const u8{ "--fixture", "test/fixtures/workflow-journal.jsonl" };
    const text = try runList(std.testing.allocator, std.testing.io, &text_args);
    defer std.testing.allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect workflow list\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "- workflow_id: 7 execution_id: 8 status: running events: 7\n") != null);

    const json_args = [_][]const u8{ "--fixture", "test/fixtures/workflow-journal.jsonl", "--format", "json" };
    const json = try runList(std.testing.allocator, std.testing.io, &json_args);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.workflow.list.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"workflow_id\":7") != null);
}
