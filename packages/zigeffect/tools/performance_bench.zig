const std = @import("std");
const fx = @import("zigeffect");

const OutputFormat = enum { text, json };

const ParsedArgs = struct {
    format: OutputFormat = .text,
    options: fx.PerformanceBenchmarkOptions = .{},
};

pub const PerformanceBenchError = error{
    UnknownFlag,
    MissingFlagValue,
    InvalidNumber,
};

pub fn runPerformanceBench(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
    const parsed = try parseArgs(args);
    var report = try fx.runPerformanceBenchmarks(allocator, parsed.options);
    defer report.deinit();
    return switch (parsed.format) {
        .text => fx.formatPerformanceBenchmarkText(allocator, report),
        .json => fx.formatPerformanceBenchmarkJson(allocator, report),
    };
}

fn parseArgs(args: []const []const u8) !ParsedArgs {
    var parsed = ParsedArgs{};
    var index: usize = 0;
    while (index < args.len) {
        const flag = args[index];
        if (std.mem.eql(u8, flag, "--json")) {
            parsed.format = .json;
        } else if (std.mem.eql(u8, flag, "--journal-events")) {
            index += 1;
            if (index >= args.len) return error.MissingFlagValue;
            parsed.options.journal_events = try parseUsize(args[index]);
        } else if (std.mem.eql(u8, flag, "--mailbox-messages")) {
            index += 1;
            if (index >= args.len) return error.MissingFlagValue;
            parsed.options.mailbox_messages = try parseUsize(args[index]);
        } else if (std.mem.eql(u8, flag, "--entity-count")) {
            index += 1;
            if (index >= args.len) return error.MissingFlagValue;
            parsed.options.entity_count = try parseUsize(args[index]);
        } else {
            return error.UnknownFlag;
        }
        index += 1;
    }
    return parsed;
}

fn parseUsize(value: []const u8) PerformanceBenchError!usize {
    return std.fmt.parseInt(usize, value, 10) catch error.InvalidNumber;
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const output = try runPerformanceBench(init.gpa, args[1..]);
    defer init.gpa.free(output);
    std.debug.print("{s}", .{output});
}

test "performance bench command formats text" {
    const args = [_][]const u8{ "--journal-events", "4", "--mailbox-messages", "6", "--entity-count", "2" };
    const output = try runPerformanceBench(std.testing.allocator, &args);
    defer std.testing.allocator.free(output);
    try std.testing.expect(std.mem.indexOf(u8, output, "schema: zigeffect.performance.benchmark.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "journal.events_appended: 4") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "mailbox.messages_offered: 6") != null);
}

test "performance bench command formats json" {
    const args = [_][]const u8{ "--json", "--journal-events", "4", "--mailbox-messages", "6" };
    const output = try runPerformanceBench(std.testing.allocator, &args);
    defer std.testing.allocator.free(output);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"schema\":\"zigeffect.performance.benchmark.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"events_appended\":4") != null);
}

test "performance bench command rejects invalid arguments" {
    const bad_number = [_][]const u8{ "--journal-events", "nope" };
    try std.testing.expectError(error.InvalidNumber, runPerformanceBench(std.testing.allocator, &bad_number));

    const missing_value = [_][]const u8{"--mailbox-messages"};
    try std.testing.expectError(error.MissingFlagValue, runPerformanceBench(std.testing.allocator, &missing_value));

    const unknown = [_][]const u8{"--wat"};
    try std.testing.expectError(error.UnknownFlag, runPerformanceBench(std.testing.allocator, &unknown));
}
