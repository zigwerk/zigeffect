# zigeffect Causal Replay Feasibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only replay feasibility report for named zigeffect causal snapshot manifests.

**Architecture:** Extend `tools/causal_snapshot.zig` with replay-feasibility schema constants, event classification helpers, a deterministic text formatter, and a `replay-feasibility` CLI subcommand. The command reads an existing snapshot manifest and causal JSON artifact, explains why replay is currently false, and never executes replay or mutates state.

**Tech Stack:** Zig tool module under `packages/zigeffect`, existing snapshot manifest parser/reference resolution, existing causal artifact compatibility helpers, `std.json`, Bun repo checks.

---

## Files

- Modify: `packages/zigeffect/tools/causal_snapshot.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Task 1: Specify Replay Feasibility Behavior

**Files:**
- Modify: `packages/zigeffect/tools/causal_snapshot.zig`

- [ ] **Step 1: Add replay feasibility schema constants**

Add these after the existing snapshot compare constants:

```zig
pub const replay_feasibility_schema = "zigeffect.causal.replay-feasibility.v1";
pub const replay_feasibility_schema_version: u32 = 1;
const replay_feasibility_event_sample_limit: usize = 20;
```

- [ ] **Step 2: Add a replay fixture**

Add this fixture near the existing compare fixtures:

```zig
const replay_manifest_json =
    \\{
    \\  "schema": "zigeffect.causal.snapshot-manifest.v1",
    \\  "schema_version": 1,
    \\  "name": "baseline",
    \\  "target": "dogfood",
    \\  "phase": "captured",
    \\  "artifact": {
    \\    "path": ".zig-cache/causal-artifacts/replay.json",
    \\    "schema": "zigeffect.causal.v1",
    \\    "schema_version": 1,
    \\    "event_taxonomy_version": 1,
    \\    "events": 7,
    \\    "first_event_id": 1,
    \\    "last_event_id": 7,
    \\    "findings": 4
    \\  },
    \\  "warnings": []
    \\}
;

const replay_artifact_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"scenario","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"Config","status":"missing","redacted_detail":"missing provider"},
    \\    {"id":3,"kind":"resource_acquired","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":10,"trace_id":null,"span_id":null,"label":"db","type_name":"Resource","status":"acquired","redacted_detail":"<redacted>"},
    \\    {"id":4,"kind":"fiber_forked","run_id":1,"parent_id":1,"fiber_id":20,"scope_id":10,"trace_id":null,"span_id":null,"label":"worker","type_name":"Fiber","status":"pending","redacted_detail":""},
    \\    {"id":5,"kind":"schedule_decision","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"retry","type_name":"Schedule.exponential","status":"exhausted","redacted_detail":"budget exhausted"},
    \\    {"id":6,"kind":"log_recorded","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"logger","type_name":"Logger","status":"info","redacted_detail":"hello"},
    \\    {"id":7,"kind":"effect_suspended","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future","type_name":"Command","status":"pending","redacted_detail":"<truncated>"}
    \\  ]
    \\}
;
```

- [ ] **Step 3: Add failing replay feasibility tests**

Add these tests after the snapshot compare tests:

```zig
test "replay feasibility report refuses replay and counts event posture" {
    const report = try formatReplayFeasibilityText(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json",
        replay_manifest_json,
        replay_artifact_json,
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal replay feasibility report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.replay-feasibility.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "snapshot: baseline") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "artifact: .zig-cache/causal-artifacts/replay.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "feasible: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "reason: snapshot manifest references observed causal artifact only") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "events: 7") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "structural events: 5") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "finding evidence events: 4") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "sampleable events: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "unknown events: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "redacted detail events: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "truncated detail events: 1") != null);
}

