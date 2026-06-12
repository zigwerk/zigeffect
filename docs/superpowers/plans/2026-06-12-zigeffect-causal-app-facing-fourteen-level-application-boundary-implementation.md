# zigeffect causal app-facing fourteen-level application boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the local-only, guarded application-boundary artifact for the fourteen-level app-facing report and hand off to the fourteen-level policy branch.

**Architecture:** Promote the thirteen-level application-boundary tool into a fourteen-level boundary that consumes the fourteen-level report, adds direct fourteen-level source fields, preserves thirteen/twelve/lower lineage, and keeps mutation authority disabled. The build, governance registry, hardening backlog, docs, fixture, and master roadmap are updated in the same milestone so agents can discover the new contract.

**Tech Stack:** Zig build tools and tests, local JSON/text causal artifacts, Bun root verification, SolidJS/webui read-only evidence contract.

---

### Task 1: Branch and Checkpoint Verification

**Files:**
- Inspect: `.git` state only

- [ ] **Step 1: Confirm active branch**

Run: `git branch --show-current`
Expected: `codex/zigeffect-causal-app-facing-fourteen-level-application-boundary`

- [ ] **Step 2: Confirm local master includes the current checkpoint**

Run: `git rev-parse master`
Expected: the same hash as `git rev-parse codex/zigeffect-causal-app-facing-fourteen-level-application-boundary` before new implementation work begins.

### Task 2: RED Boundary Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_fourteen_level_application_boundary.zig`

- [ ] **Step 1: Write the failing constants test**

```zig
const std = @import("std");

test "app-facing fourteen-level application boundary constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-fourteen-level-application-boundary", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-fourteen-level-policy", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-fourteen-level-policy", next_branch_if_applied);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/zigeffect && zig test tools/causal_app_facing_fourteen_level_application_boundary.zig`
Expected: compile failure for undeclared `schema`.

