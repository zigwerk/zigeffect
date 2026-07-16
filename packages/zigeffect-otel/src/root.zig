const std = @import("std");
const zstd = @import("zigeffect_std");

test "OTLP exporter is exposed as a scoped ZigEffect layer" {
    var config_provider = zstd.Service.ValueProvider(ExporterLayerConfig).init(.{
        .io = std.testing.io,
        .options = .{ .host = "127.0.0.1", .port = 1, .retry_attempts = 0 },
    });
    const config_layer = config_provider.layer();
    const live_exporter_layer = exporterLayer();
    const Layers = @TypeOf(.{ config_layer, live_exporter_layer });
    const Env = zstd.fx.LayerGraphEnv(Layers);
    var causal_store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer causal_store.deinit();
    var app = zstd.fx.layerGraph(std.testing.allocator, .{ config_layer, live_exporter_layer })
        .withCausalStore(&causal_store);
    defer app.deinit();

    try app.run(shutdownExporterEffect(Env));
    var snapshot = try causal_store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(zstd.Service.hasOperation(snapshot, Exporter, "otel.exporter.shutdown", "success"));
}

const SSL_METHOD = opaque {};
const SSL_CTX = opaque {};
const SSL = opaque {};
extern fn TLS_client_method() ?*const SSL_METHOD;
extern fn TLS_server_method() ?*const SSL_METHOD;
extern fn SSL_CTX_new(method: *const SSL_METHOD) ?*SSL_CTX;
extern fn SSL_CTX_free(context: *SSL_CTX) void;
extern fn SSL_CTX_ctrl(context: *SSL_CTX, command: c_int, larg: c_long, parg: ?*anyopaque) c_long;
extern fn SSL_CTX_use_certificate_chain_file(context: *SSL_CTX, path: [*:0]const u8) c_int;
extern fn SSL_CTX_use_PrivateKey_file(context: *SSL_CTX, path: [*:0]const u8, file_type: c_int) c_int;
extern fn SSL_CTX_check_private_key(context: *const SSL_CTX) c_int;
extern fn SSL_CTX_load_verify_locations(context: *SSL_CTX, ca_file: ?[*:0]const u8, ca_path: ?[*:0]const u8) c_int;
extern fn SSL_CTX_set_default_verify_paths(context: *SSL_CTX) c_int;
const VerifyCallback = ?*const fn (c_int, ?*anyopaque) callconv(.c) c_int;
extern fn SSL_CTX_set_verify(context: *SSL_CTX, mode: c_int, callback: VerifyCallback) void;
extern fn SSL_new(context: *SSL_CTX) ?*SSL;
extern fn SSL_free(ssl: *SSL) void;
extern fn SSL_set_fd(ssl: *SSL, fd: c_int) c_int;
extern fn SSL_ctrl(ssl: *SSL, command: c_int, larg: c_long, parg: ?*anyopaque) c_long;
extern fn SSL_set1_host(ssl: *SSL, hostname: [*:0]const u8) c_int;
extern fn SSL_connect(ssl: *SSL) c_int;
extern fn SSL_accept(ssl: *SSL) c_int;
extern fn SSL_read(ssl: *SSL, buffer: *anyopaque, length: c_int) c_int;
extern fn SSL_write(ssl: *SSL, buffer: *const anyopaque, length: c_int) c_int;
extern fn SSL_shutdown(ssl: *SSL) c_int;
extern fn SSL_get_error(ssl: *const SSL, result: c_int) c_int;
extern fn SSL_get_verify_result(ssl: *const SSL) c_long;

const ssl_verify_peer: c_int = 1;
const ssl_filetype_pem = 1;
const ssl_ctrl_set_min_proto_version = 123;
const ssl_ctrl_set_max_proto_version = 124;
const ssl_ctrl_set_tlsext_hostname = 55;
const tls_1_2_version = 0x0303;
const tls_1_3_version = 0x0304;
const ssl_error_want_read = 2;
const ssl_error_want_write = 3;
const ssl_error_zero_return = 6;
const x509_v_ok = 0;

pub const capability = zstd.Capability.Descriptor{
    .id = "zigeffect-otel.otlp-http-json",
    .kind = .telemetry,
    .maturity = .production_candidate,
    .package = "zigeffect-otel",
    .version = "0.1.0",
    .features = &.{ "otlp-http-json", "logs", "metrics", "traces", "bounded-queue", "retry", "flush", "w3c-trace-context" },
    .side_effects = .real,
    .conformance = .{ .schema = "zigeffect.otlp-live-conformance", .version = 1, .receipt = "conformance/otlp-http-live.v1.json", .authority = .live_external, .observed_at_ms = 1783777336000, .valid_until_ms = 1791553336000, .content_sha256 = "sha256:ca7db537af861210ae00800d0fc08ef1f03e0413c94ec76aefc5e1e4e31b2192" },
    .limitations = &.{ "the checked-in live receipt covers plaintext collector mode; direct TLS is described separately by secure_capability", "OTLP/gRPC is not implemented" },
};

/// Direct, peer-verified OTLP/HTTP export. This capability is deliberately
/// separate because its live TLS test is local until an external collector
/// qualification receipt is checked in.
pub const secure_capability = zstd.Capability.Descriptor{
    .id = "zigeffect-otel.otlp-http-json-secure",
    .kind = .telemetry,
    .maturity = .local_development,
    .package = "zigeffect-otel",
    .version = "0.1.0",
    .features = &.{ "otlp-http-json", "typed-records", "logs", "metrics", "traces", "bounded-queue", "retry", "flush", "w3c-trace-context", "tls1.2", "tls1.3", "hostname-verification", "platform-trust", "private-ca", "bounded-auth-headers", "bearer-auth" },
    .side_effects = .real,
    .limitations = &.{ "an external secure-collector receipt is not yet checked in", "OTLP/gRPC is not implemented" },
};

pub const Signal = enum {
    logs,
    metrics,
    traces,

    pub fn path(self: Signal) []const u8 {
        return switch (self) {
            .logs => "/v1/logs",
            .metrics => "/v1/metrics",
            .traces => "/v1/traces",
        };
    }
    fn rootField(self: Signal) []const u8 {
        return switch (self) {
            .logs => "resourceLogs",
            .metrics => "resourceMetrics",
            .traces => "resourceSpans",
        };
    }
};
pub const Batch = struct { signal: Signal, payload: []const u8 };

pub const AttributeValue = union(enum) {
    string: []const u8,
    int: i64,
};

pub const Attribute = struct {
    key: []const u8,
    value: AttributeValue,
};

pub const MetricRecord = struct {
    service_name: []const u8,
    scope: []const u8 = "zigeffect",
    name: []const u8,
    unit: []const u8 = "1",
    value: i64,
    time_unix_nanos: u64 = 0,
    attributes: []const Attribute = &.{},
};

pub const Exemplar = struct {
    time_unix_nanos: u64,
    value: f64,
    trace_id: []const u8,
    span_id: []const u8,
    filtered_attributes: []const Attribute = &.{},
};

pub const HistogramRecord = struct {
    service_name: []const u8,
    scope: []const u8 = "zigeffect",
    name: []const u8,
    unit: []const u8 = "1",
    count: u64,
    sum: f64,
    bucket_counts: []const u64,
    explicit_bounds: []const f64,
    min: ?f64 = null,
    max: ?f64 = null,
    time_unix_nanos: u64 = 0,
    attributes: []const Attribute = &.{},
    exemplars: []const Exemplar = &.{},
};

pub const SpanLink = struct {
    trace_id: []const u8,
    span_id: []const u8,
    tracestate: []const u8 = "",
    attributes: []const Attribute = &.{},
};

