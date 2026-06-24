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
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportAuthMode"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportAuth"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportLimits"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportTlsPolicy"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportBackpressurePolicy"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportConnectionPoolPolicy"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportLifecycleState"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportMetricsSnapshot"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportFailureReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "InProcessClusterTransport"));
    try std.testing.expect(@hasDecl(fx.cluster, "LoopbackHttpClusterTransport"));
    try std.testing.expect(@hasDecl(fx.cluster, "LoopbackSocketClusterTransport"));
    try std.testing.expect(@hasDecl(fx.cluster, "RemoteSocketClusterTransport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ProductionHttpClusterTransport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ProductionSocketClusterTransport"));
    try std.testing.expect(@hasDecl(fx.cluster, "formatClusterTransportSocketFrame"));
    try std.testing.expect(@hasDecl(fx.cluster, "clusterTransportSocketFrameBody"));
    try std.testing.expect(@hasDecl(fx.cluster, "formatClusterTransportFailureReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "chunkedClusterTransportRequest"));
    try std.testing.expect(@hasDecl(fx, "ClusterTransport"));
    try std.testing.expect(@hasDecl(fx, "ClusterTransportTlsPolicy"));
    try std.testing.expect(@hasDecl(fx, "ClusterTransportBackpressurePolicy"));
    try std.testing.expect(@hasDecl(fx, "LoopbackSocketClusterTransport"));
    try std.testing.expect(@hasDecl(fx, "RemoteSocketClusterTransport"));
    try std.testing.expect(@hasDecl(fx, "ProductionHttpClusterTransport"));
    try std.testing.expect(@hasDecl(fx, "ProductionSocketClusterTransport"));
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

test "transport request json redacts auth credential while preserving trace and chunk metadata" {
    const request = fx.ClusterTransportRequest{
        .kind = .request,
        .address = fx.entityAddress("counter", "transport-metadata"),
        .payload_type_name = "text",
        .payload = "get",
        .redacted_detail = "metadata",
        .idempotency_key = "transport-metadata-key",
        .auth = .{ .mode = .bearer_token, .credential = "token-1" },
        .trace_id = 7001,
        .span_id = 7002,
        .origin_causal_event_id = 7003,
        .chunk_index = 0,
        .chunk_count = 3,
        .policy = .{ .timeout_ms = 250, .max_retries = 2 },
    };

    const json = try fx.formatClusterTransportRequestJson(std.testing.allocator, request);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "token-1") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, fx.causal_redaction_marker) != null);

    var parsed = try fx.parseClusterTransportRequestJson(std.testing.allocator, json);
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(fx.ClusterTransportAuthMode.bearer_token, parsed.auth.mode);
    try std.testing.expectEqualStrings(fx.causal_redaction_marker, parsed.auth.credential.?);
    try std.testing.expectEqual(@as(?u64, 7001), parsed.trace_id);
    try std.testing.expectEqual(@as(?u64, 7002), parsed.span_id);
    try std.testing.expectEqual(@as(?u64, 7003), parsed.origin_causal_event_id);
    try std.testing.expectEqual(@as(?u32, 0), parsed.chunk_index);
    try std.testing.expectEqual(@as(?u32, 3), parsed.chunk_count);
}

test "transport request json never serializes sentinel auth credentials" {
    const request = fx.ClusterTransportRequest{
        .kind = .tell,
        .address = fx.entityAddress("counter", "transport-secret"),
        .payload_type_name = "text",
        .payload = "inc",
        .redacted_detail = "auth metadata",
        .auth = .{ .mode = .shared_secret, .credential = "sentinel-transport-secret-123" },
    };

    const json = try fx.formatClusterTransportRequestJson(std.testing.allocator, request);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "sentinel-transport-secret-123") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, fx.causal_redaction_marker) != null);
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

