# zigeffect Causal Agent Query Compare Runs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add bounded cross-run comparison to `causal-query --agent` while
preserving the existing `zigeffect.causal.agent-query.v1` contract.

**Architecture:** Extend `packages/zigeffect/tools/causal_query.zig` with an
optional `--compare-file` CLI flag, a `compare_runs <left_run_id>:<right_run_id>`
query, per-side bounded run selection, deterministic delta summaries, dual
artifact warnings/limitations, and query-specific `comparison` JSON inside the
existing agent envelope. Update docs, schema governance prose, and production
hardening backlog handoff. Do not add durable writes, live telemetry, Cockroach,
new adapters, or mutation authority.

**Tech Stack:** Zig 0.16, `std.json.parseFromSlice`, existing `causal_artifact`
compatibility helpers, existing `causal-query` build/test step, Bun root
verification.

---

## File Map

- Modify: `packages/zigeffect/tools/causal_query.zig`
  - Add `--compare-file` parser support in `main`.
  - Add `runQueryCompareFiles` or equivalent helper for two JSON inputs.
  - Add `compare_runs` selection, summary, bounded event merge, warnings,
    limitations, next-query hints, and tests.
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
  - Document delivered `compare_runs` and CLI examples.
- Modify: `packages/zigeffect/docs/schema-governance.md`
  - Update `agent-query.v1` description to include cross-run comparison.
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
  - Update the `agent-query` schema entry description/compatibility notes if
    needed. Do not bump schema count unless a new schema is added.
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Mark cross-run comparison as delivered and advance the recommended next
    branch.
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
  - Reflect delivered cross-run comparison and the next handoff.
- Modify: `packages/zigeffect/docs/roadmap.md`
  - Mark this milestone delivered.
- Modify: `packages/zigeffect/README.md`
  - Add short command example.
- Modify:
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark branch 45 delivered and set the next branch.
- Add this plan and companion design doc under `docs/superpowers/`.

## Task 1: Add Red Tests

**Files:**
- Modify: `packages/zigeffect/tools/causal_query.zig`

- [ ] **Step 1: Add compare fixture JSON**

Add a deterministic fixture with two run ids and distinct failure/status/kind
shape. Include retention, sampling, and truncation metadata so confidence and
limitations behavior can be verified.

- [ ] **Step 2: Add same-artifact comparison test**

Add:

```zig
test "agent compare_runs compares two runs from one artifact" {
    const output = try runQuery(
        std.testing.allocator,
        compare_runs_sample_json,
        &.{ "--agent", "compare_runs", "1:2" },
    );
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "\"query\":\"compare_runs\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"comparison\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"left_run_id\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"right_run_id\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"failure_delta\":-") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "both runs selected from same artifact") != null);
}
```

- [ ] **Step 3: Add cross-artifact comparison test**

Expose a helper such as:

```zig
pub fn runQueryCompareFiles(
    allocator: std.mem.Allocator,
    left_json: []const u8,
    right_json: []const u8,
    args: []const []const u8,
) ![]const u8
```

Then test:

```zig
test "agent compare_runs compares two files with bounded evidence" {
    const output = try runQueryCompareFiles(
        std.testing.allocator,
        compare_runs_left_json,
        compare_runs_right_json,
        &.{ "--agent", "--limit", "5", "compare_runs", "1:2" },
    );
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "\"truncated\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"limit\":5") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"left\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"right\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "<left-artifact.json>") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "<right-artifact.json>") != null);
}
```

- [ ] **Step 4: Add negative and warning tests**

Add tests for:

- malformed pair `compare_runs nope`;
- missing pair argument;
- absent left or right run evidence;
- warning labels for unsupported/future/unknown left and right artifacts;
- `next_queries` commands distinguishing left and right artifacts.

- [ ] **Step 5: Verify RED**

Run:

```sh
cd packages/zigeffect && zig build causal-query
```

Expected: compile/test failures until implementation exists.

## Task 2: Implement Parser And Query Entry Point

**Files:**
- Modify: `packages/zigeffect/tools/causal_query.zig`

- [ ] **Step 1: Add compare-file support to CLI main**

Track:

```zig
var file_path: []const u8 = default_artifact_path;
var compare_file_path: ?[]const u8 = null;
```

Parse `--compare-file <path>` beside `--file <path>`. Read the second file only
when provided.

- [ ] **Step 2: Add two-artifact run helper**

Keep `runQuery` compatibility by routing it through a helper with optional
right JSON:

```zig
pub fn runQuery(allocator: std.mem.Allocator, json: []const u8, args: []const []const u8) ![]const u8;
pub fn runQueryCompareFiles(allocator: std.mem.Allocator, left_json: []const u8, right_json: []const u8, args: []const []const u8) ![]const u8;
```

The single-artifact path should call the shared implementation with
`right_json = null`.

- [ ] **Step 3: Parse run pair**

Implement `parseRunPair("1:2")` with typed errors:

- `MissingQueryArgument`;
- `InvalidQueryNumber`.

Reject missing colon, empty sides, extra colon, or non-numeric sides.

## Task 3: Implement Run Comparison Data Model

**Files:**
- Modify: `packages/zigeffect/tools/causal_query.zig`

- [ ] **Step 1: Select per-side run events**