pub const SpanRecord = struct {
    service_name: []const u8,
    scope: []const u8 = "zigeffect",
    trace_id: []const u8,
    span_id: []const u8,
    parent_span_id: []const u8 = "",
    name: []const u8,
    start_time_unix_nanos: u64,
    end_time_unix_nanos: u64,
    status_error: bool = false,
    attributes: []const Attribute = &.{},
    links: []const SpanLink = &.{},
};

pub const LogRecord = struct {
    service_name: []const u8,
    scope: []const u8 = "zigeffect",
    time_unix_nanos: u64,
    severity_number: u8 = 9,
    severity_text: []const u8 = "INFO",
    body: []const u8,
    attributes: []const Attribute = &.{},
};

pub fn batchStreamAlloc(allocator: std.mem.Allocator, batches: []const Batch) !zstd.fx.EffectStream(Batch, anyerror, zstd.Stream.EmptyEnv) {
    const Owned = struct { signal: Signal, payload: []u8 };
    const Puller = struct {
        allocator: std.mem.Allocator,
        batches: []Owned,
        offset: usize = 0,
        pub fn pull(self: *@This(), _: *zstd.fx.Context(zstd.Stream.EmptyEnv), output_allocator: std.mem.Allocator, max: usize) anyerror!zstd.fx.EffectStream(Batch, anyerror, zstd.Stream.EmptyEnv).Chunk {
            const count = @min(max, self.batches.len - self.offset);
            const output = try output_allocator.alloc(Batch, count);
            for (self.batches[self.offset .. self.offset + count], 0..) |item, index| output[index] = .{ .signal = item.signal, .payload = item.payload };
            self.offset += count;
            return .{ .allocator = output_allocator, .items = output, .end = self.offset == self.batches.len };
        }
        pub fn close(_: *@This(), _: zstd.fx.StreamCloseReason) void {}
        pub fn deinit(self: *@This()) void {
            for (self.batches) |item| self.allocator.free(item.payload);
            self.allocator.free(self.batches);
        }
    };
    const owned = try allocator.alloc(Owned, batches.len);
    errdefer allocator.free(owned);
    var initialized: usize = 0;
    errdefer for (owned[0..initialized]) |item| allocator.free(item.payload);
    for (batches, 0..) |batch, index| {
        owned[index] = .{ .signal = batch.signal, .payload = try allocator.dupe(u8, batch.payload) };
        initialized += 1;
    }
    return zstd.fx.effectStreamFromOwnedPullerAlloc(Batch, anyerror, zstd.Stream.EmptyEnv, Puller, allocator, .{ .allocator = allocator, .batches = owned });
}

pub const TraceContext = struct {
    version: u8 = 0,
    trace_id: [16]u8,
    parent_id: [8]u8,
    flags: u8,
    tracestate: ?[]const u8 = null,

    pub fn sampled(self: TraceContext) bool {
        return self.flags & 1 == 1;
    }

    pub fn parse(traceparent: []const u8, tracestate: ?[]const u8) !TraceContext {
        if (traceparent.len != 55 or traceparent[2] != '-' or traceparent[35] != '-' or traceparent[52] != '-') return error.InvalidTraceparent;
        const version = try parseHexByte(traceparent[0..2]);
        if (version == 0xff or (version == 0 and traceparent.len != 55)) return error.InvalidTraceparent;
        var trace_id: [16]u8 = undefined;
        var parent_id: [8]u8 = undefined;
        try parseHex(traceparent[3..35], &trace_id);
        try parseHex(traceparent[36..52], &parent_id);
        if (allZero(&trace_id) or allZero(&parent_id)) return error.InvalidTraceparent;
        if (tracestate) |state| try validateTracestate(state);
        return .{ .version = version, .trace_id = trace_id, .parent_id = parent_id, .flags = try parseHexByte(traceparent[53..55]), .tracestate = tracestate };
    }

    pub fn format(self: TraceContext, buffer: *[55]u8) []const u8 {
        _ = std.fmt.bufPrint(buffer, "{x:0>2}-{x:0>32}-{x:0>16}-{x:0>2}", .{
            self.version,
            std.mem.readInt(u128, &self.trace_id, .big),
            std.mem.readInt(u64, &self.parent_id, .big),
            self.flags,
        }) catch unreachable;
        return buffer;
    }
};

fn parseHex(source: []const u8, output: []u8) !void {
    if (source.len != output.len * 2) return error.InvalidTraceparent;
    for (output, 0..) |*byte, index| byte.* = try parseHexByte(source[index * 2 .. index * 2 + 2]);
}
fn parseHexByte(source: []const u8) !u8 {
    return std.fmt.parseUnsigned(u8, source, 16) catch error.InvalidTraceparent;
}
fn allZero(bytes: []const u8) bool {
    for (bytes) |byte| if (byte != 0) return false;
    return true;
}

fn validateTracestate(value: []const u8) !void {
    if (value.len == 0 or value.len > 512) return error.InvalidTracestate;
    var members = std.mem.splitScalar(u8, value, ',');
    var count: usize = 0;
    while (members.next()) |raw| {
        count += 1;
        if (count > 32) return error.InvalidTracestate;
        const member = std.mem.trim(u8, raw, " \t");
        const equals = std.mem.indexOfScalar(u8, member, '=') orelse return error.InvalidTracestate;
        if (equals == 0 or equals + 1 == member.len) return error.InvalidTracestate;
        for (member) |byte| if (byte < 0x20 or byte > 0x7e or byte == ',') return error.InvalidTracestate;
    }
}

pub const Backpressure = enum { reject_new, drop_oldest };
pub const Temporality = enum { cumulative };
pub const HistogramPolicy = struct { explicit_bounds: []const f64 = &.{ 5, 10, 25, 50, 100, 250, 500, 1000 } };
pub const AttributePolicy = struct { max_attributes_per_record: usize = 32, max_distinct_values_per_key: usize = 1000, max_value_bytes: usize = 4096 };
pub const Header = struct { name: []const u8, value: []const u8 };
pub const TlsOptions = struct {
    /// SNI and RFC 6125 hostname verification name. This must be NUL
    /// terminated because OpenSSL retains it during the handshake.
    server_name: [:0]const u8,
    /// Optional private CA bundle. Null uses the platform trust store.
    ca_file: ?[:0]const u8 = null,

    pub fn validate(self: TlsOptions) !void {
        if (self.server_name.len == 0 or self.server_name.len > 253) return error.InvalidTlsOptions;
        if (std.mem.indexOfScalar(u8, self.server_name, 0) != null) return error.InvalidTlsOptions;
        if (self.ca_file) |path| if (path.len == 0 or path.len > 4096 or std.mem.indexOfScalar(u8, path, 0) != null) return error.InvalidTlsOptions;
    }
};

