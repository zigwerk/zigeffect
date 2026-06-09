# zigeffect Causal Scenario Fork Proposals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add safe scenario fork proposal artifacts for named snapshots and registered scenarios without executing commands, mutating source, mutating runtime state, or replaying arbitrary event logs.

**Architecture:** Extend `packages/zigeffect/tools/causal_snapshot.zig` with a proposal schema, path helpers, pure JSON/text formatters, and a `fork-proposal` CLI subcommand. The command reads an existing snapshot manifest and registered scenario metadata, writes draft JSON/text artifacts, and prints next safe commands.

**Tech Stack:** Zig tool module under `packages/zigeffect`, existing snapshot manifest parser/reference resolution, existing `causal_run` registry metadata, local `.zig-cache/causal-artifacts` files, Bun repo checks.

---

## Files

- Modify: `packages/zigeffect/tools/causal_snapshot.zig`
  - Add schema constants, fork proposal paths, JSON/text formatters, CLI command, and unit tests.
- Modify: `packages/zigeffect/README.md`
  - Document `fork-proposal` and its non-executing boundary.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Add agent workflow for reviewing fork proposals before replay.
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
  - Clarify the M5 fork boundary.
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
  - Add command examples and artifact names.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark safe fork proposals as delivered and advance to M6 workbench.

---

## Task 1: Specify Fork Proposal Paths And Formatters

**Files:**
- Modify: `packages/zigeffect/tools/causal_snapshot.zig`

- [ ] **Step 1: Add failing unit tests**

Append tests near the deterministic replay tests:

```zig
test "scenario fork proposal paths include snapshot scenario and fork" {
    const paths = try scenarioForkProposalPaths(std.testing.allocator, "missing-service-baseline", "missing-service-compile-fail", "missing-service-fork");
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-fork-proposal-missing-service-baseline-missing-service-compile-fail-missing-service-fork.json",
        paths.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-fork-proposal-missing-service-baseline-missing-service-compile-fail-missing-service-fork.txt",
        paths.text_path,
    );
}

test "scenario fork proposal json is draft non executing evidence" {
    const scenario = try causal_run.scenarioByName("missing-service-compile-fail");
    const json = try formatScenarioForkProposalJson(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-missing-service-baseline.json",
        baseline_manifest_json,
        scenario,
        "missing-service-fork",
    );
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.scenario-fork-proposal.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"mode\":\"registered_scenario_fork_proposal\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"proposal_status\":\"draft\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"approved\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"executed\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"fork_name\":\"missing-service-fork\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"scenario\":{\"slug\":\"missing-service-compile-fail\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "replay-scenario missing-service-baseline missing-service-compile-fail") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "runtime memory forking") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "arbitrary causal event-log replay") != null);
}

test "scenario fork proposal text states review boundary" {
    const scenario = try causal_run.scenarioByName("missing-service-compile-fail");
    const text = try formatScenarioForkProposalText(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-missing-service-baseline.json",
        baseline_manifest_json,
        scenario,
        "missing-service-fork",
    );
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect causal scenario fork proposal") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "mode: registered_scenario_fork_proposal") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "approved: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "executed: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "blocked operations:") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "Fork proposal does not execute commands.") != null);
}

test "causal snapshot usage lists fork proposal command" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "fork-proposal <snapshot> <scenario> <fork>") != null);
}
```

- [ ] **Step 2: Run tests and verify red**

Run:

```sh
zig build examples
```

Expected: FAIL because `scenarioForkProposalPaths`,
`formatScenarioForkProposalJson`, `formatScenarioForkProposalText`, and the
usage line do not exist yet.

- [ ] **Step 3: Add minimal implementation**

Add:

```zig
pub const scenario_fork_proposal_schema = "zigeffect.causal.scenario-fork-proposal.v1";
pub const scenario_fork_proposal_schema_version: u32 = 1;

const ScenarioForkProposalPaths = struct {
    json_path: []const u8,
    text_path: []const u8,

    fn deinit(self: ScenarioForkProposalPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json_path);
        allocator.free(self.text_path);
    }
};
```