test "replay feasibility report names blockers and event posture sample" {
    const report = try formatReplayFeasibilityText(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json",
        replay_manifest_json,
        replay_artifact_json,
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "blocking reasons:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "snapshot manifest references observed artifacts, not executable programs") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "service values/providers are not serialized") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "resource constructors/finalizers are not serialized") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "scheduler state and fiber closures are not serialized") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "schedule timing and randomness decisions are observations, not replay inputs") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "logs, metrics, and spans may be sampled") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "unknown event taxonomy prevents complete replay classification") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "redacted or truncated detail prevents faithful replay evidence") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event id=1 kind=run_started posture=structural_observation") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event id=2 kind=service_required posture=finding_evidence_observation") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event id=6 kind=log_recorded posture=sampleable_observation") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event id=7 kind=effect_suspended posture=unknown_taxonomy") != null);
}

test "replay feasibility event posture sample is bounded" {
    var artifact = std.ArrayList(u8).empty;
    defer artifact.deinit(std.testing.allocator);
    try artifact.appendSlice(std.testing.allocator, "{\"events\":[");
    for (1..22) |id| {
        if (id > 1) try artifact.append(std.testing.allocator, ',');
        try artifact.print(std.testing.allocator, "{{\"id\":{d},\"kind\":\"run_started\",\"run_id\":1,\"parent_id\":null,\"fiber_id\":null,\"scope_id\":null,\"trace_id\":null,\"span_id\":null,\"label\":\"event\",\"type_name\":\"Command\",\"status\":\"started\",\"redacted_detail\":\"\"}}", .{id});
    }
    try artifact.appendSlice(std.testing.allocator, "]}");

    const report = try formatReplayFeasibilityText(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json",
        replay_manifest_json,
        artifact.items,
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "event posture sample limit: 20") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event id=20 kind=run_started") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event id=21 kind=run_started") == null);
}
```

- [ ] **Step 4: Update usage text test coverage**

If no usage test exists, rely on the executable smoke in Task 2. Otherwise add
an assertion that usage includes `replay-feasibility`.

- [ ] **Step 5: Run the red test**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: FAIL because `formatReplayFeasibilityText` is referenced but not
implemented.

- [ ] **Step 6: Commit the red specification**

```sh
git add packages/zigeffect/tools/causal_snapshot.zig
git commit -m "test(zigeffect): specify causal replay feasibility"
```

## Task 2: Implement Replay Feasibility

**Files:**
- Modify: `packages/zigeffect/tools/causal_snapshot.zig`

- [ ] **Step 1: Add replay stats type**

Add near the snapshot manifest parse structs:

```zig
const ReplayFeasibilityStats = struct {
    structural_events: usize = 0,
    finding_evidence_events: usize = 0,
    sampleable_events: usize = 0,
    unknown_events: usize = 0,
    redacted_detail_events: usize = 0,
    truncated_detail_events: usize = 0,
    has_service_events: bool = false,
    has_resource_events: bool = false,
    has_fiber_events: bool = false,
    has_schedule_events: bool = false,
};
```

- [ ] **Step 2: Add event taxonomy string helpers**

Add helpers below `formatSnapshotManifestText`:

```zig
fn isStructuralEventKind(kind: []const u8) bool {
    return std.mem.eql(u8, kind, "run_started") or
        std.mem.eql(u8, kind, "run_completed") or
        std.mem.eql(u8, kind, "effect_started") or
        std.mem.eql(u8, kind, "effect_completed") or
        std.mem.eql(u8, kind, "layer_started") or
        std.mem.eql(u8, kind, "layer_completed") or
        std.mem.eql(u8, kind, "service_required") or
        std.mem.eql(u8, kind, "service_provided") or
        std.mem.eql(u8, kind, "service_replaced") or
        std.mem.eql(u8, kind, "scope_opened") or
        std.mem.eql(u8, kind, "scope_closed") or
        std.mem.eql(u8, kind, "resource_acquired") or
        std.mem.eql(u8, kind, "resource_finalized") or
        std.mem.eql(u8, kind, "fiber_forked") or
        std.mem.eql(u8, kind, "fiber_started") or
        std.mem.eql(u8, kind, "fiber_joined") or
        std.mem.eql(u8, kind, "fiber_interrupted") or
        std.mem.eql(u8, kind, "schedule_decision") or
        std.mem.eql(u8, kind, "exit_recorded") or
        std.mem.eql(u8, kind, "assertion_recorded");
}