pub const Options = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 4318,
    max_queue_items: usize = 512,
    max_payload_bytes: usize = 1024 * 1024,
    request_deadline_ms: u64 = 5000,
    shutdown_deadline_ms: u64 = 10_000,
    retry_attempts: usize = 3,
    retry_base_ms: u64 = 25,
    backpressure: Backpressure = .reject_new,
    temporality: Temporality = .cumulative,
    histogram: HistogramPolicy = .{},
    attributes: AttributePolicy = .{},
    /// Null is intended only for an explicitly trusted same-node collector.
    /// Set TLS for direct production export.
    tls: ?TlsOptions = null,
    headers: []const Header = &.{},
    bearer_token: ?[]const u8 = null,

    pub fn validate(self: Options) !void {
        if (self.host.len == 0 or self.port == 0 or self.max_queue_items == 0 or self.max_payload_bytes == 0 or self.request_deadline_ms == 0 or self.shutdown_deadline_ms == 0 or self.retry_base_ms == 0) return error.InvalidExporterOptions;
        if (self.attributes.max_attributes_per_record == 0 or self.attributes.max_distinct_values_per_key == 0 or self.attributes.max_value_bytes == 0) return error.InvalidExporterOptions;
        if (self.tls) |tls| try tls.validate();
        if (self.headers.len > 32) return error.InvalidExporterHeader;
        for (self.headers) |header| try validateHeader(header);
        if (self.bearer_token) |token| {
            if (token.len == 0 or token.len > 8192 or containsControl(token)) return error.InvalidBearerToken;
        }
    }
};

fn validateHeader(header: Header) !void {
    if (header.name.len == 0 or header.name.len > 128 or header.value.len > 4096 or containsControl(header.value)) return error.InvalidExporterHeader;
    for (header.name) |byte| if (!isHeaderNameByte(byte)) return error.InvalidExporterHeader;
    if (std.ascii.eqlIgnoreCase(header.name, "authorization") or std.ascii.eqlIgnoreCase(header.name, "content-length") or std.ascii.eqlIgnoreCase(header.name, "host") or std.ascii.eqlIgnoreCase(header.name, "connection")) return error.ReservedExporterHeader;
}

fn containsControl(value: []const u8) bool {
    for (value) |byte| if (byte < 0x20 or byte == 0x7f) return true;
    return false;
}

fn isHeaderNameByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or std.mem.indexOfScalar(u8, "!#$%&'*+-.^_`|~", byte) != null;
}

const Item = struct { signal: Signal, payload: []u8 };
pub const Snapshot = struct { queued: usize, accepted: usize, exported: usize, dropped: usize, failures: usize, retries: usize, shutting_down: bool };

pub const Exporter = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    options: Options,
    queue: std.ArrayList(Item) = .empty,
    mutex: std.atomic.Mutex = .unlocked,
    accepted: usize = 0,
    exported: usize = 0,
    dropped: usize = 0,
    failures: usize = 0,
    retries: usize = 0,
    shutting_down: bool = false,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, options: Options) !Exporter {
        try options.validate();
        return .{ .allocator = allocator, .io = io, .options = options };
    }
    pub fn deinit(self: *Exporter) void {
        self.lock();
        defer self.mutex.unlock();
        for (self.queue.items) |item| self.allocator.free(item.payload);
        self.queue.deinit(self.allocator);
    }

    pub fn enqueue(self: *Exporter, signal: Signal, payload: []const u8) !void {
        if (payload.len == 0 or payload.len > self.options.max_payload_bytes) return error.TelemetryPayloadTooLarge;
        if (zstd.Secrets.containsSecret(payload)) return error.SecretMaterialRejected;
        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, payload, .{}) catch return error.InvalidOtlpJson;
        defer parsed.deinit();
        if (parsed.value != .object or parsed.value.object.get(signal.rootField()) == null) return error.InvalidOtlpJson;
        const owned = try self.allocator.dupe(u8, payload);
        errdefer self.allocator.free(owned);
        self.lock();
        defer self.mutex.unlock();
        if (self.shutting_down) return error.ExporterShuttingDown;
        if (self.queue.items.len == self.options.max_queue_items) switch (self.options.backpressure) {
            .reject_new => {
                self.dropped += 1;
                return error.TelemetryBackpressure;
            },
            .drop_oldest => {
                const old = self.queue.orderedRemove(0);
                self.allocator.free(old.payload);
                self.dropped += 1;
            },
        };
        try self.queue.append(self.allocator, .{ .signal = signal, .payload = owned });
        self.accepted += 1;
    }

    pub fn enqueueMetric(self: *Exporter, record: MetricRecord) !void {
        const payload = try encodeMetricAlloc(self.allocator, record, self.options.attributes);
        defer self.allocator.free(payload);
        try self.enqueue(.metrics, payload);
    }

    pub fn enqueueHistogram(self: *Exporter, record: HistogramRecord) !void {
        const payload = try encodeHistogramAlloc(self.allocator, record, self.options.attributes);
        defer self.allocator.free(payload);
        try self.enqueue(.metrics, payload);
    }

    pub fn enqueueSpan(self: *Exporter, record: SpanRecord) !void {
        const payload = try encodeSpanAlloc(self.allocator, record, self.options.attributes);
        defer self.allocator.free(payload);
        try self.enqueue(.traces, payload);
    }

    pub fn enqueueLog(self: *Exporter, record: LogRecord) !void {
        const payload = try encodeLogAlloc(self.allocator, record, self.options.attributes);
        defer self.allocator.free(payload);
        try self.enqueue(.logs, payload);
    }

    pub fn flush(self: *Exporter) !void {
        while (true) {
            self.lock();
            if (self.queue.items.len == 0) {
                self.mutex.unlock();
                return;
            }
            const item = self.queue.orderedRemove(0);
            self.mutex.unlock();
            self.sendWithRetry(item) catch |err| {
                self.lock();
                self.failures += 1;
                self.queue.insert(self.allocator, 0, item) catch {
                    self.dropped += 1;
                    self.mutex.unlock();
                    self.allocator.free(item.payload);
                    return error.TelemetryBackpressure;
                };
                self.mutex.unlock();
                return err;
            };
            self.allocator.free(item.payload);
            self.lock();
            self.exported += 1;
            self.mutex.unlock();
        }
    }

    pub fn shutdown(self: *Exporter) !void {
        self.lock();
        self.shutting_down = true;
        self.mutex.unlock();
        const start = std.Io.Clock.Timestamp.now(self.io, .awake);
        self.flush() catch |err| {
            if (elapsedMs(start, std.Io.Clock.Timestamp.now(self.io, .awake)) >= self.options.shutdown_deadline_ms) return error.TelemetryShutdownDeadlineExceeded;
            return err;
        };
    }

    pub fn snapshot(self: *Exporter) Snapshot {
        self.lock();
        defer self.mutex.unlock();
        return .{ .queued = self.queue.items.len, .accepted = self.accepted, .exported = self.exported, .dropped = self.dropped, .failures = self.failures, .retries = self.retries, .shutting_down = self.shutting_down };
    }

    fn sendWithRetry(self: *Exporter, item: Item) !void {
        var attempt: usize = 0;
        while (true) : (attempt += 1) {
            self.send(item) catch |err| {
                if (attempt >= self.options.retry_attempts or !retryable(err)) return err;
                self.lock();
                self.retries += 1;
                self.mutex.unlock();
                const shift: u6 = @intCast(@min(attempt, 10));
                try sleepMs(self.io, self.options.retry_base_ms << shift);
                continue;
            };
            return;
        }
    }

    const SendRace = union(enum) { request: anyerror!void, timeout: std.Io.Cancelable!void };

    fn send(self: *Exporter, item: Item) !void {
        var results: [2]SendRace = undefined;
        var select = std.Io.Select(SendRace).init(self.io, &results);
        select.async(.request, sendTask, .{ self, item });
        select.async(.timeout, deadlineTask, .{ self.io, self.options.request_deadline_ms });
        const first = select.await() catch |err| {
            select.cancelDiscard();
            return err;
        };
        switch (first) {
            .request => |result| {
                select.cancelDiscard();
                try result;
            },
            .timeout => |result| {
                try result;
                select.cancelDiscard();
                return error.TelemetryRequestDeadlineExceeded;
            },
        }
    }

    fn sendTask(self: *Exporter, item: Item) !void {
        return self.sendNow(item);
    }

    fn sendNow(self: *Exporter, item: Item) !void {
        const address = std.Io.net.IpAddress.resolve(self.io, self.options.host, self.options.port) catch return error.CollectorUnavailable;
        var stream = address.connect(self.io, .{ .mode = .stream }) catch return error.CollectorUnavailable;
        defer stream.close(self.io);
        const custom_headers = try exporterHeadersAlloc(self.allocator, self.options);
        defer self.allocator.free(custom_headers);
        const request = try std.fmt.allocPrint(self.allocator, "POST {s} HTTP/1.1\r\nHost: {s}:{d}\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nConnection: close\r\n{s}\r\n{s}", .{ item.signal.path(), self.options.host, self.options.port, item.payload.len, custom_headers, item.payload });
        defer self.allocator.free(request);
        var response: [4096]u8 = undefined;
        const count = if (self.options.tls) |tls| blk: {
            const context = try createClientTlsContext(tls);
            defer SSL_CTX_free(context);
            const ssl = SSL_new(context) orelse return error.TlsConnectionInitializationFailed;
            defer SSL_free(ssl);
            if (SSL_set_fd(ssl, stream.socket.handle) != 1) return error.TlsSocketBindingFailed;
            if (SSL_ctrl(ssl, ssl_ctrl_set_tlsext_hostname, 0, @ptrCast(@constCast(tls.server_name.ptr))) != 1) return error.TlsServerNameFailed;
            if (SSL_set1_host(ssl, tls.server_name.ptr) != 1) return error.TlsHostVerificationConfigurationFailed;
            if (SSL_connect(ssl) != 1) return error.TlsHandshakeFailed;
            if (SSL_get_verify_result(ssl) != x509_v_ok) return error.TlsPeerVerificationFailed;
            try tlsWriteAll(ssl, request);
            const received = try tlsRead(ssl, &response);
            _ = SSL_shutdown(ssl);
            break :blk received;
        } else blk: {
            try writeAll(stream, self.io, request);
            break :blk try streamRead(stream, self.io, &response);
        };
        if (count == 0) return error.CollectorUnavailable;
        try validateCollectorResponse(response[0..count]);
    }
    fn lock(self: *Exporter) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
    }
};

