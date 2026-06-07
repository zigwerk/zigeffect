const std = @import("std");

pub fn Chunk(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        items: []T,
    };
}
