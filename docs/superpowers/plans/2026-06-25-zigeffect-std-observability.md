# zigeffect-std Observability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `zstd.Observability` as an effect-native logging, metrics, tracing, and artifact-export facade over the engine's real observability services.

**Architecture:** `packages/zigeffect-std/src/observability/root.zig` owns the standard-library service boundary. It wraps `fx.services.logger.Logger`, `fx.services.metrics.Metrics`, and `fx.services.tracing.Tracing` in a single `Recorder` service, exposes effect constructors for logs, counters, gauges, histograms, span lifecycle, and artifact export, and records std service causal facts for every boundary operation. Artifact export is deterministic JSON with redaction applied before data leaves the service.

**Tech Stack:** Zig, zigeffect `Effect`/`Runtime`/`Context`/`CausalStore`, engine logger/metrics/tracing services, `zstd.Service`, `zstd.Secrets`, `zstd.Json`, Bun-driven Zig test gate.

---

### Task 1: Public API Tests

**Files:**
- Create: `packages/zigeffect-std/src/observability/root.zig`
- Modify: `packages/zigeffect-std/src/root.zig`
- Test: `packages/zigeffect-std/src/observability/root.zig`

- [ ] **Step 1: Write the failing test**

Add tests in `packages/zigeffect-std/src/observability/root.zig` that prove:

```zig
test "Observability effects log metrics spans and causal facts" {
    const zstd = @import("../root.zig");

    var recorder = Recorder.init(std.testing.allocator);
    defer recorder.deinit();

    var provider = zstd.Service.Provider(.{Recorder}).init(.{&recorder});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{Recorder})
        .withCausalStore(&store);

    try runtime.run(logEffect(@TypeOf(provider), .info, "local compile token=abc123", &.{}));
    try runtime.run(incrementEffect(@TypeOf(provider), "agent.runs", 1));
    try runtime.run(gaugeEffect(@TypeOf(provider), "queue.depth", 2));
    try runtime.run(observeEffect(@TypeOf(provider), "build.ms", 42));
    const span_id = try runtime.run(startSpanEffect(@TypeOf(provider), "codex build span", null, &.{}));
    try runtime.run(endSpanEffect(@TypeOf(provider), span_id));

    try std.testing.expectEqual(@as(usize, 1), recorder.logger.structured_entries.items.len);
    try std.testing.expectEqual(@as(i64, 1), recorder.metrics.get("agent.runs"));
    try std.testing.expectEqual(@as(i64, 2), recorder.metrics.get("queue.depth"));
    try std.testing.expect(recorder.metrics.histogram("build.ms") != null);
    try std.testing.expectEqual(true, recorder.tracing.spanEnded(span_id).?);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 6), snapshot.events.len);
    try std.testing.expectEqualStrings(@typeName(Recorder), snapshot.events[0].service_key);
    try std.testing.expectEqualStrings("log", snapshot.events[0].label);
    try std.testing.expect(std.mem.indexOf(u8, snapshot.events[0].redacted_detail, "abc123") == null);
}
```

Also add a root export test:

```zig
test "root exports Observability namespace" {
    const zstd = @import("root.zig");
    try std.testing.expect(@hasDecl(zstd, "Observability"));
    try std.testing.expect(@hasDecl(zstd.Observability, "Recorder"));
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun run zigeffect:std:test`

Expected: FAIL because `packages/zigeffect-std/src/observability/root.zig` or the `zstd.Observability` export does not exist yet.

### Task 2: Recorder Service and Effects

**Files:**
- Create: `packages/zigeffect-std/src/observability/root.zig`
- Modify: `packages/zigeffect-std/src/root.zig`

- [ ] **Step 1: Implement the minimal service**

Create `Recorder` with:

```zig
pub const Level = fx.services.logger.LogLevel;
pub const Field = fx.services.logger.LogField;
pub const Attribute = fx.services.tracing.TraceAttribute;
pub const SpanId = fx.services.tracing.SpanId;

pub const Recorder = struct {
    allocator: std.mem.Allocator,
    logger: fx.services.logger.Logger,
    metrics: fx.services.metrics.Metrics,
    tracing: fx.services.tracing.Tracing,

    pub fn init(allocator: std.mem.Allocator) Recorder { ... }
    pub fn deinit(self: *Recorder) void { ... }
    pub fn log(self: *Recorder, level: Level, message: []const u8, fields: []const Field) !void { ... }
    pub fn increment(self: *Recorder, name: []const u8, amount: i64) !void { ... }
    pub fn gauge(self: *Recorder, name: []const u8, value: i64) !void { ... }
    pub fn observe(self: *Recorder, name: []const u8, value: i64) !void { ... }
    pub fn startSpan(self: *Recorder, name: []const u8, parent_id: ?SpanId, attributes: []const Attribute) !SpanId { ... }
    pub fn endSpan(self: *Recorder, id: SpanId) !void { ... }
};
```

