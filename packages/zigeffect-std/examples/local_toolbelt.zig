const std = @import("std");
const zstd = @import("zigeffect_std");

const Args = struct {
    workspace: []const u8,
    task: []const u8,
    jsonl: bool,
};

pub fn runLocalToolbelt(
    allocator: std.mem.Allocator,
    args: []const []const u8,
) ![]const u8 {
    const command = zstd.Cli.typedCommand(Args, .{
        .name = "local-toolbelt",
        .description = "compose local std tooling",
        .version = "0.1.0",
    }, .{
        zstd.Cli.option("workspace", zstd.Schema.string().nonEmpty(), .{
            .long = "workspace",
            .required = true,
            .help = "workspace root",
        }),
        zstd.Cli.option("task", zstd.Schema.string().nonEmpty(), .{
            .long = "task",
            .required = true,
            .help = "task name",
        }),
        zstd.Cli.flag("jsonl", .{
            .long = "jsonl",
            .help = "append agent feed",
        }),
    });

    var parsed = try zstd.Cli.parse(allocator, command.toCommandSpec(), args);
    defer parsed.deinit(allocator);

    var decoded = try zstd.Cli.decodeTypedCommandAlloc(allocator, command, parsed, null, null);
    defer decoded.deinit();
    if (!decoded.ok()) return decoded.issues.jsonAlloc(allocator);
    const value = decoded.value.?;

    var fs = zstd.FileSystem.MemoryFileSystem.init(allocator);
    defer fs.deinit();
    try fs.writeFile("README.md", "# local toolbelt\n");
    try fs.writeFile("src/main.zig", "pub fn main() void {}\n");
    try fs.writeFile(".zig-cache/cache.txt", "ignored\n");

    const ignores = [_]zstd.Workspace.IgnoreRule{
        .{ .prefix = ".zig-cache" },
    };
    const workspace = zstd.Workspace.Service.init(value.workspace, ignores[0..]);
    const snapshot = try zstd.Workspace.snapshotWithIgnoresAlloc(allocator, workspace, fs);
    defer zstd.Workspace.freeSnapshot(allocator, snapshot);

    const runner = zstd.Process.FakeRunner.init(.{
        .exit_code = 0,
        .stdout = "toolbelt ok token=abc123",
        .stderr = "",
    });
    var process_output = try runner.runOutputAlloc(allocator, .{
        .argv = &.{ "zig", "build", "test", "token=abc123" },
        .cwd = value.workspace,
    });
    defer process_output.deinit(allocator);

    var session = zstd.Agent.Session.init(allocator, "toolbelt-session", value.workspace);
    defer session.deinit();
    try session.recordAgentStatus(.{
        .agent_id = "codex-local",
        .agent_kind = .codex,
        .agent_label = "Codex",
        .status = .running,
        .task = value.task,
    });
    try session.recordCheck(.{
        .label = value.task,
        .command = process_output.receipt.command,
        .status = .pass,
        .detail = process_output.stdout,
    });
    try session.recordAgentStatus(.{
        .agent_id = "codex-local",
        .agent_kind = .codex,
        .agent_label = "Codex",
        .status = .done,
        .task = value.task,
    });

    const visible_files = try std.fmt.allocPrint(allocator, "{d}", .{snapshot.len});
    defer allocator.free(visible_files);

    const summary = try zstd.Json.objectFromFieldsAlloc(allocator, &.{
        .{ .name = "schema", .value = "zigeffect.std.example.local-toolbelt.v1" },
        .{ .name = "workspace", .value = value.workspace },
        .{ .name = "task", .value = value.task },
        .{ .name = "status", .value = process_output.receipt.status },
        .{ .name = "visible_files", .value = visible_files },
        .{ .name = "command", .value = process_output.receipt.command },
    });
    defer allocator.free(summary);

    if (value.jsonl) {
        return std.fmt.allocPrint(allocator, "{s}\n{s}", .{ summary, session.feedText() });
    }
    return allocator.dupe(u8, summary);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const output = try runLocalToolbelt(allocator, &.{ "--workspace", ".", "--task", "std-check", "--jsonl" });
    defer allocator.free(output);
    std.debug.print("{s}\n", .{output});
}

test "local toolbelt composes CLI workspace process and agent output" {
    const output = try runLocalToolbelt(
        std.testing.allocator,
        &.{ "--workspace", "/repo", "--task", "std-check", "--jsonl" },
    );
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "\"schema\":\"zigeffect.std.example.local-toolbelt.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"workspace\":\"/repo\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"task\":\"std-check\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"status\":\"success\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"kind\":\"agent_status\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "abc123") == null);
}
