# zigeffect Causal Graph History Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dependency-free embedded graph-history backend that retains sanitized causal events and answers cause, lineage, and filter queries after the core store has dropped old retained events.

**Architecture:** Implement `causal_graph_history_backend.zig` as an adapter-owned event history behind `CausalBackendKind.nendb_graph`. The first implementation is scan-based and allocator-owned; it proves the graph query contract that future NenDB or durable adapters can replace.

**Tech Stack:** Zig 0.16, `std.ArrayList`, existing `CausalStore` and `CausalBackend`, backend conformance fixtures, Bun repo checks.

---

## File Structure

- Create: `packages/zigeffect/src/services/causal_graph_history_backend.zig`
  - Owns cloned event history, query helpers, backend state, max-event ceiling, and deinit behavior.
- Create: `packages/zigeffect/test/causal_graph_history_backend_test.zig`
  - Tests backend conformance behavior, retention-independent cause/lineage queries, filter queries, redaction/truncation propagation, and max-event failure.
- Modify: `packages/zigeffect/src/zigeffect.zig`
  - Exports the graph-history backend module and public API through `fx`.
- Modify: `packages/zigeffect/test/all_test.zig`
  - Imports the graph-history backend tests into package tests.
- Modify: `packages/zigeffect/build.zig`
  - Adds direct `zig build causal-graph-history-backend` step and wires it into the package `test` step.
- Modify: `packages/zigeffect/README.md`
  - Documents graph-history backend use and focused gate.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Guides agents to use graph history for local full-history queries without treating it as durable truth.
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
  - Updates backend adapter strategy with the concrete scan-based graph history bridge.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Marks graph-history backend delivered and advances M4 to the durable Cockroach/RoachGraph history branch.

## Task 1: Graph-History Backend Test First

**Files:**
- Create: `packages/zigeffect/test/causal_graph_history_backend_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Write the failing graph-history tests**

Create `packages/zigeffect/test/causal_graph_history_backend_test.zig` with:

```zig
const std = @import("std");
const fx = @import("zigeffect");
const conformance = @import("support/causal_backend_conformance.zig");

fn eventsContainString(events: []const fx.CausalEvent, needle: []const u8) bool {
    for (events) |event| {
        if (std.mem.indexOf(u8, event.label, needle) != null) return true;
        if (std.mem.indexOf(u8, event.type_name, needle) != null) return true;
        if (std.mem.indexOf(u8, event.status, needle) != null) return true;
        if (std.mem.indexOf(u8, event.redacted_detail, needle) != null) return true;
    }
    return false;
}

test "graph history backend preserves queryable history beyond store retention" {
    var backend_state = fx.CausalGraphHistoryBackendState.init(std.testing.allocator, .{});
    defer backend_state.deinit();

    var store = fx.CausalStore.initWithOptions(std.testing.allocator, conformance.standardStoreOptions());
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const ids = try conformance.recordStandardTrace(&store);
    try conformance.expectStandardStorePosture(&store, ids);

    try std.testing.expectEqual(fx.CausalBackendKind.nendb_graph, store.attachedBackendKind().?);
    try std.testing.expectEqual(@as(usize, 3), backend_state.eventCount());
    try std.testing.expectEqual(@as(u64, 3), backend_state.writtenEventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.failedEventCount());
    try std.testing.expectEqual(@as(u64, 0), store.backendFailureCount());

    var store_cause = try store.cause(std.testing.allocator, ids.retained_log);
    defer store_cause.deinit();
    try std.testing.expectEqual(@as(usize, 0), store_cause.events.len);

    var history_cause = try backend_state.cause(std.testing.allocator, ids.retained_log);
    defer history_cause.deinit();
    try std.testing.expectEqual(@as(usize, 2), history_cause.events.len);
    try std.testing.expectEqual(ids.started, history_cause.events[0].id);
    try std.testing.expectEqual(ids.retained_log, history_cause.events[1].id);

    var history_lineage = try backend_state.lineage(std.testing.allocator, ids.started);
    defer history_lineage.deinit();
    try std.testing.expectEqual(@as(usize, 3), history_lineage.events.len);
    try std.testing.expectEqual(ids.started, history_lineage.events[0].id);
    try std.testing.expectEqual(ids.retained_log, history_lineage.events[1].id);
    try std.testing.expectEqual(ids.completed, history_lineage.events[2].id);

    var logs = try backend_state.eventsByKind(std.testing.allocator, .log_recorded);
    defer logs.deinit();
    try std.testing.expectEqual(@as(usize, 1), logs.events.len);
    try std.testing.expectEqual(ids.retained_log, logs.events[0].id);

    var snapshot = try backend_state.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 3), snapshot.events.len);
    try std.testing.expect(eventsContainString(snapshot.events, "raw-secret") == false);
    try std.testing.expect(eventsContainString(snapshot.events, fx.causal_redaction_marker));
    try std.testing.expect(eventsContainString(snapshot.events, fx.causal_truncation_marker));
}

