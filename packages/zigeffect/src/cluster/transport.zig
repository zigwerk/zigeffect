const std = @import("std");
const envelope = @import("envelope.zig");
const identity = @import("identity.zig");
const message_storage = @import("message_storage.zig");
const routing = @import("routing.zig");
const async_backend_mod = @import("../runtime/async_backend.zig");

pub const Allocator = std.mem.Allocator;
pub const AsyncBackend = async_backend_mod.AsyncBackend;
pub const EntityAddress = identity.EntityAddress;
pub const MessageCorrelationId = envelope.MessageCorrelationId;
pub const MessageEnvelope = envelope.MessageEnvelope;
pub const MessageEnvelopeKind = envelope.MessageEnvelopeKind;
pub const MessageId = envelope.MessageId;
pub const MessageStorage = message_storage.MessageStorage;
pub const ShardCount = routing.ShardCount;
pub const ShardId = routing.ShardId;
pub const Suspension = async_backend_mod.Suspension;

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
    TransportUnauthorized,
    TransportPayloadTooLarge,
    TransportBackpressured,
    InvalidTransportLimits,
};

pub const ClusterTransportKind = enum {
    in_process,
    loopback_http,
    production_http,
    production_socket,
};

pub const ClusterTransportPolicy = struct {
    timeout_ms: u64 = 30_000,
    max_retries: usize = 0,
};

pub const ClusterTransportAuthMode = enum {
    none,
    bearer_token,
    shared_secret,
};

pub const ClusterTransportAuth = struct {
    mode: ClusterTransportAuthMode = .none,
    credential: ?[]const u8 = null,
};

pub const ClusterTransportLimits = struct {
    max_envelope_bytes: usize = 1024 * 1024,
    max_chunk_bytes: usize = 64 * 1024,
    max_in_flight: usize = 1024,
};

pub const ClusterTransportLifecycleState = struct {
    started: bool = true,
    stopped: bool = false,
    sends: usize = 0,
    successes: usize = 0,
    failures: usize = 0,
    retries: usize = 0,
    backpressured: usize = 0,
    bytes_sent: usize = 0,
    bytes_received: usize = 0,
    in_flight: usize = 0,
    last_error_name: []const u8 = "",
};

pub const ClusterTransportMetricsSnapshot = ClusterTransportLifecycleState;

pub const ClusterTransportFailureReport = struct {
    transport: ClusterTransportKind,
    retryable: bool,
    attempts: usize,
    error_name: []const u8,
    redacted_detail: []const u8 = "",
};

