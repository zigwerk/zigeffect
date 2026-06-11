# ZigEffect App-Facing Consumption Report Evaluation Report Evaluator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the read-only evaluator that consumes evaluation-report policy artifacts and classifies explicit local request/evidence files for the next app-facing handoff.

**Architecture:** Reuse the existing consumption-report evaluator shape, but shift the source contract to `consumption-report-evaluation-report-policy.v1`. The tool remains a local JSON/text producer with bounded file analysis and no mutation authority.

**Tech Stack:** Zig tool under `packages/zigeffect/tools`, Zig build step, schema governance/backlog generators, markdown docs.

---

### Task 1: Failing Evaluator Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator.zig`

- [ ] **Step 1: Write the failing test**

Create a new Zig tool file with tests for the schema constants and option parsing. The tests should expect:

```zig
"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator.v1"
"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator"
"start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report"
"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator.zig
```

Expected: FAIL because the implementation is still missing.

### Task 2: Implement Evaluator Producer

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator.zig`

- [ ] **Step 1: Add constants and command parser**

Implement constants, source policy schema, output suffixes, required verification commands, advisory authority flags, `Options`, `parseOptions`, path validation, and output path helpers.

- [ ] **Step 2: Add source policy model**

Model the source policy fields emitted by `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy`, including application evidence, source report evidence, request/support summaries, findings, policy checks, interpretation rules, scopes, denied claims, negative fixtures, verification commands, and authority flags.

- [ ] **Step 3: Add file analysis**

Implement bounded file reads, SHA-256 digests, JSON schema detection, file classification, role detection, redaction posture, denied content checks, and helper functions for request/evidence safety.

- [ ] **Step 4: Add evaluation logic**

Evaluate source schema/status/decision/readiness, source refs, source evidence, source checks, catalogs, disabled authority, SolidJS webui posture, request presence, support evidence, denied claims, and redaction posture.

- [ ] **Step 5: Add JSON/text reports**

Emit source refs, source evidence summaries, request/evidence file analysis, checks, signal evaluations, findings, denied claims, next queries, required verification commands, local output paths, and agent guidance.

- [ ] **Step 6: Run tests to verify green**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator.zig
```

Expected: PASS.

### Task 3: Register Build Target and Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator.md`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add build target**

Add executable and test registration for:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator
```

- [ ] **Step 2: Add docs**

Document the command, source gate, input gate, statuses, and next handoff.

- [ ] **Step 3: Add schema governance entry**

Register the evaluator schema with strict v1, advisory-only, approved evaluation-report policy source, bounded explicit evidence, no Cockroach, no mutation, and SolidJS/webui compatibility tags.

- [ ] **Step 4: Add backlog/roadmap entry**

Mark the evaluator delivered, add evidence sources, include verification commands, and update the recommended next branch to the next evaluation-report handoff.

### Task 4: Generate Artifacts and Verify

**Files:**
- Modify generated docs:
  - `packages/zigeffect/docs/schema-governance.md`
  - `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Generate a ready evaluator artifact**

Run the evaluator against the ready policy artifact with a request and support evidence file.

- [ ] **Step 2: Generate advisory/blocked fixtures**

Run missing-support and blocked-source/unsafe-request paths with explicit `--out-prefix` values.

- [ ] **Step 3: Refresh generated docs**

Run schema governance and production hardening backlog JSON/text generators.

- [ ] **Step 4: Full verification**

Run the focused Zig test, build-step help, schema/backlog generators, examples, zigeffect tests, repo checks, and `git diff --check`.

- [ ] **Step 5: Commit**

Stage and commit with:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing evaluation report evaluator"
```