test "transport response json preserves trace chunk and production kind" {
    const response = fx.ClusterTransportResponse{
        .shard_id = 2,
        .envelope = .{
            .id = 99,
            .kind = .request,
            .address = fx.entityAddress("counter", "transport-response-metadata"),
            .correlation_id = 99,
            .idempotency_key = "transport-response-metadata-key",
            .trace_id = 8001,
            .span_id = 8002,
            .chunk_index = 1,
            .chunk_count = 4,
            .payload_type_name = "text",
            .payload = "get",
            .redacted_detail = "metadata",
        },
        .correlation_id = 99,
        .attempts = 1,
        .transport = .production_http,
    };

    const json = try fx.formatClusterTransportResponseJson(std.testing.allocator, response);
    defer std.testing.allocator.free(json);
    var parsed = try fx.parseClusterTransportResponseJson(std.testing.allocator, json);
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(fx.ClusterTransportKind.production_http, parsed.transport);
    try std.testing.expectEqual(@as(?u64, 8001), parsed.envelope.trace_id);
    try std.testing.expectEqual(@as(?u64, 8002), parsed.envelope.span_id);
    try std.testing.expectEqual(@as(?u32, 1), parsed.envelope.chunk_index);
    try std.testing.expectEqual(@as(?u32, 4), parsed.envelope.chunk_count);
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

test "production transport rejects invalid limits on init" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();

    try std.testing.expectError(error.InvalidTransportLimits, fx.ProductionHttpClusterTransport.init(std.testing.allocator, storage, .{
        .shard_count = 4,
        .limits = .{ .max_envelope_bytes = 0, .max_chunk_bytes = 1, .max_in_flight = 1 },
    }));
    try std.testing.expectError(error.InvalidTransportLimits, fx.ProductionHttpClusterTransport.init(std.testing.allocator, storage, .{
        .shard_count = 4,
        .limits = .{ .max_envelope_bytes = 8, .max_chunk_bytes = 0, .max_in_flight = 1 },
    }));
    try std.testing.expectError(error.InvalidTransportLimits, fx.ProductionHttpClusterTransport.init(std.testing.allocator, storage, .{
        .shard_count = 4,
        .limits = .{ .max_envelope_bytes = 8, .max_chunk_bytes = 9, .max_in_flight = 1 },
    }));
    try std.testing.expectError(error.InvalidTransportLimits, fx.ProductionHttpClusterTransport.init(std.testing.allocator, storage, .{
        .shard_count = 4,
        .limits = .{ .max_envelope_bytes = 8, .max_chunk_bytes = 8, .max_in_flight = 0 },
    }));
}

test "production transport auth rejects before durable submission" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();
    var transport_state = try fx.ProductionHttpClusterTransport.init(std.testing.allocator, storage, .{
        .shard_count = 4,
        .auth = .{ .mode = .bearer_token, .credential = "secret-token" },
    });
    defer transport_state.deinit();

    const address = fx.entityAddress("counter", "production-auth-reject");
    const shard_id = try fx.shardIdForAddress(address, 4);
    try std.testing.expectError(error.TransportUnauthorized, transport_state.asClusterTransport().send(std.testing.allocator, .{
        .kind = .tell,
        .address = address,
        .payload_type_name = "text",
        .payload = "inc",
        .redacted_detail = "auth failure",
        .auth = .{ .mode = .bearer_token, .credential = "wrong-token" },
    }));

    var by_shard = try storage.unprocessedByShard(shard_id, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 0), by_shard.records.len);
    const metrics = transport_state.snapshotMetrics();
    try std.testing.expectEqual(@as(usize, 1), metrics.failures);
    try std.testing.expectEqualStrings("TransportUnauthorized", metrics.last_error_name);
}

test "production transport limit and backpressure reject before durable submission" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();
    var transport_state = try fx.ProductionHttpClusterTransport.init(std.testing.allocator, storage, .{
        .shard_count = 4,
        .limits = .{ .max_envelope_bytes = 4, .max_chunk_bytes = 4, .max_in_flight = 1 },
    });
    defer transport_state.deinit();

    const address = fx.entityAddress("counter", "production-limit-reject");
    const shard_id = try fx.shardIdForAddress(address, 4);
    try std.testing.expectError(error.TransportPayloadTooLarge, transport_state.asClusterTransport().send(std.testing.allocator, .{
        .kind = .tell,
        .address = address,
        .payload_type_name = "text",
        .payload = "12345",
        .redacted_detail = "too large",
    }));

    transport_state.lifecycle.in_flight = 1;
    try std.testing.expectError(error.TransportBackpressured, transport_state.asClusterTransport().send(std.testing.allocator, .{
        .kind = .tell,
        .address = address,
        .payload_type_name = "text",
        .payload = "inc",
        .redacted_detail = "backpressure",
    }));

    var by_shard = try storage.unprocessedByShard(shard_id, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 0), by_shard.records.len);
    const metrics = transport_state.snapshotMetrics();
    try std.testing.expectEqual(@as(usize, 2), metrics.failures);
    try std.testing.expectEqual(@as(usize, 1), metrics.backpressured);
}

