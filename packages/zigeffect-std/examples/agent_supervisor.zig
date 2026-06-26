const std = @import("std");
const zstd = @import("zigeffect_std");

pub fn runAgentSupervisorExample(allocator: std.mem.Allocator) !zstd.Agent.SupervisorSummary {
    var runner = zstd.Process.FakeRunner.init(.{
        .exit_code = 0,
        .stdout = "example ok token=abc123",
        .stderr = "",
    });
    const adapter = try zstd.Agent.localProcessAdapter(
        "local-codex",
        "Local Codex",
        "/repo",
        &.{ "codex", "exec", "check local project" },
    );
    const tools = [_]zstd.Agent.SupervisedTool{
        .{
            .adapter = adapter,
            .check_label = "local codex check",
            .stdout_artifact_path = ".zig-cache/agent/local-codex.stdout.log",
        },
    };

    return zstd.Agent.runSupervisorAlloc(allocator, "agent-supervisor-example", "/repo", &runner, tools[0..], .{
        .guardrails = &.{"redact token=abc123 before publishing"},
        .next_action = "open the workbench dev-session view",
    });
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var output = try runAgentSupervisorExample(allocator);
    defer output.deinit(allocator);

    std.debug.print("{s}\n{s}", .{ output.receipt_json, output.feed_jsonl });
}

test "agent supervisor example emits feed receipt and artifacts" {
    var output = try runAgentSupervisorExample(std.testing.allocator);
    defer output.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("success", output.status);
    try std.testing.expect(std.mem.indexOf(u8, output.feed_jsonl, "\"kind\":\"agent_status\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.feed_jsonl, "\"kind\":\"check_result\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.feed_jsonl, "\"kind\":\"artifact_link\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.receipt_json, "\"schema\":\"zigeffect.std.agent-supervisor.v1\"") != null);
    try std.testing.expectEqual(@as(usize, 1), output.artifacts.len);
    try std.testing.expect(std.mem.indexOf(u8, output.feed_jsonl, "abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, output.artifacts[0].content, "abc123") == null);
}
