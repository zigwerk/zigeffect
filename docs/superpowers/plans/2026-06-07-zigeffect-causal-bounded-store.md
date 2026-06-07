# zigeffect Causal Bounded Store Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an opt-in bounded retention policy to `CausalStore` so causal capture can be used in longer zigeffect development and CI loops without unbounded memory growth.

**Architecture:** Keep `CausalStore.init` unbounded. Add `CausalStoreOptions`, `initWithOptions`, and `initBounded`, store retention counters on `CausalStore`, drop oldest retained events after recording, and disclose retention state in text, CI, and JSON artifacts.

**Tech Stack:** Zig 0.16, `std.ArrayList`, existing zigeffect causal runtime and Bun-managed verification commands.

---

## File Structure

- Modify `packages/zigeffect/src/services/causal.zig` for bounded retention state, constructors, methods, record trimming, and artifact formatting.
- Modify `packages/zigeffect/src/zigeffect.zig` to re-export `CausalStoreOptions`.
- Modify `packages/zigeffect/test/services_test.zig` for RED/GREEN bounded-store tests.
- Modify `packages/zigeffect/README.md`, `packages/zigeffect/docs/agent-guide.md`, `packages/zigeffect/docs/agent-observable-runtime.md`, and `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md` to document the new policy.

### Task 1: RED Bounded Retention Tests

**Files:**
- Modify: `packages/zigeffect/test/services_test.zig`

- [ ] **Step 1: Add bounded retention test**

Add this test after the deterministic causal store test:

```zig
test "bounded causal store keeps newest events and reports dropped count" {
    var store = fx.CausalStore.initBounded(std.testing.allocator, 2);
    defer store.deinit();

    const first = try store.record(.{ .kind = .run_started, .label = "first" });
    const second = try store.record(.{ .kind = .effect_started, .parent_id = first, .label = "second" });
    const third = try store.record(.{ .kind = .exit_recorded, .parent_id = second, .label = "third" });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expectEqual(@as(usize, 2), snapshot.events.len);
    try std.testing.expectEqual(second, snapshot.events[0].id);
    try std.testing.expectEqual(third, snapshot.events[1].id);
    try std.testing.expectEqual(@as(u64, 1), store.droppedEventCount());
    try std.testing.expectEqual(@as(?u64, second), store.oldestRetainedEventId());
}
```

- [ ] **Step 2: Add zero-retention backend test**

Add this test near the backend test:

```zig
test "bounded causal store can retain zero events while forwarding backend events" {
    var backend_state = FakeCausalBackendState{};
    var store = fx.CausalStore.initBounded(std.testing.allocator, 0);
    store.attachBackend(fakeCausalBackend(&backend_state));
    defer store.deinit();

    const first = try store.record(.{ .kind = .run_started, .label = "backend-only" });
    const second = try store.record(.{ .kind = .exit_recorded, .parent_id = first, .label = "backend-only" });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expectEqual(@as(usize, 0), snapshot.events.len);
    try std.testing.expectEqual(@as(u64, 2), store.droppedEventCount());
    try std.testing.expectEqual(@as(?u64, null), store.oldestRetainedEventId());
    try std.testing.expectEqual(@as(usize, 2), backend_state.count);
    try std.testing.expectEqual(first, backend_state.ids[0]);
    try std.testing.expectEqual(second, backend_state.ids[1]);
}
```

- [ ] **Step 3: Add artifact retention test**

Add this test near the JSON/report tests:

```zig
test "causal artifacts disclose bounded retention state" {
    var store = fx.CausalStore.initBounded(std.testing.allocator, 1);
    defer store.deinit();

    _ = try store.record(.{ .kind = .run_started, .label = "dropped" });
    const retained = try store.record(.{ .kind = .exit_recorded, .label = "retained" });

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"retention\": {") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"max_events\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"dropped_events\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"oldest_retained_event_id\": 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"id\": 1") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"id\": 2") != null);

    const report = try fx.formatCausalCiReport(std.testing.allocator, "bounded", &store);
    defer std.testing.allocator.free(report);
    try std.testing.expect(std.mem.indexOf(u8, report, "retention: max_events=1 dropped_events=1 oldest_retained_event=2") != null);
    try std.testing.expectEqual(retained, store.oldestRetainedEventId().?);
}
```

- [ ] **Step 4: Run tests and verify RED**

Run:

```bash
cd packages/zigeffect && zig build test --summary none
```

Expected: FAIL because `initBounded`, `droppedEventCount`, `oldestRetainedEventId`, and retention formatting do not exist yet.

### Task 2: GREEN Bounded Store Core

**Files:**
- Modify: `packages/zigeffect/src/services/causal.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Add options and constructors**

Add near the causal schema constants:

```zig
pub const CausalStoreOptions = struct {
    max_events: ?usize = null,
};
```

Add fields to `CausalStore`:

```zig
max_events: ?usize = null,
dropped_event_count: u64 = 0,
```

Add constructors:

```zig
pub fn init(allocator: Allocator) CausalStore {
    return initWithOptions(allocator, .{});
}