fn isFindingEvidenceEventKind(kind: []const u8) bool {
    return std.mem.eql(u8, kind, "service_required") or
        std.mem.eql(u8, kind, "scope_closed") or
        std.mem.eql(u8, kind, "resource_acquired") or
        std.mem.eql(u8, kind, "resource_finalized") or
        std.mem.eql(u8, kind, "fiber_forked") or
        std.mem.eql(u8, kind, "fiber_started") or
        std.mem.eql(u8, kind, "fiber_joined") or
        std.mem.eql(u8, kind, "fiber_interrupted") or
        std.mem.eql(u8, kind, "schedule_decision") or
        std.mem.eql(u8, kind, "assertion_recorded");
}

fn isSampleableEventKind(kind: []const u8) bool {
    return std.mem.eql(u8, kind, "log_recorded") or
        std.mem.eql(u8, kind, "metric_recorded") or
        std.mem.eql(u8, kind, "span_recorded");
}

fn isServiceEventKind(kind: []const u8) bool {
    return std.mem.startsWith(u8, kind, "service_");
}

fn isResourceEventKind(kind: []const u8) bool {
    return std.mem.startsWith(u8, kind, "resource_");
}

fn isFiberEventKind(kind: []const u8) bool {
    return std.mem.startsWith(u8, kind, "fiber_");
}

fn isScheduleEventKind(kind: []const u8) bool {
    return std.mem.eql(u8, kind, "schedule_decision");
}
```

- [ ] **Step 3: Add replay posture helpers**

Add:

```zig
fn replayEventPosture(kind: []const u8) []const u8 {
    if (!causal_artifact.isKnownCausalEventKind(kind)) return "unknown_taxonomy";
    if (isSampleableEventKind(kind)) return "sampleable_observation";
    if (isFindingEvidenceEventKind(kind)) return "finding_evidence_observation";
    return "structural_observation";
}

fn containsReplayMarker(value: []const u8, marker: []const u8) bool {
    return std.mem.indexOf(u8, value, marker) != null;
}
```

- [ ] **Step 4: Add stats computation**

Add:

```zig
fn replayFeasibilityStats(events: []const Event) ReplayFeasibilityStats {
    var stats = ReplayFeasibilityStats{};
    for (events) |event| {
        if (isStructuralEventKind(event.kind)) stats.structural_events += 1;
        if (isFindingEvidenceEventKind(event.kind)) stats.finding_evidence_events += 1;
        if (isSampleableEventKind(event.kind)) stats.sampleable_events += 1;
        if (!causal_artifact.isKnownCausalEventKind(event.kind)) stats.unknown_events += 1;
        if (containsReplayMarker(event.redacted_detail, "<redacted>")) stats.redacted_detail_events += 1;
        if (containsReplayMarker(event.redacted_detail, "<truncated>")) stats.truncated_detail_events += 1;
        if (isServiceEventKind(event.kind)) stats.has_service_events = true;
        if (isResourceEventKind(event.kind)) stats.has_resource_events = true;
        if (isFiberEventKind(event.kind)) stats.has_fiber_events = true;
        if (isScheduleEventKind(event.kind)) stats.has_schedule_events = true;
    }
    return stats;
}
```

- [ ] **Step 5: Add warning, blocker, posture, and next-query helpers**

Add:

```zig
fn appendReplayArtifactWarnings(output: *std.ArrayList(u8), allocator: std.mem.Allocator, artifact: Artifact) !void {
    var warnings = std.ArrayList(u8).empty;
    defer warnings.deinit(allocator);
    try causal_artifact.appendArtifactCompatibilityWarnings(&warnings, allocator, "artifact", artifactMetadata(artifact));
    try causal_artifact.appendUnknownEventKindWarnings(&warnings, allocator, "artifact", artifact.events);
    try output.appendSlice(allocator, "artifact warnings:\n");
    if (warnings.items.len == 0) {
        try output.appendSlice(allocator, "- none\n");
        return;
    }
    var iterator = std.mem.splitScalar(u8, warnings.items, '\n');
    while (iterator.next()) |line| {
        if (line.len == 0) continue;
        try output.print(allocator, "- {s}\n", .{line});
    }
}

