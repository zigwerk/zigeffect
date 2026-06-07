# zigeffect Causal Tool Taxonomy Awareness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make saved-artifact causal tools parse `event_taxonomy_version` and warn agents when artifact event-kind semantics are newer than the tool supports.

**Architecture:** Add a shared tool helper for taxonomy compatibility warning text, parse `event_taxonomy_version` in query/compare/dev-loop artifact structs, prepend warnings to query and compare reports, and keep dev-loop query reports concise by calling a no-warning query variant internally.

**Tech Stack:** Zig 0.16, zigeffect build tool modules, Bun repository scripts.

---

## Files

- Create: `packages/zigeffect/tools/causal_artifact.zig`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_query.zig`
- Modify: `packages/zigeffect/tools/causal_compare.zig`
- Modify: `packages/zigeffect/tools/causal_loop.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/roadmap.md`

## Task 1: RED Tests

- [ ] **Step 1: Add future taxonomy query fixture and test**

In `packages/zigeffect/tools/causal_query.zig`, add a fixture with
`"event_taxonomy_version": 2` and a test:

```zig
test "query warns when artifact taxonomy is newer than supported" {
    const output = try runQuery(std.testing.allocator, future_taxonomy_sample_json, &.{"snapshot"});
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "warning: artifact event_taxonomy_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "events: 1") != null);
}
```

- [ ] **Step 2: Add future taxonomy compare fixture and test**

In `packages/zigeffect/tools/causal_compare.zig`, add fixtures with before
taxonomy `2` and after taxonomy `3`, then add:

```zig
test "compare warns when artifact taxonomy is newer than supported" {
    const report = try runCompare(std.testing.allocator, future_taxonomy_before_json, future_taxonomy_after_json);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "warning: before event_taxonomy_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "warning: after event_taxonomy_version=3 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "before events: 2") != null);
}
```

- [ ] **Step 3: Add future taxonomy dev-loop query report test**

In `packages/zigeffect/tools/causal_loop.zig`, add a versioned fixture with
`"event_taxonomy_version": 2`, then add:

```zig
test "query report warns once when artifact taxonomy is newer than supported" {
    const report = try buildQueryReport(std.testing.allocator, future_taxonomy_dogfood_query_json, ".zig-cache/causal-artifacts/after.json");
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "warning: .zig-cache/causal-artifacts/after.json event_taxonomy_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "queries: 12") != null);
}
```

- [ ] **Step 4: Verify RED**

Run:

```bash
cd packages/zigeffect && zig build examples
```

Expected: FAIL because the tools do not parse or report taxonomy warnings.

## Task 2: Shared Warning Helper

- [ ] **Step 1: Create tool helper**

Create `packages/zigeffect/tools/causal_artifact.zig`:

```zig
const std = @import("std");

pub const supported_event_taxonomy_version: u32 = 1;

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

- [ ] **Step 2: Wire helper into build modules**

In `packages/zigeffect/build.zig`, create a module:

```zig
const causal_artifact_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_artifact.zig"),
    .target = target,
    .optimize = optimize,
});
```

Add imports:

```zig
causal_query_tool_module.addImport("causal_artifact", causal_artifact_tool_module);
causal_compare_tool_module.addImport("causal_artifact", causal_artifact_tool_module);
causal_loop_tool_module.addImport("causal_artifact", causal_artifact_tool_module);
```

## Task 3: Query Tool

- [ ] **Step 1: Import helper and parse taxonomy version**

In `packages/zigeffect/tools/causal_query.zig`:

```zig
const causal_artifact = @import("causal_artifact");
```

Add to `Artifact`:

```zig
event_taxonomy_version: ?u32 = null,
```

- [ ] **Step 2: Add query options and no-warning variant**

Add:

```zig
pub const QueryOptions = struct {
    include_artifact_warnings: bool = true,
    artifact_label: []const u8 = "artifact",
};
```

Change `runQuery` to call:

```zig
return runQueryWithOptions(allocator, json, args, .{});
```

Add `runQueryWithOptions` containing the existing query logic and pass
`parsed.value.event_taxonomy_version` into formatting.

- [ ] **Step 3: Include warning in query output**

Update `formatQueryResult` to receive `QueryOptions` and taxonomy version. After
the `causal.query:` line, call:

```zig
if (options.include_artifact_warnings) {
    try causal_artifact.appendTaxonomyVersionWarning(&output, allocator, options.artifact_label, event_taxonomy_version);
}
```

- [ ] **Step 4: Run query tests**

Run:

```bash
cd packages/zigeffect && zig build examples
```

Expected: query warning test passes; compare and loop still fail until updated.

## Task 4: Compare Tool

- [ ] **Step 1: Import helper and parse taxonomy version**

In `packages/zigeffect/tools/causal_compare.zig`:

```zig
const causal_artifact = @import("causal_artifact");
```

Add `event_taxonomy_version: ?u32 = null` to `Artifact`.

- [ ] **Step 2: Emit before/after warnings**

After the compare report header:

```zig
try causal_artifact.appendTaxonomyVersionWarning(&output, allocator, "before", before_parsed.value.event_taxonomy_version);
try causal_artifact.appendTaxonomyVersionWarning(&output, allocator, "after", after_parsed.value.event_taxonomy_version);
```

- [ ] **Step 3: Run compare tests**

Run:

```bash
cd packages/zigeffect && zig build examples
```

Expected: query and compare warning tests pass; loop still fails until updated.

## Task 5: Dev-Loop Query Report

- [ ] **Step 1: Import helper and parse taxonomy version**

In `packages/zigeffect/tools/causal_loop.zig`:

```zig
const causal_artifact = @import("causal_artifact");
```

Add `event_taxonomy_version: ?u32 = null` to its `Artifact`.

- [ ] **Step 2: Emit a single query-report warning**

In `buildQueryReport`, before `queries:`, call:

```zig
try causal_artifact.appendTaxonomyVersionWarning(&output, allocator, artifact_path, parsed.value.event_taxonomy_version);
```

- [ ] **Step 3: Suppress repeated query warnings**

In `appendQuery`, replace:

```zig
const result = try causal_query.runQuery(allocator, json, args);
```

with:

```zig
const result = try causal_query.runQueryWithOptions(allocator, json, args, .{
    .include_artifact_warnings = false,
});
```

- [ ] **Step 4: Run loop tests**

Run:

```bash
cd packages/zigeffect && zig build examples
```

Expected: all warning tests pass.

## Task 6: Docs, Verification, Commit

- [ ] **Step 1: Update docs**

Document that query, compare, and dev-loop query reports warn when
`event_taxonomy_version` is newer than supported.

- [ ] **Step 2: Run full verification**

Run:

```bash
cd packages/zigeffect && zig build test --summary none
cd packages/zigeffect && zig build examples
bun run zig:test
cd packages/zigeffect && zig build causal-dev-loop -- baseline
cd packages/zigeffect && zig build causal-dev-loop -- after
git diff --check
```

- [ ] **Step 3: Commit implementation**

Run:

```bash
git add packages/zigeffect/tools/causal_artifact.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/tools/causal_query.zig \
  packages/zigeffect/tools/causal_compare.zig \
  packages/zigeffect/tools/causal_loop.zig \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/agent-observable-runtime.md \
  packages/zigeffect/docs/roadmap.md
git commit -m "feat(zigeffect): warn on future causal taxonomy artifacts"
```

## Self-Review

- Spec coverage: The plan covers shared helper, query warnings, compare
  warnings, dev-loop query-report warnings, docs, and full verification.
- Placeholder scan: No implementation placeholders remain.
- Type consistency: The plan consistently uses `event_taxonomy_version`,
  `supported_event_taxonomy_version`, and `runQueryWithOptions`.
