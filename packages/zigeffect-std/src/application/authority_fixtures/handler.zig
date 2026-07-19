const std = @import("std");
const forgery = @import("forgery.zig");

// Forbidden: the accepted result shape plus an injected handler field.
const Forged = struct {
    root: std.Io.Dir,
    layer: forgery.EmptyLayer,
    ownership: forgery.Ownership,
    handler: *const fn () void,
};

test "a forged result injecting a handler fails closed" {
    try forgery.reject(Forged);
}
