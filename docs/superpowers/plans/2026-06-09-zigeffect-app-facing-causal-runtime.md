# zigeffect App-Facing Causal Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first M7 app-facing causal runtime adapter so request and background-job incidents emit bounded, redacted, workbench-compatible causal events.

**Architecture:** Add a focused `causal_app_runtime` service module that wraps a caller-owned `CausalStore`, records app lifecycle facts as existing causal event kinds, and exports through the existing `formatCausalJson` path. Keep SolidJS + `zig-webui` as the viewer by preserving `zigeffect.causal.v1` artifact compatibility.

**Tech Stack:** Zig standard library, existing `CausalStore`, existing causal JSON/workbench tooling, Bun only for workbench verification.

---

## File Structure

- Create `packages/zigeffect/src/services/causal_app_runtime.zig`
  - Owns app trace defaults, request/job trace start helpers, and lifecycle
    event mapping methods.
- Create `packages/zigeffect/test/causal_app_runtime_test.zig`
  - Covers request defaults, job defaults, app lifecycle mapping, findings, and
    redaction through exported JSON.
- Modify `packages/zigeffect/src/zigeffect.zig`
  - Re-export the module, schema constants, types, defaults, and helper
    functions.
- Modify `packages/zigeffect/test/all_test.zig`
  - Include the app runtime tests in the aggregate test suite.
- Modify `packages/zigeffect/build.zig`
  - Add a `causal-app-runtime` test step and include it in the default
    `test` dependency chain.
- Modify `packages/zigeffect/README.md`
  - Document the app-facing request/job adapter at the existing causal runtime
    usage surface.
- Modify `packages/zigeffect/docs/agent-observable-runtime.md` and
  `packages/zigeffect/docs/agent-guide.md`
  - Add concise M7 guidance for app request/job traces and workbench usage.
- Modify
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark the app-facing runtime foundation branch as active/delivered after
    implementation evidence exists.

## Task 1: RED Request/Job Adapter Tests

**Files:**
- Create: `packages/zigeffect/test/causal_app_runtime_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Write the failing app runtime tests**

```zig
const std = @import("std");
const fx = @import("zigeffect");

fn hasEvent(
    snapshot: fx.CausalSnapshot,
    kind: fx.CausalEventKind,
    label_substring: []const u8,
    status: []const u8,
) bool {
    for (snapshot.events) |event| {
        if (event.kind == kind and
            std.mem.indexOf(u8, event.label, label_substring) != null and
            std.mem.eql(u8, event.status, status))
        {
            return true;
        }
    }
    return false;
}

test "app request trace records bounded workbench-compatible lifecycle events" {
    const options = fx.defaultRequestCausalStoreOptions();
    try std.testing.expectEqual(@as(?usize, fx.default_request_max_events), options.max_events);
    try std.testing.expectEqual(@as(?usize, fx.default_app_max_event_string_bytes), options.max_event_string_bytes);

    var store = fx.CausalStore.initWithOptions(std.testing.allocator, options);
    defer store.deinit();

    var trace = try fx.CausalAppTrace.startRequest(&store, .{
        .method = "GET",
        .route = "/api/projects/:id",
        .runtime = "worker",
        .trace_id = 42,
    });
    try trace.recordServiceResolution("ProjectService", "satisfied");
    const scope_id = try trace.openScope("request scope");
    try trace.recordResourceAcquired("hyperdrive connection", scope_id);
    try trace.recordRetryAttempt("load project", 2, 3, "retrying");
    try trace.recordResourceFinalized("hyperdrive connection", scope_id, "success");
    try trace.closeScope(scope_id, "success");
    try trace.complete(.success);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expect(hasEvent(snapshot, .run_started, "app.request GET /api/projects/:id", "started"));
    try std.testing.expect(hasEvent(snapshot, .service_required, "ProjectService", "satisfied"));
    try std.testing.expect(hasEvent(snapshot, .scope_opened, "request scope", "opened"));
    try std.testing.expect(hasEvent(snapshot, .resource_acquired, "hyperdrive connection", "success"));
    try std.testing.expect(hasEvent(snapshot, .schedule_decision, "load project", "retrying"));
    try std.testing.expect(hasEvent(snapshot, .resource_finalized, "hyperdrive connection", "success"));
    try std.testing.expect(hasEvent(snapshot, .scope_closed, "request scope", "success"));
    try std.testing.expect(hasEvent(snapshot, .run_completed, "app.request GET /api/projects/:id", "success"));

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\": \"zigeffect.causal.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "ProjectService") != null);
}

