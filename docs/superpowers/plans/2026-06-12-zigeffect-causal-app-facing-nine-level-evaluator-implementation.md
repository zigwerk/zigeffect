# Zigeffect App-Facing Nine-Level Evaluator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the alias-named nine-level evaluator producer that consumes ready nine-level policy evidence and advances the backlog to the ten-level report branch.

**Architecture:** Reuse the existing eight-level evaluator producer, preserve its ready/advisory/blocked classifier, and retarget source parsing to the short nine-level policy aliases. The physical tool, build step, docs, and branch use short names while emitted schemas keep the full expanded lineage.

**Tech Stack:** Zig build tool, Zig unit tests, deterministic JSON/text artifacts, Bun project verification.

---

### Task 1: Add Failing Evaluator Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_nine_level_evaluator.zig`

- [ ] **Step 1: Write the constants test first**

```zig
const std = @import("std");

test "app-facing nine-level evaluator constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
        schema,
    );
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-nine-level-evaluator", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-ten-level-report", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-ten-level-report", next_branch_if_ready);
}
```

- [ ] **Step 2: Run the focused RED test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_nine_level_evaluator.zig
```

Expected: FAIL with undeclared `schema`.

### Task 2: Promote The Evaluator Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_nine_level_evaluator.zig`

- [ ] **Step 1: Copy the eight-level evaluator into the alias file**

Copy from:

```text
packages/zigeffect/tools/causal_app_facing_eight_level_evaluator.zig
```

- [ ] **Step 2: Replace top-level constants**

Use these values:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-nine-level-evaluator";
pub const recommendation = "start-app-facing-ten-level-report";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-ten-level-report";

const source_policy_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1";
const generated_by = "causal-app-facing-nine-level-evaluator";
const compact_output_prefix_name = "app-facing-ci-nine-level-evaluator";
```

- [ ] **Step 3: Replace alias source fields**

The consumed policy artifact should use the short nine-level aliases:

```text
source_nine_level_application_boundary
source_nine_level_application_boundary_schema
source_nine_level_report
source_nine_level_report_status
source_eight_level_policy
source_eight_level_policy_schema
source_eight_level_policy_status
```

Keep fallback support for inherited fully expanded keys where the eight-level
implementation already provides it, but make emitted evaluator JSON prefer the
short alias fields from the nine-level policy.

- [ ] **Step 4: Keep alias usage text**

Usage should begin:

```text
usage: zig build causal-app-facing-nine-level-evaluator -- --from-policy <nine-level-policy.json> evaluate
```

- [ ] **Step 5: Run the focused GREEN test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_nine_level_evaluator.zig
```

Expected: PASS.

### Task 3: Build Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] Add module, executable, run step, and test target for:

```text
causal-app-facing-nine-level-evaluator
zigeffect-causal-app-facing-nine-level-evaluator
tools/causal_app_facing_nine_level_evaluator.zig
```

- [ ] Verify:

```bash
cd packages/zigeffect
zig build causal-app-facing-nine-level-evaluator -- --help
```

Expected: usage text names `--from-policy`, `evaluate`, `--request`,
`--evidence`, and `--out-prefix`.

### Task 4: Schema Governance RED And GREEN

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`

- [ ] Update tests first to expect schema count plus one and the nine-level evaluator schema.

- [ ] Run the governance RED test:

```bash
cd packages/zigeffect
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
```

Expected: FAIL until the schema is registered.

- [ ] Register the schema with `emitted_by = causal-app-facing-nine-level-evaluator` and `consumed_by` containing agents, reviewers, non-blocking CI advisory readers, local SolidJS workbench, production-hardening backlog, and future app-facing ten-level report.

- [ ] Run the governance GREEN test.

### Task 5: Production Backlog RED And GREEN

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] Update tests first to expect:

```text
recommendation = start-app-facing-ten-level-report
recommended_next_branch = codex/zigeffect-causal-app-facing-ten-level-report
delivered item id = app-facing-nine-level-evaluator
branch = codex/zigeffect-causal-app-facing-nine-level-evaluator
verification = zig build causal-app-facing-nine-level-evaluator -- --help
```

- [ ] Run the backlog RED test:

```bash
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

- [ ] Add the delivered backlog item, dependency order, and verification commands.

- [ ] Run the backlog GREEN test.

### Task 6: Docs, Roadmap, And Artifacts

**Files:**
- Create: `packages/zigeffect/docs/app-facing-nine-level-evaluator.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Regenerate: `packages/zigeffect/docs/schema-governance.md`
- Regenerate: `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] Document consumed schema, emitted schema, command shape, ready/advisory/blocked behavior, denied authority, and artifact examples.
- [ ] Mark roadmap item `codex/zigeffect-causal-app-facing-nine-level-evaluator` delivered.
- [ ] Add next roadmap item `codex/zigeffect-causal-app-facing-ten-level-report`.
- [ ] Generate ready, advisory, and blocked artifacts under `.zig-cache/causal-artifacts/`.

### Task 7: Full Verification And Integration

- [ ] Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_nine_level_evaluator.zig
zig build causal-app-facing-nine-level-evaluator -- --help
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

- [ ] Commit `feat(zigeffect): add app-facing nine-level evaluator`.
- [ ] Fast-forward local `master`.
- [ ] Create `codex/zigeffect-causal-app-facing-ten-level-report` for the next milestone.
