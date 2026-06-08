# zigeffect Causal NenDB Storage Adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a NenDB-shaped storage adapter that maps causal events into graph node/edge writes while keeping queryable adapter-owned history and avoiding a brittle direct upstream dependency.

**Architecture:** Implement `causal_nendb_storage_backend.zig` as a `CausalBackendKind.nendb_graph` adapter with an injected `CausalNendbGraphWriter`. The adapter formats deterministic node/edge writes, calls the writer fail-closed, then appends cloned local history with the same query vocabulary as the scan-only graph-history backend.

**Tech Stack:** Zig 0.16, existing `CausalStore` and `CausalBackend`, fake writer tests, backend conformance fixture, Bun repo checks.

---

## File Structure

- Create: `packages/zigeffect/src/services/causal_nendb_storage_backend.zig`
  - Owns the NenDB write contract, event-to-node/edge mapping, writer callback,
    local history, query helpers, flush hook, counters, and deinit behavior.
- Create: `packages/zigeffect/test/causal_nendb_storage_backend_test.zig`
  - Tests mapping, fake writer writes, conformance trace behavior,
    retention-independent queries, fail-closed writer errors, max-event
    preflight, and flush hook behavior.
- Modify: `packages/zigeffect/src/zigeffect.zig`
  - Exports the NenDB storage backend module and public API through `fx`.
- Modify: `packages/zigeffect/test/all_test.zig`
  - Imports the NenDB storage backend tests into package tests.
- Modify: `packages/zigeffect/build.zig`
  - Adds direct `zig build causal-nendb-storage-backend` step and wires it into
    the package `test` step.
- Modify: `packages/zigeffect/README.md`
  - Documents the NenDB storage adapter contract and focused gate.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Guides agents to distinguish scan-only graph history from the NenDB writer
    adapter.
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
  - Updates backend adapter strategy with the concrete NenDB storage contract.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Marks the NenDB storage adapter delivered and advances M4 to async stream
    adapter design.

## Task 1: NenDB Storage Adapter Test First

**Files:**
- Create: `packages/zigeffect/test/causal_nendb_storage_backend_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Write the fake writer and failing tests**

Create `packages/zigeffect/test/causal_nendb_storage_backend_test.zig` with:

```zig
const std = @import("std");
const fx = @import("zigeffect");
const conformance = @import("support/causal_backend_conformance.zig");

const FakeNendbWriter = struct {
    allocator: std.mem.Allocator,
    writes: std.ArrayList(fx.CausalNendbWrite) = .empty,
    fail_next: bool = false,
    flush_count: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) FakeNendbWriter {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *FakeNendbWriter) void {
        for (self.writes.items) |*write| {
            fx.deinitCausalNendbWrite(self.allocator, write);
        }
        self.writes.deinit(self.allocator);
    }

    pub fn writer(self: *FakeNendbWriter) fx.CausalNendbGraphWriter {
        return .{
            .state = self,
            .write = writeFakeNendb,
            .flush = flushFakeNendb,
        };
    }
};

fn writeFakeNendb(raw: ?*anyopaque, write: fx.CausalNendbWrite) anyerror!void {
    const state: *FakeNendbWriter = @ptrCast(@alignCast(raw.?));
    if (state.fail_next) {
        state.fail_next = false;
        return error.FakeNendbWriterRejected;
    }

    var cloned = try fx.cloneCausalNendbWrite(state.allocator, write);
    errdefer fx.deinitCausalNendbWrite(state.allocator, &cloned);
    try state.writes.append(state.allocator, cloned);
}

fn flushFakeNendb(raw: ?*anyopaque) anyerror!void {
    const state: *FakeNendbWriter = @ptrCast(@alignCast(raw.?));
    state.flush_count += 1;
}

fn writesContainString(writes: []const fx.CausalNendbWrite, needle: []const u8) bool {
    for (writes) |write| {
        if (std.mem.indexOf(u8, write.node.label, needle) != null) return true;
        if (std.mem.indexOf(u8, write.node.properties, needle) != null) return true;
        if (write.parent_edge) |edge| {
            if (std.mem.indexOf(u8, edge.label, needle) != null) return true;
            if (std.mem.indexOf(u8, edge.properties, needle) != null) return true;
        }
    }
    return false;
}