### Task 3: Boundary Tool Implementation

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_fourteen_level_application_boundary.zig`

- [ ] **Step 1: Promote the thirteen-level implementation**

Use `packages/zigeffect/tools/causal_app_facing_thirteen_level_application_boundary.zig` as the implementation source and update all public constants, defaults, usage text, source report schema, source report suffix, output prefix, generated_by, branch, recommendation, required verification command, and test names from thirteen-level to fourteen-level.

- [ ] **Step 2: Add direct fourteen-level source fields**

The JSON output must emit:

```json
"source_fourteen_level_report": "<input report path>",
"source_fourteen_level_report_schema": "<source schema>",
"source_fourteen_level_report_status": "<source fourteen status>"
```

It must preserve direct `source_thirteen_level_evaluator`, `source_thirteen_level_policy`, `source_thirteen_level_application_boundary`, `source_thirteen_level_report`, `source_twelve_level_evaluator`, and lower lineage fields from the source report.

- [ ] **Step 3: Update source status parsing**

The source status field in `SourceReportArtifact` must be:

```zig
consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status: []const u8,
```

All readiness checks, text rendering, and direct source status output must read that field.

- [ ] **Step 4: Keep authority gates unchanged**

The promoted tool must still reject CI enforcement, required status checks, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live agent projection, raw payload capture, deployment mutation, durable writes, NenDB writes, NenDB adapter execution, public upload, hosted dashboard, React renderer drift, Cockroach scope, and auto-apply claims.

### Task 4: Docs and Fixture

**Files:**
- Create: `packages/zigeffect/docs/app-facing-fourteen-level-application-boundary.md`
- Create: `packages/zigeffect/test/fixtures/app-facing-fourteen-level-application-boundary-after-safe.txt`

- [ ] **Step 1: Add docs**

Document the consumed fourteen-level report schema, emitted fourteen-level application-boundary schema, aliases, plan usage, record-applied usage, blocked source probe usage, gates, non-authority claims, and handoff to `codex/zigeffect-causal-app-facing-fourteen-level-policy`.

- [ ] **Step 2: Add safe after-report fixture**

The fixture text must include the required safety markers: `zigeffect`, `causal`, `read-only`, `consumption`, `evaluation-report`, `evaluation report`, and `application`. It must not include any prohibited authority marker.

### Task 5: Build, Governance, Backlog, Roadmap

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Wire build executable and test**

Add executable `zigeffect-causal-app-facing-fourteen-level-application-boundary`, build step `causal-app-facing-fourteen-level-application-boundary`, and include the new Zig file in the zigeffect test step.

- [ ] **Step 2: Register schema governance**

Add the fourteen-level application-boundary schema entry with `record-only`, `advisory-only`, `application-boundary`, `source-fourteen-level-report`, `guarded-record-applied`, `local-report-only`, `read-only-consumption`, `bounded-agent-context`, `solid-webui`, `webui-dev/zig-webui`, `no-cockroach`, `no-ci-enforcement`, `no-app-runtime-integration`, `no-nendb-write`, `no-nendb-adapter-execution`, `no-public-artifact-upload`, `no-hosted-live-dashboard`, `no-auto-apply`, and `no-mutation-authority` compatibility markers.

- [ ] **Step 3: Update hardening backlog**

Mark `app-facing-fourteen-level-application-boundary` delivered, update recommendation to `start-app-facing-fourteen-level-policy`, update recommended branch to `codex/zigeffect-causal-app-facing-fourteen-level-policy`, and add plan/applied/blocked generation commands.

- [ ] **Step 4: Update master roadmap**

Mark the fourteen-level application-boundary item delivered and add the next branch item for `codex/zigeffect-causal-app-facing-fourteen-level-policy`.

### Task 6: Artifact Generation and Verification

**Files:**
- Generate: `.zig-cache/causal-artifacts/app-facing-ci-fourteen-level-application-boundary-plan.json`
- Generate: `.zig-cache/causal-artifacts/app-facing-ci-fourteen-level-application-boundary.json`
- Generate: `.zig-cache/causal-artifacts/app-facing-ci-fourteen-level-application-boundary-blocked.json`

- [ ] **Step 1: Generate plan artifact**

Run: `cd packages/zigeffect && zig build causal-app-facing-fourteen-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-fourteen-level-report.json plan --reason "planned app-facing fourteen-level application boundary" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-fourteen-level-application-boundary-plan`
Expected: `applied=false`, `ready_for_next_branch=false`, `mutation_authority=none`.

- [ ] **Step 2: Generate applied artifact**

Run: `cd packages/zigeffect && zig build causal-app-facing-fourteen-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-fourteen-level-report.json record-applied --reason "reviewed app-facing fourteen-level application boundary" --after-report test/fixtures/app-facing-fourteen-level-application-boundary-after-safe.txt --application-change "reviewed local fourteen-level application boundary for agents reviewers CI advisory readers and SolidJS webui" --before "before local fourteen-level application boundary evidence" --after "after local fourteen-level application boundary evidence" --verified-command "bun run zigeffect:workbench:typecheck" --verified-command "bun run zigeffect:workbench:test" --verified-command "zig build causal-app-facing-fourteen-level-report -- --help" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-fourteen-level-application-boundary`
Expected: `applied=true`, `ready_for_next_branch=true`, `mutation_authority=record-only`, next branch `codex/zigeffect-causal-app-facing-fourteen-level-policy`.

- [ ] **Step 3: Generate blocked source artifact**

Run the same `record-applied` command with `--from-report ../../.zig-cache/causal-artifacts/app-facing-ci-fourteen-level-report-blocked.json` and `--out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-fourteen-level-application-boundary-blocked`.
Expected: blocked status, `applied=false`, `ready_for_next_branch=false`.

- [ ] **Step 4: Run verification**

Run the verification list from `docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-fourteen-level-application-boundary-design.md`.
Expected: every command exits 0.

### Task 7: Commit, Master Checkpoint, Next Branch

**Files:**
- Commit all files changed by this milestone.

- [ ] **Step 1: Commit**

Run: `git add docs/superpowers packages/zigeffect && git commit -m "feat(zigeffect): add app-facing fourteen-level application boundary"`
Expected: commit succeeds on `codex/zigeffect-causal-app-facing-fourteen-level-application-boundary`.

- [ ] **Step 2: Fast-forward master**

Run from the master worktree: `git merge --ff-only codex/zigeffect-causal-app-facing-fourteen-level-application-boundary`
Expected: local `master` points at the milestone commit.

- [ ] **Step 3: Create next branch**

Run: `git switch -c codex/zigeffect-causal-app-facing-fourteen-level-policy`
Expected: active worktree is ready for the next sequential milestone.
