# Production Telemetry CI Gate Advisory CI Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `causal-production-telemetry-ci-gate-advisory-ci-report`, a record-only renderer for reviewer-facing advisory CI report artifacts from dry-run evaluator output.

**Architecture:** Add one Zig tool following the existing production telemetry artifact-chain pattern. The tool parses one evaluator JSON artifact, validates reportability and authority boundaries, renders deterministic JSON/text report artifacts, and updates schema governance, backlog, roadmap, and operations docs.

**Tech Stack:** Zig 0.16.0, `std.json`, existing zigeffect build steps, Bun root verification.

---

## File Structure

- Create `packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report.zig`
  - CLI parsing, source evaluator parsing, report checks, report rendering,
    file IO, and tests.
- Modify `packages/zigeffect/build.zig`
  - Add executable, build step, and test integration after the dry-run
    evaluator tool.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Add schema entry and update schema count from 66 to 67.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Mark advisory CI report delivered and recommend the application-boundary
    branch.
- Create `packages/zigeffect/docs/production-telemetry-ci-gate-advisory-ci-report.md`
  - Document command, source contract, statuses, publication boundaries, and
    verification.
- Modify existing roadmap and operations docs that mention the advisory CI
  report as the next branch.

## Task 1: Create the Red Test

**Files:**
- Create: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report.zig`

- [ ] **Step 1: Add the failing constants test**

Create the file with only this test:

```zig
const std = @import("std");

test "ci gate advisory CI report schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1", production_telemetry_ci_gate_advisory_ci_report_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_advisory_ci_report_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-advisory-ci-report-application-boundary", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary", next_branch_if_ready);
}
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_advisory_ci_report.zig
```

Expected: fail with an undeclared identifier for
`production_telemetry_ci_gate_advisory_ci_report_schema`.

## Task 2: Implement Constants and CLI Parsing

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report.zig`

- [ ] **Step 1: Add constants**

Add these constants:

```zig
pub const production_telemetry_ci_gate_advisory_ci_report_schema = "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1";
pub const production_telemetry_ci_gate_advisory_ci_report_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report";
pub const recommendation = "start-production-telemetry-ci-gate-advisory-ci-report-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary";

const evaluator_schema = "zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1";
const generated_by = "causal-production-telemetry-ci-gate-advisory-ci-report";
```

- [ ] **Step 2: Add option parsing types**

Define `Options` with `evaluator_path`, `reason`, `reviewed_by`, `policy`,
and `out_prefix`. Parse:

```sh
--from-evaluator <evaluator.json> summarize --reason <reason>
```

Also parse optional `--by`, `--policy`, and `--out-prefix`.

- [ ] **Step 3: Add CLI parsing tests**

Add tests for required command shape, defaults, and custom actor/policy/output
prefix.

- [ ] **Step 4: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_advisory_ci_report.zig
```

Expected: constants and CLI parsing tests pass.

## Task 3: Parse Evaluator Artifacts and Evaluate Report Status

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report.zig`

- [ ] **Step 1: Add source structs**

Define structs for evaluator checks, signals, findings, publication channels,
and the source evaluator artifact. Required source fields are:

```zig
schema
schema_version
evaluation_status
ready_for_next_branch
advisory_findings_count
blocked_findings_count
ci_gate_enforcement_enabled
ci_required_status_check_enabled
ci_workflow_mutation_enabled
ci_upload_execution_enabled
production_telemetry_ingestion
live_exporter_enabled
network_send_enabled
collector_endpoint_configured
otlp_serialization_enabled
runtime_pipeline_enabled
durable_write_enabled
nendb_write_enabled
signal_evaluations
findings
next_queries
checks
blocked_claims
generated_by
```

- [ ] **Step 2: Add report status logic**

Return:

- `ready` for `evaluation_status="ready"` with zero blocked findings.
- `advisory` for `evaluation_status="advisory-findings"` with zero blocked
  findings.
- `blocked` for invalid schema, blocked source status, disabled-authority
  violations, blocked source findings, or missing source sections.

- [ ] **Step 3: Add report status tests**

Add one sample ready evaluator artifact, one advisory artifact, one blocked
artifact, and one authority-violating artifact. Assert the output status and
`ready_for_next_branch` value for each.

## Task 4: Render JSON and Text Reports

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report.zig`

- [ ] **Step 1: Add JSON rendering**

Render deterministic JSON with:

```text
schema
schema_version
source_evaluator
source_evaluation_status
report_status
ready_for_next_branch
reviewed_by
policy
reason
headline
report_sections
signal_summary
advisory_findings
next_queries
checks
blocked_claims
publication_channels
required_verification_commands
generated_by
source_branch
recommendation
next_branch_if_ready
json_output
text_output
agent_guidance
```

- [ ] **Step 2: Add text rendering**

Render a concise local artifact report with headline, source status, report
status, signal summary, advisory findings, next queries, blocked claims, and
record-only publication channels.

- [ ] **Step 3: Add output path tests**

Assert that `*-ci-gate-dry-run-evaluator.json` becomes
`*-ci-gate-advisory-ci-report.json`.

## Task 5: Add Build Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add module, executable, step, and test integration**

Add the advisory CI report tool immediately after the dry-run evaluator build
step. The build step name must be:

```text
causal-production-telemetry-ci-gate-advisory-ci-report
```

- [ ] **Step 2: Run help through build**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-advisory-ci-report -- --help
```

Expected: prints usage and exits 0.

## Task 6: Update Governance, Backlog, and Docs

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Create: `packages/zigeffect/docs/production-telemetry-ci-gate-advisory-ci-report.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/production-telemetry-ci-gate-dry-run-evaluator.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Register schema**

Add schema:

```text
zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1
```

Update schema count assertions from 66 to 67.

- [ ] **Step 2: Update backlog**

Add delivered backlog item `production-telemetry-ci-gate-advisory-ci-report`
and set recommendation to:

```text
start-production-telemetry-ci-gate-advisory-ci-report-application-boundary
```

- [ ] **Step 3: Update docs**

Document command, source contract, report statuses, record-only publication
channels, verification commands, and next branch handoff.

## Task 7: Verify and Commit

**Files:**
- All implementation and docs files from this plan.

- [ ] **Step 1: Run focused verification**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_advisory_ci_report.zig
zig build causal-production-telemetry-ci-gate-advisory-ci-report -- --help
```

Expected: both commands exit 0.

- [ ] **Step 2: Generate advisory and blocked artifacts**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-advisory-ci-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-dry-run-evaluator.json \
  summarize \
  --reason "CI advisory report reviewed"
zig build causal-production-telemetry-ci-gate-advisory-ci-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-dry-run-evaluator-negative.json \
  summarize \
  --reason "negative CI advisory report path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-negative
```

Expected: first command emits ready or advisory report; second emits blocked
report.

- [ ] **Step 3: Run full verification**

Run:

```sh
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

Expected: every command exits 0.

- [ ] **Step 4: Commit**

Run:

```sh
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-design.md \
  docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-implementation.md \
  packages/zigeffect/README.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git commit -m "feat(zigeffect): add production telemetry ci gate advisory ci report"
```

Expected: commit succeeds on
`codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report`.
