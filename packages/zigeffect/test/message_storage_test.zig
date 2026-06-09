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

test "in-memory message storage claims and acks unprocessed messages" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();
    const first_address = fx.entityAddress("counter", "one");
    const second_address = fx.entityAddress("counter", "two");

    var first = try storage.submit(.{
        .shard_id = 4,
        .now_ms = 1_000,
        .envelope = .{ .kind = .request, .address = first_address, .idempotency_key = "first", .payload = "inc" },
    });
    defer first.deinit(std.testing.allocator);
    var second = try storage.submit(.{
        .shard_id = 4,
        .now_ms = 1_001,
        .envelope = .{ .kind = .request, .address = second_address, .idempotency_key = "second", .payload = "inc" },
    });
    defer second.deinit(std.testing.allocator);
    var other_shard = try storage.submit(.{
        .shard_id = 5,
        .now_ms = 1_002,
        .envelope = .{ .kind = .request, .address = first_address, .idempotency_key = "third", .payload = "inc" },
    });
    defer other_shard.deinit(std.testing.allocator);

    const claimed = try storage.claim(.{ .shard_id = 4, .message_id = first.envelope.id, .now_ms = 1_010 });
    defer fx.deinitMessageEnvelope(std.testing.allocator, claimed);
    try std.testing.expectEqual(first.envelope.id, claimed.id);
    try std.testing.expectEqual(@as(fx.MessageAttempt, 1), claimed.attempt);

    var before_ack = try storage.unprocessedByShard(4, std.testing.allocator);
    defer before_ack.deinit();
    try std.testing.expectEqual(@as(usize, 2), before_ack.records.len);

    try storage.ack(.{ .message_id = first.envelope.id, .now_ms = 1_020 });
    var after_ack = try storage.unprocessedByShard(4, std.testing.allocator);
    defer after_ack.deinit();
    try std.testing.expectEqual(@as(usize, 1), after_ack.records.len);
    try std.testing.expect((try storage.unprocessedById(first.envelope.id, std.testing.allocator)) == null);
}

test "in-memory message storage persists replies and removes replied requests from unprocessed queries" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();
    const address = fx.entityAddress("counter", "one");

    try std.testing.expectError(error.MissingRequest, storage.storeReply(.{
        .shard_id = 4,
        .now_ms = 1_000,
        .envelope = .{ .kind = .reply, .address = address, .correlation_id = 999, .payload = "missing" },
    }));

    var request = try storage.submit(.{
        .shard_id = 4,
        .now_ms = 1_001,
        .envelope = .{ .kind = .request, .address = address, .idempotency_key = "reply", .payload = "get" },
    });
    defer request.deinit(std.testing.allocator);
    const correlation_id = request.envelope.correlation_id.?;

    const stored_reply = try storage.storeReply(.{
        .shard_id = 4,
        .now_ms = 1_010,
        .envelope = .{ .kind = .reply, .address = address, .correlation_id = correlation_id, .payload = "value=1" },
    });
    defer fx.deinitMessageEnvelope(std.testing.allocator, stored_reply);

    const found_reply = (try storage.reply(correlation_id, std.testing.allocator)).?;
    defer fx.deinitMessageEnvelope(std.testing.allocator, found_reply);
    try std.testing.expectEqual(correlation_id, found_reply.correlation_id.?);
    try std.testing.expectEqualStrings("value=1", found_reply.payload);

    try std.testing.expectError(error.DuplicateReply, storage.storeReply(.{
        .shard_id = 4,
        .now_ms = 1_011,
        .envelope = .{ .kind = .reply, .address = address, .correlation_id = correlation_id, .payload = "value=2" },
    }));
    try std.testing.expect((try storage.unprocessedById(request.envelope.id, std.testing.allocator)) == null);
}

test "stored message record json round-trips" {
    const address = fx.entityAddress("counter", "json");
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();
    var submitted = try storage.submit(.{
        .shard_id = 7,
        .now_ms = 2_000,
        .envelope = .{ .kind = .request, .address = address, .idempotency_key = "json", .payload = "inc" },
    });
    defer submitted.deinit(std.testing.allocator);
    var record = (try storage.unprocessedById(submitted.envelope.id, std.testing.allocator)).?;
    defer record.deinit(std.testing.allocator);

    const json = try fx.formatStoredMessageRecordJson(std.testing.allocator, record);
    defer std.testing.allocator.free(json);
    var parsed = try fx.parseStoredMessageRecordJson(std.testing.allocator, json);
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(record.shard_id, parsed.shard_id);
    try std.testing.expectEqual(record.envelope.id, parsed.envelope.id);
    try std.testing.expectEqualStrings(record.envelope.payload, parsed.envelope.payload);
}

test "file message storage replays unprocessed messages after reopen" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const address = fx.entityAddress("counter", "file");

    {
        var file_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer file_state.deinit();
        const storage = file_state.asMessageStorage();
        var submitted = try storage.submit(.{
            .shard_id = 7,
            .now_ms = 3_000,
            .envelope = .{ .kind = .request, .address = address, .idempotency_key = "file", .payload = "inc" },
        });
        defer submitted.deinit(std.testing.allocator);
    }

    var reopened_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer reopened_state.deinit();
    const reopened = reopened_state.asMessageStorage();
    var by_shard = try reopened.unprocessedByShard(7, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 1), by_shard.records.len);
    try std.testing.expectEqualStrings("inc", by_shard.records[0].envelope.payload);
}

test "file message storage detects duplicate submissions after reopen" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const address = fx.entityAddress("counter", "file-duplicate");

    {
        var file_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer file_state.deinit();
        const storage = file_state.asMessageStorage();
        var submitted = try storage.submit(.{
            .shard_id = 7,
            .now_ms = 3_000,
            .envelope = .{ .kind = .request, .address = address, .idempotency_key = "file-duplicate", .payload = "inc" },
        });
        defer submitted.deinit(std.testing.allocator);
    }

    var reopened_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer reopened_state.deinit();
    const reopened = reopened_state.asMessageStorage();
    var duplicate = try reopened.submit(.{
        .shard_id = 7,
        .now_ms = 3_100,
        .envelope = .{ .kind = .request, .address = address, .idempotency_key = "file-duplicate", .payload = "again" },
    });
    defer duplicate.deinit(std.testing.allocator);
    try std.testing.expect(duplicate.duplicate);
}
