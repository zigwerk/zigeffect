# Zigeffect Causal App-Facing Evaluation Report Application Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the guarded application-boundary tool for app-facing advisory remediation report consumption-report evaluation reports.

**Architecture:** Reuse the existing consumption-report application-boundary shape, swapping the source artifact to the evaluation-report schema and renaming application evidence to evaluation-report application evidence. The tool remains local and record-only: `plan` records intent, while `record-applied` only sets `applied=true` after source gates, before/after evidence, safe after-report content, and verification commands pass.

**Tech Stack:** Zig build tool, Zig JSON parsing/formatting, existing zigeffect causal artifact conventions, Bun for root verification.

---

### Task 1: Add Build Target And Red Test

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Expected missing source: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary.zig`

- [ ] **Step 1: Add build wiring**

Add a build executable and test target named:

```zig
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary
```

The source path must be:

```text
tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary.zig
```

- [ ] **Step 2: Run red test**

Run:

```bash
cd packages/zigeffect
zig build test
```

Expected: fail because the new tool source file does not exist.

### Task 2: Implement Boundary Tool

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary.zig`

- [ ] **Step 1: Start from the established boundary pattern**

Copy the structure of:

```text
packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary.zig
```

Rename constants to:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.v1";
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy";
pub const next_branch_if_applied = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy";
const source_report_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report.v1";
const generated_by = "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary";
```

- [ ] **Step 2: Rename input options**

Use:

```zig
report_path: []const u8,
mode: Mode,
evaluation_report_after_path: ?[]const u8 = null,
evaluation_report_application_changes: []const []const u8 = &.{},
before_evidence: []const []const u8 = &.{},
after_evidence: []const []const u8 = &.{},
verified_commands: []const []const u8 = &.{},
```

The CLI flags must be:

```text
--from-report
plan|record-applied
--evaluation-report-after
--evaluation-report-application-change
--before
--after
--verified-command
```

- [ ] **Step 3: Parse source evaluation-report fields**

The source struct must include:

```zig
source_consumption_report_evaluator: []const u8 = "",
source_evaluator_status: []const u8 = "",
source_report_policy: []const u8 = "",
source_report_policy_status: []const u8 = "",
source_report_application_boundary: []const u8 = "",
source_report_application_status: []const u8 = "",
source_consumption_report: []const u8 = "",
source_consumption_report_status: []const u8 = "",
consumption_report_evaluation_report_status: []const u8,
ready_for_next_branch: bool,
blocked_findings_count: usize = 0,
advisory_findings_count: usize = 0,
mutation_authority: []const u8 = "",
request_summary: []const SourceFile = &.{},
support_evidence_summary: []const SourceFile = &.{},
checks: []const SourceCheck = &.{},
blocked_findings: []const SourceFinding = &.{},
advisory_findings: []const SourceFinding = &.{},
publication_channels: []const SourcePublicationChannel = &.{},
required_verification_commands: []const []const u8 = &.{},
```

- [ ] **Step 4: Implement gates**

Source gate:

```zig
source.ready_for_next_branch
source.blocked_findings_count == 0
status is "ready" or "advisory"
source.mutation_authority == "none"
authority booleans are disabled
SolidJS webui read-only fields are correct
source refs, summaries, checks, local publication channels, and verification contract are present
```

Application gate:

```zig
plan -> applied=false, ready_for_next_branch=false
record-applied -> all source checks pass plus application change, before, after, after-report present, after-report safe, and all required verification commands present
```

- [ ] **Step 5: Add tests**

Add tests for:

```text
constants are stable
CLI parses plan and record-applied options
default output path replaces evaluation-report suffix
plan mode records planned state without applied authority
record-applied complete evidence produces applied boundary
record-applied missing evidence stays blocked
unsafe after-report blocks applied boundary
blocked source report blocks application
source authority drift blocks application
```

- [ ] **Step 6: Run green test**

Run:

```bash
cd packages/zigeffect
zig build test
```

Expected: pass.

### Task 3: Register Schema, Backlog, Roadmap, And Docs

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.md`

- [ ] **Step 1: Add schema governance entry**

Add schema:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.v1
```

Increment schema count from `102` to `103` and add tests for text and JSON reports.

- [ ] **Step 2: Add backlog item**

Update recommendation to:

```text
start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy
```

Update next branch to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy
```

Add a delivered backlog item and dependency-order entry for the new application boundary.

- [ ] **Step 3: Add verification commands**

Add commands for help, plan, record-applied, and blocked source generation, plus existing schema/backlog/examples/test checks.

- [ ] **Step 4: Add roadmap entry**

Mark item 67 delivered and add item 68 as the next evaluation-report policy branch.

- [ ] **Step 5: Add package doc**

Document command shape, source gate, application gate, statuses, and handoff branch.

### Task 4: Regenerate Artifacts And Verify

**Files:**
- Modify generated docs: `packages/zigeffect/docs/schema-governance.md`
- Modify generated docs: `packages/zigeffect/docs/production-hardening-backlog.md`
- Generate local `.zig-cache/causal-artifacts/*evaluation-report-application-boundary*.json`

- [ ] **Step 1: Regenerate docs**

Run:

```bash
cd packages/zigeffect
zig build causal-schema-governance -- --format text 2> docs/schema-governance.md
zig build causal-production-hardening-backlog -- --format text 2> docs/production-hardening-backlog.md
```

- [ ] **Step 2: Generate boundary artifacts**

Run help, plan, record-applied, and blocked-source commands from the backlog.

- [ ] **Step 3: Run full verification**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary -- --help
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

Expected: every command exits 0.

### Task 5: Commit And Advance Branch

**Files:**
- All files from Tasks 1-4

- [ ] **Step 1: Stage milestone**

Run:

```bash
git add docs/superpowers packages/zigeffect
git diff --cached --check
```

- [ ] **Step 2: Commit**

Run:

```bash
git commit -m "feat(zigeffect): add app-facing evaluation report application boundary"
```

- [ ] **Step 3: Create next branch**

Run:

```bash
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy
```
