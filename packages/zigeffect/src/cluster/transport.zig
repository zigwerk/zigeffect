const std = @import("std");
const envelope = @import("envelope.zig");
const identity = @import("identity.zig");
const message_storage = @import("message_storage.zig");
const routing = @import("routing.zig");

pub const Allocator = std.mem.Allocator;
pub const EntityAddress = identity.EntityAddress;
pub const MessageCorrelationId = envelope.MessageCorrelationId;
pub const MessageEnvelope = envelope.MessageEnvelope;
pub const MessageEnvelopeKind = envelope.MessageEnvelopeKind;
pub const MessageId = envelope.MessageId;
pub const MessageStorage = message_storage.MessageStorage;
pub const ShardCount = routing.ShardCount;
pub const ShardId = routing.ShardId;

pub const transport_request_schema = "zigeffect.cluster.transport.request.v1";
pub const transport_request_schema_version: u32 = 1;
pub const transport_response_schema = "zigeffect.cluster.transport.response.v1";
pub const transport_response_schema_version: u32 = 1;

pub const ClusterTransportError = error{
    InvalidShardCount,
    UnsupportedIngressKind,
    TransportTimeout,
    TransportUnavailable,
    RetryLimitExceeded,
    CorruptTransportMessage,
    IncompatibleTransportSchema,
};

pub const ClusterTransportKind = enum {
    in_process,
    loopback_http,
};

pub const ClusterTransportPolicy = struct {
    timeout_ms: u64 = 30_000,
    max_retries: usize = 0,
};

pub const ClusterTransportRequest = struct {
    kind: MessageEnvelopeKind,
    address: EntityAddress,
    payload_type_name: []const u8 = "",
    payload: []const u8 = "",
    redacted_detail: []const u8 = "",
    idempotency_key: ?[]const u8 = null,
    policy: ClusterTransportPolicy = .{},

    pub fn deinit(self: *ClusterTransportRequest, allocator: Allocator) void {
        if (self.address.entity_type.name.len > 0) allocator.free(self.address.entity_type.name);
        if (self.payload_type_name.len > 0) allocator.free(self.payload_type_name);
        if (self.payload.len > 0) allocator.free(self.payload);
        if (self.redacted_detail.len > 0) allocator.free(self.redacted_detail);
        if (self.idempotency_key) |key| {
            if (key.len > 0) allocator.free(key);
        }
    }
};

pub const ClusterTransportResponse = struct {
    shard_id: ShardId,
    envelope: MessageEnvelope,
    correlation_id: ?MessageCorrelationId = null,
    duplicate: bool = false,
    attempts: usize = 1,
    transport: ClusterTransportKind,

    pub fn deinit(self: *ClusterTransportResponse, allocator: Allocator) void {
        envelope.deinitMessageEnvelope(allocator, self.envelope);
    }
};

pub const ClusterTransport = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        send: *const fn (*anyopaque, Allocator, ClusterTransportRequest) anyerror!ClusterTransportResponse,
    };

    pub fn send(self: ClusterTransport, allocator: Allocator, request: ClusterTransportRequest) !ClusterTransportResponse {
        return self.vtable.send(self.ptr, allocator, request);
    }
};

pub const InProcessClusterTransportOptions = struct {
    shard_count: ShardCount,
};