test "transport failure report formats without secrets" {
    const report = fx.ClusterTransportFailureReport{
        .transport = .production_http,
        .retryable = true,
        .attempts = 3,
        .error_name = "TransportUnavailable",
        .redacted_detail = "mode=bearer_token",
    };
    const text = try fx.formatClusterTransportFailureReport(std.testing.allocator, report);
    defer std.testing.allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "TransportUnavailable") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "production_http") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "secret") == null);
}

test "production http transport stores messages through authenticated encoded request bytes" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();
    var transport_state = try fx.ProductionHttpClusterTransport.init(std.testing.allocator, storage, .{
        .shard_count = 16,
        .auth = .{ .mode = .shared_secret, .credential = "shared-1" },
    });
    defer transport_state.deinit();

    const address = fx.entityAddress("counter", "production-http-store");
    const shard_id = try fx.shardIdForAddress(address, 16);
    var response = try transport_state.asClusterTransport().send(std.testing.allocator, .{
        .kind = .request,
        .address = address,
        .payload_type_name = "text",
        .payload = "get",
        .redacted_detail = "read current value",
        .idempotency_key = "production-http-store-key",
        .auth = .{ .mode = .shared_secret, .credential = "shared-1" },
        .trace_id = 9001,
        .span_id = 9002,
    });
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(shard_id, response.shard_id);
    try std.testing.expectEqual(fx.ClusterTransportKind.production_http, response.transport);
    try std.testing.expectEqual(@as(?u64, 9001), response.envelope.trace_id);
    try std.testing.expectEqual(@as(?u64, 9002), response.envelope.span_id);

    var by_shard = try storage.unprocessedByShard(shard_id, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 1), by_shard.records.len);
    try std.testing.expectEqual(@as(?u64, 9001), by_shard.records[0].envelope.trace_id);

    const metrics = transport_state.snapshotMetrics();
    try std.testing.expect(metrics.bytes_sent > 0);
    try std.testing.expect(metrics.bytes_received > 0);
    try std.testing.expectEqual(@as(usize, 1), metrics.successes);
}

test "production http transport retries transient unavailable attempts" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    var transport_state = try fx.ProductionHttpClusterTransport.init(std.testing.allocator, storage_state.asMessageStorage(), .{
        .shard_count = 8,
        .failures_before_success = 2,
    });
    defer transport_state.deinit();

    var response = try transport_state.asClusterTransport().send(std.testing.allocator, .{
        .kind = .tell,
        .address = fx.entityAddress("counter", "production-http-retry"),
        .payload_type_name = "text",
        .payload = "inc",
        .redacted_detail = "increment",
        .policy = .{ .timeout_ms = 500, .max_retries = 2 },
    });
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), response.attempts);
    try std.testing.expectEqual(fx.ClusterTransportKind.production_http, response.transport);
    const metrics = transport_state.snapshotMetrics();
    try std.testing.expectEqual(@as(usize, 2), metrics.retries);
    try std.testing.expectEqual(@as(usize, 1), metrics.successes);
}

test "production http transport stops after retry limit without durable submission" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();
    var transport_state = try fx.ProductionHttpClusterTransport.init(std.testing.allocator, storage, .{
        .shard_count = 8,
        .failures_before_success = 2,
    });
    defer transport_state.deinit();

    const address = fx.entityAddress("counter", "production-http-retry-limit");
    const shard_id = try fx.shardIdForAddress(address, 8);
    try std.testing.expectError(error.RetryLimitExceeded, transport_state.asClusterTransport().send(std.testing.allocator, .{
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
    const failure = transport_state.lastFailure().?;
    try std.testing.expectEqual(fx.ClusterTransportKind.production_http, failure.transport);
    try std.testing.expectEqualStrings("RetryLimitExceeded", failure.error_name);
}

test "socket frame codec extracts framed body" {
    const body = "{\"schema\":\"zigeffect.cluster.transport.request.v1\"}";
    const frame = try fx.formatClusterTransportSocketFrame(std.testing.allocator, body);
    defer std.testing.allocator.free(frame);
    const parsed = try fx.clusterTransportSocketFrameBody(frame);
    try std.testing.expectEqualStrings(body, parsed);
    try std.testing.expectError(error.CorruptTransportMessage, fx.clusterTransportSocketFrameBody("BAD/1 3\nabc"));
    try std.testing.expectError(error.CorruptTransportMessage, fx.clusterTransportSocketFrameBody("ZIGFX/1 5\nabc"));
}

test "production socket transport stores messages through framed request bytes" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();
    var transport_state = try fx.ProductionSocketClusterTransport.init(std.testing.allocator, storage, .{ .shard_count = 16 });
    defer transport_state.deinit();

    const address = fx.entityAddress("counter", "production-socket-store");
    const shard_id = try fx.shardIdForAddress(address, 16);
    var response = try transport_state.asClusterTransport().send(std.testing.allocator, .{
        .kind = .request,
        .address = address,
        .payload_type_name = "text",
        .payload = "get",
        .redacted_detail = "read current value",
        .idempotency_key = "production-socket-store-key",
        .trace_id = 9101,
        .span_id = 9102,
        .chunk_index = 0,
        .chunk_count = 1,
    });
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(shard_id, response.shard_id);
    try std.testing.expectEqual(fx.ClusterTransportKind.production_socket, response.transport);
    try std.testing.expectEqual(@as(?u64, 9101), response.envelope.trace_id);
    try std.testing.expectEqual(@as(?u64, 9102), response.envelope.span_id);
    try std.testing.expectEqual(@as(?u32, 0), response.envelope.chunk_index);
    try std.testing.expectEqual(@as(?u32, 1), response.envelope.chunk_count);

    var by_shard = try storage.unprocessedByShard(shard_id, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 1), by_shard.records.len);

    const metrics = transport_state.snapshotMetrics();
    try std.testing.expect(metrics.bytes_sent > 0);
    try std.testing.expect(metrics.bytes_received > 0);
    try std.testing.expectEqual(@as(usize, 1), metrics.successes);
}