test "graph history backend filters by run scope and fiber" {
    var backend_state = fx.CausalGraphHistoryBackendState.init(std.testing.allocator, .{});
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const run_id = store.nextRunId();
    const other_run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const root = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .label = "graph-history-run",
    });
    _ = try store.record(.{
        .kind = .scope_opened,
        .run_id = run_id,
        .parent_id = root,
        .scope_id = scope_id,
        .status = "opened",
    });
    _ = try store.record(.{
        .kind = .fiber_forked,
        .run_id = run_id,
        .parent_id = root,
        .scope_id = scope_id,
        .fiber_id = 42,
        .status = "pending",
    });
    _ = try store.record(.{
        .kind = .run_started,
        .run_id = other_run_id,
        .label = "other-run",
    });

    var by_run = try backend_state.eventsByRun(std.testing.allocator, run_id);
    defer by_run.deinit();
    try std.testing.expectEqual(@as(usize, 3), by_run.events.len);

    var by_scope = try backend_state.eventsByScope(std.testing.allocator, scope_id);
    defer by_scope.deinit();
    try std.testing.expectEqual(@as(usize, 2), by_scope.events.len);
    try std.testing.expectEqual(scope_id, by_scope.events[0].scope_id.?);
    try std.testing.expectEqual(scope_id, by_scope.events[1].scope_id.?);

    var by_fiber = try backend_state.eventsByFiber(std.testing.allocator, 42);
    defer by_fiber.deinit();
    try std.testing.expectEqual(@as(usize, 1), by_fiber.events.len);
    try std.testing.expectEqual(@as(?u64, 42), by_fiber.events[0].fiber_id);
}

test "graph history backend max_events fails closed without partial history" {
    var backend_state = fx.CausalGraphHistoryBackendState.init(std.testing.allocator, .{ .max_events = 0 });
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const id = try store.record(.{
        .kind = .run_started,
        .label = "overflowing-graph-history",
    });

    try std.testing.expectEqual(@as(u64, 1), id);
    try std.testing.expectEqual(@as(usize, 0), backend_state.eventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.writtenEventCount());
    try std.testing.expectEqual(@as(u64, 1), backend_state.failedEventCount());
    try std.testing.expectEqual(@as(u64, 1), store.backendFailureCount());

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expectEqual(id, snapshot.events[0].id);
}
```

Add the test import in `packages/zigeffect/test/all_test.zig` after the OTel
backend import:

```zig
    _ = @import("causal_graph_history_backend_test.zig");
```

- [ ] **Step 2: Run the red check**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
```

Expected: FAIL because `fx.CausalGraphHistoryBackendState` does not exist yet.

- [ ] **Step 3: Commit the red tests**

```bash
git add packages/zigeffect/test/causal_graph_history_backend_test.zig packages/zigeffect/test/all_test.zig
git commit -m "test(zigeffect): specify causal graph history backend"
```

## Task 2: Implement The Graph-History Backend

**Files:**
- Create: `packages/zigeffect/src/services/causal_graph_history_backend.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add the graph-history backend module**

Create `packages/zigeffect/src/services/causal_graph_history_backend.zig` with a
scan-based implementation:

```zig
const std = @import("std");
const causal = @import("causal.zig");
const causal_backend = @import("causal_backend.zig");

pub const Allocator = std.mem.Allocator;

pub const CausalGraphHistoryBackendOptions = struct {
    max_events: ?usize = null,
};

pub const CausalGraphHistoryBackendError = error{
    CausalGraphHistoryBackendFull,
};

