# Production Telemetry CI Gate Required Status Check Enforcement Application Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary`, a record-only plan-or-record-applied boundary for externally reviewed active required-status-check enforcement evidence.

**Architecture:** Add one Zig application-boundary tool following the existing production telemetry plan-or-record-applied pattern. The tool parses a ready required-status-check enforcement-readiness artifact, supports `plan` and `record-applied`, validates external active-enforcement evidence before setting `applied=true`, renders deterministic JSON/text reports, and updates build wiring, schema governance, backlog, roadmap, README, and operations docs. It never mutates GitHub, workflows, branch protection, CI, telemetry, storage, or runtime state.

**Tech Stack:** Zig 0.16.0, `std.json`, existing zigeffect build steps, Bun root verification.

---

## File Structure

- Create `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary.zig`
  - CLI parsing, source enforcement-readiness parsing, source checks, plan/record-applied evaluation, evidence safety checks, deterministic JSON/text rendering, file IO, and focused tests.
- Modify `packages/zigeffect/build.zig`
  - Add module, executable, build step, and test integration after the required-status-check enforcement-readiness tool.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Add the new schema entry and update schema count from `73` to `74`.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Mark required-status-check enforcement application-boundary delivered and recommend the future enforcement policy branch.
- Create `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.md`
  - Document command, modes, source readiness contract, evidence gates, denied inferences, handoff, and verification.
- Modify `packages/zigeffect/README.md`
  - Add command example after enforcement-readiness.
- Modify `packages/zigeffect/docs/operations.md`
  - Add operations guidance and update current next branch.
- Modify `packages/zigeffect/docs/production-hardening-backlog.md`
  - Add delivered backlog item, dependency order item, and verification commands.
- Modify `packages/zigeffect/docs/schema-governance.md`
  - Add schema matrix prose and schema count.
- Modify `packages/zigeffect/docs/roadmap.md` and `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark this milestone delivered and add the enforcement policy handoff.
- Update adjacent current-next docs that currently name this branch.

## Task 1: Create Red Constants Test

**Files:**
- Create: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary.zig`

- [ ] **Step 1: Write the failing constants test**

Create the file with this initial content:

```zig
const std = @import("std");

test "ci gate required status check enforcement application boundary schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1", production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-required-status-check-enforcement-policy", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy", next_branch_if_ready);
}
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary.zig
```

Expected: fail with an undeclared identifier for `production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_schema`.

- [ ] **Step 3: Do not commit the red state**

Continue to Task 2 before committing.

## Task 2: Implement Constants, Modes, Options, Parser, And Output Paths

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary.zig`

- [ ] **Step 1: Add constants and enums**

Add:

```zig
pub const production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1";
pub const production_telemetry_ci_gate_required_status_check_enforcement_application_boundary_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary";
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-enforcement-policy";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy";

