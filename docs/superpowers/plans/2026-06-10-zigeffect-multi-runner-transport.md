# zigeffect Multi-Runner Transport Implementation Plan

> Historical plan: its production naming was corrected by M131 of the
> 2026-07-11 production application platform roadmap. The delivered adapters
> serialize protocol-shaped bytes but dispatch to an in-process handler.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add production HTTP and socket cluster transports with auth hooks, size limits, trace/chunk propagation, backpressure, retries, lifecycle metrics, failure evidence, and runner compatibility across transport modes.

**Architecture:** Extend the existing `cluster/transport.zig` module instead of creating a parallel routing path. Production transports reuse the stable JSON request/response schema, wrap it in HTTP or socket bytes, enforce policy before durable mutation, and submit accepted messages through `MessageStorage.submit` via the existing in-process handler. Concrete transports own lifecycle metrics and failure evidence while the public vtable stays small.

**Tech Stack:** Zig standard library, zigeffect cluster message storage, zigeffect async backend wait contract, `bun:test`-driven repo commands, `zig build` gates.

---

Spec: `docs/superpowers/specs/2026-06-10-zigeffect-multi-runner-transport-design.md`

Roadmap: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

## File Map

- Modify `packages/zigeffect/src/cluster/transport.zig`
  - Extend transport kinds, request/response metadata, auth, limits, lifecycle, failure reporting, production HTTP, socket frame codec, and production socket.
- Modify `packages/zigeffect/src/cluster/root.zig`
  - Re-export new cluster transport public surface.
- Modify `packages/zigeffect/src/zigeffect.zig`
  - Re-export top-level aliases used by public tests and examples.
- Modify `packages/zigeffect/test/cluster_transport_test.zig`
  - Add red tests for each production transport behavior and compatibility mode.
- Modify `packages/zigeffect/test/public_api_stability_test.zig`
  - Pin new public exports and new transport errors.
- Modify `packages/zigeffect/docs/architecture.md`
  - Document production transports as durable runner ingress.
- Modify `packages/zigeffect/docs/effectts-parity.md`
  - Update cluster parity status for production transport features.
- Modify `packages/zigeffect/docs/usage.md`
  - Add a compact usage example for auth, limits, and compatibility transport setup.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Mark M49 deliverables and acceptance complete after gates pass.
- Create `docs/superpowers/reports/2026-06-10-zigeffect-milestone-49-completion.md`
  - Capture verification evidence and behavior shipped.

## Task 1: Public Contract, Trace Fields, and Chunk Fields

**Files:**
- Modify: `packages/zigeffect/test/cluster_transport_test.zig`
- Modify: `packages/zigeffect/test/public_api_stability_test.zig`
- Modify: `packages/zigeffect/src/cluster/transport.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Add the failing public export and metadata tests**

Append these expectations to the first public export test in
`cluster_transport_test.zig`:

```zig
try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportAuthMode"));
try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportAuth"));
try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportLimits"));
try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportLifecycleState"));
try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportMetricsSnapshot"));
try std.testing.expect(@hasDecl(fx.cluster, "ClusterTransportFailureReport"));
try std.testing.expect(@hasDecl(fx.cluster, "ProductionHttpClusterTransport"));
try std.testing.expect(@hasDecl(fx.cluster, "ProductionSocketClusterTransport"));
try std.testing.expect(@hasDecl(fx.cluster, "formatClusterTransportSocketFrame"));
try std.testing.expect(@hasDecl(fx.cluster, "clusterTransportSocketFrameBody"));
try std.testing.expect(@hasDecl(fx.cluster, "formatClusterTransportFailureReport"));
try std.testing.expect(@hasDecl(fx, "ProductionHttpClusterTransport"));
try std.testing.expect(@hasDecl(fx, "ProductionSocketClusterTransport"));
```

Add this new test near the existing JSON request round-trip test:

```zig
test "transport request json preserves auth trace and chunk metadata" {
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
        .chunk_index = 0,
        .chunk_count = 3,
        .policy = .{ .timeout_ms = 250, .max_retries = 2 },
    };

    const json = try fx.formatClusterTransportRequestJson(std.testing.allocator, request);
    defer std.testing.allocator.free(json);

    var parsed = try fx.parseClusterTransportRequestJson(std.testing.allocator, json);
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(fx.ClusterTransportAuthMode.bearer_token, parsed.auth.mode);
    try std.testing.expectEqualStrings("token-1", parsed.auth.credential.?);
    try std.testing.expectEqual(@as(?u64, 7001), parsed.trace_id);
    try std.testing.expectEqual(@as(?u64, 7002), parsed.span_id);
    try std.testing.expectEqual(@as(?u32, 0), parsed.chunk_index);
    try std.testing.expectEqual(@as(?u32, 3), parsed.chunk_count);
}
```

Add this new test near the existing response JSON round-trip test:

```zig
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
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: compile failure for missing auth, limits, lifecycle, failure report,
production transport declarations, and metadata fields.