fn encodeMetricAlloc(allocator: std.mem.Allocator, record: MetricRecord, policy: AttributePolicy) ![]u8 {
    try validateRecordStrings(record.service_name, record.scope, record.name);
    try validateAttributes(record.attributes, policy);
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    const writer = &output.writer;
    try writer.writeAll("{\"resourceMetrics\":[{\"resource\":{\"attributes\":[");
    try writeAttribute(writer, .{ .key = "service.name", .value = .{ .string = record.service_name } });
    try writer.writeAll("]},\"scopeMetrics\":[{\"scope\":{\"name\":");
    try std.json.Stringify.value(record.scope, .{}, writer);
    try writer.writeAll("},\"metrics\":[{\"name\":");
    try std.json.Stringify.value(record.name, .{}, writer);
    try writer.writeAll(",\"unit\":");
    try std.json.Stringify.value(record.unit, .{}, writer);
    try writer.writeAll(",\"gauge\":{\"dataPoints\":[{\"asInt\":");
    var value_buffer: [32]u8 = undefined;
    try std.json.Stringify.value(try std.fmt.bufPrint(&value_buffer, "{d}", .{record.value}), .{}, writer);
    if (record.time_unix_nanos != 0) {
        try writer.writeAll(",\"timeUnixNano\":");
        var time_buffer: [32]u8 = undefined;
        try std.json.Stringify.value(try std.fmt.bufPrint(&time_buffer, "{d}", .{record.time_unix_nanos}), .{}, writer);
    }
    try writer.writeAll(",\"attributes\":[");
    try writeAttributes(writer, record.attributes);
    try writer.writeAll("]}]}}]}]}]}\n");
    return output.toOwnedSlice();
}

fn encodeHistogramAlloc(allocator: std.mem.Allocator, record: HistogramRecord, policy: AttributePolicy) ![]u8 {
    try validateRecordStrings(record.service_name, record.scope, record.name);
    try validateAttributes(record.attributes, policy);
    if (record.bucket_counts.len != record.explicit_bounds.len + 1 or !std.math.isFinite(record.sum)) return error.InvalidTelemetryRecord;
    var total: u64 = 0;
    for (record.bucket_counts) |count| total = std.math.add(u64, total, count) catch return error.InvalidTelemetryRecord;
    if (total != record.count) return error.InvalidTelemetryRecord;
    for (record.explicit_bounds, 0..) |bound, index| {
        if (!std.math.isFinite(bound) or (index != 0 and bound <= record.explicit_bounds[index - 1])) return error.InvalidTelemetryRecord;
    }
    if (record.min) |value| if (!std.math.isFinite(value)) return error.InvalidTelemetryRecord;
    if (record.max) |value| if (!std.math.isFinite(value)) return error.InvalidTelemetryRecord;
    if (record.min != null and record.max != null and record.min.? > record.max.?) return error.InvalidTelemetryRecord;
    if (record.exemplars.len > 16) return error.InvalidTelemetryRecord;
    for (record.exemplars) |exemplar| {
        try validateTelemetryIds(exemplar.trace_id, exemplar.span_id, "");
        if (!std.math.isFinite(exemplar.value)) return error.InvalidTelemetryRecord;
        try validateAttributes(exemplar.filtered_attributes, policy);
    }

    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    const writer = &output.writer;
    try writer.writeAll("{\"resourceMetrics\":[{\"resource\":{\"attributes\":[");
    try writeAttribute(writer, .{ .key = "service.name", .value = .{ .string = record.service_name } });
    try writer.writeAll("]},\"scopeMetrics\":[{\"scope\":{\"name\":");
    try std.json.Stringify.value(record.scope, .{}, writer);
    try writer.writeAll("},\"metrics\":[{\"name\":");
    try std.json.Stringify.value(record.name, .{}, writer);
    try writer.writeAll(",\"unit\":");
    try std.json.Stringify.value(record.unit, .{}, writer);
    try writer.writeAll(",\"histogram\":{\"aggregationTemporality\":2,\"dataPoints\":[{\"count\":");
    try writeJsonU64String(writer, record.count);
    try writer.writeAll(",\"sum\":");
    try writer.print("{d}", .{record.sum});
    if (record.time_unix_nanos != 0) {
        try writer.writeAll(",\"timeUnixNano\":");
        try writeJsonU64String(writer, record.time_unix_nanos);
    }
    if (record.min) |value| try writer.print(",\"min\":{d}", .{value});
    if (record.max) |value| try writer.print(",\"max\":{d}", .{value});
    try writer.writeAll(",\"bucketCounts\":[");
    for (record.bucket_counts, 0..) |count, index| {
        if (index != 0) try writer.writeByte(',');
        try writeJsonU64String(writer, count);
    }
    try writer.writeAll("],\"explicitBounds\":[");
    for (record.explicit_bounds, 0..) |bound, index| {
        if (index != 0) try writer.writeByte(',');
        try writer.print("{d}", .{bound});
    }
    try writer.writeAll("],\"attributes\":[");
    try writeAttributes(writer, record.attributes);
    try writer.writeAll("],\"exemplars\":[");
    for (record.exemplars, 0..) |exemplar, index| {
        if (index != 0) try writer.writeByte(',');
        try writer.writeAll("{\"timeUnixNano\":");
        try writeJsonU64String(writer, exemplar.time_unix_nanos);
        try writer.print(",\"asDouble\":{d},\"traceId\":", .{exemplar.value});
        try std.json.Stringify.value(exemplar.trace_id, .{}, writer);
        try writer.writeAll(",\"spanId\":");
        try std.json.Stringify.value(exemplar.span_id, .{}, writer);
        try writer.writeAll(",\"filteredAttributes\":[");
        try writeAttributes(writer, exemplar.filtered_attributes);
        try writer.writeAll("]}");
    }
    try writer.writeAll("]}]}}]}]}]}\n");
    return output.toOwnedSlice();
}

