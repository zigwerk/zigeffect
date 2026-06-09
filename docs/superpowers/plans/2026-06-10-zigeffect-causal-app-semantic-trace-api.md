# zigeffect Causal App Semantic Trace API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add typed app semantic causal refs, app trace helpers, and a bounded `trace_data` agent query.

**Architecture:** Extend the existing append-only `CausalEvent` spine with app semantic reference fields, then add ergonomic helpers on `CausalAppTrace`. Keep events exported as `zigeffect.causal.v1`; use `span_recorded` plus stable `type_name` values for semantic roles, and expose data-lineage slices through `causal-query --agent trace_data`.

**Tech Stack:** Zig standard library, zigeffect `CausalStore`, existing causal app runtime tests, existing causal query tool, Bun workbench checks.

---

## File Map

- Modify `packages/zigeffect/src/services/causal.zig`: add app semantic refs to `CausalEvent`, clone/free/export fields.
- Modify `packages/zigeffect/src/services/causal_jsonl_backend.zig`: include refs in JSONL event records.
- Modify `packages/zigeffect/src/services/causal_nendb_storage_backend.zig`: preserve refs in durable projection records.
- Modify `packages/zigeffect/src/services/causal_app_runtime.zig`: add semantic ref and event types plus helper methods.
- Modify `packages/zigeffect/src/zigeffect.zig`: export app semantic types.
- Modify `packages/zigeffect/test/causal_app_runtime_test.zig`: add failing semantic API tests first.
- Modify `packages/zigeffect/examples/causal_app_request.zig`: dogfood semantic helpers.
- Modify `packages/zigeffect/tools/causal_query.zig`: parse refs, return refs, implement `trace_data`, derive data relationships.
- Modify `packages/zigeffect/workbench/src/causalArtifact.ts`: type optional semantic refs.
- Modify docs/backlog files after implementation proves behavior.

### Task 1: Red Tests For App Semantic Refs

**Files:**
- Modify: `packages/zigeffect/test/causal_app_runtime_test.zig`

- [ ] **Step 1: Add failing semantic helper tests**

Add tests that use the desired public API:

```zig
test "app semantic trace records data lineage refs without raw payloads" {
    var store = fx.CausalStore.initWithOptions(std.testing.allocator, fx.defaultRequestCausalStoreOptions());
    defer store.deinit();

    var trace = try fx.CausalAppTrace.startRequest(&store, .{
        .method = "GET",
        .route = "/api/projects/:id",
        .runtime = "worker",
    });

    const refs = fx.CausalAppSemanticRefs{
        .data_subject_ref = "tenant:acme",
        .domain_entity_ref = "project:123",
        .schema_ref = "Project.v1",
    };
    _ = try trace.recordDataRead("load project", refs, "success");
    _ = try trace.recordDataTransformed("shape project response", refs, "success");
    _ = try trace.recordDataWritten("cache project", refs, "success");
    _ = try trace.recordPolicyDecision("project visibility", refs, "allowed");
    _ = try trace.recordResponseSent("GET /api/projects/:id", .{
        .data_subject_ref = "tenant:acme",
        .artifact_id = "response:project:123",
        .schema_ref = "ProjectResponse.v1",
    }, "200");
    try trace.complete(.success);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expectEqualStrings("tenant:acme", snapshot.events[1].data_subject_ref);
    try std.testing.expectEqualStrings("project:123", snapshot.events[1].domain_entity_ref);
    try std.testing.expectEqualStrings("Project.v1", snapshot.events[1].schema_ref);
    try std.testing.expectEqualStrings("zigeffect.app.data_read", snapshot.events[1].type_name);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"data_subject_ref\": \"tenant:acme\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"artifact_id\": \"response:project:123\"") != null);
}

test "app semantic refs are redacted and bounded before export" {
    var store = fx.CausalStore.initWithOptions(std.testing.allocator, .{
        .max_events = 16,
        .max_event_string_bytes = 32,
    });
    defer store.deinit();

    var trace = try fx.CausalAppTrace.startRequest(&store, .{
        .method = "POST",
        .route = "/api/private",
        .runtime = "worker",
    });
    _ = try trace.recordDataRead("read private payload", .{
        .data_subject_ref = "user_email=person@example.com token=raw-secret",
        .schema_ref = "PrivatePayload.v1",
    }, "success");

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "person@example.com") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, fx.causal_redaction_marker) != null);
}
```