const source_readiness_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-readiness.v1";
const generated_by = "causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary";
```

Add:

```zig
const Mode = enum { plan, record_applied };
const ApplicationStatus = enum { planned, applied, blocked };
const CheckStatus = enum { pass, fail, skipped };
```

- [ ] **Step 2: Add `Options`**

Add:

```zig
const Options = struct {
    readiness_path: []const u8,
    mode: Mode,
    reviewed_by: []const u8 = "ci-gate-required-status-check-enforcement-application-boundary-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary",
    reason: []const u8,
    required_check_names: []const []const u8 = &.{},
    branch_protection_before: []const []const u8 = &.{},
    branch_protection_after: []const []const u8 = &.{},
    workflow_evidence: []const []const u8 = &.{},
    check_run_evidence: []const []const u8 = &.{},
    failure_mode_evidence: []const []const u8 = &.{},
    owner_approvals: []const []const u8 = &.{},
    rollback_evidence: []const []const u8 = &.{},
    merge_blocking_evidence: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,
};
```

Use a `deinit` helper to free every owned option slice created by
`toOwnedSlice`.

- [ ] **Step 3: Add parser**

Support:

```sh
--from-readiness <required-status-check-enforcement-readiness.json> plan|record-applied --reason <reason>
```

Also support:

- `--by <actor>`
- `--policy <policy>`
- `--required-check-name <name>`
- `--branch-protection-before <path-or-summary>`
- `--branch-protection-after <path-or-summary>`
- `--workflow-evidence <path-or-summary>`
- `--check-run-evidence <path-or-summary>`
- `--failure-mode-evidence <path-or-summary>`
- `--owner-approval <path-or-summary>`
- `--rollback-evidence <path-or-summary>`
- `--merge-blocking-evidence <path-or-summary>`
- `--verified-command <command>`
- `--out-prefix <path-prefix>`
- `--help`

Return stable errors:

```zig
error.MissingReadinessPath
error.InvalidReadinessPath
error.UnknownMode
error.MissingReason
error.MissingFlagValue
error.UnknownFlag
error.UnknownArgument
```

- [ ] **Step 4: Add output path replacement**

Implement:

- `foo-ci-gate-required-status-check-enforcement-readiness.json` becomes
  `foo-ci-gate-required-status-check-enforcement-application-boundary.json`;
- `foo.json` becomes
  `foo-ci-gate-required-status-check-enforcement-application-boundary.json`;
- `--out-prefix x` emits `x.json` and `x.txt`.

- [ ] **Step 5: Add parser tests**

Add tests for:

- plan options with defaults;
- record-applied options with every evidence flag;
- invalid non-JSON source path;
- unknown mode;
- missing reason;
- implicit and explicit output paths.

- [ ] **Step 6: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary.zig
```

Expected: constants, parser, and output path tests pass.

## Task 3: Parse Source Enforcement-Readiness And Add Source Checks

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary.zig`

- [ ] **Step 1: Add source structs**

Add source structs:

```zig
const SourceCheck = struct {
    name: []const u8 = "",
    id: []const u8 = "",
    status: []const u8,
    detail: []const u8 = "",
};

const SourceNegativeFixture = struct {
    id: []const u8 = "",
    artifact_state: []const u8 = "",
    decision: []const u8 = "",
    failed_gate: []const u8 = "",
    reason: []const u8 = "",
};

const SourceReadinessArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_policy: []const u8 = "",
    source_policy_status: []const u8 = "",
    source_policy_decision: []const u8 = "",
    source_policy_ready_for_next_branch: bool = false,
    source_application_status: []const u8 = "",
    source_application_mode: []const u8 = "",
    source_applied: bool = false,
    source_application_mutation_authority: []const u8 = "",
    decision: []const u8,
    enforcement_readiness_status: []const u8,
    ready_for_next_branch: bool,
    active_enforcement_claim_allowed: bool = false,
    merge_blocker_claim_allowed: bool = false,
    mutation_authority: []const u8 = "",
    ci_gate_enabled: bool = false,
    ci_gate_enforcement_enabled: bool = false,
    ci_required_status_check_enabled: bool = false,
    ci_workflow_mutation_enabled: bool = false,
    ci_upload_execution_enabled: bool = false,
    ci_report_publication_enabled: bool = false,
    github_api_mutation_enabled: bool = false,
    github_check_run_creation_enabled: bool = false,
    branch_protection_mutation_by_tool_enabled: bool = false,
    github_step_summary_write_enabled: bool = false,
    pull_request_comment_enabled: bool = false,
    production_telemetry_ingestion: bool = false,
    live_exporter_enabled: bool = false,
    network_send_enabled: bool = false,
    collector_endpoint_configured: bool = false,
    otlp_serialization_enabled: bool = false,
    runtime_pipeline_enabled: bool = false,
    durable_write_enabled: bool = false,
    nendb_write_enabled: bool = false,
    required_check_names: []const []const u8 = &.{},
    branch_protection_evidence: []const []const u8 = &.{},
    workflow_evidence: []const []const u8 = &.{},
    check_run_evidence: []const []const u8 = &.{},
    failure_mode_evidence: []const []const u8 = &.{},
    owner_approvals: []const []const u8 = &.{},
    rollback_evidence: []const []const u8 = &.{},
    checks: []const SourceCheck = &.{},
    denied_inference_rules: []const []const u8 = &.{},
    negative_fixtures: []const SourceNegativeFixture = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};