test "map causal event to deterministic nendb node and parent edge" {
    var write = try fx.mapCausalEventToNendbWrite(std.testing.allocator, .{
        .id = 42,
        .kind = .effect_started,
        .run_id = 7,
        .parent_id = 9,
        .fiber_id = 10,
        .scope_id = 11,
        .trace_id = 12,
        .span_id = 13,
        .label = "load-vessel",
        .type_name = "VesselEffect",
        .status = "running",
        .redacted_detail = "safe detail",
    });
    defer fx.deinitCausalNendbWrite(std.testing.allocator, &write);

    try std.testing.expectEqual(@as(u64, 42), write.node.id);
    try std.testing.expectEqualStrings("causal_event", write.node.label);
    try std.testing.expectEqual(fx.stableCausalNendbLabelId("effect_started"), write.node.kind);
    try std.testing.expect(std.mem.indexOf(u8, write.node.properties, "\"kind\":\"effect_started\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, write.node.properties, "\"event_id\":42") != null);
    try std.testing.expect(std.mem.indexOf(u8, write.node.properties, "\"run_id\":7") != null);
    try std.testing.expect(std.mem.indexOf(u8, write.node.properties, "\"label\":\"load-vessel\"") != null);
    try std.testing.expect(write.parent_edge != null);
    try std.testing.expectEqual(@as(u64, 9), write.parent_edge.?.from);
    try std.testing.expectEqual(@as(u64, 42), write.parent_edge.?.to);
    try std.testing.expectEqualStrings("causal_parent", write.parent_edge.?.label);
    try std.testing.expectEqual(fx.stableCausalNendbEdgeLabelId("causal_parent"), write.parent_edge.?.label_id);
    try std.testing.expect(std.mem.indexOf(u8, write.parent_edge.?.properties, "\"from_event_id\":9") != null);
    try std.testing.expect(std.mem.indexOf(u8, write.parent_edge.?.properties, "\"to_event_id\":42") != null);

    var second = try fx.mapCausalEventToNendbWrite(std.testing.allocator, .{
        .id = 43,
        .kind = .effect_started,
        .parent_id = 42,
    });
    defer fx.deinitCausalNendbWrite(std.testing.allocator, &second);
    try std.testing.expectEqual(write.node.kind, second.node.kind);
    try std.testing.expectEqual(write.parent_edge.?.label_id, second.parent_edge.?.label_id);
}

test "nendb storage backend writes conformance events and keeps queryable history" {
    var fake = FakeNendbWriter.init(std.testing.allocator);
    defer fake.deinit();
    var backend_state = fx.CausalNendbStorageBackendState.init(std.testing.allocator, fake.writer(), .{});
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
    try std.testing.expectEqual(@as(usize, 3), fake.writes.items.len);
    try std.testing.expectEqual(ids.started, fake.writes.items[0].node.id);
    try std.testing.expect(fake.writes.items[0].parent_edge == null);
    try std.testing.expectEqual(ids.retained_log, fake.writes.items[1].node.id);
    try std.testing.expectEqual(ids.started, fake.writes.items[1].parent_edge.?.from);
    try std.testing.expectEqual(ids.retained_log, fake.writes.items[1].parent_edge.?.to);
    try std.testing.expectEqual(ids.completed, fake.writes.items[2].node.id);
    try std.testing.expectEqual(ids.started, fake.writes.items[2].parent_edge.?.from);
    try std.testing.expect(writesContainString(fake.writes.items, "raw-secret") == false);
    try std.testing.expect(writesContainString(fake.writes.items, fx.causal_redaction_marker));
    try std.testing.expect(writesContainString(fake.writes.items, fx.causal_truncation_marker));

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
}

test "nendb storage backend filters by run scope and fiber" {
    var fake = FakeNendbWriter.init(std.testing.allocator);
    defer fake.deinit();
    var backend_state = fx.CausalNendbStorageBackendState.init(std.testing.allocator, fake.writer(), .{});
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
        .label = "nendb-storage-run",
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

    var by_fiber = try backend_state.eventsByFiber(std.testing.allocator, 42);
    defer by_fiber.deinit();
    try std.testing.expectEqual(@as(usize, 1), by_fiber.events.len);
    try std.testing.expectEqual(@as(?u64, 42), by_fiber.events[0].fiber_id);
}

test "nendb storage writer failure fails closed without local history" {
    var fake = FakeNendbWriter.init(std.testing.allocator);
    defer fake.deinit();
    fake.fail_next = true;
    var backend_state = fx.CausalNendbStorageBackendState.init(std.testing.allocator, fake.writer(), .{});
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const id = try store.record(.{
        .kind = .run_started,
        .label = "writer-failure",
    });

    try std.testing.expectEqual(@as(u64, 1), id);
    try std.testing.expectEqual(@as(usize, 0), fake.writes.items.len);
    try std.testing.expectEqual(@as(usize, 0), backend_state.eventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.writtenEventCount());
    try std.testing.expectEqual(@as(u64, 1), backend_state.failedEventCount());
    try std.testing.expectEqual(@as(u64, 1), store.backendFailureCount());

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expectEqual(id, snapshot.events[0].id);
}

