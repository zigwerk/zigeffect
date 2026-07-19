const std = @import("std");
const forgery = @import("forgery.zig");

// Forbidden: the accepted result shape plus an injected managed-runtime field.
const Forged = struct {
    root: std.Io.Dir,
    layer: forgery.EmptyLayer,
    ownership: forgery.Ownership,
    runtime: *anyopaque,
};

test "a forged result injecting a managed runtime fails closed" {
    try forgery.reject(Forged);
}
