# Production Telemetry CI Gate Advisory CI Report Application Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary`, a guarded record-only application boundary for advisory CI report publication evidence.

**Architecture:** Add one Zig tool following the existing production telemetry application-boundary pattern. The tool parses one advisory CI report artifact, validates source reportability and disabled authority, supports `plan` and `record-applied`, renders deterministic JSON/text artifacts, and updates schema governance, backlog, roadmap, README, and operations docs.

**Tech Stack:** Zig 0.16.0, `std.json`, `std.crypto.hash.sha2.Sha256`, existing zigeffect build steps, Bun root verification.

---

## File Structure

- Create `packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary.zig`
  - CLI parsing, source report parsing, application checks, report-after
    safety, artifact rendering, file IO, and focused tests.
- Modify `packages/zigeffect/build.zig`
  - Add executable, build step, and test integration after the advisory CI
    report tool.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Add schema entry and update schema count from 67 to 68.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Mark report application boundary delivered and recommend the publication
    policy branch.
- Create `packages/zigeffect/docs/production-telemetry-ci-gate-advisory-ci-report-application-boundary.md`
  - Document command, source contract, modes, report safety, handoff, and
    verification.
- Modify `packages/zigeffect/README.md`
  - Add command example after advisory CI report.
- Modify `packages/zigeffect/docs/operations.md`
  - Add operations guidance and update current next branch.
- Modify `packages/zigeffect/docs/production-hardening-backlog.md`
  - Add delivered backlog item, dependency order item, and verification
    commands.
- Modify `packages/zigeffect/docs/schema-governance.md`
  - Add schema matrix prose.
- Modify `packages/zigeffect/docs/roadmap.md` and
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark the application boundary delivered and add the next branch.
- Update predecessor docs that currently point at this branch as current next.

## Task 1: Create Red Constants Test

**Files:**
- Create: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary.zig`

- [ ] **Step 1: Add the failing constants test**

Create the file with only this test:

```zig
const std = @import("std");

test "ci gate advisory CI report application boundary schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-application-boundary.v1", production_telemetry_ci_gate_advisory_ci_report_application_boundary_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_advisory_ci_report_application_boundary_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-advisory-ci-report-publication-policy", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy", next_branch_if_applied);
}
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary.zig
```

Expected: fail with an undeclared identifier for
`production_telemetry_ci_gate_advisory_ci_report_application_boundary_schema`.

## Task 2: Implement Constants And CLI Parsing

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary.zig`

- [ ] **Step 1: Add constants and enums**

Add constants:

```zig
pub const production_telemetry_ci_gate_advisory_ci_report_application_boundary_schema = "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-application-boundary.v1";
pub const production_telemetry_ci_gate_advisory_ci_report_application_boundary_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary";
pub const recommendation = "start-production-telemetry-ci-gate-advisory-ci-report-publication-policy";
pub const next_branch_if_applied = "codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy";

const source_report_schema = "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1";
const generated_by = "causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary";
```

Define `Mode = enum { plan, record_applied }`,
`ReportApplicationStatus = enum { planned, applied, blocked }`, and
`CheckStatus = enum { pass, fail, skipped }`.

- [ ] **Step 2: Add `Options` and parser**

Parse:

```sh
--from-report <advisory-ci-report.json> plan|record-applied --reason <reason>
```

Also parse `--by`, `--policy`, `--report-after`, `--publication-change`,
`--before`, `--after`, `--verified-command`, and `--out-prefix`.

Validate:

- source path ends with `.json`
- `--report-after` ends with `.txt`, `.md`, or `.json`
- `--reason` is present and non-empty

- [ ] **Step 3: Add CLI parsing tests**

Add tests for:

- plan mode default actor and policy
- record-applied with report-after, publication-change, before, after, and
  verified-command flags
- unknown mode returns `error.UnknownMode`
- invalid report-after path returns `error.InvalidReportAfterPath`

