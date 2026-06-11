# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Evaluation Report Application Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the guarded application-boundary producer for the four-level evaluation-report artifact and advance the roadmap/backlog to the four-level policy branch.

**Architecture:** Reuse the existing app-facing evaluation-report evaluation-report evaluation-report application-boundary producer. Retarget the source schema, source status field, current source lineage, CLI flags, output field names, required build target, fixtures, docs, schema governance, hardening backlog, and roadmap handoff to the four-level evaluation-report layer.

**Tech Stack:** Zig build tool, Zig unit tests, deterministic JSON/text artifacts, Bun project verification.

---

### Task 1: Add Failing Boundary Tool Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig`

- [ ] **Step 1: Write the constants test first**

```zig
const std = @import("std");

test "app-facing consumption report evaluation-report evaluation-report evaluation-report evaluation-report application boundary constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", next_branch_if_applied);
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig
```

Expected: FAIL with undeclared symbols before implementation exists.

### Task 2: Implement The Boundary Producer

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig`

- [ ] **Step 1: Mechanically adapt the predecessor**

Use this template:

```text
packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig
```

Retarget constants to:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy";
pub const next_branch_if_applied = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy";

const source_report_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1";
const generated_by = "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary";
const source_report_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json";
const output_prefix_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary";
const compact_output_prefix_name = "app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary";
```

- [ ] **Step 2: Retarget current source fields**

The `SourceReportArtifact` parser must include these current triple-layer source fields from the four-level report artifact:

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
consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status: []const u8 = "",
```

- [ ] **Step 3: Preserve inherited source fields**

Keep these inherited double-layer fields:

```zig
source_consumption_report_evaluation_report_evaluation_report_policy: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_policy_schema: []const u8 = "",
source_evaluation_report_evaluation_report_policy_status: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_application_boundary: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_application_boundary_schema: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_status: []const u8 = "",
source_evaluation_report_evaluation_report_application_status: []const u8 = "",
source_evaluation_report_evaluation_report_application_changes: []const []const u8 = &.{},
```

- [ ] **Step 4: Retarget CLI flags and output fields**

Use four-level application flags:

```text
--evaluation-report-evaluation-report-evaluation-report-evaluation-report-after
--evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-change
```

`plan` must emit:

```text
evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status = planned
applied = false
ready_for_next_branch = false
mutation_authority = none
```

`record-applied` may emit:

```text
evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status = applied
applied = true
ready_for_next_branch = true
mutation_authority = record-only
```

only when every boundary check passes.

- [ ] **Step 5: Preserve guards**

Keep checks for source schema, ready/advisory source status, no blocked findings, disabled authority flags, SolidJS WebUI read-only posture, source references, request/support/signal summaries, local-only publication channels, source verification commands, reviewed application changes, before/after evidence, safe after-report content, denied claims, and next queries.

### Task 3: Register Build Target And Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.md`

- [ ] **Step 1: Add build target after the four-level report target**

Register:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary
```

Add module, executable, run step, test executable, and `test_step` dependency immediately after the four-level report tool block in `packages/zigeffect/build.zig`.

- [ ] **Step 2: Add docs**

Document:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- \
  --from-report <consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json> \
  plan \
  --reason <reason>
```

and:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- \
  --from-report <consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json> \
  record-applied \
  --reason <reason> \
  --evaluation-report-evaluation-report-evaluation-report-evaluation-report-after <after-report.txt> \
  --evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-change <change> \
  --before <evidence> \
  --after <evidence> \
  --verified-command "zig build examples"
```

State that the command is local-only, record-only, and non-mutating.

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
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

Increment the schema inventory count from 114 to 115 and update tests.

- [ ] **Step 2: Update production hardening backlog**

Mark the four-level application-boundary branch delivered. Add dependency order, evidence sources, verification commands, and update the recommended next branch to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy
```

- [ ] **Step 3: Update roadmap**

Move the application-boundary branch from Next to Delivered and add the four-level policy branch as the new Next item.

- [ ] **Step 4: Regenerate generated docs**

```bash
cd packages/zigeffect
zig build causal-schema-governance > /dev/null 2> docs/schema-governance.md
zig build causal-production-hardening-backlog > /dev/null 2> docs/production-hardening-backlog.md
```

### Task 5: Generate Artifacts, Verify, Commit, And Continue

**Files:**
- All changed files

- [ ] **Step 1: Run focused tests and help**

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help
```

- [ ] **Step 2: Generate ready, applied, and blocked artifacts**

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-1ed481ad46bc4cf1.json plan --reason "app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report application boundary planned" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-plan
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-1ed481ad46bc4cf1.json record-applied --reason "reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report application boundary" --evaluation-report-evaluation-report-evaluation-report-evaluation-report-after ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-after.txt --evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-change "reviewed local evaluation report evaluation report evaluation report evaluation report application boundary for agents reviewers CI advisory readers and SolidJS webui" --before "before local evaluation report evaluation report evaluation report evaluation report application boundary evidence" --after "after local evaluation report evaluation report evaluation report evaluation report application boundary evidence" --verified-command "bun run zigeffect:workbench:typecheck" --verified-command "bun run zigeffect:workbench:test" --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-blocked.json record-applied --reason "blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report application boundary source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-blocked
```

- [ ] **Step 3: Run project verification**

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

- [ ] **Step 4: Commit and continue**

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing evaluation report application boundary"
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy
```