pub const CausalGraphHistoryBackendState = struct {
    allocator: Allocator,
    events: std.ArrayList(causal.CausalEvent) = .empty,
    max_events: ?usize = null,
    written_event_count: u64 = 0,
    failed_event_count: u64 = 0,

    pub fn init(allocator: Allocator, options: CausalGraphHistoryBackendOptions) CausalGraphHistoryBackendState {
        return .{
            .allocator = allocator,
            .max_events = options.max_events,
        };
    }

    pub fn deinit(self: *CausalGraphHistoryBackendState) void {
        for (self.events.items) |event| {
            deinitEventStrings(self.allocator, event);
        }
        self.events.deinit(self.allocator);
    }

    pub fn backend(self: *CausalGraphHistoryBackendState) causal_backend.CausalBackend {
        return .{
            .kind = .nendb_graph,
            .state = self,
            .record = recordGraphHistoryBackend,
        };
    }

    pub fn eventCount(self: *const CausalGraphHistoryBackendState) usize {
        return self.events.items.len;
    }

    pub fn writtenEventCount(self: *const CausalGraphHistoryBackendState) u64 {
        return self.written_event_count;
    }

    pub fn failedEventCount(self: *const CausalGraphHistoryBackendState) u64 {
        return self.failed_event_count;
    }

    pub fn snapshot(self: *const CausalGraphHistoryBackendState, allocator: Allocator) Allocator.Error!causal.CausalSnapshot {
        return snapshotFromEvents(allocator, self.events.items);
    }

    pub fn cause(self: *const CausalGraphHistoryBackendState, allocator: Allocator, event_id: u64) Allocator.Error!causal.CausalLineage {
        var output = std.ArrayList(causal.CausalEvent).empty;
        errdefer deinitEventList(allocator, &output);
        try self.appendCauseChain(allocator, &output, event_id);
        return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
    }

    pub fn lineage(self: *const CausalGraphHistoryBackendState, allocator: Allocator, event_id: u64) Allocator.Error!causal.CausalLineage {
        var output = std.ArrayList(causal.CausalEvent).empty;
        errdefer deinitEventList(allocator, &output);
        for (self.events.items) |event| {
            if (event.id == event_id or event.parent_id == event_id) {
                try appendClonedEvent(allocator, &output, event);
            }
        }
        return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
    }

    pub fn eventsByKind(self: *const CausalGraphHistoryBackendState, allocator: Allocator, kind: causal.CausalEventKind) Allocator.Error!causal.CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: causal.CausalEvent, expected: causal.CausalEventKind) bool {
                return event.kind == expected;
            }
        }.matches, kind);
    }

    pub fn eventsByRun(self: *const CausalGraphHistoryBackendState, allocator: Allocator, run_id: u64) Allocator.Error!causal.CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: causal.CausalEvent, expected: u64) bool {
                return event.run_id == expected;
            }
        }.matches, run_id);
    }

    pub fn eventsByScope(self: *const CausalGraphHistoryBackendState, allocator: Allocator, scope_id: u64) Allocator.Error!causal.CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: causal.CausalEvent, expected: u64) bool {
                return event.scope_id == expected;
            }
        }.matches, scope_id);
    }

    pub fn eventsByFiber(self: *const CausalGraphHistoryBackendState, allocator: Allocator, fiber_id: u64) Allocator.Error!causal.CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: causal.CausalEvent, expected: u64) bool {
                return event.fiber_id == expected;
            }
        }.matches, fiber_id);
    }

    fn findEvent(self: *const CausalGraphHistoryBackendState, event_id: u64) ?causal.CausalEvent {
        for (self.events.items) |event| {
            if (event.id == event_id) return event;
        }
        return null;
    }

    fn appendCauseChain(self: *const CausalGraphHistoryBackendState, allocator: Allocator, output: *std.ArrayList(causal.CausalEvent), event_id: u64) Allocator.Error!void {
        const event = self.findEvent(event_id) orelse return;
        if (event.parent_id) |parent_id| {
            try self.appendCauseChain(allocator, output, parent_id);
        }
        try appendClonedEvent(allocator, output, event);
    }

    fn filterEvents(
        self: *const CausalGraphHistoryBackendState,
        allocator: Allocator,
        comptime matches: anytype,
        expected: anytype,
    ) Allocator.Error!causal.CausalSnapshot {
        var output = std.ArrayList(causal.CausalEvent).empty;
        errdefer deinitEventList(allocator, &output);
        for (self.events.items) |event| {
            if (matches(event, expected)) {
                try appendClonedEvent(allocator, &output, event);
            }
        }
        return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
    }
};

