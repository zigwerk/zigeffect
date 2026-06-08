# zigeffect Causal Snapshot Compare Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add first-class comparison for named zigeffect causal snapshot manifests.

**Architecture:** Extend `tools/causal_snapshot.zig` with manifest parsing, reference resolution, snapshot-level text report formatting, and a `compare` CLI subcommand. Keep event-level diffing delegated to `causal_compare.runCompare`, and keep all state local to existing manifest/artifact files.

**Tech Stack:** Zig tool module under `packages/zigeffect`, existing `causal_snapshot` manifest helpers, existing `causal_compare` event diff engine, `std.json`, Bun repo checks.

---

## Files

- Modify: `packages/zigeffect/tools/causal_snapshot.zig`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Task 1: Specify Snapshot Compare Behavior

**Files:**
- Modify: `packages/zigeffect/tools/causal_snapshot.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add compare import and schema constants to the snapshot tool**

In `packages/zigeffect/tools/causal_snapshot.zig`, add `causal_compare` beside
the existing imports and add compare schema constants after the manifest
schema constants:

```zig
const std = @import("std");
const causal_artifact = @import("causal_artifact");
const causal_compare = @import("causal_compare");
const causal_run = @import("causal_run");

pub const snapshot_manifest_schema = "zigeffect.causal.snapshot-manifest.v1";
pub const snapshot_manifest_schema_version: u32 = 1;
pub const snapshot_compare_schema = "zigeffect.causal.snapshot-compare.v1";
pub const snapshot_compare_schema_version: u32 = 1;
```

- [ ] **Step 2: Add failing compare fixtures and tests**

In `packages/zigeffect/tools/causal_snapshot.zig`, add these fixtures near the
existing sample JSON fixtures:

```zig
const compare_before_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"scenario","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"Config","status":"missing","redacted_detail":"missing provider"}
    \\  ]
    \\}
;

const compare_after_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"scenario","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"Config","status":"provided","redacted_detail":"provider added"},
    \\    {"id":3,"kind":"exit_recorded","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"scenario","type_name":"Command","status":"success","redacted_detail":""}
    \\  ]
    \\}
;

const baseline_manifest_json =
    \\{
    \\  "schema": "zigeffect.causal.snapshot-manifest.v1",
    \\  "schema_version": 1,
    \\  "name": "baseline",
    \\  "target": "dogfood",
    \\  "phase": "baseline",
    \\  "artifact": {
    \\    "path": ".zig-cache/causal-artifacts/before.json",
    \\    "schema": "zigeffect.causal.v1",
    \\    "schema_version": 1,
    \\    "event_taxonomy_version": 1,
    \\    "events": 2,
    \\    "first_event_id": 1,
    \\    "last_event_id": 2,
    \\    "findings": 1
    \\  },
    \\  "warnings": []
    \\}
;

const after_manifest_json =
    \\{
    \\  "schema": "zigeffect.causal.snapshot-manifest.v1",
    \\  "schema_version": 1,
    \\  "name": "after",
    \\  "target": "dogfood",
    \\  "phase": "after",
    \\  "artifact": {
    \\    "path": ".zig-cache/causal-artifacts/after.json",
    \\    "schema": "zigeffect.causal.v1",
    \\    "schema_version": 1,
    \\    "event_taxonomy_version": 1,
    \\    "events": 3,
    \\    "first_event_id": 1,
    \\    "last_event_id": 3,
    \\    "findings": 0
    \\  },
    \\  "warnings": []
    \\}
;

const future_manifest_json =
    \\{
    \\  "schema": "zigeffect.causal.snapshot-manifest.v1",
    \\  "schema_version": 2,
    \\  "name": "future",
    \\  "target": "dogfood",
    \\  "phase": "after",
    \\  "artifact": {
    \\    "path": ".zig-cache/causal-artifacts/future.json",
    \\    "events": 2,
    \\    "first_event_id": 4,
    \\    "last_event_id": 5,
    \\    "findings": 0
    \\  },
    \\  "warnings": [
    \\    "warning: artifact event kind effect_suspended unknown to supported taxonomy=1"
    \\  ]
    \\}