test "nendb storage max_events fails before writer call" {
    var fake = FakeNendbWriter.init(std.testing.allocator);
    defer fake.deinit();
    var backend_state = fx.CausalNendbStorageBackendState.init(std.testing.allocator, fake.writer(), .{ .max_events = 0 });
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    _ = try store.record(.{
        .kind = .run_started,
        .label = "overflowing-nendb-storage",
    });

    try std.testing.expectEqual(@as(usize, 0), fake.writes.items.len);
    try std.testing.expectEqual(@as(usize, 0), backend_state.eventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.writtenEventCount());
    try std.testing.expectEqual(@as(u64, 1), backend_state.failedEventCount());
    try std.testing.expectEqual(@as(u64, 1), store.backendFailureCount());
}

test "nendb storage backend flush invokes optional writer hook" {
    var fake = FakeNendbWriter.init(std.testing.allocator);
    defer fake.deinit();
    var backend_state = fx.CausalNendbStorageBackendState.init(std.testing.allocator, fake.writer(), .{});
    defer backend_state.deinit();

    try backend_state.flush();
    try std.testing.expectEqual(@as(u64, 1), fake.flush_count);
    try std.testing.expectEqual(@as(u64, 1), backend_state.flushedCount());
}
```

Add this import to `packages/zigeffect/test/all_test.zig` after the graph
history backend import:

```zig
    _ = @import("causal_nendb_storage_backend_test.zig");
```

- [ ] **Step 2: Run the red check**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
```

Expected: FAIL because `fx.CausalNendbStorageBackendState` and related public
NenDB storage symbols do not exist yet.

- [ ] **Step 3: Commit the red tests**

```bash
git add packages/zigeffect/test/causal_nendb_storage_backend_test.zig packages/zigeffect/test/all_test.zig
git commit -m "test(zigeffect): specify causal nendb storage backend"
```

## Task 2: Implement The NenDB Storage Backend

**Files:**
- Create: `packages/zigeffect/src/services/causal_nendb_storage_backend.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add the NenDB storage backend module**

Create `packages/zigeffect/src/services/causal_nendb_storage_backend.zig`.

Implementation requirements:

- Define `CausalNendbNode`, `CausalNendbEdge`, `CausalNendbWrite`, and
  `CausalNendbGraphWriter`.
- Define schema constants:
  - `causal_nendb_node_schema = "zigeffect.causal.nendb_node.v1"`
  - `causal_nendb_edge_schema = "zigeffect.causal.nendb_edge.v1"`
  - version `1` for both schemas.
- Define stable hash helpers:
  - `stableCausalNendbLabelId(value) u8`
  - `stableCausalNendbEdgeLabelId(value) u16`
- Define `mapCausalEventToNendbWrite`, `cloneCausalNendbWrite`, and
  `deinitCausalNendbWrite`.
- Implement JSON property formatting with the same escaping behavior as JSONL.
- Implement `CausalNendbStorageBackendState` with:
  - `.backend()` returning kind `.nendb_graph`;
  - fail-closed writer-first recording;
  - local query helpers matching `CausalGraphHistoryBackendState`;
  - `flush()` invoking the optional writer flush hook.

- [ ] **Step 2: Export the NenDB storage backend**

In `packages/zigeffect/src/zigeffect.zig`, add the service import beside the
other causal backend imports:

```zig
    pub const causal_nendb_storage_backend = @import("services/causal_nendb_storage_backend.zig");
```

Inside `services`, expose:

```zig
    pub const CausalNendbNode = causal_nendb_storage_backend.CausalNendbNode;
    pub const CausalNendbEdge = causal_nendb_storage_backend.CausalNendbEdge;
    pub const CausalNendbWrite = causal_nendb_storage_backend.CausalNendbWrite;
    pub const CausalNendbGraphWriter = causal_nendb_storage_backend.CausalNendbGraphWriter;
    pub const CausalNendbStorageBackendOptions = causal_nendb_storage_backend.CausalNendbStorageBackendOptions;
    pub const CausalNendbStorageBackendError = causal_nendb_storage_backend.CausalNendbStorageBackendError;
    pub const CausalNendbStorageBackendState = causal_nendb_storage_backend.CausalNendbStorageBackendState;
    pub const causal_nendb_node_schema = causal_nendb_storage_backend.causal_nendb_node_schema;
    pub const causal_nendb_node_schema_version = causal_nendb_storage_backend.causal_nendb_node_schema_version;
    pub const causal_nendb_edge_schema = causal_nendb_storage_backend.causal_nendb_edge_schema;
    pub const causal_nendb_edge_schema_version = causal_nendb_storage_backend.causal_nendb_edge_schema_version;
    pub const stableCausalNendbLabelId = causal_nendb_storage_backend.stableCausalNendbLabelId;
    pub const stableCausalNendbEdgeLabelId = causal_nendb_storage_backend.stableCausalNendbEdgeLabelId;
    pub const mapCausalEventToNendbWrite = causal_nendb_storage_backend.mapCausalEventToNendbWrite;
    pub const cloneCausalNendbWrite = causal_nendb_storage_backend.cloneCausalNendbWrite;
    pub const deinitCausalNendbWrite = causal_nendb_storage_backend.deinitCausalNendbWrite;
