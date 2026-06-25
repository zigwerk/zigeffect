const std = @import("std");
const Secrets = @import("../secrets/root.zig");

pub const EnvVar = struct {
    name: []const u8,
    value: []const u8,
    secret: bool = false,
};

pub const Command = struct {
    argv: []const []const u8,
    cwd: []const u8 = "",
    env: []const EnvVar = &.{},
};

pub const Result = struct {
    exit_code: i32,
    stdout: []const u8 = "",
    stderr: []const u8 = "",
};

pub const Receipt = struct {
    command: []const u8,
    status: []const u8,
    exit_code: i32,

    pub fn deinit(self: *Receipt, allocator: std.mem.Allocator) void {
        allocator.free(self.command);
    }
};

pub const FakeRunner = struct {
    result: Result,

    pub fn init(result: Result) FakeRunner {
        return .{ .result = result };
    }

    pub fn runAlloc(
        self: FakeRunner,
        allocator: std.mem.Allocator,
        command: Command,
    ) !Receipt {
        const command_text = try formatCommandAlloc(allocator, command);
        defer allocator.free(command_text);

        return .{
            .command = try Secrets.redactAlloc(allocator, command_text),
            .status = if (self.result.exit_code == 0) "success" else "failure",
            .exit_code = self.result.exit_code,
        };
    }
};

fn formatCommandAlloc(allocator: std.mem.Allocator, command: Command) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    for (command.argv, 0..) |arg, index| {
        if (index != 0) try output.append(allocator, ' ');
        try output.appendSlice(allocator, arg);
    }

    return output.toOwnedSlice(allocator);
}

test "Process fake runner returns redacted receipts" {
    const runner = FakeRunner.init(.{ .exit_code = 0, .stdout = "ok" });
    var receipt = try runner.runAlloc(std.testing.allocator, .{
        .argv = &.{ "echo", "token=abc123" },
        .cwd = "/repo",
    });
    defer receipt.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("[REDACTED]", receipt.command);
    try std.testing.expectEqualStrings("success", receipt.status);
    try std.testing.expectEqual(@as(i32, 0), receipt.exit_code);
}