fn appendReplayBlockingReasons(output: *std.ArrayList(u8), allocator: std.mem.Allocator, stats: ReplayFeasibilityStats) !void {
    try output.appendSlice(allocator, "blocking reasons:\n");
    try output.appendSlice(allocator, "- snapshot manifest references observed artifacts, not executable programs\n");
    try output.appendSlice(allocator, "- replay engine is not implemented\n");
    try output.appendSlice(allocator, "- event records do not serialize service implementations, closures, resource constructors, scheduler state, clock transcripts, or external effects\n");
    if (stats.has_service_events) try output.appendSlice(allocator, "- service values/providers are not serialized\n");
    if (stats.has_resource_events) try output.appendSlice(allocator, "- resource constructors/finalizers are not serialized\n");
    if (stats.has_fiber_events) try output.appendSlice(allocator, "- scheduler state and fiber closures are not serialized\n");
    if (stats.has_schedule_events) try output.appendSlice(allocator, "- schedule timing and randomness decisions are observations, not replay inputs\n");
    if (stats.sampleable_events > 0) try output.appendSlice(allocator, "- logs, metrics, and spans may be sampled\n");
    if (stats.unknown_events > 0) try output.appendSlice(allocator, "- unknown event taxonomy prevents complete replay classification\n");
    if (stats.redacted_detail_events > 0 or stats.truncated_detail_events > 0) try output.appendSlice(allocator, "- redacted or truncated detail prevents faithful replay evidence\n");
}

fn appendReplayEventPostureSample(output: *std.ArrayList(u8), allocator: std.mem.Allocator, events: []const Event) !void {
    try output.print(allocator, "event posture sample limit: {d}\n", .{replay_feasibility_event_sample_limit});
    try output.appendSlice(allocator, "event posture sample:\n");
    const limit = @min(events.len, replay_feasibility_event_sample_limit);
    if (limit == 0) {
        try output.appendSlice(allocator, "- none\n");
        return;
    }
    for (events[0..limit]) |event| {
        try output.print(allocator, "- event id={d} kind={s} posture={s}", .{ event.id, event.kind, replayEventPosture(event.kind) });
        if (event.status.len > 0) try output.print(allocator, " status={s}", .{event.status});
        try output.append(allocator, '\n');
    }
}

