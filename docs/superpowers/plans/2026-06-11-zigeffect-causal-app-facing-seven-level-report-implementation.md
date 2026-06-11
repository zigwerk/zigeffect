# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build the read-only seven-level evaluation-report producer and advance the roadmap/backlog to the matching seven-level application-boundary branch.

**Architecture:** Reuse the existing six-level report producer. Promote every evaluation-report lineage token by one level, retarget the source evaluator schema, preserve ready/advisory/blocked report publication, and update build/docs/governance/backlog/roadmap surfaces.

**Tech Stack:** Zig build tool, Zig unit tests, deterministic JSON/text artifacts, Bun project verification.

---

### Task 1: Add Failing Report Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig`

- [x] **Step 1: Write the constants test first**

```zig
const std = @import("std");

test "app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report schema and branch constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
        schema,
    );
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        next_branch_if_ready,
    );
}
```

- [x] **Step 2: Run the test to verify RED**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig
```

Expected: FAIL with undeclared `schema`.

### Task 2: Implement The Report Producer

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig`

- [x] **Step 1: Adapt the predecessor**

Use this template:

```text
packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig
```

Promote each evaluation-report chain by one level with sentinel-token replacement:

```bash
cp packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig
perl -0pi -e 's/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/g; s/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/g; s/evaluation_report_evaluation_report_evaluation_report_evaluation_report/evaluation_report_evaluation_report_evaluation_report_evaluation_report/g; s/evaluation_report_evaluation_report_evaluation_report/evaluation_report_evaluation_report_evaluation_report/g; s/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/g; s/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/g; s/evaluation_report_evaluation_report_evaluation_report_evaluation_report/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/g; s/evaluation_report_evaluation_report_evaluation_report/evaluation_report_evaluation_report_evaluation_report_evaluation_report/g; s/evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report/evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report/g; s/evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report/evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report/g; s/evaluation-report-evaluation-report-evaluation-report-evaluation-report/evaluation-report-evaluation-report-evaluation-report-evaluation-report/g; s/evaluation-report-evaluation-report-evaluation-report/evaluation-report-evaluation-report-evaluation-report/g; s/evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report/evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report/g; s/evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report/evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report/g; s/evaluation-report-evaluation-report-evaluation-report-evaluation-report/evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report/g; s/evaluation-report-evaluation-report-evaluation-report/evaluation-report-evaluation-report-evaluation-report-evaluation-report/g; s/evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report/evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report/g; s/evaluation report evaluation report evaluation report evaluation report evaluation report/evaluation report evaluation report evaluation report evaluation report evaluation report/g; s/evaluation report evaluation report evaluation report evaluation report/evaluation report evaluation report evaluation report evaluation report/g; s/evaluation report evaluation report evaluation report/evaluation report evaluation report evaluation report/g; s/evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report/evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report/g; s/evaluation report evaluation report evaluation report evaluation report evaluation report/evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report/g; s/evaluation report evaluation report evaluation report evaluation report/evaluation report evaluation report evaluation report evaluation report evaluation report/g; s/evaluation report evaluation report evaluation report/evaluation report evaluation report evaluation report evaluation report/g' \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig
```

- [x] **Step 2: Confirm top-level constants**

The new file must contain:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary";

const source_evaluator_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1";
const generated_by = "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report";
```

- [x] **Step 3: Keep report gates**

Ready output must require:

```text
source-evaluator-schema
source-evaluator-reportable
source-ready-for-next-branch
source-no-blocked-findings
source-evaluation-report-policy-ready
source-evaluation-report-application-evidence
source-file-analysis-present
source-report-sections-present
source-disabled-authority
source-solid-webui
report-publication-local-only
```

Advisory source evaluator artifacts remain advisory reports. Blocked source evaluator artifacts, missing inherited evidence, unsafe publication posture, public upload claims, app runtime claims, NenDB write claims, Cockroach claims, or authority drift must block.

- [x] **Step 4: Run focused tests**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig
```

Expected: PASS.

### Task 3: Register Build Target And Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.md`

- [x] **Step 1: Add build target after the six-level evaluator target**

Register:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report
```

Add module, executable, run step, test executable, and `test_step` dependency immediately after the six-level evaluator tool block in `packages/zigeffect/build.zig`.

- [x] **Step 2: Add docs**

Document:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- \
  --from-evaluator <consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.json> \
  summarize \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

State that the report is advisory and read-only. It never mutates app, GitHub, workflow, runtime, storage, adapter, deployment, registry, or production state.

### Task 4: Update Governance, Backlog, Roadmap, And Generated Docs

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Regenerate: `packages/zigeffect/docs/schema-governance.md`
- Regenerate: `packages/zigeffect/docs/production-hardening-backlog.md`

- [x] **Step 1: Add schema governance entry**

Add:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1
```

Increment the schema inventory count from 125 to 126 and update tests.

- [x] **Step 2: Update production hardening backlog**

Mark the seven-level report branch delivered. Add dependency order, evidence sources, verification commands, and update the recommended next branch to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary
```

- [x] **Step 3: Update roadmap**

Move the seven-level report branch from Next to Delivered and add the seven-level application-boundary branch as the new Next item.

- [x] **Step 4: Regenerate generated docs**

```bash
cd packages/zigeffect
zig build causal-schema-governance > /dev/null 2> docs/schema-governance.md
zig build causal-production-hardening-backlog > /dev/null 2> docs/production-hardening-backlog.md
```

### Task 5: Generate Artifacts, Verify, Commit, And Branch

**Files:**
- Generated locally under `.zig-cache/causal-artifacts/`

- [x] **Step 1: Generate ready, advisory, and blocked report artifacts**

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.json \
  summarize \
  --reason "reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report"

zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-advisory.json \
  summarize \
  --reason "advisory app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report source" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-advisory

zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-blocked.json \
  summarize \
  --reason "blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report source" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-blocked
```

- [x] **Step 2: Run verification and commit**

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing evaluation report summary"
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary
```
