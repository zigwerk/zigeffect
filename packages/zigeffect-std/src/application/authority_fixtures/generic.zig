const std = @import("std");
const forgery = @import("forgery.zig");

// Forbidden (generic-shaped attempt): a structurally identical but distinct
// generic instantiation. Even a byte-for-byte matching layout is a different
// type than the framework's `CommandResources(LayerType)`, so exact type
// equality rejects it.
fn Generic(comptime Layer: type) type {
    return struct {
        root: std.Io.Dir,
        layer: Layer,
        ownership: forgery.Ownership,
    };
}

const Forged = Generic(forgery.EmptyLayer);

test "a generic look-alike result fails closed" {
    try forgery.reject(Forged);
}
