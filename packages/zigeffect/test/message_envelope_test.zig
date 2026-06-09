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

test "message delivery tracker detects duplicate request idempotency" {
    var tracker = fx.MessageDeliveryTracker.init(std.testing.allocator);
    defer tracker.deinit();

    const address = fx.entityAddress("counter", "one");
    var first = try tracker.submit(.{
        .kind = .request,
        .address = address,
        .idempotency_key = "counter:one:1",
        .payload_type_name = "text",
        .payload = "inc",
    });
    defer first.deinit(std.testing.allocator);
    var duplicate = try tracker.submit(.{
        .kind = .request,
        .address = address,
        .idempotency_key = "counter:one:1",
        .payload_type_name = "text",
        .payload = "inc-again",
    });
    defer duplicate.deinit(std.testing.allocator);

    try std.testing.expect(!first.duplicate);
    try std.testing.expect(duplicate.duplicate);
    try std.testing.expectEqual(first.envelope.id, duplicate.envelope.id);
    try std.testing.expectEqual(@as(usize, 1), tracker.pendingCount(address));
}

test "message delivery tracker retries unacked claims at least once" {
    var tracker = fx.MessageDeliveryTracker.init(std.testing.allocator);
    defer tracker.deinit();

    const address = fx.entityAddress("counter", "one");
    var submitted = try tracker.submit(.{
        .kind = .request,
        .address = address,
        .idempotency_key = "counter:one:retry",
        .payload_type_name = "text",
        .payload = "inc",
    });
    defer submitted.deinit(std.testing.allocator);

    const first = try tracker.claimNext(address);
    defer fx.deinitMessageEnvelope(std.testing.allocator, first);
    const retry = try tracker.claimNext(address);
    defer fx.deinitMessageEnvelope(std.testing.allocator, retry);

    try std.testing.expectEqual(submitted.envelope.id, first.id);
    try std.testing.expectEqual(first.id, retry.id);
    try std.testing.expectEqual(@as(u32, 1), first.attempt);
    try std.testing.expectEqual(@as(u32, 2), retry.attempt);

    try tracker.ack(first.id);
    try std.testing.expectEqual(@as(usize, 0), tracker.pendingCount(address));
    try std.testing.expectError(error.MessageNotFound, tracker.claimNext(address));
}

test "message delivery tracker validates missing and duplicate replies" {
    var tracker = fx.MessageDeliveryTracker.init(std.testing.allocator);
    defer tracker.deinit();

    const address = fx.entityAddress("counter", "one");
    try std.testing.expectError(error.MissingRequest, tracker.storeReply(.{
        .kind = .reply,
        .address = address,
        .correlation_id = 999,
        .payload_type_name = "text",
        .payload = "missing",
    }));

    var submitted = try tracker.submit(.{
        .kind = .request,
        .address = address,
        .idempotency_key = "counter:one:reply",
        .payload_type_name = "text",
        .payload = "get",
    });
    defer submitted.deinit(std.testing.allocator);

    const correlation_id = submitted.envelope.correlation_id.?;
    const reply = try tracker.storeReply(.{
        .kind = .reply,
        .address = address,
        .correlation_id = correlation_id,
        .payload_type_name = "text",
        .payload = "value=1",
    });
    defer fx.deinitMessageEnvelope(std.testing.allocator, reply);

    try std.testing.expectError(error.DuplicateReply, tracker.storeReply(.{
        .kind = .reply,
        .address = address,
        .correlation_id = correlation_id,
        .payload_type_name = "text",
        .payload = "value=2",
    }));
}

test "message diagnostics redact raw payload" {
    const address = fx.entityAddress("counter", "one");
    const report = try fx.formatMessageDiagnostic(std.testing.allocator, .{
        .id = 123,
        .kind = .chunk_reply,
        .address = address,
        .correlation_id = 99,
        .attempt = 2,
        .chunk_index = 1,
        .chunk_count = 3,
        .payload_type_name = "secret-text",
        .payload = "raw-secret-token",
        .redacted_detail = "token=<redacted>",
    });
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "token=<redacted>") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "chunk: 1/3") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "raw-secret-token") == null);
}
