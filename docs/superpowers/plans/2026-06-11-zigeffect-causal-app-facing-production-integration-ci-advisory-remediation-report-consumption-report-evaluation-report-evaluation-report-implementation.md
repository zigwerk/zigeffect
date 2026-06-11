# ZigEffect App-Facing Consumption Report Evaluation Report Evaluation Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the read-only report producer that consumes consumption-report evaluation-report evaluator artifacts and summarizes them for the next guarded application-boundary step.

**Architecture:** Reuse the existing consumption-report evaluation-report producer shape, but shift the source contract to `consumption-report-evaluation-report-evaluator.v1` and preserve both immediate evaluation-report evidence and inherited consumption-report evidence. The tool remains local JSON/text only and carries no mutation authority.

**Tech Stack:** Zig tool under `packages/zigeffect/tools`, Zig build step, schema governance/backlog generators, markdown docs.

---

### Task 1: Failing Report Producer Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report.zig`

- [ ] **Step 1: Write the failing constants test**

Create a new Zig tool file with a constants test that expects:

```zig
"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report.v1"
"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report"
"start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary"
"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report.zig
```

Expected: FAIL because `schema`, `source_branch`, `recommendation`, and `next_branch_if_ready` are not implemented yet.

### Task 2: Implement Report Producer

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report.zig`

- [ ] **Step 1: Add constants and command parser**

Implement constants, source evaluator schema, evaluator suffix, output suffix, required verification commands, advisory authority flags, `Options`, `parseOptions`, `outputPathsForOptions`, and `usage`.

- [ ] **Step 2: Add source evaluator model**

Model fields emitted by `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator`, including source policy refs, evaluation-report application refs, inherited consumption-report refs, before/after evidence, request/support/signal summaries, findings, denied claims, next queries, agent guidance, and authority flags.

- [ ] **Step 3: Add source checks**

Implement checks for source schema, reportable status, ready handoff, no blocked findings, policy/application refs, application evidence, request/evidence summaries, report sections, disabled authority, SolidJS webui posture, and local-only publication.

- [ ] **Step 4: Add JSON/text reports**

Emit schema metadata, source refs, source evidence arrays, request/support/signal summaries, blocked/advisory findings, report checks, policy rule ids, consumption scope ids, denied claims, next queries, publication channels, verification commands, output paths, and agent guidance.

- [ ] **Step 5: Add ready/advisory/blocked tests**

Add tests for ready evaluator output, advisory evaluator output, blocked evaluator output, authority drift blocking, publication local-only posture, default output path handling, and option parsing.

- [ ] **Step 6: Run tests to verify green**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report.zig
```

Expected: PASS.

### Task 3: Register Build Target and Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report.md`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add build target**

Add executable and test registration for:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report
```

- [ ] **Step 2: Add docs**

Document the command, source gate, statuses, local-only publication posture, and next handoff.

- [ ] **Step 3: Add schema governance entry**

Register the new schema with strict v1, advisory-only, source evaluation-report evaluator compatibility, local-report-only, bounded explicit evidence, no Cockroach, no CI enforcement, no app runtime integration, no storage writes, no adapter execution, no public upload, no auto-apply, no mutation authority, and SolidJS/webui compatibility tags.

- [ ] **Step 4: Add backlog and roadmap updates**

Mark the report producer delivered, move the recommended next branch to the new application-boundary branch, add verification commands for ready/advisory/blocked report runs, and mark roadmap item 70 delivered with item 71 as the next application-boundary.

### Task 4: Generate Artifacts and Verify

**Files:**
- Modify generated docs:
  - `packages/zigeffect/docs/schema-governance.md`
  - `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Generate ready/advisory/blocked report artifacts**

Run the report producer against:

```text
../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator.json
../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator-advisory.json
../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator-blocked.json
```

- [ ] **Step 2: Refresh generated docs**

Run:

```bash
cd packages/zigeffect
zig build causal-schema-governance 2> docs/schema-governance.md
zig build causal-production-hardening-backlog 2> docs/production-hardening-backlog.md
```

- [ ] **Step 3: Full verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

- [ ] **Step 4: Commit**

Stage and commit with:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing evaluation report evaluation report"
```
