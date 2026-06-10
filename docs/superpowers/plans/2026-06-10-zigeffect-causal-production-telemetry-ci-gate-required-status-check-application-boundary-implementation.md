# Production Telemetry CI Gate Required Status Check Application Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `causal-production-telemetry-ci-gate-required-status-check-application-boundary`, a record-only plan-or-record-applied boundary for externally reviewed required-status-check application evidence.

**Architecture:** Add one Zig tool following the existing production telemetry application-boundary pattern. The tool parses a ready required-status-check readiness artifact, supports `plan` and `record-applied`, validates reviewed evidence before setting `applied=true`, renders deterministic JSON/text reports, and updates build wiring, schema governance, backlog, roadmap, README, and operations docs. It never mutates GitHub, branch protection, workflows, CI, storage, telemetry, or runtime state.

**Tech Stack:** Zig 0.16.0, `std.json`, `std.crypto.hash.sha2.Sha256`, existing zigeffect build steps, Bun root verification.

---

## File Structure

- Create `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_application_boundary.zig`
  - CLI parsing, source readiness parsing, source checks, plan/record-applied
    evaluation, after-state safety checks, negative fixtures, deterministic
    JSON/text rendering, file IO, and focused tests.
- Modify `packages/zigeffect/build.zig`
  - Add module, executable, build step, and test integration after the
    required-status-check readiness tool.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Add the new schema entry and update schema count from 70 to 71.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Mark required-status-check application boundary delivered and recommend the
    required-status-check policy branch.
- Create `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-application-boundary.md`
  - Document command, modes, source contract, evidence gates, after-state
    safety, denied inferences, handoff, and verification.
- Modify `packages/zigeffect/README.md`
  - Add command example after required-status-check readiness.
- Modify `packages/zigeffect/docs/operations.md`
  - Add operations guidance and update current next branch.
- Modify `packages/zigeffect/docs/production-hardening-backlog.md`
  - Add delivered backlog item, dependency order item, and verification
    commands.
- Modify `packages/zigeffect/docs/schema-governance.md`
  - Add schema matrix prose.
- Modify `packages/zigeffect/docs/roadmap.md` and
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark the application-boundary milestone delivered and add the next policy
    branch.
- Update predecessor docs that currently point at this branch as current next.

## Task 1: Create Red Constants Test

**Files:**
- Create: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_application_boundary.zig`

- [ ] **Step 1: Add the failing constants test**

Create the file with only this test:

```zig
const std = @import("std");

test "ci gate required status check application boundary schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1", production_telemetry_ci_gate_required_status_check_application_boundary_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_required_status_check_application_boundary_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-required-status-check-policy", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy", next_branch_if_ready);
}
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_application_boundary.zig
```

Expected: fail with an undeclared identifier for
`production_telemetry_ci_gate_required_status_check_application_boundary_schema`.

## Task 2: Implement Constants, Modes, Options, And Parser

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_application_boundary.zig`

- [ ] **Step 1: Add constants and enums**

Add constants:

```zig
pub const production_telemetry_ci_gate_required_status_check_application_boundary_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1";
pub const production_telemetry_ci_gate_required_status_check_application_boundary_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary";
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-policy";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy";

const source_readiness_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1";
const generated_by = "causal-production-telemetry-ci-gate-required-status-check-application-boundary";
const output_prefix_suffix = "-ci-gate-required-status-check-application-boundary";
const compact_output_prefix_name = "production-telemetry-ci-gate-required-status-check-application-boundary";
```

Define:

```zig
const Mode = enum { plan, record_applied };
const RequiredStatusCheckApplicationStatus = enum { planned, applied, blocked };
const CheckStatus = enum { pass, fail };
```

- [ ] **Step 2: Add `Options`**

Add an options struct with these fields:

```zig
const Options = struct {
    source_path: []const u8,
    mode: Mode,
    reason: []const u8,
    reviewed_by: []const u8 = "required-status-check-application-boundary-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-application-boundary",
    required_check_profile: ?[]const u8 = null,
    branch_protection_changes: []const []const u8 = &.{},
    workflow_changes: []const []const u8 = &.{},
    check_run_changes: []const []const u8 = &.{},
    before_evidence: []const []const u8 = &.{},
    after_evidence: []const []const u8 = &.{},
    branch_protection_after_path: ?[]const u8 = null,
    workflow_after_path: ?[]const u8 = null,
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,
};
```

