# zigeffect Causal Scenario Learning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `zig build causal-scenario-proposal -- local [scenario]`, a deterministic read-only artifact that recommends when causal evidence should become a reviewed scenario or invariant.

**Architecture:** Create `packages/zigeffect/tools/causal_scenario_proposal.zig` as a focused artifact reader, evidence summarizer, and formatter. The tool reads the current local verdict, diagnosis, remediation plan, and audit-chain artifacts; derives `add-scenario`, `refine-scenario`, or `none`; writes JSON/text proposal reports; and updates build wiring, manifest, docs, and roadmaps. It never edits `causal_run.zig` or any source registry.

**Tech Stack:** Zig 0.16, existing `causal_run` scenario registry, existing causal dev-loop schemas, Zig std JSON parser, Bun repo verification commands.

---

## Files

- Create: `packages/zigeffect/tools/causal_scenario_proposal.zig`
  - Owns path helpers, option parsing, input validation, diagnosis evidence
    parsing, recommendation selection, invariant suggestion, JSON/text
    formatting, and CLI artifact IO.
- Modify: `packages/zigeffect/build.zig`
  - Adds the tool module, tests, executable, build step, and aggregate examples
    dependency.
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
  - Adds scenario-proposal artifact paths to the retention manifest and tests.
- Modify: `packages/zigeffect/README.md`
  - Adds the command to the local causal self-improvement workflow.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Adds guidance for reading and citing scenario proposals.
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
  - Adds default and scenario-specific proposal artifact paths.
- Modify: `packages/zigeffect/docs/roadmap.md`
  - Marks the first scenario-learning slice delivered.
- Modify:
  `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
  - Updates the remediation-control roadmap with the scenario-learning step.
- Modify:
  `docs/superpowers/specs/2026-06-07-zigeffect-self-improving-dev-harness-roadmap.md`
  - Updates Milestone 5 with delivered command details.

## Tasks

### Task 0: Documentation Checkpoint

**Files:**
- Create:
  `docs/superpowers/specs/2026-06-07-zigeffect-causal-scenario-learning-design.md`
- Create:
  `docs/superpowers/plans/2026-06-07-zigeffect-causal-scenario-learning.md`

- [ ] Write the design with command shape, inputs, outputs, schema, validation,
  recommendation values, and acceptance criteria.
- [ ] Write this implementation plan with files, scope, TDD checkpoints, and
  verification commands.
- [ ] Run:

```sh
git diff --check
printf '%s\n' \
  '\bTB''D\b' \
  '\bTO''DO\b' \
  'implement late''r' \
  'fill in detail''s' \
  'Similar to Tas''k' \
  'appropriate error handlin''g' > /tmp/zigeffect-plan-placeholder-patterns.txt
rg -n -f /tmp/zigeffect-plan-placeholder-patterns.txt docs/superpowers/specs/2026-06-07-zigeffect-causal-scenario-learning-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-scenario-learning.md
```

Expected: `git diff --check` prints nothing; `rg` exits nonzero with no
matches.

- [ ] Commit:

```sh
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-scenario-learning-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-scenario-learning.md
git commit -m "docs(zigeffect): plan causal scenario learning"
```

### Task 1: Paths, Options, And Recommendation Core

**Files:**
- Create: `packages/zigeffect/tools/causal_scenario_proposal.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] Write failing tests for default and scenario output paths:

```zig
test "scenario proposal default and scenario paths are deterministic" {
    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-scenario-proposal.json",
        defaultScenarioProposalJsonPath(),
    );
    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-scenario-proposal.txt",
        defaultScenarioProposalTextPath(),
    );

    const json = try scenarioScenarioProposalJsonPath(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(json);
    const text = try scenarioScenarioProposalTextPath(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(text);

    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json",
        json,
    );
    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.txt",
        text,
    );
}
```

- [ ] Write failing tests for `parseOptions`:

```zig
test "scenario proposal parses local default and scenario options" {
    const default_options = try parseOptions(&.{ "zigeffect-causal-scenario-proposal", "local" });
    try std.testing.expectEqual(@as(?[]const u8, null), default_options.scenario_slug);

    const scenario_options = try parseOptions(&.{ "zigeffect-causal-scenario-proposal", "local", "causal-scoped-fiber" });
    try std.testing.expectEqualStrings("causal-scoped-fiber", scenario_options.scenario_slug.?);

    try std.testing.expectError(error.MissingMode, parseOptions(&.{"zigeffect-causal-scenario-proposal"}));
    try std.testing.expectError(error.UnknownMode, parseOptions(&.{ "zigeffect-causal-scenario-proposal", "remote" }));
}
```

- [ ] Write failing tests for recommendation selection:

```zig
test "scenario proposal recommendation uses verdict and audit-chain posture" {
    try std.testing.expectEqual(Recommendation.none, chooseRecommendation(.{
        .scenario_slug = "causal-scoped-fiber",
        .verdict_status = "clear",
        .actions = 0,
        .new_actions = 0,
        .persisting_actions = 0,
        .audit_chain_assessment = "inconclusive",
        .persisting_event_ids = &.{},
        .appeared_event_ids = &.{},
    }));
    try std.testing.expectEqual(Recommendation.add_scenario, chooseRecommendation(.{
        .scenario_slug = null,
        .verdict_status = "attention",
        .actions = 2,
        .new_actions = 0,
        .persisting_actions = 2,
        .audit_chain_assessment = "unchanged",
        .persisting_event_ids = &.{ 3, 4 },
        .appeared_event_ids = &.{},
    }));
    try std.testing.expectEqual(Recommendation.refine_scenario, chooseRecommendation(.{
        .scenario_slug = "causal-scoped-fiber",
        .verdict_status = "attention",
        .actions = 1,
        .new_actions = 1,
        .persisting_actions = 0,
        .audit_chain_assessment = "regressed",
        .persisting_event_ids = &.{},
        .appeared_event_ids = &.{9},
    }));
}
```

