const std = @import("std");
const app = @import("app");

test "production profile compiles real adapter and lifecycle wiring" {
    try std.testing.expect(app.productionContract());
}

test "API exposes one canonical application composition" {
    try std.testing.expect(@hasDecl(app, "rootLayer"));
    try std.testing.expect(@hasDecl(app, "program"));
    try std.testing.expect(@hasDecl(app, "run"));
}