- [ ] **Step 3: Add parser**

Parse this shape:

```sh
--from-readiness <required-status-check-readiness.json> plan|record-applied --reason <reason>
```

Also parse:

- `--by`
- `--policy`
- `--required-check-profile`
- `--branch-protection-change`
- `--workflow-change`
- `--check-run-change`
- `--before`
- `--after`
- `--branch-protection-after`
- `--workflow-after`
- `--verified-command`
- `--out-prefix`
- `--help`

Validation:

- source path must end with `.json`
- mode must be `plan` or `record-applied`
- `--reason` must be present and non-empty
- `--branch-protection-after` must end in `.json`, `.md`, or `.txt`
- `--workflow-after` must end in `.yml` or `.yaml`

Return stable errors:

```zig
error.MissingSourceReadiness
error.InvalidSourceReadinessPath
error.UnknownMode
error.MissingReason
error.MissingOptionValue
error.UnknownOption
error.InvalidBranchProtectionAfterPath
error.InvalidWorkflowAfterPath
```

- [ ] **Step 4: Add parser tests**

Add tests for:

- plan mode with default actor and policy;
- record-applied mode with custom actor and policy;
- required check profile, branch-protection change, workflow change, check-run
  change, before evidence, after evidence, after-state paths, verified command,
  and output prefix;
- unknown mode returns `error.UnknownMode`;
- missing reason returns `error.MissingReason`;
- invalid branch-protection after path returns
  `error.InvalidBranchProtectionAfterPath`;
- invalid workflow after path returns `error.InvalidWorkflowAfterPath`.

- [ ] **Step 5: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_application_boundary.zig
```

Expected: constants and parser tests pass.

## Task 3: Parse And Evaluate Source Readiness Artifacts

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_application_boundary.zig`

- [ ] **Step 1: Add source structs**

Add source structs:

```zig
const SourceReadinessCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8,
};

const SourceRequiredStatusCheckProfile = struct {
    id: []const u8,
    activation_enabled: bool,
    source: []const u8,
    intended_future_signal: []const u8,
    denied_claim: []const u8,
};

const SourceReadinessDimension = struct {
    id: []const u8,
    required: bool,
    evidence: []const u8,
};

const SourceActivationGuardrail = struct {
    id: []const u8,
    required_before_application: bool,
    reason: []const u8,
};

const SourceNegativeFixture = struct {
    id: []const u8,
    artifact_state: []const u8,
    decision: []const u8,
    failed_gate: []const u8,
    reason: []const u8,
};

const SourceDeniedInferenceRule = struct {
    id: []const u8,
    consumer_role: []const u8,
    allowed_use: []const u8,
    failure_effect: []const u8,
    denied_claim: []const u8,
};

const RequiredStatusCheckReadinessArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    generated_by: []const u8,
    source_branch: []const u8,
    recommendation: []const u8,
    next_branch_if_ready: []const u8,
    decision: []const u8,
    required_status_check_readiness_status: []const u8,
    ready_for_next_branch: bool,
    mutation_authority: []const u8,
    ci_gate_enabled: bool,
    ci_gate_enforcement_enabled: bool,
    ci_required_status_check_enabled: bool,
    ci_workflow_mutation_enabled: bool,
    ci_upload_execution_enabled: bool,
    ci_report_publication_enabled: bool,
    github_api_mutation_enabled: bool = false,
    github_check_run_creation_enabled: bool = false,
    github_step_summary_write_enabled: bool,
    pull_request_comment_enabled: bool,
    production_telemetry_ingestion: bool,
    network_send_enabled: bool,
    runtime_pipeline_enabled: bool,
    durable_write_enabled: bool,
    nendb_write_enabled: bool,
    required_status_check_profiles: []SourceRequiredStatusCheckProfile,
    readiness_dimensions: []SourceReadinessDimension,
    activation_guardrails: []SourceActivationGuardrail,
    denied_inference_rules: []SourceDeniedInferenceRule,
    negative_fixtures: []SourceNegativeFixture,
    blocked_claims: [][]const u8,
    required_verification_commands: [][]const u8,
    verified_commands: [][]const u8,
    checks: []SourceReadinessCheck,
};
```

- [ ] **Step 2: Add source checks**

Implement source checks named exactly:

- `source-schema`
- `source-readiness-ready`
- `source-decision-approved`
- `source-required-checks-disabled`
- `source-branch-protection-disabled`
- `source-github-api-disabled`
- `source-ci-execution-disabled`
- `source-runtime-and-storage-disabled`
- `source-catalogs-present`
- `source-verification-recorded`

The checks pass only when the source artifact is ready, approved, verified,
has no mutation authority, keeps all execution booleans disabled, has
required-check profiles with `activation_enabled=false`, and includes the
catalogs required by the design spec.

- [ ] **Step 3: Add source fixture tests**

Add JSON fixtures inside tests:

- `ready_readiness_json`: contains schema
  `zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1`,
  decision `approve`, status `ready`, `ready_for_next_branch=true`, disabled
  authority booleans, three required-check profiles with
  `activation_enabled=false`, dimensions, guardrails, denied inference rules,
  negative fixtures, blocked claims, required verification commands, matching
  verified commands, and source checks.
- `blocked_readiness_json`: same schema but decision `reject`, status
  `blocked`, `ready_for_next_branch=false`.
- `active_profile_json`: same as ready but one profile has
  `activation_enabled=true`.
- `missing_catalogs_json`: same as ready but empty `activation_guardrails` and
  empty `denied_inference_rules`.
- `incomplete_verification_json`: same as ready but missing
  `zig build release-gate-report` from `verified_commands`.

Assert:

- ready fixture passes every source check;
- blocked fixture fails `source-readiness-ready`;
- active profile fixture fails `source-required-checks-disabled`;
- missing catalog fixture fails `source-catalogs-present`;
- incomplete verification fixture fails `source-verification-recorded`.

## Task 4: Add Application Evidence, Safety Checks, And Status Evaluation

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_application_boundary.zig`

- [ ] **Step 1: Add application structs**

Add:

```zig
const ApplicationCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const ApplicationResult = struct {
    status: RequiredStatusCheckApplicationStatus,
    applied: bool,
    checks: []ApplicationCheck,
};

const RequiredStatusCheckApplicationEvidence = struct {
    selected_profile: ?[]const u8,
    branch_protection_changes: []const []const u8,
    workflow_changes: []const []const u8,
    check_run_changes: []const []const u8,
    before: []const []const u8,
    after: []const []const u8,
    branch_protection_after_path: ?[]const u8,
    workflow_after_path: ?[]const u8,
};
```

- [ ] **Step 2: Add required verification commands**

Use:

```zig
const required_verification_commands = &.{
    "zig build causal-production-telemetry-ci-gate-required-status-check-readiness",
    "zig build causal-artifacts",
    "zig build release-gate --summary none",
    "zig build release-gate-report",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};
```

- [ ] **Step 3: Add plan checks**

For `plan`, append checks:

- `source-checks-pass`
- `mode-plan`
- `selected-profile-known`
- `selected-profile-inactive`
- `mutation-authority-none`

If all source checks pass and optional selected profile is known/inactive,
status is `planned` and `applied=false`. Otherwise status is `blocked` and
`applied=false`.

- [ ] **Step 4: Add record-applied checks**

For `record-applied`, append checks:

- `source-checks-pass`
- `mode-record-applied`
- `required-check-profile-present`
- `selected-profile-known`
- `selected-profile-inactive`
- `branch-protection-change-present`
- `workflow-or-check-run-change-present`
- `before-evidence-present`
- `after-evidence-present`
- `post-verification-recorded`
- `branch-protection-after-safe`
- `workflow-after-safe`
- `mutation-authority-none`

Status is `applied` and `applied=true` only when every check passes. Otherwise
status is `blocked` and `applied=false`.

- [ ] **Step 5: Add after-state safety helpers**

Implement:

```zig
fn readOptionalFile(allocator: std.mem.Allocator, path: ?[]const u8) !?[]const u8
fn branchProtectionAfterSafe(content: ?[]const u8) bool
fn workflowAfterSafe(content: ?[]const u8) bool
fn containsAny(haystack: []const u8, needles: []const []const u8) bool
fn containsAll(haystack: []const u8, needles: []const []const u8) bool
```

Branch-protection after-state passes when content is absent in plan mode, or
when present content includes `required`, `status`, `check`, and `branch` and
does not include prohibited markers:

```zig
const prohibited_after_state_markers = &.{
    "ghp_",
    "github_pat_",
    "secret",
    "token",
    "otlp endpoint",
    "deployment success",
    "production health",
    "production cluster ready",
    "durable write enabled",
    "nendb write enabled",
    "mutation_authority=granted",
    "\"mutation_authority\": \"granted\"",
};
```

Workflow after-state passes when content is absent in plan mode, or when
present content includes `zigeffect`, `causal`, and either `release-gate` or
`required`, and does not include prohibited markers:

```zig
const prohibited_workflow_after_markers = &.{
    "workflow mutated by tool",
    "github api mutation enabled",
    "create check run",
    "upload-artifact",
    "GITHUB_STEP_SUMMARY",
    "pull_request_comment",
    "otlp endpoint",
    "network send enabled",
    "durable write enabled",
    "nendb write enabled",
    "react renderer enabled",
    "mutation_authority=granted",
    "\"mutation_authority\": \"granted\"",
};
```

- [ ] **Step 6: Add evidence tests**

Add tests:

- plan with ready source returns `planned`, `applied=false`, and disabled
  authority;
- plan with blocked source returns `blocked`, `applied=false`;
- record-applied missing profile returns `blocked`;
- record-applied missing branch-protection change returns `blocked`;
- record-applied missing workflow/check-run change returns `blocked`;
- record-applied missing before or after evidence returns `blocked`;
- record-applied missing `zig build release-gate-report` verification returns
  `blocked`;
- record-applied unsafe branch-protection after-state with `github_pat_`
  returns `blocked`;
- record-applied unsafe workflow after-state with `upload-artifact` returns
  `blocked`;
- record-applied complete evidence returns `applied`, `applied=true`.

## Task 5: Add Catalogs, Rendering, File IO, And CLI Main

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_application_boundary.zig`