;
```

Then add these tests after the existing snapshot manifest tests:

```zig
test "snapshot compare report names manifests and embeds causal compare" {
    const report = try formatSnapshotCompareText(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json",
        baseline_manifest_json,
        compare_before_json,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-after.json",
        after_manifest_json,
        compare_after_json,
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal snapshot compare report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.snapshot-compare.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "left snapshot: baseline") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "left manifest: .zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "left target: dogfood") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "left phase: baseline") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "left artifact: .zig-cache/causal-artifacts/before.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "right snapshot: after") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "right phase: after") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "right artifact: .zig-cache/causal-artifacts/after.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event delta from manifests: +1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "finding delta from manifests: -1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event compare:\nzigeffect causal compare report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "changed events:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "next queries:") != null);
}

test "snapshot compare report surfaces manifest warnings" {
    const report = try formatSnapshotCompareText(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json",
        baseline_manifest_json,
        compare_before_json,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-future.json",
        future_manifest_json,
        future_json,
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "manifest warnings:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "warning: right manifest schema_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "right manifest: warning: artifact event kind effect_suspended unknown") != null);
}

test "snapshot manifest references resolve names and explicit paths" {
    const named = try resolveSnapshotManifestReference(std.testing.allocator, "baseline");
    defer named.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json", named.path);

    const explicit = try resolveSnapshotManifestReference(std.testing.allocator, ".zig-cache/causal-artifacts/custom.json");
    defer explicit.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom.json", explicit.path);

    try std.testing.expectError(error.InvalidSnapshotName, resolveSnapshotManifestReference(std.testing.allocator, "bad name"));
}
```

- [ ] **Step 3: Wire the snapshot tool to the compare module**

In `packages/zigeffect/build.zig`, add this import after the existing snapshot
tool imports:

```zig
causal_snapshot_tool_module.addImport("causal_compare", causal_compare_tool_module);
```

- [ ] **Step 4: Run the red test**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: FAIL because `formatSnapshotCompareText` and
`resolveSnapshotManifestReference` are referenced but not implemented.

- [ ] **Step 5: Commit the red specification**

```sh
git add packages/zigeffect/tools/causal_snapshot.zig packages/zigeffect/build.zig
git commit -m "test(zigeffect): specify causal snapshot compare"
```

## Task 2: Implement Snapshot Compare

**Files:**
- Modify: `packages/zigeffect/tools/causal_snapshot.zig`

- [ ] **Step 1: Add manifest parse structs and reference path type**

Add these types above the formatter helpers:

```zig
pub const SnapshotManifestReferencePath = struct {
    path: []const u8,

    pub fn deinit(self: SnapshotManifestReferencePath, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
    }
};

const SnapshotManifestForCompare = struct {
    schema: ?[]const u8 = null,
    schema_version: ?u32 = null,
    name: []const u8,
    target: []const u8,
    phase: []const u8,
    artifact: SnapshotManifestArtifactForCompare,
    warnings: ?[]const []const u8 = null,
};

const SnapshotManifestArtifactForCompare = struct {
    path: []const u8,
    schema: ?[]const u8 = null,
    schema_version: ?u32 = null,
    event_taxonomy_version: ?u32 = null,
    events: usize = 0,
    first_event_id: ?u64 = null,
    last_event_id: ?u64 = null,
    findings: usize = 0,
};
```

- [ ] **Step 2: Implement reference resolution**

Add:

```zig
pub fn resolveSnapshotManifestReference(allocator: std.mem.Allocator, value: []const u8) !SnapshotManifestReferencePath {
    if (isExplicitSnapshotManifestPath(value)) {
        return .{ .path = try allocator.dupe(u8, value) };
    }

    const paths = try snapshotManifestPaths(allocator, value);
    allocator.free(paths.text_path);
    return .{ .path = paths.json_path };
}

fn isExplicitSnapshotManifestPath(value: []const u8) bool {
    return std.mem.indexOfScalar(u8, value, '/') != null or std.mem.endsWith(u8, value, ".json");
}
```

- [ ] **Step 3: Implement manifest artifact-path extraction for the CLI**

Add:

```zig
fn snapshotArtifactPathFromManifestJson(allocator: std.mem.Allocator, manifest_json: []const u8) ![]const u8 {
    var parsed = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, manifest_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    return allocator.dupe(u8, parsed.value.artifact.path);
}
```

- [ ] **Step 4: Implement signed delta and summary helpers**

Add:

```zig
fn appendSignedDeltaText(output: *std.ArrayList(u8), allocator: std.mem.Allocator, label: []const u8, delta: isize) !void {
    if (delta >= 0) {
        try output.print(allocator, "{s}: +{d}\n", .{ label, delta });
    } else {
        try output.print(allocator, "{s}: {d}\n", .{ label, delta });
    }
}