- [ ] **Step 3: Implement minimal public contract and JSON metadata**

In `transport.zig`, add:

```zig
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
```

Extend `ClusterTransportRequest`:

```zig
auth: ClusterTransportAuth = .{},
trace_id: ?u64 = null,
span_id: ?u64 = null,
chunk_index: ?u32 = null,
chunk_count: ?u32 = null,
```

Free `auth.credential` in `ClusterTransportRequest.deinit`.

Extend `ClusterTransportRequestJson` and `ClusterTransportResponseJson` with:

```zig
auth_mode: []const u8 = "none",
auth_credential: ?[]const u8 = null,
trace_id: ?u64 = null,
span_id: ?u64 = null,
chunk_index: ?u32 = null,
chunk_count: ?u32 = null,
```

Write the fields in request and response JSON, parse them with
`std.meta.stringToEnum`, and copy response fields into `MessageEnvelope`.

Update `cloneClusterTransportRequest` to clone auth credentials and metadata.

Export the new public symbols through `cluster/root.zig` and `zigeffect.zig`.

- [ ] **Step 4: Run the green test**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: all raw Zig tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add packages/zigeffect/src/cluster/transport.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_transport_test.zig packages/zigeffect/test/public_api_stability_test.zig
git commit -m "feat(zigeffect): extend cluster transport protocol metadata"
```

## Task 2: Auth, Limits, Backpressure, and Failure Reports

**Files:**
- Modify: `packages/zigeffect/test/cluster_transport_test.zig`
- Modify: `packages/zigeffect/src/cluster/transport.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Add failing tests for policy enforcement**

Add tests:

```zig
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
```

```zig
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
```

```zig
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
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: compile failure for missing production HTTP type, lifecycle metrics,
and failure formatting.

- [ ] **Step 3: Implement enforcement helpers**

In `transport.zig`, add:

```zig
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
```

Add helpers:

```zig
fn validateTransportLimits(limits: ClusterTransportLimits) ClusterTransportError!void
fn validateTransportAuth(required: ClusterTransportAuth, provided: ClusterTransportAuth) ClusterTransportError!void
fn validateTransportEnvelopeLimits(request: ClusterTransportRequest, limits: ClusterTransportLimits) ClusterTransportError!void
fn isRetryableTransportError(err: anyerror) bool
fn transportErrorName(err: anyerror) []const u8
fn recordTransportFailure(lifecycle: *ClusterTransportLifecycleState, last_failure: *?ClusterTransportFailureReport, kind: ClusterTransportKind, attempts: usize, err: anyerror, detail: []const u8) void
```

Add:

```zig
pub fn formatClusterTransportFailureReport(allocator: Allocator, report: ClusterTransportFailureReport) Allocator.Error![]const u8
```

The format string should be:

```text
cluster transport failure transport=<kind> retryable=<bool> attempts=<n> error=<name> detail=<redacted-detail>
```

- [ ] **Step 4: Add the production HTTP shell**

Implement `ProductionHttpClusterTransportOptions` and
`ProductionHttpClusterTransport` with:

```zig
pub const ProductionHttpClusterTransportOptions = struct {
    shard_count: ShardCount,
    auth: ClusterTransportAuth = .{},
    limits: ClusterTransportLimits = .{},
    failures_before_success: usize = 0,
};
```

`send` should enforce stopped state, timeout, auth, limits, and backpressure
before durable mutation. For this task, it can submit via the internal handler
without retry-byte wrapping. Task 3 adds the production HTTP bytes and retry
loop.

- [ ] **Step 5: Run the green test**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: all raw Zig tests pass.

- [ ] **Step 6: Commit**

Run:

```bash
git add packages/zigeffect/src/cluster/transport.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_transport_test.zig
git commit -m "feat(zigeffect): add transport auth limits and failure metrics"
```

## Task 3: Production HTTP Byte Boundary and Retry Policy

**Files:**
- Modify: `packages/zigeffect/test/cluster_transport_test.zig`
- Modify: `packages/zigeffect/src/cluster/transport.zig`

- [ ] **Step 1: Add failing production HTTP tests**

Add tests:

```zig
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
}
```

```zig
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
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: failures because production HTTP does not yet exercise encoded HTTP
request/response bytes or retry metrics.