fn encodeSpanAlloc(allocator: std.mem.Allocator, record: SpanRecord, policy: AttributePolicy) ![]u8 {
    try validateRecordStrings(record.service_name, record.scope, record.name);
    try validateTelemetryIds(record.trace_id, record.span_id, record.parent_span_id);
    if (record.end_time_unix_nanos < record.start_time_unix_nanos) return error.InvalidTelemetryRecord;
    try validateAttributes(record.attributes, policy);
    if (record.links.len > 128) return error.InvalidTelemetryRecord;
    for (record.links) |link| {
        try validateTelemetryIds(link.trace_id, link.span_id, "");
        if (link.tracestate.len != 0) try validateTracestate(link.tracestate);
        try validateAttributes(link.attributes, policy);
    }
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    const writer = &output.writer;
    try writer.writeAll("{\"resourceSpans\":[{\"resource\":{\"attributes\":[");
    try writeAttribute(writer, .{ .key = "service.name", .value = .{ .string = record.service_name } });
    try writer.writeAll("]},\"scopeSpans\":[{\"scope\":{\"name\":");
    try std.json.Stringify.value(record.scope, .{}, writer);
    try writer.writeAll("},\"spans\":[{\"traceId\":");
    try std.json.Stringify.value(record.trace_id, .{}, writer);
    try writer.writeAll(",\"spanId\":");
    try std.json.Stringify.value(record.span_id, .{}, writer);
    if (record.parent_span_id.len != 0) {
        try writer.writeAll(",\"parentSpanId\":");
        try std.json.Stringify.value(record.parent_span_id, .{}, writer);
    }
    try writer.writeAll(",\"name\":");
    try std.json.Stringify.value(record.name, .{}, writer);
    try writer.writeAll(",\"kind\":2,\"startTimeUnixNano\":");
    var start_buffer: [32]u8 = undefined;
    try std.json.Stringify.value(try std.fmt.bufPrint(&start_buffer, "{d}", .{record.start_time_unix_nanos}), .{}, writer);
    try writer.writeAll(",\"endTimeUnixNano\":");
    var end_buffer: [32]u8 = undefined;
    try std.json.Stringify.value(try std.fmt.bufPrint(&end_buffer, "{d}", .{record.end_time_unix_nanos}), .{}, writer);
    try writer.writeAll(",\"attributes\":[");
    try writeAttributes(writer, record.attributes);
    try writer.writeAll("],\"links\":[");
    for (record.links, 0..) |link, index| {
        if (index != 0) try writer.writeByte(',');
        try writer.writeAll("{\"traceId\":");
        try std.json.Stringify.value(link.trace_id, .{}, writer);
        try writer.writeAll(",\"spanId\":");
        try std.json.Stringify.value(link.span_id, .{}, writer);
        if (link.tracestate.len != 0) {
            try writer.writeAll(",\"traceState\":");
            try std.json.Stringify.value(link.tracestate, .{}, writer);
        }
        try writer.writeAll(",\"attributes\":[");
        try writeAttributes(writer, link.attributes);
        try writer.writeAll("]}");
    }
    try writer.writeAll("],\"status\":{\"code\":");
    try writer.print("{d}", .{@as(u8, if (record.status_error) 2 else 1)});
    try writer.writeAll("}}]}]}]}\n");
    return output.toOwnedSlice();
}

fn encodeLogAlloc(allocator: std.mem.Allocator, record: LogRecord, policy: AttributePolicy) ![]u8 {
    try validateRecordStrings(record.service_name, record.scope, record.body);
    if (record.severity_number > 24) return error.InvalidTelemetryRecord;
    try validateAttributes(record.attributes, policy);
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    const writer = &output.writer;
    try writer.writeAll("{\"resourceLogs\":[{\"resource\":{\"attributes\":[");
    try writeAttribute(writer, .{ .key = "service.name", .value = .{ .string = record.service_name } });
    try writer.writeAll("]},\"scopeLogs\":[{\"scope\":{\"name\":");
    try std.json.Stringify.value(record.scope, .{}, writer);
    try writer.writeAll("},\"logRecords\":[{\"timeUnixNano\":");
    var time_buffer: [32]u8 = undefined;
    try std.json.Stringify.value(try std.fmt.bufPrint(&time_buffer, "{d}", .{record.time_unix_nanos}), .{}, writer);
    try writer.writeAll(",\"severityNumber\":");
    try writer.print("{d}", .{record.severity_number});
    try writer.writeAll(",\"severityText\":");
    try std.json.Stringify.value(record.severity_text, .{}, writer);
    try writer.writeAll(",\"body\":{\"stringValue\":");
    try std.json.Stringify.value(record.body, .{}, writer);
    try writer.writeAll("},\"attributes\":[");
    try writeAttributes(writer, record.attributes);
    try writer.writeAll("]}]}]}]}\n");
    return output.toOwnedSlice();
}

fn validateRecordStrings(service_name: []const u8, scope: []const u8, name: []const u8) !void {
    if (service_name.len == 0 or service_name.len > 256 or scope.len == 0 or scope.len > 256 or name.len == 0 or name.len > 1024) return error.InvalidTelemetryRecord;
    if (containsControl(service_name) or containsControl(scope) or containsControl(name)) return error.InvalidTelemetryRecord;
}

fn validateTelemetryIds(trace_id: []const u8, span_id: []const u8, parent_span_id: []const u8) !void {
    if (trace_id.len != 32 or span_id.len != 16 or (parent_span_id.len != 0 and parent_span_id.len != 16)) return error.InvalidTelemetryRecord;
    for (trace_id) |byte| if (!std.ascii.isHex(byte)) return error.InvalidTelemetryRecord;
    for (span_id) |byte| if (!std.ascii.isHex(byte)) return error.InvalidTelemetryRecord;
    for (parent_span_id) |byte| if (!std.ascii.isHex(byte)) return error.InvalidTelemetryRecord;
}

fn writeJsonU64String(writer: *std.Io.Writer, value: u64) !void {
    var buffer: [32]u8 = undefined;
    try std.json.Stringify.value(try std.fmt.bufPrint(&buffer, "{d}", .{value}), .{}, writer);
}

fn validateAttributes(attributes: []const Attribute, policy: AttributePolicy) !void {
    if (attributes.len > policy.max_attributes_per_record) return error.TooManyTelemetryAttributes;
    for (attributes) |attribute| {
        if (attribute.key.len == 0 or attribute.key.len > 256 or containsControl(attribute.key)) return error.InvalidTelemetryAttribute;
        switch (attribute.value) {
            .string => |value| if (value.len > policy.max_value_bytes or containsControl(value)) return error.InvalidTelemetryAttribute,
            .int => {},
        }
    }
}

fn writeAttributes(writer: *std.Io.Writer, attributes: []const Attribute) !void {
    for (attributes, 0..) |attribute, index| {
        if (index != 0) try writer.writeByte(',');
        try writeAttribute(writer, attribute);
    }
}