fn appendSnapshotManifestSummary(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    side: []const u8,
    manifest_path: []const u8,
    manifest: SnapshotManifestForCompare,
) !void {
    try output.print(allocator, "{s} snapshot: {s}\n", .{ side, manifest.name });
    try output.print(allocator, "{s} manifest: {s}\n", .{ side, manifest_path });
    try output.print(allocator, "{s} target: {s}\n", .{ side, manifest.target });
    try output.print(allocator, "{s} phase: {s}\n", .{ side, manifest.phase });
    try output.print(allocator, "{s} artifact: {s}\n", .{ side, manifest.artifact.path });
    try output.print(allocator, "{s} events: {d}\n", .{ side, manifest.artifact.events });
    if (manifest.artifact.first_event_id) |first| {
        if (manifest.artifact.last_event_id) |last| {
            try output.print(allocator, "{s} event ids: {d}..{d}\n", .{ side, first, last });
        }
    } else {
        try output.print(allocator, "{s} event ids: none\n", .{side});
    }
    try output.print(allocator, "{s} findings: {d}\n", .{ side, manifest.artifact.findings });
}
```

- [ ] **Step 5: Implement manifest warning helpers**

Add:

```zig
fn appendSnapshotManifestWarnings(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    side: []const u8,
    manifest: SnapshotManifestForCompare,
    wrote: *bool,
) !void {
    if (manifest.schema) |schema| {
        if (!std.mem.eql(u8, schema, snapshot_manifest_schema)) {
            try output.print(allocator, "- warning: {s} manifest schema={s} unsupported; expected {s}\n", .{ side, schema, snapshot_manifest_schema });
            wrote.* = true;
        }
    } else {
        try output.print(allocator, "- warning: {s} manifest schema missing; expected {s}\n", .{ side, snapshot_manifest_schema });
        wrote.* = true;
    }

    if (manifest.schema_version) |version| {
        if (version > snapshot_manifest_schema_version) {
            try output.print(allocator, "- warning: {s} manifest schema_version={d} newer than supported={d}\n", .{ side, version, snapshot_manifest_schema_version });
            wrote.* = true;
        }
    } else {
        try output.print(allocator, "- warning: {s} manifest schema_version missing; expected {d}\n", .{ side, snapshot_manifest_schema_version });
        wrote.* = true;
    }

    if (manifest.warnings) |warnings| {
        for (warnings) |warning| {
            try output.print(allocator, "- {s} manifest: {s}\n", .{ side, warning });
            wrote.* = true;
        }
    }
}
```

- [ ] **Step 6: Implement the compare formatter**

Add:

```zig
pub fn formatSnapshotCompareText(
    allocator: std.mem.Allocator,
    left_manifest_path: []const u8,
    left_manifest_json: []const u8,
    left_artifact_json: []const u8,
    right_manifest_path: []const u8,
    right_manifest_json: []const u8,
    right_artifact_json: []const u8,
) ![]const u8 {
    var left_parsed = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, left_manifest_json, .{ .ignore_unknown_fields = true });
    defer left_parsed.deinit();
    var right_parsed = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, right_manifest_json, .{ .ignore_unknown_fields = true });
    defer right_parsed.deinit();

    const compare_report = try causal_compare.runCompare(allocator, left_artifact_json, right_artifact_json);
    defer allocator.free(compare_report);

    const left = left_parsed.value;
    const right = right_parsed.value;

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal snapshot compare report\n");
    try output.print(allocator, "schema: {s}\n", .{snapshot_compare_schema});
    try output.print(allocator, "schema version: {d}\n", .{snapshot_compare_schema_version});
    try appendSnapshotManifestSummary(&output, allocator, "left", left_manifest_path, left);
    try appendSnapshotManifestSummary(&output, allocator, "right", right_manifest_path, right);
    try appendSignedDeltaText(&output, allocator, "event delta from manifests", @as(isize, @intCast(right.artifact.events)) - @as(isize, @intCast(left.artifact.events)));
    try appendSignedDeltaText(&output, allocator, "finding delta from manifests", @as(isize, @intCast(right.artifact.findings)) - @as(isize, @intCast(left.artifact.findings)));

    try output.appendSlice(allocator, "manifest warnings:\n");
    var wrote_warning = false;
    try appendSnapshotManifestWarnings(&output, allocator, "left", left, &wrote_warning);
    try appendSnapshotManifestWarnings(&output, allocator, "right", right, &wrote_warning);
    if (!wrote_warning) try output.appendSlice(allocator, "- none\n");

    try output.appendSlice(allocator, "event compare:\n");
    try output.appendSlice(allocator, compare_report);
    if (compare_report.len == 0 or compare_report[compare_report.len - 1] != '\n') {
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "next queries:\n");
    try output.print(allocator, "- zig build causal-query -- --file {s} snapshot\n", .{left.artifact.path});
    try output.print(allocator, "- zig build causal-query -- --file {s} snapshot\n", .{right.artifact.path});
    try output.print(allocator, "- zig build causal-compare -- {s} {s}\n", .{ left.artifact.path, right.artifact.path });

    return output.toOwnedSlice(allocator);
}
```

- [ ] **Step 7: Add the compare CLI branch**

Update `usage()` to include compare:

```zig
fn usage() []const u8 {
    return "usage: zig build causal-snapshot -- manifest <name> <artifact.json> [--format json|text] [--target <target>] [--phase <phase>] [--baseline <path>] [--compare-report <path>] [--query-report <path>] [--advice-report <path>]\n       zig build causal-snapshot -- capture <name> [scenario]\n       zig build causal-snapshot -- compare <left> <right>\n";
}
```

Add this branch in `main` before the final unknown-command failure:

```zig
    if (std.mem.eql(u8, args[1], "compare")) {
        if (args.len != 4) failUsage(error.InvalidSnapshotCompareArguments);
        const left_manifest_ref = try resolveSnapshotManifestReference(allocator, args[2]);
        defer left_manifest_ref.deinit(allocator);
        const right_manifest_ref = try resolveSnapshotManifestReference(allocator, args[3]);
        defer right_manifest_ref.deinit(allocator);

        const left_manifest_json = try std.Io.Dir.cwd().readFileAlloc(init.io, left_manifest_ref.path, allocator, .limited(1024 * 1024));
        defer allocator.free(left_manifest_json);
        const right_manifest_json = try std.Io.Dir.cwd().readFileAlloc(init.io, right_manifest_ref.path, allocator, .limited(1024 * 1024));
        defer allocator.free(right_manifest_json);

        const left_artifact_path = try snapshotArtifactPathFromManifestJson(allocator, left_manifest_json);
        defer allocator.free(left_artifact_path);
        const right_artifact_path = try snapshotArtifactPathFromManifestJson(allocator, right_manifest_json);
        defer allocator.free(right_artifact_path);

        const left_artifact_json = try std.Io.Dir.cwd().readFileAlloc(init.io, left_artifact_path, allocator, .limited(1024 * 1024));
        defer allocator.free(left_artifact_json);
        const right_artifact_json = try std.Io.Dir.cwd().readFileAlloc(init.io, right_artifact_path, allocator, .limited(1024 * 1024));
        defer allocator.free(right_artifact_json);

        const report = try formatSnapshotCompareText(
            allocator,
            left_manifest_ref.path,
            left_manifest_json,
            left_artifact_json,
            right_manifest_ref.path,
            right_manifest_json,
            right_artifact_json,
        );
        defer allocator.free(report);
        std.debug.print("{s}", .{report});
        return;
    }
