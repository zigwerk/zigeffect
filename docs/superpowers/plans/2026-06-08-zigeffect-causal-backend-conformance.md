# zigeffect Causal Backend Conformance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable causal backend conformance harness and observable backend failure metadata before implementing durable backend adapters.

**Architecture:** Keep the production `CausalBackend` callback API unchanged. Add test-support fixtures that future adapter tests can reuse, add a direct `zig build causal-backend-conformance` step, and make backend write failures visible in reports and JSON without perturbing the deterministic in-memory store.

**Tech Stack:** Zig stdlib, zigeffect causal runtime, package build steps, Bun repo verification.

---

## File Structure

- Create `packages/zigeffect/test/support/causal_backend_conformance.zig`
  - Reusable standard trace helpers.
  - A copying capture backend fixture.
  - A failing backend fixture.
- Create `packages/zigeffect/test/causal_backend_conformance_test.zig`
  - Contract tests for stored-event forwarding, sampling, retention, redaction,
    truncation, and backend failure counting.
- Modify `packages/zigeffect/test/all_test.zig`
  - Import the new conformance test file in the raw package test suite.
- Modify `packages/zigeffect/src/services/causal.zig`
  - Count backend write failures.
  - Emit backend metadata in text, CI, and JSON reports.
- Modify `packages/zigeffect/build.zig`
  - Add `causal-backend-conformance` build step.
  - Make the causal package test step depend on the conformance tests.
- Modify docs:
  - `packages/zigeffect/README.md`
  - `packages/zigeffect/docs/agent-guide.md`
  - `packages/zigeffect/docs/agent-observable-runtime.md`
  - `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

---

### Task 1: Add RED Backend Conformance Tests

**Files:**
- Create: `packages/zigeffect/test/causal_backend_conformance_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Add the conformance test file**

```zig
const std = @import("std");
const fx = @import("zigeffect");
const conformance = @import("support/causal_backend_conformance.zig");

test "causal backend conformance captures only stored sanitized events" {
    var backend_state = conformance.CaptureBackendState.init(std.testing.allocator);
    defer backend_state.deinit();

    var store = fx.CausalStore.initWithOptions(std.testing.allocator, conformance.standardStoreOptions());
    store.attachBackend(backend_state.backend(.memory));
    defer store.deinit();

    const ids = try conformance.recordStandardTrace(&store);
    try conformance.expectStandardStorePosture(&store, ids);

    try std.testing.expectEqual(@as(usize, 3), backend_state.events.items.len);
    try std.testing.expectEqual(ids.started, backend_state.events.items[0].id);
    try std.testing.expectEqual(ids.retained_log, backend_state.events.items[1].id);
    try std.testing.expectEqual(ids.completed, backend_state.events.items[2].id);
    try std.testing.expectEqual(fx.CausalEventKind.run_started, backend_state.events.items[0].kind);
    try std.testing.expectEqual(fx.CausalEventKind.log_recorded, backend_state.events.items[1].kind);
    try std.testing.expectEqual(fx.CausalEventKind.run_completed, backend_state.events.items[2].kind);
    try std.testing.expect(std.mem.indexOf(u8, backend_state.events.items[0].label, "raw-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, backend_state.events.items[0].label, fx.causal_redaction_marker) != null);
    try std.testing.expect(std.mem.indexOf(u8, backend_state.events.items[0].label, fx.causal_truncation_marker) != null);
    try std.testing.expect(backend_state.events.items[0].label.len <= conformance.standard_max_event_string_bytes);
}

test "causal backend conformance counts backend failures without perturbing store" {
    var backend_state = conformance.FailingBackendState{};

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend(.json_lines));
    defer store.deinit();

    const first = try store.record(.{ .kind = .run_started, .label = "failing-backend" });
    const second = try store.record(.{
        .kind = .run_completed,
        .parent_id = first,
        .label = "failing-backend",
        .status = "success",
    });

    try std.testing.expectEqual(@as(u64, 2), second);
    try std.testing.expectEqual(@as(u64, 2), backend_state.attempted_count);
    try std.testing.expectEqual(@as(u64, 2), store.backendFailureCount());

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 2), snapshot.events.len);
    try std.testing.expectEqual(first, snapshot.events[0].id);
    try std.testing.expectEqual(second, snapshot.events[1].id);

    const report = try fx.formatCausalReport(std.testing.allocator, "backend failure", &store);
    defer std.testing.allocator.free(report);
    try std.testing.expect(std.mem.indexOf(u8, report, "backend: kind=json_lines failed_writes=2") != null);

    const ci_report = try fx.formatCausalCiReport(std.testing.allocator, "backend failure", &store);
    defer std.testing.allocator.free(ci_report);
    try std.testing.expect(std.mem.indexOf(u8, ci_report, "backend: kind=json_lines failed_writes=2") != null);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"backend\": {") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"kind\": \"json_lines\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"failed_writes\": 2") != null);
}
```