pub const InProcessClusterTransport = struct {
    message_storage: MessageStorage,
    shard_count: ShardCount,
    next_message_sequence: u64 = 1,

    pub fn init(allocator: Allocator, storage: MessageStorage, options: InProcessClusterTransportOptions) ClusterTransportError!InProcessClusterTransport {
        _ = allocator;
        if (options.shard_count == 0) return error.InvalidShardCount;
        return .{
            .message_storage = storage,
            .shard_count = options.shard_count,
        };
    }

    pub fn deinit(self: *InProcessClusterTransport) void {
        _ = self;
    }

    pub fn asClusterTransport(self: *InProcessClusterTransport) ClusterTransport {
        return .{
            .ptr = self,
            .vtable = &.{
                .send = sendOpaque,
            },
        };
    }

    pub fn send(self: *InProcessClusterTransport, allocator: Allocator, request: ClusterTransportRequest) !ClusterTransportResponse {
        _ = allocator;
        return self.sendWithAttempts(request, 1, .in_process);
    }

    fn sendWithAttempts(
        self: *InProcessClusterTransport,
        request: ClusterTransportRequest,
        attempts: usize,
        transport_kind: ClusterTransportKind,
    ) !ClusterTransportResponse {
        try validateIngressKind(request.kind);
        if (request.policy.timeout_ms == 0) return error.TransportTimeout;

        const shard_id = try routing.shardIdForAddress(request.address, self.shard_count);
        var idempotency_buf: [48]u8 = undefined;
        const idempotency_key = request.idempotency_key orelse blk: {
            const key = std.fmt.bufPrint(&idempotency_buf, "transport-inprocess:{d}", .{self.next_message_sequence}) catch unreachable;
            self.next_message_sequence += 1;
            break :blk key;
        };

        var submitted = try self.message_storage.submit(.{
            .shard_id = shard_id,
            .envelope = .{
                .kind = request.kind,
                .address = request.address,
                .idempotency_key = idempotency_key,
                .payload_type_name = request.payload_type_name,
                .payload = request.payload,
                .redacted_detail = request.redacted_detail,
            },
        });
        errdefer submitted.deinit(std.heap.page_allocator);

        return .{
            .shard_id = shard_id,
            .envelope = submitted.envelope,
            .correlation_id = submitted.envelope.correlation_id,
            .duplicate = submitted.duplicate,
            .attempts = attempts,
            .transport = transport_kind,
        };
    }

    fn sendOpaque(ptr: *anyopaque, allocator: Allocator, request: ClusterTransportRequest) anyerror!ClusterTransportResponse {
        const self: *InProcessClusterTransport = @ptrCast(@alignCast(ptr));
        return self.send(allocator, request);
    }
};

pub const LoopbackHttpClusterTransportOptions = struct {
    shard_count: ShardCount,
    failures_before_success: usize = 0,
};

pub const LoopbackHttpClusterTransport = struct {
    handler: InProcessClusterTransport,
    failures_before_success: usize = 0,

    pub fn init(allocator: Allocator, storage: MessageStorage, options: LoopbackHttpClusterTransportOptions) ClusterTransportError!LoopbackHttpClusterTransport {
        return .{
            .handler = try InProcessClusterTransport.init(allocator, storage, .{ .shard_count = options.shard_count }),
            .failures_before_success = options.failures_before_success,
        };
    }

    pub fn deinit(self: *LoopbackHttpClusterTransport) void {
        self.handler.deinit();
    }

    pub fn asClusterTransport(self: *LoopbackHttpClusterTransport) ClusterTransport {
        return .{
            .ptr = self,
            .vtable = &.{
                .send = sendOpaque,
            },
        };
    }

    pub fn send(self: *LoopbackHttpClusterTransport, allocator: Allocator, request: ClusterTransportRequest) !ClusterTransportResponse {
        const max_attempts = request.policy.max_retries + 1;
        var attempts: usize = 0;
        while (attempts < max_attempts) {
            attempts += 1;
            if (self.failures_before_success > 0) {
                self.failures_before_success -= 1;
                if (attempts >= max_attempts) return error.RetryLimitExceeded;
                continue;
            }

            const request_json = try formatClusterTransportRequestJson(allocator, request);
            defer allocator.free(request_json);
            const http_request = try formatClusterTransportHttpRequest(allocator, request_json);
            defer allocator.free(http_request);
            const request_body = try clusterTransportHttpBody(http_request);

            var parsed_request = try parseClusterTransportRequestJson(allocator, request_body);
            defer parsed_request.deinit(allocator);

            var handler_response = try self.handler.sendWithAttempts(parsed_request, attempts, .loopback_http);
            defer handler_response.deinit(allocator);

            const response_json = try formatClusterTransportResponseJson(allocator, handler_response);
            defer allocator.free(response_json);
            const http_response = try formatClusterTransportHttpResponse(allocator, response_json);
            defer allocator.free(http_response);
            const response_body = try clusterTransportHttpBody(http_response);
            return try parseClusterTransportResponseJson(allocator, response_body);
        }

        return error.RetryLimitExceeded;
    }

    fn sendOpaque(ptr: *anyopaque, allocator: Allocator, request: ClusterTransportRequest) anyerror!ClusterTransportResponse {
        const self: *LoopbackHttpClusterTransport = @ptrCast(@alignCast(ptr));
        return self.send(allocator, request);
    }
};

