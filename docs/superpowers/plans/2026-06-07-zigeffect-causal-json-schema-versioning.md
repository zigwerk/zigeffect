# zigeffect Causal JSON Schema Versioning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make generated zigeffect causal JSON artifacts self-identifying with a stable schema name and version while preserving legacy artifact parsing.

**Architecture:** Add root-level metadata in `formatCausalJson` and expose constants from `services/causal.zig`. Keep parser changes additive by making metadata optional in local artifact structs.

**Tech Stack:** Zig, Zig standard JSON parser, Bun-managed repository commands, existing `zig build` causal harness tools.

---

## File Structure

- Modify `packages/zigeffect/src/services/causal.zig` to add schema constants and emit root metadata.
- Modify `packages/zigeffect/test/services_test.zig` to test generated JSON metadata.
- Modify `packages/zigeffect/tools/causal_query.zig` to accept optional metadata and test versioned plus legacy artifacts.
- Modify `packages/zigeffect/tools/causal_compare.zig` to accept optional metadata and test versioned artifacts.
- Modify `packages/zigeffect/tools/causal_loop.zig` to accept optional metadata and test query report generation from versioned artifacts.
- Update `packages/zigeffect/README.md`, `packages/zigeffect/docs/agent-guide.md`, `packages/zigeffect/docs/agent-observable-runtime.md`, and the roadmap spec to document the stable artifact header.

### Task 1: RED Generated Artifact Metadata

**Files:**
- Modify: `packages/zigeffect/test/services_test.zig`

- [ ] **Step 1: Write the failing metadata expectation**

Add these assertions to the existing causal JSON export test after the JSON is generated:

```zig
try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\": \"zigeffect.causal.v1\"") != null);
try std.testing.expect(std.mem.indexOf(u8, json, "\"schema_version\": 1") != null);
```

- [ ] **Step 2: Run the service tests and verify RED**

Run:

```bash
cd packages/zigeffect && zig build test --summary none
```

Expected: FAIL because `formatCausalJson` does not yet emit `schema` or `schema_version`.

### Task 2: GREEN Root Metadata

**Files:**
- Modify: `packages/zigeffect/src/services/causal.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Add schema constants**

Add near the causal service public declarations:

```zig
pub const causal_json_schema = "zigeffect.causal.v1";
pub const causal_json_schema_version: u32 = 1;
```

Re-export them from `src/zigeffect.zig` beside `formatCausalJson`.

- [ ] **Step 2: Emit root metadata**

Change `formatCausalJson` to start with:

```zig
try output.appendSlice(allocator, "{\n  \"schema\": ");
try appendJsonString(&output, allocator, causal_json_schema);
try output.print(allocator, ",\n  \"schema_version\": {d},\n  \"events\": [\n", .{causal_json_schema_version});
```

- [ ] **Step 3: Run the service tests and verify GREEN**

Run:

```bash
cd packages/zigeffect && zig build test --summary none
```

Expected: PASS.

### Task 3: Parser Compatibility Tests

**Files:**
- Modify: `packages/zigeffect/tools/causal_query.zig`
- Modify: `packages/zigeffect/tools/causal_compare.zig`
- Modify: `packages/zigeffect/tools/causal_loop.zig`

- [ ] **Step 1: Add optional metadata fields to parser structs**

Use this shape in each local `Artifact` struct:

```zig
const Artifact = struct {
    schema: ?[]const u8 = null,
    schema_version: ?u32 = null,
    events: []Event,
};
```

- [ ] **Step 2: Add versioned parser fixtures**

Add `schema` and `schema_version` to one local fixture in each tool:

```json
{
  "schema": "zigeffect.causal.v1",
  "schema_version": 1,
  "events": []
}
```

Keep at least one fixture without metadata so legacy parsing remains covered.

- [ ] **Step 3: Add behavior tests**

For `causal_query.zig`, add:

```zig
test "query accepts versioned causal artifacts" {
    const output = try runQuery(std.testing.allocator, versioned_sample_json, &.{"snapshot"});
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "events: 6") != null);
}
```

For `causal_compare.zig`, add:

```zig
test "compare accepts versioned causal artifacts" {
    const report = try runCompare(std.testing.allocator, versioned_before_json, versioned_after_json);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "before events: 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "after events: 3") != null);
}
```

For `causal_loop.zig`, add:

```zig
test "query report accepts versioned causal artifacts" {
    const report = try buildQueryReport(std.testing.allocator, versioned_dogfood_query_json, "artifact.json");
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal query report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "queries: 8") != null);
}
```

- [ ] **Step 4: Run tool tests**

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

- [ ] **Step 1: Document the artifact header**

Document this canonical root shape:

```json
{
  "schema": "zigeffect.causal.v1",
  "schema_version": 1,
  "events": []
}
```

- [ ] **Step 2: Update Milestone 8 status**

Mark stable schema versioning as delivered for the first hardening slice, while
leaving bounded memory, redaction hardening, sampling, and retention planned.

### Task 5: Verification And Commit

**Files:**
- Stage all modified files from Tasks 1-4.

- [ ] **Step 1: Run focused and repo verification**

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
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-json-schema-versioning-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-json-schema-versioning.md packages/zigeffect/src/services/causal.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/services_test.zig packages/zigeffect/tools/causal_query.zig packages/zigeffect/tools/causal_compare.zig packages/zigeffect/tools/causal_loop.zig packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md
git commit -m "feat(zigeffect): version causal json artifacts"
```

## Self-Review

- Spec coverage: each acceptance criterion maps to Tasks 1-5.
- Placeholder scan: no `TBD`, `TODO`, or deferred implementation language.
- Type consistency: schema constants use `[]const u8` and `u32`; parser structs use nullable fields with defaults for legacy compatibility.