- [ ] **Step 3: Implement production HTTP send loop**

Refactor HTTP send behavior into a helper:

```zig
fn sendHttpBytes(
    allocator: Allocator,
    handler: *InProcessClusterTransport,
    request: ClusterTransportRequest,
    attempts: usize,
    transport_kind: ClusterTransportKind,
) !ClusterTransportResponse
```

The helper formats request JSON, wraps it with
`formatClusterTransportHttpRequest`, extracts the body, parses the request,
calls `handler.sendWithAttempts(parsed_request, attempts, transport_kind)`,
formats response JSON, wraps it with `formatClusterTransportHttpResponse`,
extracts the body, and parses the response.

Update `LoopbackHttpClusterTransport.send` to call the helper.

Update `ProductionHttpClusterTransport.send` to:

- enforce preflight checks before the loop;
- increment `sends` once per user send;
- increment `in_flight` before encoded send and decrement on all exits;
- apply deterministic transient failures before byte submission;
- retry while `attempts < max_attempts`;
- increment `retries` for each retry after a transient failure;
- update bytes sent/received from encoded request/response sizes;
- return `RetryLimitExceeded` after the retry budget is exhausted.

- [ ] **Step 4: Run the green test**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: all raw Zig tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add packages/zigeffect/src/cluster/transport.zig packages/zigeffect/test/cluster_transport_test.zig
git commit -m "feat(zigeffect): add production http cluster transport"
```

## Task 4: Socket Frame Codec and Production Socket Transport

**Files:**
- Modify: `packages/zigeffect/test/cluster_transport_test.zig`
- Modify: `packages/zigeffect/src/cluster/transport.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Add failing socket tests**

Add tests:

```zig
test "socket frame codec extracts framed body" {
    const body = "{\"schema\":\"zigeffect.cluster.transport.request.v1\"}";
    const frame = try fx.formatClusterTransportSocketFrame(std.testing.allocator, body);
    defer std.testing.allocator.free(frame);
    const parsed = try fx.clusterTransportSocketFrameBody(frame);
    try std.testing.expectEqualStrings(body, parsed);
    try std.testing.expectError(error.CorruptTransportMessage, fx.clusterTransportSocketFrameBody("BAD/1 3\nabc"));
    try std.testing.expectError(error.CorruptTransportMessage, fx.clusterTransportSocketFrameBody("ZIGFX/1 5\nabc"));
}
```