- [ ] **Step 4: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary.zig
```

Expected: constants and CLI parsing tests pass.

## Task 3: Evaluate Source Reports

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary.zig`

- [ ] **Step 1: Add source artifact structs**

Define structs for:

- `SourceCheck` with `name`, `status`, `detail`
- `PublicationChannel` with `id`, `allowed`, `executed_by_tool`, `detail`
- `SourceReportArtifact` with source schema, status, authority flags,
  publication channels, checks, blocked claims, required verification commands,
  generated metadata, and agent guidance
- `ApplicationCheck`
- `ApplicationResult`

- [ ] **Step 2: Add source checks**

Implement checks named exactly:

- `source-report-schema`
- `source-report-status`
- `source-publication-disabled`
- `source-authority-disabled`
- `source-publication-channels-carried`
- `source-checks-passed`
- `source-blocked-claims-carried`
- `source-verification-recorded`

- [ ] **Step 3: Add source evaluation tests**

Add sample JSON strings for:

- ready source report
- advisory source report
- blocked source report
- source report with `github_step_summary_write_enabled=true`

Assert plan mode returns planned for ready/advisory, blocked for blocked, and
blocked for enabled publication or authority.

## Task 4: Evaluate `record-applied`

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary.zig`

- [ ] **Step 1: Add report-after safety**

Add required markers:

```zig
const required_report_markers = &.{ "zigeffect", "causal", "advisory", "report" };
```

Add prohibited markers:

```zig
const prohibited_report_markers = &.{
    "required_status_check",
    "ci_gate_enabled=true",
    "ci_gate_enforcement_enabled=true",
    "ci_report_publication_enabled=true",
    "github_step_summary_write_enabled=true",
    "pull_request_comment_enabled=true",
    "ci_upload_execution_enabled=true",
    "production_telemetry_ingestion=true",
    "network_send_enabled=true",
    "durable_write_enabled=true",
    "nendb_write_enabled=true",
    "production_cluster_ready",
    "production_health_proven",
    "mutation_authority=granted",
    "secrets.",
    "PRODUCTION_TELEMETRY_TOKEN",
    "OTEL_EXPORTER_OTLP_ENDPOINT",
};
```

- [ ] **Step 2: Add record-applied checks**

Implement checks named exactly:

- `publication-change-present`
- `before-evidence-present`
- `after-evidence-present`
- `post-verification-recorded`
- `after-report-present`
- `after-report-safe`

Use `allChecksPassed` for record-applied. Emit:

- applied result when every check is pass
- blocked result otherwise

- [ ] **Step 3: Add record-applied tests**

Add tests for:

- missing publication-change blocks
- missing before evidence blocks
- missing after evidence blocks
- missing verified commands blocks
- unsafe report-after content blocks
- complete record-applied emits `applied=true` and
  `mutation_authority="record-only"`

## Task 5: Render Artifacts And File IO

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary.zig`

- [ ] **Step 1: Add output path replacement**

Implement default output replacement:

```text
*-ci-gate-advisory-ci-report.json
*-ci-gate-advisory-ci-report-application-boundary.json
```

Add a test for the replacement.

- [ ] **Step 2: Add JSON rendering**

Render fields:

```text
schema
schema_version
source_advisory_ci_report
source_report_status
mode
report_application_status
applied
mutation_authority
disabled authority flags
reviewed_by
policy
reason
report_after_path
after_report_digest
publication_changes
before_evidence
after_evidence
source_checks
application_checks
application_boundary_rules
denied_publication_claims
negative_fixtures
blocked_claims
required_verification_commands
verified_commands
generated_by
source_branch
recommendation
next_branch_if_applied
json_output
text_output
agent_guidance
```

- [ ] **Step 3: Add text rendering**

Render a concise report with source status, mode, application status,
`applied`, `mutation_authority`, checks, evidence lists, denied claims,
negative fixtures, and agent guidance.

- [ ] **Step 4: Add `main`, `run`, and file IO**

