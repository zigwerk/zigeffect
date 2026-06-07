const std = @import("std");
const fx = @import("zigeffect");

test "match namespace exposes tagged union matcher entry points" {
    try std.testing.expect(@hasDecl(fx.match, "exhaustive"));
    try std.testing.expect(@hasDecl(fx.match, "partial"));
    try std.testing.expect(@hasDecl(fx.match, "orElse"));
    try std.testing.expect(@hasDecl(fx.match, "option"));
    try std.testing.expect(@hasDecl(fx.match, "either"));
}
