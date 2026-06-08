# Zigeffect Causal Async Stream Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dependency-free bounded async stream causal backend for agents and local tools to observe stored zigeffect causal events incrementally.

**Architecture:** Implement `CausalAsyncStreamBackendState` as an adapter-owned bounded queue plus optional sink callback behind `CausalBackendKind.async_stream`. The backend clones stored, sanitized causal events, fails closed on queue or sink errors, and exposes peek/drain/clear/flush APIs without adding threads, filesystems, databases, Cockroach, or runtime-level async scheduling.

**Tech Stack:** Zig 0.15-style package code in `packages/zigeffect`, `std.ArrayList`, existing `CausalBackend` interface, `bun` repository checks.

---

## Files

- Create: `packages/zigeffect/src/services/causal_async_stream_backend.zig`
- Create: `packages/zigeffect/test/causal_async_stream_backend_test.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/all_test.zig`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Task 1: Specify Async Stream Backend Behavior

**Files:**
- Create: `packages/zigeffect/test/causal_async_stream_backend_test.zig`

- [ ] **Step 1: Add the focused test file**

Create `packages/zigeffect/test/causal_async_stream_backend_test.zig` with tests that compile against the desired public API:

```zig
const std = @import("std");
const fx = @import("zigeffect");
const conformance = @import("support/causal_backend_conformance.zig");

const FakeAsyncSink = struct {
    allocator: std.mem.Allocator,
    events: std.ArrayList(fx.CausalEvent) = .empty,
    fail_next: bool = false,
    flush_count: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) FakeAsyncSink {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *FakeAsyncSink) void {
        for (self.events.items) |event| {
            fx.deinitCausalAsyncStreamEvent(self.allocator, event);
        }
        self.events.deinit(self.allocator);
    }

    pub fn sink(self: *FakeAsyncSink) fx.CausalAsyncStreamSink {
        return .{
            .state = self,
            .on_event = onFakeAsyncEvent,
            .flush = flushFakeAsyncSink,
        };
    }
};

fn onFakeAsyncEvent(raw: ?*anyopaque, event: fx.CausalEvent) anyerror!void {
    const state: *FakeAsyncSink = @ptrCast(@alignCast(raw.?));
    if (state.fail_next) {
        state.fail_next = false;
        return error.FakeAsyncSinkRejected;
    }

    const cloned = try fx.cloneCausalAsyncStreamEvent(state.allocator, event);
    errdefer fx.deinitCausalAsyncStreamEvent(state.allocator, cloned);
    try state.events.append(state.allocator, cloned);
}

fn flushFakeAsyncSink(raw: ?*anyopaque) anyerror!void {
    const state: *FakeAsyncSink = @ptrCast(@alignCast(raw.?));
    state.flush_count += 1;
}

fn eventsContainString(events: []const fx.CausalEvent, needle: []const u8) bool {
    for (events) |event| {
        if (std.mem.indexOf(u8, event.label, needle) != null) return true;
        if (std.mem.indexOf(u8, event.type_name, needle) != null) return true;
        if (std.mem.indexOf(u8, event.status, needle) != null) return true;
        if (std.mem.indexOf(u8, event.redacted_detail, needle) != null) return true;
    }
    return false;
}

test "async stream backend queues conformance events and exposes async_stream kind" {
    var backend_state = fx.CausalAsyncStreamBackendState.init(std.testing.allocator, .{});
    defer backend_state.deinit();

    var store = fx.CausalStore.initWithOptions(std.testing.allocator, conformance.standardStoreOptions());
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const ids = try conformance.recordStandardTrace(&store);
    try conformance.expectStandardStorePosture(&store, ids);

    try std.testing.expectEqual(fx.CausalBackendKind.async_stream, store.attachedBackendKind().?);
    try std.testing.expectEqual(@as(usize, 3), backend_state.eventCount());
    try std.testing.expectEqual(@as(u64, 3), backend_state.acceptedEventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.drainedEventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.failedEventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.droppedEventCount());

    var snapshot = try backend_state.peekSnapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 3), snapshot.events.len);
    try std.testing.expectEqual(ids.started, snapshot.events[0].id);
    try std.testing.expectEqual(ids.retained_log, snapshot.events[1].id);
    try std.testing.expectEqual(ids.completed, snapshot.events[2].id);
    try std.testing.expect(eventsContainString(snapshot.events, "raw-secret") == false);
    try std.testing.expect(eventsContainString(snapshot.events, fx.causal_redaction_marker));
    try std.testing.expect(eventsContainString(snapshot.events, fx.causal_truncation_marker));
}

test "async stream peek leaves events queued and drain clears in order" {
    var backend_state = fx.CausalAsyncStreamBackendState.init(std.testing.allocator, .{});
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const root = try store.record(.{ .kind = .run_started, .label = "stream-run" });
    const child = try store.record(.{ .kind = .effect_completed, .parent_id = root, .status = "done" });

    var snapshot = try backend_state.peekSnapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 2), snapshot.events.len);
    try std.testing.expectEqual(@as(usize, 2), backend_state.eventCount());

    var drained = try backend_state.drain(std.testing.allocator);
    defer drained.deinit();
    try std.testing.expectEqual(@as(usize, 2), drained.events.len);
    try std.testing.expectEqual(root, drained.events[0].id);
    try std.testing.expectEqual(child, drained.events[1].id);
    try std.testing.expectEqual(@as(usize, 0), backend_state.eventCount());
    try std.testing.expectEqual(@as(u64, 2), backend_state.drainedEventCount());
}

test "async stream sink receives accepted events and flushes" {
    var fake = FakeAsyncSink.init(std.testing.allocator);
    defer fake.deinit();
    var backend_state = fx.CausalAsyncStreamBackendState.init(std.testing.allocator, .{
        .sink = fake.sink(),
    });
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const id = try store.record(.{ .kind = .run_started, .label = "sink-run" });
    try std.testing.expectEqual(@as(usize, 1), fake.events.items.len);
    try std.testing.expectEqual(id, fake.events.items[0].id);
    try std.testing.expectEqualStrings("sink-run", fake.events.items[0].label);

    try backend_state.flush();
    try std.testing.expectEqual(@as(u64, 1), fake.flush_count);
    try std.testing.expectEqual(@as(u64, 1), backend_state.flushedCount());
}

test "async stream sink failure fails closed without queueing" {
    var fake = FakeAsyncSink.init(std.testing.allocator);
    defer fake.deinit();
    fake.fail_next = true;
    var backend_state = fx.CausalAsyncStreamBackendState.init(std.testing.allocator, .{
        .sink = fake.sink(),
    });
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const id = try store.record(.{ .kind = .run_started, .label = "rejected" });
    try std.testing.expectEqual(@as(u64, 1), id);
    try std.testing.expectEqual(@as(usize, 0), backend_state.eventCount());
    try std.testing.expectEqual(@as(usize, 0), fake.events.items.len);
    try std.testing.expectEqual(@as(u64, 0), backend_state.acceptedEventCount());
    try std.testing.expectEqual(@as(u64, 1), backend_state.failedEventCount());
    try std.testing.expectEqual(@as(u64, 1), backend_state.droppedEventCount());
    try std.testing.expectEqual(@as(u64, 1), store.backendFailureCount());
}

test "async stream max_events fails before sink call" {
    var fake = FakeAsyncSink.init(std.testing.allocator);
    defer fake.deinit();
    var backend_state = fx.CausalAsyncStreamBackendState.init(std.testing.allocator, .{
        .max_events = 0,
        .sink = fake.sink(),
    });
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    _ = try store.record(.{ .kind = .run_started, .label = "overflow" });
    try std.testing.expectEqual(@as(usize, 0), backend_state.eventCount());
    try std.testing.expectEqual(@as(usize, 0), fake.events.items.len);
    try std.testing.expectEqual(@as(u64, 1), backend_state.failedEventCount());
    try std.testing.expectEqual(@as(u64, 1), backend_state.droppedEventCount());
    try std.testing.expectEqual(@as(u64, 1), store.backendFailureCount());
}

test "async stream clear releases queued events without changing accepted count" {
    var backend_state = fx.CausalAsyncStreamBackendState.init(std.testing.allocator, .{});
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    _ = try store.record(.{ .kind = .run_started, .label = "clear-me" });
    _ = try store.record(.{ .kind = .run_completed, .status = "ok" });

    try std.testing.expectEqual(@as(usize, 2), backend_state.eventCount());
    try std.testing.expectEqual(@as(u64, 2), backend_state.acceptedEventCount());
    backend_state.clear();
    try std.testing.expectEqual(@as(usize, 0), backend_state.eventCount());
    try std.testing.expectEqual(@as(u64, 2), backend_state.acceptedEventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.drainedEventCount());
}
```