pub const ClusterTransportRequest = struct {
    kind: MessageEnvelopeKind,
    address: EntityAddress,
    payload_type_name: []const u8 = "",
    payload: []const u8 = "",
    redacted_detail: []const u8 = "",
    idempotency_key: ?[]const u8 = null,
    auth: ClusterTransportAuth = .{},
    trace_id: ?u64 = null,
    span_id: ?u64 = null,
    chunk_index: ?u32 = null,
    chunk_count: ?u32 = null,
    policy: ClusterTransportPolicy = .{},

    pub fn deinit(self: *ClusterTransportRequest, allocator: Allocator) void {
        if (self.address.entity_type.name.len > 0) allocator.free(self.address.entity_type.name);
        if (self.payload_type_name.len > 0) allocator.free(self.payload_type_name);
        if (self.payload.len > 0) allocator.free(self.payload);
        if (self.redacted_detail.len > 0) allocator.free(self.redacted_detail);
        if (self.idempotency_key) |key| {
            if (key.len > 0) allocator.free(key);
        }
        if (self.auth.credential) |credential| {
            if (credential.len > 0) allocator.free(credential);
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

pub const ClusterTransportAsyncWait = struct {
    request: ClusterTransportRequest,
    suspension_id: u64,
    submitted: bool = false,

    pub fn deinit(self: *ClusterTransportAsyncWait, allocator: Allocator) void {
        self.request.deinit(allocator);
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

pub fn registerClusterTransportWait(
    allocator: Allocator,
    backend: AsyncBackend,
    request: ClusterTransportRequest,
    suspension_id: u64,
) (Allocator.Error || async_backend_mod.AsyncBackendError)!ClusterTransportAsyncWait {
    var owned_request = try cloneClusterTransportRequest(allocator, request);
    errdefer owned_request.deinit(allocator);

    try backend.registerIoWait(.{
        .suspension = .{
            .kind = .external,
            .id = suspension_id,
            .label = "cluster.transport",
        },
        .io_kind = .network,
        .interest = .completion,
        .reason = request.idempotency_key orelse request.redacted_detail,
    });

    return .{
        .request = owned_request,
        .suspension_id = suspension_id,
    };
}

pub fn completeClusterTransportWait(
    allocator: Allocator,
    backend: AsyncBackend,
    transport_value: ClusterTransport,
    wait: *ClusterTransportAsyncWait,
) anyerror!ClusterTransportResponse {
    if (wait.submitted) return error.RetryLimitExceeded;

    try backend.completeIo(.{
        .suspension_id = wait.suspension_id,
        .io_kind = .network,
        .reason = "cluster transport ready",
    });

    const wake = (try backend.pollWake()) orelse return error.TransportUnavailable;
    if (wake.suspension.id != wait.suspension_id) return error.TransportUnavailable;
    if (wake.status != .ready) return error.TransportUnavailable;

    var response = try transport_value.send(allocator, wait.request);
    errdefer response.deinit(allocator);
    wait.submitted = true;
    return response;
}

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

pub const ProductionHttpClusterTransportOptions = struct {
    shard_count: ShardCount,
    auth: ClusterTransportAuth = .{},
    limits: ClusterTransportLimits = .{},
    failures_before_success: usize = 0,
};

pub const ProductionHttpClusterTransport = struct {
    handler: InProcessClusterTransport,
    auth: ClusterTransportAuth = .{},
    limits: ClusterTransportLimits = .{},
    failures_before_success: usize = 0,
    lifecycle: ClusterTransportLifecycleState = .{},
    last_failure: ?ClusterTransportFailureReport = null,

    pub fn init(allocator: Allocator, storage: MessageStorage, options: ProductionHttpClusterTransportOptions) ClusterTransportError!ProductionHttpClusterTransport {
        try validateTransportLimits(options.limits);
        return .{
            .handler = try InProcessClusterTransport.init(allocator, storage, .{ .shard_count = options.shard_count }),
            .auth = options.auth,
            .limits = options.limits,
            .failures_before_success = options.failures_before_success,
        };
    }

    pub fn deinit(self: *ProductionHttpClusterTransport) void {
        self.handler.deinit();
    }

    pub fn asClusterTransport(self: *ProductionHttpClusterTransport) ClusterTransport {
        return .{
            .ptr = self,
            .vtable = &.{
                .send = sendOpaque,
            },
        };
    }

    pub fn snapshotMetrics(self: *const ProductionHttpClusterTransport) ClusterTransportMetricsSnapshot {
        return self.lifecycle;
    }

    pub fn stop(self: *ProductionHttpClusterTransport) void {
        self.lifecycle.started = false;
        self.lifecycle.stopped = true;
    }

    pub fn lastFailure(self: *const ProductionHttpClusterTransport) ?ClusterTransportFailureReport {
        return self.last_failure;
    }

    pub fn send(self: *ProductionHttpClusterTransport, allocator: Allocator, request: ClusterTransportRequest) !ClusterTransportResponse {
        self.lifecycle.sends += 1;
        try self.preflight(request);

        self.lifecycle.in_flight += 1;
        defer self.lifecycle.in_flight -= 1;

        var response = self.handler.sendWithAttempts(request, 1, .production_http) catch |err| {
            self.recordFailure(1, err, "durable submit failed");
            return err;
        };
        errdefer response.deinit(allocator);

        self.lifecycle.successes += 1;
        return response;
    }

    fn preflight(self: *ProductionHttpClusterTransport, request: ClusterTransportRequest) ClusterTransportError!void {
        if (self.lifecycle.stopped) {
            self.recordFailure(1, error.TransportUnavailable, "transport stopped");
            return error.TransportUnavailable;
        }
        if (request.policy.timeout_ms == 0) {
            self.recordFailure(1, error.TransportTimeout, "timeout before submit");
            return error.TransportTimeout;
        }
        validateTransportAuth(self.auth, request.auth) catch |err| {
            self.recordFailure(1, err, "auth rejected");
            return err;
        };
        validateTransportEnvelopeLimits(request, self.limits) catch |err| {
            self.recordFailure(1, err, "envelope limits rejected");
            return err;
        };
        if (self.lifecycle.in_flight >= self.limits.max_in_flight) {
            self.recordFailure(1, error.TransportBackpressured, "max in-flight reached");
            return error.TransportBackpressured;
        }
    }

    fn recordFailure(self: *ProductionHttpClusterTransport, attempts: usize, err: anyerror, detail: []const u8) void {
        recordTransportFailure(&self.lifecycle, &self.last_failure, .production_http, attempts, err, detail);
    }

    fn sendOpaque(ptr: *anyopaque, allocator: Allocator, request: ClusterTransportRequest) anyerror!ClusterTransportResponse {
        const self: *ProductionHttpClusterTransport = @ptrCast(@alignCast(ptr));
        return self.send(allocator, request);
    }
};

pub const ProductionSocketClusterTransportOptions = ProductionHttpClusterTransportOptions;

pub const ProductionSocketClusterTransport = struct {};

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
    auth_mode: []const u8 = "none",
    auth_credential: ?[]const u8 = null,
    trace_id: ?u64 = null,
    span_id: ?u64 = null,
    chunk_index: ?u32 = null,
    chunk_count: ?u32 = null,
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
    trace_id: ?u64 = null,
    span_id: ?u64 = null,
    chunk_index: ?u32 = null,
    chunk_count: ?u32 = null,
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
    try output.appendSlice(allocator, ",\"auth_mode\":");
    try appendJsonString(&output, allocator, @tagName(request.auth.mode));
    try output.appendSlice(allocator, ",\"auth_credential\":");
    try appendOptionalJsonString(&output, allocator, request.auth.credential);
    try output.appendSlice(allocator, ",\"trace_id\":");
    try appendOptionalJsonU64(&output, allocator, request.trace_id);
    try output.appendSlice(allocator, ",\"span_id\":");
    try appendOptionalJsonU64(&output, allocator, request.span_id);
    try output.appendSlice(allocator, ",\"chunk_index\":");
    try appendOptionalJsonU32(&output, allocator, request.chunk_index);
    try output.appendSlice(allocator, ",\"chunk_count\":");
    try appendOptionalJsonU32(&output, allocator, request.chunk_count);
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
    const auth_mode = std.meta.stringToEnum(ClusterTransportAuthMode, parsed.value.auth_mode) orelse return error.CorruptTransportMessage;
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
        .auth = .{
            .mode = auth_mode,
            .credential = if (parsed.value.auth_credential) |credential| try dupeOrEmpty(allocator, credential) else null,
        },
        .trace_id = parsed.value.trace_id,
        .span_id = parsed.value.span_id,
        .chunk_index = parsed.value.chunk_index,
        .chunk_count = parsed.value.chunk_count,
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
    try output.appendSlice(allocator, ",\"trace_id\":");
    try appendOptionalJsonU64(&output, allocator, response.envelope.trace_id);
    try output.appendSlice(allocator, ",\"span_id\":");
    try appendOptionalJsonU64(&output, allocator, response.envelope.span_id);
    try output.appendSlice(allocator, ",\"chunk_index\":");
    try appendOptionalJsonU32(&output, allocator, response.envelope.chunk_index);
    try output.appendSlice(allocator, ",\"chunk_count\":");
    try appendOptionalJsonU32(&output, allocator, response.envelope.chunk_count);
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
            .trace_id = parsed.value.trace_id,
            .span_id = parsed.value.span_id,
            .chunk_index = parsed.value.chunk_index,
            .chunk_count = parsed.value.chunk_count,
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

pub fn formatClusterTransportSocketFrame(allocator: Allocator, body: []const u8) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "ZIGFX/1 {d}\n{s}", .{ body.len, body });
}

pub fn clusterTransportSocketFrameBody(frame: []const u8) ClusterTransportError![]const u8 {
    const separator_index = std.mem.indexOfScalar(u8, frame, '\n') orelse return error.CorruptTransportMessage;
    const header = frame[0..separator_index];
    const body = frame[separator_index + 1 ..];
    const prefix = "ZIGFX/1 ";
    if (!std.mem.startsWith(u8, header, prefix)) return error.CorruptTransportMessage;
    const expected_len = std.fmt.parseInt(usize, header[prefix.len..], 10) catch return error.CorruptTransportMessage;
    if (body.len != expected_len) return error.CorruptTransportMessage;
    return body;
}

pub fn formatClusterTransportFailureReport(allocator: Allocator, report: ClusterTransportFailureReport) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "cluster transport failure transport={s} retryable={} attempts={d} error={s} detail={s}",
        .{
            @tagName(report.transport),
            report.retryable,
            report.attempts,
            report.error_name,
            report.redacted_detail,
        },
    );
}

fn validateTransportLimits(limits: ClusterTransportLimits) ClusterTransportError!void {
    if (limits.max_envelope_bytes == 0) return error.InvalidTransportLimits;
    if (limits.max_chunk_bytes == 0) return error.InvalidTransportLimits;
    if (limits.max_chunk_bytes > limits.max_envelope_bytes) return error.InvalidTransportLimits;
    if (limits.max_in_flight == 0) return error.InvalidTransportLimits;
}

fn validateTransportAuth(required: ClusterTransportAuth, provided: ClusterTransportAuth) ClusterTransportError!void {
    if (required.mode != provided.mode) return error.TransportUnauthorized;
    switch (required.mode) {
        .none => {
            if (provided.credential != null) return error.TransportUnauthorized;
        },
        .bearer_token, .shared_secret => {
            const required_credential = required.credential orelse return error.TransportUnauthorized;
            const provided_credential = provided.credential orelse return error.TransportUnauthorized;
            if (required_credential.len == 0 or provided_credential.len == 0) return error.TransportUnauthorized;
            if (!std.mem.eql(u8, required_credential, provided_credential)) return error.TransportUnauthorized;
        },
    }
}

fn validateTransportEnvelopeLimits(request: ClusterTransportRequest, limits: ClusterTransportLimits) ClusterTransportError!void {
    if (request.payload.len > limits.max_envelope_bytes) return error.TransportPayloadTooLarge;
}

fn isRetryableTransportError(err: anyerror) bool {
    return err == error.TransportUnavailable or
        err == error.TransportBackpressured or
        err == error.TransportTimeout;
}

fn recordTransportFailure(
    lifecycle: *ClusterTransportLifecycleState,
    last_failure: *?ClusterTransportFailureReport,
    kind: ClusterTransportKind,
    attempts: usize,
    err: anyerror,
    detail: []const u8,
) void {
    lifecycle.failures += 1;
    if (err == error.TransportBackpressured) lifecycle.backpressured += 1;
    lifecycle.last_error_name = @errorName(err);
    last_failure.* = .{
        .transport = kind,
        .retryable = isRetryableTransportError(err),
        .attempts = attempts,
        .error_name = @errorName(err),
        .redacted_detail = detail,
    };
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

fn cloneClusterTransportRequest(allocator: Allocator, request: ClusterTransportRequest) Allocator.Error!ClusterTransportRequest {
    var owned = ClusterTransportRequest{
        .kind = request.kind,
        .address = .{
            .entity_type = .{ .name = try dupeOrEmpty(allocator, request.address.entity_type.name) },
            .id = request.address.id,
        },
        .policy = request.policy,
        .auth = .{ .mode = request.auth.mode },
        .trace_id = request.trace_id,
        .span_id = request.span_id,
        .chunk_index = request.chunk_index,
        .chunk_count = request.chunk_count,
    };
    errdefer owned.deinit(allocator);

    owned.payload_type_name = try dupeOrEmpty(allocator, request.payload_type_name);
    owned.payload = try dupeOrEmpty(allocator, request.payload);
    owned.redacted_detail = try dupeOrEmpty(allocator, request.redacted_detail);
    owned.idempotency_key = if (request.idempotency_key) |key| try dupeOrEmpty(allocator, key) else null;
    owned.auth.credential = if (request.auth.credential) |credential| try dupeOrEmpty(allocator, credential) else null;
    return owned;
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

fn appendOptionalJsonU32(output: *std.ArrayList(u8), allocator: Allocator, value: ?u32) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}