```zig
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
        .chunk_index = 0,
        .chunk_count = 1,
    });
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(shard_id, response.shard_id);
    try std.testing.expectEqual(fx.ClusterTransportKind.production_socket, response.transport);
    try std.testing.expectEqual(@as(?u64, 9101), response.envelope.trace_id);
    try std.testing.expectEqual(@as(?u32, 0), response.envelope.chunk_index);

    var by_shard = try storage.unprocessedByShard(shard_id, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 1), by_shard.records.len);
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: compile failure for missing socket frame and production socket APIs.

- [ ] **Step 3: Implement socket frame and transport**

Add:

```zig
pub fn formatClusterTransportSocketFrame(allocator: Allocator, body: []const u8) Allocator.Error![]const u8
pub fn clusterTransportSocketFrameBody(frame: []const u8) ClusterTransportError![]const u8
```

Add:

```zig
pub const ProductionSocketClusterTransportOptions = ProductionHttpClusterTransportOptions;
pub const ProductionSocketClusterTransport = struct { ... };
```

The socket transport mirrors production HTTP policy enforcement and retry
behavior, but uses socket frames instead of HTTP bytes. It returns
`.production_socket`.

Extract shared production preflight and retry accounting helpers so HTTP and
socket paths stay consistent.

- [ ] **Step 4: Run the green test**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: all raw Zig tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add packages/zigeffect/src/cluster/transport.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_transport_test.zig
git commit -m "feat(zigeffect): add production socket cluster transport"
```

## Task 5: Chunk Metadata Helper and Compatibility Matrix

**Files:**
- Modify: `packages/zigeffect/test/cluster_transport_test.zig`
- Modify: `packages/zigeffect/src/cluster/transport.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Add failing chunk helper and compatibility tests**

Add:

```zig
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
```

Add production HTTP and production socket runner tests using the existing
`expectRunnerProcessesTransportAsk` helper. Pass expected trace and chunk
metadata through the helper:

```zig
test "cluster runner processes ask sent through production http transport" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runner_storage_state = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer runner_storage_state.deinit();
    var message_storage_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_state.deinit();

    var transport_state = try fx.ProductionHttpClusterTransport.init(std.testing.allocator, message_storage_state.asMessageStorage(), .{ .shard_count = 8 });
    defer transport_state.deinit();

    try expectRunnerProcessesTransportAsk(
        transport_state.asClusterTransport(),
        runner_storage_state.asRunnerStorage(),
        message_storage_state.asMessageStorage(),
        .production_http,
    );
}
```

```zig
test "cluster runner processes ask sent through production socket transport" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runner_storage_state = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer runner_storage_state.deinit();
    var message_storage_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_state.deinit();

    var transport_state = try fx.ProductionSocketClusterTransport.init(std.testing.allocator, message_storage_state.asMessageStorage(), .{ .shard_count = 8 });
    defer transport_state.deinit();

    try expectRunnerProcessesTransportAsk(
        transport_state.asClusterTransport(),
        runner_storage_state.asRunnerStorage(),
        message_storage_state.asMessageStorage(),
        .production_socket,
    );
}
```

Update `expectRunnerProcessesTransportAsk` to send `trace_id = 12001`,
`span_id = 12002`, `chunk_index = 0`, `chunk_count = 1`, and assert those fields
are visible to the entity handler and durable reply.

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: missing chunk helper and failed propagation assertions.

- [ ] **Step 3: Implement chunk helper and propagation**

Add:

```zig
pub fn chunkedClusterTransportRequest(
    allocator: Allocator,
    request: ClusterTransportRequest,
    limits: ClusterTransportLimits,
) (Allocator.Error || ClusterTransportError)!ClusterTransportRequest
```

Use `cloneClusterTransportRequest`, validate limits, and set chunk fields when
`payload.len > max_chunk_bytes`.

Update `InProcessClusterTransport.sendWithAttempts` to copy request `trace_id`,
`span_id`, `chunk_index`, and `chunk_count` into the submitted
`MessageEnvelope`.

- [ ] **Step 4: Run the green test**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: all raw Zig tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add packages/zigeffect/src/cluster/transport.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_transport_test.zig
git commit -m "test(zigeffect): cover production transport compatibility"
```

## Task 6: Documentation, Roadmap, Completion Report, and Release Gate

**Files:**
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `packages/zigeffect/docs/effectts-parity.md`
- Modify: `packages/zigeffect/docs/usage.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Create: `docs/superpowers/reports/2026-06-10-zigeffect-milestone-49-completion.md`

- [ ] **Step 1: Update docs**

Update architecture docs to say:

```markdown
- `transport.zig`: durable cluster transport boundary with in-process,
  loopback HTTP, production HTTP, and production socket transports. Production
  transports enforce auth hooks, envelope limits, backpressure, retry policy,
  trace/chunk propagation, lifecycle metrics, and secret-free failure evidence
  before appending accepted ingress messages to `MessageStorage`.