test "production socket transport retries transient unavailable attempts" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    var transport_state = try fx.ProductionSocketClusterTransport.init(std.testing.allocator, storage_state.asMessageStorage(), .{
        .shard_count = 8,
        .failures_before_success = 1,
    });
    defer transport_state.deinit();

    var response = try transport_state.asClusterTransport().send(std.testing.allocator, .{
        .kind = .tell,
        .address = fx.entityAddress("counter", "production-socket-retry"),
        .payload_type_name = "text",
        .payload = "inc",
        .redacted_detail = "increment",
        .policy = .{ .timeout_ms = 500, .max_retries = 1 },
    });
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), response.attempts);
    try std.testing.expectEqual(fx.ClusterTransportKind.production_socket, response.transport);
    const metrics = transport_state.snapshotMetrics();
    try std.testing.expectEqual(@as(usize, 1), metrics.retries);
    try std.testing.expectEqual(@as(usize, 1), metrics.successes);
}

test "chunked transport request records chunk metadata without changing payload" {
    const request = fx.ClusterTransportRequest{
        .kind = .request,
        .address = fx.entityAddress("counter", "chunk-helper"),
        .payload_type_name = "text",
        .payload = "abcdef",
        .redacted_detail = "chunk",
    };
    var chunked = try fx.chunkedClusterTransportRequest(std.testing.allocator, request, .{
        .max_envelope_bytes = 64,
        .max_chunk_bytes = 2,
        .max_in_flight = 2,
    });
    defer chunked.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(?u32, 0), chunked.chunk_index);
    try std.testing.expectEqual(@as(?u32, 3), chunked.chunk_count);
    try std.testing.expectEqualStrings("abcdef", chunked.payload);
}

test "cluster runner processes ask sent through in-process transport" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runner_storage_state = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer runner_storage_state.deinit();
    var message_storage_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_state.deinit();

    var transport_state = try fx.InProcessClusterTransport.init(
        std.testing.allocator,
        message_storage_state.asMessageStorage(),
        .{ .shard_count = 8 },
    );
    defer transport_state.deinit();

    try expectRunnerProcessesTransportAsk(
        transport_state.asClusterTransport(),
        runner_storage_state.asRunnerStorage(),
        message_storage_state.asMessageStorage(),
        .in_process,
    );
}

test "cluster runner processes ask sent through loopback http transport" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runner_storage_state = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer runner_storage_state.deinit();
    var message_storage_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_state.deinit();

    var transport_state = try fx.LoopbackHttpClusterTransport.init(
        std.testing.allocator,
        message_storage_state.asMessageStorage(),
        .{ .shard_count = 8 },
    );
    defer transport_state.deinit();

    try expectRunnerProcessesTransportAsk(
        transport_state.asClusterTransport(),
        runner_storage_state.asRunnerStorage(),
        message_storage_state.asMessageStorage(),
        .loopback_http,
    );
}

