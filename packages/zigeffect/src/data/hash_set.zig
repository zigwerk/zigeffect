const std = @import("std");

pub fn HashSet(comptime T: type) type {
    return struct {
        map: std.AutoHashMap(T, void),
    };
}
