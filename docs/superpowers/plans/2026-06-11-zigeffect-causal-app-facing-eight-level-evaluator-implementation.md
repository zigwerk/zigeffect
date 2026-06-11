# Zigeffect App-Facing Eight-Level Evaluator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the alias-named eight-level evaluator producer that consumes ready eight-level policy evidence and advances the backlog to the nine-level report branch.

**Architecture:** Reuse the existing seven-level evaluator producer, preserve its ready/advisory/blocked classifier, and retarget source parsing to the short eight-level policy aliases. The physical tool, build step, docs, and branch use short names while emitted schemas keep the full expanded lineage.

**Tech Stack:** Zig build tool, Zig unit tests, deterministic JSON/text artifacts, Bun project verification.

---

### Task 1: Add Failing Evaluator Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_eight_level_evaluator.zig`

- [ ] **Step 1: Write the constants test first**

```zig
const std = @import("std");

test "app-facing eight-level evaluator constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
        schema,
    );
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-eight-level-evaluator", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-nine-level-report", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-nine-level-report", next_branch_if_ready);
}
```

- [ ] **Step 2: Run the focused RED test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eight_level_evaluator.zig
```

Expected: FAIL with undeclared `schema`.

### Task 2: Promote The Evaluator Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_eight_level_evaluator.zig`

- [ ] **Step 1: Copy the seven-level evaluator into the alias file**

Copy from:

```text
packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig
```

- [ ] **Step 2: Replace top-level constants**

Use these values:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-eight-level-evaluator";
pub const recommendation = "start-app-facing-nine-level-report";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-nine-level-report";

const source_policy_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1";
const generated_by = "causal-app-facing-eight-level-evaluator";
const source_policy_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.json";
const output_prefix_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator";
const compact_output_prefix_name = "app-facing-ci-eight-level-evaluator";
```

- [ ] **Step 3: Replace alias source fields**

The consumed policy artifact should use the short eight-level aliases:

```text
source_eight_level_application_boundary
source_eight_level_application_boundary_schema
source_eight_level_report
source_eight_level_report_status
```

Keep fallback support for inherited fully expanded seven/eight-level keys when
it is already present in the copied implementation, but make the emitted
evaluator JSON prefer the short alias fields.

- [ ] **Step 4: Keep alias usage text**

Usage should begin:

```text
usage: zig build causal-app-facing-eight-level-evaluator -- --from-policy <eight-level-policy.json> evaluate
```

- [ ] **Step 5: Run the focused GREEN test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eight_level_evaluator.zig
```

Expected: PASS.

### Task 3: Build Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] Add module, executable, run step, and test target for:

```text
causal-app-facing-eight-level-evaluator
zigeffect-causal-app-facing-eight-level-evaluator
tools/causal_app_facing_eight_level_evaluator.zig
```

- [ ] Verify:

```bash
cd packages/zigeffect
zig build causal-app-facing-eight-level-evaluator -- --help
```

Expected: usage text names `--from-policy`, `evaluate`, `--request`,
`--evidence`, and `--out-prefix`.

### Task 4: Schema Governance RED And GREEN

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`

- [ ] Update tests first to expect schema count plus one and the eight-level evaluator schema:

```zig
try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1");
```

- [ ] Run the governance RED test:

```bash
cd packages/zigeffect
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
```

Expected: FAIL until the schema is registered.

- [ ] Register the schema after the eight-level policy entry with:

```text
emitted_by = causal-app-facing-eight-level-evaluator
consumed_by = agents, reviewers, non-blocking CI advisory readers, local SolidJS workbench, production-hardening backlog, future app-facing nine-level report
compatibility = strict-v1, record-only, advisory-only, source-eight-level-policy, bounded-explicit-evidence, local-report-only, read-only-consumption, bounded-agent-context, app-facing, solid-webui, webui-dev/zig-webui, no-authority tags
```

- [ ] Run the governance GREEN test.

### Task 5: Production Backlog RED And GREEN

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] Update tests first to expect:

```text
recommendation = start-app-facing-nine-level-report
recommended_next_branch = codex/zigeffect-causal-app-facing-nine-level-report
delivered item id = app-facing-eight-level-evaluator
branch = codex/zigeffect-causal-app-facing-eight-level-evaluator
verification = zig build causal-app-facing-eight-level-evaluator -- --help
```

- [ ] Run the backlog RED test:

```bash
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: FAIL until the backlog item and recommendation are updated.

- [ ] Add the delivered backlog item, dependency-order entry, and verification commands for ready, advisory, and blocked evaluator artifacts.

- [ ] Run the backlog GREEN test.

### Task 6: Docs And Roadmap

**Files:**
- Create: `packages/zigeffect/docs/app-facing-eight-level-evaluator.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] Document consumed schema, emitted schema, alias naming policy, ready/advisory/blocked outcomes, denied authority, and next branch.
- [ ] Mark roadmap item 97 delivered and add item 98:

```text
98. `codex/zigeffect-causal-app-facing-nine-level-report`
   - Next: consume ready or advisory eight-level evaluator evidence, summarize the ninth app-facing evaluation-report layer, preserve local-only no-mutation authority, and hand off to the matching application-boundary branch.
```

### Task 7: Generate Artifacts And Full Verification

- [ ] Regenerate generated docs:

```bash
cd packages/zigeffect
zig build causal-schema-governance > /dev/null 2> docs/schema-governance.md
zig build causal-production-hardening-backlog > /dev/null 2> docs/production-hardening-backlog.md
```

- [ ] Generate ready evaluator artifact:

```bash
cd packages/zigeffect
zig build causal-app-facing-eight-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-policy.json evaluate --reason "reviewed app-facing eight-level evaluator" --request ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator-support.txt --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator
```

- [ ] Generate advisory evaluator artifact without support evidence:

```bash
cd packages/zigeffect
zig build causal-app-facing-eight-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-policy.json evaluate --reason "advisory app-facing eight-level evaluator missing support" --request ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator-advisory
```

- [ ] Generate blocked evaluator artifact from rejected policy:

```bash
cd packages/zigeffect
zig build causal-app-facing-eight-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-policy-reject.json evaluate --reason "blocked app-facing eight-level evaluator source" --request ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator-blocked
```

- [ ] Run full verification:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eight_level_evaluator.zig
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-app-facing-eight-level-evaluator -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: all commands exit 0.

### Task 8: Commit And Merge Checkpoint

- [ ] Commit:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing eight-level evaluator"
```

- [ ] Fast-forward `master`:

```bash
git -C /Users/seanknowles/.config/superpowers/worktrees/yachdee/master-local-merge merge --ff-only codex/zigeffect-causal-app-facing-eight-level-evaluator
```

- [ ] Create `codex/zigeffect-causal-app-facing-nine-level-report`:

```bash
git switch -c codex/zigeffect-causal-app-facing-nine-level-report
```

## Self-Review

- Spec coverage: The plan covers evaluator behavior, alias fields, docs, build wiring, schema governance, backlog, roadmap, generated docs, artifacts, verification, commit, merge, and next branch handoff.
- Placeholder scan: No placeholders or TODO markers are intentionally left.
- Type consistency: The plan consistently uses eight-level evaluator for the output producer and nine-level report for the next branch.