- [ ] **Step 2: Run the focused red test**

Run:

```sh
cd packages/zigeffect && zig build test-raw --summary none
```

Expected: FAIL because `CausalAsyncStreamBackendState`, `CausalAsyncStreamSink`,
`cloneCausalAsyncStreamEvent`, and `deinitCausalAsyncStreamEvent` are not yet
exported.

- [ ] **Step 3: Commit the failing tests**

```sh
git add packages/zigeffect/test/causal_async_stream_backend_test.zig
git commit -m "test(zigeffect): specify causal async stream backend"
```

## Task 2: Implement Async Stream Backend

**Files:**
- Create: `packages/zigeffect/src/services/causal_async_stream_backend.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/all_test.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add the backend service implementation**

Create `packages/zigeffect/src/services/causal_async_stream_backend.zig`:

```zig
const std = @import("std");
const causal = @import("causal.zig");
const causal_backend = @import("causal_backend.zig");

pub const Allocator = std.mem.Allocator;

pub const CausalAsyncStreamSink = struct {
    state: ?*anyopaque = null,
    on_event: *const fn (?*anyopaque, causal.CausalEvent) anyerror!void,
    flush: ?*const fn (?*anyopaque) anyerror!void = null,
};

pub const CausalAsyncStreamBackendOptions = struct {
    max_events: ?usize = null,
    sink: ?CausalAsyncStreamSink = null,
};