const ClusterTransportRequestJson = struct {
    schema: []const u8,
    schema_version: u32,
    kind: []const u8,
    entity_type: []const u8,
    entity_id: u64,
    payload_type_name: []const u8,
    payload: []const u8,
    redacted_detail: []const u8,
    idempotency_key: ?[]const u8,
    timeout_ms: u64,
    max_retries: usize,
};

const ClusterTransportResponseJson = struct {
    schema: []const u8,
    schema_version: u32,
    shard_id: ShardId,
    kind: []const u8,
    message_id: MessageId,
    correlation_id: ?MessageCorrelationId,
    entity_type: []const u8,
    entity_id: u64,
    idempotency_key: []const u8,
    payload_type_name: []const u8,
    payload: []const u8,
    redacted_detail: []const u8,
    duplicate: bool,
    attempts: usize,
    transport: []const u8,
};

pub fn formatClusterTransportRequestJson(allocator: Allocator, request: ClusterTransportRequest) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, transport_request_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{transport_request_schema_version});
    try output.appendSlice(allocator, ",\"kind\":");
    try appendJsonString(&output, allocator, @tagName(request.kind));
    try output.appendSlice(allocator, ",\"entity_type\":");
    try appendJsonString(&output, allocator, request.address.entity_type.name);
    try output.print(allocator, ",\"entity_id\":{d}", .{request.address.id});
    try output.appendSlice(allocator, ",\"payload_type_name\":");
    try appendJsonString(&output, allocator, request.payload_type_name);
    try output.appendSlice(allocator, ",\"payload\":");
    try appendJsonString(&output, allocator, request.payload);
    try output.appendSlice(allocator, ",\"redacted_detail\":");
    try appendJsonString(&output, allocator, request.redacted_detail);
    try output.appendSlice(allocator, ",\"idempotency_key\":");
    try appendOptionalJsonString(&output, allocator, request.idempotency_key);
    try output.print(allocator, ",\"timeout_ms\":{d}", .{request.policy.timeout_ms});
    try output.print(allocator, ",\"max_retries\":{d}", .{request.policy.max_retries});
    try output.append(allocator, '}');
    return output.toOwnedSlice(allocator);
}

pub fn parseClusterTransportRequestJson(allocator: Allocator, content: []const u8) (Allocator.Error || ClusterTransportError)!ClusterTransportRequest {
    var parsed = std.json.parseFromSlice(ClusterTransportRequestJson, allocator, content, .{ .ignore_unknown_fields = true }) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.CorruptTransportMessage,
    };
    defer parsed.deinit();

    if (!std.mem.eql(u8, parsed.value.schema, transport_request_schema)) return error.IncompatibleTransportSchema;
    if (parsed.value.schema_version != transport_request_schema_version) return error.IncompatibleTransportSchema;
    const kind = std.meta.stringToEnum(MessageEnvelopeKind, parsed.value.kind) orelse return error.CorruptTransportMessage;
    try validateIngressKind(kind);

    return .{
        .kind = kind,
        .address = .{
            .entity_type = .{ .name = try dupeOrEmpty(allocator, parsed.value.entity_type) },
            .id = parsed.value.entity_id,
        },
        .payload_type_name = try dupeOrEmpty(allocator, parsed.value.payload_type_name),
        .payload = try dupeOrEmpty(allocator, parsed.value.payload),
        .redacted_detail = try dupeOrEmpty(allocator, parsed.value.redacted_detail),
        .idempotency_key = if (parsed.value.idempotency_key) |key| try dupeOrEmpty(allocator, key) else null,
        .policy = .{
            .timeout_ms = parsed.value.timeout_ms,
            .max_retries = parsed.value.max_retries,
        },
    };
}

