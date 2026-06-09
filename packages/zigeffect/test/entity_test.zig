const std = @import("std");
const fx = @import("zigeffect");

test "cluster entity public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "identity"));
    try std.testing.expect(@hasDecl(fx.cluster, "mailbox"));
    try std.testing.expect(@hasDecl(fx.cluster, "entity"));
    try std.testing.expect(@hasDecl(fx.cluster, "EntityType"));
    try std.testing.expect(@hasDecl(fx.cluster, "EntityId"));
    try std.testing.expect(@hasDecl(fx.cluster, "EntityAddress"));
    try std.testing.expect(@hasDecl(fx.cluster, "entityId"));
    try std.testing.expect(@hasDecl(fx.cluster, "entityAddress"));
    try std.testing.expect(@hasDecl(fx, "EntityAddress"));
}

test "entity ids are stable and entity-type sensitive" {
    const first = fx.entityId("counter", "tenant-1");
    const second = fx.entityId("counter", "tenant-1");
    const other_type = fx.entityId("ledger", "tenant-1");
    const other_key = fx.entityId("counter", "tenant-2");

    try std.testing.expectEqual(first, second);
    try std.testing.expect(first != other_type);
    try std.testing.expect(first != other_key);

    const address = fx.entityAddress("counter", "tenant-1");
    try std.testing.expectEqual(first, address.id);
    try std.testing.expectEqualStrings("counter", address.entity_type.name);
    try std.testing.expect(address.eql(fx.EntityAddress{
        .entity_type = fx.EntityType.init("counter"),
        .id = first,
    }));
}
