# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the record-only policy producer for the evaluation-report evaluation-report evaluation-report application-boundary artifact and advance the roadmap/backlog to the evaluator branch.

**Architecture:** Reuse the existing evaluation-report evaluation-report policy producer shape. Retarget the source schema, current policy output fields, build target, governance entry, backlog item, and roadmap handoff to the triple evaluation-report layer while preserving inherited double-layer source field names exactly as they appear in the applied boundary artifact.

**Tech Stack:** Zig build tool, Zig unit tests, deterministic JSON/text artifacts, Bun project verification.

---

### Task 1: Add Failing Policy Tool Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy.zig`

- [ ] **Step 1: Write a constants test first**

```zig
const std = @import("std");

test "app-facing consumption report evaluation-report evaluation-report evaluation-report policy constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator", next_branch_if_ready);
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy.zig
```

Expected: FAIL with undeclared constants before implementation exists.

### Task 2: Implement the Policy Producer

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy.zig`

- [ ] **Step 1: Mechanically adapt the predecessor**

Use `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy.zig` as the template. Replace output schema and generated names with the triple policy names:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.v1
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy
```

- [ ] **Step 2: Retarget the source schema**

The source boundary schema must be:

```zig
const source_boundary_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1";
```

- [ ] **Step 3: Retarget current source fields**

The source artifact struct must parse the current triple application fields:

```zig
source_consumption_report_evaluation_report_evaluation_report_evaluation_report: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_evaluation_report_status: []const u8 = "",
evaluation_report_evaluation_report_evaluation_report_application_status: []const u8,
evaluation_report_evaluation_report_evaluation_report_after_path: ?[]const u8 = null,
evaluation_report_evaluation_report_evaluation_report_after_digest: []const u8 = "",
evaluation_report_evaluation_report_evaluation_report_after_present: bool = false,
evaluation_report_evaluation_report_evaluation_report_application_changes: []const []const u8 = &.{},
```

- [ ] **Step 4: Preserve inherited double-layer fields**

Keep inherited source fields at the names present in the source JSON:

```zig
source_consumption_report_evaluation_report_evaluation_report_policy: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_policy_schema: []const u8 = "",
source_evaluation_report_evaluation_report_policy_status: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_application_boundary: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_application_boundary_schema: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_status: []const u8 = "",
source_evaluation_report_evaluation_report_application_status: []const u8 = "",
source_evaluation_report_evaluation_report_after_digest: []const u8 = "",
source_evaluation_report_evaluation_report_after_present: bool = false,
source_evaluation_report_evaluation_report_application_changes: []const []const u8 = &.{},
```

- [ ] **Step 5: Preserve policy gates**

Approved policy status requires source schema match, source applied status, `applied=true`, `ready_for_next_branch=true`, `mutation_authority=record-only`, disabled authority flags, SolidJS WebUI read-only posture, source references, application evidence, clean source checks, denied inference rules, local-only publication, and all required verification commands.

### Task 3: Register Build Target and Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.md`

- [ ] **Step 1: Add build target**

Register:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy
```

- [ ] **Step 2: Add docs**

Document usage:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy -- --from-application <evaluation-report-evaluation-report-evaluation-report-application-boundary.json> approve|reject --reason <reason>
```

Document that `approve` requires every `--verified-command`.

### Task 4: Update Governance, Backlog, Roadmap, and Generated Docs

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Regenerate: `packages/zigeffect/docs/schema-governance.md`
- Regenerate: `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Add schema governance entry**

Add schema:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.v1
```

Increment schema count from 111 to 112 and update tests.

- [ ] **Step 2: Update backlog**

Mark `app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy` delivered, add dependency order and verification commands, and recommend:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator
```

- [ ] **Step 3: Update roadmap**

Move item 76 from Next to Delivered and add the evaluator branch as the new Next item.

### Task 5: Verify and Commit

**Files:**
- All changed files

- [ ] **Step 1: Run focused tests and artifacts**

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy -- --help
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-8647693e68603dc4.json approve --reason "reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report policy" --verified-command "bun run zigeffect:workbench:typecheck" --verified-command "bun run zigeffect:workbench:test" --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
```

- [ ] **Step 2: Run project verification**

```bash
cd packages/zigeffect
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

- [ ] **Step 3: Commit and continue**

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing evaluation report policy"
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator
```