fn appendReplayNextQueries(output: *std.ArrayList(u8), allocator: std.mem.Allocator, manifest_path: []const u8, artifact_path: []const u8, events: []const Event) !void {
    try output.appendSlice(allocator, "next queries:\n");
    try output.print(allocator, "- zig build causal-query -- --file {s} snapshot\n", .{artifact_path});
    if (firstEventId(events)) |event_id| {
        try output.print(allocator, "- zig build causal-query -- --file {s} lineage {d}\n", .{ artifact_path, event_id });
    }
    try output.print(allocator, "- zig build causal-snapshot -- compare {s} {s}\n", .{ manifest_path, manifest_path });
}
```

- [ ] **Step 6: Implement formatter**

Add:

```zig
pub fn formatReplayFeasibilityText(
    allocator: std.mem.Allocator,
    manifest_path: []const u8,
    manifest_json: []const u8,
    artifact_json: []const u8,
) ![]const u8 {
    var manifest_parsed = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, manifest_json, .{ .ignore_unknown_fields = true });
    defer manifest_parsed.deinit();
    var artifact_parsed = try std.json.parseFromSlice(Artifact, allocator, artifact_json, .{ .ignore_unknown_fields = true });
    defer artifact_parsed.deinit();

    const manifest = manifest_parsed.value;
    const artifact = artifact_parsed.value;
    const stats = replayFeasibilityStats(artifact.events);

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal replay feasibility report\n");
    try output.print(allocator, "schema: {s}\n", .{replay_feasibility_schema});
    try output.print(allocator, "schema version: {d}\n", .{replay_feasibility_schema_version});
    try output.print(allocator, "snapshot: {s}\n", .{manifest.name});
    try output.print(allocator, "manifest: {s}\n", .{manifest_path});
    try output.print(allocator, "target: {s}\n", .{manifest.target});
    try output.print(allocator, "phase: {s}\n", .{manifest.phase});
    try output.print(allocator, "artifact: {s}\n", .{manifest.artifact.path});
    try output.appendSlice(allocator, "feasible: false\n");
    try output.print(allocator, "reason: {s}\n", .{replay_reason});
    try output.print(allocator, "events: {d}\n", .{artifact.events.len});
    try output.print(allocator, "structural events: {d}\n", .{stats.structural_events});
    try output.print(allocator, "finding evidence events: {d}\n", .{stats.finding_evidence_events});
    try output.print(allocator, "sampleable events: {d}\n", .{stats.sampleable_events});
    try output.print(allocator, "unknown events: {d}\n", .{stats.unknown_events});
    try output.print(allocator, "redacted detail events: {d}\n", .{stats.redacted_detail_events});
    try output.print(allocator, "truncated detail events: {d}\n", .{stats.truncated_detail_events});
    try appendReplayArtifactWarnings(&output, allocator, artifact);
    try appendReplayBlockingReasons(&output, allocator, stats);
    try appendReplayEventPostureSample(&output, allocator, artifact.events);
    try appendReplayNextQueries(&output, allocator, manifest_path, manifest.artifact.path, artifact.events);

    return output.toOwnedSlice(allocator);
}
```

- [ ] **Step 7: Add CLI command**

Update `usage()`:

```zig
fn usage() []const u8 {
    return "usage: zig build causal-snapshot -- manifest <name> <artifact.json> [--format json|text] [--target <target>] [--phase <phase>] [--baseline <path>] [--compare-report <path>] [--query-report <path>] [--advice-report <path>]\n       zig build causal-snapshot -- capture <name> [scenario]\n       zig build causal-snapshot -- compare <left> <right>\n       zig build causal-snapshot -- replay-feasibility <snapshot>\n";
}
```

Add before the final unknown-command branch:

```zig
    if (std.mem.eql(u8, args[1], "replay-feasibility")) {
        if (args.len != 3) failUsage(error.InvalidReplayFeasibilityArguments);
        const manifest_ref = try resolveSnapshotManifestReference(allocator, args[2]);
        defer manifest_ref.deinit(allocator);

        const manifest_json = try std.Io.Dir.cwd().readFileAlloc(init.io, manifest_ref.path, allocator, .limited(1024 * 1024));
        defer allocator.free(manifest_json);
        const artifact_path = try snapshotArtifactPathFromManifestJson(allocator, manifest_json);
        defer allocator.free(artifact_path);
        const artifact_json = try std.Io.Dir.cwd().readFileAlloc(init.io, artifact_path, allocator, .limited(1024 * 1024));
        defer allocator.free(artifact_json);

        const report = try formatReplayFeasibilityText(allocator, manifest_ref.path, manifest_json, artifact_json);
        defer allocator.free(report);
        std.debug.print("{s}", .{report});
        return;
    }
