# zigeffect Causal Loop Auto-Query Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `causal-dev-loop -- after` write an automatic query report by running selected `causal-query` helpers against the after artifact.

**Architecture:** Extend `causal_loop.zig` with a small after-artifact analyzer and query-report formatter that calls `causal_query.runQuery`. Keep `causal_query.zig` as the query execution source of truth and only import it into the loop tool.

**Tech Stack:** Zig 0.16, existing `causal_loop.zig`, `causal_query.zig`, `std.json.parseFromSlice`, `std.ArrayList`, existing Zig build module imports.

---

## File Structure

- Modify `packages/zigeffect/build.zig`
  Add `causal_query_tool_module` as an import to `causal_loop_tool_module`.
- Modify `packages/zigeffect/tools/causal_loop.zig`
  Add query report paths, after-artifact parsing, query selection, query report
  formatting, query report writing, and tests.
- Modify `packages/zigeffect/README.md`
  Document the query report artifact.
- Modify `packages/zigeffect/docs/agent-guide.md`
  Explain how agents use the query report.
- Modify `packages/zigeffect/docs/agent-observable-runtime.md`
  Update Phase 0 with automatic query report generation.
- Modify `packages/zigeffect/docs/causal-scenarios.md`
  Add the `*-queries.txt` artifact paths.
- Modify `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
  Mark automatic query helper execution as delivered.

## Task 1: Add Red Tests For Query Report Paths And Formatting

**Files:**

- Modify `packages/zigeffect/tools/causal_loop.zig`

- [ ] **Step 1: Add query path expectations**

Update `dev loop paths are stable` to assert:

```zig
try std.testing.expectEqualStrings(
    ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt",
    paths.query_report_path,
);
```

Update `scenario dev loop paths include scenario slug` to assert:

```zig
try std.testing.expectEqualStrings(
    ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-queries.txt",
    paths.query_report_path,
);
```

- [ ] **Step 2: Add query report formatting tests**

Add:

```zig
test "query report runs selected dogfood follow-up queries" {
    const report = try buildQueryReport(std.testing.allocator, dogfood_query_json, ".zig-cache/causal-artifacts/after.json");
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal query report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "query: causal-query -- --file .zig-cache/causal-artifacts/after.json cause 3") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal.query: requirements 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal.query: resources 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal.query: fibers pending") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal.query: retries 1") != null);
}

test "query report is explicit when no follow-up queries are selected" {
    const report = try buildQueryReport(std.testing.allocator, no_finding_query_json, ".zig-cache/causal-artifacts/after.json");
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "queries: 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "no follow-up queries selected") != null);
}
```

- [ ] **Step 3: Verify red**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: fail because `query_report_path`, `buildQueryReport`, and test JSON
fixtures do not exist.

## Task 2: Add Query Report Path And Build Import

**Files:**

- Modify `packages/zigeffect/build.zig`
- Modify `packages/zigeffect/tools/causal_loop.zig`

- [ ] **Step 1: Import causal_query into loop module**

In `build.zig`, add:

```zig
causal_loop_tool_module.addImport("causal_query", causal_query_tool_module);
```

- [ ] **Step 2: Add `query_report_path` to `LoopPaths`**

Add the field, deinit handling, default path, and scenario path:

```zig
query_report_path: []const u8,
```

Default:

```txt
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt
```

Scenario:

```txt
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-queries.txt
```

## Task 3: Implement Query Selection And Report Formatting

**Files:**

- Modify `packages/zigeffect/tools/causal_loop.zig`

- [ ] **Step 1: Add local event parser types**

Add `Artifact` and `Event` structs matching the causal JSON shape.

- [ ] **Step 2: Add query selection helpers**

Add helpers:

- `buildQueryReport(allocator, json, artifact_path)`;
- `appendFindingQueries(output, allocator, json, artifact_path, events, event)`;
- `appendQuery(output, allocator, json, artifact_path, args)`;
- `hasFinalizedResource(events, acquired)`;
- duplicate exact query suppression.

- [ ] **Step 3: Call `causal_query.runQuery`**

`appendQuery` should print the command line and append the returned query
output.

- [ ] **Step 4: Verify green**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: query report tests pass.

## Task 4: Write Query Report During After Phase

**Files:**

- Modify `packages/zigeffect/tools/causal_loop.zig`

- [ ] **Step 1: Generate report after compare**

In `runAfter`, after writing the compare report, call:

```zig
const query_report = try buildQueryReport(allocator, after, paths.after_json_path);
defer allocator.free(query_report);
try writeArtifact(init.io, paths.query_report_path, query_report);
```

- [ ] **Step 2: Add summary path**

In after summaries, print:

```txt
query report: <path>
```

Keep concise next-query commands if useful, but the query report path should be
the primary follow-up.

## Task 5: Update Docs, Verify, And Commit

**Files:**

- Modify docs listed above.

- [ ] **Step 1: Document query report artifacts**

Mention:

```txt
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-queries.txt
```

- [ ] **Step 2: Run runtime checks**

Run:

```sh
cd packages/zigeffect && zig build causal-dev-loop -- baseline
cd packages/zigeffect && zig build causal-dev-loop -- after
cd packages/zigeffect && zig build causal-dev-loop -- baseline missing-service-compile-fail
cd packages/zigeffect && zig build causal-dev-loop -- after missing-service-compile-fail
```

Expected: after phases write query report artifacts with executed
`causal.query` output.

- [ ] **Step 3: Run broad verification**

Run:

```sh
cd packages/zigeffect && zig build test
cd packages/zigeffect && zig build examples
bun run zig:test
git diff --check
```

Expected: all pass.

- [ ] **Step 4: Commit**

Run:

```sh
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-loop-auto-query-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-loop-auto-query.md docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md packages/zigeffect/build.zig packages/zigeffect/tools/causal_loop.zig packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/docs/causal-scenarios.md
git commit -m "feat(zigeffect): add causal loop query reports"
```

Expected: commit succeeds.

## Self-Review

- Spec coverage: The plan covers paths, query selection, report generation,
  after-phase writing, docs, verification, and commit.
- Placeholder scan: No placeholder-only implementation steps remain.
- Scope check: App-facing development loops remain a later slice.
