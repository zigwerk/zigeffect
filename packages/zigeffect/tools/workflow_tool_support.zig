const std = @import("std");
const fx = @import("zigeffect");

pub const WorkflowToolInput = union(enum) {
    fixture: []const u8,
    journal_dir: []const u8,
};

pub const WorkflowToolArgs = struct {
    input: WorkflowToolInput,
    format: fx.workflow.WorkflowReportFormat = .text,
    selection: ?fx.workflow.WorkflowExecutionKey = null,
};

pub const WorkflowToolError = error{
    MissingWorkflowJournalInput,
    ConflictingWorkflowJournalInput,
    InvalidWorkflowReportFormat,
    InvalidWorkflowToolArgument,
    MissingWorkflowSelectionValue,
};

const max_fixture_bytes = 16 * 1024 * 1024;

pub fn parseArgs(_: std.mem.Allocator, args: []const []const u8) !WorkflowToolArgs {
    var input: ?WorkflowToolInput = null;
    var format: fx.workflow.WorkflowReportFormat = .text;
    var workflow_id: ?fx.workflow.WorkflowId = null;
    var execution_id: ?fx.workflow.ExecutionId = null;

    var index: usize = 0;
    while (index < args.len) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--fixture")) {
            const value = try nextArg(args, &index);
            if (input != null) return error.ConflictingWorkflowJournalInput;
            input = .{ .fixture = value };
        } else if (std.mem.eql(u8, arg, "--journal-dir")) {
            const value = try nextArg(args, &index);
            if (input != null) return error.ConflictingWorkflowJournalInput;
            input = .{ .journal_dir = value };
        } else if (std.mem.eql(u8, arg, "--format")) {
            format = parseFormat(try nextArg(args, &index)) orelse return error.InvalidWorkflowReportFormat;
        } else if (std.mem.eql(u8, arg, "--workflow-id")) {
            workflow_id = try std.fmt.parseInt(u64, try nextArg(args, &index), 10);
        } else if (std.mem.eql(u8, arg, "--execution-id")) {
            execution_id = try std.fmt.parseInt(u64, try nextArg(args, &index), 10);
        } else {
            return error.InvalidWorkflowToolArgument;
        }
        index += 1;
    }

    const selected = if (workflow_id == null and execution_id == null)
        null
    else if (workflow_id != null and execution_id != null)
        fx.workflow.WorkflowExecutionKey{
            .workflow_id = workflow_id.?,
            .execution_id = execution_id.?,
        }
    else
        return error.MissingWorkflowSelectionValue;

    return .{
        .input = input orelse return error.MissingWorkflowJournalInput,
        .format = format,
        .selection = selected,
    };
}

pub fn loadEvents(
    allocator: std.mem.Allocator,
    io: std.Io,
    input: WorkflowToolInput,
) !fx.workflow.JournalEventBatch {
    switch (input) {
        .fixture => |path| {
            var cwd = std.Io.Dir.cwd();
            return loadFixtureEvents(allocator, io, &cwd, path);
        },
        .journal_dir => |path| {
            var cwd = std.Io.Dir.cwd();
            var dir = try cwd.openDir(io, path, .{});
            defer dir.close(io);
            var file_store = try fx.workflow.FileJournalStore.open(allocator, io, &dir, .{});
            defer file_store.deinit();
            const journal = file_store.asJournalStore();
            return journal.readAll(allocator);
        },
    }
}

pub fn loadFixtureEvents(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: *std.Io.Dir,
    path: []const u8,
) !fx.workflow.JournalEventBatch {
    const content = try dir.readFileAlloc(io, path, allocator, .limited(max_fixture_bytes));
    defer allocator.free(content);

    var output = std.ArrayList(fx.workflow.WorkflowEvent).empty;
    errdefer {
        for (output.items) |event| fx.workflow.deinitWorkflowEventStrings(allocator, event);
        output.deinit(allocator);
    }

    var line_start: usize = 0;
    while (line_start <= content.len) {
        const newline_index = std.mem.indexOfScalarPos(u8, content, line_start, '\n') orelse content.len;
        const line = std.mem.trim(u8, content[line_start..newline_index], "\r");
        if (line.len != 0) {
            const event = try fx.workflow.parseWorkflowEventJson(allocator, line);
            errdefer fx.workflow.deinitWorkflowEventStrings(allocator, event);
            try output.append(allocator, event);
        }
        if (newline_index == content.len) break;
        line_start = newline_index + 1;
    }

    return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
}

fn nextArg(args: []const []const u8, index: *usize) WorkflowToolError![]const u8 {
    if (index.* + 1 >= args.len) return error.MissingWorkflowSelectionValue;
    index.* += 1;
    return args[index.*];
}

fn parseFormat(value: []const u8) ?fx.workflow.WorkflowReportFormat {
    if (std.mem.eql(u8, value, "text")) return .text;
    if (std.mem.eql(u8, value, "json")) return .json;
    return null;
}

test "workflow tool args parse fixture input and json format" {
    const args = [_][]const u8{
        "--fixture",
        "journal.jsonl",
        "--format",
        "json",
        "--workflow-id",
        "7",
        "--execution-id",
        "8",
    };

    const parsed = try parseArgs(std.testing.allocator, &args);
    try std.testing.expectEqual(fx.workflow.WorkflowReportFormat.json, parsed.format);
    try std.testing.expectEqual(@as(u64, 7), parsed.selection.?.workflow_id);
    try std.testing.expectEqual(@as(u64, 8), parsed.selection.?.execution_id);
    switch (parsed.input) {
        .fixture => |path| try std.testing.expectEqualStrings("journal.jsonl", path),
        else => return error.ExpectedFixtureInput,
    }
}

test "workflow tool args reject conflicting inputs" {
    const args = [_][]const u8{
        "--fixture",
        "journal.jsonl",
        "--journal-dir",
        ".zig-cache/workflows",
    };

    try std.testing.expectError(error.ConflictingWorkflowJournalInput, parseArgs(std.testing.allocator, &args));
}

test "workflow tool fixture loader parses json lines" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const first = try fx.workflow.formatWorkflowEventJson(std.testing.allocator, .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "fixture-workflow",
        .status = "running",
        .idempotency_key = "fixture-start",
    });
    defer std.testing.allocator.free(first);
    const second = try fx.workflow.formatWorkflowEventJson(std.testing.allocator, .{
        .sequence = 2,
        .kind = .workflow_completed,
        .workflow_id = 7,
        .execution_id = 8,
        .status = "completed",
        .idempotency_key = "fixture-completed",
    });
    defer std.testing.allocator.free(second);

    var file = try tmp.dir.createFile(std.testing.io, "journal.jsonl", .{ .read = true });
    defer file.close(std.testing.io);
    try file.writeStreamingAll(std.testing.io, first);
    try file.writeStreamingAll(std.testing.io, "\n");
    try file.writeStreamingAll(std.testing.io, second);
    try file.writeStreamingAll(std.testing.io, "\n");

    var events = try loadFixtureEvents(
        std.testing.allocator,
        std.testing.io,
        &tmp.dir,
        "journal.jsonl",
    );
    defer events.deinit();

    try std.testing.expectEqual(@as(usize, 2), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_started, events.events[0].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_completed, events.events[1].kind);
    try std.testing.expectEqualStrings("fixture-workflow", events.events[0].name);
}