Read source report and optional report-after content with a 1 MiB bound. Write
JSON and text artifacts to the resolved output paths. Print the text report to
stderr/stdout consistently with sibling tools.

## Task 6: Add Build Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add module, executable, step, and test integration**

Add a build module for
`tools/causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary.zig`
immediately after the advisory CI report tool.

Build step:

```text
causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary
```

Executable:

```text
zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary
```

- [ ] **Step 2: Verify help**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary -- --help
```

Expected: usage mentions `--from-report`, `plan|record-applied`,
`--report-after`, and evidence flags.

## Task 7: Update Governance And Backlog

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Add schema governance entry**

Add schema
`zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-application-boundary.v1`
with category `production-hardening`, status `current`, emitted by
`causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary`,
and compatibility:

```text
strict-v1, record-only, report-application-boundary, plan-or-record-applied,
before-after-verification, local-artifact-only, cluster-release-gate-aware,
no-live-ingestion, no-network, no-durable-write, no-nendb-write,
no-ci-gate-enforcement, no-required-status-check, no-tool-workflow-mutation,
no-tool-ci-upload, no-tool-github-step-summary-write, no-tool-pr-comment
```

Update schema count from 67 to 68 and tests accordingly.

- [ ] **Step 2: Add backlog item**

Add delivered item `production-telemetry-ci-gate-advisory-ci-report-application-boundary`.

Set recommendation to:

```text
start-production-telemetry-ci-gate-advisory-ci-report-publication-policy
```

Set recommended next branch to:

```text
codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy
```

Add dependency order item after advisory CI report and update tests.

## Task 8: Update Docs

**Files:**
- Create: `packages/zigeffect/docs/production-telemetry-ci-gate-advisory-ci-report-application-boundary.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Modify predecessor docs that call this branch current next.

- [ ] **Step 1: Add the new guide**

Document command, source contract, modes, report safety, denied claims,
handoff, and verification.

- [ ] **Step 2: Update command catalogs**

Add the new command after the advisory CI report command in README and
operations.

- [ ] **Step 3: Update roadmap references**

Mark the application boundary delivered and set current next branch to
`codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy`.

## Task 9: Generate Artifacts And Verify

**Files:**
- Generated under `.zig-cache/causal-artifacts/` only.

- [ ] **Step 1: Generate plan artifact**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-advisory-ci-report.json \
  plan \
  --reason "CI advisory report application boundary planned"
```

Expected: text report shows `report_application_status: planned` and
`applied: false`.

- [ ] **Step 2: Generate negative artifact**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-negative.json \
  record-applied \
  --reason "negative CI advisory report application boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-application-boundary-negative
```

Expected: text report shows `report_application_status: blocked` and
`applied: false`.

- [ ] **Step 3: Generate applied fixture**

Run with explicit local report-after evidence:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-advisory-ci-report.json \
  record-applied \
  --reason "CI advisory report application boundary reviewed" \
  --report-after ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-application-boundary-after.txt \
  --publication-change "reviewed local advisory CI report publication procedure" \
  --before "advisory CI report local artifact existed before application" \
  --after "advisory CI report application boundary reviewed after publication" \
  --verified-command "zig build causal-production-telemetry-ci-gate-advisory-ci-report" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-application-boundary-applied
```

Expected: text report shows `report_application_status: applied`,
`applied: true`, and `mutation_authority: record-only`.

- [ ] **Step 4: Run full verification**

Run:

```sh
cd packages/zigeffect
zig fmt build.zig tools/causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary.zig tools/causal_production_hardening_backlog.zig tools/causal_schema_governance.zig
zig test tools/causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary.zig
zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: all commands exit 0.

## Self-Review Checklist

- Spec coverage: tasks cover CLI, source contract, modes, report safety,
  rendering, build wiring, schema governance, backlog, docs, artifact
  generation, and verification.
- Placeholder scan: no TBD, TODO, or unspecified implementation steps remain.
- Type consistency: branch, schema, command, mode, status, and field names are
  consistent across tasks.
