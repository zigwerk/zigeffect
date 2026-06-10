const std = @import("std");
const fx = @import("zigeffect");

test "cluster transport public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "transport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportKind"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportPolicy"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportRequest"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportResponse"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportError"));
    try std.testing.expect(@hasDecl(fx.cluster, "InProcessClusterTransport"));
    try std.testing.expect(@hasDecl(fx.cluster, "LoopbackHttpClusterTransport"));
    try std.testing.expect(@hasDecl(fx, "ClusterTransport"));
}

test "transport request json round-trips" {
    const request = fx.ClusterTransportRequest{
        .kind = .request,
        .address = fx.entityAddress("counter", "transport-request"),
        .payload_type_name = "text",
        .payload = "get",
        .redacted_detail = "read current value",
        .idempotency_key = "transport-request-key",
        .policy = .{ .timeout_ms = 250, .max_retries = 2 },
    };

    const json = try fx.formatClusterTransportRequestJson(std.testing.allocator, request);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, fx.transport_request_schema) != null);

    var parsed = try fx.parseClusterTransportRequestJson(std.testing.allocator, json);
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(fx.MessageEnvelopeKind.request, parsed.kind);
    try std.testing.expect(parsed.address.eql(request.address));
    try std.testing.expectEqualStrings("text", parsed.payload_type_name);
    try std.testing.expectEqualStrings("get", parsed.payload);
    try std.testing.expectEqualStrings("read current value", parsed.redacted_detail);
    try std.testing.expectEqualStrings("transport-request-key", parsed.idempotency_key.?);
    try std.testing.expectEqual(@as(u64, 250), parsed.policy.timeout_ms);
    try std.testing.expectEqual(@as(usize, 2), parsed.policy.max_retries);
}

test "transport response json round-trips" {
    const address = fx.entityAddress("counter", "transport-response");
    const response = fx.ClusterTransportResponse{
        .shard_id = 7,
        .envelope = .{
            .id = 42,
            .kind = .request,
            .address = address,
            .correlation_id = 99,
            .idempotency_key = "transport-response-key",
            .payload_type_name = "text",
            .payload = "get",
            .redacted_detail = "read current value",
        },
        .correlation_id = 99,
        .duplicate = true,
        .attempts = 3,
        .transport = .loopback_http,
    };

    const json = try fx.formatClusterTransportResponseJson(std.testing.allocator, response);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, fx.transport_response_schema) != null);

    var parsed = try fx.parseClusterTransportResponseJson(std.testing.allocator, json);
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(fx.ShardId, 7), parsed.shard_id);
    try std.testing.expectEqual(@as(fx.MessageId, 42), parsed.envelope.id);
    try std.testing.expectEqual(fx.MessageEnvelopeKind.request, parsed.envelope.kind);
    try std.testing.expect(parsed.envelope.address.eql(address));
    try std.testing.expectEqual(@as(?fx.MessageCorrelationId, 99), parsed.correlation_id);
    try std.testing.expectEqualStrings("transport-response-key", parsed.envelope.idempotency_key);
    try std.testing.expectEqualStrings("text", parsed.envelope.payload_type_name);
    try std.testing.expectEqualStrings("get", parsed.envelope.payload);
    try std.testing.expectEqualStrings("read current value", parsed.envelope.redacted_detail);
    try std.testing.expect(parsed.duplicate);
    try std.testing.expectEqual(@as(usize, 3), parsed.attempts);
    try std.testing.expectEqual(fx.ClusterTransportKind.loopback_http, parsed.transport);
}

test "transport parser rejects incompatible schemas" {
    const bad_request =
        \\{"schema":"other.schema","schema_version":1,"kind":"tell","entity_type":"counter","entity_id":1,"payload_type_name":"text","payload":"x","redacted_detail":"x","idempotency_key":null,"timeout_ms":1,"max_retries":0}
    ;
    try std.testing.expectError(error.IncompatibleTransportSchema, fx.parseClusterTransportRequestJson(std.testing.allocator, bad_request));

    const bad_response =
        \\{"schema":"other.schema","schema_version":1,"shard_id":0,"kind":"tell","message_id":1,"correlation_id":null,"entity_type":"counter","entity_id":1,"idempotency_key":"k","payload_type_name":"text","payload":"x","redacted_detail":"x","duplicate":false,"attempts":1,"transport":"in_process"}
    ;
    try std.testing.expectError(error.IncompatibleTransportSchema, fx.parseClusterTransportResponseJson(std.testing.allocator, bad_response));
}