```

Add matching root-level exports near the other backend aliases.

- [ ] **Step 3: Add the focused build gate**

In `packages/zigeffect/build.zig`, add a test module after the graph-history
backend test step:

```zig
    const causal_nendb_storage_backend_test_module = b.createModule(.{
        .root_source_file = b.path("test/causal_nendb_storage_backend_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_nendb_storage_backend_test_module.addImport("zigeffect", zigeffect);

    const causal_nendb_storage_backend_tests = b.addTest(.{
        .name = "zigeffect-causal-nendb-storage-backend-tests",
        .root_module = causal_nendb_storage_backend_test_module,
    });
    const run_causal_nendb_storage_backend_tests = b.addRunArtifact(causal_nendb_storage_backend_tests);
    const causal_nendb_storage_backend_step = b.step("causal-nendb-storage-backend", "Run causal NenDB storage backend tests");
    causal_nendb_storage_backend_step.dependOn(&run_causal_nendb_storage_backend_tests.step);
```

Add the focused tests to the package `test` dependencies:

```zig
    test_step.dependOn(&run_causal_nendb_storage_backend_tests.step);
```

- [ ] **Step 4: Run the focused green check**

Run:

```bash
cd packages/zigeffect
zig build causal-nendb-storage-backend
```

Expected: PASS.

- [ ] **Step 5: Run package checks**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
zig build test --summary none
```

Expected: both PASS.

- [ ] **Step 6: Commit the implementation**

```bash
git add packages/zigeffect/src/services/causal_nendb_storage_backend.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): add causal nendb storage backend"
```

## Task 3: Document The NenDB Storage Adapter

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update README backend guidance**

After the graph-history backend paragraph, add a NenDB storage paragraph that
states:

- `fx.CausalNendbStorageBackendState` maps stored causal events to
  NenDB-shaped node and parent-edge writes through `CausalNendbGraphWriter`.
- This branch does not add a direct upstream NenDB dependency because upstream
  package shape is not stable enough for the current Zig build.
- Use `zig build causal-nendb-storage-backend` for the focused gate.

- [ ] **Step 2: Update the agent guide**

Add guidance that agents should use:

- graph-history backend for scan-only local history;
- NenDB storage backend when they need to verify the event-to-NenDB graph write
  contract;
- failure counters to decide whether graph storage evidence is complete.

- [ ] **Step 3: Update the agent-observable runtime doc**

Add a concrete `CausalNendbStorageBackendState` paragraph near the
`nendb_graph` backend section. It should mention:

- deterministic node/edge mapping;
- injected writer;
- no direct dependency yet;
- future wrapper target: `nendb.EmbeddedDB.addNode`, `addEdge`, `flush`.

- [ ] **Step 4: Update the master roadmap ledger**

Update M4 evidence to include the NenDB storage adapter and set the next action
to async stream adapter design.

- [ ] **Step 5: Run docs diff check**

Run:

```bash
git diff --check
```

Expected: no whitespace errors.

- [ ] **Step 6: Commit docs**

```bash
git add packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): document causal nendb storage backend"
```

## Task 4: Final Verification And Merge

**Files:**
- Verify branch state only.

- [ ] **Step 1: Run focused backend gates**

Run:

```bash
cd packages/zigeffect
zig build causal-nendb-storage-backend
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
git merge --ff-only codex/zigeffect-causal-nendb-storage-adapter
git branch -d codex/zigeffect-causal-nendb-storage-adapter
```

Expected: fast-forward merge succeeds and branch deletes cleanly.

- [ ] **Step 4: Run post-merge smoke verification**

Run:

```bash
cd packages/zigeffect
zig build causal-nendb-storage-backend
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
git switch -c codex/zigeffect-causal-async-stream-backend
```

Expected: new feature branch is created from verified `master`.

## Self-Review

- Spec coverage: The tasks cover NenDB writer mapping, fake writer behavior,
  retention-independent queries, fail-closed writer errors, max-event preflight,
  flush, docs, roadmap updates, verification, and merge.
- Red-flag scan: No placeholder task names or vague test-only instructions
  remain; implementation details are named by public API and behavior.
- Type consistency: Public API names match the design:
  `CausalNendbGraphWriter`, `CausalNendbWrite`,
  `CausalNendbStorageBackendState`, `mapCausalEventToNendbWrite`,
  `cloneCausalNendbWrite`, and `deinitCausalNendbWrite`.
