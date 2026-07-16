const std = @import("std");
const zstd = @import("zigeffect_std");
const Iap = @import("iap.zig");

pub const Grpc = zstd.Grpc;

pub const Protocol = enum { grpc, connect };

pub const CallContext = struct {
    protocol: Protocol,
    authority: []const u8,
    service: []const u8,
    method: []const u8,
    shape: Grpc.CallShape,
    authorization: []const u8 = "",
    iap_jwt: []const u8 = "",
    traceparent: []const u8 = "",
    tracestate: []const u8 = "",
    baggage: []const u8 = "",
    request_id: []const u8 = "",
};

pub const TimestampSource = struct {
    pointer: *anyopaque,
    now_fn: *const fn (*anyopaque) u64,

    pub fn from(comptime Target: type, target: *Target) TimestampSource {
        return .{ .pointer = target, .now_fn = struct {
            fn now(pointer: *anyopaque) u64 {
                return (@as(*Target, @ptrCast(@alignCast(pointer)))).nowMillis();
            }
        }.now };
    }
};

pub const IapAuth = struct {
    verifier: *Iap.Verifier,
    clock: TimestampSource,
    allow_health_without_identity: bool = true,

    pub fn interceptor(self: *IapAuth) Interceptor {
        return Interceptor.from(IapAuth, self);
    }

    pub fn before(self: *IapAuth, context: *CallContext) ?Grpc.Status {
        if (self.allow_health_without_identity and std.mem.eql(u8, context.service, "grpc.health.v1.Health")) return null;
        if (context.iap_jwt.len == 0) return .{ .code = .unauthenticated, .message = "IAP identity required" };
        var identity = self.verifier.verifyAlloc(std.heap.page_allocator, context.iap_jwt, self.clock.now_fn(self.clock.pointer)) catch {
            return .{ .code = .unauthenticated, .message = "IAP identity rejected" };
        };
        identity.deinit();
        return null;
    }

    pub fn after(_: *IapAuth, _: *const CallContext, _: Outcome) void {}
};

pub const ClientCallContext = struct {
    authority: []const u8,
    service: []const u8,
    method: []const u8,
    shape: Grpc.CallShape,
    metadata: []const Grpc.Metadata,
    appended_metadata: []const Grpc.Metadata = &.{},
};

pub const ClientOutcome = struct {
    code: Grpc.Code,
    transport_failed: bool = false,
};

pub const CausalBoundary = enum {
    resolve,
    connect,
    pick,
    attempt,
    retry,
    stream,
    handler,
    status,
    drain,
    shutdown,
};

/// Writes secret-free native gRPC lifecycle facts into ZigEffect's causal
/// application runtime. Dynamic values are restricted to bounded service and
/// method labels; payloads, metadata, authorities, and credentials are never
/// recorded.
pub const CausalFacts = struct {
    recorder: zstd.CausalRuntime.CausalRecorder,
    service_key: []const u8 = "zigeffect-grpc",
    dropped: std.atomic.Value(usize) = .init(0),

    pub fn emit(
        self: *CausalFacts,
        boundary: CausalBoundary,
        status: []const u8,
        service: []const u8,
        method: []const u8,
    ) void {
        self.emitCorrelated(boundary, status, service, method, null, null);
    }

    pub fn emitCall(
        self: *CausalFacts,
        boundary: CausalBoundary,
        status: []const u8,
        context: *const CallContext,
    ) void {
        const trace_parent = zstd.fx.parseTraceParent(context.traceparent) catch null;
        self.emitCorrelated(
            boundary,
            status,
            context.service,
            context.method,
            if (context.request_id.len == 0) null else std.hash.Wyhash.hash(0, context.request_id),
            trace_parent,
        );
    }

    fn emitCorrelated(
        self: *CausalFacts,
        boundary: CausalBoundary,
        status: []const u8,
        service: []const u8,
        method: []const u8,
        boundary_id: ?u64,
        trace_parent: ?zstd.fx.TraceParent,
    ) void {
        const safe_service = boundedRpcAttribute(service);
        const safe_method = boundedRpcAttribute(method);
        var detail_buffer: [600]u8 = undefined;
        const detail = std.fmt.bufPrint(
            &detail_buffer,
            "service={s} method={s}",
            .{ safe_service, safe_method },
        ) catch "service=other method=other";
        _ = self.recorder.record(.{
            .kind = .external_signal_received,
            .service_key = self.service_key,
            .boundary_id = boundary_id,
            .trace_id = if (trace_parent) |trace| trace.trace_id_low else null,
            .span_id = if (trace_parent) |trace| trace.parent_id else null,
            .context = if (trace_parent) |trace| trace.context() else .{},
            .label = @tagName(boundary),
            .type_name = "GrpcBoundaryFact",
            .status = status,
            .redacted_detail = detail,
        }) catch {
            _ = self.dropped.fetchAdd(1, .monotonic);
        };
    }

    pub fn interceptor(self: *CausalFacts) Interceptor {
        return Interceptor.from(CausalFacts, self);
    }

    pub fn clientInterceptor(self: *CausalFacts) ClientInterceptor {
        return ClientInterceptor.from(CausalFacts, self);
    }

    pub fn before(self: *CausalFacts, context: *CallContext) ?Grpc.Status {
        self.emitCall(.handler, "started", context);
        return null;
    }

    pub fn after(self: *CausalFacts, context: *const CallContext, outcome: Outcome) void {
        self.emitCall(.handler, if (outcome.code == .ok) "succeeded" else "failed", context);
        self.emitCall(.status, @tagName(outcome.code), context);
    }

    pub fn beforeClient(self: *CausalFacts, context: *ClientCallContext) ?Grpc.Status {
        self.emit(.attempt, "started", context.service, context.method);
        return null;
    }

    pub fn afterClient(self: *CausalFacts, context: *const ClientCallContext, outcome: ClientOutcome) void {
        self.emit(.attempt, if (outcome.code == .ok) "succeeded" else "failed", context.service, context.method);
        self.emit(.status, @tagName(outcome.code), context.service, context.method);
    }
};

