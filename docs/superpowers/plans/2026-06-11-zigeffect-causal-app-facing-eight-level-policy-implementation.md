# Zigeffect App-Facing Eight-Level Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the alias-named eight-level policy producer that consumes applied eight-level application-boundary evidence and hands off to the short eight-level evaluator branch.

**Architecture:** Promote the existing seven-level policy producer into a short physical file while preserving full schema lineage in emitted artifacts. The tool remains local, record-only, and read-only, with `approve` guarded by source applied evidence plus required verification commands.

**Tech Stack:** Zig build tools and `zig test`, Bun root checks, existing zigeffect causal schema governance and production-hardening backlog generators.

---

### Task 1: Policy Tool RED Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_eight_level_policy.zig`

- [ ] **Step 1: Write the failing constants test**

```zig
const std = @import("std");

test "app-facing eight-level policy constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-eight-level-policy", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-eight-level-evaluator", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-eight-level-evaluator", next_branch_if_ready);
}
```

- [ ] **Step 2: Run the focused RED test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eight_level_policy.zig
```

Expected: FAIL with undeclared identifiers.

### Task 2: Promote The Policy Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_eight_level_policy.zig`

- [ ] **Step 1: Copy the seven-level policy implementation into the alias file**

Copy from:

```text
packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig
```

- [ ] **Step 2: Replace top-level constants**

Use these values:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-eight-level-policy";
pub const recommendation = "start-app-facing-eight-level-evaluator";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-eight-level-evaluator";

const source_boundary_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1";
const generated_by = "causal-app-facing-eight-level-policy";
const source_boundary_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json";
const output_prefix_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy";
const compact_output_prefix_name = "app-facing-ci-eight-level-policy";
```

- [ ] **Step 3: Promote source field names**

The consumed source artifact fields should use the eight-level application-boundary names:

```text
source_eight_level_application_boundary
source_eight_level_application_boundary_schema
source_eight_level_application_boundary_status
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest
```

- [ ] **Step 4: Keep alias usage text**

Usage should begin:

```text
usage: zig build causal-app-facing-eight-level-policy -- --from-application <eight-level-application-boundary.json> approve|reject
```

- [ ] **Step 5: Run the focused GREEN test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eight_level_policy.zig
```

Expected: PASS.

### Task 3: Build Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] Add module, executable, run step, and test target for:

```text
causal-app-facing-eight-level-policy
zigeffect-causal-app-facing-eight-level-policy
tools/causal_app_facing_eight_level_policy.zig
```

- [ ] Verify:

```bash
cd packages/zigeffect
zig build causal-app-facing-eight-level-policy -- --help
```

### Task 4: Schema Governance RED And GREEN

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`

- [ ] Update tests first to expect schema count plus one and the eight-level policy schema.
- [ ] Run the governance RED test.
- [ ] Register the schema with `emitted_by = &.{"causal-app-facing-eight-level-policy"}` and compatibility tags for `strict-v1`, `record-only`, `policy-only`, `source-eight-level-application-boundary`, `approve-reject-decision`, `local-publication-only`, `read-only-consumption`, `bounded-agent-context`, `app-facing`, `solid-webui`, `webui-dev/zig-webui`, and all no-authority tags.
- [ ] Run the governance GREEN test.

### Task 5: Production Backlog RED And GREEN

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] Update tests first to expect:

```text
recommendation = start-app-facing-eight-level-evaluator
recommended_next_branch = codex/zigeffect-causal-app-facing-eight-level-evaluator
delivered item id = app-facing-eight-level-policy
branch = codex/zigeffect-causal-app-facing-eight-level-policy
verification = zig build causal-app-facing-eight-level-policy -- --help
```

- [ ] Run the backlog RED test.
- [ ] Add the delivered backlog item, dependency order, and verification commands.
- [ ] Run the backlog GREEN test.

### Task 6: Docs And Roadmap

**Files:**
- Create: `packages/zigeffect/docs/app-facing-eight-level-policy.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] Document consumed schema, emitted schema, alias naming policy, decisions, gates, denied authority, and next branch.
- [ ] Mark roadmap item 96 delivered and add item 97:

```text
97. `codex/zigeffect-causal-app-facing-eight-level-evaluator`
   - Next: consume approved eight-level policy evidence plus bounded local request and support evidence, emit ready advisory or blocked evaluator findings, preserve no-mutation authority, and hand off to the next eight-level report.
```

### Task 7: Generate Artifacts And Full Verification

- [ ] Regenerate:

```bash
cd packages/zigeffect
zig build causal-schema-governance > /dev/null 2> docs/schema-governance.md
zig build causal-production-hardening-backlog > /dev/null 2> docs/production-hardening-backlog.md
```

- [ ] Generate approve and reject policy artifacts from `.zig-cache/causal-artifacts/app-facing-ci-eight-level-application-boundary.json`.
- [ ] Run the verification commands from the design spec.

### Task 8: Commit And Merge Checkpoint

- [ ] Commit:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing eight-level policy"
```

- [ ] Fast-forward master.
- [ ] Create `codex/zigeffect-causal-app-facing-eight-level-evaluator`.
