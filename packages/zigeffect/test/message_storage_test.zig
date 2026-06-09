const std = @import("std");
const fx = @import("zigeffect");

test "message storage public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "message_storage"));
    try std.testing.expect(@hasDecl(fx.cluster, "MessageStorage"));
    try std.testing.expect(@hasDecl(fx.cluster, "StoredMessageRecord"));
    try std.testing.expect(@hasDecl(fx.cluster, "MessageStorageSubmit"));
    try std.testing.expect(@hasDecl(fx.cluster, "InMemoryMessageStorage"));
    try std.testing.expect(@hasDecl(fx.cluster, "FileMessageStorage"));
    try std.testing.expect(@hasDecl(fx, "MessageStorage"));
}

test "in-memory message storage submits idempotently and lists unprocessed by shard" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();
    const address = fx.entityAddress("counter", "one");

    var first = try storage.submit(.{
        .shard_id = 3,
        .now_ms = 1_000,
        .envelope = .{
            .kind = .request,
            .address = address,
            .idempotency_key = "counter:one:1",
            .payload_type_name = "text",
            .payload = "inc",
        },
    });
    defer first.deinit(std.testing.allocator);
    var duplicate = try storage.submit(.{
        .shard_id = 3,
        .now_ms = 1_001,
        .envelope = .{
            .kind = .request,
            .address = address,
            .idempotency_key = "counter:one:1",
            .payload_type_name = "text",
            .payload = "inc-again",
        },
    });
    defer duplicate.deinit(std.testing.allocator);

    try std.testing.expect(!first.duplicate);
    try std.testing.expect(duplicate.duplicate);
    try std.testing.expectEqual(first.envelope.id, duplicate.envelope.id);

    var by_shard = try storage.unprocessedByShard(3, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 1), by_shard.records.len);
    try std.testing.expectEqual(first.envelope.id, by_shard.records[0].envelope.id);

    var by_id = (try storage.unprocessedById(first.envelope.id, std.testing.allocator)).?;
    defer by_id.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(fx.ShardId, 3), by_id.shard_id);
}
