# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the read-only five-level evaluation-report policy producer and advance the roadmap/backlog to the matching five-level evaluator branch.

**Architecture:** Reuse the existing four-level policy producer. Promote every evaluation-report lineage token by one level, retarget the source application-boundary schema, preserve approve/reject behavior, and update build/docs/governance/backlog/roadmap surfaces.

**Tech Stack:** Zig build tool, Zig unit tests, deterministic JSON/text artifacts, Bun project verification.

---

### Task 1: Add Failing Policy Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig`

- [ ] **Step 1: Write the constants test first**

```zig
const std = @import("std");

test "app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report policy schema and branch constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
        schema,
    );
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        next_branch_if_ready,
    );
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig
```

Expected: FAIL with undeclared `schema`.

### Task 2: Implement The Policy Producer

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig`

- [ ] **Step 1: Adapt the predecessor**

Use this template:

```text
packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig
```

Promote each evaluation-report chain by one level with sentinel-token replacement:

```bash
cp packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig
perl -0pi -e 's/evaluation_report_evaluation_report_evaluation_report_evaluation_report/__EVAL_SNAKE_4__/g; s/evaluation_report_evaluation_report_evaluation_report/__EVAL_SNAKE_3__/g; s/evaluation_report_evaluation_report/__EVAL_SNAKE_2__/g; s/__EVAL_SNAKE_4__/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/g; s/__EVAL_SNAKE_3__/evaluation_report_evaluation_report_evaluation_report_evaluation_report/g; s/__EVAL_SNAKE_2__/evaluation_report_evaluation_report_evaluation_report/g; s/evaluation-report-evaluation-report-evaluation-report-evaluation-report/__EVAL_HYPHEN_4__/g; s/evaluation-report-evaluation-report-evaluation-report/__EVAL_HYPHEN_3__/g; s/evaluation-report-evaluation-report/__EVAL_HYPHEN_2__/g; s/__EVAL_HYPHEN_4__/evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report/g; s/__EVAL_HYPHEN_3__/evaluation-report-evaluation-report-evaluation-report-evaluation-report/g; s/__EVAL_HYPHEN_2__/evaluation-report-evaluation-report-evaluation-report/g; s/evaluation report evaluation report evaluation report evaluation report/__EVAL_TEXT_4__/g; s/evaluation report evaluation report evaluation report/__EVAL_TEXT_3__/g; s/evaluation report evaluation report/__EVAL_TEXT_2__/g; s/__EVAL_TEXT_4__/evaluation report evaluation report evaluation report evaluation report evaluation report/g; s/__EVAL_TEXT_3__/evaluation report evaluation report evaluation report evaluation report/g; s/__EVAL_TEXT_2__/evaluation report evaluation report evaluation report/g' \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig
```

- [ ] **Step 2: Confirm top-level constants**

The new file must contain:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator";

const source_boundary_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1";
const generated_by = "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy";
const source_boundary_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json";
const output_prefix_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy";
```

- [ ] **Step 3: Keep policy gates**

Approval must require:

```text
source-schema
source-applied
source-ready-for-next
source-application-evidence
source-publication-local-only
source-denied-claims-present
source-negative-fixtures-present
source-required-verification-present
required-verification-commands
source-authority-disabled
reviewer-decision
```

Reject mode must preserve blocked policy evidence without treating rejection as a tool failure.

Unsafe source boundaries, planned-only boundaries, blocked boundaries, missing verification, unsafe publication claims, or authority drift must block approval.

- [ ] **Step 4: Run focused tests**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig
```

Expected: PASS.

### Task 3: Register Build Target And Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.md`

- [ ] **Step 1: Add build target after the five-level application-boundary target**

Register:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy
```

Add module, executable, run step, test executable, and `test_step` dependency immediately after the five-level application-boundary tool block in `packages/zigeffect/build.zig`.

- [ ] **Step 2: Add docs**

Document:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- \
  --from-application <consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json> \
  approve|reject \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--verified-command <command>]... \
  [--out-prefix <path-prefix>]
```

State that the policy is interpretation-only and never mutates app, GitHub, workflow, runtime, storage, adapter, deployment, or production state.

### Task 4: Update Governance, Backlog, Roadmap, And Generated Docs

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Regenerate: `packages/zigeffect/docs/schema-governance.md`
- Regenerate: `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Add schema governance entry**

Add:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1
```

Increment the schema inventory count from 119 to 120 and update tests.

- [ ] **Step 2: Update production hardening backlog**

Mark the five-level policy branch delivered. Add dependency order, evidence sources, verification commands, and update the recommended next branch to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator
```

- [ ] **Step 3: Update roadmap**

Move the five-level policy branch from Next to Delivered and add the five-level evaluator branch as the new Next item.

- [ ] **Step 4: Regenerate generated docs**

```bash
cd packages/zigeffect
zig build causal-schema-governance > /dev/null 2> docs/schema-governance.md
zig build causal-production-hardening-backlog > /dev/null 2> docs/production-hardening-backlog.md
```

### Task 5: Generate Artifacts, Verify, Commit, And Branch

**Files:**
- Generated locally under `.zig-cache/causal-artifacts/`

- [ ] **Step 1: Generate approve and reject artifacts**

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json \
  approve \
  --reason "reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report policy" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"

zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json \
  reject \
  --reason "rejected app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report policy" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-reject
```

- [ ] **Step 2: Generate blocked-source approval artifact**

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-blocked.json \
  approve \
  --reason "blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report policy source" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-blocked
```

- [ ] **Step 3: Run verification and commit**

```bash
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing evaluation report policy"
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator
```