```

- [ ] **Step 8: Run the green tests**

Run:

```sh
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build causal-snapshot
```

Expected: both pass. The no-arg `causal-snapshot` command prints usage and
exits zero.

- [ ] **Step 9: Smoke the CLI compare command**

Run:

```sh
cd packages/zigeffect
zig build causal-test
zig build causal-snapshot -- capture baseline
zig build causal-snapshot -- compare baseline baseline
```

Expected: compare prints a `zigeffect causal snapshot compare report` and an
embedded `zigeffect causal compare report` for the baseline artifact.

- [ ] **Step 10: Commit the implementation**

```sh
git add packages/zigeffect/tools/causal_snapshot.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): add causal snapshot compare"
```

## Task 3: Document Snapshot Compare

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update README quickstart**

In the snapshot section of `packages/zigeffect/README.md`, add:

```md
zig build causal-snapshot -- compare baseline baseline
```

Then explain:

```md
`causal-snapshot compare` accepts snapshot names or manifest JSON paths. It
reads each manifest's referenced causal JSON artifact, prints snapshot-level
event/finding deltas, and embeds the existing `causal-compare` event diff.
```

- [ ] **Step 2: Update the agent guide**

In `packages/zigeffect/docs/agent-guide.md`, extend the snapshot guidance with:

```md
Compare named snapshots with
`zig build causal-snapshot -- compare <left> <right>`. Use names such as
`baseline` and `after` when manifests were written to the default artifact
directory, or pass explicit manifest JSON paths when reviewing uploaded CI
artifacts. Treat the report as a state-level summary; query the underlying
causal JSON paths for event-level evidence.
```

- [ ] **Step 3: Update observable-runtime docs**

In `packages/zigeffect/docs/agent-observable-runtime.md`, update the M5 section
with:

```md
`zig build causal-snapshot -- compare <left> <right>` compares two snapshot
manifests by name or path. It reports manifest identity, event/finding deltas,
manifest warnings, and then embeds `causal-compare` output for the referenced
causal JSON artifacts.
```

- [ ] **Step 4: Update causal scenarios docs**

In `packages/zigeffect/docs/causal-scenarios.md`, add the compare command to
the snapshot command block:

```sh
zig build causal-snapshot -- compare <left> <right>
```

Then explain that the command does not rerun the scenario and only reads the
existing manifests and artifacts.

- [ ] **Step 5: Update the master roadmap**

In
`docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`,
change M5 evidence to:

```md
snapshot manifest schema/tool exists; snapshot compare over named manifests
exists; compare and audit-chain tools already exist
```

Change M5 next action to:

```md
build replay feasibility reports for named snapshots
```

Change the immediate branch queue to:

```md
1. `codex/zigeffect-causal-replay-feasibility`
   - Explain which snapshot events are replayable and which are observational only.
