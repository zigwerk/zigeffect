const std = @import("std");
const forgery = @import("forgery.zig");

// Forbidden: the accepted result shape plus an injected private-identity field.
const Forged = struct {
    root: std.Io.Dir,
    layer: forgery.EmptyLayer,
    ownership: forgery.Ownership,
    identity: [16]u8,
};

test "a forged result injecting command identity fails closed" {
    try forgery.reject(Forged);
}
