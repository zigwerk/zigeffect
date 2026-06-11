# Zigeffect App-Facing Evaluation Report Evaluation Report Application Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the guarded application-boundary producer for the evaluation-report-evaluation-report artifact and advance the roadmap/backlog to the next policy branch.

**Architecture:** Reuse the existing app-facing evaluation-report application-boundary producer shape. Retarget source schema, source status fields, output field names, required build target, fixtures, docs, governance, backlog, and roadmap to the new evaluation-report-evaluation-report layer.

**Tech Stack:** Zig build tool, Zig unit tests, deterministic JSON/text artifacts, Bun project verification.

---

### Task 1: Add Failing Boundary Tool Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary.zig`

- [ ] **Step 1: Write a constants test first**

```zig
test "app-facing consumption report evaluation-report evaluation-report application boundary constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy", next_branch_if_applied);
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary.zig
```

Expected: FAIL with undeclared symbols or missing file before implementation exists.

### Task 2: Implement the Boundary Producer

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary.zig`

- [ ] **Step 1: Mechanically adapt the predecessor**

Use `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary.zig` as the template. Replace the source schema with `...evaluation-report-evaluation-report.v1`, the output schema with `...evaluation-report-evaluation-report-application-boundary.v1`, and the next branch with `...evaluation-report-evaluation-report-policy`.

- [ ] **Step 2: Retarget source fields**

The source artifact struct must parse the evaluation-report-evaluation-report fields:

```zig
source_evaluator: []const u8
source_evaluator_status: []const u8
source_consumption_report_evaluation_report_policy: []const u8
source_evaluation_report_policy_status: []const u8
source_consumption_report_evaluation_report_application_boundary: []const u8
source_evaluation_report_application_status: []const u8
source_consumption_report_evaluation_report: []const u8
source_consumption_report_evaluation_report_status: []const u8
consumption_report_evaluation_report_evaluation_report_status: []const u8
ready_for_next_branch: bool
blocked_findings_count: usize
mutation_authority: []const u8
```

- [ ] **Step 3: Preserve boundary gates**

Keep checks for source schema, ready/advisory status, no blocked findings, disabled authority, SolidJS WebUI read-only posture, source references, source summaries, source checks, local-only publication, and source verification commands.

- [ ] **Step 4: Implement `plan` and `record-applied` outputs**

`plan` must emit `evaluation_report_evaluation_report_application_status="planned"`, `applied=false`, `ready_for_next_branch=false`, and `mutation_authority="none"`.

`record-applied` must emit `evaluation_report_evaluation_report_application_status="applied"` only when all application checks pass. Otherwise it emits `blocked` and `applied=false`.

### Task 3: Register Build Target and Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary.md`

- [ ] **Step 1: Add build target**

Register target name:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary
```

- [ ] **Step 2: Add docs**

Document usage:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary -- --from-report <evaluation-report-evaluation-report.json> plan|record-applied --reason <reason>
```

Document that `record-applied` requires `--evaluation-report-evaluation-report-after`, `--evaluation-report-evaluation-report-application-change`, `--before`, `--after`, and every `--verified-command`.

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
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary.v1
```

Increment schema count by one and update tests.

- [ ] **Step 2: Update backlog**

Mark `app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary` delivered, add dependency order, add verification commands, and recommend:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy
```

- [ ] **Step 3: Update roadmap**

Move this branch from Next to Delivered and add the policy branch as Next.

### Task 5: Verify and Commit

**Files:**
- All changed files

- [ ] **Step 1: Run focused tests**

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary -- --help
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

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing evaluation report application boundary"
```
