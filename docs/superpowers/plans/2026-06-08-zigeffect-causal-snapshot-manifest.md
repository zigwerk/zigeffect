# Zigeffect Causal Snapshot Manifest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a versioned named snapshot manifest tool for existing zigeffect causal JSON artifacts.

**Architecture:** Create `tools/causal_snapshot.zig` as a pure formatter plus CLI wrapper. The formatter parses existing causal JSON, computes small derived metadata, emits JSON/text manifests, and never mutates source code or reruns tests. The CLI supports `manifest` for stdout and `capture` for writing manifest files that reference known existing causal artifacts.

**Tech Stack:** Zig tool module under `packages/zigeffect`, existing `causal_artifact` compatibility helpers, existing `causal_run` artifact path helpers, `std.json`, Bun repo checks.

---

## Files

- Create: `packages/zigeffect/tools/causal_snapshot.zig`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Task 1: Specify Snapshot Manifest Tool

**Files:**
- Create: `packages/zigeffect/tools/causal_snapshot.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add tests-first tool skeleton**

Create `packages/zigeffect/tools/causal_snapshot.zig` with imports, fixtures, and tests that reference the desired API:

```zig
const std = @import("std");
const causal_artifact = @import("causal_artifact");
const causal_run = @import("causal_run");

pub const snapshot_manifest_schema = "zigeffect.causal.snapshot-manifest.v1";
pub const snapshot_manifest_schema_version: u32 = 1;

const sample_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"baseline","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"Config","status":"missing","redacted_detail":"missing provider"},
    \\    {"id":3,"kind":"schedule_decision","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"retry","type_name":"Schedule.exponential","status":"exhausted","redacted_detail":"budget exhausted"}
    \\  ]
    \\}
;

const future_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 2,
    \\  "event_taxonomy_version": 3,
    \\  "events": [
    \\    {"id":4,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":5,"kind":"effect_suspended","run_id":1,"parent_id":4,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future event","type_name":"Command","status":"pending","redacted_detail":""}
    \\  ]
    \\}
;

test "snapshot manifest json names artifact and derived event metadata" {
    const manifest = try formatSnapshotManifestJson(std.testing.allocator, sample_json, .{
        .name = "baseline",
        .target = "dogfood",
        .phase = "baseline",
        .artifact_path = ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
    });
    defer std.testing.allocator.free(manifest);

    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"schema\":\"zigeffect.causal.snapshot-manifest.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"name\":\"baseline\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"target\":\"dogfood\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"phase\":\"baseline\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"events\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"first_event_id\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"last_event_id\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"findings\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"feasible\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json snapshot") != null);
}

test "snapshot manifest text includes replay posture and next query" {
    const report = try formatSnapshotManifestText(std.testing.allocator, sample_json, .{
        .name = "after",
        .target = "package-tests",
        .phase = "after",
        .artifact_path = ".zig-cache/causal-artifacts/zigeffect-causal-package-tests.json",
        .baseline_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-before.json",
        .compare_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-compare.txt",
    });
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal snapshot manifest") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "name: after") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "target: package-tests") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "baseline: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-before.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "compare report: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-compare.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "replay feasible: false") != null);
}

test "snapshot manifest warns for future artifact shape and unknown event kind" {
    const manifest = try formatSnapshotManifestJson(std.testing.allocator, future_json, .{
        .name = "future",
        .artifact_path = ".zig-cache/causal-artifacts/future.json",
    });
    defer std.testing.allocator.free(manifest);

    try std.testing.expect(std.mem.indexOf(u8, manifest, "schema_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "event_taxonomy_version=3 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "event kind effect_suspended unknown") != null);
}

test "snapshot names validate before path formatting" {
    try validateSnapshotName("baseline");
    try validateSnapshotName("after_1");
    try std.testing.expectError(error.InvalidSnapshotName, validateSnapshotName(""));
    try std.testing.expectError(error.InvalidSnapshotName, validateSnapshotName("../oops"));
    try std.testing.expectError(error.InvalidSnapshotName, validateSnapshotName("bad name"));
}

