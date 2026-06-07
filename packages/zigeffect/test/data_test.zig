const std = @import("std");
const fx = @import("zigeffect");

test "data namespace exposes core data type constructors" {
    try std.testing.expect(@hasDecl(fx.data, "Option"));
    try std.testing.expect(@hasDecl(fx.data, "Either"));
    try std.testing.expect(@hasDecl(fx.data, "Duration"));
    try std.testing.expect(@hasDecl(fx.data, "Redacted"));
    try std.testing.expect(@hasDecl(fx.data, "Chunk"));
    try std.testing.expect(@hasDecl(fx.data, "HashSet"));
    try std.testing.expect(@hasDecl(fx.data, "DateTime"));
    try std.testing.expect(@hasDecl(fx.data, "BigDecimal"));
}
