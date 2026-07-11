const std = @import("std");
const zstd = @import("zigeffect_std");

pub const capability = zstd.Capability.Descriptor{
    .id = "zigeffect-otel.otlp-http-json",
    .kind = .telemetry,
    .maturity = .production_candidate,
    .package = "zigeffect-otel",
    .version = "0.1.0",
    .features = &.{ "otlp-http-json", "logs", "metrics", "traces", "bounded-queue", "retry", "flush", "w3c-trace-context" },
    .side_effects = .real,
    .conformance = .{ .schema = "zigeffect.otlp-live-conformance", .version = 1, .receipt = "conformance/otlp-http-live.v1.json", .authority = .live_external, .observed_at_ms = 1783777336000, .valid_until_ms = 1791553336000, .content_sha256 = "sha256:ca7db537af861210ae00800d0fc08ef1f03e0413c94ec76aefc5e1e4e31b2192" },
    .limitations = &.{ "plain HTTP only; deploy behind a local authenticated collector", "OTLP/gRPC is not implemented" },
};

pub const Signal = enum {
    logs,
    metrics,
    traces,

    pub fn path(self: Signal) []const u8 {
        return switch (self) { .logs => "/v1/logs", .metrics => "/v1/metrics", .traces => "/v1/traces" };
    }
    fn rootField(self: Signal) []const u8 {
        return switch (self) { .logs => "resourceLogs", .metrics => "resourceMetrics", .traces => "resourceSpans" };
    }
};
pub const Batch = struct { signal: Signal, payload: []const u8 };

pub fn batchStreamAlloc(allocator: std.mem.Allocator, batches: []const Batch) !zstd.fx.EffectStream(Batch, anyerror, zstd.Stream.EmptyEnv) {
    const Owned = struct { signal: Signal, payload: []u8 };
    const Puller = struct {
        allocator: std.mem.Allocator,
        batches: []Owned,
        offset: usize = 0,
        pub fn pull(self: *@This(), _: *zstd.fx.Context(zstd.Stream.EmptyEnv), output_allocator: std.mem.Allocator, max: usize) anyerror!zstd.fx.EffectStream(Batch, anyerror, zstd.Stream.EmptyEnv).Chunk { const count = @min(max, self.batches.len - self.offset); const output = try output_allocator.alloc(Batch, count); for (self.batches[self.offset .. self.offset + count], 0..) |item, index| output[index] = .{ .signal = item.signal, .payload = item.payload }; self.offset += count; return .{ .allocator = output_allocator, .items = output, .end = self.offset == self.batches.len }; }
        pub fn close(_: *@This(), _: zstd.fx.StreamCloseReason) void {}
        pub fn deinit(self: *@This()) void { for (self.batches) |item| self.allocator.free(item.payload); self.allocator.free(self.batches); }
    };
    const owned = try allocator.alloc(Owned, batches.len); errdefer allocator.free(owned); var initialized: usize = 0; errdefer for (owned[0..initialized]) |item| allocator.free(item.payload);
    for (batches, 0..) |batch, index| { owned[index] = .{ .signal = batch.signal, .payload = try allocator.dupe(u8, batch.payload) }; initialized += 1; }
    return zstd.fx.effectStreamFromOwnedPullerAlloc(Batch, anyerror, zstd.Stream.EmptyEnv, Puller, allocator, .{ .allocator = allocator, .batches = owned });
}