pub const ClientInterceptor = struct {
    pointer: *anyopaque,
    before_fn: *const fn (*anyopaque, *ClientCallContext) ?Grpc.Status,
    after_fn: *const fn (*anyopaque, *const ClientCallContext, ClientOutcome) void,

    pub fn from(comptime Target: type, target: *Target) ClientInterceptor {
        return .{
            .pointer = target,
            .before_fn = struct {
                fn call(pointer: *anyopaque, context: *ClientCallContext) ?Grpc.Status {
                    return (@as(*Target, @ptrCast(@alignCast(pointer)))).beforeClient(context);
                }
            }.call,
            .after_fn = struct {
                fn call(pointer: *anyopaque, context: *const ClientCallContext, outcome: ClientOutcome) void {
                    (@as(*Target, @ptrCast(@alignCast(pointer)))).afterClient(context, outcome);
                }
            }.call,
        };
    }
};

pub const AppendClientMetadata = struct {
    metadata: []const Grpc.Metadata,

    pub fn interceptor(self: *AppendClientMetadata) ClientInterceptor {
        return ClientInterceptor.from(AppendClientMetadata, self);
    }

    pub fn beforeClient(self: *AppendClientMetadata, context: *ClientCallContext) ?Grpc.Status {
        context.appended_metadata = self.metadata;
        return null;
    }

    pub fn afterClient(_: *AppendClientMetadata, _: *const ClientCallContext, _: ClientOutcome) void {}
};

pub const InterceptedClient = struct {
    downstream: Grpc.Client,
    interceptors: []const ClientInterceptor,

    pub fn client(self: *InterceptedClient) Grpc.Client {
        return .{ .ptr = self, .invoke_fn = invokeErased };
    }

    pub fn invokeAlloc(self: *InterceptedClient, allocator: std.mem.Allocator, request: Grpc.UnaryRequest, options: Grpc.CallOptions) anyerror!Grpc.UnaryResponse {
        var context = ClientCallContext{
            .authority = request.authority,
            .service = request.service,
            .method = request.method,
            .shape = .unary,
            .metadata = request.metadata,
        };
        var entered: usize = 0;
        for (self.interceptors, 0..) |interceptor, index| {
            if (interceptor.before_fn(interceptor.pointer, &context)) |denied| {
                finishClient(self.interceptors, index, &context, .{ .code = denied.code });
                return Grpc.UnaryResponse.initAlloc(allocator, "", denied);
            }
            entered += 1;
        }
        const combined = try allocator.alloc(Grpc.Metadata, context.metadata.len + context.appended_metadata.len);
        defer allocator.free(combined);
        @memcpy(combined[0..context.metadata.len], context.metadata);
        @memcpy(combined[context.metadata.len..], context.appended_metadata);
        var forwarded = request;
        forwarded.metadata = combined;
        const response = self.downstream.invokeAlloc(allocator, forwarded, options) catch |err| {
            finishClient(self.interceptors, entered, &context, .{ .code = .unavailable, .transport_failed = true });
            return err;
        };
        finishClient(self.interceptors, entered, &context, .{ .code = response.status.code });
        return response;
    }

    fn invokeErased(pointer: *anyopaque, allocator: std.mem.Allocator, request: Grpc.UnaryRequest, options: Grpc.CallOptions) anyerror!Grpc.UnaryResponse {
        return (@as(*InterceptedClient, @ptrCast(@alignCast(pointer)))).invokeAlloc(allocator, request, options);
    }
};

pub const StreamingClient = struct {
    pointer: *anyopaque,
    invoke_fn: *const fn (*anyopaque, std.mem.Allocator, Grpc.StreamingRequest, Grpc.CallOptions) anyerror!Grpc.StreamingResponse,

    pub fn from(comptime Target: type, target: *Target) StreamingClient {
        return .{
            .pointer = target,
            .invoke_fn = struct {
                fn invoke(pointer: *anyopaque, allocator: std.mem.Allocator, request: Grpc.StreamingRequest, options: Grpc.CallOptions) anyerror!Grpc.StreamingResponse {
                    return (@as(*Target, @ptrCast(@alignCast(pointer)))).invokeStreamingAlloc(allocator, request, options);
                }
            }.invoke,
        };
    }
};