Implement `scenarioForkProposalPaths`, `formatScenarioForkProposalJson`, and
`formatScenarioForkProposalText`. Use existing `appendJsonString`,
`SnapshotManifestForCompare`, and scenario metadata from `causal_run.Scenario`.

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
git commit -m "test(zigeffect): specify causal scenario fork proposals"
```

---

## Task 2: Add Fork Proposal CLI

**Files:**
- Modify: `packages/zigeffect/tools/causal_snapshot.zig`

- [ ] **Step 1: Implement the subcommand**

Add a `fork-proposal` branch to `main`:

```zig
if (std.mem.eql(u8, args[1], "fork-proposal")) {
    if (args.len != 5) failUsage(error.InvalidScenarioForkProposalArguments);
    const manifest_ref = try resolveSnapshotManifestReference(allocator, args[2]);
    defer manifest_ref.deinit(allocator);
    const scenario = causal_run.scenarioByName(args[3]) catch |err| failUsage(err);
    const fork_name = args[4];
    try validateSnapshotName(fork_name);

    const manifest_json = try std.Io.Dir.cwd().readFileAlloc(init.io, manifest_ref.path, allocator, .limited(1024 * 1024));
    defer allocator.free(manifest_json);
    var manifest = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, manifest_json, .{ .ignore_unknown_fields = true });
    defer manifest.deinit();
    const paths = try scenarioForkProposalPaths(allocator, manifest.value.name, scenario.slug, fork_name);
    defer paths.deinit(allocator);

    const json = try formatScenarioForkProposalJson(allocator, manifest_ref.path, manifest_json, scenario, fork_name);
    defer allocator.free(json);
    const text = try formatScenarioForkProposalText(allocator, manifest_ref.path, manifest_json, scenario, fork_name);
    defer allocator.free(text);
    try writeArtifact(init.io, paths.json_path, json);
    try writeArtifact(init.io, paths.text_path, text);
    std.debug.print("zigeffect causal scenario fork proposal written\njson: {s}\ntext: {s}\nreplay: zig build causal-snapshot -- replay-scenario {s} {s}\n", .{ paths.json_path, paths.text_path, manifest.value.name, scenario.slug });
    return;
}
```

- [ ] **Step 2: Verify focused commands**

Run:

```sh
zig build examples
zig build causal-snapshot
zig build causal-run -- missing-service-compile-fail
zig build causal-snapshot -- capture missing-service-baseline missing-service-compile-fail
zig build causal-snapshot -- fork-proposal missing-service-baseline missing-service-compile-fail missing-service-fork
```

Expected: all pass, and the final command writes JSON/text fork proposal
artifacts.

- [ ] **Step 3: Commit**

Run:

```sh
git add packages/zigeffect/tools/causal_snapshot.zig
git commit -m "feat(zigeffect): add causal scenario fork proposals"
```

---

## Task 3: Document Fork Proposal Workflow

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update command docs**

Document:

```sh
zig build causal-snapshot -- fork-proposal <snapshot> <scenario> <fork>
```

State that it writes draft proposal artifacts and does not execute commands,
fork runtime memory, replay arbitrary event logs, mutate source, or update the
scenario registry.

- [ ] **Step 2: Update roadmap**

Set M5 to delivered for snapshot manifests, comparison, replay feasibility,
registered-scenario replay, and safe scenario fork proposals. Advance the
immediate branch queue to M6 read-only workbench.

- [ ] **Step 3: Verify docs references**

Run:

```sh
rg -n "fork-proposal|scenario-fork-proposal|registered_scenario_fork_proposal" packages/zigeffect docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
rg -n "Cockroach|RoachGraph|cockroach_history" packages/zigeffect docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Expected: first command finds the new docs and tool code; second command finds
no active zigeffect or master-roadmap Cockroach/RoachGraph backend instructions.

- [ ] **Step 4: Commit**

Run:

```sh
git add packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/docs/causal-scenarios.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): document causal scenario fork proposals"
```

---

## Task 4: Branch Verification And Merge

**Files:**
- No source edits unless verification reveals a bug.

- [ ] **Step 1: Run focused checks**

Run:

```sh
zig build examples
zig build causal-snapshot
zig build causal-run -- missing-service-compile-fail
zig build causal-snapshot -- capture missing-service-baseline missing-service-compile-fail
zig build causal-snapshot -- fork-proposal missing-service-baseline missing-service-compile-fail missing-service-fork
```

Expected: all pass and fork proposal JSON contains
`registered_scenario_fork_proposal` and `"executed":false`.

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

Expected: all commands pass. Existing matrix partial coverage for config/cause
may remain until later roadmap slices.

- [ ] **Step 3: Merge**

Run:

```sh
git checkout master
git merge --ff-only codex/zigeffect-causal-scenario-fork-proposals
git branch -d codex/zigeffect-causal-scenario-fork-proposals
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
- Type consistency: helper names, schema names, and CLI command names are
  consistent across tests, implementation, docs, and verification.
