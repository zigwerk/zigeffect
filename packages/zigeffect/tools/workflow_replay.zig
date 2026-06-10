const std = @import("std");
const fx = @import("zigeffect");
const support = @import("workflow_tool_support");

pub fn runReplay(
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
        .text => fx.workflow.formatReplayReportText(allocator, &report),
        .json => fx.workflow.formatReplayReportJson(allocator, &report),
    };
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const report = try runReplay(init.gpa, init.io, args[1..]);
    defer init.gpa.free(report);
    std.debug.print("{s}", .{report});
}

test "workflow replay tool module loads" {
    try std.testing.expectEqualStrings("zigeffect.workflow.replay.v1", fx.workflow.workflow_replay_schema);
}

test "workflow replay formats fixture text and json output" {
    const text_args = [_][]const u8{ "--fixture", "test/fixtures/workflow-journal.jsonl" };
    const text = try runReplay(std.testing.allocator, std.testing.io, &text_args);
    defer std.testing.allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect workflow replay\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "status: running\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "pending_timers: 1\n") != null);

    const json_args = [_][]const u8{ "--fixture", "test/fixtures/workflow-journal.jsonl", "--format", "json" };
    const json = try runReplay(std.testing.allocator, std.testing.io, &json_args);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.workflow.replay.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"pending_timers\":1") != null);
}