test "cluster runner processes ask sent through production http transport" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runner_storage_state = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer runner_storage_state.deinit();
    var message_storage_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_state.deinit();

    var transport_state = try fx.ProductionHttpClusterTransport.init(
        std.testing.allocator,
        message_storage_state.asMessageStorage(),
        .{ .shard_count = 8 },
    );
    defer transport_state.deinit();

    try expectRunnerProcessesTransportAsk(
        transport_state.asClusterTransport(),
        runner_storage_state.asRunnerStorage(),
        message_storage_state.asMessageStorage(),
        .production_http,
    );
}

test "cluster runner processes ask sent through production socket transport" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runner_storage_state = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer runner_storage_state.deinit();
    var message_storage_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_state.deinit();

    var transport_state = try fx.ProductionSocketClusterTransport.init(
        std.testing.allocator,
        message_storage_state.asMessageStorage(),
        .{ .shard_count = 8 },
    );
    defer transport_state.deinit();

    try expectRunnerProcessesTransportAsk(
        transport_state.asClusterTransport(),
        runner_storage_state.asRunnerStorage(),
        message_storage_state.asMessageStorage(),
        .production_socket,
    );
}

test "loopback socket transport crosses real localhost TCP and preserves envelope fields" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runner_storage_state = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer runner_storage_state.deinit();
    var message_storage_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_state.deinit();

    var transport_state = try fx.LoopbackSocketClusterTransport.init(
        std.testing.allocator,
        std.testing.io,
        message_storage_state.asMessageStorage(),
        .{ .shard_count = 8, .port = 19391 },
    );
    defer transport_state.deinit();

    try expectRunnerProcessesTransportAsk(
        transport_state.asClusterTransport(),
        runner_storage_state.asRunnerStorage(),
        message_storage_state.asMessageStorage(),
        .production_socket,
    );

    const metrics = transport_state.snapshotMetrics();
    try std.testing.expectEqual(@as(usize, 1), metrics.sends);
    try std.testing.expectEqual(@as(usize, 1), metrics.successes);
    try std.testing.expect(metrics.bytes_sent > 0);
    try std.testing.expect(metrics.bytes_received > 0);
}

test "loopback socket transport trace is structurally equivalent to in-process transport trace" {
    var in_process_trace = fx.CausalStore.init(std.testing.allocator);
    defer in_process_trace.deinit();
    try recordTransportAcceptanceTrace(&in_process_trace, .in_process, 0);

    var loopback_trace = fx.CausalStore.init(std.testing.allocator);
    defer loopback_trace.deinit();
    try recordTransportAcceptanceTrace(&loopback_trace, .loopback_socket, 19392);

    var in_process_snapshot = try in_process_trace.snapshot(std.testing.allocator);
    defer in_process_snapshot.deinit();
    var loopback_snapshot = try loopback_trace.snapshot(std.testing.allocator);
    defer loopback_snapshot.deinit();

    try std.testing.expect(try fx.causalStructurallyEquivalent(
        std.testing.allocator,
        in_process_snapshot.events,
        loopback_snapshot.events,
    ));
}

test "remote socket transport rejects wrong auth before durable submission" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var message_storage_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_state.deinit();

    var transport_state = try fx.RemoteSocketClusterTransport.init(
        std.testing.allocator,
        std.testing.io,
        message_storage_state.asMessageStorage(),
        .{
            .shard_count = 8,
            .port = 19393,
            .auth = .{ .mode = .shared_secret, .credential = "server-secret" },
            .pool_size = 2,
            .reconnect_attempts = 1,
        },
    );
    defer transport_state.deinit();

    const address = fx.entityAddress("counter", "remote-auth-reject");
    const shard_id = try fx.shardIdForAddress(address, 8);

    try std.testing.expectError(error.TransportUnauthorized, transport_state.asClusterTransport().send(std.testing.allocator, .{
        .kind = .tell,
        .address = address,
        .payload_type_name = "text",
        .payload = "inc",
        .redacted_detail = "auth failure",
        .auth = .{ .mode = .shared_secret, .credential = "wrong-secret" },
    }));

    var by_shard = try message_storage_state.asMessageStorage().unprocessedByShard(shard_id, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 0), by_shard.records.len);
    const metrics = transport_state.snapshotMetrics();
    try std.testing.expectEqual(@as(usize, 1), metrics.failures);
    try std.testing.expectEqualStrings("TransportUnauthorized", metrics.last_error_name);
    const failure = transport_state.lastFailure().?;
    try std.testing.expect(std.mem.indexOf(u8, failure.redacted_detail, "server-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, failure.redacted_detail, "wrong-secret") == null);
}

test "remote socket transport sends over socket path with matching auth" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var message_storage_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_state.deinit();

    var transport_state = try fx.RemoteSocketClusterTransport.init(
        std.testing.allocator,
        std.testing.io,
        message_storage_state.asMessageStorage(),
        .{
            .shard_count = 8,
            .port = 19394,
            .auth = .{ .mode = .shared_secret, .credential = "server-secret" },
            .pool_size = 2,
            .reconnect_attempts = 1,
        },
    );
    defer transport_state.deinit();

    const address = fx.entityAddress("counter", "remote-auth-ok");
    var response = try transport_state.asClusterTransport().send(std.testing.allocator, .{
        .kind = .request,
        .address = address,
        .payload_type_name = "text",
        .payload = "get",
        .redacted_detail = "remote read",
        .idempotency_key = "remote-auth-ok-key",
        .auth = .{ .mode = .shared_secret, .credential = "server-secret" },
        .trace_id = 14001,
        .span_id = 14002,
    });
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(fx.ClusterTransportKind.production_socket, response.transport);
    try std.testing.expect(response.correlation_id != null);
    const metrics = transport_state.snapshotMetrics();
    try std.testing.expectEqual(@as(usize, 1), metrics.sends);
    try std.testing.expectEqual(@as(usize, 1), metrics.successes);
    try std.testing.expect(metrics.bytes_sent > 0);
    try std.testing.expect(metrics.bytes_received > 0);
}

