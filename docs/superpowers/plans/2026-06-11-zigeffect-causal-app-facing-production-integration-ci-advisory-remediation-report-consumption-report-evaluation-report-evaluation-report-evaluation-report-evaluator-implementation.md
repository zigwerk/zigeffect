# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Evaluator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the read-only evaluator producer for triple evaluation-report policy artifacts and advance the roadmap/backlog to the next report summarizer branch.

**Architecture:** Mechanically adapt the existing evaluation-report evaluation-report evaluator tool to consume the just-delivered triple policy artifact. Preserve the single-file Zig producer pattern, add build/schema/backlog/roadmap registration, and keep all authority disabled.

**Tech Stack:** Zig build tool, Zig unit tests, deterministic JSON/text causal artifacts, Bun project verification.

---

### Task 1: Add Failing Evaluator Constants Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig`

- [ ] **Step 1: Write the constants test first**

```zig
const std = @import("std");

test "app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluator schema and branch constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
        schema,
    );
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        next_branch_if_ready,
    );
}
```

- [ ] **Step 2: Run the test to verify RED**

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig
```

Expected: FAIL with undeclared constants before implementation exists.

### Task 2: Implement the Evaluator Producer

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig`

- [ ] **Step 1: Mechanically adapt the predecessor evaluator**

Use this file as the template:

`packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator.zig`

Replace output and command identifiers with:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator
```

- [ ] **Step 2: Retarget the source policy**

Set:

```zig
const source_policy_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.v1";
const generated_by = "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator";
const source_policy_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.json";
const output_prefix_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator";
const compact_output_prefix_name = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator";
```

- [ ] **Step 3: Retarget required verification commands**

The required commands must include:

```zig
const required_verification_commands: []const []const u8 = &.{
    "bun run zigeffect:workbench:typecheck",
    "bun run zigeffect:workbench:test",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy -- --help",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};
```

- [ ] **Step 4: Retarget `SourcePolicyArtifact` current-layer fields**

The source struct must parse:

```zig
consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_status: []const u8,
source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_evaluation_report: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_evaluation_report_status: []const u8 = "",
source_evaluation_report_evaluation_report_evaluation_report_application_status: []const u8 = "",
source_evaluation_report_evaluation_report_evaluation_report_after_digest: []const u8 = "",
source_evaluation_report_evaluation_report_evaluation_report_after_present: bool = false,
source_evaluation_report_evaluation_report_evaluation_report_application_changes: []const []const u8 = &.{},
```

- [ ] **Step 5: Preserve inherited double-layer fields**

Keep inherited fields with the names emitted by the source artifact:

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

- [ ] **Step 6: Retarget evaluator checks and output fields**

Update source checks, JSON output, text output, usage, fixtures, next queries, guidance, denied input messages, and tests so every current-layer phrase is `evaluation report evaluation report evaluation report` and every next-branch phrase is `evaluation report evaluation report evaluation report evaluation report`.

### Task 3: Register Build Target and Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator.md`

- [ ] **Step 1: Add build target after the triple policy target**

Register:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator
```

Add its module, executable, run step, test executable, and `test_step` dependency immediately before `causal_production_telemetry_readiness_review_tool_module`.

- [ ] **Step 2: Add docs**

Document:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- \
  --from-policy <consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.json> \
  evaluate \
  --reason <reason> \
  --request <path>... \
  [--evidence <path>]...
```

State that ready output requires a ready approved policy source, safe request files, bounded redaction posture, and no authority drift.

### Task 4: Update Governance, Backlog, Roadmap, and Generated Docs

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Regenerate: `packages/zigeffect/docs/schema-governance.md`
- Regenerate: `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Add schema governance entry**

Add:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1
```

Increment schema count from 112 to 113 and update text/json tests.

- [ ] **Step 2: Update backlog**

Mark this evaluator delivered. Add dependency order, evidence sources, verification commands, and recommend:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report
```

- [ ] **Step 3: Update roadmap**

Move the evaluator branch from Next to Delivered and add the report summarizer branch as the new Next item.

- [ ] **Step 4: Regenerate docs**

```bash
cd packages/zigeffect
zig build causal-schema-governance > /dev/null 2> docs/schema-governance.md
zig build causal-production-hardening-backlog > /dev/null 2> docs/production-hardening-backlog.md
```

### Task 5: Verify Artifacts and Commit

**Files:**
- All changed files

- [ ] **Step 1: Create bounded request/evidence fixtures**

```bash
mkdir -p .zig-cache/causal-artifacts
printf '%s\n' '{"request_id":"triple-evaluator-agent-context","consumer_role":"agent-readonly","requested_fields":["source ids","policy rules","denied claims","next queries"],"redaction":"redacted","mutation_authority":"none","raw_payload_capture_enabled":false}' > .zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json
printf '%s\n' 'SolidJS webui-dev/zig-webui read-only evaluator support evidence with redacted source ids and mutation_authority=none.' > .zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-support.txt
```

- [ ] **Step 2: Run focused tests and CLI**

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --help
```

- [ ] **Step 3: Generate ready, advisory, and blocked artifacts**

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy-ab1d305b37585600.json evaluate --reason "reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluator" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-support.txt
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy-ab1d305b37585600.json evaluate --reason "advisory app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluator without support evidence" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-advisory
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy-blocked.json evaluate --reason "blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluator source" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-blocked
```

- [ ] **Step 4: Run project verification**

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

- [ ] **Step 5: Commit and continue**

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing evaluation report evaluator"
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report
```