test "snapshot manifest paths are deterministic" {
    const paths = try snapshotManifestPaths(std.testing.allocator, "baseline");
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json", paths.json_path);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.txt", paths.text_path);
}
```

- [ ] **Step 2: Add the build step for the red test**

In `packages/zigeffect/build.zig`, add the new tool module near the query/compare
tools:

```zig
const causal_snapshot_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_snapshot.zig"),
    .target = target,
    .optimize = optimize,
});
causal_snapshot_tool_module.addImport("causal_artifact", causal_artifact_tool_module);
causal_snapshot_tool_module.addImport("causal_run", causal_run_tool_module);

const causal_snapshot_tool = b.addExecutable(.{
    .name = "zigeffect-causal-snapshot",
    .root_module = causal_snapshot_tool_module,
});
const run_causal_snapshot_tool = b.addRunArtifact(causal_snapshot_tool);
if (b.args) |args| run_causal_snapshot_tool.addArgs(args);
const causal_snapshot_step = b.step("causal-snapshot", "Format or capture named causal snapshot manifests");
causal_snapshot_step.dependOn(&run_causal_snapshot_tool.step);

const causal_snapshot_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-snapshot-tests",
    .root_module = causal_snapshot_tool_module,
});
const run_causal_snapshot_tool_tests = b.addRunArtifact(causal_snapshot_tool_tests);
```

Add the tool and tests to `examples_step`:

```zig
examples_step.dependOn(&causal_snapshot_tool.step);
examples_step.dependOn(&run_causal_snapshot_tool_tests.step);
```

- [ ] **Step 3: Run the red test**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: FAIL because `formatSnapshotManifestJson`,
`formatSnapshotManifestText`, `validateSnapshotName`, and
`snapshotManifestPaths` are referenced by tests but not implemented.

- [ ] **Step 4: Commit the red specification**

```sh
git add packages/zigeffect/tools/causal_snapshot.zig packages/zigeffect/build.zig
git commit -m "test(zigeffect): specify causal snapshot manifest"
```

## Task 2: Implement Snapshot Manifest Formatters And CLI

**Files:**
- Modify: `packages/zigeffect/tools/causal_snapshot.zig`

- [ ] **Step 1: Implement public types and helpers**

Add these public structs and helpers above the tests:

```zig
pub const SnapshotManifestOptions = struct {
    name: []const u8,
    target: []const u8 = "manual",
    phase: []const u8 = "manual",
    artifact_path: []const u8,
    baseline_path: ?[]const u8 = null,
    compare_report_path: ?[]const u8 = null,
    query_report_path: ?[]const u8 = null,
    advice_report_path: ?[]const u8 = null,
};

pub const SnapshotManifestPaths = struct {
    json_path: []const u8,
    text_path: []const u8,

    pub fn deinit(self: SnapshotManifestPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json_path);
        allocator.free(self.text_path);
    }
};

const Artifact = struct {
    schema: ?[]const u8 = null,
    schema_version: ?u32 = null,
    event_taxonomy_version: ?u32 = null,
    events: []Event,
};

