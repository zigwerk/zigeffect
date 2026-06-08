# zigeffect Causal Schema And Taxonomy Fixtures Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add shared schema/taxonomy compatibility warnings and fixtures so causal tools keep parsing artifacts while telling agents when schema shape or event-kind semantics may be incomplete.

**Architecture:** Add shared metadata and warning helpers to `tools/causal_artifact.zig`, then call them from the saved-artifact tools that already parse causal JSON. Keep legacy artifacts warning-free, current v1 artifacts warning-free, and future/unknown artifacts warning-rich but parseable.

**Tech Stack:** Zig stdlib, zigeffect build tool modules, `zig test`, `zig build test`, Bun verification commands.

---

## File Structure

- Modify `packages/zigeffect/tools/causal_artifact.zig`
  - Add supported schema constants.
  - Add `ArtifactMetadata`.
  - Add combined schema/taxonomy warning helper.
  - Add known event-kind classifier and unknown-kind warning helper.
  - Add direct tests for helper behavior.
- Modify `packages/zigeffect/tools/causal_query.zig`
  - Add future schema, unsupported schema, and unknown-kind fixtures.
  - Emit shared metadata warnings and unknown-kind warnings.
- Modify `packages/zigeffect/tools/causal_compare.zig`
  - Emit before/after schema warnings and before/after unknown-kind warnings.
- Modify `packages/zigeffect/tools/causal_loop.zig`
  - Emit schema and unknown-kind warnings in generated query reports.
- Modify `packages/zigeffect/tools/causal_advice.zig`
  - Emit schema and unknown-kind warnings in advice reports.
- Modify `packages/zigeffect/build.zig`
  - Add a direct `causal_artifact` helper test target.
