# Zigeffect App-Facing Eleven-Level Evaluator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the alias-named eleven-level app-facing evaluator that consumes approved eleven-level policy evidence and hands ready/advisory findings to the twelve-level report branch.

**Architecture:** Promote the proven ten-level evaluator into an eleven-level alias file while updating the source policy contract, lineage fields, generated aliases, and next-branch handoff. The evaluator remains local and read-only; unsafe source policy, unsafe request evidence, or authority drift blocks, while missing support evidence remains advisory.

**Tech Stack:** Zig build tools and `zig test`, Bun root checks, existing zigeffect causal schema governance and production-hardening backlog generators.

---

### Task 1: Evaluator Tool RED Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_eleven_level_evaluator.zig`

- [ ] **Step 1: Write the failing test**

```zig
const std = @import("std");

test "eleven-level evaluator exposes the expected schema and handoff branch" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
        schema,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-twelve-level-report",
        next_branch_if_ready,
    );
}
```

- [ ] **Step 2: Run RED verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eleven_level_evaluator.zig
```

Expected: FAIL because `schema` and `next_branch_if_ready` are not defined.

### Task 2: Promote The Evaluator Implementation

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_eleven_level_evaluator.zig`

- [ ] **Step 1: Copy the ten-level evaluator**

Run:

```bash
cp packages/zigeffect/tools/causal_app_facing_ten_level_evaluator.zig packages/zigeffect/tools/causal_app_facing_eleven_level_evaluator.zig
```

- [ ] **Step 2: Mechanically promote naming**

Run:

```bash
perl -0pi -e 's/ten-level/eleven-level/g; s/ten level/eleven level/g; s/ten_level/eleven_level/g; s/TenLevel/ElevenLevel/g' packages/zigeffect/tools/causal_app_facing_eleven_level_evaluator.zig
```

- [ ] **Step 3: Manually retarget constants**

Ensure the top constants are:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1";
pub const source_branch = "codex/zigeffect-causal-app-facing-eleven-level-evaluator";
pub const recommendation = "start-app-facing-twelve-level-report";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-twelve-level-report";
const source_policy_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1";
const generated_by = "causal-app-facing-eleven-level-evaluator";
const source_policy_suffix = "-ci-eleven-level-policy.json";
const output_prefix_suffix = "-ci-eleven-level-evaluator";
const compact_output_prefix_name = "app-facing-ci-eleven-level-evaluator";
```

- [ ] **Step 4: Preserve lineage**

Add or keep direct `source_eleven_level_*` fields for the current policy path and
preserve inherited `source_ten_level_*` and `source_nine_level_*` fields from
the source policy artifact.

- [ ] **Step 5: Run GREEN verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eleven_level_evaluator.zig
```

Expected: PASS.

### Task 3: Build, Docs, And Governance

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-eleven-level-evaluator.md`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`

- [ ] **Step 1: Add build wiring**

Add a module, executable, run step, and test target named:

```text
causal-app-facing-eleven-level-evaluator
zigeffect-causal-app-facing-eleven-level-evaluator
```

- [ ] **Step 2: Add user-facing docs**

Document the consumed eleven-level policy schema, emitted eleven-level evaluator
schema, ready/advisory/blocked outcomes, and next branch.

- [ ] **Step 3: Register schema governance**

Add the eleven-level evaluator schema to schema governance, increment text/json
schema count expectations, and add an `expectSchema` check for the new schema.

- [ ] **Step 4: Verify build and governance**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-eleven-level-evaluator -- --help
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
```

Expected: both commands exit 0.

### Task 4: Backlog And Roadmap

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update backlog next recommendation**

Set:

```zig
pub const recommendation = "start-app-facing-twelve-level-report";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-twelve-level-report";
```

- [ ] **Step 2: Add delivered backlog item**

Add `app-facing-eleven-level-evaluator` after `app-facing-eleven-level-policy`
with delivered status, tool/docs/spec/plan evidence, required verification
commands, and branch `codex/zigeffect-causal-app-facing-eleven-level-evaluator`.

- [ ] **Step 3: Update roadmap**

Mark item 109 delivered and add item 110 as
`codex/zigeffect-causal-app-facing-twelve-level-report`.

- [ ] **Step 4: Verify backlog**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-hardening-backlog -- --format json
```

Expected: both commands exit 0 and the JSON recommends the twelve-level report
branch.

### Task 5: Artifact Generation And Final Verification

**Files:**
- Read generated artifacts under `.zig-cache/causal-artifacts/`

- [ ] **Step 1: Generate ready, advisory, and blocked evaluator artifacts**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-eleven-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-policy.json evaluate --reason "reviewed app-facing eleven-level evaluator" --request ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator-support.txt --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator
zig build causal-app-facing-eleven-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-policy.json evaluate --reason "advisory app-facing eleven-level evaluator source" --request ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator-advisory
zig build causal-app-facing-eleven-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-policy-reject.json evaluate --reason "blocked app-facing eleven-level evaluator source" --request ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator-blocked
```

Expected: ready, advisory, and blocked JSON/text artifacts are written.

- [ ] **Step 2: Run full verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eleven_level_evaluator.zig
zig build causal-app-facing-eleven-level-evaluator -- --help
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

- [ ] **Step 1: Commit**

Run:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing eleven-level evaluator"
```

- [ ] **Step 2: Fast-forward local master worktree**

Run:

```bash
git -C /Users/seanknowles/.config/superpowers/worktrees/yachdee/master-local-merge merge --ff-only codex/zigeffect-causal-app-facing-eleven-level-evaluator
```

- [ ] **Step 3: Create the next branch**

Run:

```bash
git switch -c codex/zigeffect-causal-app-facing-twelve-level-report
```

Expected: master includes the completed milestone and the working tree is ready
for the twelve-level report milestone.