```

- [ ] **Step 8: Run green focused checks**

Run:

```sh
cd packages/zigeffect
zig build examples
zig build causal-snapshot
zig build causal-test
zig build causal-snapshot -- capture baseline
zig build causal-snapshot -- replay-feasibility baseline
zig build causal-snapshot -- replay-feasibility .zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json
```

Expected: all commands pass. The feasibility report includes `feasible: false`.

- [ ] **Step 9: Commit implementation**

```sh
git add packages/zigeffect/tools/causal_snapshot.zig
git commit -m "feat(zigeffect): add causal replay feasibility report"
```

## Task 3: Document Replay Feasibility

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update README snapshot section**

Add:

```md
zig build causal-snapshot -- replay-feasibility baseline
```

Then explain:

```md
`causal-snapshot replay-feasibility` reads a snapshot manifest and its causal
JSON artifact, keeps `feasible: false`, and lists the blockers that must be
resolved before deterministic replay can exist.
```

- [ ] **Step 2: Update agent guide**

Add:

```md
Use `zig build causal-snapshot -- replay-feasibility <snapshot>` when an agent
needs to know whether a named state can be replayed. Today the answer must
remain `feasible: false`; the report is useful because it explains which event
categories are observations, which details are redacted/truncated, and what
future replay work would need.
```

- [ ] **Step 3: Update observable runtime docs**

Add:

```md
`zig build causal-snapshot -- replay-feasibility <snapshot>` is a read-only
M5 report. It does not replay. It classifies event posture, counts blockers,
and prints safe next query commands over the artifact.
```

- [ ] **Step 4: Update causal scenarios docs**

Add the command to the snapshot command block:

```sh
zig build causal-snapshot -- replay-feasibility <snapshot>
```

Say it reads existing artifacts only and does not rerun scenarios.

- [ ] **Step 5: Update the master roadmap**

In
`docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`,
change M5 evidence to:

```md
snapshot manifest schema/tool, named snapshot compare, and replay-feasibility
reports exist; compare and audit-chain tools already exist
```

Change M5 next action to:

```md
build deterministic replay for supported pure/simulated scenarios
```

Change the immediate branch queue to:

```md
1. `codex/zigeffect-causal-deterministic-replay`
   - Add the first replay execution path for explicitly supported deterministic scenarios.
```

- [ ] **Step 6: Run docs checks**

Run:

```sh
rg -n "replay-feasibility|replay feasible|feasible: false|deterministic replay" packages/zigeffect/README.md packages/zigeffect/docs docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git diff --check
```

Expected: docs mention replay feasibility but do not claim replay execution.
The active zigeffect causal-runtime surface stays local-artifact and
NenDB-adapter focused.

- [ ] **Step 7: Commit documentation**

```sh
git add packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/docs/causal-scenarios.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): document causal replay feasibility"
```

## Task 4: Verify And Merge

**Files:**
- All touched files.

- [ ] **Step 1: Run focused package gates**

Run:

```sh
cd packages/zigeffect
zig build causal-snapshot
zig build causal-test
zig build causal-snapshot -- capture baseline
zig build causal-snapshot -- replay-feasibility baseline
zig build test-raw --summary none
zig build test --summary none
zig build causal-test-matrix
zig build examples
```

Expected: all pass. The replay feasibility smoke prints `feasible: false`.

- [ ] **Step 2: Run repo gates**

Run:

```sh
bun run check
bun run zig:test
git diff --check HEAD
```

Expected: all pass.

- [ ] **Step 3: Inspect branch state**

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
git merge --ff-only codex/zigeffect-causal-replay-feasibility
git branch -d codex/zigeffect-causal-replay-feasibility
cd packages/zigeffect && zig build causal-snapshot
cd packages/zigeffect && zig build test --summary none
bun run check
bun run zig:test
git diff --check HEAD
```

Expected: fast-forward merge succeeds, post-merge smoke passes, and `master`
is ready for `codex/zigeffect-causal-deterministic-replay`.

## Success Criteria

- `zig build causal-snapshot -- replay-feasibility <snapshot>` accepts snapshot
  names and explicit manifest paths.
- The report keeps `feasible: false`.
- The report explains deterministic blockers and event posture without
  executing replay.
- No database, durable service, or direct NenDB package dependency is added.
- The feature branch is committed, verified, fast-forward merged, and deleted.