- Modify docs:
  - `packages/zigeffect/docs/agent-guide.md`
  - `packages/zigeffect/README.md`
  - `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

---

### Task 1: Add RED Tests For Shared Compatibility Helpers

**Files:**
- Modify: `packages/zigeffect/tools/causal_artifact.zig`

- [ ] **Step 1: Add helper tests**

Append these tests to `causal_artifact.zig`:

```zig
test "artifact compatibility warnings cover future schema and taxonomy versions" {
    var output = std.ArrayList(u8).empty;
    defer output.deinit(std.testing.allocator);

    try appendArtifactCompatibilityWarnings(&output, std.testing.allocator, "artifact", .{
        .schema = supported_causal_schema,
        .schema_version = 2,
        .event_taxonomy_version = 3,
    });

    try std.testing.expect(std.mem.indexOf(u8, output.items, "warning: artifact schema_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, "warning: artifact event_taxonomy_version=3 newer than supported=1") != null);
}

test "artifact compatibility warnings accept legacy and current metadata quietly" {
    var legacy = std.ArrayList(u8).empty;
    defer legacy.deinit(std.testing.allocator);
    try appendArtifactCompatibilityWarnings(&legacy, std.testing.allocator, "legacy", .{});
    try std.testing.expectEqual(@as(usize, 0), legacy.items.len);

    var current = std.ArrayList(u8).empty;
    defer current.deinit(std.testing.allocator);
    try appendArtifactCompatibilityWarnings(&current, std.testing.allocator, "current", .{
        .schema = supported_causal_schema,
        .schema_version = supported_causal_schema_version,
        .event_taxonomy_version = supported_event_taxonomy_version,
    });
    try std.testing.expectEqual(@as(usize, 0), current.items.len);
}

test "artifact compatibility warnings flag unsupported schema names" {
    var output = std.ArrayList(u8).empty;
    defer output.deinit(std.testing.allocator);

    try appendArtifactCompatibilityWarnings(&output, std.testing.allocator, "artifact", .{
        .schema = "zigeffect.causal.v2",
        .schema_version = 1,
        .event_taxonomy_version = 1,
    });

    try std.testing.expect(std.mem.indexOf(u8, output.items, "warning: artifact schema=zigeffect.causal.v2 unsupported; expected zigeffect.causal.v1") != null);
}

test "known causal event kind helper covers current taxonomy strings" {
    try std.testing.expect(isKnownCausalEventKind("run_started"));
    try std.testing.expect(isKnownCausalEventKind("service_required"));
    try std.testing.expect(isKnownCausalEventKind("span_recorded"));
    try std.testing.expect(!isKnownCausalEventKind("effect_suspended"));
}

test "unknown event kind warning names the unsupported kind" {
    var output = std.ArrayList(u8).empty;
    defer output.deinit(std.testing.allocator);

    try appendUnknownEventKindWarning(&output, std.testing.allocator, "artifact", "effect_suspended");

    try std.testing.expect(std.mem.indexOf(u8, output.items, "warning: artifact event kind effect_suspended unknown to supported taxonomy=1") != null);
}
```

- [ ] **Step 2: Run direct helper tests and verify RED**

Run:

```bash
cd packages/zigeffect && zig test tools/causal_artifact.zig
```

Expected: FAIL at compile time because the new constants and helpers do not exist.

---

### Task 2: Implement Shared Compatibility Helpers

**Files:**
- Modify: `packages/zigeffect/tools/causal_artifact.zig`

- [ ] **Step 1: Replace the helper file with the expanded helper surface**

Use this structure at the top of `causal_artifact.zig`, preserving the existing taxonomy warning text:

```zig
const std = @import("std");

pub const supported_causal_schema = "zigeffect.causal.v1";
pub const supported_causal_schema_version: u32 = 1;
pub const supported_event_taxonomy_version: u32 = 1;

pub const ArtifactMetadata = struct {
    schema: ?[]const u8 = null,
    schema_version: ?u32 = null,
    event_taxonomy_version: ?u32 = null,
};

pub fn appendArtifactCompatibilityWarnings(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    artifact_label: []const u8,
    metadata: ArtifactMetadata,
) std.mem.Allocator.Error!void {
    if (metadata.schema) |schema| {
        if (!std.mem.eql(u8, schema, supported_causal_schema)) {
            try output.print(
                allocator,
                "warning: {s} schema={s} unsupported; expected {s}\n",
                .{ artifact_label, schema, supported_causal_schema },
            );
        }
    }

    if (metadata.schema_version) |version| {
        if (version > supported_causal_schema_version) {
            try output.print(
                allocator,
                "warning: {s} schema_version={d} newer than supported={d}; artifact shape may be incomplete\n",
                .{ artifact_label, version, supported_causal_schema_version },
            );
        }
    }

    try appendTaxonomyVersionWarning(output, allocator, artifact_label, metadata.event_taxonomy_version);
}
```

- [ ] **Step 2: Keep taxonomy warning as a wrapper-compatible helper**

Keep:

```zig
pub fn appendTaxonomyVersionWarning(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    artifact_label: []const u8,
    event_taxonomy_version: ?u32,
) std.mem.Allocator.Error!void {
    const version = event_taxonomy_version orelse return;
    if (version <= supported_event_taxonomy_version) return;
    try output.print(
        allocator,
        "warning: {s} event_taxonomy_version={d} newer than supported={d}; event-kind role semantics may be incomplete\n",
        .{ artifact_label, version, supported_event_taxonomy_version },
    );
}
```

- [ ] **Step 3: Add known-kind helpers**

Add:

```zig
const known_causal_event_kinds = [_][]const u8{
    "run_started",
    "run_completed",
    "effect_started",
    "effect_completed",
    "layer_started",
    "layer_completed",
    "service_required",
    "service_provided",
    "service_replaced",
    "scope_opened",
    "scope_closed",
    "resource_acquired",
    "resource_finalized",
    "fiber_forked",
    "fiber_started",
    "fiber_joined",
    "fiber_interrupted",
    "schedule_decision",
    "exit_recorded",
    "log_recorded",
    "metric_recorded",
    "span_recorded",
    "assertion_recorded",
};

pub fn isKnownCausalEventKind(kind: []const u8) bool {
    for (known_causal_event_kinds) |candidate| {
        if (std.mem.eql(u8, kind, candidate)) return true;
    }
    return false;
}

pub fn appendUnknownEventKindWarning(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    artifact_label: []const u8,
    kind: []const u8,
) std.mem.Allocator.Error!void {
    try output.print(
        allocator,
        "warning: {s} event kind {s} unknown to supported taxonomy={d}; query/advice role semantics may be incomplete\n",
        .{ artifact_label, kind, supported_event_taxonomy_version },
    );
}

pub fn appendUnknownEventKindWarnings(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    artifact_label: []const u8,
    events: anytype,
) std.mem.Allocator.Error!void {
    var seen = std.ArrayList([]const u8).empty;
    defer seen.deinit(allocator);

    for (events) |event| {
        if (isKnownCausalEventKind(event.kind)) continue;
        var already_seen = false;
        for (seen.items) |kind| {
            if (std.mem.eql(u8, kind, event.kind)) {
                already_seen = true;
                break;
            }
        }
        if (already_seen) continue;
        try seen.append(allocator, event.kind);
        try appendUnknownEventKindWarning(output, allocator, artifact_label, event.kind);
    }
}
```

- [ ] **Step 4: Verify GREEN**

Run:

```bash
cd packages/zigeffect && zig test tools/causal_artifact.zig
```

Expected: PASS.

---

### Task 3: Add RED Fixtures For Query And Compare Compatibility Warnings

**Files:**
- Modify: `packages/zigeffect/tools/causal_query.zig`
- Modify: `packages/zigeffect/tools/causal_compare.zig`

- [ ] **Step 1: Add query fixtures and tests**

Add fixtures near the current taxonomy fixtures:

```zig
const future_schema_unknown_kind_sample_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 2,
    \\  "event_taxonomy_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future schema","type_name":"Fixture","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"effect_suspended","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future event","type_name":"Fixture","status":"pending","redacted_detail":""},
    \\    {"id":3,"kind":"effect_suspended","run_id":1,"parent_id":2,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future duplicate","type_name":"Fixture","status":"pending","redacted_detail":""}
    \\  ]
    \\}
;

const unsupported_schema_sample_json =
    \\{
    \\  "schema": "zigeffect.causal.v2",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"unsupported schema","type_name":"Fixture","status":"started","redacted_detail":""}
    \\  ]
    \\}