test "remote socket transport validates TLS and pool policy before start" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var message_storage_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_state.deinit();

    try std.testing.expectError(error.InvalidTransportLimits, fx.RemoteSocketClusterTransport.init(
        std.testing.allocator,
        std.testing.io,
        message_storage_state.asMessageStorage(),
        .{
            .shard_count = 8,
            .port = 19395,
            .tls = .{ .mode = .pinned_fingerprint, .pinned_fingerprint = "" },
        },
    ));

    try std.testing.expectError(error.InvalidTransportLimits, fx.RemoteSocketClusterTransport.init(
        std.testing.allocator,
        std.testing.io,
        message_storage_state.asMessageStorage(),
        .{
            .shard_count = 8,
            .port = 19396,
            .pool = .{ .max_connections = 0 },
        },
    ));
}

test "remote socket transport applies reject backpressure before durable submission" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var message_storage_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_state.deinit();

    var transport_state = try fx.RemoteSocketClusterTransport.init(
        std.testing.allocator,
        std.testing.io,
        message_storage_state.asMessageStorage(),
        .{
            .shard_count = 8,
            .port = 19397,
            .backpressure = .{ .strategy = .reject, .max_queued = 0 },
        },
    );
    defer transport_state.deinit();

    const address = fx.entityAddress("counter", "remote-backpressure");
    const shard_id = try fx.shardIdForAddress(address, 8);
    try std.testing.expectError(error.TransportBackpressured, transport_state.asClusterTransport().send(std.testing.allocator, .{
        .kind = .tell,
        .address = address,
        .payload_type_name = "text",
        .payload = "inc",
        .redacted_detail = "backpressure",
    }));

    var by_shard = try message_storage_state.asMessageStorage().unprocessedByShard(shard_id, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 0), by_shard.records.len);
    const metrics = transport_state.snapshotMetrics();
    try std.testing.expectEqual(@as(usize, 1), metrics.backpressured);
}

test "remote socket transport preserves origin causal event id across socket path" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var message_storage_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_state.deinit();

    var transport_state = try fx.RemoteSocketClusterTransport.init(
        std.testing.allocator,
        std.testing.io,
        message_storage_state.asMessageStorage(),
        .{ .shard_count = 8, .port = 19398 },
    );
    defer transport_state.deinit();

    const address = fx.entityAddress("counter", "remote-origin-causal");
    var response = try transport_state.asClusterTransport().send(std.testing.allocator, .{
        .kind = .request,
        .address = address,
        .payload_type_name = "text",
        .payload = "get",
        .redacted_detail = "origin",
        .idempotency_key = "remote-origin-causal-key",
        .origin_causal_event_id = 777,
    });
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u64, 777), response.origin_causal_event_id);
    try std.testing.expectEqual(@as(?u64, 777), response.envelope.origin_causal_event_id);
}

const TraceTransportKind = enum {
    in_process,
    loopback_socket,
};

