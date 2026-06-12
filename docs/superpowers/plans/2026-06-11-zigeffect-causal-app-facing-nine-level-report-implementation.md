# Zigeffect App-Facing Nine-Level Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the alias-named nine-level report producer that consumes ready or advisory eight-level evaluator evidence and advances the backlog to the nine-level application-boundary branch.

**Architecture:** Reuse the existing eight-level report producer, preserve its ready/advisory/blocked report classifier, and retarget source parsing to the short eight-level evaluator aliases. The physical tool, build step, docs, and branch use short names while emitted schemas keep the full expanded lineage.

**Tech Stack:** Zig build tool, Zig unit tests, deterministic JSON/text artifacts, Bun project verification.

---

### Task 1: Add Failing Report Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_nine_level_report.zig`

- [ ] **Step 1: Write the constants test first**

```zig
const std = @import("std");

test "app-facing nine-level report constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
        schema,
    );
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-nine-level-report", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-nine-level-application-boundary", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-nine-level-application-boundary", next_branch_if_ready);
}
```

- [ ] **Step 2: Run the focused RED test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_nine_level_report.zig
```

Expected: FAIL with undeclared `schema`.

### Task 2: Promote The Report Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_nine_level_report.zig`

- [ ] **Step 1: Copy the previous eight-level report into the alias file**

Copy from:

```text
packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig
```

- [ ] **Step 2: Replace top-level constants**

Use these values:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-nine-level-report";
pub const recommendation = "start-app-facing-nine-level-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-nine-level-application-boundary";

const source_evaluator_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1";
const generated_by = "causal-app-facing-nine-level-report";
const evaluator_suffix = "-ci-eight-level-evaluator.json";
const output_suffix = "-ci-nine-level-report";
const compact_output_prefix_name = "app-facing-ci-nine-level-report";
```

- [ ] **Step 3: Replace alias source fields**

The consumed evaluator artifact should prefer these aliases:

```text
source_eight_level_policy
source_eight_level_policy_schema
source_eight_level_policy_status
source_eight_level_application_boundary
source_eight_level_application_boundary_schema
source_eight_level_report
source_eight_level_report_status
source_eight_level_application_status
source_eight_level_after_digest
source_eight_level_after_present
source_eight_level_application_changes
source_inherited_policy
source_inherited_policy_schema
source_inherited_policy_status
source_inherited_application_boundary
source_inherited_application_boundary_schema
source_inherited_report
source_inherited_report_status
```

Keep fallback support for inherited fully expanded source keys already present
in the copied implementation.

- [ ] **Step 4: Keep alias usage text**

Usage should begin:

```text
usage: zig build causal-app-facing-nine-level-report -- --from-evaluator <eight-level-evaluator.json> summarize
```

- [ ] **Step 5: Run the focused GREEN test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_nine_level_report.zig
```

Expected: PASS.

### Task 3: Build Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] Add module, executable, run step, and test target for:

```text
causal-app-facing-nine-level-report
zigeffect-causal-app-facing-nine-level-report
tools/causal_app_facing_nine_level_report.zig
```

- [ ] Verify:

```bash
cd packages/zigeffect
zig build causal-app-facing-nine-level-report -- --help
```

Expected: usage text names `--from-evaluator`, `summarize`, `--reason`, and
`--out-prefix`.

### Task 4: Schema Governance RED And GREEN

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`

- [ ] Update tests first to expect schema count plus one and the nine-level report schema:

```zig
try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1");
```

- [ ] Run the governance RED test:

```bash
cd packages/zigeffect
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
```

Expected: FAIL until the schema is registered.

- [ ] Register the schema after the eight-level evaluator entry with:

```text
emitted_by = causal-app-facing-nine-level-report
consumed_by = agents, reviewers, non-blocking CI advisory readers, local SolidJS workbench, production-hardening backlog, future app-facing nine-level application-boundary
compatibility = strict-v1, record-only, advisory-only, source-eight-level-evaluator, local-report-only, read-only-consumption, bounded-agent-context, app-facing, solid-webui, webui-dev/zig-webui, no-authority tags
```

- [ ] Run the governance GREEN test.

### Task 5: Production Backlog RED And GREEN

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] Update tests first to expect:

```text
recommendation = start-app-facing-nine-level-application-boundary
recommended_next_branch = codex/zigeffect-causal-app-facing-nine-level-application-boundary
delivered item id = app-facing-nine-level-report
branch = codex/zigeffect-causal-app-facing-nine-level-report
verification = zig build causal-app-facing-nine-level-report -- --help
```

- [ ] Run the backlog RED test:

```bash
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: FAIL until the backlog item and recommendation are updated.

- [ ] Add the delivered backlog item, dependency-order entry, and verification commands for ready, advisory, and blocked report artifacts.

- [ ] Run the backlog GREEN test.

### Task 6: Docs And Roadmap

**Files:**
- Create: `packages/zigeffect/docs/app-facing-nine-level-report.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] Document consumed schema, emitted schema, alias naming policy, ready/advisory/blocked outcomes, denied authority, and next branch.
- [ ] Mark roadmap item 98 delivered and add item 99:

```text
99. `codex/zigeffect-causal-app-facing-nine-level-application-boundary`
   - Next: consume ready or advisory nine-level report artifacts, record planned or reviewed local application-boundary evidence, preserve local-only no-mutation authority, and hand off to the nine-level policy branch.
```

### Task 7: Generate Artifacts And Full Verification

- [ ] Regenerate generated docs:

```bash
cd packages/zigeffect
zig build causal-schema-governance > /dev/null 2> docs/schema-governance.md
zig build causal-production-hardening-backlog > /dev/null 2> docs/production-hardening-backlog.md
```

- [ ] Generate ready report artifact:

```bash
cd packages/zigeffect
zig build causal-app-facing-nine-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator.json summarize --reason "reviewed app-facing nine-level report" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-report
```

- [ ] Generate advisory report artifact:

```bash
cd packages/zigeffect
zig build causal-app-facing-nine-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator-advisory.json summarize --reason "advisory app-facing nine-level report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-report-advisory
```

- [ ] Generate blocked report artifact:

```bash
cd packages/zigeffect
zig build causal-app-facing-nine-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator-blocked.json summarize --reason "blocked app-facing nine-level report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-report-blocked
```

- [ ] Run full verification:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_nine_level_report.zig
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-app-facing-nine-level-report -- --help
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

### Task 8: Commit, Merge, And Branch Checkpoint

- [ ] Commit:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing nine-level report"
```

- [ ] Fast-forward local master:

```bash
git -C /Users/seanknowles/.config/superpowers/worktrees/yachdee/master-local-merge merge --ff-only codex/zigeffect-causal-app-facing-nine-level-report
```

- [ ] Create the next branch:

```bash
git switch -c codex/zigeffect-causal-app-facing-nine-level-application-boundary
```