pub fn formatClusterTransportResponseJson(allocator: Allocator, response: ClusterTransportResponse) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, transport_response_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{transport_response_schema_version});
    try output.print(allocator, ",\"shard_id\":{d}", .{response.shard_id});
    try output.appendSlice(allocator, ",\"kind\":");
    try appendJsonString(&output, allocator, @tagName(response.envelope.kind));
    try output.print(allocator, ",\"message_id\":{d}", .{response.envelope.id});
    try output.appendSlice(allocator, ",\"correlation_id\":");
    try appendOptionalJsonU64(&output, allocator, response.correlation_id);
    try output.appendSlice(allocator, ",\"entity_type\":");
    try appendJsonString(&output, allocator, response.envelope.address.entity_type.name);
    try output.print(allocator, ",\"entity_id\":{d}", .{response.envelope.address.id});
    try output.appendSlice(allocator, ",\"idempotency_key\":");
    try appendJsonString(&output, allocator, response.envelope.idempotency_key);
    try output.appendSlice(allocator, ",\"payload_type_name\":");
    try appendJsonString(&output, allocator, response.envelope.payload_type_name);
    try output.appendSlice(allocator, ",\"payload\":");
    try appendJsonString(&output, allocator, response.envelope.payload);
    try output.appendSlice(allocator, ",\"redacted_detail\":");
    try appendJsonString(&output, allocator, response.envelope.redacted_detail);
    try output.print(allocator, ",\"duplicate\":{}", .{response.duplicate});
    try output.print(allocator, ",\"attempts\":{d}", .{response.attempts});
    try output.appendSlice(allocator, ",\"transport\":");
    try appendJsonString(&output, allocator, @tagName(response.transport));
    try output.append(allocator, '}');
    return output.toOwnedSlice(allocator);
}

pub fn parseClusterTransportResponseJson(allocator: Allocator, content: []const u8) (Allocator.Error || ClusterTransportError)!ClusterTransportResponse {
    var parsed = std.json.parseFromSlice(ClusterTransportResponseJson, allocator, content, .{ .ignore_unknown_fields = true }) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.CorruptTransportMessage,
    };
    defer parsed.deinit();

    if (!std.mem.eql(u8, parsed.value.schema, transport_response_schema)) return error.IncompatibleTransportSchema;
    if (parsed.value.schema_version != transport_response_schema_version) return error.IncompatibleTransportSchema;
    const kind = std.meta.stringToEnum(MessageEnvelopeKind, parsed.value.kind) orelse return error.CorruptTransportMessage;
    const transport_kind = std.meta.stringToEnum(ClusterTransportKind, parsed.value.transport) orelse return error.CorruptTransportMessage;

    return .{
        .shard_id = parsed.value.shard_id,
        .envelope = .{
            .id = parsed.value.message_id,
            .kind = kind,
            .address = .{
                .entity_type = .{ .name = try dupeOrEmpty(allocator, parsed.value.entity_type) },
                .id = parsed.value.entity_id,
            },
            .correlation_id = parsed.value.correlation_id,
            .idempotency_key = try dupeOrEmpty(allocator, parsed.value.idempotency_key),
            .payload_type_name = try dupeOrEmpty(allocator, parsed.value.payload_type_name),
            .payload = try dupeOrEmpty(allocator, parsed.value.payload),
            .redacted_detail = try dupeOrEmpty(allocator, parsed.value.redacted_detail),
        },
        .correlation_id = parsed.value.correlation_id,
        .duplicate = parsed.value.duplicate,
        .attempts = parsed.value.attempts,
        .transport = transport_kind,
    };
}

pub fn formatClusterTransportHttpRequest(allocator: Allocator, body: []const u8) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "POST /cluster/messages HTTP/1.1\r\nContent-Type: application/json\r\nContent-Length: {d}\r\n\r\n{s}",
        .{ body.len, body },
    );
}

pub fn formatClusterTransportHttpResponse(allocator: Allocator, body: []const u8) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {d}\r\n\r\n{s}",
        .{ body.len, body },
    );
}

pub fn clusterTransportHttpBody(message: []const u8) ClusterTransportError![]const u8 {
    const separator = "\r\n\r\n";
    const index = std.mem.indexOf(u8, message, separator) orelse return error.CorruptTransportMessage;
    return message[index + separator.len ..];
}

fn validateIngressKind(kind: MessageEnvelopeKind) ClusterTransportError!void {
    switch (kind) {
        .tell, .request, .interrupt => {},
        .reply, .ack, .chunk_reply => return error.UnsupportedIngressKind,
    }
}

fn dupeOrEmpty(allocator: Allocator, value: []const u8) Allocator.Error![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: Allocator, value: []const u8) Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

fn appendOptionalJsonString(output: *std.ArrayList(u8), allocator: Allocator, value: ?[]const u8) Allocator.Error!void {
    if (value) |text| {
        try appendJsonString(output, allocator, text);
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendOptionalJsonU64(output: *std.ArrayList(u8), allocator: Allocator, value: ?u64) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}
