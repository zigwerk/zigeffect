const std = @import("std");

pub fn copy(comptime T: type, allocator: std.mem.Allocator, input: []const T) std.mem.Allocator.Error![]T {
    return allocator.dupe(T, input);
}