pub const InterceptedStreamingClient = struct {
    downstream: StreamingClient,
    interceptors: []const ClientInterceptor,

    pub fn invokeStreamingAlloc(self: *InterceptedStreamingClient, allocator: std.mem.Allocator, request: Grpc.StreamingRequest, options: Grpc.CallOptions) anyerror!Grpc.StreamingResponse {
        var context = ClientCallContext{
            .authority = request.authority,
            .service = request.service,
            .method = request.method,
            .shape = request.shape,
            .metadata = request.metadata,
        };
        var entered: usize = 0;
        for (self.interceptors, 0..) |interceptor, index| {
            if (interceptor.before_fn(interceptor.pointer, &context)) |denied| {
                finishClient(self.interceptors, index, &context, .{ .code = denied.code });
                return Grpc.StreamingResponse.initAlloc(allocator, &.{}, denied);
            }
            entered += 1;
        }
        const combined = try allocator.alloc(Grpc.Metadata, context.metadata.len + context.appended_metadata.len);
        defer allocator.free(combined);
        @memcpy(combined[0..context.metadata.len], context.metadata);
        @memcpy(combined[context.metadata.len..], context.appended_metadata);
        var forwarded = request;
        forwarded.metadata = combined;
        const response = self.downstream.invoke_fn(self.downstream.pointer, allocator, forwarded, options) catch |err| {
            finishClient(self.interceptors, entered, &context, .{ .code = .unavailable, .transport_failed = true });
            return err;
        };
        finishClient(self.interceptors, entered, &context, .{ .code = response.status.code });
        return response;
    }
};

fn finishClient(interceptors: []const ClientInterceptor, entered: usize, context: *const ClientCallContext, outcome: ClientOutcome) void {
    var index = entered;
    while (index != 0) {
        index -= 1;
        const interceptor = interceptors[index];
        interceptor.after_fn(interceptor.pointer, context, outcome);
    }
}

pub const TelemetrySignal = enum { logs, metrics, traces };

pub const TelemetryAttributeValue = union(enum) { string: []const u8, int: i64 };
pub const TelemetryAttribute = struct { key: []const u8, value: TelemetryAttributeValue };
pub const MetricRecord = struct {
    service_name: []const u8,
    name: []const u8,
    unit: []const u8,
    value: i64,
    time_unix_nanos: u64,
    attributes: []const TelemetryAttribute,
};
pub const Exemplar = struct {
    time_unix_nanos: u64,
    value: f64,
    trace_id: []const u8,
    span_id: []const u8,
    filtered_attributes: []const TelemetryAttribute = &.{},
};
pub const HistogramRecord = struct {
    service_name: []const u8,
    name: []const u8,
    unit: []const u8,
    count: u64,
    sum: f64,
    bucket_counts: []const u64,
    explicit_bounds: []const f64,
    min: ?f64 = null,
    max: ?f64 = null,
    time_unix_nanos: u64,
    attributes: []const TelemetryAttribute,
    exemplars: []const Exemplar = &.{},
};
pub const SpanLink = struct {
    trace_id: []const u8,
    span_id: []const u8,
    tracestate: []const u8 = "",
    attributes: []const TelemetryAttribute = &.{},
};
pub const SpanRecord = struct {
    service_name: []const u8,
    trace_id: []const u8,
    span_id: []const u8,
    parent_span_id: []const u8,
    name: []const u8,
    start_time_unix_nanos: u64,
    end_time_unix_nanos: u64,
    status_error: bool,
    attributes: []const TelemetryAttribute,
    links: []const SpanLink = &.{},
};
pub const LogRecord = struct {
    service_name: []const u8,
    time_unix_nanos: u64,
    severity_number: u8,
    severity_text: []const u8,
    body: []const u8,
    attributes: []const TelemetryAttribute,
};
pub const TelemetryRecord = union(enum) { metric: MetricRecord, histogram: HistogramRecord, span: SpanRecord, log: LogRecord };

pub const TelemetrySink = struct {
    pointer: *anyopaque,
    emit_fn: *const fn (*anyopaque, TelemetryRecord) anyerror!void,

    pub fn from(comptime Target: type, target: *Target) TelemetrySink {
        return .{ .pointer = target, .emit_fn = struct {
            fn emit(pointer: *anyopaque, record: TelemetryRecord) anyerror!void {
                return (@as(*Target, @ptrCast(@alignCast(pointer)))).emit(record);
            }
        }.emit };
    }
};