- [ ] **Step 2: Run red test**

Run:

```sh
cd packages/zigeffect
zig build causal-app-runtime
```

Expected: FAIL because `CausalAppSemanticRefs`, `recordDataRead`,
`recordDataTransformed`, `recordDataWritten`, `recordPolicyDecision`, and
`recordResponseSent` do not exist yet.

### Task 2: Core Event Fields And Backends

**Files:**
- Modify: `packages/zigeffect/src/services/causal.zig`
- Modify: `packages/zigeffect/src/services/causal_jsonl_backend.zig`
- Modify: `packages/zigeffect/src/services/causal_nendb_storage_backend.zig`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`

- [ ] **Step 1: Add event fields**

Add to `CausalEvent`:

```zig
artifact_id: []const u8 = "",
domain_entity_ref: []const u8 = "",
data_subject_ref: []const u8 = "",
schema_ref: []const u8 = "",
```

- [ ] **Step 2: Clone, redact, bound, and free fields**

Update `cloneEventForStore`, `cloneEvent`, and `deinitEventStrings` so all four
new fields use the same ownership path as `service_key`.

- [ ] **Step 3: Export refs**

Add the four fields to `formatCausalJson`, `formatCausalJsonLine`, and the
NenDB event projection JSON writer.

- [ ] **Step 4: Type workbench parsing**

Add optional fields to the TypeScript causal event type:

```ts
artifact_id?: string;
domain_entity_ref?: string;
data_subject_ref?: string;
schema_ref?: string;
```

- [ ] **Step 5: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig build causal-app-runtime
zig build causal-jsonl-backend
zig build causal-nendb-storage-backend
```

Expected: tests still fail only on missing app semantic helper methods until
Task 3 is complete; backend tests should compile with the new fields.

### Task 3: App Semantic Trace Helpers

**Files:**
- Modify: `packages/zigeffect/src/services/causal_app_runtime.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Add public semantic types**

Add:

```zig
pub const CausalAppSemanticKind = enum {
    function_boundary,
    data_read,
    data_transformed,
    data_written,
    service_call,
    domain_action,
    policy_decision,
    artifact_emitted,
    response_sent,
};

pub const CausalAppSemanticRefs = struct {
    artifact_id: []const u8 = "",
    domain_entity_ref: []const u8 = "",
    data_subject_ref: []const u8 = "",
    schema_ref: []const u8 = "",
    service_key: []const u8 = "",
    cause_event_id: ?u64 = null,
};
```

- [ ] **Step 2: Add `recordSemanticEvent`**

Implement a method that maps the semantic kind to
`type_name = "zigeffect.app.<kind>"`, emits `.span_recorded`, copies refs into
the new event fields, and defaults parent/run/trace through `CausalAppTrace.record`.

- [ ] **Step 3: Add ergonomic helpers**

Add wrapper methods:

```zig
pub fn recordDataRead(self: *CausalAppTrace, label: []const u8, refs: CausalAppSemanticRefs, status: []const u8) !u64
pub fn recordDataTransformed(self: *CausalAppTrace, label: []const u8, refs: CausalAppSemanticRefs, status: []const u8) !u64
pub fn recordDataWritten(self: *CausalAppTrace, label: []const u8, refs: CausalAppSemanticRefs, status: []const u8) !u64
pub fn recordPolicyDecision(self: *CausalAppTrace, label: []const u8, refs: CausalAppSemanticRefs, status: []const u8) !u64
pub fn recordResponseSent(self: *CausalAppTrace, label: []const u8, refs: CausalAppSemanticRefs, status: []const u8) !u64
```

Also add helpers for `recordFunctionBoundary`, `recordServiceCall`,
`recordDomainAction`, and `recordArtifactEmitted`.

- [ ] **Step 4: Export types**

Re-export `CausalAppSemanticKind` and `CausalAppSemanticRefs` from
`src/zigeffect.zig`.

- [ ] **Step 5: Run green test**

Run:

```sh
cd packages/zigeffect
zig build causal-app-runtime
```

Expected: PASS.

### Task 4: Agent `trace_data` Query

**Files:**
- Modify: `packages/zigeffect/tools/causal_query.zig`

- [ ] **Step 1: Add failing query tests**

Add a fixture with app semantic refs and test:

```zig
const app_semantic_sample_json = ...;

