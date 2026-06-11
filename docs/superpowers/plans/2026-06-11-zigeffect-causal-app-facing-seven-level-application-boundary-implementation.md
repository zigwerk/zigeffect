# Zigeffect App-Facing Seven-Level Application Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build the guarded seven-level evaluation-report application-boundary producer and advance the roadmap/backlog to the matching seven-level policy branch.

**Architecture:** Reuse the six-level application-boundary producer. Promote every evaluation-report lineage token by one level, retarget the source report schema to the seven-level report, preserve plan/record-applied/blocked behavior, and update build/docs/governance/backlog/roadmap surfaces.

**Tech Stack:** Zig build tool, Zig unit tests, deterministic JSON/text artifacts, Bun project verification.

---

### Task 1: Add Failing Application-Boundary Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [x] **Step 1: Write the tool constants test first**

```zig
const std = @import("std");

test "app-facing seven-level application boundary constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
        schema,
    );
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        next_branch_if_applied,
    );
}
```

- [x] **Step 2: Run the focused RED test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig
```

Expected: fail with undeclared `schema`.

- [x] **Step 3: Add RED registry expectations**

Update tests to expect schema count `127`, a seven-level application-boundary schema entry, and a seven-level policy recommended branch.

Run:

```bash
cd packages/zigeffect
zig test tools/causal_schema_governance.zig
zig test tools/causal_production_hardening_backlog.zig
```

Expected: fail because the schema entry and backlog item are not implemented yet.

### Task 2: Implement The Application-Boundary Producer

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig`
- Create: `packages/zigeffect/test/fixtures/app-facing-seven-level-application-boundary-after-safe.txt`

- [x] **Step 1: Promote the predecessor**

Copy this predecessor:

```text
packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig
```

into:

```text
packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig
```

Promote snake-case, hyphen-case, and display-text lineage tokens by one evaluation-report level.

- [x] **Step 2: Confirm top-level constants**

The new file must contain:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy";
pub const next_branch_if_applied = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy";

const source_report_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1";
```

- [x] **Step 3: Preserve application gates**

`plan` mode must emit `applied=false` and `mutation_authority="none"`.

`record-applied` mode must require:

```text
source-report-schema
source-report-ready
source-ready-for-next-branch
source-no-blocked-findings
source-evidence-present
source-authority-disabled
report-application-change-present
before-evidence-present
after-evidence-present
after-report-present
after-report-safe
post-verification-recorded
publication-local-only
```

- [x] **Step 4: Run focused GREEN test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig
```

Expected: all tests pass.

### Task 3: Register Build Target And Tool Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.md`

- [x] **Step 1: Add build target after the seven-level report target**

Register module, executable, run step, test executable, and `test_step` dependency for:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary
```

- [x] **Step 2: Add user docs**

Document the command, output schema, plan mode, record-applied mode, required evidence, and explicit non-authority claims. Include that `record-applied` remains evidence recording only and does not mutate apps, GitHub, workflows, storage, adapters, deployments, public artifacts, or production systems.

- [x] **Step 3: Verify build help**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help
```

Expected: prints usage for the seven-level application-boundary command.

### Task 4: Update Governance, Backlog, Roadmap, And Generated Docs

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Regenerate: `packages/zigeffect/docs/schema-governance.md`
- Regenerate: `packages/zigeffect/docs/production-hardening-backlog.md`

- [x] **Step 1: Add schema governance entry**

Add the new schema:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

Update governance tests from `126` to `127`.

- [x] **Step 2: Add backlog item and update recommendation**

Mark the seven-level report as delivered evidence for this branch and add a delivered seven-level application-boundary item. Update the recommended next branch to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy
```

- [x] **Step 3: Update master roadmap**

Move the seven-level report branch to delivered if not already delivered, mark the seven-level application-boundary branch as delivered after implementation, and add the seven-level policy branch as the next action.

- [x] **Step 4: Regenerate generated docs**

Run:

```bash
cd packages/zigeffect
zig build causal-schema-governance > /dev/null 2> docs/schema-governance.md
zig build causal-production-hardening-backlog > /dev/null 2> docs/production-hardening-backlog.md
```

Expected: schema docs say `schema count: 127`; backlog docs recommend the seven-level policy branch.

### Task 5: Generate Artifacts, Verify, Commit, And Prepare Next Branch

**Files:**
- Generated: `.zig-cache/causal-artifacts/*seven-level*application-boundary*`

- [x] **Step 1: Generate planned, applied, and blocked artifacts**

Run the seven-level application-boundary command against the ready seven-level report, the ready seven-level report plus fixture evidence, and the blocked seven-level report.

- [x] **Step 2: Run full verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

- [x] **Step 3: Commit**

Commit with:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing seven-level application boundary"
```

- [x] **Step 4: Create the next branch**

Create:

```bash
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy
```