pub const OtlpTelemetry = struct {
    allocator: std.mem.Allocator,
    service_name: []const u8,
    sink: TelemetrySink,
    export_failures: std.atomic.Value(usize) = .init(0),
    sequence: std.atomic.Value(u64) = .init(1),

    pub fn interceptor(self: *OtlpTelemetry) Interceptor {
        return Interceptor.from(OtlpTelemetry, self);
    }

    pub fn before(_: *OtlpTelemetry, _: *CallContext) ?Grpc.Status {
        return null;
    }

    pub fn after(self: *OtlpTelemetry, context: *const CallContext, outcome: Outcome) void {
        const service = boundedRpcAttribute(context.service);
        const method = boundedRpcAttribute(context.method);
        const protocol = @tagName(context.protocol);
        const metric_attributes = [_]TelemetryAttribute{
            .{ .key = "rpc.system", .value = .{ .string = protocol } },
            .{ .key = "rpc.service", .value = .{ .string = service } },
            .{ .key = "rpc.method", .value = .{ .string = method } },
            .{ .key = "rpc.grpc.status_code", .value = .{ .int = @intFromEnum(outcome.code) } },
            .{ .key = "rpc.request.messages", .value = .{ .int = telemetryInt(outcome.request_messages) } },
            .{ .key = "rpc.response.messages", .value = .{ .int = telemetryInt(outcome.response_messages) } },
        };
        var trace_id: [32]u8 = undefined;
        var parent_id: [16]u8 = undefined;
        traceIdentifiers(context, self.sequence.fetchAdd(1, .monotonic), &trace_id, &parent_id);
        var span_id: [16]u8 = undefined;
        spanIdentifier(trace_id, self.sequence.load(.monotonic), &span_id);
        const end_nanos = if (outcome.end_time_unix_nanos != 0) outcome.end_time_unix_nanos else outcome.duration_millis *| std.time.ns_per_ms;
        const start_nanos = end_nanos -| outcome.duration_millis *| std.time.ns_per_ms;

        self.emit(.{ .metric = .{
            .service_name = self.service_name,
            .name = "rpc.server.call.attempts",
            .unit = "{attempt}",
            .value = 1,
            .time_unix_nanos = outcome.end_time_unix_nanos,
            .attributes = &metric_attributes,
        } });
        self.emitDurationHistogram(
            "rpc.server.call.duration",
            context.service,
            context.method,
            outcome.code,
            outcome.duration_millis,
            end_nanos,
            &trace_id,
            &span_id,
        );
        const span_attributes = [_]TelemetryAttribute{
            .{ .key = "rpc.system", .value = .{ .string = protocol } },
            .{ .key = "rpc.service", .value = .{ .string = service } },
            .{ .key = "rpc.method", .value = .{ .string = method } },
        };
        self.emit(.{ .span = .{
            .service_name = self.service_name,
            .trace_id = &trace_id,
            .span_id = &span_id,
            .parent_span_id = &parent_id,
            .name = method,
            .start_time_unix_nanos = start_nanos,
            .end_time_unix_nanos = end_nanos,
            .status_error = outcome.code != .ok,
            .attributes = &span_attributes,
        } });

        if (outcome.code != .ok) {
            const log_attributes = [_]TelemetryAttribute{
                .{ .key = "rpc.system", .value = .{ .string = protocol } },
                .{ .key = "rpc.service", .value = .{ .string = service } },
                .{ .key = "rpc.method", .value = .{ .string = method } },
                .{ .key = "rpc.grpc.status_code", .value = .{ .int = @intFromEnum(outcome.code) } },
            };
            self.emit(.{ .log = .{
                .service_name = self.service_name,
                .time_unix_nanos = end_nanos,
                .severity_number = 17,
                .severity_text = "ERROR",
                .body = "RPC completed with non-OK status",
                .attributes = &log_attributes,
            } });
        }
    }

    pub fn recordClientAttempt(
        self: *OtlpTelemetry,
        service: []const u8,
        method: []const u8,
        code: Grpc.Code,
        duration_millis: u64,
        end_time_unix_nanos: u64,
    ) void {
        var context = CallContext{
            .protocol = .grpc,
            .authority = "",
            .service = service,
            .method = method,
            .shape = .unary,
        };
        var trace_id: [32]u8 = undefined;
        var parent_id: [16]u8 = undefined;
        traceIdentifiers(&context, self.sequence.fetchAdd(1, .monotonic), &trace_id, &parent_id);
        var span_id: [16]u8 = undefined;
        spanIdentifier(trace_id, self.sequence.load(.monotonic), &span_id);
        self.emitDurationHistogram("rpc.client.attempt.duration", service, method, code, duration_millis, end_time_unix_nanos, &trace_id, &span_id);
    }

    pub fn recordConnection(self: *OtlpTelemetry, state: []const u8, delta: i64, time_unix_nanos: u64) void {
        const attributes = [_]TelemetryAttribute{.{ .key = "network.state", .value = .{ .string = boundedRpcAttribute(state) } }};
        self.emit(.{ .metric = .{
            .service_name = self.service_name,
            .name = "rpc.client.connections.usage",
            .unit = "{connection}",
            .value = delta,
            .time_unix_nanos = time_unix_nanos,
            .attributes = &attributes,
        } });
    }

    fn emitDurationHistogram(
        self: *OtlpTelemetry,
        name: []const u8,
        service_value: []const u8,
        method_value: []const u8,
        code: Grpc.Code,
        duration_millis: u64,
        time_unix_nanos: u64,
        trace_id: []const u8,
        span_id: []const u8,
    ) void {
        const bounds = [_]f64{ 5, 10, 25, 50, 100, 250, 500, 1_000 };
        var bucket_counts = [_]u64{0} ** (bounds.len + 1);
        var bucket = bounds.len;
        for (bounds, 0..) |bound, index| if (@as(f64, @floatFromInt(duration_millis)) <= bound) {
            bucket = index;
            break;
        };
        bucket_counts[bucket] = 1;
        const attributes = [_]TelemetryAttribute{
            .{ .key = "rpc.system", .value = .{ .string = "grpc" } },
            .{ .key = "rpc.service", .value = .{ .string = boundedRpcAttribute(service_value) } },
            .{ .key = "rpc.method", .value = .{ .string = boundedRpcAttribute(method_value) } },
            .{ .key = "rpc.grpc.status_code", .value = .{ .int = @intFromEnum(code) } },
        };
        const exemplars = [_]Exemplar{.{
            .time_unix_nanos = time_unix_nanos,
            .value = @floatFromInt(duration_millis),
            .trace_id = trace_id,
            .span_id = span_id,
        }};
        self.emit(.{ .histogram = .{
            .service_name = self.service_name,
            .name = name,
            .unit = "ms",
            .count = 1,
            .sum = @floatFromInt(duration_millis),
            .bucket_counts = &bucket_counts,
            .explicit_bounds = &bounds,
            .min = @floatFromInt(duration_millis),
            .max = @floatFromInt(duration_millis),
            .time_unix_nanos = time_unix_nanos,
            .attributes = &attributes,
            .exemplars = &exemplars,
        } });
    }

    fn emit(self: *OtlpTelemetry, record: TelemetryRecord) void {
        self.sink.emit_fn(self.sink.pointer, record) catch self.recordFailure();
    }

    fn recordFailure(self: *OtlpTelemetry) void {
        _ = self.export_failures.fetchAdd(1, .monotonic);
    }
};