```

Update parity docs to state that zigeffect now covers local durable workflows,
cluster workflows, and production-shaped multi-runner transport with durable
storage-backed delivery.

Update usage docs with a compact example:

```zig
var transport_state = try fx.ProductionHttpClusterTransport.init(allocator, message_storage, .{
    .shard_count = 32,
    .auth = .{ .mode = .bearer_token, .credential = "runner-token" },
    .limits = .{ .max_envelope_bytes = 1024 * 1024, .max_chunk_bytes = 64 * 1024, .max_in_flight = 512 },
});
defer transport_state.deinit();

var response = try transport_state.asClusterTransport().send(allocator, .{
    .kind = .request,
    .address = fx.entityAddress("counter", "alice"),
    .payload_type_name = "text",
    .payload = "get",
    .redacted_detail = "read counter",
    .auth = .{ .mode = .bearer_token, .credential = "runner-token" },
    .trace_id = 42,
});
defer response.deinit(allocator);
```

- [ ] **Step 2: Mark roadmap M49 complete**

In the M49 roadmap block, mark every deliverable and acceptance checkbox as
complete.

- [ ] **Step 3: Add completion report**

Create `docs/superpowers/reports/2026-06-10-zigeffect-milestone-49-completion.md`
with:

```markdown
# zigeffect Milestone 49 Completion Report

Date: 2026-06-10

Milestone: 49 - Multi-Runner Transport

## Shipped

- Production HTTP transport with auth, limits, backpressure, retry metrics, and
  byte-boundary request/response handling.
- Production socket transport with deterministic frame codec and the same
  durable storage semantics.
- Trace and chunk metadata propagation through transport request, durable
  message storage, runner processing, and replies.
- Secret-free failure reports and lifecycle metrics.
- Compatibility tests across in-process, loopback HTTP, production HTTP, and
  production socket modes.

## Verification

- `cd packages/zigeffect && zig build test-raw`
- `cd packages/zigeffect && zig build release-gate`
- `cd packages/zigeffect && zig build examples`
- `bun run zigeffect:test`
- `bun run zig:test`
- `zig fmt --check` on modified Zig files
- `git diff --check`
- marker scan on modified source, tests, docs, spec, plan, roadmap, and report
```

- [ ] **Step 4: Run full verification**

Run:

```bash
cd packages/zigeffect && zig build test-raw
cd packages/zigeffect && zig build release-gate
cd packages/zigeffect && zig build examples
bun run zigeffect:test
bun run zig:test
zig fmt --check packages/zigeffect/src/cluster/transport.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_transport_test.zig packages/zigeffect/test/public_api_stability_test.zig
git diff --check
run the project marker scan on the modified source, tests, docs, spec, plan, roadmap, and report
```

Expected: all Zig and Bun gates pass, `zig fmt --check` passes, `git diff
--check` passes, marker scan exits with no matches.

- [ ] **Step 5: Commit closeout**

Run:

```bash
git add packages/zigeffect/docs/architecture.md packages/zigeffect/docs/effectts-parity.md packages/zigeffect/docs/usage.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/reports/2026-06-10-zigeffect-milestone-49-completion.md
git commit -m "docs(zigeffect): complete multi-runner transport"
```

## Self-Review Checklist

- Every M49 deliverable has a task: production HTTP, production socket, auth,
  limits and chunking, metrics and trace propagation, backpressure and retry
  policies, compatibility tests.
- Acceptance is covered by runner tests across four modes and by pre-mutation
  rejection tests.
- Secrets stay out of failure reports and lifecycle fields.
- Public API aliases are exported from both `fx.cluster` and top-level `fx`.
- Transport failures do not mutate durable storage before auth, limit, timeout,
  stopped-state, or backpressure checks pass.
- The full release gate runs before roadmap closeout.