- [ ] **Step 1: Add denied inference rules**

Add denied inference rules for:

- `github-api-mutation-by-tool`
- `branch-protection-mutation-by-tool`
- `workflow-mutation-by-tool`
- `github-check-run-created-by-tool`
- `artifact-upload-executed-by-tool`
- `github-step-summary-written-by-tool`
- `pull-request-comment-written-by-tool`
- `ci-gate-enforcement-by-tool`
- `live-telemetry-ingestion`
- `network-send`
- `runtime-pipeline-activation`
- `durable-production-write`
- `nendb-write`
- `non-nendb-durable-adapter`
- `alternate-renderer`
- `deployment-success-proof`
- `production-health-proof`
- `production-cluster-readiness-proof`
- `customer-impact-proof`
- `capacity-proof`
- `mutation-authority`

- [ ] **Step 2: Add negative fixtures**

Add negative fixture ids:

- `blocked-source-readiness-denied`
- `missing-required-check-profile-denied`
- `active-source-required-check-profile-denied`
- `missing-branch-protection-change-denied`
- `missing-workflow-or-check-run-change-denied`
- `missing-before-evidence-denied`
- `missing-after-evidence-denied`
- `missing-release-gate-report-verification-denied`
- `unsafe-branch-protection-after-secret-denied`
- `unsafe-workflow-after-upload-denied`
- `github-api-mutation-claim-denied`
- `live-telemetry-claim-denied`
- `durable-write-claim-denied`
- `nendb-write-claim-denied`
- `production-health-claim-denied`
- `production-cluster-readiness-claim-denied`
- `alternate-renderer-claim-denied`
- `mutation-authority-claim-denied`

- [ ] **Step 3: Add deterministic output paths**

Implement the same output prefix behavior as predecessor tools:

- if `--out-prefix` is present, use it;
- otherwise derive from the source path;
- replace a trailing readiness suffix with
  `-ci-gate-required-status-check-application-boundary`;
- compact deeply chained file names to
  `production-telemetry-ci-gate-required-status-check-application-boundary-<digest>`.

- [ ] **Step 4: Add JSON renderer**

Render a JSON object containing:

- schema metadata;
- source readiness summary;
- mode, status, applied flag, reviewer, policy, reason;
- disabled authority booleans;
- selected profile and evidence arrays;
- after-state paths;
- application checks;
- denied inference rules;
- negative fixtures;
- blocked claims;
- required verification commands;
- verified commands;
- recommendation and next branch;
- agent guidance.

Use stable field ordering.

- [ ] **Step 5: Add text renderer**

Render text with sections:

- header and schema;
- source readiness summary;
- mode/status/applied/authority;
- evidence summary;
- checks;
- denied inference rules;
- negative fixtures;
- blocked claims;
- verification commands;
- agent guidance.

- [ ] **Step 6: Add `main`**

`main` should:

1. parse args;
2. print usage for `--help`;
3. read source readiness JSON;
4. read optional after-state files;
5. parse source readiness artifact with `std.json.parseFromSlice`;
6. evaluate source and application checks;
7. render JSON and text;
8. write sibling `.json` and `.txt` artifacts;
9. print the text report to stderr/stdout consistently with neighboring tools.

- [ ] **Step 7: Add rendering tests**

Assert that ready record-applied output contains:

- `"schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1"`
- `"required_status_check_application_status": "applied"`
- `"applied": true`
- `"mutation_authority": "none"`
- `"github_api_mutation_enabled": false`
- `"branch_protection_mutation_by_tool_enabled": false`
- `"next_branch_if_ready": "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy"`
- text line `required status check application status: applied`
- text line `applied: true`

Assert that blocked output contains:

- `"required_status_check_application_status": "blocked"`
- `"applied": false`
- `Treat blocked required-status-check application-boundary artifacts as a stop sign.`

## Task 6: Wire Build, Schema Governance, Backlog, And Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Create: `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-application-boundary.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Modify predecessor docs that point at the current branch.

- [ ] **Step 1: Add build wiring**

In `packages/zigeffect/build.zig`, add module/executable/step/test wiring after
the required-status-check readiness tool:

```zig
const causal_required_status_check_application_boundary_mod = b.addModule("causal_required_status_check_application_boundary", .{
    .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_required_status_check_application_boundary.zig"),
    .target = target,
    .optimize = optimize,
});
const causal_required_status_check_application_boundary_exe = b.addExecutable(.{
    .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary",
    .root_module = causal_required_status_check_application_boundary_mod,
});
b.installArtifact(causal_required_status_check_application_boundary_exe);
const causal_required_status_check_application_boundary_run = b.addRunArtifact(causal_required_status_check_application_boundary_exe);
if (b.args) |args| causal_required_status_check_application_boundary_run.addArgs(args);
const causal_required_status_check_application_boundary_step = b.step(
    "causal-production-telemetry-ci-gate-required-status-check-application-boundary",
    "Emit guarded production telemetry CI gate required-status-check application-boundary evidence",
);
causal_required_status_check_application_boundary_step.dependOn(&causal_required_status_check_application_boundary_run.step);
const causal_required_status_check_application_boundary_tests = b.addTest(.{
    .root_module = causal_required_status_check_application_boundary_mod,
});
test_step.dependOn(&b.addRunArtifact(causal_required_status_check_application_boundary_tests).step);
```

Adjust names to match nearby local variable style.

- [ ] **Step 2: Add schema governance entry**

Add schema:

```zig
.{
    .schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-production-telemetry-ci-gate-required-status-check-application-boundary"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate required status check policy" },
    .compatibility = &.{ "strict-v1", "record-only", "required-status-check-application-boundary", "plan-or-record-applied", "before-after-verification", "branch-protection-evidence", "check-run-evidence", "cluster-release-gate-aware", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-tool-github-api-mutation", "no-tool-branch-protection-mutation", "no-tool-workflow-mutation", "no-tool-ci-upload", "no-tool-github-step-summary-write", "no-tool-pr-comment" },
    .governance_requirements = &.{ "source readiness checks", "branch-protection evidence checks", "workflow or check-run evidence checks", "after-state safety checks", "next-branch required status check policy handoff" },
},
```

Update expected schema count from 70 to 71 in inventory, text, and JSON tests.
Add explicit expectations for the new schema in text and JSON reports.

- [ ] **Step 3: Update hardening backlog**

Set:

```zig
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-policy";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy";
```

Add delivered item:

```zig
.{
    .id = "production-telemetry-ci-gate-required-status-check-application-boundary",
    .title = "Production Telemetry CI Gate Required Status Check Application Boundary",
    .gap_id = "production-telemetry-ci-gate-required-status-check-application-boundary",
    .priority = "P5",
    .status = "delivered",
    .summary = "Consumes ready required-status-check readiness artifacts and records planned or externally applied required-status-check application-boundary evidence without mutating GitHub branch protection, workflows, check runs, CI uploads, telemetry, storage, or runtime state.",
    .depends_on = &.{ "production-telemetry-ci-gate-required-status-check-readiness", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
    .deliverables = &.{
        "planned and blocked required-status-check application-boundary artifacts",
        "record-applied evidence gate",
        "branch-protection before after evidence checks",
        "workflow or check-run evidence checks",
        "required-status-check policy handoff",
    },
    .evidence_sources = &.{
        "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary-design.md",
        "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary-implementation.md",
        "packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_application_boundary.zig",
        "packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-application-boundary.md",
    },
    .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary",
    .agent_guidance = "Use planned artifacts to prepare policy work only; use applied artifacts only when external reviewed branch-protection or check-run evidence plus before after verification exists; do not infer GitHub mutation by the tool, workflow mutation by the tool, CI upload execution by the tool, live telemetry, durable writes, NenDB writes, production cluster claims, or mutation authority.",
},
```

Add the new id to `dependency_order` after
`production-telemetry-ci-gate-required-status-check-readiness`.

Add positive and negative verification commands for the new tool.

Update backlog tests to expect the new recommendation, next branch, and
delivered item.

- [ ] **Step 4: Write tool docs**

Create
`packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-application-boundary.md`
with sections:

- title and one-paragraph summary;
- non-goals and denied authority;
- command examples for plan and record-applied;
- mode semantics;
- source readiness contract;
- evidence gates;
- after-state safety;
- handoff to the required-status-check policy branch;
- verification commands.

- [ ] **Step 5: Update README and operations docs**

Add command examples and warnings:

- readiness artifacts are source evidence only;
- plan does not apply branch protection;
- record-applied is only a record of external reviewed application;
- the tool does not call GitHub APIs or mutate workflows;
- next branch is
  `codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy`.

- [ ] **Step 6: Update roadmap and master roadmap spec**

Mark this branch delivered and add the next branch:

```md
35. `codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy`
   - Current next branch: define interpretation policy for externally applied
     required-status-check evidence before enforcement or branch-protection
     assumptions become agent-readable facts.
```

- [ ] **Step 7: Update predecessor docs**

In docs that say this application-boundary branch is current next, change the
handoff to the policy branch only after this milestone is documented as
delivered.

## Task 7: Generate Artifacts, Verify, And Commit

**Files:**
- Generated ignored artifacts under `.zig-cache/causal-artifacts/`
- Git-tracked files from previous tasks.

- [ ] **Step 1: Run format**

Run:

```sh
cd packages/zigeffect
zig fmt build.zig tools/causal_production_telemetry_ci_gate_required_status_check_application_boundary.zig tools/causal_production_hardening_backlog.zig tools/causal_schema_governance.zig
```

- [ ] **Step 2: Run focused tests**

Run:

```sh
zig test tools/causal_production_telemetry_ci_gate_required_status_check_application_boundary.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary -- --help
zig build causal-schema-governance -- --format json 2>&1 | rg 'schema_count|required-status-check-application-boundary|required-status-check-policy'
zig build causal-production-hardening-backlog -- --format json 2>&1 | rg 'recommendation|recommended_next_branch|required-status-check-application-boundary|required-status-check-policy'
```

Expected:

- focused tool tests pass;
- backlog tests pass;
- help output shows the full CLI;
- schema count is 71;
- backlog recommendation points to the policy branch.

- [ ] **Step 3: Generate a planned artifact**

Run:

```sh
zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-readiness.json \
  plan \
  --reason "required status check application boundary planned" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-application-boundary
```

Expected:

- `required_status_check_application_status: planned`
- `applied: false`
- `mutation_authority: none`
- `next branch if ready: codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy`

- [ ] **Step 4: Generate a blocked negative artifact**

Run:

```sh
zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-readiness-negative.json \
  record-applied \
  --reason "negative required status check application boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-application-boundary-negative
```

Expected:

- `required_status_check_application_status: blocked`
- `applied: false`
- failed checks include source readiness and missing evidence.

- [ ] **Step 5: Run broad verification**

Run:

```sh
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: every command exits 0.

- [ ] **Step 6: Stage and commit**

Run:

```sh
git status --short --branch
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  packages/zigeffect/README.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-application-boundary.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_application_boundary.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git diff --cached --check
git commit -m "feat(zigeffect): add required status check application boundary"
```

Include any predecessor docs touched by the implementation in the same `git add`
before the cached diff check.