fn telemetryInt(value: anytype) i64 {
    return std.math.cast(i64, value) orelse std.math.maxInt(i64);
}

pub const Outcome = struct {
    code: Grpc.Code,
    duration_millis: u64,
    request_messages: usize = 1,
    response_messages: usize = 1,
    end_time_unix_nanos: u64 = 0,
};

fn boundedRpcAttribute(value: []const u8) []const u8 {
    if (value.len == 0 or value.len > 256) return "other";
    for (value) |byte| if (!(std.ascii.isAlphanumeric(byte) or byte == '.' or byte == '_' or byte == '-')) return "other";
    return value;
}

fn traceIdentifiers(context: *const CallContext, sequence: u64, trace_id: *[32]u8, parent_id: *[16]u8) void {
    if (context.traceparent.len == 55 and validTraceparent(context.traceparent)) {
        @memcpy(trace_id, context.traceparent[3..35]);
        @memcpy(parent_id, context.traceparent[36..52]);
        return;
    }
    var hash: [32]u8 = undefined;
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(context.service);
    hasher.update(context.method);
    hasher.update(std.mem.asBytes(&sequence));
    hasher.final(&hash);
    _ = std.fmt.bufPrint(trace_id, "{x}", .{hash[0..16]}) catch unreachable;
    _ = std.fmt.bufPrint(parent_id, "{x}", .{hash[16..24]}) catch unreachable;
}

fn spanIdentifier(trace_id: [32]u8, sequence: u64, span_id: *[16]u8) void {
    var hash: [32]u8 = undefined;
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(&trace_id);
    hasher.update(std.mem.asBytes(&sequence));
    hasher.final(&hash);
    _ = std.fmt.bufPrint(span_id, "{x}", .{hash[0..8]}) catch unreachable;
}

pub const Interceptor = struct {
    pointer: *anyopaque,
    before_fn: *const fn (*anyopaque, *CallContext) ?Grpc.Status,
    after_fn: *const fn (*anyopaque, *const CallContext, Outcome) void,

    pub fn from(comptime Target: type, target: *Target) Interceptor {
        return .{
            .pointer = target,
            .before_fn = struct {
                fn call(pointer: *anyopaque, context: *CallContext) ?Grpc.Status {
                    return (@as(*Target, @ptrCast(@alignCast(pointer)))).before(context);
                }
            }.call,
            .after_fn = struct {
                fn call(pointer: *anyopaque, context: *const CallContext, outcome: Outcome) void {
                    (@as(*Target, @ptrCast(@alignCast(pointer)))).after(context, outcome);
                }
            }.call,
        };
    }
};

pub const BeforeResult = struct {
    status: ?Grpc.Status,
    entered: usize,
};

pub fn runBefore(interceptors: []const Interceptor, context: *CallContext) BeforeResult {
    for (interceptors, 0..) |interceptor, index| if (interceptor.before_fn(interceptor.pointer, context)) |denied| {
        return .{ .status = denied, .entered = index };
    };
    return .{ .status = null, .entered = interceptors.len };
}

pub fn before(interceptors: []const Interceptor, context: *CallContext) ?Grpc.Status {
    return runBefore(interceptors, context).status;
}

pub fn after(interceptors: []const Interceptor, context: *const CallContext, outcome: Outcome) void {
    afterEntered(interceptors, interceptors.len, context, outcome);
}

pub fn afterEntered(interceptors: []const Interceptor, entered: usize, context: *const CallContext, outcome: Outcome) void {
    var index = entered;
    while (index != 0) {
        index -= 1;
        const interceptor = interceptors[index];
        interceptor.after_fn(interceptor.pointer, context, outcome);
    }
}

pub const TokenVerifier = struct {
    pointer: *anyopaque,
    verify_fn: *const fn (*anyopaque, []const u8) bool,

    pub fn from(comptime Target: type, target: *Target) TokenVerifier {
        return .{
            .pointer = target,
            .verify_fn = struct {
                fn call(pointer: *anyopaque, token: []const u8) bool {
                    return (@as(*Target, @ptrCast(@alignCast(pointer)))).verify(token);
                }
            }.call,
        };
    }

    pub fn verify(self: TokenVerifier, token: []const u8) bool {
        return self.verify_fn(self.pointer, token);
    }
};

