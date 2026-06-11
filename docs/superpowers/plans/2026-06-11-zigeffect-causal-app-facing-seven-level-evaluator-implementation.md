# Zigeffect App-Facing Seven-Level Evaluator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build the read-only seven-level evaluator producer that consumes ready seven-level policy evidence and advances the backlog to the eight-level report branch.

**Architecture:** Reuse the existing six-level evaluator producer. Promote every evaluation-report lineage token by one level, retarget the source policy schema to the seven-level policy, preserve ready/advisory/blocked request classification, and update build/docs/governance/backlog/roadmap surfaces.

**Tech Stack:** Zig build tool, Zig unit tests, deterministic JSON/text artifacts, Bun project verification.

---

### Task 1: Add Failing Evaluator Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig`

- [x] **Step 1: Write the constants test first**

```zig
const std = @import("std");

test "app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator schema and branch constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
        schema,
    );
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        next_branch_if_ready,
    );
}
```

- [x] **Step 2: Run the test to verify RED**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig
```

Expected: FAIL with undeclared `schema`.

### Task 2: Add Failing Governance And Backlog Tests

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [x] **Step 1: Update schema governance test expectations first**

Change the expected schema count from `128` to `129`, and add:

```zig
try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1");
```

Also update text and JSON report tests to expect `schema count: 129` and `"schema_count": 129`.

- [x] **Step 2: Update backlog test expectations first**

Update the top-level recommendation expectations to:

```zig
"start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report"
"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report"
```

Add delivered item assertions for:

```zig
try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator");
try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "delivered");
```

Add JSON assertions for the new evaluator id, branch, and help command:

```zig
try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator\"") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator\"") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --help") != null);
```

- [x] **Step 3: Run tests to verify RED**

Run:

```bash
cd packages/zigeffect
zig build test
```

Expected: FAIL because schema governance has 128 entries and the backlog still recommends the seven-level evaluator branch.

### Task 3: Implement The Evaluator Producer

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig`

- [x] **Step 1: Promote the predecessor evaluator**

Use the six-level evaluator as the source:

```bash
cp packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig
```

Then promote all filename, branch, schema, JSON field, text, and command strings by one `evaluation-report` level. Use sentinel replacement from longest token to shortest to avoid partial replacement:

```bash
perl -0pi -e 's/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/g; s/evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report/evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report/g; s/evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report/evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report/g' \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig
```

- [x] **Step 2: Confirm top-level constants**

The new file must contain:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1";
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report";

const source_policy_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1";
const generated_by = "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator";
const source_policy_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.json";
const output_prefix_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator";
```

- [x] **Step 3: Keep evaluator gates**

Ready output must require source policy readiness, approval, `ready_for_next_branch=true`, disabled authority, SolidJS read-only posture, inherited evidence, local-only publication, verification commands, safe request files, and bounded redaction posture.

Missing support evidence must produce advisory findings when the source policy and request are otherwise safe. Rejected policy, blocked source policy, unsafe requests, unsafe support evidence, public upload claims, app runtime claims, NenDB write claims, Cockroach claims, or authority drift must block.

- [x] **Step 4: Run focused tests**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig
```

Expected: PASS.

### Task 4: Add Build Target And Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.md`

- [x] **Step 1: Add build target after the seven-level policy target**

Add a module, executable, run artifact, public step, test artifact, and `test_step` dependency for:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator
```

Use a short internal test artifact name:

```zig
.name = "zigeffect-causal-app-facing-seven-level-evaluator-tests"
```

- [x] **Step 2: Verify build help**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --help
```

Expected: usage text naming `--from-policy`, `evaluate`, `--request`, `--evidence`, and `--out-prefix`.

- [x] **Step 3: Add docs**

Write docs that name the source schema, output schema, ready/advisory/blocked behavior, denied authority boundary, and eight-level report handoff branch.

### Task 5: Update Governance, Backlog, And Roadmap

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Generated: `packages/zigeffect/docs/schema-governance.md`
- Generated: `packages/zigeffect/docs/production-hardening-backlog.md`

- [x] **Step 1: Register schema**

Add schema governance entry:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1
```

Set emitted_by to the new build step and consumed_by to agents, reviewers, non-blocking CI advisory readers, local SolidJS workbench, production-hardening backlog, and the future eight-level report producer.

- [x] **Step 2: Update backlog**

Add a delivered evaluator item after the seven-level policy item. Update:

```zig
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report";
```

Add dependency-order and verification commands for help, ready, advisory, and blocked evaluator artifacts.

- [x] **Step 3: Update roadmap**

Mark item 93 delivered and add item 94 as the eight-level report branch:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report
```

- [x] **Step 4: Regenerate generated docs**

Run:

```bash
cd packages/zigeffect
zig build causal-schema-governance > /dev/null 2> docs/schema-governance.md
zig build causal-production-hardening-backlog > /dev/null 2> docs/production-hardening-backlog.md
```

### Task 6: Generate Artifacts And Verify

**Files:**
- Generated: `.zig-cache/causal-artifacts/*evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator*`

- [x] **Step 1: Generate ready evaluator artifact**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.json evaluate --reason "reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-support.txt
```

- [x] **Step 2: Generate advisory evaluator artifact**

Run the same command without `--evidence` and with:

```bash
--out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-advisory
```

Expected: artifact status is `advisory-findings`.

- [x] **Step 3: Generate blocked evaluator artifact**

Run with blocked policy input:

```bash
--from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-blocked.json
--out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-blocked
```

Expected: artifact status is `blocked`.

- [x] **Step 4: Run full verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: all commands pass.

### Task 7: Commit And Prepare Next Branch

**Files:**
- All files touched above

- [x] **Step 1: Mark plan complete**

Replace every unchecked box in this file with `[x]` after verification passes.

- [x] **Step 2: Commit**

Run:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing seven-level evaluator"
```

- [x] **Step 3: Create next report branch**

Run:

```bash
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report
```

## Self-Review

- Spec coverage: Tasks cover evaluator tool behavior, docs, build wiring, schema governance, backlog, roadmap, generated docs, artifacts, verification, commit, and next branch handoff.
- Placeholder scan: No placeholders or TODO markers are intentionally left.
- Type consistency: The plan consistently uses seven-level evaluator for the output producer and eight-level report for the next branch.
