# zigeffect Causal Deterministic Replay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first deterministic replay execution path by rerunning registered causal scenarios and comparing the replay artifact with a named snapshot baseline.

**Architecture:** Extend `packages/zigeffect/tools/causal_snapshot.zig` with replay artifact paths, a pure deterministic replay report formatter, and a `replay-scenario` CLI subcommand. Reuse `causal_run.scenarioByName`, `causal_run.buildCommandArtifacts`, and `causal_compare.runCompare`; never attempt arbitrary event-log replay.

**Tech Stack:** Zig tool module under `packages/zigeffect`, existing causal snapshot/compare/run helpers, local `.zig-cache/causal-artifacts` files, Bun repo checks.

---

## Files

- Modify: `packages/zigeffect/tools/causal_snapshot.zig`
  - Add schema constants, replay path helpers, report formatter, CLI command, and unit tests.
- Modify: `packages/zigeffect/README.md`
  - Document `replay-scenario` and its boundary.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Add agent workflow for replaying a registered scenario.
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
  - Clarify M5 deterministic replay posture.
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
  - Add command examples and artifact names.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark deterministic replay branch as active/delivered and advance the next branch.

---

## Task 1: Specify Replay Artifact Paths And Report Formatting

**Files:**
- Modify: `packages/zigeffect/tools/causal_snapshot.zig`

- [ ] **Step 1: Add failing unit tests**

Append tests near the existing snapshot compare and replay-feasibility tests:

```zig
test "deterministic replay artifact paths include snapshot and scenario" {
    const paths = try deterministicReplayArtifactPaths(std.testing.allocator, "scoped-baseline", "causal-scoped-fiber");
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-replay-scoped-baseline-causal-scoped-fiber.txt",
        paths.report_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-replay-scoped-baseline-causal-scoped-fiber.json",
        paths.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-replay-scoped-baseline-causal-scoped-fiber.dot",
        paths.dot_path,
    );
}

test "deterministic replay report states registered rerun boundary" {
    const scenario = try causal_run.scenarioByName("causal-scoped-fiber");
    const paths = try deterministicReplayArtifactPaths(std.testing.allocator, "scoped-baseline", scenario.slug);
    defer paths.deinit(std.testing.allocator);

    const report = try formatDeterministicReplayText(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-scoped-baseline.json",
        baseline_manifest_json,
        compare_before_json,
        scenario,
        paths,
        .{ .exited = 0 },
        compare_before_json,
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.deterministic-replay.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "mode: registered_scenario_rerun") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "executed: true") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "arbitrary event replay: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "scenario: causal-scoped-fiber") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "command status: success") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "boundary:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event compare:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal compare report") != null);
}

test "causal snapshot usage lists replay scenario command" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "replay-scenario <snapshot> <scenario>") != null);
}
```

- [ ] **Step 2: Run tests and verify red**

Run:

```sh
zig build examples
```

Expected: FAIL because `deterministicReplayArtifactPaths`,
`formatDeterministicReplayText`, and the usage text do not exist yet.

- [ ] **Step 3: Add minimal implementation**

Add constants and helpers in `causal_snapshot.zig`:

```zig
pub const deterministic_replay_schema = "zigeffect.causal.deterministic-replay.v1";
pub const deterministic_replay_schema_version: u32 = 1;

fn deterministicReplayArtifactPaths(
    allocator: std.mem.Allocator,
    snapshot_name: []const u8,
    scenario_slug: []const u8,
) !causal_run.ArtifactPaths {
    try validateSnapshotName(snapshot_name);
    _ = try causal_run.scenarioByName(scenario_slug);
    return .{
        .report_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-replay-{s}-{s}.txt", .{ causal_run.artifact_dir, snapshot_name, scenario_slug }),
        .json_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-replay-{s}-{s}.json", .{ causal_run.artifact_dir, snapshot_name, scenario_slug }),
        .dot_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-replay-{s}-{s}.dot", .{ causal_run.artifact_dir, snapshot_name, scenario_slug }),
    };
}
```

Add a formatter that parses the manifest, compares `baseline_artifact_json` with
`replay_artifact_json`, and prints the schema, mode, boundary, scenario
metadata, paths, command status, verdict, compare report, and next queries.

- [ ] **Step 4: Verify green**

Run:

```sh
zig build examples
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```sh
git add packages/zigeffect/tools/causal_snapshot.zig
git commit -m "test(zigeffect): specify deterministic causal replay"
```

---

## Task 2: Execute Registered Scenario Replay From The CLI

**Files:**
- Modify: `packages/zigeffect/tools/causal_snapshot.zig`

- [ ] **Step 1: Add failing CLI-facing unit coverage**

Add a test that calls the path and report formatter through the same structs the
CLI will use:

```zig
test "deterministic replay report marks command expectation mismatch" {
    const scenario = try causal_run.scenarioByName("causal-scoped-fiber");
    const paths = try deterministicReplayArtifactPaths(std.testing.allocator, "scoped-baseline", scenario.slug);
    defer paths.deinit(std.testing.allocator);

    const report = try formatDeterministicReplayText(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-scoped-baseline.json",
        baseline_manifest_json,
        compare_before_json,
        scenario,
        paths,
        .{ .exited = 1 },
        compare_after_json,
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "command status: failure") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "verdict: command_failed") != null);
}
```

- [ ] **Step 2: Run tests and verify red**

Run:

```sh
zig build examples
```

Expected: FAIL until verdict classification handles command expectation mismatch.

- [ ] **Step 3: Implement CLI command**

Extend `usage()` with:

```text
zig build causal-snapshot -- replay-scenario <snapshot> <scenario>
```

Add a `replay-scenario` branch to `main`:

```zig
if (std.mem.eql(u8, args[1], "replay-scenario")) {
    if (args.len != 4) failUsage(error.InvalidDeterministicReplayArguments);
    const manifest_ref = try resolveSnapshotManifestReference(allocator, args[2]);
    defer manifest_ref.deinit(allocator);
    const scenario = causal_run.scenarioByName(args[3]) catch |err| failUsage(err);

    const manifest_json = try std.Io.Dir.cwd().readFileAlloc(init.io, manifest_ref.path, allocator, .limited(1024 * 1024));
    defer allocator.free(manifest_json);
    const baseline_artifact_path = try snapshotArtifactPathFromManifestJson(allocator, manifest_json);
    defer allocator.free(baseline_artifact_path);
    const baseline_artifact_json = try std.Io.Dir.cwd().readFileAlloc(init.io, baseline_artifact_path, allocator, .limited(1024 * 1024));
    defer allocator.free(baseline_artifact_json);

    var manifest = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, manifest_json, .{ .ignore_unknown_fields = true });
    defer manifest.deinit();
    const replay_paths = try deterministicReplayArtifactPaths(allocator, manifest.value.name, scenario.slug);
    defer replay_paths.deinit(allocator);

    const result = try runScenarioCommand(allocator, init.io, scenario);
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    const artifacts = try causal_run.buildCommandArtifacts(allocator, scenario, result);
    defer artifacts.deinit(allocator);
    try writeArtifact(init.io, replay_paths.report_path, artifacts.report);
    try writeArtifact(init.io, replay_paths.json_path, artifacts.json);
    try writeArtifact(init.io, replay_paths.dot_path, artifacts.dot);

    const report = try formatDeterministicReplayText(allocator, manifest_ref.path, manifest_json, baseline_artifact_json, scenario, replay_paths, result.term, artifacts.json);
    defer allocator.free(report);
    std.debug.print("{s}", .{report});
    return;
}
```

Add a small local `runScenarioCommand` wrapper around `std.process.run` with the
same stdout/stderr limits as `causal_run`.

- [ ] **Step 4: Verify green**

Run:

```sh
zig build examples
zig build causal-snapshot
```

Expected: PASS and usage includes `replay-scenario`.

- [ ] **Step 5: Commit**

Run:

```sh
git add packages/zigeffect/tools/causal_snapshot.zig
git commit -m "feat(zigeffect): add deterministic causal replay"
```

---

## Task 3: Document Replay Workflow And Update Roadmap

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update command docs**

Document:

```sh
zig build causal-snapshot -- replay-scenario <snapshot> <scenario>
```

State that it reruns a registered scenario and compares artifacts. State that it
does not replay arbitrary event logs or reconstruct runtime state.

- [ ] **Step 2: Update roadmap**

Set M5 status to include deterministic registered-scenario replay. Advance the
recommended next branch to M6 workbench planning unless a hardening follow-up is
chosen first.

- [ ] **Step 3: Verify docs references**

Run:

```sh
rg -n "replay-scenario|deterministic-replay|registered_scenario_rerun" packages/zigeffect docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
rg -n "Cockroach|RoachGraph|cockroach_history" packages/zigeffect docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Expected: the first command finds the new replay docs; the second finds no
active backend instructions for Cockroach or RoachGraph.

- [ ] **Step 4: Commit**

Run:

```sh
git add packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/docs/causal-scenarios.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): document deterministic causal replay"
```

---

## Task 4: Branch Verification And Merge

**Files:**
- No source edits unless verification reveals a bug.

- [ ] **Step 1: Run focused commands**

Run:

```sh
zig build examples
zig build causal-snapshot
zig build causal-test
zig build causal-run -- causal-scoped-fiber
zig build causal-snapshot -- capture scoped-baseline causal-scoped-fiber
zig build causal-snapshot -- replay-scenario scoped-baseline causal-scoped-fiber
```

Expected: all commands pass; replay output includes `mode:
registered_scenario_rerun` and `arbitrary event replay: false`.

- [ ] **Step 2: Run package verification**

Run:

```sh
zig build test-raw --summary none
zig build test --summary none
zig build causal-test-matrix
bun run check
bun run zig:test
git diff --check HEAD
```

Expected: all commands pass. The causal matrix may still report existing partial
coverage for config/cause until later roadmap milestones expand it.

- [ ] **Step 3: Merge**

Run:

```sh
git checkout master
git merge --ff-only codex/zigeffect-causal-deterministic-replay
git branch -d codex/zigeffect-causal-deterministic-replay
```

- [ ] **Step 4: Post-merge smoke checks**

Run:

```sh
zig build causal-snapshot
zig build test --summary none
git diff --check HEAD
bun run check
bun run zig:test
```

Expected: all commands pass on `master`.

## Self-Review

- Spec coverage: all design goals map to a task.
- Placeholder scan: no placeholders or unresolved TODOs remain.
- Type consistency: helper names and CLI command names are consistent across
  tests, implementation steps, docs, and verification.
