const std = @import("std");

pub const CapturedConsole = struct {
    allocator: std.mem.Allocator,
    stdout: std.ArrayList(u8),
    stderr: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) CapturedConsole {
        return .{
            .allocator = allocator,
            .stdout = .empty,
            .stderr = .empty,
        };
    }

    pub fn deinit(self: *CapturedConsole) void {
        self.stdout.deinit(self.allocator);
        self.stderr.deinit(self.allocator);
    }

    pub fn writeOut(self: *CapturedConsole, text: []const u8) std.mem.Allocator.Error!void {
        try self.stdout.appendSlice(self.allocator, text);
    }

    pub fn writeErr(self: *CapturedConsole, text: []const u8) std.mem.Allocator.Error!void {
        try self.stderr.appendSlice(self.allocator, text);
    }

    pub fn stdoutText(self: CapturedConsole) []const u8 {
        return self.stdout.items;
    }

    pub fn stderrText(self: CapturedConsole) []const u8 {
        return self.stderr.items;
    }
};

test "Console captures stdout and stderr" {
    var console = CapturedConsole.init(std.testing.allocator);
    defer console.deinit();

    try console.writeOut("hello");
    try console.writeErr("oops");

    try std.testing.expectEqualStrings("hello", console.stdoutText());
    try std.testing.expectEqualStrings("oops", console.stderrText());
}