```

- [ ] **Step 2: Implement source checks**

Add checks:

- `source-schema`
- `source-readiness-ready`
- `source-policy-applied`
- `source-active-claims-still-denied`
- `source-mutation-authority-none`
- `source-tool-authority-disabled`
- `source-runtime-and-storage-disabled`
- `source-evidence-catalogs-present`
- `source-checks-passed`
- `source-verification-recorded`

Source readiness must have active and merge-blocker claims denied. This branch
is what can record externally applied active enforcement.

- [ ] **Step 3: Add source fixture tests**

Add embedded JSON fixtures:

- `readyReadinessJson()` with readiness ready, `source_applied=true`, active
  claims denied, evidence arrays present, checks pass, and catalogs present.
- `blockedReadinessJson()` with `enforcement_readiness_status="blocked"`.
- `unsafeReadinessJson()` with an authority boolean set to true.

Test expectations:

- ready source passes source checks;
- blocked source fails source readiness;
- unsafe source fails authority checks.

## Task 4: Add Application Evaluation, Evidence Safety, And Reports

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary.zig`

- [ ] **Step 1: Add constants**

Add:

- `required_verification_commands`
- disabled tool authority booleans
- `mutation_authority = "none"`
- evidence requirement catalog
- denied inference rules
- negative fixtures
- blocked claims

- [ ] **Step 2: Add application checks**

Common checks:

- all source checks pass;
- reason is present;
- evidence is safe.

`plan` checks:

- mode is `plan`.

`record-applied` checks:

- mode is `record-applied`;
- required check names present;
- branch-protection before present;
- branch-protection after present;
- workflow or check-run evidence present;
- failure-mode evidence present;
- owner approval present;
- rollback evidence present;
- verification recorded;
- merge-blocking evidence is present before merge-blocker claims are allowed.

Evidence is unsafe if any evidence string contains secret-shaped terms such as
`secret=`, `token=`, `ghp_`, `sk-`, `password=`, `BEGIN PRIVATE KEY`, or denied
claim markers such as `github_api_mutation_enabled=true`,
`branch_protection_mutation_by_tool_enabled=true`,
`ci_workflow_mutation_enabled=true`, `production_health=proven`,
`durable_write_enabled=true`, or `nendb_write_enabled=true`.

- [ ] **Step 3: Define status fields**

Set output fields from the result:

- planned passing output:
  - `required_status_check_enforcement_application_status="planned"`
  - `applied=false`
  - `active_enforcement_recorded=false`
  - `merge_blocking_recorded=false`
  - `active_enforcement_claim_allowed=false`
  - `merge_blocker_claim_allowed=false`
- applied passing output:
  - `required_status_check_enforcement_application_status="applied"`
  - `applied=true`
  - `active_enforcement_recorded=true`
  - `active_enforcement_claim_allowed=true`
  - `merge_blocking_recorded=true` when merge-blocking evidence exists
  - `merge_blocker_claim_allowed=true` when merge-blocking evidence exists
- blocked output:
  - `required_status_check_enforcement_application_status="blocked"`
  - `applied=false`
  - `active_enforcement_recorded=false`
  - `merge_blocking_recorded=false`
  - `active_enforcement_claim_allowed=false`
  - `merge_blocker_claim_allowed=false`

- [ ] **Step 4: Add report rendering**

Render JSON and text with:

- schema metadata;
- source readiness metadata;
- mode and reviewer decision;
- application status fields;
- tool authority booleans;
- required check names;
- before/after branch-protection evidence;
- workflow/check-run evidence;
- failure-mode, owner approval, rollback, and merge-blocking evidence;
- evidence requirements;
- checks;
- denied inference rules;
- negative fixtures;
- blocked claims;
- required and verified commands;
- generated output paths;
- agent guidance.

- [ ] **Step 5: Add report tests**

Test:

- `plan` from ready source emits planned status and active claims false;
- `record-applied` from ready source plus complete evidence emits applied
  status and active enforcement true;
- `record-applied` with merge-blocking evidence allows merge-blocker claim;
- blocked source emits blocked status;
- missing before/after/workflow/failure/owner/rollback/verification evidence
  blocks applied status;
- unsafe evidence blocks applied status;
- text output denies mutation by this tool.

