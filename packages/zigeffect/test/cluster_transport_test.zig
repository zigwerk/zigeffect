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
