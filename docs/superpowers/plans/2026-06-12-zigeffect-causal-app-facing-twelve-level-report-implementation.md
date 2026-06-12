# Zigeffect App-Facing Twelve-Level Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build the alias-named twelve-level app-facing report that consumes ready/advisory eleven-level evaluator evidence and hands local report artifacts to the twelve-level application-boundary branch.

**Architecture:** Promote the proven eleven-level report implementation into a twelve-level alias file while updating the emitted schema, branch handoff, source evaluator contract, status field, docs, and direct eleven-level lineage carryover. The tool remains local, read-only, and advisory: it never grants CI, GitHub, app runtime, durable storage, NenDB, deployment, production-health, registry, auto-apply, or mutation authority.

**Tech Stack:** Zig build tools and `zig test`, generated zigeffect schema governance and production-hardening backlog docs, Bun root checks.

---

### Task 1: Report Tool RED Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_twelve_level_report.zig`

- [x] **Step 1: Write the failing test**

```zig
const std = @import("std");

test "twelve-level report exposes the expected schema and handoff branch" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
        schema,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-twelve-level-application-boundary",
        next_branch_if_ready,
    );
}
```

- [x] **Step 2: Run RED verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_twelve_level_report.zig
```

Expected: FAIL because `schema` and `next_branch_if_ready` are not defined.

### Task 2: Promote The Report Implementation

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_twelve_level_report.zig`

- [x] **Step 1: Copy the eleven-level report**

Run:

```bash
cp packages/zigeffect/tools/causal_app_facing_eleven_level_report.zig packages/zigeffect/tools/causal_app_facing_twelve_level_report.zig
```

- [x] **Step 2: Mechanically promote naming**

Run:

```bash
perl -0pi -e 's/eleven-level/twelve-level/g; s/eleven level/twelve level/g; s/eleven_level/twelve_level/g; s/ElevenLevel/TwelveLevel/g' packages/zigeffect/tools/causal_app_facing_twelve_level_report.zig
```

- [x] **Step 3: Retarget constants**

Ensure the top constants are:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1";
pub const source_branch = "codex/zigeffect-causal-app-facing-twelve-level-report";
pub const recommendation = "start-app-facing-twelve-level-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-twelve-level-application-boundary";
const source_evaluator_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1";
const generated_by = "causal-app-facing-twelve-level-report";
const evaluator_suffix = "-ci-eleven-level-evaluator.json";
const output_suffix = "-ci-twelve-level-report";
const compact_output_prefix_name = "app-facing-ci-twelve-level-report";
```

- [x] **Step 4: Preserve direct eleven-level lineage**

Add `source_eleven_level_policy`, `source_eleven_level_application_boundary`,
`source_eleven_level_report`, status/schema fields, after digest/presence, and
application changes to the source struct and emitted JSON/text output. Keep
existing ten, nine, and inherited lower-level lineage fields.

- [x] **Step 5: Run GREEN verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_twelve_level_report.zig
```

Expected: PASS.

### Task 3: Build, Docs, And Governance

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-twelve-level-report.md`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`

- [x] **Step 1: Add build wiring**

Add a module, executable, run step, and test target named:

```text
causal-app-facing-twelve-level-report
zigeffect-causal-app-facing-twelve-level-report
```

- [x] **Step 2: Add user-facing docs**

Document the consumed eleven-level evaluator schema, emitted twelve-level report
schema, ready/advisory/blocked outcomes, and next branch.

- [x] **Step 3: Register schema governance**

Add the twelve-level report schema to schema governance, increment text/json
schema count expectations, and add an `expectSchema` check for the new schema.

- [x] **Step 4: Verify build and governance**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-twelve-level-report -- --help
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
```

Expected: both commands exit 0.

### Task 4: Backlog And Roadmap

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [x] **Step 1: Update backlog next recommendation**

Set:

```zig
pub const recommendation = "start-app-facing-twelve-level-application-boundary";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-twelve-level-application-boundary";
```

- [x] **Step 2: Add delivered backlog item**

Add `app-facing-twelve-level-report` after `app-facing-eleven-level-evaluator`
with delivered status, tool/docs/spec/plan evidence, required verification
commands, and branch `codex/zigeffect-causal-app-facing-twelve-level-report`.

- [x] **Step 3: Update roadmap**

Mark item 110 delivered and add item 111 as
`codex/zigeffect-causal-app-facing-twelve-level-application-boundary`.

- [x] **Step 4: Verify backlog**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-hardening-backlog -- --format json
```

Expected: both commands exit 0 and the JSON recommends the twelve-level
application-boundary branch.

### Task 5: Artifact Generation And Final Verification

**Files:**
- Read generated artifacts under `.zig-cache/causal-artifacts/`

- [x] **Step 1: Generate ready, advisory, and blocked report artifacts**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-twelve-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator.json summarize --reason "reviewed app-facing twelve-level report" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-report
zig build causal-app-facing-twelve-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator-advisory.json summarize --reason "advisory app-facing twelve-level report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-report-advisory
zig build causal-app-facing-twelve-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator-blocked.json summarize --reason "blocked app-facing twelve-level report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-report-blocked
```

Expected: ready, advisory, and blocked JSON/text artifacts are written.

- [x] **Step 2: Run full verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_twelve_level_report.zig
zig build causal-app-facing-twelve-level-report -- --help
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: every command exits 0.

### Task 6: Commit, Merge, And Continue

**Files:**
- Commit all touched docs and zigeffect files.

- [x] **Step 1: Commit**

Run:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing twelve-level report"
```

- [x] **Step 2: Fast-forward local master worktree**

Run:

```bash
git -C /Users/seanknowles/.config/superpowers/worktrees/yachdee/master-local-merge merge --ff-only codex/zigeffect-causal-app-facing-twelve-level-report
```

- [x] **Step 3: Create the next branch**

Run:

```bash
git switch -c codex/zigeffect-causal-app-facing-twelve-level-application-boundary
```

Expected: master includes the completed milestone and the working tree is ready
for the twelve-level application-boundary milestone.
