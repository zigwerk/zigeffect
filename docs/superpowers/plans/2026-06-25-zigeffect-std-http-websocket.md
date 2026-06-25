# zigeffect-std HTTP and WebSocket Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `zstd.Http` from a fake client helper into an effect-native HTTP/WebSocket standard-library boundary for local agent tools and workbench feeds.

**Architecture:** Keep this milestone inside `packages/zigeffect-std/src/http/root.zig`. The module owns request/response contracts, fake and local client services, deterministic in-memory server routing, WebSocket frame encoding/decoding, redacted diagnostics, and effect constructors. The live client uses Zig 0.16 `std.http.Client.fetch` and captures response bodies through `std.Io.Writer.Allocating`; server behavior remains deterministic/in-memory for this milestone so tests do not depend on background listener lifecycle.

**Tech Stack:** Zig, `std.http.Client`, `std.Io.Writer.Allocating`, zigeffect `Effect`/`Runtime`/`Context`, `zstd.Service`, `zstd.Secrets`, Bun-driven Zig test gate.

---

### Task 1: Effect-Native HTTP Client Contract

**Files:**
- Modify: `packages/zigeffect-std/src/http/root.zig`

- [ ] **Step 1: Write the failing test**

Add a test proving a client service runs through the effect runtime and records causal facts:

```zig
test "Http sendEffect uses client services and records redacted causal facts" {
    const zstd = @import("../root.zig");

    var client = FakeClient.init(.{ .status = 202, .body = "accepted" });
    var provider = zstd.Service.Provider(.{FakeClient}).init(.{&client});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{FakeClient})
        .withCausalStore(&store);

    var response = try runtime.run(sendEffect(@TypeOf(provider), FakeClient, .{
        .method = "POST",
        .url = "https://example.test/api?token=abc123",
        .headers = &.{.{ .name = "authorization", .value = "Bearer token" }},
        .body = "{\"name\":\"local\"}",
    }));
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u16, 202), response.status);
    try std.testing.expectEqualStrings("accepted", response.body);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    const event_index = zstd.Service.findOperation(snapshot, FakeClient, "http.send", "success");
    try std.testing.expect(event_index != null);
    try std.testing.expect(std.mem.indexOf(u8, snapshot.events[event_index.?].redacted_detail, "abc123") == null);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun run zigeffect:std:test`

Expected: FAIL because `sendEffect`, owned `Response.deinit`, and effect-native client signatures are not implemented yet.

- [ ] **Step 3: Implement client contract**

Implement:

- `Response.deinit(allocator)`.
- `cloneResponseAlloc`.
- `FakeClient.sendAlloc(allocator, request)`.
- `SendEffect(Env, Client)` and `sendEffect(Env, Client, request)`.
- `redactRequestAlloc` includes method, URL, sensitive headers, and body-secret detection.

- [ ] **Step 4: Run test to verify it passes**

Run: `bun run zigeffect:std:test`

Expected: PASS.

### Task 2: Local HTTP Client Adapter

**Files:**
- Modify: `packages/zigeffect-std/src/http/root.zig`

- [ ] **Step 1: Write the failing test**

Add a compile/runtime test for the adapter without requiring internet:

```zig
test "Http LocalClient exposes live adapter contract without network access" {
    var local = LocalClient.init(std.testing.allocator, std.testing.io);
    defer local.deinit();

    try std.testing.expect(local.response_body_limit == 1024 * 1024);
    try std.testing.expect(@hasDecl(LocalClient, "sendAlloc"));
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun run zigeffect:std:test`

Expected: FAIL because `LocalClient` is missing.

- [ ] **Step 3: Implement local client**

Implement `LocalClient` with:

