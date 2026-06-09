# zigeffect App Incident Mapping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add app incident classification and app-aware advice/diagnosis mappings for artifacts emitted by `CausalAppTrace`.

**Architecture:** Extend `causal_app_runtime` with a pure classifier over existing causal events, then update `causal-advice` and `causal-diagnosis` to prefer app-specific actions when event fields clearly identify app incidents. Preserve standard `zigeffect.causal.v1` artifacts and existing event taxonomy.

**Tech Stack:** Zig standard library, zigeffect `CausalStore`, existing causal advice/diagnosis tools, Bun only for workbench verification.

---

## File Structure

- Modify `packages/zigeffect/src/services/causal_app_runtime.zig`
  - Add incident enum/result container/classifier.
- Modify `packages/zigeffect/src/zigeffect.zig`
  - Re-export incident types and `deriveCausalAppIncidents`.
- Modify `packages/zigeffect/test/causal_app_runtime_test.zig`
  - Add classifier tests for request example and direct app trace incidents.
- Modify `packages/zigeffect/tools/causal_advice.zig`
  - Add app-specific advice actions and tests.
- Modify `packages/zigeffect/tools/causal_diagnosis.zig`
  - Add app action mappings and tests.
- Modify `packages/zigeffect/README.md`,
  `packages/zigeffect/docs/agent-guide.md`,
  `packages/zigeffect/docs/agent-observable-runtime.md`,
  `packages/zigeffect/docs/roadmap.md`, and
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Document app incident mapping and next M8 remediation-audit step.

## Task 1: RED Classifier Tests

**Files:**
- Modify: `packages/zigeffect/test/causal_app_runtime_test.zig`

- [ ] **Step 1: Add failing classifier tests**

Append tests that call the not-yet-existing classifier:

```zig
test "deriveCausalAppIncidents classifies app config requirement and response failures" {
    var store = fx.CausalStore.initWithOptions(std.testing.allocator, fx.defaultRequestCausalStoreOptions());
    defer store.deinit();

    var trace = try fx.CausalAppTrace.startRequest(&store, .{
        .method = "GET",
        .route = "/health",
        .runtime = "worker",
    });
    try trace.recordConfigFailure("YACHDEE_ENV", "MissingConfig");
    try trace.recordRequirementFailure("HealthService", "MissingService");
    _ = try store.record(.{
        .kind = .span_recorded,
        .run_id = trace.run_id,
        .parent_id = trace.root_event_id,
        .label = "app.response",
        .type_name = "zigeffect.app.response",
        .status = "500",
        .redacted_detail = "body=missing_environment",
    });
    try trace.complete(.failure);

    var incidents = try fx.deriveCausalAppIncidents(std.testing.allocator, &store);
    defer incidents.deinit();

    try std.testing.expectEqual(@as(usize, 3), incidents.items.len);
    try std.testing.expectEqual(fx.CausalAppIncidentKind.missing_config, incidents.items[0].kind);
    try std.testing.expectEqual(fx.CausalAppIncidentKind.missing_requirement, incidents.items[1].kind);
    try std.testing.expectEqual(fx.CausalAppIncidentKind.failed_response, incidents.items[2].kind);
    try std.testing.expectEqualStrings("YACHDEE_ENV", incidents.items[0].label);
    try std.testing.expectEqualStrings("HealthService", incidents.items[1].label);
}

test "deriveCausalAppIncidents classifies retry resource and fiber app incidents" {
    var store = fx.CausalStore.initWithOptions(std.testing.allocator, fx.defaultRequestCausalStoreOptions());
    defer store.deinit();

    var trace = try fx.CausalAppTrace.startRequest(&store, .{
        .method = "POST",
        .route = "/api/jobs",
        .runtime = "worker",
    });
    const scope_id = try trace.openScope("app request scope");
    try trace.recordResourceAcquired("app database", scope_id);
    try trace.recordRetryAttempt("upstream call", 3, 3, "exhausted");
    try trace.recordFiberStatus("app child fiber", 77, .started);
    try trace.complete(.failure);

    var incidents = try fx.deriveCausalAppIncidents(std.testing.allocator, &store);
    defer incidents.deinit();

    try std.testing.expectEqual(@as(usize, 3), incidents.items.len);
    try std.testing.expectEqual(fx.CausalAppIncidentKind.resource_leak, incidents.items[0].kind);
    try std.testing.expectEqual(fx.CausalAppIncidentKind.retry_exhausted, incidents.items[1].kind);
    try std.testing.expectEqual(fx.CausalAppIncidentKind.fiber_unresolved, incidents.items[2].kind);
}
```

- [ ] **Step 2: Run RED**

Run:

```bash
cd packages/zigeffect && zig build causal-app-runtime
```

Expected: FAIL because `deriveCausalAppIncidents` and
`CausalAppIncidentKind` are not exported yet.

## Task 2: GREEN Classifier Implementation

**Files:**
- Modify: `packages/zigeffect/src/services/causal_app_runtime.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Implement classifier**

Add `CausalAppIncidentKind`, `CausalAppIncident`, `CausalAppIncidents`, string
clone/deinit helpers, and `deriveCausalAppIncidents`. The classifier should
scan `store.events.items` in order and append incidents for the rules in the
design.

- [ ] **Step 2: Export classifier**

Add service-level and top-level aliases for:

```zig
pub const CausalAppIncidentKind = services.causal_app_runtime.CausalAppIncidentKind;
pub const CausalAppIncident = services.causal_app_runtime.CausalAppIncident;
pub const CausalAppIncidents = services.causal_app_runtime.CausalAppIncidents;
pub const deriveCausalAppIncidents = services.causal_app_runtime.deriveCausalAppIncidents;
```

- [ ] **Step 3: Run GREEN**

Run:

```bash
cd packages/zigeffect && zig build causal-app-runtime
```

Expected: PASS.

## Task 3: RED/GREEN Advice And Diagnosis Mappings

**Files:**
- Modify: `packages/zigeffect/tools/causal_advice.zig`
- Modify: `packages/zigeffect/tools/causal_diagnosis.zig`

- [ ] **Step 1: Add failing app advice tests**

Add a JSON fixture with app events and assert app actions:

```zig
const app_incident_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"app.request GET /health","type_name":"zigeffect.app.request","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"assertion_recorded","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"YACHDEE_ENV","type_name":"MissingConfig","status":"failure","redacted_detail":"app.config.required"},
    \\    {"id":3,"kind":"assertion_recorded","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"HealthService","type_name":"MissingService","status":"failure","redacted_detail":"app.requirement.required"},
    \\    {"id":4,"kind":"span_recorded","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"app.response","type_name":"zigeffect.app.response","status":"500","redacted_detail":"body=missing_environment"}
    \\  ]
    \\}
;

test "advice report emits app-specific incident actions" {
    const report = try buildAdviceReport(std.testing.allocator, app_incident_json, ".zig-cache/causal-artifacts/app.json");
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "action fix-app-config status=observed event=2 kind=assertion_recorded label=YACHDEE_ENV") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "action wire-app-requirement status=observed event=3 kind=assertion_recorded label=HealthService") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "action inspect-app-response-failure status=observed event=4 kind=span_recorded label=app.response") != null);
}
```

Expected RED: app events currently become generic command actions or no action.

- [ ] **Step 2: Implement app advice actions**

Add helper predicates such as `isAppConfigFailure`, `isAppRequirementFailure`,
`isAppResponseFailure`, `isAppRetryExhaustion`, `isAppResource`, and
`isAppFiber`. In `actionNameForEvent`, check app predicates before generic
rules. Add `why` text and query commands in `appendAdviceAction`.

- [ ] **Step 3: Add and pass diagnosis mapping tests**

Extend `mapAction` tests for app actions and implement mappings.

Run:

```bash
cd packages/zigeffect && zig build causal-advice
cd packages/zigeffect && zig build causal-diagnosis
```

Expected: PASS.

## Task 4: Docs, Verification, Commit

**Files:**
- Modify all docs listed in File Structure.

- [ ] **Step 1: Document app incident mapping**

Mention `deriveCausalAppIncidents`, app-specific advice actions, and the next
app remediation audit branch.

- [ ] **Step 2: Run final verification**

Run:

```bash
cd packages/zigeffect && zig build causal-app-runtime
cd packages/zigeffect && zig build causal-advice
cd packages/zigeffect && zig build causal-diagnosis
cd packages/zigeffect && zig build test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run check
bun run zig:test
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 3: Commit**

Run:

```bash
git add docs/superpowers/specs/2026-06-09-zigeffect-app-incident-mapping-design.md docs/superpowers/plans/2026-06-09-zigeffect-app-incident-mapping.md packages/zigeffect/src/services/causal_app_runtime.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/causal_app_runtime_test.zig packages/zigeffect/tools/causal_advice.zig packages/zigeffect/tools/causal_diagnosis.zig packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/docs/roadmap.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): classify app causal incidents"
```

## Plan Self-Review

- Spec coverage: classifier, exports, advice, diagnosis, docs, and verification
  are covered.
- Placeholder scan: no placeholders are intentionally present.
- Type consistency: all names use `CausalAppIncident*` and
  `deriveCausalAppIncidents`.