pub const BearerAuth = struct {
    verifier: TokenVerifier,

    pub fn init(verifier: TokenVerifier) BearerAuth {
        return .{ .verifier = verifier };
    }

    pub fn interceptor(self: *BearerAuth) Interceptor {
        return Interceptor.from(BearerAuth, self);
    }

    pub fn before(self: *BearerAuth, context: *CallContext) ?Grpc.Status {
        const prefix = "Bearer ";
        if (!std.mem.startsWith(u8, context.authorization, prefix)) return .{ .code = .unauthenticated, .message = "bearer token required" };
        const token = context.authorization[prefix.len..];
        if (token.len == 0 or !self.verifier.verify(token)) return .{ .code = .unauthenticated, .message = "bearer token rejected" };
        return null;
    }

    pub fn after(_: *BearerAuth, _: *const CallContext, _: Outcome) void {}
};

pub const AdmissionPolicy = struct {
    /// Empty service or method values are wildcards.
    service: []const u8 = "",
    method: []const u8 = "",
    max_in_flight: usize,
    requests_per_second: u32 = 0,
    burst: u32 = 0,

    pub fn validate(self: AdmissionPolicy) !void {
        if (self.max_in_flight == 0) return error.InvalidAdmissionPolicy;
        if ((self.requests_per_second == 0) != (self.burst == 0)) return error.InvalidAdmissionPolicy;
        if (self.service.len > 512 or self.method.len > 256) return error.InvalidAdmissionPolicy;
    }
};

const AdmissionState = struct {
    policy: AdmissionPolicy,
    in_flight: usize = 0,
    tokens_milli: u64,
    last_refill_millis: u64,
};

/// Bounded, method-aware concurrency and token-bucket admission interceptor.
/// Policies are evaluated in declaration order, allowing exact policies to be
/// placed before service-wide and global fallbacks.
pub const AdmissionControl = struct {
    allocator: std.mem.Allocator,
    clock: TimestampSource,
    states: []AdmissionState,
    mutex: std.atomic.Mutex = .unlocked,

    pub fn initAlloc(allocator: std.mem.Allocator, clock: TimestampSource, policies: []const AdmissionPolicy) !AdmissionControl {
        if (policies.len == 0 or policies.len > 1024) return error.InvalidAdmissionPolicy;
        const states = try allocator.alloc(AdmissionState, policies.len);
        errdefer allocator.free(states);
        const now = clock.now_fn(clock.pointer);
        for (policies, 0..) |policy, index| {
            try policy.validate();
            states[index] = .{
                .policy = policy,
                .tokens_milli = std.math.mul(u64, policy.burst, 1000) catch return error.InvalidAdmissionPolicy,
                .last_refill_millis = now,
            };
        }
        return .{ .allocator = allocator, .clock = clock, .states = states };
    }

    pub fn deinit(self: *AdmissionControl) void {
        self.allocator.free(self.states);
        self.* = undefined;
    }

    pub fn interceptor(self: *AdmissionControl) Interceptor {
        return Interceptor.from(AdmissionControl, self);
    }

    pub fn before(self: *AdmissionControl, context: *CallContext) ?Grpc.Status {
        self.lock();
        defer self.mutex.unlock();
        const state = self.find(context) orelse return null;
        if (state.in_flight >= state.policy.max_in_flight) return .{
            .code = .resource_exhausted,
            .message = "method concurrency limit exceeded",
        };
        if (state.policy.requests_per_second != 0) {
            const now = self.clock.now_fn(self.clock.pointer);
            if (now > state.last_refill_millis) {
                const elapsed = now - state.last_refill_millis;
                const added = std.math.mul(u64, elapsed, state.policy.requests_per_second) catch std.math.maxInt(u64);
                const capacity = @as(u64, state.policy.burst) * 1000;
                state.tokens_milli = @min(capacity, state.tokens_milli +| added);
                state.last_refill_millis = now;
            }
            if (state.tokens_milli < 1000) return .{
                .code = .resource_exhausted,
                .message = "method rate limit exceeded",
            };
            state.tokens_milli -= 1000;
        }
        state.in_flight += 1;
        return null;
    }

    pub fn after(self: *AdmissionControl, context: *const CallContext, _: Outcome) void {
        self.lock();
        defer self.mutex.unlock();
        const state = self.find(context) orelse return;
        std.debug.assert(state.in_flight != 0);
        state.in_flight -= 1;
    }

    fn find(self: *AdmissionControl, context: *const CallContext) ?*AdmissionState {
        for (self.states) |*state| {
            if (state.policy.service.len != 0 and !std.mem.eql(u8, state.policy.service, context.service)) continue;
            if (state.policy.method.len != 0 and !std.mem.eql(u8, state.policy.method, context.method)) continue;
            return state;
        }
        return null;
    }

    fn lock(self: *AdmissionControl) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
    }
};

pub const TelemetrySnapshot = struct {
    started: usize,
    completed: usize,
    failed: usize,
    in_flight: usize,
    duration_millis: u64,
};