test "app request trace records config and requirement failures as causal findings" {
    var store = fx.CausalStore.initWithOptions(std.testing.allocator, fx.defaultRequestCausalStoreOptions());
    defer store.deinit();

    var trace = try fx.CausalAppTrace.startRequest(&store, .{
        .method = "POST",
        .route = "/api/projects",
        .runtime = "worker",
    });
    try trace.recordConfigFailure("database.password", "MissingConfig");
    try trace.recordRequirementFailure("ProjectRepository", "MissingService");
    try trace.complete(.failure);

    var findings = try store.findings(std.testing.allocator);
    defer findings.deinit();

    try std.testing.expectEqual(@as(usize, 2), findings.items.len);
    try std.testing.expectEqual(fx.CausalFindingKind.assertion_failure, findings.items[0].kind);
    try std.testing.expectEqual(fx.CausalFindingKind.assertion_failure, findings.items[1].kind);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "database.password") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "ProjectRepository") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "MissingConfig") != null);
}

test "app trace redacts accidental sensitive values before JSON export" {
    var store = fx.CausalStore.initWithOptions(std.testing.allocator, fx.defaultRequestCausalStoreOptions());
    defer store.deinit();

    var trace = try fx.CausalAppTrace.startRequest(&store, .{
        .method = "GET",
        .route = "/api/private",
        .runtime = "worker",
    });
    try trace.recordRequirementFailure("Authorization token=raw-secret", "Rejected");
    try trace.complete(.failure);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, fx.causal_redaction_marker) != null);
}

test "app background job trace uses job defaults and distinct lifecycle labels" {
    const options = fx.defaultJobCausalStoreOptions();
    try std.testing.expectEqual(@as(?usize, fx.default_job_max_events), options.max_events);

    var store = fx.CausalStore.initWithOptions(std.testing.allocator, options);
    defer store.deinit();

    var trace = try fx.CausalAppTrace.startJob(&store, .{
        .job_name = "daily-rollup",
        .runtime = "worker-cron",
        .trace_id = 99,
    });
    try trace.recordLayerConstruction("RollupLayer", "success");
    try trace.recordFiberStatus("rollup fiber", 7, .started);
    try trace.recordFiberStatus("rollup fiber", 7, .success);
    try trace.complete(.success);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expect(hasEvent(snapshot, .run_started, "app.job daily-rollup", "started"));
    try std.testing.expect(hasEvent(snapshot, .layer_completed, "RollupLayer", "success"));
    try std.testing.expect(hasEvent(snapshot, .fiber_started, "rollup fiber", "started"));
    try std.testing.expect(hasEvent(snapshot, .fiber_joined, "rollup fiber", "success"));
    try std.testing.expect(hasEvent(snapshot, .run_completed, "app.job daily-rollup", "success"));
}
```

- [ ] **Step 2: Include the test in aggregate and build steps**

In `packages/zigeffect/test/all_test.zig` add:

```zig
    _ = @import("causal_app_runtime_test.zig");
```

In `packages/zigeffect/build.zig`, add a module/test/step named
`causal-app-runtime` following the existing `causal-async-stream-backend`
pattern and make the default `test` step depend on it.

- [ ] **Step 3: Run test to verify RED**

Run:

```bash
cd packages/zigeffect && zig build causal-app-runtime
```

Expected: FAIL because `defaultRequestCausalStoreOptions`,
`CausalAppTrace`, and related constants are not exported yet.

## Task 2: GREEN Adapter Module And Exports

**Files:**
- Create: `packages/zigeffect/src/services/causal_app_runtime.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Implement the app runtime adapter**