Add `LogEffect`, `IncrementEffect`, `GaugeEffect`, `ObserveEffect`, `StartSpanEffect`, and `EndSpanEffect`, each requiring `Recorder`, delegating to the service, and calling `StdService.recordOperation`.

- [ ] **Step 2: Export namespace**

Add:

```zig
pub const Observability = @import("observability/root.zig");
```

to `packages/zigeffect-std/src/root.zig`.

- [ ] **Step 3: Run test to verify it passes**

Run: `bun run zigeffect:std:test`

Expected: PASS for the new behavior and all existing std tests.

### Task 3: Redacted Artifact Export

**Files:**
- Modify: `packages/zigeffect-std/src/observability/root.zig`

- [ ] **Step 1: Write the failing test**

Add a test proving artifact export is useful and secret-safe:

```zig
test "Observability exports redacted workbench and otlp json artifacts" {
    var recorder = Recorder.init(std.testing.allocator);
    defer recorder.deinit();

    try recorder.log(.warn, "authorization: Bearer local-token", &.{});
    _ = try recorder.startSpan("postgres://user:pass@localhost/db", null, &.{});
    try recorder.increment("agent.sessions", 3);
    try recorder.observe("agent.latency_ms", 99);

    const workbench = try recorder.workbenchJsonAlloc(std.testing.allocator, "dev-session token=abc123");
    defer std.testing.allocator.free(workbench);
    try std.testing.expect(std.mem.indexOf(u8, workbench, "\"schema\":\"zigeffect.std.observability.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, workbench, "abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, workbench, "local-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, workbench, "[REDACTED]") != null);

    const otlp = try recorder.otlpJsonAlloc(std.testing.allocator, "zigeffect-local");
    defer std.testing.allocator.free(otlp);
    try std.testing.expect(std.mem.indexOf(u8, otlp, "\"resourceLogs\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, otlp, "\"resourceMetrics\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, otlp, "\"resourceSpans\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, otlp, "pass@localhost") == null);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun run zigeffect:std:test`

Expected: FAIL because `workbenchJsonAlloc` and `otlpJsonAlloc` are missing.

- [ ] **Step 3: Implement artifact export**

Implement deterministic JSON writers that include logs, counters, histograms, and spans. Apply `Secrets.redactAlloc` and `Json.escapeStringAlloc` to every string field before it is appended to either artifact.

- [ ] **Step 4: Run test to verify it passes**

Run: `bun run zigeffect:std:test`

Expected: PASS.

### Task 4: Docs and Roadmap

**Files:**
- Modify: `packages/zigeffect-std/README.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-25-zigeffect-std-effectts-grade-roadmap-design.md`

- [ ] **Step 1: Update public docs**

Document `zstd.Observability` as a delivered std module with service-backed logging, metrics, tracing, redacted workbench JSON, and OTLP-shaped JSON.

- [ ] **Step 2: Update roadmap status**

Change the Effect-grade standard library roadmap status from M1-M6 delivered to M1-M7 delivered, with M8-M10 remaining.

- [ ] **Step 3: Run docs checks**

Run:

```bash
git diff --check
```

Expected: no whitespace errors.

### Task 5: Final Verification and Commit

**Files:**
- All M7 files above.

- [ ] **Step 1: Run full std gate**

Run:

```bash
bun run zigeffect:std:test
bun run zigeffect:local-agent-gate
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 2: Commit**

Run:

```bash
git add docs/superpowers/plans/2026-06-25-zigeffect-std-observability.md \
  docs/superpowers/specs/2026-06-25-zigeffect-std-effectts-grade-roadmap-design.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect-std/README.md \
  packages/zigeffect-std/src/root.zig \
  packages/zigeffect-std/src/observability/root.zig
git commit -m "Add zigeffect std observability"
```

Expected: commit succeeds after the verification gate.
