const std = @import("std");
const fx = @import("zigeffect");

test "traits namespace exposes equality hash and ordering contracts" {
    try std.testing.expect(@hasDecl(fx.traits, "equals"));
    try std.testing.expect(@hasDecl(fx.traits, "hash"));
    try std.testing.expect(@hasDecl(fx.traits, "compare"));
    try std.testing.expect(@hasDecl(fx.traits, "Ordering"));
}
