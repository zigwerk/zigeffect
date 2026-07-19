const std = @import("std");
const forgery = @import("forgery.zig");

// Forbidden: the accepted result shape plus an injected command-outcome field.
const Forged = struct {
    root: std.Io.Dir,
    layer: forgery.EmptyLayer,
    ownership: forgery.Ownership,
    outcome: anyerror!void,
};

test "a forged result injecting a command outcome fails closed" {
    try forgery.reject(Forged);
}
