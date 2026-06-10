const std = @import("std");
const fx = @import("zigeffect");

pub fn expectMessageStorageConformance(store: fx.MessageStorage) !void {
    const first_address = fx.entityAddress("storage-message", "one");
    const second_address = fx.entityAddress("storage-message", "two");

    var first = try store.submit(.{
        .shard_id = 9,
        .now_ms = 3_000,
        .envelope = .{
            .kind = .request,
            .address = first_address,
            .idempotency_key = "message-one",
            .payload_type_name = "text",
            .payload = "get",
        },
    });
    defer first.deinit(std.testing.allocator);

    var duplicate = try store.submit(.{
        .shard_id = 9,
        .now_ms = 3_001,
        .envelope = .{
            .kind = .request,
            .address = first_address,
            .idempotency_key = "message-one",
            .payload_type_name = "text",
            .payload = "again",
        },
    });
    defer duplicate.deinit(std.testing.allocator);
    try std.testing.expect(duplicate.duplicate);
    try std.testing.expectEqual(first.envelope.id, duplicate.envelope.id);

    var second = try store.submit(.{
        .shard_id = 9,
        .now_ms = 3_002,
        .envelope = .{ .kind = .request, .address = second_address, .idempotency_key = "message-two", .payload = "set" },
    });
    defer second.deinit(std.testing.allocator);

    var by_shard = try store.unprocessedByShard(9, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 2), by_shard.records.len);

    const claimed = try store.claim(.{ .shard_id = 9, .message_id = first.envelope.id, .now_ms = 3_010 });
    defer fx.deinitMessageEnvelope(std.testing.allocator, claimed);
    try std.testing.expectEqual(@as(fx.MessageAttempt, 1), claimed.attempt);

    const stored_reply = try store.storeReply(.{
        .shard_id = 9,
        .now_ms = 3_020,
        .envelope = .{ .kind = .reply, .address = first_address, .correlation_id = first.envelope.correlation_id.?, .payload = "value" },
    });
    defer fx.deinitMessageEnvelope(std.testing.allocator, stored_reply);

    const found_reply = (try store.reply(first.envelope.correlation_id.?, std.testing.allocator)).?;
    defer fx.deinitMessageEnvelope(std.testing.allocator, found_reply);
    try std.testing.expectEqualStrings("value", found_reply.payload);
    try std.testing.expectError(error.DuplicateReply, store.storeReply(.{
        .shard_id = 9,
        .now_ms = 3_021,
        .envelope = .{ .kind = .reply, .address = first_address, .correlation_id = first.envelope.correlation_id.?, .payload = "again" },
    }));

    try store.ack(.{ .message_id = second.envelope.id, .now_ms = 3_030 });
    try std.testing.expect((try store.unprocessedById(second.envelope.id, std.testing.allocator)) == null);

    store.reset();
    var after_reset = try store.unprocessedByShard(9, std.testing.allocator);
    defer after_reset.deinit();
    try std.testing.expectEqual(@as(usize, 0), after_reset.records.len);
}