- [ ] **Step 2: Import the test file**

Add to `packages/zigeffect/test/all_test.zig`:

```zig
    _ = @import("causal_backend_conformance_test.zig");
```

- [ ] **Step 3: Run raw package tests and verify RED**

```bash
cd packages/zigeffect && zig build test-raw --summary none
```

Expected: FAIL because `support/causal_backend_conformance.zig` and `backendFailureCount` do not exist.

---

### Task 2: Implement Reusable Test-Support Backends

**Files:**
- Create: `packages/zigeffect/test/support/causal_backend_conformance.zig`

- [ ] **Step 1: Add the support module**

```zig
const std = @import("std");
const fx = @import("zigeffect");

pub const standard_max_event_string_bytes: usize = 32;

pub const StandardTraceIds = struct {
    started: u64,
    sampled_log: u64,
    retained_log: u64,
    completed: u64,
};

pub fn standardStoreOptions() fx.CausalStoreOptions {
    return .{
        .max_events = 1,
        .sampling = .{ .log_every_n = 2 },
        .max_event_string_bytes = standard_max_event_string_bytes,
    };
}
```

- [ ] **Step 2: Add string/event clone helpers**

```zig
fn cloneSlice(allocator: std.mem.Allocator, value: []const u8) ![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

fn cloneEvent(allocator: std.mem.Allocator, event: fx.CausalEvent) !fx.CausalEvent {
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

fn deinitEventStrings(allocator: std.mem.Allocator, event: fx.CausalEvent) void {
    if (event.label.len > 0) allocator.free(event.label);
    if (event.type_name.len > 0) allocator.free(event.type_name);
    if (event.status.len > 0) allocator.free(event.status);
    if (event.redacted_detail.len > 0) allocator.free(event.redacted_detail);
}
```

- [ ] **Step 3: Add the capture backend**

```zig
pub const CaptureBackendState = struct {
    allocator: std.mem.Allocator,
    events: std.ArrayList(fx.CausalEvent) = .empty,

    pub fn init(allocator: std.mem.Allocator) CaptureBackendState {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *CaptureBackendState) void {
        for (self.events.items) |event| {
            deinitEventStrings(self.allocator, event);
        }
        self.events.deinit(self.allocator);
    }

    pub fn backend(self: *CaptureBackendState, kind: fx.CausalBackendKind) fx.CausalBackend {
        return .{
            .kind = kind,
            .state = self,
            .record = recordCaptureBackend,
        };
    }
};

fn recordCaptureBackend(raw: ?*anyopaque, event: fx.CausalEvent) anyerror!void {
    const state: *CaptureBackendState = @ptrCast(@alignCast(raw.?));
    const owned = try cloneEvent(state.allocator, event);
    errdefer deinitEventStrings(state.allocator, owned);
    try state.events.append(state.allocator, owned);
}
```

- [ ] **Step 4: Add the failing backend**

```zig
pub const FailingBackendState = struct {
    attempted_count: u64 = 0,

    pub fn backend(self: *FailingBackendState, kind: fx.CausalBackendKind) fx.CausalBackend {
        return .{
            .kind = kind,
            .state = self,
            .record = recordFailingBackend,
        };
    }
};

fn recordFailingBackend(raw: ?*anyopaque, event: fx.CausalEvent) anyerror!void {
    _ = event;
    const state: *FailingBackendState = @ptrCast(@alignCast(raw.?));
    state.attempted_count += 1;
    return error.CausalBackendWriteFailed;
}
```

- [ ] **Step 5: Add standard trace helpers**