## Task 5: Add File IO, Main, Build Wiring, And Schema Governance

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary.zig`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`

- [ ] **Step 1: Add `main`, `run`, and file IO**

Implement:

- `main(init: std.process.Init) !void`
- `run(init: std.process.Init, options: Options) !void`
- bounded source read with `readFileAlloc`
- parent directory creation
- write JSON and text output files
- usage text that names every CLI flag

- [ ] **Step 2: Wire the build step**

In `packages/zigeffect/build.zig`, add after the required-status-check
enforcement-readiness tool:

- module for
  `tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary.zig`;
- executable named
  `zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary`;
- run step named
  `causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary`;
- test artifact wired into `test_step`.

- [ ] **Step 3: Update schema governance**

Add schema:

`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1`

Use compatibility tags:

- `strict-v1`
- `record-only`
- `required-status-check-enforcement-application-boundary`
- `plan-or-record-applied`
- `applied-external-enforcement-evidence`
- `active-enforcement-record`
- `merge-blocker-record`
- `branch-protection-before-after`
- `workflow-or-check-run-evidence`
- `owner-approval`
- `rollback-evidence`
- `no-tool-github-api-mutation`
- `no-tool-branch-protection-mutation`
- `no-tool-workflow-mutation`
- `no-tool-ci-upload`
- `no-live-ingestion`
- `no-durable-write`
- `no-nendb-write`

Update schema count from `73` to `74` and test expectations.

- [ ] **Step 4: Run focused verification**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary.zig
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary -- --help
zig build test
```

Expected: all commands exit 0.

## Task 6: Update Backlog, Docs, README, Operations, And Roadmaps

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Create: `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Modify: adjacent current-next docs that name this branch.

- [ ] **Step 1: Update production hardening backlog tool**

Set:

```zig
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-enforcement-policy";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy";
```

Add delivered item:

`production-telemetry-ci-gate-required-status-check-enforcement-application-boundary`

Add dependency order entry after required-status-check enforcement-readiness.

Add verification commands for positive planned and negative application
boundary artifacts.

Update tests that assert current recommendation, next branch, delivered items,
dependency order, and command listing.

- [ ] **Step 2: Add user-facing docs**

Create the enforcement application-boundary doc with sections:

- command;
- modes;
- source readiness contract;
- application evidence checks;
- denied inferences;
- handoff;
- verification.

- [ ] **Step 3: Update summary docs**

Update README, operations, roadmap, schema-governance, production-hardening
backlog docs, and the master roadmap to mark enforcement application-boundary
delivered and name the next enforcement policy branch.

- [ ] **Step 4: Run doc/backlog checks**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected: commands exit 0 and output references the new schema/item and next
branch.

## Task 7: Full Verification And Commit

**Files:**
- All files modified in Tasks 1-6.

- [ ] **Step 1: Run tool generation checks**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-readiness.json \
  plan \
  --reason "required status check enforcement application boundary planned"
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-readiness-negative.json \
  record-applied \
  --reason "negative required status check enforcement application boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary-negative
```

Expected: commands exit 0 and write JSON/text artifacts. The first command may
emit blocked status when the local source readiness artifact is blocked; unit
tests cover ready-source planned and applied paths.

- [ ] **Step 2: Run package verification**

Run:

```sh
cd packages/zigeffect
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 3: Stage and inspect**

Run:

```sh
git status --short
git diff --stat
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  packages/zigeffect/README.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.md \
  packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-readiness.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git diff --cached --check
git diff --cached --stat
```

Expected: no ignored `.zig-cache` output is staged, and staged diff check exits
0.

- [ ] **Step 4: Commit**

Run:

```sh
git commit -m "feat(zigeffect): add required status check enforcement application boundary"
```

Expected: commit succeeds.

## Plan Self-Review

- Spec coverage: every design requirement maps to a task: CLI and output paths
  in Task 2, source checks in Task 3, application/evidence/report behavior in
  Task 4, build/schema in Task 5, backlog/docs in Task 6, verification/commit
  in Task 7.
- Placeholder scan: no `TBD`, `TODO`, or deferred implementation markers are
  present.
- Type consistency: branch names, schema names, command names, mode names, and
  status field names match the design spec.
