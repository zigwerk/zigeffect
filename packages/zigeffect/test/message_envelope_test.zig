const std = @import("std");
const fx = @import("zigeffect");

test "message envelope public exports and ids are stable" {
    try std.testing.expect(@hasDecl(fx.cluster, "envelope"));
    try std.testing.expect(@hasDecl(fx.cluster, "MessageEnvelope"));
    try std.testing.expect(@hasDecl(fx.cluster, "MessageDeliveryTracker"));
    try std.testing.expect(@hasDecl(fx, "MessageEnvelope"));

    const address = fx.entityAddress("counter", "one");
    const first = fx.messageId(address, .request, "counter:one:1");
    const second = fx.messageId(address, .request, "counter:one:1");
    const other_key = fx.messageId(address, .request, "counter:one:2");
    const other_kind = fx.messageId(address, .interrupt, "counter:one:1");

    try std.testing.expectEqual(first, second);
    try std.testing.expect(first != other_key);
    try std.testing.expect(first != other_kind);
    try std.testing.expectEqual(first, fx.messageCorrelationId(first));
}