test "in-process transport writes tell ask and interrupt messages" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();
    var transport_state = try fx.InProcessClusterTransport.init(std.testing.allocator, storage, .{ .shard_count = 16 });
    defer transport_state.deinit();
    const transport = transport_state.asClusterTransport();

    const address = fx.entityAddress("counter", "in-process-writes");
    const shard_id = try fx.shardIdForAddress(address, 16);

    var tell = try transport.send(std.testing.allocator, .{
        .kind = .tell,
        .address = address,
        .payload_type_name = "text",
        .payload = "inc",
        .redacted_detail = "increment",
    });
    defer tell.deinit(std.testing.allocator);

    var ask = try transport.send(std.testing.allocator, .{
        .kind = .request,
        .address = address,
        .payload_type_name = "text",
        .payload = "get",
        .redacted_detail = "read current value",
    });
    defer ask.deinit(std.testing.allocator);

    var interrupt = try transport.send(std.testing.allocator, .{
        .kind = .interrupt,
        .address = address,
        .payload_type_name = "interrupt",
        .payload = "cancel",
        .redacted_detail = "cancel",
    });
    defer interrupt.deinit(std.testing.allocator);

    try std.testing.expectEqual(shard_id, tell.shard_id);
    try std.testing.expectEqual(fx.ClusterTransportKind.in_process, tell.transport);
    try std.testing.expectEqual(@as(usize, 1), tell.attempts);
    try std.testing.expectEqual(fx.MessageEnvelopeKind.request, ask.envelope.kind);
    try std.testing.expect(ask.correlation_id != null);
    try std.testing.expectEqual(fx.MessageEnvelopeKind.interrupt, interrupt.envelope.kind);

    var by_shard = try storage.unprocessedByShard(shard_id, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 3), by_shard.records.len);
}

test "in-process transport preserves duplicate idempotency keys" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();
    var transport_state = try fx.InProcessClusterTransport.init(std.testing.allocator, storage, .{ .shard_count = 8 });
    defer transport_state.deinit();
    const transport = transport_state.asClusterTransport();

    const address = fx.entityAddress("counter", "in-process-duplicate");
    const shard_id = try fx.shardIdForAddress(address, 8);

    var first = try transport.send(std.testing.allocator, .{
        .kind = .request,
        .address = address,
        .payload_type_name = "text",
        .payload = "first",
        .redacted_detail = "first request",
        .idempotency_key = "same-key",
    });
    defer first.deinit(std.testing.allocator);

    var duplicate = try transport.send(std.testing.allocator, .{
        .kind = .request,
        .address = address,
        .payload_type_name = "text",
        .payload = "second",
        .redacted_detail = "second request",
        .idempotency_key = "same-key",
    });
    defer duplicate.deinit(std.testing.allocator);

    try std.testing.expect(!first.duplicate);
    try std.testing.expect(duplicate.duplicate);
    try std.testing.expectEqual(first.envelope.id, duplicate.envelope.id);
    try std.testing.expectEqualStrings("first", duplicate.envelope.payload);

    var by_shard = try storage.unprocessedByShard(shard_id, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 1), by_shard.records.len);
}

test "in-process timeout policy rejects before durable submission" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();
    var transport_state = try fx.InProcessClusterTransport.init(std.testing.allocator, storage, .{ .shard_count = 4 });
    defer transport_state.deinit();
    const transport = transport_state.asClusterTransport();

    const address = fx.entityAddress("counter", "in-process-timeout");
    const shard_id = try fx.shardIdForAddress(address, 4);

    try std.testing.expectError(error.TransportTimeout, transport.send(std.testing.allocator, .{
        .kind = .tell,
        .address = address,
        .payload_type_name = "text",
        .payload = "inc",
        .redacted_detail = "increment",
        .policy = .{ .timeout_ms = 0 },
    }));

    var by_shard = try storage.unprocessedByShard(shard_id, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 0), by_shard.records.len);
}