pub const CausalAsyncStreamBackendError = error{
    CausalAsyncStreamBackendFull,
};

pub const CausalAsyncStreamBackendState = struct {
    allocator: Allocator,
    events: std.ArrayList(causal.CausalEvent) = .empty,
    max_events: ?usize = null,
    sink: ?CausalAsyncStreamSink = null,
    accepted_event_count: u64 = 0,
    drained_event_count: u64 = 0,
    failed_event_count: u64 = 0,
    dropped_event_count: u64 = 0,
    flushed_count: u64 = 0,

    pub fn init(allocator: Allocator, options: CausalAsyncStreamBackendOptions) CausalAsyncStreamBackendState {
        return .{
            .allocator = allocator,
            .max_events = options.max_events,
            .sink = options.sink,
        };
    }

    pub fn deinit(self: *CausalAsyncStreamBackendState) void {
        self.clear();
        self.events.deinit(self.allocator);
    }

    pub fn backend(self: *CausalAsyncStreamBackendState) causal_backend.CausalBackend {
        return .{
            .kind = .async_stream,
            .state = self,
            .record = recordAsyncStreamBackend,
        };
    }

    pub fn eventCount(self: *const CausalAsyncStreamBackendState) usize {
        return self.events.items.len;
    }

    pub fn acceptedEventCount(self: *const CausalAsyncStreamBackendState) u64 {
        return self.accepted_event_count;
    }

    pub fn drainedEventCount(self: *const CausalAsyncStreamBackendState) u64 {
        return self.drained_event_count;
    }

    pub fn failedEventCount(self: *const CausalAsyncStreamBackendState) u64 {
        return self.failed_event_count;
    }

    pub fn droppedEventCount(self: *const CausalAsyncStreamBackendState) u64 {
        return self.dropped_event_count;
    }

    pub fn flushedCount(self: *const CausalAsyncStreamBackendState) u64 {
        return self.flushed_count;
    }

    pub fn peekSnapshot(self: *const CausalAsyncStreamBackendState, allocator: Allocator) Allocator.Error!causal.CausalSnapshot {
        return snapshotFromEvents(allocator, self.events.items);
    }

    pub fn drain(self: *CausalAsyncStreamBackendState, allocator: Allocator) Allocator.Error!causal.CausalSnapshot {
        const snapshot = try snapshotFromEvents(allocator, self.events.items);
        const drained_count = self.events.items.len;
        self.clear();
        self.drained_event_count += drained_count;
        return snapshot;
    }

    pub fn clear(self: *CausalAsyncStreamBackendState) void {
        for (self.events.items) |event| {
            deinitEventStrings(self.allocator, event);
        }
        self.events.clearRetainingCapacity();
    }

    pub fn flush(self: *CausalAsyncStreamBackendState) anyerror!void {
        if (self.sink) |sink| {
            if (sink.flush) |flush_sink| {
                try flush_sink(sink.state);
                self.flushed_count += 1;
            }
        }
    }
};