fn writeAttribute(writer: *std.Io.Writer, attribute: Attribute) !void {
    try writer.writeAll("{\"key\":");
    try std.json.Stringify.value(attribute.key, .{}, writer);
    try writer.writeAll(",\"value\":{");
    switch (attribute.value) {
        .string => |value| {
            try writer.writeAll("\"stringValue\":");
            try std.json.Stringify.value(value, .{}, writer);
        },
        .int => |value| {
            try writer.writeAll("\"intValue\":");
            var buffer: [32]u8 = undefined;
            try std.json.Stringify.value(try std.fmt.bufPrint(&buffer, "{d}", .{value}), .{}, writer);
        },
    }
    try writer.writeAll("}}");
}

fn exporterHeadersAlloc(allocator: std.mem.Allocator, options: Options) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    for (options.headers) |header| {
        try result.appendSlice(allocator, header.name);
        try result.appendSlice(allocator, ": ");
        try result.appendSlice(allocator, header.value);
        try result.appendSlice(allocator, "\r\n");
    }
    if (options.bearer_token) |token| {
        try result.appendSlice(allocator, "Authorization: Bearer ");
        try result.appendSlice(allocator, token);
        try result.appendSlice(allocator, "\r\n");
    }
    return result.toOwnedSlice(allocator);
}

fn createClientTlsContext(options: TlsOptions) !*SSL_CTX {
    const method = TLS_client_method() orelse return error.TlsInitializationFailed;
    const context = SSL_CTX_new(method) orelse return error.TlsInitializationFailed;
    errdefer SSL_CTX_free(context);
    if (SSL_CTX_ctrl(context, ssl_ctrl_set_min_proto_version, tls_1_2_version, null) != 1) return error.TlsPolicyConfigurationFailed;
    if (SSL_CTX_ctrl(context, ssl_ctrl_set_max_proto_version, tls_1_3_version, null) != 1) return error.TlsPolicyConfigurationFailed;
    if (options.ca_file) |ca_file| {
        if (SSL_CTX_load_verify_locations(context, ca_file.ptr, null) != 1) return error.TlsCaLoadFailed;
    } else if (SSL_CTX_set_default_verify_paths(context) != 1) return error.TlsCaLoadFailed;
    SSL_CTX_set_verify(context, ssl_verify_peer, null);
    return context;
}

fn createTestServerTlsContext(certificate_file: [:0]const u8, private_key_file: [:0]const u8) !*SSL_CTX {
    const method = TLS_server_method() orelse return error.TlsInitializationFailed;
    const context = SSL_CTX_new(method) orelse return error.TlsInitializationFailed;
    errdefer SSL_CTX_free(context);
    if (SSL_CTX_ctrl(context, ssl_ctrl_set_min_proto_version, tls_1_2_version, null) != 1) return error.TlsPolicyConfigurationFailed;
    if (SSL_CTX_ctrl(context, ssl_ctrl_set_max_proto_version, tls_1_3_version, null) != 1) return error.TlsPolicyConfigurationFailed;
    if (SSL_CTX_use_certificate_chain_file(context, certificate_file.ptr) != 1) return error.TlsCertificateLoadFailed;
    if (SSL_CTX_use_PrivateKey_file(context, private_key_file.ptr, ssl_filetype_pem) != 1) return error.TlsPrivateKeyLoadFailed;
    if (SSL_CTX_check_private_key(context) != 1) return error.TlsPrivateKeyMismatch;
    return context;
}

fn tlsWriteAll(ssl: *SSL, bytes: []const u8) !void {
    var offset: usize = 0;
    while (offset < bytes.len) {
        const maximum: usize = @intCast(std.math.maxInt(c_int));
        const result = SSL_write(ssl, bytes[offset..].ptr, @intCast(@min(bytes.len - offset, maximum)));
        if (result > 0) {
            offset += @intCast(result);
            continue;
        }
        const code = SSL_get_error(ssl, result);
        if (code == ssl_error_want_read or code == ssl_error_want_write) continue;
        return error.TlsWriteFailed;
    }
}

fn tlsRead(ssl: *SSL, buffer: []u8) !usize {
    while (true) {
        const result = SSL_read(ssl, buffer.ptr, @intCast(@min(buffer.len, @as(usize, @intCast(std.math.maxInt(c_int))))));
        if (result > 0) return @intCast(result);
        const code = SSL_get_error(ssl, result);
        if (code == ssl_error_want_read or code == ssl_error_want_write) continue;
        if (code == ssl_error_zero_return) return 0;
        return error.TlsReadFailed;
    }
}

fn validateCollectorResponse(response: []const u8) !void {
    const line_end = std.mem.indexOf(u8, response, "\r\n") orelse return error.InvalidCollectorResponse;
    const line = response[0..line_end];
    if (std.mem.startsWith(u8, line, "HTTP/1.1 200") or std.mem.startsWith(u8, line, "HTTP/1.1 202") or std.mem.startsWith(u8, line, "HTTP/1.1 204")) return;
    if (std.mem.startsWith(u8, line, "HTTP/1.1 429") or std.mem.startsWith(u8, line, "HTTP/1.1 5")) return error.CollectorRetryableResponse;
    return error.CollectorRejectedTelemetry;
}

fn retryable(err: anyerror) bool {
    return switch (err) {
        error.CollectorUnavailable, error.CollectorRetryableResponse, error.ConnectionResetByPeer, error.BrokenPipe => true,
        else => false,
    };
}
fn sleepMs(io: std.Io, value: u64) !void {
    try (std.Io.Clock.Duration{ .raw = .fromMilliseconds(@intCast(value)), .clock = .awake }).sleep(io);
}
fn deadlineTask(io: std.Io, value: u64) std.Io.Cancelable!void {
    return (std.Io.Clock.Duration{ .raw = .fromMilliseconds(@intCast(value)), .clock = .awake }).sleep(io);
}
fn elapsedMs(start: std.Io.Clock.Timestamp, end: std.Io.Clock.Timestamp) u64 {
    const duration = start.durationTo(end);
    return @intCast(@max(0, duration.raw.toMilliseconds()));
}
fn writeAll(stream: std.Io.net.Stream, io: std.Io, bytes: []const u8) !void {
    var offset: usize = 0;
    while (offset < bytes.len) {
        const parts = [_][]const u8{bytes[offset..]};
        const n = try io.vtable.netWrite(io.userdata, stream.socket.handle, "", &parts, 1);
        if (n == 0) return error.WriteZero;
        offset += n;
    }
}
fn streamRead(stream: std.Io.net.Stream, io: std.Io, buffer: []u8) !usize {
    var parts = [_][]u8{buffer};
    return io.vtable.netRead(io.userdata, stream.socket.handle, &parts);
}

test "plaintext and secure OTLP capability slices validate independently" {
    try capability.validate();
    try secure_capability.validate();
}

test "W3C trace context validates round trips and rejects zero ids" {
    const source = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01";
    const context = try TraceContext.parse(source, "vendor=value");
    try std.testing.expect(context.sampled());
    var formatted: [55]u8 = undefined;
    try std.testing.expectEqualStrings(source, context.format(&formatted));
    try std.testing.expectError(error.InvalidTraceparent, TraceContext.parse("00-00000000000000000000000000000000-00f067aa0ba902b7-01", null));
}