test "http codec extracts request and response bodies" {
    const address = fx.entityAddress("counter", "http-codec");
    const request = fx.ClusterTransportRequest{
        .kind = .tell,
        .address = address,
        .payload_type_name = "text",
        .payload = "inc",
        .redacted_detail = "increment",
        .idempotency_key = "http-codec-key",
    };
    const request_json = try fx.formatClusterTransportRequestJson(std.testing.allocator, request);
    defer std.testing.allocator.free(request_json);
    const http_request = try fx.formatClusterTransportHttpRequest(std.testing.allocator, request_json);
    defer std.testing.allocator.free(http_request);
    const request_body = try fx.clusterTransportHttpBody(http_request);
    try std.testing.expectEqualStrings(request_json, request_body);

    const response = fx.ClusterTransportResponse{
        .shard_id = 1,
        .envelope = .{
            .id = 123,
            .kind = .tell,
            .address = address,
            .idempotency_key = "http-codec-key",
            .payload_type_name = "text",
            .payload = "inc",
            .redacted_detail = "increment",
        },
        .attempts = 1,
        .transport = .loopback_http,
    };
    const response_json = try fx.formatClusterTransportResponseJson(std.testing.allocator, response);
    defer std.testing.allocator.free(response_json);
    const http_response = try fx.formatClusterTransportHttpResponse(std.testing.allocator, response_json);
    defer std.testing.allocator.free(http_response);
    const response_body = try fx.clusterTransportHttpBody(http_response);
    try std.testing.expectEqualStrings(response_json, response_body);
}

test "loopback http transport stores messages through encoded request bytes" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();
    var transport_state = try fx.LoopbackHttpClusterTransport.init(std.testing.allocator, storage, .{ .shard_count = 16 });
    defer transport_state.deinit();
    const transport = transport_state.asClusterTransport();

    const address = fx.entityAddress("counter", "loopback-store");
    const shard_id = try fx.shardIdForAddress(address, 16);
    var response = try transport.send(std.testing.allocator, .{
        .kind = .request,
        .address = address,
        .payload_type_name = "text",
        .payload = "get",
        .redacted_detail = "read current value",
        .idempotency_key = "loopback-store-key",
    });
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(shard_id, response.shard_id);
    try std.testing.expectEqual(fx.ClusterTransportKind.loopback_http, response.transport);
    try std.testing.expectEqual(@as(usize, 1), response.attempts);
    try std.testing.expect(response.correlation_id != null);

    var by_shard = try storage.unprocessedByShard(shard_id, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 1), by_shard.records.len);
    try std.testing.expectEqualStrings("loopback-store-key", by_shard.records[0].envelope.idempotency_key);
}

test "loopback http transport retries transient unavailable attempts" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();
    var transport_state = try fx.LoopbackHttpClusterTransport.init(std.testing.allocator, storage, .{
        .shard_count = 8,
        .failures_before_success = 2,
    });
    defer transport_state.deinit();
    const transport = transport_state.asClusterTransport();

    const address = fx.entityAddress("counter", "loopback-retry");
    const shard_id = try fx.shardIdForAddress(address, 8);
    var response = try transport.send(std.testing.allocator, .{
        .kind = .tell,
        .address = address,
        .payload_type_name = "text",
        .payload = "inc",
        .redacted_detail = "increment",
        .policy = .{ .timeout_ms = 500, .max_retries = 2 },
    });
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), response.attempts);
    try std.testing.expectEqual(fx.ClusterTransportKind.loopback_http, response.transport);
    var by_shard = try storage.unprocessedByShard(shard_id, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 1), by_shard.records.len);
}

test "loopback http transport stops after retry limit" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();
    var transport_state = try fx.LoopbackHttpClusterTransport.init(std.testing.allocator, storage, .{
        .shard_count = 8,
        .failures_before_success = 2,
    });
    defer transport_state.deinit();
    const transport = transport_state.asClusterTransport();

    const address = fx.entityAddress("counter", "loopback-retry-limit");
    const shard_id = try fx.shardIdForAddress(address, 8);
    try std.testing.expectError(error.RetryLimitExceeded, transport.send(std.testing.allocator, .{
        .kind = .tell,
        .address = address,
        .payload_type_name = "text",
        .payload = "inc",
        .redacted_detail = "increment",
        .policy = .{ .timeout_ms = 500, .max_retries = 1 },
    }));

    var by_shard = try storage.unprocessedByShard(shard_id, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 0), by_shard.records.len);
}