```

- [ ] **Step 6: Run docs checks**

Run:

```sh
rg -n "causal-snapshot|snapshot compare|snapshot-compare|replay feasible|SQL durable" packages/zigeffect/README.md packages/zigeffect/docs docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git diff --check
```

Expected: docs mention snapshot compare and do not claim replay is feasible.

- [ ] **Step 7: Commit documentation**

```sh
git add packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/docs/causal-scenarios.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): document causal snapshot compare"
```

## Task 4: Verify And Merge

**Files:**
- All touched files.

- [ ] **Step 1: Run focused zigeffect gates**

Run:

```sh
cd packages/zigeffect
zig build causal-snapshot
zig build causal-test
zig build causal-snapshot -- capture baseline
zig build causal-snapshot -- compare baseline baseline
zig build test-raw --summary none
zig build test --summary none
zig build causal-test-matrix
zig build examples
```

Expected: all commands pass. The compare smoke prints a snapshot compare report
with an embedded causal compare report.

- [ ] **Step 2: Run repo integration gates**

Run:

```sh
bun run check
bun run zig:test
git diff --check HEAD
```

Expected: all pass.

- [ ] **Step 3: Inspect final branch state**

Run:

```sh
git status --short --branch
git log --oneline -5
```

Expected: only the unrelated untracked
`docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
remains outside this branch's commits.

- [ ] **Step 4: Merge to master**

Run:

```sh
git switch master
git merge --ff-only codex/zigeffect-causal-snapshot-compare
git branch -d codex/zigeffect-causal-snapshot-compare
cd packages/zigeffect && zig build causal-snapshot
cd packages/zigeffect && zig build test --summary none
bun run check
bun run zig:test
git diff --check HEAD
```

Expected: fast-forward merge succeeds, post-merge smoke passes, and `master`
is ready for `codex/zigeffect-causal-replay-feasibility`.

## Success Criteria

- `zig build causal-snapshot -- compare <left> <right>` accepts snapshot names
  and explicit manifest JSON paths.
- Snapshot compare reports cite both manifests, both artifacts, manifest event
  and finding deltas, warnings, next queries, and embedded event compare output.
- No SQL durable-history dependency or direct NenDB package dependency is
  introduced.
- The feature branch is committed, verified, fast-forward merged, and deleted.
