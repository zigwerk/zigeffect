# Zigeffect Causal App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the report-consumption report evaluator that consumes ready report-policy artifacts plus explicit local request/evidence files and emits ready, advisory, or blocked read-only evaluator artifacts.

**Architecture:** Follow the existing consumption evaluator pattern as a sibling producer. Keep parsing, classification, source policy checks, JSON/text formatting, build wiring, schema governance, backlog, and roadmap updates in the same local-tool style used by the previous milestones.

**Tech Stack:** Zig build tool, Zig std JSON parsing and IO, Bun workspace verification, existing zigeffect causal docs and governance tools.

---

### Task 1: Red Tests For Evaluator Contract

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluator.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add failing schema, option, classifier, ready/advisory/blocked, and invalid-source tests**

Create the new evaluator file with tests matching these expected behaviors:

```zig
test "app-facing advisory remediation report consumption report evaluator schema and branch constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator.v1",
        schema,
    );
}
```

Add tests for:

- Parsing `--from-policy <report-policy.json> evaluate --reason <reason> --request ... --evidence ...`.
- Default output suffix replacement from `-ci-advisory-remediation-report-consumption-report-policy.json` to `-ci-advisory-remediation-report-consumption-report-evaluator`.
- File classification for bounded request JSON, request text, report-policy JSON, causal JSON, workbench text, and denied outside paths.
- Ready output when source policy is approved and support evidence is present.
- Advisory output when support evidence is missing.
- Blocked output when request content enables app runtime integration.
- Blocked output when source policy is rejected.

- [ ] **Step 2: Wire a temporary build test target and verify red**

Run:

```bash
cd packages/zigeffect
zig build test
```

Expected: fails until the evaluator implementation and build wiring are complete.

### Task 2: Evaluator Implementation

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluator.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Implement CLI parsing and output paths**

Implement:

```text
--from-policy <consumption-report-policy.json> evaluate --reason <reason> --request <path>... [--evidence <path>]...
```

Use bounded `.json` and `.txt` inputs only.

- [ ] **Step 2: Implement source policy validation**

Parse `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy.v1` and require ready/approve/non-mutating status, source refs, source evidence, policy catalogs, verification evidence, disabled authority, and SolidJS webui read-only posture.

- [ ] **Step 3: Implement request/evidence classification**

Classify bounded request, policy, causal, and workbench files. Block secret-shaped inputs, raw capture, authority drift, Cockroach scope, React renderer scope, deployment/production-health claims, public upload, auto-apply, NenDB writes, and NenDB adapter execution.

- [ ] **Step 4: Implement JSON/text reports**

Emit schema, status, source policy summary, request/evidence summaries, checks, signal evaluations, findings, denied claims, next queries, required verification commands, output paths, and agent guidance.

- [ ] **Step 5: Wire build step**

Add:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator
```

and attach its tests to `zig build test`.

- [ ] **Step 6: Verify green**

Run:

```bash
cd packages/zigeffect
zig build test
```

Expected: evaluator tests pass with the existing suite.

### Task 3: Governance, Backlog, Roadmap, And Docs

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator.md`
- Regenerate: `packages/zigeffect/docs/schema-governance.md`
- Regenerate: `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Add schema governance entry**

Add schema:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator.v1
```

Set category `app-runtime`, status `current`, emitted_by the new tool, and consumed_by agents, reviewers, non-blocking CI advisory readers, local SolidJS workbench, production-hardening backlog, and the future evaluation-report branch.

- [ ] **Step 2: Update backlog**

Mark the report-evaluator item delivered, add the next evaluation-report item, update dependency order, and update recommended next branch:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report
```

- [ ] **Step 3: Update roadmap**

Mark roadmap item 65 delivered and add item 66 for the evaluation-report handoff.

- [ ] **Step 4: Add package docs**

Document command usage, source gates, statuses, denied boundaries, and handoff branch.

- [ ] **Step 5: Regenerate generated docs**

Run:

```bash
cd packages/zigeffect
zig build causal-schema-governance -- --format text 2> docs/schema-governance.md
zig build causal-production-hardening-backlog -- --format text 2> docs/production-hardening-backlog.md
```

### Task 4: Artifact Generation And Final Verification

**Files:**
- Generate local artifacts under `.zig-cache/causal-artifacts/`

- [ ] **Step 1: Generate ready, advisory, and blocked evaluator artifacts**

Use the ready, negative, and blocked report-policy artifacts already produced by the previous milestone plus bounded request/evidence fixtures.

- [ ] **Step 2: Run focused verification**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator -- --help
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
git commit -m "feat(zigeffect): add app-facing advisory report consumption report evaluator"
git branch codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report
```
