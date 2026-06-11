# Zigeffect Causal App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the report-consumption evaluation-report producer that consumes ready or advisory report-evaluator artifacts and emits local ready, advisory, or blocked report artifacts.

**Architecture:** Reuse the existing evaluator-to-report producer pattern from the consumption-report milestone. The new tool parses `consumption-report-evaluator.v1`, validates source readiness and authority boundaries, preserves source summaries/findings, and emits a local-only `consumption-report-evaluation-report.v1` artifact with an application-boundary handoff.

**Tech Stack:** Zig build tool, Zig std JSON parsing and IO, existing zigeffect causal governance/backlog docs, Bun workspace verification.

---

### Task 1: Red Build Target

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create later: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report.zig`

- [ ] **Step 1: Add the missing build target**

Add a build executable and test target named:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect
zig build test
```

Expected: fail because the new tool source file does not exist.

### Task 2: Producer Implementation

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add producer constants and tests**

The new tool must expose:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report.v1";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary";
```

- [ ] **Step 2: Implement CLI parsing**

Implement:

```text
--from-evaluator <consumption-report-evaluator.json> summarize --reason <reason>
```

with optional `--by`, `--policy`, and `--out-prefix`.

- [ ] **Step 3: Implement source evaluator validation**

Require schema v1, ready or advisory status, no blocked findings, source refs, source report application evidence, request summaries, signal summaries, denied claims, next queries, disabled authority, and SolidJS webui read-only posture.

- [ ] **Step 4: Implement JSON and text formatting**

Emit source refs, source request/evidence summaries, source signals, blocked/advisory findings, report checks, publication channels, denied claims, next queries, required verification commands, and agent guidance.

- [ ] **Step 5: Run green test**

Run:

```bash
cd packages/zigeffect
zig build test
```

Expected: new producer tests and existing tests pass.

### Task 3: Governance, Backlog, Roadmap, And Docs

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report.md`
- Regenerate: `packages/zigeffect/docs/schema-governance.md`
- Regenerate: `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Add schema governance entry**

Add:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report.v1
```

- [ ] **Step 2: Update backlog**

Mark evaluation-report delivered and update recommended next branch:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary
```

- [ ] **Step 3: Update roadmap**

Mark item 66 delivered and add item 67 for the evaluation-report application-boundary branch.

- [ ] **Step 4: Add package docs**

Document command usage, source gates, statuses, denied boundaries, and next handoff.

- [ ] **Step 5: Regenerate generated docs**

Run:

```bash
cd packages/zigeffect
zig build causal-schema-governance -- --format text 2> docs/schema-governance.md
zig build causal-production-hardening-backlog -- --format text 2> docs/production-hardening-backlog.md
```

### Task 4: Artifact Generation And Verification

**Files:**
- Generate local artifacts under `.zig-cache/causal-artifacts/`

- [ ] **Step 1: Generate ready, advisory, and blocked evaluation-report artifacts**

Use the ready, advisory, and blocked report-evaluator artifacts from the previous milestone.

- [ ] **Step 2: Run focused verification**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
```

- [ ] **Step 3: Run repository verification**

Run:

```bash
bun run check
bun run zig:test
git diff --check
```

- [ ] **Step 4: Commit and branch**

Commit:

```bash
git add docs packages
git commit -m "feat(zigeffect): add app-facing advisory report consumption evaluation report"
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary
```