test "agent trace_data returns semantic data lineage relationships" {
    const output = try runQuery(std.testing.allocator, app_semantic_sample_json, &.{ "--agent", "trace_data", "tenant:acme" });
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "\"query\":\"trace_data\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"data_subject_ref\":\"tenant:acme\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"relationship\":\"reads\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"relationship\":\"writes\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"relationship\":\"transforms\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"relationship\":\"emits\"") != null);
}
```

- [ ] **Step 2: Run red query tests**

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: FAIL because `trace_data` is not implemented.

- [ ] **Step 3: Implement query and output refs**

Extend the parsed `Event` struct with the four semantic ref fields. Include those
fields in agent JSON events. Add `trace_data <data_subject_ref>` to the query
dispatcher and add relationship mapping from semantic `type_name` values.

- [ ] **Step 4: Run green query tests**

Run:

```sh
cd packages/zigeffect
zig build examples
zig build causal-query -- --agent trace_data subject:health
```

Expected: PASS and a valid agent-query JSON envelope.

### Task 5: Example And Documentation

**Files:**
- Modify: `packages/zigeffect/examples/causal_app_request.zig`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Dogfood semantic helpers**

Replace direct app response `store.record(.span_recorded, ...)` calls in the app
request example with `recordDataRead`, `recordResponseSent`, and
`recordArtifactEmitted` where appropriate.

- [ ] **Step 2: Update docs**

Document semantic refs, helper methods, redaction rules, and
`causal-query --agent trace_data <data_subject_ref>`.

- [ ] **Step 3: Update backlog status**

Set `app-semantic-trace-api` to delivered or partial based on implemented
evidence. Keep `agent-query-interface` partial until `compare_runs` exists, but
remove `trace_data` from its future-only wording.

### Task 6: Verification And Commit

**Files:**
- All modified files

- [ ] **Step 1: Format**

Run:

```sh
cd packages/zigeffect
zig fmt src/services/causal.zig src/services/causal_jsonl_backend.zig src/services/causal_nendb_storage_backend.zig src/services/causal_app_runtime.zig src/zigeffect.zig test/causal_app_runtime_test.zig examples/causal_app_request.zig tools/causal_query.zig tools/causal_production_hardening_backlog.zig
```

- [ ] **Step 2: Focused verification**

Run:

```sh
cd packages/zigeffect
zig build causal-app-runtime
zig build causal-jsonl-backend
zig build causal-nendb-storage-backend
zig build examples
zig build test
```

- [ ] **Step 3: Repo verification**

Run:

```sh
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:test
bun run zig:test
bun run check
git diff --check
```

- [ ] **Step 4: Commit**

Stage only branch-owned files. Leave unrelated dirty docs untouched.

```sh
git add docs/superpowers/specs/2026-06-10-zigeffect-causal-app-semantic-trace-api-design.md docs/superpowers/plans/2026-06-10-zigeffect-causal-app-semantic-trace-api.md packages/zigeffect/src/services/causal.zig packages/zigeffect/src/services/causal_jsonl_backend.zig packages/zigeffect/src/services/causal_nendb_storage_backend.zig packages/zigeffect/src/services/causal_app_runtime.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/causal_app_runtime_test.zig packages/zigeffect/examples/causal_app_request.zig packages/zigeffect/tools/causal_query.zig packages/zigeffect/workbench/src/causalArtifact.ts packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/docs/schema-governance.md packages/zigeffect/docs/production-hardening-backlog.md packages/zigeffect/tools/causal_production_hardening_backlog.zig
git commit -m "feat(zigeffect): add app semantic causal tracing"
```

## Self-Review

- Spec coverage: tasks cover core refs, app helper API, backend preservation,
  agent `trace_data`, example dogfooding, docs, verification, and commit.
- Placeholder scan: no task relies on a vague TODO; every behavior has a named
  file and verification command.
- Type consistency: public types are `CausalAppSemanticKind` and
  `CausalAppSemanticRefs`; helper methods are named consistently across tests
  and implementation.