fn cloneSlice(allocator: Allocator, value: []const u8) Allocator.Error![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

pub fn cloneCausalAsyncStreamEvent(allocator: Allocator, event: causal.CausalEvent) Allocator.Error!causal.CausalEvent {
    var owned = event;
    owned.label = try cloneSlice(allocator, event.label);
    errdefer if (owned.label.len > 0) allocator.free(owned.label);
    owned.type_name = try cloneSlice(allocator, event.type_name);
    errdefer if (owned.type_name.len > 0) allocator.free(owned.type_name);
    owned.status = try cloneSlice(allocator, event.status);
    errdefer if (owned.status.len > 0) allocator.free(owned.status);
    owned.redacted_detail = try cloneSlice(allocator, event.redacted_detail);
    errdefer if (owned.redacted_detail.len > 0) allocator.free(owned.redacted_detail);
    return owned;
}

pub fn deinitCausalAsyncStreamEvent(allocator: Allocator, event: causal.CausalEvent) void {
    deinitEventStrings(allocator, event);
}

fn deinitEventStrings(allocator: Allocator, event: causal.CausalEvent) void {
    if (event.label.len > 0) allocator.free(event.label);
    if (event.type_name.len > 0) allocator.free(event.type_name);
    if (event.status.len > 0) allocator.free(event.status);
    if (event.redacted_detail.len > 0) allocator.free(event.redacted_detail);
}

fn snapshotFromEvents(allocator: Allocator, source: []const causal.CausalEvent) Allocator.Error!causal.CausalSnapshot {
    const events = try allocator.alloc(causal.CausalEvent, source.len);
    errdefer allocator.free(events);

    var initialized: usize = 0;
    errdefer {
        for (events[0..initialized]) |event| {
            deinitEventStrings(allocator, event);
        }
    }

    for (source, 0..) |event, index| {
        events[index] = try cloneCausalAsyncStreamEvent(allocator, event);
        initialized += 1;
    }

    return .{ .allocator = allocator, .events = events };
}

fn recordAsyncStreamBackend(raw: ?*anyopaque, event: causal.CausalEvent) anyerror!void {
    const state: *CausalAsyncStreamBackendState = @ptrCast(@alignCast(raw.?));
    if (state.max_events) |max_events| {
        if (state.events.items.len >= max_events) {
            state.failed_event_count += 1;
            state.dropped_event_count += 1;
            return error.CausalAsyncStreamBackendFull;
        }
    }

    state.events.ensureUnusedCapacity(state.allocator, 1) catch |err| {
        state.failed_event_count += 1;
        state.dropped_event_count += 1;
        return err;
    };

    const owned = cloneCausalAsyncStreamEvent(state.allocator, event) catch |err| {
        state.failed_event_count += 1;
        state.dropped_event_count += 1;
        return err;
    };
    errdefer deinitEventStrings(state.allocator, owned);

    if (state.sink) |sink| {
        sink.on_event(sink.state, owned) catch |err| {
            state.failed_event_count += 1;
            state.dropped_event_count += 1;
            return err;
        };
    }

    state.events.appendAssumeCapacity(owned);
    state.accepted_event_count += 1;
}
```

- [ ] **Step 2: Export the service module**

In `packages/zigeffect/src/zigeffect.zig`, add this import inside
`pub const services = struct` near the other causal backend imports:

```zig
pub const causal_async_stream_backend = @import("services/causal_async_stream_backend.zig");
```

Add these exports inside the nested `services` alias block:

```zig
pub const CausalAsyncStreamSink = causal_async_stream_backend.CausalAsyncStreamSink;
pub const CausalAsyncStreamBackendOptions = causal_async_stream_backend.CausalAsyncStreamBackendOptions;
pub const CausalAsyncStreamBackendError = causal_async_stream_backend.CausalAsyncStreamBackendError;
pub const CausalAsyncStreamBackendState = causal_async_stream_backend.CausalAsyncStreamBackendState;
pub const cloneCausalAsyncStreamEvent = causal_async_stream_backend.cloneCausalAsyncStreamEvent;
pub const deinitCausalAsyncStreamEvent = causal_async_stream_backend.deinitCausalAsyncStreamEvent;
```

Add matching top-level exports:

```zig
pub const CausalAsyncStreamSink = services.causal_async_stream_backend.CausalAsyncStreamSink;
pub const CausalAsyncStreamBackendOptions = services.causal_async_stream_backend.CausalAsyncStreamBackendOptions;
pub const CausalAsyncStreamBackendError = services.causal_async_stream_backend.CausalAsyncStreamBackendError;
pub const CausalAsyncStreamBackendState = services.causal_async_stream_backend.CausalAsyncStreamBackendState;
pub const cloneCausalAsyncStreamEvent = services.causal_async_stream_backend.cloneCausalAsyncStreamEvent;
pub const deinitCausalAsyncStreamEvent = services.causal_async_stream_backend.deinitCausalAsyncStreamEvent;
```

- [ ] **Step 3: Wire the test import**

In `packages/zigeffect/test/all_test.zig`, add:

```zig
_ = @import("causal_async_stream_backend_test.zig");
```

Place it after `causal_nendb_storage_backend_test.zig`.

- [ ] **Step 4: Add the focused build step**

In `packages/zigeffect/build.zig`, add the module and step after the NenDB
storage backend step:

```zig
const causal_async_stream_backend_test_module = b.createModule(.{
    .root_source_file = b.path("test/causal_async_stream_backend_test.zig"),
    .target = target,
    .optimize = optimize,
});
causal_async_stream_backend_test_module.addImport("zigeffect", zigeffect);

const causal_async_stream_backend_tests = b.addTest(.{
    .name = "zigeffect-causal-async-stream-backend-tests",
    .root_module = causal_async_stream_backend_test_module,
});
const run_causal_async_stream_backend_tests = b.addRunArtifact(causal_async_stream_backend_tests);
const causal_async_stream_backend_step = b.step("causal-async-stream-backend", "Run causal async stream backend tests");
causal_async_stream_backend_step.dependOn(&run_causal_async_stream_backend_tests.step);
```

Add the focused test to the causal package test step:

```zig
test_step.dependOn(&run_causal_async_stream_backend_tests.step);
```

- [ ] **Step 5: Run the focused green test**

Run:

```sh
cd packages/zigeffect && zig build causal-async-stream-backend
```

Expected: PASS.

- [ ] **Step 6: Run package tests**

Run:

```sh
cd packages/zigeffect && zig build test-raw --summary none
cd packages/zigeffect && zig build test --summary none
```

Expected: PASS for both commands.

- [ ] **Step 7: Commit implementation**

```sh
git add packages/zigeffect/src/services/causal_async_stream_backend.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/all_test.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): add causal async stream backend"
```

## Task 3: Document Async Stream Backend

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update README backend section**

Add this paragraph after the NenDB storage section in
`packages/zigeffect/README.md`:

```md
Use `fx.CausalAsyncStreamBackendState` when a local agent, watch-mode tool, or
app runtime wants to observe stored causal events incrementally without claiming
durable history. The adapter keeps a bounded queue of cloned, sanitized events,
optionally forwards accepted events to a caller-provided `CausalAsyncStreamSink`,
and exposes `peekSnapshot`, `drain`, `clear`, and `flush`. If
`failedEventCount()` or `backendFailureCount()` is nonzero, treat the stream as
incomplete and fall back to retained store, graph-history, NenDB storage, JSONL,
or full JSON evidence. Run `zig build causal-async-stream-backend` for the
focused adapter gate.
```

- [ ] **Step 2: Update the agent guide**

Add this paragraph after the NenDB storage section in
`packages/zigeffect/docs/agent-guide.md`:

```md
Use `CausalAsyncStreamBackendState` when an agent needs incremental events from
a running local command but does not need durable history. `peekSnapshot`
returns a copy of the queued stream without mutating it; `drain` returns queued
events in order and clears the stream; `clear` discards queued events; `flush`
calls the optional sink flush hook. Treat the async stream as incomplete if
backend failures or dropped stream events are nonzero. Run
`zig build causal-async-stream-backend` for the focused adapter gate.
```

- [ ] **Step 3: Update the agent-observable runtime guide**

Replace the `async_stream` bullet in
`packages/zigeffect/docs/agent-observable-runtime.md` with:

```md
- `async_stream`: dependency-free bounded event stream for local agents,
  watch-mode tools, and future app runtime bridges