fn recordTransportAcceptanceTrace(store: *fx.CausalStore, kind: TraceTransportKind, port: u16) !void {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runner_storage_state = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer runner_storage_state.deinit();
    var message_storage_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_state.deinit();

    switch (kind) {
        .in_process => {
            var transport_state = try fx.InProcessClusterTransport.init(
                std.testing.allocator,
                message_storage_state.asMessageStorage(),
                .{ .shard_count = 8 },
            );
            defer transport_state.deinit();
            try recordTransportAcceptanceTraceWithTransport(
                store,
                transport_state.asClusterTransport(),
                runner_storage_state.asRunnerStorage(),
                message_storage_state.asMessageStorage(),
            );
        },
        .loopback_socket => {
            var transport_state = try fx.LoopbackSocketClusterTransport.init(
                std.testing.allocator,
                std.testing.io,
                message_storage_state.asMessageStorage(),
                .{ .shard_count = 8, .port = port },
            );
            defer transport_state.deinit();
            try recordTransportAcceptanceTraceWithTransport(
                store,
                transport_state.asClusterTransport(),
                runner_storage_state.asRunnerStorage(),
                message_storage_state.asMessageStorage(),
            );
        },
    }
}

fn recordTransportAcceptanceTraceWithTransport(
    store: *fx.CausalStore,
    transport: fx.ClusterTransport,
    runner_storage: fx.RunnerStorage,
    message_storage: fx.MessageStorage,
) !void {
    var runner = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = fx.runnerAddress("machine-trace", "runner-trace"),
        .runner_storage = runner_storage,
        .message_storage = message_storage,
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 1,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
    defer runner.deinit();

    const run_id = store.nextRunId();
    const run = try store.record(.{ .kind = .run_started, .run_id = run_id, .status = "started", .label = "transport trace" });

    var plan = try runner.acquireBalancedShards(1_000);
    defer plan.deinit();
    try std.testing.expectEqual(@as(usize, 8), plan.shards.len);
    const runner_event = try store.record(.{ .kind = .cluster_runner_registered, .run_id = run_id, .parent_id = run, .status = "registered" });

    const address = fx.entityAddress("counter", "transport-trace-acceptance");
    _ = try runner.registerEntity(.{ .address = address, .name = "transport-counter" }, 1_000);
    const entity_event = try store.record(.{ .kind = .cluster_entity_registered, .run_id = run_id, .parent_id = runner_event, .status = "registered" });

    var response = try transport.send(std.testing.allocator, .{
        .kind = .request,
        .address = address,
        .payload_type_name = "text",
        .payload = "get",
        .redacted_detail = "read through trace transport",
        .idempotency_key = "transport-trace-acceptance-key",
        .trace_id = 13001,
        .span_id = 13002,
    });
    defer response.deinit(std.testing.allocator);
    const submitted_event = try store.record(.{ .kind = .cluster_message_submitted, .run_id = run_id, .parent_id = entity_event, .trace_id = 13001, .span_id = 13002, .status = "submitted" });

    var before_tick = try message_storage.unprocessedByShard(response.shard_id, std.testing.allocator);
    defer before_tick.deinit();
    try std.testing.expectEqual(@as(usize, 1), before_tick.records.len);
    const claimed_event = try store.record(.{ .kind = .cluster_message_claimed, .run_id = run_id, .parent_id = submitted_event, .trace_id = 13001, .span_id = 13002, .status = "claimed" });

    const Handler = struct {
        pub fn handle(_: *fx.EntityScope, envelope: fx.EntityEnvelope) !fx.EntityHandlerResult {
            try std.testing.expectEqual(fx.EntityEnvelopeKind.ask, envelope.kind);
            try std.testing.expectEqualStrings("get", envelope.payload);
            return .{ .reply = "value=trace" };
        }
    };

    const report = try runner.tick(Handler, 1_100);
    try std.testing.expectEqual(@as(usize, 1), report.scanned);
    try std.testing.expectEqual(@as(usize, 1), report.dispatched);
    try std.testing.expectEqual(@as(usize, 1), report.replied);
    try std.testing.expectEqual(@as(usize, 1), report.acked);
    const processed_event = try store.record(.{ .kind = .cluster_entity_processed, .run_id = run_id, .parent_id = claimed_event, .trace_id = 13001, .span_id = 13002, .status = "processed" });

    const reply = (try message_storage.reply(response.correlation_id.?, std.testing.allocator)).?;
    defer fx.deinitMessageEnvelope(std.testing.allocator, reply);
    try std.testing.expectEqual(fx.MessageEnvelopeKind.reply, reply.kind);
    try std.testing.expectEqualStrings("value=trace", reply.payload);
    const replied_event = try store.record(.{ .kind = .cluster_message_replied, .run_id = run_id, .parent_id = processed_event, .trace_id = 13001, .span_id = 13002, .status = "replied" });
    const acked_event = try store.record(.{ .kind = .cluster_message_acked, .run_id = run_id, .parent_id = replied_event, .trace_id = 13001, .span_id = 13002, .status = "acked" });
    _ = try store.record(.{ .kind = .cluster_trace_propagated, .run_id = run_id, .parent_id = acked_event, .trace_id = 13001, .span_id = 13002, .status = "propagated" });
    _ = try store.record(.{ .kind = .run_completed, .run_id = run_id, .parent_id = run, .status = "success", .label = "transport trace" });
}

