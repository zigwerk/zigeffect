# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Application Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the read-only six-level evaluation-report application-boundary producer and advance the roadmap/backlog to the matching six-level policy branch.

**Architecture:** Reuse the existing five-level application-boundary producer. Promote every evaluation-report lineage token by one level, retarget the source report schema, preserve plan/record-applied/blocked behavior, and update build/docs/governance/backlog/roadmap surfaces.

**Tech Stack:** Zig build tool, Zig unit tests, deterministic JSON/text artifacts, Bun project verification.

---

### Task 1: Add Failing Application Boundary Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig`

- [ ] **Step 1: Write the constants test first**

```zig
const std = @import("std");

test "app-facing consumption report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report application boundary constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
        schema,
    );
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        next_branch_if_applied,
    );
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig
```

Expected: FAIL with undeclared `schema`.

### Task 2: Implement The Application Boundary Producer

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig`

- [ ] **Step 1: Adapt the predecessor**

Use this template:

```text
packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig
```

Promote each evaluation-report chain by one level with sentinel-token replacement:

```bash
cp packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig
perl -0pi -e 's/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/__EVAL_SNAKE_5__/g; s/evaluation_report_evaluation_report_evaluation_report_evaluation_report/__EVAL_SNAKE_4__/g; s/evaluation_report_evaluation_report_evaluation_report/__EVAL_SNAKE_3__/g; s/evaluation_report_evaluation_report/__EVAL_SNAKE_2__/g; s/__EVAL_SNAKE_5__/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/g; s/__EVAL_SNAKE_4__/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/g; s/__EVAL_SNAKE_3__/evaluation_report_evaluation_report_evaluation_report_evaluation_report/g; s/__EVAL_SNAKE_2__/evaluation_report_evaluation_report_evaluation_report/g; s/evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report/__EVAL_HYPHEN_5__/g; s/evaluation-report-evaluation-report-evaluation-report-evaluation-report/__EVAL_HYPHEN_4__/g; s/evaluation-report-evaluation-report-evaluation-report/__EVAL_HYPHEN_3__/g; s/evaluation-report-evaluation-report/__EVAL_HYPHEN_2__/g; s/__EVAL_HYPHEN_5__/evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report/g; s/__EVAL_HYPHEN_4__/evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report/g; s/__EVAL_HYPHEN_3__/evaluation-report-evaluation-report-evaluation-report-evaluation-report/g; s/__EVAL_HYPHEN_2__/evaluation-report-evaluation-report-evaluation-report/g; s/evaluation report evaluation report evaluation report evaluation report evaluation report/__EVAL_TEXT_5__/g; s/evaluation report evaluation report evaluation report evaluation report/__EVAL_TEXT_4__/g; s/evaluation report evaluation report evaluation report/__EVAL_TEXT_3__/g; s/evaluation report evaluation report/__EVAL_TEXT_2__/g; s/__EVAL_TEXT_5__/evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report/g; s/__EVAL_TEXT_4__/evaluation report evaluation report evaluation report evaluation report evaluation report/g; s/__EVAL_TEXT_3__/evaluation report evaluation report evaluation report evaluation report/g; s/__EVAL_TEXT_2__/evaluation report evaluation report evaluation report/g' \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig
```

- [ ] **Step 2: Confirm top-level constants**

The new file must contain:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy";
pub const next_branch_if_applied = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy";

const source_report_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1";
const generated_by = "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary";
const source_report_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json";
const output_prefix_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary";
```

- [ ] **Step 3: Keep application-boundary gates**

Plan mode must emit `applied=false` and `mutation_authority="none"`.

Record-applied mode must require:

```text
source-report-schema
source-report-ready-or-advisory
source-ready-for-next-branch
source-no-blocked-findings
source-evidence-present
source-disabled-authority
application-evidence-present
report-after-present
report-after-safe
post-verification-recorded
publication-local-only
```

Blocked source reports, unsafe after-report content, missing evidence, incomplete verification, unsafe publication claims, or mutation authority must block application.

- [ ] **Step 4: Run focused tests**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig
```

Expected: PASS.

### Task 3: Register Build Target And Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.md`

- [ ] **Step 1: Add build target after the six-level report target**

Register:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary
```

Add module, executable, run step, test executable, and `test_step` dependency immediately after the six-level report tool block in `packages/zigeffect/build.zig`.

- [ ] **Step 2: Add docs**

Document:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- \
  --from-report <consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json> \
  plan|record-applied \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-after <path>] \
  [--evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-change <text>] \
  [--before <text>] \
  [--after <text>] \
  [--verified-command <command>] \
  [--out-prefix <path-prefix>]
```

State that `record-applied` is evidence recording only and still does not mutate apps, GitHub, workflows, storage, adapters, deployments, or production systems.

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
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

Increment the schema inventory count from 122 to 123 and update tests.

- [ ] **Step 2: Update production hardening backlog**

Mark the six-level application-boundary branch delivered. Add dependency order, evidence sources, verification commands, and update the recommended next branch to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy
```

- [ ] **Step 3: Update roadmap**

Move the six-level application-boundary branch from Next to Delivered and add the six-level policy branch as the new Next item.

- [ ] **Step 4: Regenerate generated docs**

```bash
cd packages/zigeffect
zig build causal-schema-governance > /dev/null 2> docs/schema-governance.md
zig build causal-production-hardening-backlog > /dev/null 2> docs/production-hardening-backlog.md
```

### Task 5: Generate Artifacts, Verify, Commit, And Branch

**Files:**
- Generated locally under `.zig-cache/causal-artifacts/`

- [ ] **Step 1: Generate planned boundary artifact**

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-703575bb1247cd12.json \
  plan \
  --reason "planned app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary"
```

- [ ] **Step 2: Generate applied and blocked artifacts**

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-703575bb1247cd12.json \
  record-applied \
  --reason "reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary" \
  --evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-change "reviewed local evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary for agents reviewers CI advisory readers and SolidJS webui" \
  --before "before local evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary evidence" \
  --after "after local evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary evidence" \
  --evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-after test/fixtures/app-facing-six-level-application-boundary-after-safe.txt \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary

zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-blocked.json \
  record-applied \
  --reason "blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary source" \
  --evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-change "blocked local evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary evidence" \
  --before "blocked before evidence" \
  --after "blocked after evidence" \
  --evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-after ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-blocked.txt \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-blocked
```

- [ ] **Step 3: Run verification and commit**

```bash
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing evaluation report application boundary"
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy
```
