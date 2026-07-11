const std = @import("std");
const app = @import("app");

test "production profile compiles real adapter and lifecycle wiring" {
    try std.testing.expect(app.productionContract());
}