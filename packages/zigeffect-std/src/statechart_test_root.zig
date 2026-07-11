const std = @import("std");

pub const Statechart = @import("statechart/root.zig");

test {
    std.testing.refAllDecls(Statechart);
}
