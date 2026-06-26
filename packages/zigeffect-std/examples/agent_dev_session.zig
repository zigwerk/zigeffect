const std = @import("std");
const zstd = @import("zigeffect_std");

pub fn runAgentDevSession(allocator: std.mem.Allocator) ![]const u8 {
    var session = zstd.Agent.Session.init(allocator, "dev-session", "/repo");
    defer session.deinit();

    try session.recordAgentStatus(.{
        .agent_id = "codex-local",
        .agent_kind = .codex,
        .agent_label = "Codex",
        .status = .running,
        .task = "implement std cookbook token=abc123",
    });
    try session.recordCheck(.{
        .label = "std examples",
        .command = "bun run zigeffect:std:test",
        .status = .running,
        .detail = "starting",
    });
    try session.recordGuardrail("redact sentinel-secret-for-tests before workbench");
    try session.linkArtifact("cookbook", "packages/zigeffect-std/docs/cookbook.md");

    const runner = zstd.Process.FakeRunner.init(.{
        .exit_code = 0,
        .stdout = "ok token=abc123",
        .stderr = "",
    });
    var output = try runner.runOutputAlloc(allocator, .{
        .argv = &.{ "codex", "exec", "token=abc123" },
        .cwd = "/repo",
    });
    defer output.deinit(allocator);

    try appendProcessReceipt(&session, output.receipt);
    try session.recordCheck(.{
        .label = "std examples",
        .command = output.receipt.command,
        .status = .pass,
        .detail = output.stdout,
    });
    try session.recordAgentStatus(.{
        .agent_id = "codex-local",
        .agent_kind = .codex,
        .agent_label = "Codex",
        .status = .done,
        .task = "M13 cookbook",
    });

    return allocator.dupe(u8, session.feedText());
}

fn appendProcessReceipt(session: *zstd.Agent.Session, receipt: zstd.Process.Receipt) !void {
    const exit_code = try std.fmt.allocPrint(session.allocator, "{d}", .{receipt.exit_code});
    defer session.allocator.free(exit_code);

    const fields = [_]zstd.Json.Field{
        .{ .name = "sequence", .value = "5" },
        .{ .name = "kind", .value = "process_receipt" },
        .{ .name = "command", .value = receipt.command },
        .{ .name = "status", .value = receipt.status },
        .{ .name = "exit_code", .value = exit_code },
    };
    const json = try zstd.Json.objectFromFieldsAlloc(session.allocator, fields[0..]);
    defer session.allocator.free(json);

    try session.feed.appendSlice(session.allocator, json);
    try session.feed.append(session.allocator, '\n');
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const feed = try runAgentDevSession(allocator);
    defer allocator.free(feed);
    std.debug.print("{s}", .{feed});
}

test "agent dev session emits workbench-compatible redacted JSONL" {
    const feed = try runAgentDevSession(std.testing.allocator);
    defer std.testing.allocator.free(feed);

    try std.testing.expect(std.mem.indexOf(u8, feed, "\"kind\":\"agent_status\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, feed, "\"kind\":\"check_result\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, feed, "\"kind\":\"guardrail\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, feed, "\"kind\":\"artifact_link\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, feed, "\"kind\":\"process_receipt\"") != null);
    try std.testing.expect(std.mem.endsWith(u8, feed, "\n"));
    try std.testing.expect(std.mem.indexOf(u8, feed, "abc123") == null);
}