;
```

Add tests:

```zig
test "query warns on future schema version and unknown event kinds" {
    const output = try runQuery(std.testing.allocator, future_schema_unknown_kind_sample_json, &.{"snapshot"});
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "warning: artifact schema_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "warning: artifact event kind effect_suspended unknown to supported taxonomy=1") != null);
    try std.testing.expectEqual(@as(usize, 2), std.mem.count(u8, output, "warning:"));
    try std.testing.expect(std.mem.indexOf(u8, output, "events: 3") != null);
}

test "query warns on unsupported schema family" {
    const output = try runQuery(std.testing.allocator, unsupported_schema_sample_json, &.{"snapshot"});
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "warning: artifact schema=zigeffect.causal.v2 unsupported; expected zigeffect.causal.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "events: 1") != null);
}

test "query keeps legacy artifacts warning-free" {
    const output = try runQuery(std.testing.allocator, sample_json, &.{"snapshot"});
    defer std.testing.allocator.free(output);

    try std.testing.expectEqual(@as(usize, 0), std.mem.count(u8, output, "warning:"));
}
```

- [ ] **Step 2: Add compare fixtures and tests**

Add a future-schema before fixture and unknown-kind after fixture, then tests:

```zig
test "compare warns on future schema and unknown event kinds" {
    const report = try runCompare(std.testing.allocator, future_schema_before_json, unknown_kind_after_json);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "warning: before schema_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "warning: after event kind effect_suspended unknown to supported taxonomy=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "before events: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "after events: 2") != null);
}

