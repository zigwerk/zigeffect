const std = @import("std");
const fx = @import("zigeffect");

test "pattern namespace exposes structural matching entry points" {
    try std.testing.expect(@hasDecl(fx.pattern, "matches"));
    try std.testing.expect(@hasDecl(fx.pattern, "capture"));
    try std.testing.expect(@hasDecl(fx.pattern, "any"));
    try std.testing.expect(@hasDecl(fx.pattern, "bind"));
    try std.testing.expect(@hasDecl(fx.pattern, "range"));
}
