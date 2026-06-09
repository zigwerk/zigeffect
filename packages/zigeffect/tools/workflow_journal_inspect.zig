const std = @import("std");
const fx = @import("zigeffect");
const support = @import("workflow_tool_support");

pub fn runInspect(
    allocator: std.mem.Allocator,
    io: std.Io,
    args: []const []const u8,
) ![]const u8 {
    const parsed = try support.parseArgs(allocator, args);
    var events = try support.loadEvents(allocator, io, parsed.input);
    defer events.deinit();

    var report = try fx.workflow.inspectExecution(allocator, events.events, parsed.selection);
    defer report.deinit();

    return switch (parsed.format) {
        .text => fx.workflow.formatInspectReportText(allocator, &report, events.events),
        .json => fx.workflow.formatInspectReportJson(allocator, &report, events.events),
    };
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const report = try runInspect(init.gpa, init.io, args[1..]);
    defer init.gpa.free(report);
    std.debug.print("{s}", .{report});
}

test "workflow journal inspect tool module loads" {
    try std.testing.expectEqualStrings("zigeffect.workflow.inspect.v1", fx.workflow.workflow_inspect_schema);
}

test "workflow journal inspect formats fixture text and json output" {
    const text_args = [_][]const u8{ "--fixture", "test/fixtures/workflow-journal.jsonl" };
    const text = try runInspect(std.testing.allocator, std.testing.io, &text_args);
    defer std.testing.allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect workflow journal inspect\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "7 step_failed failed exit.cause.failure:Boom\n") != null);

    const json_args = [_][]const u8{ "--fixture", "test/fixtures/workflow-journal.jsonl", "--format", "json" };
    const json = try runInspect(std.testing.allocator, std.testing.io, &json_args);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.workflow.inspect.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"kind\":\"step_failed\"") != null);
}
