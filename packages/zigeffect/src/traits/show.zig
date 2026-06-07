const std = @import("std");

pub fn format(allocator: std.mem.Allocator, value: anytype) std.mem.Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "{any}", .{value});
}