- `client: std.http.Client`;
- `response_body_limit`;
- `init(allocator, io)`;
- `deinit`;
- `sendAlloc(allocator, request)` using `std.http.Client.fetch`;
- method mapping for common methods;
- extra header cloning into `std.http.Header`;
- bounded `std.Io.Writer.Allocating` response body capture;
- redacted causal details through `sendEffect`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bun run zigeffect:std:test`

Expected: PASS.

### Task 3: Deterministic Server Contract

**Files:**
- Modify: `packages/zigeffect-std/src/http/root.zig`

- [ ] **Step 1: Write the failing test**

Add a test for in-memory request routing:

```zig
test "Http memory server routes requests through effect-native handler" {
    const zstd = @import("../root.zig");

    var server = MemoryServer.init(std.testing.allocator);
    defer server.deinit();
    try server.addRoute("GET", "/health", .{ .status = 200, .body = "ok" });

    var provider = zstd.Service.Provider(.{MemoryServer}).init(.{&server});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{MemoryServer})
        .withCausalStore(&store);

    var response = try runtime.run(handleEffect(@TypeOf(provider), .{ .method = "GET", .url = "/health" }));
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u16, 200), response.status);
    try std.testing.expectEqualStrings("ok", response.body);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(zstd.Service.hasOperation(snapshot, MemoryServer, "http.handle", "success"));
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun run zigeffect:std:test`

Expected: FAIL because `MemoryServer` and `handleEffect` are missing.

- [ ] **Step 3: Implement server contract**

Implement:

- `MemoryServer` with owned route table.
- `addRoute(method, path, response)`.
- `handleAlloc(request)` matching URL path exactly.
- `HandleEffect(Env)` and `handleEffect`.
- 404 response for missing routes.

- [ ] **Step 4: Run test to verify it passes**

Run: `bun run zigeffect:std:test`

Expected: PASS.

### Task 4: WebSocket Frame Contracts

**Files:**
- Modify: `packages/zigeffect-std/src/http/root.zig`

- [ ] **Step 1: Write the failing test**

Add a test proving workbench-style frame contracts are deterministic and redacted:

```zig
test "Http WebSocketFrame encodes decodes and redacts payloads" {
    const frame = WebSocketFrame{
        .kind = .text,
        .payload = "{\"authorization\":\"Bearer token=abc123\"}",
    };

    const encoded = try frame.encodeAlloc(std.testing.allocator);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"kind\":\"text\"") != null);

    var decoded = try WebSocketFrame.decodeAlloc(std.testing.allocator, encoded);
    defer decoded.deinit(std.testing.allocator);
    try std.testing.expectEqual(WebSocketFrame.Kind.text, decoded.kind);
    try std.testing.expectEqualStrings("[REDACTED]", decoded.payload);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun run zigeffect:std:test`

Expected: FAIL because `WebSocketFrame` is missing.

- [ ] **Step 3: Implement frame contract**

Implement:

- `WebSocketFrame.Kind = enum { text, binary, ping, pong, close }`.
- `encodeAlloc` as deterministic JSON.
- `decodeAlloc` using `std.json.parseFromSlice`.
- payload redaction before storage or emission.

- [ ] **Step 4: Run test to verify it passes**

Run: `bun run zigeffect:std:test`

Expected: PASS.

### Task 5: Docs, Verification, Commit

**Files:**
- Modify: `packages/zigeffect-std/README.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-25-zigeffect-std-effectts-grade-roadmap-design.md`

- [ ] **Step 1: Update docs**

Document M8 as delivered: effect-native HTTP client/server contracts, fake and live local client, deterministic memory server, WebSocket frame codecs, and redacted diagnostics.

- [ ] **Step 2: Run full gate**

Run:

```bash
bun run zigeffect:std:test
bun run zigeffect:local-agent-gate
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 3: Commit**

Run:

```bash
git add docs/superpowers/plans/2026-06-25-zigeffect-std-http-websocket.md \
  docs/superpowers/specs/2026-06-25-zigeffect-std-effectts-grade-roadmap-design.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect-std/README.md \
  packages/zigeffect-std/src/http/root.zig
git commit -m "Add zigeffect std HTTP and WebSocket"
```

Expected: commit succeeds after the verification gate.
