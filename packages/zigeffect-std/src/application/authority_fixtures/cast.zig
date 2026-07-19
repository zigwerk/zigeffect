const std = @import("std");
const zstd = @import("zigeffect_std");
const forgery = @import("forgery.zig");

// Forbidden (cast-shaped attempt): return a pointer to the accepted result
// rather than the result value. A pointer is not the exact payload type, so the
// guard rejects it — a caller cannot smuggle authority behind a cast to the
// framework result.
const Forged = *zstd.Application.CommandResources(forgery.EmptyLayer);

test "a pointer/cast-shaped result fails closed" {
    try forgery.reject(Forged);
}