Add a helper:

```zig
fn appendRunEvents(allocator: std.mem.Allocator, output: *std.ArrayList(Event), events: []const Event, run_id: u64) !void
```

Use it for both existing `summarize_run` and new comparison if it simplifies
the code.

- [ ] **Step 2: Calculate side stats**

For each side compute:

- `matched_events`;
- `returned_events`;
- `failure_events`;
- `finding_events`;
- first retained event id;
- last retained event id;
- selected returned event ids.

Use existing `isFailureEvidence` for finding/failure evidence unless a stronger
local helper already exists.

- [ ] **Step 3: Calculate deltas and set differences**

Compute deterministic first-seen arrays for:

- `left_only_kinds`;
- `right_only_kinds`;
- `left_only_statuses`;
- `right_only_statuses`.

Compute signed:

- `event_delta = right.matched_events - left.matched_events`;
- `failure_delta = right.failure_events - left.failure_events`;
- `finding_delta = right.finding_events - left.finding_events`.

- [ ] **Step 4: Bound returned events**

Split `--limit` between sides:

- `left_limit = limit / 2`;
- `right_limit = limit - left_limit`;
- if `left_limit == 0`, force `1` when left has evidence and adjust right
  accordingly.

Append left returned events first, then right returned events. The aggregate
`total_matched_events` is left plus right matched counts.

## Task 4: Implement Agent JSON Extension

**Files:**
- Modify: `packages/zigeffect/tools/causal_query.zig`

- [ ] **Step 1: Add comparison formatter**

Add an optional comparison object to the existing formatter. Keep field order
stable and append it before `events` or after `limitations`; choose the least
intrusive location and test for substrings rather than fragile full equality.

- [ ] **Step 2: Add dual artifact warnings**

Call existing warning helpers for both artifacts with labels:

- `left`;
- `right`.

When `--compare-file` is omitted, avoid duplicate warnings and add a limitation
instead.

- [ ] **Step 3: Add dual artifact limitations**

Extend limitations with per-side policy metadata absence. Preserve existing
single-artifact behavior for non-compare queries.

- [ ] **Step 4: Add comparison-aware confidence**

Return `partial` when:

- either side is truncated;
- either artifact has dropped/sampled/truncated evidence;
- either requested run has zero retained events.

Otherwise return `complete`.

- [ ] **Step 5: Add comparison-aware next queries**

For compare output, append:

- summarize left run;
- summarize right run;
- find failures left run;
- find failures right run;
- explain/trace selected evidence ids where available.

Use `<left-artifact.json>` and `<right-artifact.json>` placeholders for
cross-file queries. Use `<artifact.json>` for same-artifact comparison.

## Task 5: Update Docs And Governance

**Files:**
- Modify docs and governance files from the file map.

- [ ] **Step 1: Agent observable runtime docs**

Remove the "future work" language for `compare_runs` and add CLI examples.

- [ ] **Step 2: Schema governance docs/tool**

Record that `agent-query.v1` now covers runtime queries, app semantic
`trace_data`, and bounded cross-run comparison. Keep schema count at `81` unless
new schema constants are added.

- [ ] **Step 3: Production hardening backlog**

Update the backlog item:

- `agent-query-interface` is delivered rather than partial;
- cross-run comparison is delivered;
- recommended next branch advances to the next unresolved milestone.

Candidate next branch:

`codex/zigeffect-causal-audit-chain-snapshot-compare`

- [ ] **Step 4: Roadmap/README docs**

Add short delivered notes and command examples.

## Task 6: Verification

Run focused checks first:

```sh
cd packages/zigeffect && zig build causal-query
cd packages/zigeffect && zig build causal-query -- --agent --file <fixture> compare_runs 1:2
cd packages/zigeffect && zig build causal-schema-governance -- --format json
cd packages/zigeffect && zig build causal-production-hardening-backlog -- --format json
cd packages/zigeffect && zig fmt --check tools/causal_query.zig tools/causal_schema_governance.zig tools/causal_production_hardening_backlog.zig build.zig
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test
bun run check
bun run zig:test
git diff --check
```

If the explicit CLI fixture path is inconvenient, use the generated causal
artifact from the zigeffect examples or create a temporary `.zig-cache` fixture
outside source control.

## Commit Plan

1. Commit the design doc:

```sh
git add docs/superpowers/specs/2026-06-11-zigeffect-causal-agent-query-compare-runs-design.md
git commit -m "docs(zigeffect): design agent query cross-run comparison"
```

2. Commit this implementation plan:

```sh
git add docs/superpowers/plans/2026-06-11-zigeffect-causal-agent-query-compare-runs-implementation.md
git commit -m "docs(zigeffect): plan agent query cross-run comparison"
```

3. Commit implementation:

```sh
git add packages/zigeffect docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): add agent query cross-run comparison"
```

## Success Criteria

- `compare_runs` works in `causal-query --agent`.
- Same-artifact and cross-artifact comparisons are supported.
- Output is bounded and reports truncation honestly.
- Warnings, limitations, and confidence account for both sides.
- Next-query hints are useful for self-improving agents and CI triage.
- Docs and backlog no longer call cross-run comparison future work.
- No new mutation authority, live telemetry, Cockroach scope, or durable write
  authority is introduced.