```

Add this concrete adapter paragraph after the NenDB storage paragraph:

```md
The concrete `async_stream` adapter is `CausalAsyncStreamBackendState`. It
queues cloned stored events in order, optionally calls a caller-provided
`CausalAsyncStreamSink`, and exposes `peekSnapshot`, `drain`, `clear`, and
`flush` for explicit consumers. It is non-durable and has no scheduler,
filesystem, network, NenDB, or Cockroach dependency. Its focused gate is
`zig build causal-async-stream-backend`.
```

- [ ] **Step 4: Update the master roadmap**

In `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`:

Change the existing adapter evidence bullet to include:

```md
`CausalAsyncStreamBackendState`
```

Change M4 status evidence from:

```md
backend boundary, conformance suite, JSONL sink, polished DOT backend, OTel bridge, graph-history adapter, and NenDB storage writer contract exist
```

to:

```md
backend boundary, conformance suite, JSONL sink, polished DOT backend, OTel bridge, graph-history adapter, NenDB storage writer contract, and async stream adapter exist
```

Change the M4 next action to:

```md
verify backend adapter suite and move to M5 snapshot manifest
```

Change the current branch block under M4 to the next branch after this one:

```text
codex/zigeffect-causal-snapshot-manifest
```

- [ ] **Step 5: Run documentation sanity checks**

Run:

```sh
rg -n "async stream|causal-async-stream-backend|CausalAsyncStreamBackendState|Cockroach" packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Expected: async stream references are present, and any Cockroach references are
either legacy package text or explicit statements that Cockroach is not part of
the current NenDB-only backend sequence.