fn cloneSlice(allocator: Allocator, value: []const u8) Allocator.Error![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

fn cloneEvent(allocator: Allocator, event: causal.CausalEvent) Allocator.Error!causal.CausalEvent {
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

fn deinitEventStrings(allocator: Allocator, event: causal.CausalEvent) void {
    if (event.label.len > 0) allocator.free(event.label);
    if (event.type_name.len > 0) allocator.free(event.type_name);
    if (event.status.len > 0) allocator.free(event.status);
    if (event.redacted_detail.len > 0) allocator.free(event.redacted_detail);
}

fn deinitEventList(allocator: Allocator, events: *std.ArrayList(causal.CausalEvent)) void {
    for (events.items) |event| {
        deinitEventStrings(allocator, event);
    }
    events.deinit(allocator);
}

fn appendClonedEvent(allocator: Allocator, output: *std.ArrayList(causal.CausalEvent), event: causal.CausalEvent) Allocator.Error!void {
    const cloned = try cloneEvent(allocator, event);
    errdefer deinitEventStrings(allocator, cloned);
    try output.append(allocator, cloned);
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
        events[index] = try cloneEvent(allocator, event);
        initialized += 1;
    }
    return .{ .allocator = allocator, .events = events };
}

fn recordGraphHistoryBackend(raw: ?*anyopaque, event: causal.CausalEvent) anyerror!void {
    const state: *CausalGraphHistoryBackendState = @ptrCast(@alignCast(raw.?));
    if (state.max_events) |max_events| {
        if (state.events.items.len >= max_events) {
            state.failed_event_count += 1;
            return error.CausalGraphHistoryBackendFull;
        }
    }

    const owned = cloneEvent(state.allocator, event) catch |err| {
        state.failed_event_count += 1;
        return err;
    };
    errdefer deinitEventStrings(state.allocator, owned);

    state.events.append(state.allocator, owned) catch |err| {
        state.failed_event_count += 1;
        return err;
    };
    state.written_event_count += 1;
}
```

- [ ] **Step 2: Export the graph-history backend**

In `packages/zigeffect/src/zigeffect.zig`, add the service import beside the
other causal backend imports:

```zig
    pub const causal_graph_history_backend = @import("services/causal_graph_history_backend.zig");
```

Add service and root exports:

```zig
pub const CausalGraphHistoryBackendOptions = services.causal_graph_history_backend.CausalGraphHistoryBackendOptions;
pub const CausalGraphHistoryBackendState = services.causal_graph_history_backend.CausalGraphHistoryBackendState;
```

Inside the `services` struct, expose the same constants using
`causal_graph_history_backend.*`.

- [ ] **Step 3: Add the focused build gate**

In `packages/zigeffect/build.zig`, add a test module after the OTel backend
test step:

```zig
    const causal_graph_history_backend_test_module = b.createModule(.{
        .root_source_file = b.path("test/causal_graph_history_backend_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_graph_history_backend_test_module.addImport("zigeffect", zigeffect);

    const causal_graph_history_backend_tests = b.addTest(.{
        .name = "zigeffect-causal-graph-history-backend-tests",
        .root_module = causal_graph_history_backend_test_module,
    });
    const run_causal_graph_history_backend_tests = b.addRunArtifact(causal_graph_history_backend_tests);
    const causal_graph_history_backend_step = b.step("causal-graph-history-backend", "Run causal graph history backend tests");
    causal_graph_history_backend_step.dependOn(&run_causal_graph_history_backend_tests.step);
```

Add the focused tests to the package `test` dependencies:

```zig
    test_step.dependOn(&run_causal_graph_history_backend_tests.step);
```

- [ ] **Step 4: Run the focused green check**

Run:

```bash
cd packages/zigeffect
zig build causal-graph-history-backend
```

Expected: PASS.

- [ ] **Step 5: Run local package checks**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
zig build test --summary none
```

Expected: both PASS.

- [ ] **Step 6: Commit the implementation**

```bash
git add packages/zigeffect/src/services/causal_graph_history_backend.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): add causal graph history backend"
```

## Task 3: Document The Graph-History Backend

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update README backend guidance**

After the OTel backend paragraph in `packages/zigeffect/README.md`, add:

```markdown
Use `fx.CausalGraphHistoryBackendState` when a local harness or agent session
needs queryable event history beyond the core store's retention window. The
first graph-history bridge is dependency-free and scan-based: it returns
`CausalBackendKind.nendb_graph` but does not yet depend on NenDB. Query the
backend with `snapshot`, `cause`, `lineage`, `eventsByKind`, `eventsByRun`,
`eventsByScope`, and `eventsByFiber`. Run
`zig build causal-graph-history-backend` for the focused adapter gate.
```

- [ ] **Step 2: Update the agent guide**

After the OTel backend guidance in `packages/zigeffect/docs/agent-guide.md`,
add:

```markdown
Use `CausalGraphHistoryBackendState` when store retention may have dropped
ancestor or child events that an agent still needs for local cause and lineage
queries. Treat it as adapter sink history, not durable truth. If
`failedEventCount()` or `backendFailureCount()` is nonzero, cite the graph
history as incomplete and fall back to retained store or JSON artifact
evidence.
```

- [ ] **Step 3: Update the agent-observable runtime doc**

In `packages/zigeffect/docs/agent-observable-runtime.md`, replace the
`nendb_graph` backend bullet and add a concrete adapter paragraph after the
OTel adapter paragraph:

```markdown
- `nendb_graph`: dependency-free embedded graph-history query adapter for
  local agents; actual NenDB storage remains future work
```

```markdown
The concrete `nendb_graph` adapter is `CausalGraphHistoryBackendState`. It
clones stored causal events into an adapter-owned history and answers
`snapshot`, `cause`, `lineage`, `eventsByKind`, `eventsByRun`, `eventsByScope`,
and `eventsByFiber` queries even after the deterministic store has trimmed its
retained event window. This branch is scan-based and dependency-free; NenDB can
replace the storage engine later without changing the backend hook. Its focused
gate is `zig build causal-graph-history-backend`.
```

- [ ] **Step 4: Update the master roadmap ledger**

In
`docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`,
update the current baseline list item to include
`CausalGraphHistoryBackendState`.

Update the M4 current branch block to:

```text
codex/zigeffect-causal-durable-history-backend
```

- [ ] **Step 5: Run docs diff check**

Run:

```bash
git diff --check
```

Expected: no whitespace errors.

- [ ] **Step 6: Commit docs**

```bash
git add packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): document causal graph history backend"
```

## Task 4: Final Verification And Merge

**Files:**
- Verify branch state only.

- [ ] **Step 1: Run focused backend gates**

Run:

```bash
cd packages/zigeffect
zig build causal-graph-history-backend
zig build causal-otel-backend
zig build causal-dot-backend
zig build causal-jsonl-backend
zig build causal-backend-conformance
```

Expected: all PASS.

- [ ] **Step 2: Run package and repo verification**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
zig build test --summary none
zig build causal-test-matrix
zig build examples
cd ../..
bun run check
bun run zig:test
git diff --check HEAD
```

Expected:

- Zig focused and package checks exit zero.
- `bun run check` exits zero with no failing tests.
- `bun run zig:test` exits zero.
- `git diff --check HEAD` exits zero.
- `git status --short` shows only the known unrelated untracked
  `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  file outside this branch's committed work.

- [ ] **Step 3: Merge to master**

Run:

```bash
git switch master
git merge --ff-only codex/zigeffect-causal-graph-history-backend
git branch -d codex/zigeffect-causal-graph-history-backend
```

Expected: fast-forward merge succeeds and branch deletes cleanly.

- [ ] **Step 4: Run post-merge smoke verification**

Run:

```bash
cd packages/zigeffect
zig build causal-graph-history-backend
zig build test --summary none
cd ../..
bun run check
bun run zig:test
git diff --check HEAD
```

Expected: all exit zero; only the known unrelated untracked durable-workflows
roadmap file remains outside committed work.

- [ ] **Step 5: Start the next branch**

Run:

```bash
git switch -c codex/zigeffect-causal-durable-history-backend
```

Expected: new feature branch is created from verified `master`.

## Self-Review

- Spec coverage: The tasks cover graph-history retention, cause and lineage
  queries, filter queries, backend failure posture, redaction/truncation,
  docs, roadmap updates, verification, and merge.
- Red-flag scan: No forbidden marker strings or vague test instructions remain.
- Type consistency: Public API names match the design:
  `CausalGraphHistoryBackendOptions`, `CausalGraphHistoryBackendState`,
  `snapshot`, `cause`, `lineage`, `eventsByKind`, `eventsByRun`,
  `eventsByScope`, and `eventsByFiber`.