```zig
pub fn recordStandardTrace(store: *fx.CausalStore) !StandardTraceIds {
    const run_id = store.nextRunId();
    const started = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .label = "token=raw-secret safe-context-safe-context-safe-context",
        .type_name = "BackendConformanceRun",
    });
    const sampled_log = try store.record(.{
        .kind = .log_recorded,
        .run_id = run_id,
        .parent_id = started,
        .label = "sampled-out-log",
    });
    const retained_log = try store.record(.{
        .kind = .log_recorded,
        .run_id = run_id,
        .parent_id = started,
        .label = "retained-log",
    });
    const completed = try store.record(.{
        .kind = .run_completed,
        .run_id = run_id,
        .parent_id = started,
        .label = "backend-conformance-completed",
        .status = "success",
    });

    return .{
        .started = started,
        .sampled_log = sampled_log,
        .retained_log = retained_log,
        .completed = completed,
    };
}

pub fn expectStandardStorePosture(store: *const fx.CausalStore, ids: StandardTraceIds) !void {
    try std.testing.expectEqual(@as(u64, 2), store.droppedEventCount());
    try std.testing.expectEqual(@as(u64, 1), store.sampledEventCount());
    try std.testing.expectEqual(@as(u64, 1), store.truncatedFieldCount());
    try std.testing.expectEqual(@as(u64, 0), store.backendFailureCount());
    try std.testing.expectEqual(@as(?u64, ids.completed), store.oldestRetainedEventId());
    try std.testing.expectEqual(ids.started + 1, ids.sampled_log);
    try std.testing.expectEqual(ids.started + 2, ids.retained_log);
    try std.testing.expectEqual(ids.started + 3, ids.completed);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expectEqual(ids.completed, snapshot.events[0].id);
}
```

- [ ] **Step 6: Run raw tests and keep RED**

```bash
cd packages/zigeffect && zig build test-raw --summary none
```

Expected: still FAIL because `CausalStore.backendFailureCount` and backend report/JSON metadata do not exist.

---

### Task 3: Implement Backend Failure Metadata

**Files:**
- Modify: `packages/zigeffect/src/services/causal.zig`

- [ ] **Step 1: Add store state and accessors**

Add to `CausalStore`:

```zig
backend_failure_count: u64 = 0,
```

Add accessors near the other count accessors:

```zig
pub fn backendFailureCount(self: *const CausalStore) u64 {
    return self.backend_failure_count;
}

pub fn attachedBackendKind(self: *const CausalStore) ?causal_backend.CausalBackendKind {
    if (self.backend) |backend| return backend.kind;
    return null;
}
```

- [ ] **Step 2: Count backend write failures**

Replace:

```zig
backend.record(backend.state, owned) catch {};
```

with:

```zig
backend.record(backend.state, owned) catch {
    self.backend_failure_count += 1;
};
```

- [ ] **Step 3: Add backend text summary**

Place after `appendTruncationSummary`:

```zig
fn appendBackendSummary(output: *std.ArrayList(u8), allocator: Allocator, store: *const CausalStore) Allocator.Error!void {
    try output.appendSlice(allocator, "backend: kind=");
    if (store.attachedBackendKind()) |kind| {
        try output.appendSlice(allocator, @tagName(kind));
    } else {
        try output.appendSlice(allocator, "none");
    }
    try output.print(allocator, " failed_writes={d}\n", .{store.backend_failure_count});
}
```

Call `appendBackendSummary` after `appendTruncationSummary` in both
`formatCausalReport` and `formatCausalCiReport`.

- [ ] **Step 4: Add backend JSON metadata**

In `formatCausalJson`, after the `truncation` object and before `events`, emit:

```zig
try output.appendSlice(allocator, "  },\n  \"backend\": {\n    \"kind\": ");
if (store.attachedBackendKind()) |kind| {
    try appendJsonString(&output, allocator, @tagName(kind));
} else {
    try output.appendSlice(allocator, "null");
}
try output.print(allocator, ",\n    \"failed_writes\": {d}\n", .{store.backend_failure_count});
try output.appendSlice(allocator, "  },\n  \"events\": [\n");
```

Replace the old direct transition from `truncation` to `events`.

- [ ] **Step 5: Run raw tests and verify GREEN**

```bash
cd packages/zigeffect && zig build test-raw --summary none
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/zigeffect/src/services/causal.zig packages/zigeffect/test/all_test.zig packages/zigeffect/test/causal_backend_conformance_test.zig packages/zigeffect/test/support/causal_backend_conformance.zig
git commit -m "feat(zigeffect): add causal backend conformance fixtures"
```

---

### Task 4: Add The Direct Build Step

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add the test module near the raw unit test setup**