const Event = struct {
    id: u64,
    kind: []const u8,
    run_id: ?u64,
    parent_id: ?u64,
    fiber_id: ?u64,
    scope_id: ?u64,
    trace_id: ?u64,
    span_id: ?u64,
    label: []const u8,
    type_name: []const u8,
    status: []const u8,
    redacted_detail: []const u8,
};
```

- [ ] **Step 2: Implement validation, paths, and JSON escaping**

Implement:

```zig
pub fn validateSnapshotName(name: []const u8) error{InvalidSnapshotName}!void
pub fn snapshotManifestPaths(allocator: std.mem.Allocator, name: []const u8) !SnapshotManifestPaths
fn appendJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void
fn appendOptionalJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: ?[]const u8) !void
```

Rules:

- name length must be 1..64
- name cannot equal `.` or `..`
- allowed bytes are ASCII letters, digits, `_`, and `-`
- paths are `.zig-cache/causal-artifacts/zigeffect-causal-snapshot-<name>.json`
  and `.txt`

- [ ] **Step 3: Implement derived artifact metadata**

Implement:

```zig
fn findingCount(events: []const Event) usize
fn hasFinalizedResource(events: []const Event, acquired: Event) bool
fn pendingFiberCountAfterScopeClose(events: []const Event, closed: Event) usize
fn fiberCompletedAfter(events: []const Event, fiber_id: u64, closed_event_id: u64) bool
fn firstEventId(events: []const Event) ?u64
fn lastEventId(events: []const Event) ?u64
```

Use the same finding heuristic as compare/advice:

- `resource_acquired` without matching `resource_finalized`
- pending/running fiber after `scope_closed`
- `resource_finalized` with `status="failure"`
- `schedule_decision` with `status="exhausted"`
- `service_required` with `status="missing"`
- `assertion_recorded` with `status="failure"`

- [ ] **Step 4: Implement warnings**

Implement:

```zig
fn appendWarningsText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), metadata: causal_artifact.ArtifactMetadata, events: []const Event) !void
fn appendWarningsJsonArray(allocator: std.mem.Allocator, output: *std.ArrayList(u8), metadata: causal_artifact.ArtifactMetadata, events: []const Event) !void
```

The warning text should match existing compatibility wording closely enough for
tests:

- `schema_version=2 newer than supported=1`
- `event_taxonomy_version=3 newer than supported=1`
- `event kind effect_suspended unknown`

- [ ] **Step 5: Implement JSON formatter**

Implement:

```zig
pub fn formatSnapshotManifestJson(
    allocator: std.mem.Allocator,
    artifact_json: []const u8,
    options: SnapshotManifestOptions,
) ![]const u8
```

Formatter behavior:

- validate snapshot name first
- parse causal JSON with `.ignore_unknown_fields = true`
- emit deterministic compact JSON
- include schema, schema version, name, target, phase, artifact metadata,
  related paths, replay feasibility, next queries, and warnings

- [ ] **Step 6: Implement text formatter**

Implement:

```zig
pub fn formatSnapshotManifestText(
    allocator: std.mem.Allocator,
    artifact_json: []const u8,
    options: SnapshotManifestOptions,
) ![]const u8
```

Formatter behavior:

- validate snapshot name first
- parse causal JSON
- emit readable text summary
- include baseline/compare/query/advice lines only when paths are present
- include warnings only when present

- [ ] **Step 7: Implement CLI**

Add:

```zig
fn usage() []const u8
fn failUsage(err: anyerror) noreturn
fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void
fn captureSourcePath(allocator: std.mem.Allocator, scenario_slug: ?[]const u8) ![]const u8
pub fn main(init: std.process.Init) !void
```

CLI behavior:

- `manifest <name> <artifact.json> [--format json|text] [--target ...] [--phase ...] [--baseline ...] [--compare-report ...] [--query-report ...] [--advice-report ...]`
- `capture <name> [scenario]`
- `capture` reads the known source JSON, writes JSON/text manifests to
  `snapshotManifestPaths`, and prints a small text summary with output paths

- [ ] **Step 8: Run green tests**

Run:

```sh
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build causal-snapshot -- manifest baseline .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
```

Expected: `zig build examples` passes. The direct manifest command may fail with
`FileNotFound` if the dogfood artifact has not been generated in the current
cache; if so, first run `zig build causal-test`, then rerun the command.

- [ ] **Step 9: Commit implementation**

```sh
git add packages/zigeffect/tools/causal_snapshot.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): add causal snapshot manifest tool"
```

## Task 3: Document Snapshot Manifests

**Files:**
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add snapshot manifest paths to artifact retention manifest**

In `packages/zigeffect/tools/causal_artifacts.zig`, add default paths:

```zig
try output.print(allocator, "- snapshot manifest json {s}/zigeffect-causal-snapshot-baseline.json\n", .{causal_run.artifact_dir});
try output.print(allocator, "- snapshot manifest text {s}/zigeffect-causal-snapshot-baseline.txt\n", .{causal_run.artifact_dir});
```

Add test assertions for both paths.

- [ ] **Step 2: Update README and agent docs**

Add a short usage section to README and agent guide:

```md
Use `zig build causal-snapshot -- capture <name> [scenario]` after a causal JSON
artifact already exists. It writes a versioned snapshot manifest JSON/text pair
that names the artifact, records event counts and finding posture, and gives
agents stable query commands. Snapshot manifests do not embed events and do not
make replay feasible yet.
```

- [ ] **Step 3: Update observable runtime and scenarios docs**

Document:

- schema `zigeffect.causal.snapshot-manifest.v1`
- `manifest` and `capture` commands
- capture is read-only over existing artifacts
- replay remains not feasible until later M5 work

- [ ] **Step 4: Update master roadmap**

Change M5 progress ledger evidence to:

```md
snapshot manifest schema/tool exists; compare and audit-chain tools already exist
```

Change M5 next action to:

```md
build snapshot compare over named manifests
```

Change immediate branch queue to:

```md
1. `codex/zigeffect-causal-snapshot-compare`
   - Compare named snapshot manifests and their underlying causal JSON artifacts.