pub fn initWithOptions(allocator: Allocator, options: CausalStoreOptions) CausalStore {
    return .{
        .allocator = allocator,
        .max_events = options.max_events,
    };
}

pub fn initBounded(allocator: Allocator, max_events: usize) CausalStore {
    return initWithOptions(allocator, .{ .max_events = max_events });
}
```

- [ ] **Step 2: Add retention methods**

Add:

```zig
pub fn droppedEventCount(self: *const CausalStore) u64 {
    return self.dropped_event_count;
}

pub fn oldestRetainedEventId(self: *const CausalStore) ?u64 {
    if (self.events.items.len == 0) return null;
    return self.events.items[0].id;
}
```

- [ ] **Step 3: Trim after record**

Add:

```zig
fn trimRetainedEvents(self: *CausalStore) void {
    const max_events = self.max_events orelse return;
    while (self.events.items.len > max_events) {
        const dropped = self.events.orderedRemove(0);
        deinitEventStrings(self.allocator, dropped);
        self.dropped_event_count += 1;
    }
}
```

Call `self.trimRetainedEvents()` at the end of `record` after backend emission.

- [ ] **Step 4: Re-export options**

In `packages/zigeffect/src/zigeffect.zig`, add:

```zig
pub const CausalStoreOptions = causal.CausalStoreOptions;
```

inside `services`, and:

```zig
pub const CausalStoreOptions = services.causal.CausalStoreOptions;
```

at the top-level export section.

- [ ] **Step 5: Run tests and verify partial GREEN**

Run:

```bash
cd packages/zigeffect && zig build test --summary none
```

Expected: tests still fail only on missing retention formatting.

### Task 3: GREEN Retention Formatting

**Files:**
- Modify: `packages/zigeffect/src/services/causal.zig`

- [ ] **Step 1: Add retention report helper**

Add:

```zig
fn appendRetentionSummary(output: *std.ArrayList(u8), allocator: Allocator, store: *const CausalStore) Allocator.Error!void {
    try output.appendSlice(allocator, "retention: max_events=");
    if (store.max_events) |max_events| {
        try output.print(allocator, "{d}", .{max_events});
    } else {
        try output.appendSlice(allocator, "unbounded");
    }
    try output.print(allocator, " dropped_events={d} oldest_retained_event=", .{store.dropped_event_count});
    try appendOptionalU64(output, allocator, store.oldestRetainedEventId());
    try output.append(allocator, '\n');
}
```

Call it after the `events:` line in both `formatCausalReport` and
`formatCausalCiReport`.

- [ ] **Step 2: Add JSON optional usize helper**

Add:

```zig
fn appendOptionalJsonUsize(output: *std.ArrayList(u8), allocator: Allocator, value: ?usize) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}
```

- [ ] **Step 3: Add JSON retention object**

Update `formatCausalJson` root output to emit:

```zig
try output.print(allocator, ",\n  \"schema_version\": {d},\n  \"retention\": {\n    \"max_events\": ", .{causal_json_schema_version});
try appendOptionalJsonUsize(&output, allocator, store.max_events);
try output.print(allocator, ",\n    \"dropped_events\": {d},\n    \"oldest_retained_event_id\": ", .{store.dropped_event_count});
try appendOptionalJsonU64(&output, allocator, store.oldestRetainedEventId());
try output.appendSlice(allocator, "\n  },\n  \"events\": [\n");
```

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```bash
cd packages/zigeffect && zig build test --summary none
```

Expected: PASS.

### Task 4: Documentation

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`

- [ ] **Step 1: Document bounded constructor**

Document:

```zig
var store = fx.CausalStore.initBounded(allocator, 256);
defer store.deinit();
```

- [ ] **Step 2: Document retention metadata**

Document that reports and JSON artifacts include `max_events`,
`dropped_events`, and `oldest_retained_event_id`, and that queries operate over
retained events.

- [ ] **Step 3: Update hardening roadmap**

Mark the first bounded-store slice as delivered while leaving sampling,
redaction hardening, event taxonomy compatibility, and artifact retention
planned.

### Task 5: Verification And Commit

**Files:**
- Stage all files modified in Tasks 1-4.

- [ ] **Step 1: Run verification**

Run:

```bash
cd packages/zigeffect && zig build test --summary none
cd packages/zigeffect && zig build examples
bun run zig:test
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
git diff --check
```

Expected: all commands PASS.

- [ ] **Step 2: Commit implementation**

Run:

```bash
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-bounded-store-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-bounded-store.md docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/src/services/causal.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/services_test.zig
git commit -m "feat(zigeffect): bound causal store retention"
```

## Self-Review

- Spec coverage: each acceptance criterion maps to Tasks 1-5.
- Placeholder scan: no deferred implementation language remains.
- Type consistency: `max_events` is `?usize`, `dropped_event_count` is `u64`, and `oldestRetainedEventId` returns `?u64`.