test "exporter queue is bounded validates signal and rejects secrets" {
    var exporter = try Exporter.init(std.testing.allocator, std.testing.io, .{ .max_queue_items = 1 });
    defer exporter.deinit();
    try exporter.enqueue(.logs, "{\"resourceLogs\":[]}");
    try std.testing.expectError(error.TelemetryBackpressure, exporter.enqueue(.logs, "{\"resourceLogs\":[]}"));
    try std.testing.expectError(error.SecretMaterialRejected, exporter.enqueue(.logs, "{\"resourceLogs\":[],\"token\":\"sentinel-secret\"}"));
    try std.testing.expectError(error.InvalidOtlpJson, exporter.enqueue(.traces, "{\"resourceLogs\":[]}"));
    const snapshot = exporter.snapshot();
    try std.testing.expectEqual(@as(usize, 1), snapshot.queued);
    try std.testing.expectEqual(@as(usize, 1), snapshot.dropped);
}

test "typed telemetry records encode as valid bounded OTLP JSON" {
    var exporter = try Exporter.init(std.testing.allocator, std.testing.io, .{ .max_queue_items = 3 });
    defer exporter.deinit();
    const attributes = [_]Attribute{.{ .key = "rpc.service", .value = .{ .string = "orders.v1.Orders" } }};
    try exporter.enqueueMetric(.{ .service_name = "orders-api", .name = "rpc.server.duration", .unit = "ms", .value = 12, .attributes = &attributes });
    try exporter.enqueueSpan(.{
        .service_name = "orders-api",
        .trace_id = "4bf92f3577b34da6a3ce929d0e0e4736",
        .span_id = "00f067aa0ba902b7",
        .name = "List",
        .start_time_unix_nanos = 1,
        .end_time_unix_nanos = 2,
        .attributes = &attributes,
    });
    try exporter.enqueueLog(.{ .service_name = "orders-api", .time_unix_nanos = 2, .body = "failed", .attributes = &attributes });
    try std.testing.expectEqual(@as(usize, 3), exporter.snapshot().queued);
}

test "OTLP histograms preserve buckets links and trace-correlated exemplars" {
    const trace_id = "4bf92f3577b34da6a3ce929d0e0e4736";
    const span_id = "00f067aa0ba902b7";
    const attributes = [_]Attribute{.{ .key = "rpc.method", .value = .{ .string = "List" } }};
    const links = [_]SpanLink{.{
        .trace_id = trace_id,
        .span_id = span_id,
        .tracestate = "vendor=value",
        .attributes = &attributes,
    }};
    const span_payload = try encodeSpanAlloc(std.testing.allocator, .{
        .service_name = "orders-api",
        .trace_id = trace_id,
        .span_id = span_id,
        .name = "List",
        .start_time_unix_nanos = 1,
        .end_time_unix_nanos = 2,
        .links = &links,
    }, .{});
    defer std.testing.allocator.free(span_payload);
    var parsed_span = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, span_payload, .{});
    defer parsed_span.deinit();

    const exemplars = [_]Exemplar{.{
        .time_unix_nanos = 2,
        .value = 12.5,
        .trace_id = trace_id,
        .span_id = span_id,
        .filtered_attributes = &attributes,
    }};
    const histogram_payload = try encodeHistogramAlloc(std.testing.allocator, .{
        .service_name = "orders-api",
        .name = "rpc.server.call.duration",
        .unit = "ms",
        .count = 3,
        .sum = 37.5,
        .bucket_counts = &.{ 1, 2, 0 },
        .explicit_bounds = &.{ 5, 25 },
        .min = 2,
        .max = 20,
        .time_unix_nanos = 2,
        .attributes = &attributes,
        .exemplars = &exemplars,
    }, .{});
    defer std.testing.allocator.free(histogram_payload);
    var parsed_histogram = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, histogram_payload, .{});
    defer parsed_histogram.deinit();
    try std.testing.expect(std.mem.indexOf(u8, histogram_payload, "bucketCounts") != null);
    try std.testing.expect(std.mem.indexOf(u8, histogram_payload, trace_id) != null);

    try std.testing.expectError(error.InvalidTelemetryRecord, encodeHistogramAlloc(std.testing.allocator, .{
        .service_name = "orders-api",
        .name = "rpc.server.call.duration",
        .count = 2,
        .sum = 1,
        .bucket_counts = &.{1},
        .explicit_bounds = &.{5},
    }, .{}));
}

test "secure OTLP options require verified TLS and reject injected headers" {
    try (Options{ .tls = .{ .server_name = "localhost", .ca_file = "../zigeffect-grpc/tests/fixtures/cert.pem" } }).validate();
    try std.testing.expectError(error.InvalidTlsOptions, (Options{ .tls = .{ .server_name = "" } }).validate());
    const injected = [_]Header{.{ .name = "x-tenant", .value = "ok\r\nx-admin: true" }};
    try std.testing.expectError(error.InvalidExporterHeader, (Options{ .headers = &injected }).validate());
}

