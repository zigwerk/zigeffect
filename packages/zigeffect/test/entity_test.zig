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

test "local mailbox store returns entity messages in fifo order" {
    var store = fx.LocalMailboxStore.init(std.testing.allocator);
    defer store.deinit();

    const counter = fx.entityAddress("counter", "one");
    const ledger = fx.entityAddress("ledger", "one");

    const first = try store.offer(.{ .kind = .tell, .address = counter, .payload_type_name = "text", .payload = "first" });
    defer fx.deinitEntityEnvelope(std.testing.allocator, first);
    const second = try store.offer(.{ .kind = .tell, .address = counter, .payload_type_name = "text", .payload = "second" });
    defer fx.deinitEntityEnvelope(std.testing.allocator, second);
    const other = try store.offer(.{ .kind = .tell, .address = ledger, .payload_type_name = "text", .payload = "ledger" });
    defer fx.deinitEntityEnvelope(std.testing.allocator, other);

    try std.testing.expectEqual(@as(usize, 2), store.pendingCount(counter));
    try std.testing.expectEqual(@as(usize, 1), store.pendingCount(ledger));

    const taken_first = try store.take(counter);
    defer fx.deinitEntityEnvelope(std.testing.allocator, taken_first);
    const taken_second = try store.take(counter);
    defer fx.deinitEntityEnvelope(std.testing.allocator, taken_second);
    const taken_other = try store.take(ledger);
    defer fx.deinitEntityEnvelope(std.testing.allocator, taken_other);

    try std.testing.expectEqualStrings("first", taken_first.payload);
    try std.testing.expectEqualStrings("second", taken_second.payload);
    try std.testing.expectEqualStrings("ledger", taken_other.payload);
    try std.testing.expect(taken_first.sequence < taken_second.sequence);
    try std.testing.expectError(error.MailboxEmpty, store.take(counter));
}

test "local mailbox store keeps ask correlations and replies" {
    var store = fx.LocalMailboxStore.init(std.testing.allocator);
    defer store.deinit();

    const address = fx.entityAddress("counter", "one");
    const ask = try store.offer(.{ .kind = .ask, .address = address, .payload_type_name = "text", .payload = "question" });
    defer fx.deinitEntityEnvelope(std.testing.allocator, ask);

    try std.testing.expect(ask.correlation_id != null);
    const reply = try store.storeReply(.{
        .kind = .reply,
        .address = address,
        .correlation_id = ask.correlation_id,
        .payload_type_name = "text",
        .payload = "answer",
    });
    defer fx.deinitEntityEnvelope(std.testing.allocator, reply);

    const taken_reply = try store.takeReply(ask.correlation_id.?);
    defer fx.deinitEntityEnvelope(std.testing.allocator, taken_reply);
    try std.testing.expectEqualStrings("answer", taken_reply.payload);
    try std.testing.expectError(error.ReplyNotFound, store.takeReply(ask.correlation_id.?));
}
