# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Evaluation Report Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the record-only policy producer for the four-level evaluation-report application-boundary artifact and advance the roadmap/backlog to the four-level evaluator branch.

**Architecture:** Reuse the existing app-facing evaluation-report evaluation-report evaluation-report policy producer. Retarget schema names, source application-boundary schema, current source lineage, policy status field, CLI usage, output names, required build target, fixtures, docs, schema governance, hardening backlog, and roadmap handoff to the four-level evaluation-report layer.

**Tech Stack:** Zig build tool, Zig unit tests, deterministic JSON/text artifacts, Bun project verification.

---

### Task 1: Add Failing Policy Tool Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig`

- [ ] **Step 1: Write the constants test first**

```zig
const std = @import("std");

test "app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report policy schema and branch constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
        schema,
    );
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        next_branch_if_ready,
    );
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig
```

Expected: FAIL with undeclared symbols before implementation exists.

### Task 2: Implement The Policy Producer

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig`

- [ ] **Step 1: Adapt the predecessor**

Use this template:

```text
packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy.zig
```

Retarget constants to:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator";

const source_boundary_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1";
const generated_by = "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy";
const source_boundary_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json";
const output_prefix_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy";
```

- [ ] **Step 2: Retarget current source fields**

The parser and formatter must understand these four-level application-boundary fields:

```zig
source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status: []const u8 = "",
evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status: []const u8,
evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_path: ?[]const u8 = null,
evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest: []const u8 = "",
evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present: bool = false,
evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes: []const []const u8 = &.{},
```

- [ ] **Step 3: Retarget inherited source fields**

The parser and required source checks must require the inherited triple-layer policy/application lineage:

```zig
source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_schema: []const u8 = "",
source_evaluation_report_evaluation_report_evaluation_report_policy_status: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_evaluation_report: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_evaluation_report_status: []const u8 = "",
source_evaluation_report_evaluation_report_evaluation_report_application_status: []const u8 = "",
source_evaluation_report_evaluation_report_evaluation_report_after_digest: []const u8 = "",
source_evaluation_report_evaluation_report_evaluation_report_after_present: bool = false,
source_evaluation_report_evaluation_report_evaluation_report_application_changes: []const []const u8 = &.{},
```

- [ ] **Step 4: Keep policy gates**

Approval must require:

```text
source-schema
source-applied-application
source-refs-present
source-application-evidence-present
source-application-checks-pass
source-report-checks-pass
source-authority-disabled
source-solid-webui-readonly
source-local-publication-only
source-verification-evidence
policy-catalogs-present
required-verification-commands
```

Rejection must be blocked with a `reviewer-decision` failure.

- [ ] **Step 5: Keep output authority read-only**

The policy output must include:

```json
{
  "decision": "approve",
  "consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status": "ready",
  "ready_for_next_branch": true,
  "mutation_authority": "none",
  "ci_required_status_check_enabled": false,
  "github_api_mutation_enabled": false,
  "app_runtime_integration_enabled": false,
  "nendb_write_enabled": false,
  "nendb_adapter_execution_enabled": false,
  "solid_webui_renderer": "solidjs",
  "webui_bridge": "webui-dev/zig-webui"
}
```

### Task 3: Register Build Target And Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.md`

- [ ] **Step 1: Add build target after the four-level application-boundary target**

Register:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy
```

Add module, executable, run step, test executable, and `test_step` dependency immediately after the four-level application-boundary tool block in `packages/zigeffect/build.zig`.

- [ ] **Step 2: Add docs**

Document:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- \
  --from-application <consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json> \
  approve \
  --reason <reason> \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

and:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- \
  --from-application <consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json> \
  reject \
  --reason <reason>
```

State that the command is local-only, record-only, interpretation-only, and non-mutating.

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
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1
```

Increment the schema inventory count from 115 to 116 and update tests.

- [ ] **Step 2: Update production hardening backlog**

Mark the four-level policy branch delivered. Add dependency order, evidence sources, verification commands, and update the recommended next branch to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator
```

- [ ] **Step 3: Update roadmap**

Move the policy branch from Next to Delivered and add the four-level evaluator branch as the new Next item.

- [ ] **Step 4: Regenerate generated docs**

```bash
cd packages/zigeffect
zig build causal-schema-governance > /dev/null 2> docs/schema-governance.md
zig build causal-production-hardening-backlog > /dev/null 2> docs/production-hardening-backlog.md
```

### Task 5: Generate Artifacts, Verify, Commit, And Branch

**Files:**
- Generated locally under `.zig-cache/causal-artifacts/`

- [ ] **Step 1: Generate ready policy artifact**

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-fa99b12beae01779.json \
  approve \
  --reason "reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report policy" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

- [ ] **Step 2: Generate rejected artifact**

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-fa99b12beae01779.json \
  reject \
  --reason "blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report policy" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-rejected
```

- [ ] **Step 3: Run focused verification**

```bash
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

- [ ] **Step 4: Run project verification**

```bash
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

- [ ] **Step 5: Commit and create next branch**

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing evaluation report policy"
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator
```