```

- [ ] **Step 5: Run doc/tool checks**

Run:

```sh
cd packages/zigeffect && zig build examples
rg -n "causal-snapshot|snapshot-manifest|zigeffect.causal.snapshot-manifest.v1|replay feasible" packages/zigeffect/README.md packages/zigeffect/docs docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Expected: examples pass and docs mention snapshot manifests without claiming
replay support.

- [ ] **Step 6: Commit docs**

```sh
git add packages/zigeffect/tools/causal_artifacts.zig packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/docs/causal-scenarios.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): document causal snapshot manifests"
```

## Task 4: Verify And Merge

**Files:**
- No planned edits.

- [ ] **Step 1: Run focused gates**

Run:

```sh
cd packages/zigeffect && zig build causal-snapshot
cd packages/zigeffect && zig build causal-test
cd packages/zigeffect && zig build causal-snapshot -- manifest baseline .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
cd packages/zigeffect && zig build causal-snapshot -- manifest baseline .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json --format text
```

Expected: all commands pass after `causal-test` creates the dogfood JSON
artifact.

- [ ] **Step 2: Run package gates**

Run:

```sh
cd packages/zigeffect && zig build test-raw --summary none
cd packages/zigeffect && zig build test --summary none
cd packages/zigeffect && zig build causal-test-matrix
cd packages/zigeffect && zig build examples
```

Expected: all pass. The matrix should preserve the existing domain coverage
status.

- [ ] **Step 3: Run repo gates**

Run:

```sh
bun run check
bun run zig:test
git diff --check HEAD
```

Expected: all pass. `bun run check` should remain 259 pass, 11 skip, 0 fail
unless unrelated repo tests change.

- [ ] **Step 4: Merge and branch next**

Run:

```sh
git switch master
git merge --ff-only codex/zigeffect-causal-snapshot-manifest
git branch -d codex/zigeffect-causal-snapshot-manifest
cd packages/zigeffect && zig build causal-snapshot
cd packages/zigeffect && zig build test --summary none
bun run check
bun run zig:test
git diff --check HEAD
git switch -c codex/zigeffect-causal-snapshot-compare
```

Expected: fast-forward merge succeeds, post-merge smoke passes, and the next M5
branch is created.

## Self-Review

- Spec coverage: the plan covers schema, JSON/text formatters, manifest/capture
  commands, name validation, finding count, warnings, build integration, docs,
  and verification.
- Placeholder scan: no unspecified implementation steps or open-ended TODOs.
- Type consistency: public names match the design:
  `SnapshotManifestOptions`, `SnapshotManifestPaths`,
  `formatSnapshotManifestJson`, `formatSnapshotManifestText`,
  `validateSnapshotName`, and `snapshotManifestPaths`.