fn expectRunnerProcessesTransportAsk(
    transport: fx.ClusterTransport,
    runner_storage: fx.RunnerStorage,
    message_storage: fx.MessageStorage,
    expected_transport: fx.ClusterTransportKind,
) !void {
    var runner = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = fx.runnerAddress("machine-transport", "runner-transport"),
        .runner_storage = runner_storage,
        .message_storage = message_storage,
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 1,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
    defer runner.deinit();

    var plan = try runner.acquireBalancedShards(1_000);
    defer plan.deinit();
    try std.testing.expectEqual(@as(usize, 8), plan.shards.len);

    const address = fx.entityAddress("counter", "transport-runner-acceptance");
    _ = try runner.registerEntity(.{ .address = address, .name = "transport-counter" }, 1_000);

    var response = try transport.send(std.testing.allocator, .{
        .kind = .request,
        .address = address,
        .payload_type_name = "text",
        .payload = "get",
        .redacted_detail = "read through transport",
        .idempotency_key = "transport-runner-acceptance-key",
        .trace_id = 12001,
        .span_id = 12002,
        .chunk_index = 0,
        .chunk_count = 1,
    });
    defer response.deinit(std.testing.allocator);
    try std.testing.expectEqual(expected_transport, response.transport);
    try std.testing.expect(response.correlation_id != null);
    try std.testing.expectEqual(@as(?u64, 12001), response.envelope.trace_id);
    try std.testing.expectEqual(@as(?u64, 12002), response.envelope.span_id);
    try std.testing.expectEqual(@as(?u32, 0), response.envelope.chunk_index);
    try std.testing.expectEqual(@as(?u32, 1), response.envelope.chunk_count);

    var before_tick = try message_storage.unprocessedByShard(response.shard_id, std.testing.allocator);
    defer before_tick.deinit();
    try std.testing.expectEqual(@as(usize, 1), before_tick.records.len);
    try std.testing.expectEqual(@as(?u64, 12001), before_tick.records[0].envelope.trace_id);
    try std.testing.expectEqual(@as(?u64, 12002), before_tick.records[0].envelope.span_id);
    try std.testing.expectEqual(@as(?u32, 0), before_tick.records[0].envelope.chunk_index);
    try std.testing.expectEqual(@as(?u32, 1), before_tick.records[0].envelope.chunk_count);

    const Handler = struct {
        pub fn handle(_: *fx.EntityScope, envelope: fx.EntityEnvelope) !fx.EntityHandlerResult {
            try std.testing.expectEqual(fx.EntityEnvelopeKind.ask, envelope.kind);
            try std.testing.expectEqualStrings("get", envelope.payload);
            return .{ .reply = "value=transport" };
        }
    };

    const report = try runner.tick(Handler, 1_100);
    try std.testing.expectEqual(@as(usize, 1), report.scanned);
    try std.testing.expectEqual(@as(usize, 1), report.dispatched);
    try std.testing.expectEqual(@as(usize, 1), report.replied);
    try std.testing.expectEqual(@as(usize, 1), report.acked);

    const reply = (try message_storage.reply(response.correlation_id.?, std.testing.allocator)).?;
    defer fx.deinitMessageEnvelope(std.testing.allocator, reply);
    try std.testing.expectEqual(fx.MessageEnvelopeKind.reply, reply.kind);
    try std.testing.expectEqualStrings("value=transport", reply.payload);
    try std.testing.expectEqual(@as(?u64, 12001), reply.trace_id);
    try std.testing.expectEqual(@as(?u64, 12002), reply.span_id);
    try std.testing.expectEqual(@as(?u32, 0), reply.chunk_index);
    try std.testing.expectEqual(@as(?u32, 1), reply.chunk_count);
}