pub const Telemetry = struct {
    mutex: std.atomic.Mutex = .unlocked,
    started: usize = 0,
    completed: usize = 0,
    failed: usize = 0,
    in_flight: usize = 0,
    duration_millis: u64 = 0,

    pub fn interceptor(self: *Telemetry) Interceptor {
        return Interceptor.from(Telemetry, self);
    }

    pub fn before(self: *Telemetry, _: *CallContext) ?Grpc.Status {
        self.lock();
        defer self.mutex.unlock();
        self.started += 1;
        self.in_flight += 1;
        return null;
    }

    pub fn after(self: *Telemetry, _: *const CallContext, outcome: Outcome) void {
        self.lock();
        defer self.mutex.unlock();
        self.completed += 1;
        self.in_flight -= 1;
        self.duration_millis += outcome.duration_millis;
        if (outcome.code != .ok) self.failed += 1;
    }

    pub fn snapshot(self: *Telemetry) TelemetrySnapshot {
        self.lock();
        defer self.mutex.unlock();
        return .{
            .started = self.started,
            .completed = self.completed,
            .failed = self.failed,
            .in_flight = self.in_flight,
            .duration_millis = self.duration_millis,
        };
    }

    fn lock(self: *Telemetry) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
    }
};

pub fn validTraceparent(value: []const u8) bool {
    _ = zstd.fx.parseTraceParent(value) catch return false;
    return true;
}

pub fn validTracestate(value: []const u8) bool {
    if (value.len == 0 or value.len > 512) return false;
    var members = std.mem.splitScalar(u8, value, ',');
    var count: usize = 0;
    while (members.next()) |raw| {
        count += 1;
        if (count > 32) return false;
        const member = std.mem.trim(u8, raw, " \t");
        const equals = std.mem.indexOfScalar(u8, member, '=') orelse return false;
        if (equals == 0 or equals + 1 == member.len) return false;
        for (member) |byte| if (byte < 0x20 or byte > 0x7e or byte == ',') return false;
    }
    return true;
}

pub fn validBaggage(value: []const u8) bool {
    if (value.len == 0 or value.len > 8192) return false;
    var members = std.mem.splitScalar(u8, value, ',');
    var count: usize = 0;
    while (members.next()) |raw| {
        count += 1;
        if (count > 64) return false;
        const member = std.mem.trim(u8, raw, " \t");
        const equals = std.mem.indexOfScalar(u8, member, '=') orelse return false;
        if (equals == 0 or equals + 1 == member.len) return false;
        for (member) |byte| if (byte < 0x20 or byte > 0x7e) return false;
    }
    return true;
}

test "W3C trace context extensions are bounded and syntactically validated" {
    try std.testing.expect(validTraceparent("00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"));
    try std.testing.expect(validTracestate("vendor=value,other=opaque"));
    try std.testing.expect(!validTracestate("missing-value"));
    try std.testing.expect(validBaggage("tenant=public,region=europe-west1"));
    try std.testing.expect(!validBaggage("secret-without-value"));
}

test "causal facts cover every production RPC boundary without payloads" {
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var facts = CausalFacts{ .recorder = .fromStore(&store), .service_key = "orders-api" };
    inline for (std.meta.tags(CausalBoundary)) |boundary| {
        facts.emit(boundary, "succeeded", "orders.v1.Orders", "List");
    }
    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(std.meta.tags(CausalBoundary).len, snapshot.events.len);
    for (snapshot.events) |event| {
        try std.testing.expectEqualStrings("GrpcBoundaryFact", event.type_name);
        try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "authorization") == null);
        try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "payload") == null);
    }
}

test "causal RPC facts correlate request and W3C trace context without retaining headers" {
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var facts = CausalFacts{ .recorder = .fromStore(&store), .service_key = "orders-api" };
    const context = CallContext{
        .protocol = .connect,
        .authority = "api.example.test",
        .service = "orders.v1.Orders",
        .method = "List",
        .shape = .unary,
        .request_id = "request-42",
        .traceparent = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
    };
    facts.emitCall(.handler, "started", &context);
    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expectEqual(std.hash.Wyhash.hash(0, context.request_id), snapshot.events[0].boundary_id.?);
    try std.testing.expectEqual(@as(u64, 0xa3ce929d0e0e4736), snapshot.events[0].trace_id.?);
    try std.testing.expectEqual(@as(u64, 0x00f067aa0ba902b7), snapshot.events[0].span_id.?);
    try std.testing.expectEqual(@as(?u64, 0x4bf92f3577b34da6), snapshot.events[0].context.trace_id_high);
    try std.testing.expectEqual(@as(?u64, 0xa3ce929d0e0e4736), snapshot.events[0].context.trace_id_low);
    try std.testing.expect(std.mem.indexOf(u8, snapshot.events[0].redacted_detail, context.request_id) == null);
    try std.testing.expect(std.mem.indexOf(u8, snapshot.events[0].redacted_detail, context.traceparent) == null);
}

test "gRPC boundary facts persist through the canonical application runtime" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const layer = zstd.fx.kernel.Layer.empty();
    var runtime = try zstd.ManagedRuntime(@TypeOf(layer)).make(
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        layer,
        .{},
    );
    defer runtime.deinit();

    var facts = CausalFacts{ .recorder = runtime.causalRecorder(), .service_key = "orders-api" };
    facts.emit(.handler, "succeeded", "orders.v1.Orders", "List");
    const summary = runtime.graphSummary();
    try std.testing.expect(summary.records > 0);
    const record = try runtime.graphRecordJsonAlloc(std.testing.allocator, summary.newest_durable_event_id.?);
    defer std.testing.allocator.free(record);
    try std.testing.expect(std.mem.indexOf(u8, record, "GrpcBoundaryFact") != null);
    try runtime.shutdown();
}