- [ ] Wire the test module into `build.zig`.
- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Confirm the new tests fail because the helpers are not implemented yet.
- [ ] Implement the minimal path helpers, option parser, enum, and
  `chooseRecommendation`.
- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Commit:

```sh
git add packages/zigeffect/tools/causal_scenario_proposal.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): add causal scenario proposal classifier"
```

### Task 2: Evidence Parsing And Report Formatting

**Files:**
- Modify: `packages/zigeffect/tools/causal_scenario_proposal.zig`

- [ ] Add sample verdict, diagnosis, remediation-plan, and audit-chain strings
  inside the test file.
- [ ] Write failing tests for `formatScenarioProposalReports` that assert:
  - JSON contains `"schema": "zigeffect.causal.scenario-proposal.v1"`;
  - persisting dogfood evidence produces `"recommendation": "add-scenario"`;
  - clear scenario evidence produces `"recommendation": "none"`;
  - event ids, subsystem, source paths, proposed scenario, proposed invariants,
    review checklist, and guardrails are present.
- [ ] Implement structs for verdict and audit-chain parsing:

```zig
const Verdict = struct {
    schema: []const u8,
    schema_version: u32,
    status: []const u8,
    actions: usize,
    new_actions: usize,
    persisting_actions: usize,
    observed_actions: usize,
};

const AuditChain = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    assessment: []const u8,
    event_ids: []const u64,
    persisting_event_ids: []const u64,
    appeared_event_ids: []const u64,
    missing_event_ids: []const u64,
};
```

- [ ] Implement diagnosis evidence parsing for `event`, `subsystem`,
  `kind`, `fix category`, and `diagnosis` lines.
- [ ] Implement invariant mapping from dominant subsystem/kind to known
  invariant ids.
- [ ] Implement JSON/text formatters.
- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Commit:

```sh
git add packages/zigeffect/tools/causal_scenario_proposal.zig
git commit -m "feat(zigeffect): format causal scenario proposals"
```

### Task 3: CLI Artifact IO And Integration

**Files:**
- Modify: `packages/zigeffect/tools/causal_scenario_proposal.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] Add executable build step `causal-scenario-proposal`.
- [ ] Implement required artifact readers and writers.
- [ ] Run default integration:

```sh
cd packages/zigeffect
zig build causal-dev-session -- start
zig build causal-dev-session -- assess
zig build causal-remediation-decision -- local approve --reason "Scenario proposal integration check"
zig build causal-patch-proposal -- local approved --summary "Scenario proposal integration proposal" --file packages/zigeffect/tools/causal_scenario_proposal.zig --change "Recommend learned scenarios from causal evidence"
zig build causal-audit-chain -- local
zig build causal-scenario-proposal -- local
```

Expected: default text report includes `recommendation: add-scenario` or
`recommendation: refine-scenario`, source paths, event evidence, and guardrails.

- [ ] Run scenario integration:

```sh
cd packages/zigeffect
zig build causal-dev-session -- start causal-scoped-fiber
zig build causal-dev-session -- assess causal-scoped-fiber
zig build causal-remediation-decision -- local approve causal-scoped-fiber --reason "Scenario proposal clear scenario check"
zig build causal-patch-proposal -- local approved causal-scoped-fiber --summary "Scenario proposal clear scenario" --file packages/zigeffect/examples/causal_scoped_fiber.zig --change "Do not invent scenarios for clear evidence"
zig build causal-audit-chain -- local causal-scoped-fiber
zig build causal-scenario-proposal -- local causal-scoped-fiber
```

Expected: scenario text report includes `recommendation: none`.

- [ ] Commit:

```sh
git add packages/zigeffect/tools/causal_scenario_proposal.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): write causal scenario proposal artifacts"
```

### Task 4: Manifest, Docs, Roadmaps, And Verification

**Files:**
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify:
  `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
- Modify:
  `docs/superpowers/specs/2026-06-07-zigeffect-self-improving-dev-harness-roadmap.md`

- [ ] Add scenario-proposal JSON/text paths to the causal artifact manifest and
  manifest tests.
- [ ] Document `zig build causal-scenario-proposal -- local [scenario]`.
- [ ] Mark Milestone 5's first scenario-learning slice delivered.
- [ ] Verify:

```sh
git diff --check
cd packages/zigeffect && zig build causal-artifacts
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test --summary none
bun run check
bun run zig:test
```

- [ ] Commit:

```sh
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md docs/superpowers/specs/2026-06-07-zigeffect-self-improving-dev-harness-roadmap.md packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/causal-scenarios.md packages/zigeffect/docs/roadmap.md packages/zigeffect/tools/causal_artifacts.zig
git commit -m "docs(zigeffect): document causal scenario proposals"
```

## Self-Review

- Spec coverage: tasks cover command shape, schema, validation, recommendation
  selection, artifact paths, report formatting, CLI IO, manifest, docs, and
  final verification.
- Scope check: registry mutation and patch generation are out of scope for the
  first slice.
- TDD check: Tasks 1 and 2 require red tests before helper and report
  implementation; Task 3 performs integration after tested behavior exists.
- Type consistency: the command name is `causal-scenario-proposal`; the schema
  is `zigeffect.causal.scenario-proposal.v1`; output artifact suffix is
  `scenario-proposal`.