test "compare warns on unsupported schema family" {
    const report = try runCompare(std.testing.allocator, unsupported_schema_before_json, versioned_after_json);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "warning: before schema=zigeffect.causal.v2 unsupported; expected zigeffect.causal.v1") != null);
}
```

- [ ] **Step 3: Run tool tests and verify RED**

Run:

```bash
cd packages/zigeffect && zig build examples
```

Expected: FAIL because query and compare do not yet emit schema or unknown-kind warnings.

---

### Task 4: Wire Compatibility Warnings Into Query And Compare

**Files:**
- Modify: `packages/zigeffect/tools/causal_query.zig`
- Modify: `packages/zigeffect/tools/causal_compare.zig`

- [ ] **Step 1: Update query formatting**

Change `runQueryWithOptions` to pass metadata and all parsed events into `formatQueryResult`:

```zig
return formatQueryResult(
    allocator,
    args,
    selected.items,
    parsed.value.events,
    .{
        .schema = parsed.value.schema,
        .schema_version = parsed.value.schema_version,
        .event_taxonomy_version = parsed.value.event_taxonomy_version,
    },
    options,
);
```

Change `formatQueryResult` parameters to include `all_events: []const Event` and `metadata: causal_artifact.ArtifactMetadata`, then replace the taxonomy-only warning call with:

```zig
try causal_artifact.appendArtifactCompatibilityWarnings(&output, allocator, options.artifact_label, metadata);
try causal_artifact.appendUnknownEventKindWarnings(&output, allocator, options.artifact_label, all_events);
```

- [ ] **Step 2: Update compare warnings**

In `runCompare`, replace the two taxonomy-only warning calls with:

```zig
try causal_artifact.appendArtifactCompatibilityWarnings(&output, allocator, "before", .{
    .schema = before_parsed.value.schema,
    .schema_version = before_parsed.value.schema_version,
    .event_taxonomy_version = before_parsed.value.event_taxonomy_version,
});
try causal_artifact.appendUnknownEventKindWarnings(&output, allocator, "before", before_events);
try causal_artifact.appendArtifactCompatibilityWarnings(&output, allocator, "after", .{
    .schema = after_parsed.value.schema,
    .schema_version = after_parsed.value.schema_version,
    .event_taxonomy_version = after_parsed.value.event_taxonomy_version,
});
try causal_artifact.appendUnknownEventKindWarnings(&output, allocator, "after", after_events);
```

- [ ] **Step 3: Verify GREEN**

Run:

```bash
cd packages/zigeffect && zig build examples
```

Expected: PASS for query and compare tests plus existing examples.

- [ ] **Step 4: Commit helper/query/compare slice**

Run:

```bash
git add packages/zigeffect/tools/causal_artifact.zig packages/zigeffect/tools/causal_query.zig packages/zigeffect/tools/causal_compare.zig
git commit -m "feat(zigeffect): warn on causal schema compatibility"
```

---

### Task 5: Add RED/GREEN Fixtures For Dev Loop And Advice Reports

**Files:**
- Modify: `packages/zigeffect/tools/causal_loop.zig`
- Modify: `packages/zigeffect/tools/causal_advice.zig`

- [ ] **Step 1: Add dev-loop query-report RED test**

Add a fixture with `schema_version: 2` and an `effect_suspended` event, then add:

```zig
test "query report warns on future schema and unknown event kind" {
    const report = try buildQueryReport(std.testing.allocator, future_schema_unknown_kind_dogfood_query_json, ".zig-cache/causal-artifacts/future.json");
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "warning: .zig-cache/causal-artifacts/future.json schema_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "warning: .zig-cache/causal-artifacts/future.json event kind effect_suspended unknown to supported taxonomy=1") != null);
}
```

- [ ] **Step 2: Add advice RED test**

Add a fixture with `schema_version: 2` and an `effect_suspended` event, then add:

```zig
test "advice report warns on future schema and unknown event kind" {
    const report = try buildAdviceReport(std.testing.allocator, future_schema_unknown_kind_json, ".zig-cache/causal-artifacts/future-schema.json");
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "warning: .zig-cache/causal-artifacts/future-schema.json schema_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "warning: .zig-cache/causal-artifacts/future-schema.json event kind effect_suspended unknown to supported taxonomy=1") != null);
}
```

- [ ] **Step 3: Run tests and verify RED**

Run:

```bash
cd packages/zigeffect && zig build examples
```

Expected: FAIL because loop and advice still only emit taxonomy warnings.

- [ ] **Step 4: Wire loop and advice to shared warnings**

In `causal_loop.zig` `buildQueryReport`, replace the taxonomy-only call with:

```zig
try causal_artifact.appendArtifactCompatibilityWarnings(&output, allocator, artifact_path, .{
    .schema = parsed.value.schema,
    .schema_version = parsed.value.schema_version,
    .event_taxonomy_version = parsed.value.event_taxonomy_version,
});
try causal_artifact.appendUnknownEventKindWarnings(&output, allocator, artifact_path, parsed.value.events);
```

In `causal_advice.zig`, pass metadata and all parsed events into `formatAdviceReport`; then emit shared warnings before `actions`.

- [ ] **Step 5: Verify GREEN**

Run:

```bash
cd packages/zigeffect && zig build examples
```

Expected: PASS.

- [ ] **Step 6: Commit loop/advice slice**

Run:

```bash
git add packages/zigeffect/tools/causal_loop.zig packages/zigeffect/tools/causal_advice.zig
git commit -m "feat(zigeffect): warn causal reports on compatibility gaps"
```

---

### Task 6: Add Build Integration And Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add direct helper tests to the build**

After the `causal_artifact_tool_module` declaration in `build.zig`, add:

```zig
const causal_artifact_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-artifact-tests",
    .root_module = causal_artifact_tool_module,
});
const run_causal_artifact_tool_tests = b.addRunArtifact(causal_artifact_tool_tests);
```

Add:

```zig
test_step.dependOn(&run_causal_artifact_tool_tests.step);
```

after `test_step` is declared.

Add:

```zig
examples_step.dependOn(&run_causal_artifact_tool_tests.step);
```

near the other causal tool test dependencies.

- [ ] **Step 2: Update docs**

Update README and agent guide text near taxonomy warnings to explain schema
warnings and unknown-kind warnings.

Update the master roadmap progress ledger:

```markdown
| M3 Production hardening | in progress | bounded store, broader redaction, sampling, taxonomy, and schema/taxonomy compatibility fixtures delivered | continue with artifact size limits |
```

Remove `codex/zigeffect-causal-schema-taxonomy-fixtures` from the immediate
queue, leaving `codex/zigeffect-causal-backend-conformance` as the next item.

- [ ] **Step 3: Run docs/build checks**

Run:

```bash
git diff --check HEAD
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test --summary none
```

Expected: all commands pass.

- [ ] **Step 4: Commit docs/build integration**

Run:

```bash
git add packages/zigeffect/build.zig packages/zigeffect/docs/agent-guide.md packages/zigeffect/README.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): document causal compatibility warnings"
```

---

### Task 7: Full Verification And Merge

**Files:**
- Verify all touched files.

- [ ] **Step 1: Run package verification**

Run:

```bash
cd packages/zigeffect && zig test tools/causal_artifact.zig
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build causal-test-matrix
cd packages/zigeffect && zig build test --summary none
```

Expected: all commands pass.

- [ ] **Step 2: Run repo verification**

Run:

```bash
bun run check
bun run zig:test
```

Expected: all commands pass.

- [ ] **Step 3: Check final branch status**

Run:

```bash
git diff --check HEAD
git status --short --branch
```

Expected: no whitespace errors. Status should show only the known unrelated untracked durable-workflows roadmap file.

- [ ] **Step 4: Fast-forward merge to master**

Run:

```bash
git switch master
git merge --ff-only codex/zigeffect-causal-schema-taxonomy-fixtures
git branch -d codex/zigeffect-causal-schema-taxonomy-fixtures
```

Expected: merge succeeds and branch deletes cleanly.

- [ ] **Step 5: Post-merge verification**

Run:

```bash
git diff --check HEAD
cd packages/zigeffect && zig build test --summary none
bun run check
bun run zig:test
```

Expected: all commands pass on `master`.

## Self-Review

- Spec coverage: Tasks cover shared schema warnings, taxonomy warnings, unknown-kind warnings, legacy/current no-warning fixtures, query/compare/loop/advice integration, direct helper tests, docs, and merge verification.
- Completeness scan: There are no open implementation stubs; code-changing steps include concrete snippets and exact commands.
- Type consistency: The plan consistently uses `ArtifactMetadata`, `appendArtifactCompatibilityWarnings`, `appendUnknownEventKindWarnings`, `schema_version`, and `event_taxonomy_version`.