Implement the constants, option structs, start helpers, and lifecycle mapping
methods specified in the design. Use only `std`, `causal.zig`, and
`CausalStore.record`.

- [ ] **Step 2: Export the module from `src/zigeffect.zig`**

Add the service import under `services`, then top-level aliases for:

```zig
pub const CausalAppTraceKind = services.causal_app_runtime.CausalAppTraceKind;
pub const CausalAppStatus = services.causal_app_runtime.CausalAppStatus;
pub const CausalAppTraceOptions = services.causal_app_runtime.CausalAppTraceOptions;
pub const CausalAppTrace = services.causal_app_runtime.CausalAppTrace;
pub const causal_app_runtime_schema = services.causal_app_runtime.causal_app_runtime_schema;
pub const causal_app_runtime_schema_version = services.causal_app_runtime.causal_app_runtime_schema_version;
pub const default_request_max_events = services.causal_app_runtime.default_request_max_events;
pub const default_job_max_events = services.causal_app_runtime.default_job_max_events;
pub const default_app_max_event_string_bytes = services.causal_app_runtime.default_app_max_event_string_bytes;
pub const defaultRequestCausalStoreOptions = services.causal_app_runtime.defaultRequestCausalStoreOptions;
pub const defaultJobCausalStoreOptions = services.causal_app_runtime.defaultJobCausalStoreOptions;
```

- [ ] **Step 3: Run test to verify GREEN**

Run:

```bash
cd packages/zigeffect && zig build causal-app-runtime
```

Expected: PASS.

## Task 3: Documentation And Roadmap Update

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Document app-facing request/job traces**

Add concise docs that show:

```zig
var store = fx.CausalStore.initWithOptions(allocator, fx.defaultRequestCausalStoreOptions());
var trace = try fx.CausalAppTrace.startRequest(&store, .{
    .method = "GET",
    .route = "/api/projects/:id",
    .runtime = "worker",
});
try trace.recordServiceResolution("ProjectService", "satisfied");
try trace.complete(.success);
const json = try fx.formatCausalJson(allocator, &store);
```

Explain that artifacts open in:

```bash
zig build causal-workbench -- .zig-cache/causal-artifacts/<app-incident>.json
```

- [ ] **Step 2: Update the master roadmap**

Mark M7 as active with the request/job foundation delivered on branch
`codex/zigeffect-app-facing-causal-runtime`; leave app remediation gates
deferred to M8.

- [ ] **Step 3: Run focused verification**

Run:

```bash
cd packages/zigeffect && zig build causal-app-runtime
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
```

Expected: all commands exit 0.

## Task 4: Final Verification And Commit

**Files:**
- All changed files in this plan.

- [ ] **Step 1: Run full verification**

Run:

```bash
cd packages/zigeffect && zig build test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 2: Commit implementation**

Run:

```bash
git add docs/superpowers/specs/2026-06-09-zigeffect-app-facing-causal-runtime-design.md docs/superpowers/plans/2026-06-09-zigeffect-app-facing-causal-runtime.md packages/zigeffect/src/services/causal_app_runtime.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/causal_app_runtime_test.zig packages/zigeffect/test/all_test.zig packages/zigeffect/build.zig packages/zigeffect/README.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/docs/agent-guide.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): add app-facing causal runtime adapter"
```

## Plan Self-Review

- Spec coverage: request adapter, job adapter, app lifecycle mapping, bounded
  defaults, redaction, and SolidJS/WebUI workbench compatibility are covered.
- Placeholder scan: no deferred implementation steps are left unspecified for
  this branch.
- Type consistency: tests, exports, and module names all use
  `CausalAppTrace` and `causal_app_runtime`.
