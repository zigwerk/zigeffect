const std = @import("std");
const forgery = @import("forgery.zig");

// Forbidden: the accepted result shape plus an injected named-effect field.
const Forged = struct {
    root: std.Io.Dir,
    layer: forgery.EmptyLayer,
    ownership: forgery.Ownership,
    effect: usize,
};

test "a forged result injecting a named effect fails closed" {
    try forgery.reject(Forged);
}