pub const TraceContext = struct {
    version: u8 = 0,
    trace_id: [16]u8,
    parent_id: [8]u8,
    flags: u8,
    tracestate: ?[]const u8 = null,

    pub fn sampled(self: TraceContext) bool { return self.flags & 1 == 1; }

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
fn parseHexByte(source: []const u8) !u8 { return std.fmt.parseUnsigned(u8, source, 16) catch error.InvalidTraceparent; }
fn allZero(bytes: []const u8) bool { for (bytes) |byte| if (byte != 0) return false; return true; }

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

    pub fn validate(self: Options) !void {
        if (self.host.len == 0 or self.port == 0 or self.max_queue_items == 0 or self.max_payload_bytes == 0 or self.request_deadline_ms == 0 or self.shutdown_deadline_ms == 0 or self.retry_base_ms == 0) return error.InvalidExporterOptions;
        if (self.attributes.max_attributes_per_record == 0 or self.attributes.max_distinct_values_per_key == 0 or self.attributes.max_value_bytes == 0) return error.InvalidExporterOptions;
    }
};

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

    pub fn init(allocator: std.mem.Allocator, io: std.Io, options: Options) !Exporter { try options.validate(); return .{ .allocator = allocator, .io = io, .options = options }; }
    pub fn deinit(self: *Exporter) void { self.lock(); defer self.mutex.unlock(); for (self.queue.items) |item| self.allocator.free(item.payload); self.queue.deinit(self.allocator); }

    pub fn enqueue(self: *Exporter, signal: Signal, payload: []const u8) !void {
        if (payload.len == 0 or payload.len > self.options.max_payload_bytes) return error.TelemetryPayloadTooLarge;
        if (zstd.Secrets.containsSecret(payload)) return error.SecretMaterialRejected;
        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, payload, .{}) catch return error.InvalidOtlpJson;
        defer parsed.deinit();
        if (parsed.value != .object or parsed.value.object.get(signal.rootField()) == null) return error.InvalidOtlpJson;
        const owned = try self.allocator.dupe(u8, payload);
        errdefer self.allocator.free(owned);
        self.lock(); defer self.mutex.unlock();
        if (self.shutting_down) return error.ExporterShuttingDown;
        if (self.queue.items.len == self.options.max_queue_items) switch (self.options.backpressure) {
            .reject_new => { self.dropped += 1; return error.TelemetryBackpressure; },
            .drop_oldest => { const old = self.queue.orderedRemove(0); self.allocator.free(old.payload); self.dropped += 1; },
        };
        try self.queue.append(self.allocator, .{ .signal = signal, .payload = owned });
        self.accepted += 1;
    }

    pub fn flush(self: *Exporter) !void {
        while (true) {
            self.lock();
            if (self.queue.items.len == 0) { self.mutex.unlock(); return; }
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
            self.lock(); self.exported += 1; self.mutex.unlock();
        }
    }

    pub fn shutdown(self: *Exporter) !void {
        self.lock(); self.shutting_down = true; self.mutex.unlock();
        const start = std.Io.Clock.Timestamp.now(self.io, .awake);
        self.flush() catch |err| {
            if (elapsedMs(start, std.Io.Clock.Timestamp.now(self.io, .awake)) >= self.options.shutdown_deadline_ms) return error.TelemetryShutdownDeadlineExceeded;
            return err;
        };
    }

    pub fn snapshot(self: *Exporter) Snapshot { self.lock(); defer self.mutex.unlock(); return .{ .queued = self.queue.items.len, .accepted = self.accepted, .exported = self.exported, .dropped = self.dropped, .failures = self.failures, .retries = self.retries, .shutting_down = self.shutting_down }; }

    fn sendWithRetry(self: *Exporter, item: Item) !void {
        var attempt: usize = 0;
        while (true) : (attempt += 1) {
            self.send(item) catch |err| {
                if (attempt >= self.options.retry_attempts or !retryable(err)) return err;
                self.lock(); self.retries += 1; self.mutex.unlock();
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
        const first = select.await() catch |err| { select.cancelDiscard(); return err; };
        switch (first) {
            .request => |result| { select.cancelDiscard(); try result; },
            .timeout => |result| { try result; select.cancelDiscard(); return error.TelemetryRequestDeadlineExceeded; },
        }
    }

    fn sendTask(self: *Exporter, item: Item) !void { return self.sendNow(item); }

    fn sendNow(self: *Exporter, item: Item) !void {
        const address = std.Io.net.IpAddress.resolve(self.io, self.options.host, self.options.port) catch return error.CollectorUnavailable;
        var stream = address.connect(self.io, .{ .mode = .stream }) catch return error.CollectorUnavailable;
        defer stream.close(self.io);
        const request = try std.fmt.allocPrint(self.allocator,
            "POST {s} HTTP/1.1\r\nHost: {s}:{d}\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}",
            .{ item.signal.path(), self.options.host, self.options.port, item.payload.len, item.payload });
        defer self.allocator.free(request);
        try writeAll(stream, self.io, request);
        var response: [4096]u8 = undefined;
        const count = try streamRead(stream, self.io, &response);
        if (count == 0) return error.CollectorUnavailable;
        const line_end = std.mem.indexOf(u8, response[0..count], "\r\n") orelse return error.InvalidCollectorResponse;
        const line = response[0..line_end];
        if (!(std.mem.startsWith(u8, line, "HTTP/1.1 200") or std.mem.startsWith(u8, line, "HTTP/1.1 202") or std.mem.startsWith(u8, line, "HTTP/1.1 204"))) {
            if (std.mem.startsWith(u8, line, "HTTP/1.1 429") or std.mem.startsWith(u8, line, "HTTP/1.1 5")) return error.CollectorRetryableResponse;
            return error.CollectorRejectedTelemetry;
        }
    }
    fn lock(self: *Exporter) void { while (!self.mutex.tryLock()) std.Thread.yield() catch {}; }
};

fn retryable(err: anyerror) bool { return switch (err) { error.CollectorUnavailable, error.CollectorRetryableResponse, error.ConnectionResetByPeer, error.BrokenPipe => true, else => false }; }
fn sleepMs(io: std.Io, value: u64) !void { try (std.Io.Clock.Duration{ .raw = .fromMilliseconds(@intCast(value)), .clock = .awake }).sleep(io); }
fn deadlineTask(io: std.Io, value: u64) std.Io.Cancelable!void { return (std.Io.Clock.Duration{ .raw = .fromMilliseconds(@intCast(value)), .clock = .awake }).sleep(io); }
fn elapsedMs(start: std.Io.Clock.Timestamp, end: std.Io.Clock.Timestamp) u64 { const duration = start.durationTo(end); return @intCast(@max(0, duration.raw.toMilliseconds())); }
fn writeAll(stream: std.Io.net.Stream, io: std.Io, bytes: []const u8) !void { var offset: usize = 0; while (offset < bytes.len) { const parts = [_][]const u8{bytes[offset..]}; const n = try io.vtable.netWrite(io.userdata, stream.socket.handle, "", &parts, 1); if (n == 0) return error.WriteZero; offset += n; } }
fn streamRead(stream: std.Io.net.Stream, io: std.Io, buffer: []u8) !usize { var parts = [_][]u8{buffer}; return io.vtable.netRead(io.userdata, stream.socket.handle, &parts); }

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

test "live OTLP collector receives logs metrics and traces from two services" {
    const Collector = struct {
        io: std.Io,
        listener: *std.Io.net.Server,
        requests: usize = 0,
        saw_api: bool = false,
        saw_worker: bool = false,
        failure: ?anyerror = null,

        fn run(self: *@This()) void {
            self.serve() catch |err| { self.failure = err; };
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
        listener = address.listen(std.testing.io, .{ .reuse_address = true }) catch |err| switch (err) { error.AddressInUse => continue, else => return err };
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