test "bearer policy never exposes credentials in telemetry" {
    var telemetry = Telemetry{};
    var context = CallContext{
        .protocol = .grpc,
        .authority = "internal",
        .service = "service",
        .method = "method",
        .shape = .unary,
        .authorization = "Bearer secret",
    };
    _ = telemetry.before(&context);
    telemetry.after(&context, .{ .code = .unauthenticated, .duration_millis = 1 });
    const snapshot = telemetry.snapshot();
    try std.testing.expectEqual(@as(usize, 1), snapshot.failed);
}

test "client interceptors append metadata and observe completion in reverse order" {
    const Downstream = struct {
        const Self = @This();
        saw_authorization: bool = false,
        fn invoke(self: *@This(), allocator: std.mem.Allocator, request: Grpc.UnaryRequest, _: Grpc.CallOptions) anyerror!Grpc.UnaryResponse {
            for (request.metadata) |entry| if (std.mem.eql(u8, entry.name, "authorization") and std.mem.eql(u8, entry.value, "Bearer id-token")) {
                self.saw_authorization = true;
            };
            return Grpc.UnaryResponse.initAlloc(allocator, request.payload, .ok());
        }
        fn client(self: *@This()) Grpc.Client {
            return .{ .ptr = self, .invoke_fn = struct {
                fn call(pointer: *anyopaque, allocator: std.mem.Allocator, request: Grpc.UnaryRequest, options: Grpc.CallOptions) anyerror!Grpc.UnaryResponse {
                    return (@as(*Self, @ptrCast(@alignCast(pointer)))).invoke(allocator, request, options);
                }
            }.call };
        }
    };
    const Observer = struct {
        completed: usize = 0,
        fn beforeClient(_: *@This(), _: *ClientCallContext) ?Grpc.Status {
            return null;
        }
        fn afterClient(self: *@This(), _: *const ClientCallContext, outcome: ClientOutcome) void {
            if (outcome.code == .ok and !outcome.transport_failed) self.completed += 1;
        }
    };
    const metadata = [_]Grpc.Metadata{.{ .name = "authorization", .value = "Bearer id-token", .sensitive = true }};
    var append = AppendClientMetadata{ .metadata = &metadata };
    var observer = Observer{};
    var downstream = Downstream{};
    const interceptors = [_]ClientInterceptor{ append.interceptor(), ClientInterceptor.from(Observer, &observer) };
    var intercepted = InterceptedClient{ .downstream = downstream.client(), .interceptors = &interceptors };
    var response = try intercepted.invokeAlloc(std.testing.allocator, .{
        .authority = "orders.run.app",
        .service = "orders.v1.Orders",
        .method = "List",
        .payload = "request",
        .timeout_millis = 1_000,
    }, .{});
    defer response.deinit();
    try std.testing.expect(downstream.saw_authorization);
    try std.testing.expectEqual(@as(usize, 1), observer.completed);

    const StreamingDownstream = struct {
        saw_authorization: bool = false,
        fn invokeStreamingAlloc(self: *@This(), allocator: std.mem.Allocator, request: Grpc.StreamingRequest, _: Grpc.CallOptions) !Grpc.StreamingResponse {
            for (request.metadata) |entry| if (std.mem.eql(u8, entry.name, "authorization") and std.mem.eql(u8, entry.value, "Bearer id-token")) {
                self.saw_authorization = true;
            };
            return Grpc.StreamingResponse.initAlloc(allocator, request.messages, .ok());
        }
    };
    var streaming_downstream = StreamingDownstream{};
    var intercepted_streaming = InterceptedStreamingClient{
        .downstream = StreamingClient.from(StreamingDownstream, &streaming_downstream),
        .interceptors = &interceptors,
    };
    var streaming_response = try intercepted_streaming.invokeStreamingAlloc(std.testing.allocator, .{
        .authority = "orders.run.app",
        .service = "orders.v1.Orders",
        .method = "Watch",
        .messages = &.{"request"},
        .timeout_millis = 1_000,
        .shape = .server_streaming,
    }, .{});
    defer streaming_response.deinit();
    try std.testing.expect(streaming_downstream.saw_authorization);
    try std.testing.expectEqual(@as(usize, 2), observer.completed);
}

test "method admission enforces concurrency and deterministic token refill" {
    const Clock = struct {
        now: u64 = 0,
        fn nowMillis(self: *@This()) u64 {
            return self.now;
        }
    };
    var clock = Clock{};
    const policies = [_]AdmissionPolicy{.{
        .service = "orders.v1.Orders",
        .method = "Get",
        .max_in_flight = 1,
        .requests_per_second = 2,
        .burst = 1,
    }};
    var admission = try AdmissionControl.initAlloc(std.testing.allocator, TimestampSource.from(Clock, &clock), &policies);
    defer admission.deinit();
    var context = CallContext{
        .protocol = .grpc,
        .authority = "local",
        .service = "orders.v1.Orders",
        .method = "Get",
        .shape = .unary,
    };
    try std.testing.expect(admission.before(&context) == null);
    try std.testing.expectEqual(Grpc.Code.resource_exhausted, admission.before(&context).?.code);
    admission.after(&context, .{ .code = .ok, .duration_millis = 1 });
    try std.testing.expectEqual(Grpc.Code.resource_exhausted, admission.before(&context).?.code);
    clock.now = 500;
    try std.testing.expect(admission.before(&context) == null);
    admission.after(&context, .{ .code = .ok, .duration_millis = 1 });
}