- [ ] **Step 6: Commit docs**

```sh
git add packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): document causal async stream backend"
```

## Task 4: Verify And Merge

**Files:**
- No planned edits.

- [ ] **Step 1: Run focused backend gates**

Run:

```sh
cd packages/zigeffect && zig build causal-async-stream-backend
cd packages/zigeffect && zig build causal-backend-conformance
cd packages/zigeffect && zig build causal-nendb-storage-backend
cd packages/zigeffect && zig build causal-graph-history-backend
cd packages/zigeffect && zig build causal-otel-backend
cd packages/zigeffect && zig build causal-dot-backend
cd packages/zigeffect && zig build causal-jsonl-backend
```

Expected: PASS for every focused backend gate.

- [ ] **Step 2: Run package gates**

Run:

```sh
cd packages/zigeffect && zig build test-raw --summary none
cd packages/zigeffect && zig build test --summary none
cd packages/zigeffect && zig build causal-test-matrix
cd packages/zigeffect && zig build examples
```

Expected: PASS for tests and examples. The causal test matrix should print the
existing coverage table without reducing any current coverage domain.

- [ ] **Step 3: Run repository gates**

Run:

```sh
bun run check
bun run zig:test
git diff --check HEAD
```

Expected: PASS. `bun run check` should keep the current repository posture:
259 pass, 11 skip, 0 fail unless unrelated tests are added elsewhere.

- [ ] **Step 4: Inspect branch status**

Run:

```sh
git status --short --branch
```

Expected: branch `codex/zigeffect-causal-async-stream-backend` with only the
known unrelated untracked durable workflows roadmap file, if it is still present.

- [ ] **Step 5: Merge to master**

Run:

```sh
git switch master
git merge --ff-only codex/zigeffect-causal-async-stream-backend
git branch -d codex/zigeffect-causal-async-stream-backend
```

Expected: fast-forward merge succeeds and the feature branch is deleted.

- [ ] **Step 6: Post-merge smoke**

Run:

```sh
cd packages/zigeffect && zig build causal-async-stream-backend
cd packages/zigeffect && zig build test --summary none
bun run check
bun run zig:test
git diff --check HEAD
```

Expected: PASS for every command.

- [ ] **Step 7: Start next branch**

Run:

```sh
git switch -c codex/zigeffect-causal-snapshot-manifest
```

Expected: new branch created from verified `master` for M5 replay/snapshot work.

## Self-Review

- Spec coverage: the plan covers backend state, optional sink, bounded queue,
  peek/drain/clear/flush, fail-closed behavior, public exports, focused build
  step, docs, and full verification.
- Placeholder scan: no `TBD`, `TODO`, "fill in", or unspecified test work.
- Type consistency: public names match the design doc:
  `CausalAsyncStreamSink`, `CausalAsyncStreamBackendOptions`,
  `CausalAsyncStreamBackendError`, `CausalAsyncStreamBackendState`,
  `cloneCausalAsyncStreamEvent`, and `deinitCausalAsyncStreamEvent`.