```zig
const causal_backend_conformance_test_module = b.createModule(.{
    .root_source_file = b.path("test/causal_backend_conformance_test.zig"),
    .target = target,
    .optimize = optimize,
});
causal_backend_conformance_test_module.addImport("zigeffect", zigeffect);

const causal_backend_conformance_tests = b.addTest(.{
    .name = "zigeffect-causal-backend-conformance-tests",
    .root_module = causal_backend_conformance_test_module,
});
const run_causal_backend_conformance_tests = b.addRunArtifact(causal_backend_conformance_tests);
const causal_backend_conformance_step = b.step("causal-backend-conformance", "Run causal backend conformance contract tests");
causal_backend_conformance_step.dependOn(&run_causal_backend_conformance_tests.step);
```

- [ ] **Step 2: Add the conformance test to package test gate**

After `test_step` is created, add:

```zig
test_step.dependOn(&run_causal_backend_conformance_tests.step);
```

- [ ] **Step 3: Run the direct build step**

```bash
cd packages/zigeffect && zig build causal-backend-conformance
```

Expected: PASS.

- [ ] **Step 4: Run causal package test gate**

```bash
cd packages/zigeffect && zig build test --summary none
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/build.zig
git commit -m "build(zigeffect): add causal backend conformance gate"
```

---

### Task 5: Update Docs And Roadmap

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update causal JSON root examples**

Add after the `truncation` root object:

```json
  "backend": {
    "kind": null,
    "failed_writes": 0
  },
```

- [ ] **Step 2: Document backend failure interpretation**

Use this wording in README and agent guide near backend/sink guidance:

```markdown
Backend adapters are sinks, not the source of truth. If `failed_writes` is
nonzero, the deterministic in-memory causal trace is still usable, but backend
durability or export evidence may be incomplete. Future backend adapter branches
must run `zig build causal-backend-conformance` before claiming adapter
compatibility.
```

- [ ] **Step 3: Update the agent-observable runtime storage section**

Add:

```markdown
`zig build causal-backend-conformance` is the adapter contract gate. It proves
that a backend sees assigned, redacted, bounded stored events; does not receive
sampled-out events; can observe events before retention drops them; and cannot
make the deterministic store fail when a backend write fails.
```

- [ ] **Step 4: Update the master roadmap ledger**

Change M4:

```markdown
| M4 Durable backends | in progress | backend boundary and reusable conformance suite exist | implement JSONL backend first |
```

Change the immediate branch queue to:

```markdown
1. `codex/zigeffect-causal-jsonl-backend`
   - Implement the first production-grade sink behind the conformance contract.
```

- [ ] **Step 5: Run diff check and commit**

```bash
git diff --check
git add packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): document causal backend conformance"
```

---

### Task 6: Final Verification And Merge

**Files:**
- Verify only; no edits unless a command exposes a real issue.

- [ ] **Step 1: Run focused package verification**

```bash
cd packages/zigeffect && zig build causal-backend-conformance
cd packages/zigeffect && zig build test-raw --summary none
cd packages/zigeffect && zig build test --summary none
cd packages/zigeffect && zig build causal-test-matrix
cd packages/zigeffect && zig build examples
```

Expected: all commands exit 0.

- [ ] **Step 2: Run repo verification**

```bash
bun run check
bun run zig:test
git diff --check HEAD
```

Expected: all commands exit 0.

- [ ] **Step 3: Confirm scope**

```bash
git status --short
git diff --name-only master...HEAD
```

Expected:

- the unrelated untracked durable-workflows plan remains untracked;
- branch diff contains only backend-conformance design, plan, runtime, tests,
  build, docs, and roadmap files.

- [ ] **Step 4: Merge**

```bash
git switch master
git merge --ff-only codex/zigeffect-causal-backend-conformance
git branch -d codex/zigeffect-causal-backend-conformance
```

- [ ] **Step 5: Re-run post-merge verification**

```bash
cd packages/zigeffect && zig build causal-backend-conformance
cd packages/zigeffect && zig build test --summary none
bun run check
bun run zig:test
git diff --check HEAD
```

Expected: all commands exit 0.

---

## Self-Review Checklist

- The production backend callback shape remains unchanged.
- The conformance harness is reusable by future adapter tests.
- Backend failures are observable but do not perturb `CausalStore.record`.
- Sampling, retention, redaction, and truncation are covered by the standard
  backend trace.
- JSON changes are additive under `zigeffect.causal.v1`.
- The unrelated durable-workflows plan remains untouched.
