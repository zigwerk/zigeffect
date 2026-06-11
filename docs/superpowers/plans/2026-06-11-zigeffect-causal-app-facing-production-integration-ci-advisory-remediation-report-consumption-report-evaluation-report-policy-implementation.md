# Zigeffect Causal App-Facing Advisory Remediation Report Consumption Report Evaluation Report Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a record-only policy producer that consumes applied consumption-report evaluation-report application-boundary artifacts and emits approve/reject policy evidence for the next evaluator branch.

**Architecture:** Follow the existing `causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy.zig` shape. Add one new Zig tool, wire it into `packages/zigeffect/build.zig`, register the schema and backlog item, refresh generated docs, and update the master roadmap.

**Tech Stack:** Zig build tools, Zig standard library JSON parsing/formatting, repo-local generated Markdown artifacts, Bun verification wrappers.

---

### Task 1: Add The Policy Tool Skeleton And Red Checks

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Copy the closest policy producer**

Run:

```bash
cp packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy.zig \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy.zig
```

Expected: a new tool file exists but still has the old schema and names.

- [ ] **Step 2: Wire a temporary build target and test target**

Add a build module, executable, run step, and test dependency named:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy
```

Expected: the tool target compiles only after the new file has valid names and tests.

- [ ] **Step 3: Run the new target before implementation**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy -- --help
```

Expected: fail or show stale old usage before renaming, proving the branch needs implementation.

### Task 2: Implement Evaluation-Report Policy Semantics

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy.zig`

- [ ] **Step 1: Rename constants and CLI contract**

Set:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.v1";
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator";
```

Source schema:

```zig
const source_boundary_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.v1";
```

Expected: `--help` names the evaluation-report policy command and `--from-application`.

- [ ] **Step 2: Adapt source artifact fields**

Keep the existing source struct pattern, but require the evaluation-report application-boundary fields:

```zig
source_evaluation_report
source_evaluation_report_schema
source_evaluation_report_status
source_ready_for_next_branch
source_report_policy_status
source_report_application_status
source_consumption_report_status
source_report_after_digest
report_after_digest
report_application_changes
before_evidence
after_evidence
application_checks
source_checks
source_publication_channels
denied_application_claims
required_verification_commands
verified_commands
```

Expected: approval fails unless the source artifact is applied, ready, record-only, and fully evidenced.

- [ ] **Step 3: Define policy catalogs**

Update interpretation rules, consumption scopes, denied inference rules, and negative fixtures to mention evaluation-report evidence rather than the older consumption-report application.

Expected: generated JSON includes policy catalogs that explicitly deny CI enforcement, app mutation, app runtime integration, NenDB writes, NenDB adapter execution, Cockroach scope, public upload, hosted dashboards, alternate renderers, auto-apply, and mutation authority.

- [ ] **Step 4: Preserve approve/reject behavior**

Approval is ready only when all source and verification checks pass. Rejection always emits blocked policy evidence.

Expected: tests cover approve-ready, reject-blocked, stale source denied, authority drift denied, and missing verification denied.

### Task 3: Add Documentation And Governance

**Files:**
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.md`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add package documentation**

Document CLI usage, ready gates, denied claims, and next branch handoff.

Expected: documentation matches the implemented command and schema exactly.

- [ ] **Step 2: Register schema governance**

Add the new schema:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.v1
```

Increment the schema count by one and add text/json test expectations.

Expected: `zig build causal-schema-governance -- --format json` reports the incremented schema count.

- [ ] **Step 3: Add hardening backlog item**

Mark the new policy item delivered and update the recommended next branch to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator
```

Expected: backlog JSON includes the delivered policy item and verification command examples.

- [ ] **Step 4: Update the master roadmap**

Mark item 68 delivered and add item 69 as the evaluator branch.

Expected: roadmap preserves the long-running sequence and the no-Cockroach/NenDB-adapter-only constraint.

### Task 4: Generate Artifacts And Verify

**Files:**
- Modify generated docs:
  - `packages/zigeffect/docs/schema-governance.md`
  - `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Run the new CLI help**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy -- --help
```

Expected: usage prints successfully.

- [ ] **Step 2: Produce approve and reject fixtures**

Run approve against the applied evaluation-report application-boundary artifact with all required verification commands. Run reject against the same source with an `--out-prefix` for a negative fixture.

Expected: approve artifact has `ready_for_next_branch=true`; reject artifact has `ready_for_next_branch=false`.

- [ ] **Step 3: Refresh generated docs**

Run:

```bash
cd packages/zigeffect
zig build causal-schema-governance > docs/schema-governance.md
zig build causal-production-hardening-backlog > docs/production-hardening-backlog.md
```

Expected: generated docs mention the new policy schema and evaluator handoff.

- [ ] **Step 4: Run verification**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
git diff --cached --check
```

Expected: every command exits 0 before commit.

### Task 5: Commit And Advance

**Files:** staged milestone files only.

- [ ] **Step 1: Stage intended files**

Stage the new spec, plan, policy tool, package doc, build file, governance, backlog, generated docs, and roadmap.

Expected: `git diff --cached --stat` shows only policy milestone files.

- [ ] **Step 2: Commit**

Run:

```bash
git commit -m "feat(zigeffect): add app-facing evaluation report policy"
```

Expected: commit succeeds.

- [ ] **Step 3: Create the next branch**

Run:

```bash
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator
```

Expected: work can continue on the next evaluator milestone.