test "verified TLS OTLP export sends bounded authentication headers" {
    const Collector = struct {
        io: std.Io,
        listener: *std.Io.net.Server,
        saw_tenant: bool = false,
        saw_authorization: bool = false,
        failure: ?anyerror = null,

        fn run(self: *@This()) void {
            self.serve() catch |err| {
                self.failure = err;
            };
        }

        fn serve(self: *@This()) !void {
            const context = try createTestServerTlsContext("../zigeffect-grpc/tests/fixtures/cert.pem", "../zigeffect-grpc/tests/fixtures/key.pem");
            defer SSL_CTX_free(context);
            var stream = try self.listener.accept(self.io);
            defer stream.close(self.io);
            const ssl = SSL_new(context) orelse return error.TlsConnectionInitializationFailed;
            defer SSL_free(ssl);
            if (SSL_set_fd(ssl, stream.socket.handle) != 1 or SSL_accept(ssl) != 1) return error.TlsHandshakeFailed;
            var buffer: [16 * 1024]u8 = undefined;
            const count = try tlsRead(ssl, &buffer);
            const request = buffer[0..count];
            self.saw_tenant = std.mem.indexOf(u8, request, "x-tenant: acme\r\n") != null;
            self.saw_authorization = std.mem.indexOf(u8, request, "Authorization: Bearer test-credential\r\n") != null;
            try tlsWriteAll(ssl, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}");
            _ = SSL_shutdown(ssl);
        }
    };

    var listener: ?std.Io.net.Server = null;
    var port: u16 = 19_750;
    while (port < 19_800) : (port += 1) {
        const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", port);
        listener = address.listen(std.testing.io, .{ .reuse_address = true }) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (listener == null) return error.NoTlsCollectorPort;
    defer listener.?.deinit(std.testing.io);
    var collector = Collector{ .io = std.testing.io, .listener = &listener.? };
    const thread = try std.Thread.spawn(.{}, Collector.run, .{&collector});
    const headers = [_]Header{.{ .name = "x-tenant", .value = "acme" }};
    var exporter = try Exporter.init(std.testing.allocator, std.testing.io, .{
        .host = "127.0.0.1",
        .port = port,
        .retry_attempts = 0,
        .tls = .{ .server_name = "localhost", .ca_file = "../zigeffect-grpc/tests/fixtures/cert.pem" },
        .headers = &headers,
        .bearer_token = "test-credential",
    });
    defer exporter.deinit();
    try exporter.enqueue(.traces, "{\"resourceSpans\":[]}");
    try exporter.flush();
    thread.join();
    if (collector.failure) |err| return err;
    try std.testing.expect(collector.saw_tenant);
    try std.testing.expect(collector.saw_authorization);
}

test "live OTLP collector receives logs metrics and traces from two services" {
    const Collector = struct {
        io: std.Io,
        listener: *std.Io.net.Server,
        requests: usize = 0,
        saw_api: bool = false,
        saw_worker: bool = false,
        failure: ?anyerror = null,

        fn run(self: *@This()) void {
            self.serve() catch |err| {
                self.failure = err;
            };
        }
        fn serve(self: *@This()) !void {
            while (self.requests < 6) {
                var stream = try self.listener.accept(self.io);
                defer stream.close(self.io);
                var buffer: [8192]u8 = undefined;
                var length: usize = 0;
                while (length < buffer.len) {
                    var parts = [_][]u8{buffer[length..]};
                    const count = try self.io.vtable.netRead(self.io.userdata, stream.socket.handle, &parts);
                    if (count == 0) break;
                    length += count;
                    if (std.mem.indexOf(u8, buffer[0..length], "\r\n\r\n") != null) break;
                }
                const request = buffer[0..length];
                if (!(std.mem.startsWith(u8, request, "POST /v1/logs ") or std.mem.startsWith(u8, request, "POST /v1/metrics ") or std.mem.startsWith(u8, request, "POST /v1/traces "))) return error.UnexpectedOtlpPath;
                if (std.mem.indexOf(u8, request, "service-api") != null) self.saw_api = true;
                if (std.mem.indexOf(u8, request, "service-worker") != null) self.saw_worker = true;
                try writeAll(stream, self.io, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}");
                self.requests += 1;
            }
        }
    };

    var listener: ?std.Io.net.Server = null;
    var port: u16 = 19720;
    while (port < 19750) : (port += 1) {
        const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", port);
        listener = address.listen(std.testing.io, .{ .reuse_address = true }) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (listener == null) return error.NoLoopbackPort;
    defer listener.?.deinit(std.testing.io);
    var collector = Collector{ .io = std.testing.io, .listener = &listener.? };
    const thread = try std.Thread.spawn(.{}, Collector.run, .{&collector});

    const services = [_][]const u8{ "service-api", "service-worker" };
    for (services) |service| {
        var exporter = try Exporter.init(std.testing.allocator, std.testing.io, .{ .port = port, .retry_attempts = 0 });
        defer exporter.deinit();
        const logs = try std.fmt.allocPrint(std.testing.allocator, "{{\"resourceLogs\":[{{\"resource\":{{\"attributes\":[{{\"key\":\"service.name\",\"value\":{{\"stringValue\":\"{s}\"}}}},{{\"key\":\"zigeffect.run.id\",\"value\":{{\"stringValue\":\"run-42\"}}}}]}},\"scopeLogs\":[{{\"logRecords\":[{{\"body\":{{\"stringValue\":\"ready\"}}}}]}}]}}]}}", .{service});
        defer std.testing.allocator.free(logs);
        const metrics = try std.fmt.allocPrint(std.testing.allocator, "{{\"resourceMetrics\":[{{\"resource\":{{\"attributes\":[{{\"key\":\"service.name\",\"value\":{{\"stringValue\":\"{s}\"}}}}]}},\"scopeMetrics\":[{{\"metrics\":[]}}]}}]}}", .{service});
        defer std.testing.allocator.free(metrics);
        const traces = try std.fmt.allocPrint(std.testing.allocator, "{{\"resourceSpans\":[{{\"resource\":{{\"attributes\":[{{\"key\":\"service.name\",\"value\":{{\"stringValue\":\"{s}\"}}}}]}},\"scopeSpans\":[{{\"spans\":[]}}]}}]}}", .{service});
        defer std.testing.allocator.free(traces);
        try exporter.enqueue(.logs, logs);
        try exporter.enqueue(.metrics, metrics);
        try exporter.enqueue(.traces, traces);
        try exporter.flush();
        try std.testing.expectEqual(@as(usize, 3), exporter.snapshot().exported);
    }
    thread.join();
    if (collector.failure) |err| return err;
    try std.testing.expectEqual(@as(usize, 6), collector.requests);
    try std.testing.expect(collector.saw_api and collector.saw_worker);
}

test "collector outage preserves bounded local failure evidence" {
    var exporter = try Exporter.init(std.testing.allocator, std.testing.io, .{ .port = 19999, .retry_attempts = 1, .retry_base_ms = 1, .request_deadline_ms = 20 });
    defer exporter.deinit();
    try exporter.enqueue(.logs, "{\"resourceLogs\":[]}");
    try std.testing.expectError(error.CollectorUnavailable, exporter.flush());
    const snapshot = exporter.snapshot();
    try std.testing.expectEqual(@as(usize, 1), snapshot.queued);
    try std.testing.expectEqual(@as(usize, 1), snapshot.failures);
    try std.testing.expectEqual(@as(usize, 1), snapshot.retries);
}

pub const ExporterLayerConfig = struct {
    io: std.Io,
    options: Options,
};

pub const ExporterLayerEnv = struct {
    allocator: std.mem.Allocator,
    exporter: Exporter,

    pub fn service(self: *ExporterLayerEnv, comptime Requested: type) *Requested {
        if (Requested == Exporter) return &self.exporter;
        return zstd.fx.serviceNotFound(ExporterLayerEnv, Requested);
    }
};

fn releaseExporterLayer(env: *ExporterLayerEnv) void {
    const allocator = env.allocator;
    env.exporter.shutdown() catch {};
    env.exporter.deinit();
    allocator.destroy(env);
}

fn buildExporterLayer(allocator: std.mem.Allocator, scope: *zstd.fx.Scope, ctx: anytype) anyerror!*ExporterLayerEnv {
    const config = ctx.service(ExporterLayerConfig);
    const env = try allocator.create(ExporterLayerEnv);
    errdefer allocator.destroy(env);
    env.* = .{
        .allocator = allocator,
        .exporter = try Exporter.init(allocator, config.io, config.options),
    };
    scope.addFinalizerFor(ExporterLayerEnv, env, releaseExporterLayer) catch |err| {
        releaseExporterLayer(env);
        return err;
    };
    return env;
}

pub fn exporterLayer() @TypeOf(
    zstd.fx.LayerWithError(ExporterLayerEnv, anyerror)
        .fromContextBuilder(buildExporterLayer)
        .requires(.{ExporterLayerConfig})
        .provides(.{Exporter}),
) {
    return zstd.fx.LayerWithError(ExporterLayerEnv, anyerror)
        .fromContextBuilder(buildExporterLayer)
        .requires(.{ExporterLayerConfig})
        .provides(.{Exporter});
}

pub fn FlushExporterEffect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = void;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Exporter};

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!zstd.fx.ServiceSet {
            return zstd.fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(_: @This(), ctx: *zstd.fx.Context(EffectEnv)) anyerror!void {
            ctx.service(Exporter).flush() catch |err| {
                _ = zstd.Service.recordOperation(ctx, Exporter, "otel.exporter.flush", "failure", @errorName(err));
                return err;
            };
            _ = zstd.Service.recordOperation(ctx, Exporter, "otel.exporter.flush", "success", "bounded telemetry queue flushed");
        }
    };
}

pub fn flushExporterEffect(comptime EffectEnv: type) FlushExporterEffect(EffectEnv) {
    return .{};
}

pub fn ShutdownExporterEffect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = void;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Exporter};

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!zstd.fx.ServiceSet {
            return zstd.fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(_: @This(), ctx: *zstd.fx.Context(EffectEnv)) anyerror!void {
            ctx.service(Exporter).shutdown() catch |err| {
                _ = zstd.Service.recordOperation(ctx, Exporter, "otel.exporter.shutdown", "failure", @errorName(err));
                return err;
            };
            _ = zstd.Service.recordOperation(ctx, Exporter, "otel.exporter.shutdown", "success", "exporter scope drained");
        }
    };
}

pub fn shutdownExporterEffect(comptime EffectEnv: type) ShutdownExporterEffect(EffectEnv) {
    return .{};
}
