# Production Telemetry CI Gate Required Status Check Enforcement Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness`, a record-only evidence gate for preparing a future required-status-check enforcement application-boundary branch.

**Architecture:** Add one Zig tool following the existing production telemetry policy/readiness pattern. The tool parses a required-status-check policy artifact, accepts planned sources for blocked diagnostics, requires applied policy evidence before readiness can become ready, validates explicit enforcement evidence, renders deterministic JSON/text reports, and updates build wiring, schema governance, backlog, roadmap, README, and operations docs. It never mutates GitHub, workflows, branch protection, CI, telemetry, storage, or runtime state.

**Tech Stack:** Zig 0.16.0, `std.json`, existing zigeffect build steps, Bun root verification.

---

## File Structure

- Create `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness.zig`
  - CLI parsing, source policy parsing, source checks, enforcement evidence checks, evidence catalogs, denied inference rules, deterministic JSON/text rendering, file IO, and focused tests.
- Modify `packages/zigeffect/build.zig`
  - Add module, executable, build step, and test integration after the required-status-check policy tool.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Add the new schema entry and update schema count from `72` to `73`.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Mark required-status-check enforcement-readiness delivered and recommend the future enforcement application-boundary branch.
- Create `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-readiness.md`
  - Document command, source policy contract, planned/applied handling, evidence gates, denied inferences, handoff, and verification.
- Modify `packages/zigeffect/README.md`
  - Add command example after required-status-check policy.
- Modify `packages/zigeffect/docs/operations.md`
  - Add operations guidance and update current next branch.
- Modify `packages/zigeffect/docs/production-hardening-backlog.md`
  - Add delivered backlog item, dependency order item, and verification commands.
- Modify `packages/zigeffect/docs/schema-governance.md`
  - Add schema matrix prose and schema count.
- Modify `packages/zigeffect/docs/roadmap.md` and `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark this milestone delivered and add the enforcement application-boundary handoff.
- Update predecessor docs that currently name enforcement-readiness as the next branch.

## Task 1: Create Red Constants And Parser Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness.zig`

- [ ] **Step 1: Write the failing constants test**

Create the file with this initial content:

```zig
const std = @import("std");

test "ci gate required status check enforcement readiness schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-readiness.v1", production_telemetry_ci_gate_required_status_check_enforcement_readiness_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_required_status_check_enforcement_readiness_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary", next_branch_if_ready);
}
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness.zig
```

Expected: fail with an undeclared identifier for `production_telemetry_ci_gate_required_status_check_enforcement_readiness_schema`.

- [ ] **Step 3: Do not commit the red state**

Continue to Task 2 before committing.

## Task 2: Implement Constants, Options, CLI Parser, And Output Paths

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness.zig`

- [ ] **Step 1: Add constants and enums**

Add:

```zig
pub const production_telemetry_ci_gate_required_status_check_enforcement_readiness_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-readiness.v1";
pub const production_telemetry_ci_gate_required_status_check_enforcement_readiness_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness";
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary";

const source_policy_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1";
const generated_by = "causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness";
const output_prefix_suffix = "-ci-gate-required-status-check-enforcement-readiness";
const compact_output_prefix_name = "production-telemetry-ci-gate-required-status-check-enforcement-readiness";
```

Add:

```zig
const Decision = enum { approve, reject };
const EnforcementReadinessStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail, skipped };
```

- [ ] **Step 2: Add `Options`**

Add:

```zig
const Options = struct {
    policy_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "ci-gate-required-status-check-enforcement-readiness-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-enforcement-readiness",
    reason: []const u8,
    required_check_names: []const []const u8 = &.{},
    branch_protection_evidence: []const []const u8 = &.{},
    workflow_evidence: []const []const u8 = &.{},
    check_run_evidence: []const []const u8 = &.{},
    failure_mode_evidence: []const []const u8 = &.{},
    owner_approvals: []const []const u8 = &.{},
    rollback_evidence: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,
};
```

Use a `deinit` helper to free every owned option slice created by `toOwnedSlice`.

- [ ] **Step 3: Add parser**

Support:

```sh
--from-policy <required-status-check-policy.json> approve|reject --reason <reason>
```

Also support:

- `--by <actor>`
- `--policy <policy>`
- `--required-check-name <name>`
- `--branch-protection-evidence <path-or-summary>`
- `--workflow-evidence <path-or-summary>`
- `--check-run-evidence <path-or-summary>`
- `--failure-mode-evidence <path-or-summary>`
- `--owner-approval <path-or-summary>`
- `--rollback-evidence <path-or-summary>`
- `--verified-command <command>`
- `--out-prefix <path-prefix>`
- `--help`

Return stable errors:

```zig
error.MissingPolicyPath
error.InvalidPolicyPath
error.UnknownDecision
error.MissingReason
error.MissingFlagValue
error.UnknownFlag
error.UnknownArgument
```

- [ ] **Step 4: Add output path replacement**

Implement:

- `foo-ci-gate-required-status-check-policy.json` becomes
  `foo-ci-gate-required-status-check-enforcement-readiness.json`;
- `foo.json` becomes `foo-ci-gate-required-status-check-enforcement-readiness.json`;
- `--out-prefix x` emits `x.json` and `x.txt`.

- [ ] **Step 5: Add parser tests**

Add tests for:

- approve options with every evidence flag;
- reject options with defaults;
- invalid non-JSON source path;
- unknown decision;
- missing reason;
- implicit and explicit output paths.

- [ ] **Step 6: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness.zig
```

Expected: constants, parser, and output path tests pass.

## Task 3: Parse Source Policy And Add Readiness Checks

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness.zig`

- [ ] **Step 1: Add source structs**

Add structs for the policy artifact:

```zig
const SourceCheck = struct {
    name: []const u8 = "",
    id: []const u8 = "",
    status: []const u8,
    detail: []const u8 = "",
};

const SourceRequiredCheckSurfacePolicy = struct {
    id: []const u8 = "",
    surface: []const u8 = "",
    source_state: []const u8 = "",
    source_applied: bool = false,
    allowed_use: []const u8 = "",
    failure_effect: []const u8 = "",
    tool_mutation_enabled: bool = false,
    merge_blocker_claim_allowed: bool = false,
};

const SourcePolicyArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_application_boundary: []const u8 = "",
    source_application_status: []const u8 = "",
    source_application_mode: []const u8 = "",
    source_applied: bool = false,
    source_application_mutation_authority: []const u8 = "",
    source_readiness: []const u8 = "",
    source_after_report_digest: []const u8 = "",
    decision: []const u8,
    required_status_check_policy_status: []const u8,
    ready_for_next_branch: bool,
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
    required_check_surface_policy: []const SourceRequiredCheckSurfacePolicy = &.{},
    source_application_checks: []const SourceCheck = &.{},
    checks: []const SourceCheck = &.{},
    denied_inference_rules: []const []const u8 = &.{},
    negative_fixtures: []const SourceNegativeFixture = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};

const SourceNegativeFixture = struct {
    id: []const u8 = "",
    artifact_state: []const u8 = "",
    decision: []const u8 = "",
    failed_gate: []const u8 = "",
    reason: []const u8 = "",
};
```

- [ ] **Step 2: Implement source checks**

Add checks:

- `source-schema`
- `source-policy-ready`
- `source-policy-applied`
- `source-application-state-consistent`
- `source-tool-authority-disabled`
- `source-runtime-and-storage-disabled`
- `source-checks-passed`
- `source-surface-policy-safe`
- `source-catalogs-present`
- `source-verification-recorded`

`source-policy-applied` must fail when `source_applied=false`.

- [ ] **Step 3: Add source fixture tests**

Add embedded JSON fixtures:

- `readyAppliedPolicyJson()` with `source_applied=true`, status ready, applied source, safe surface policy, checks pass, and catalogs present.
- `readyPlannedPolicyJson()` with `source_applied=false`, status ready, planned source, safe surface policy, checks pass, and catalogs present.
- `blockedPolicyJson()` with `required_status_check_policy_status="blocked"`.

Test expectations:

- applied source can pass source checks;
- planned source fails only the applied-readiness gate;
- blocked source fails source policy readiness;
- unsafe authority booleans fail authority checks.

## Task 4: Add Enforcement Evidence, Denied Inferences, And Report Rendering

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness.zig`

- [ ] **Step 1: Add constants**

Add:

- `required_verification_commands`
- disabled authority booleans
- `mutation_authority = "none"`
- `active_enforcement_claim_allowed = false`
- `merge_blocker_claim_allowed = false`
- `evidence_requirements`
- `denied_inference_rules`
- `negative_fixtures`

- [ ] **Step 2: Add evidence checks**

Add checks:

- `reviewer-decision-approved`
- `required-check-names-present`
- `branch-protection-evidence-present`
- `workflow-or-check-run-evidence-present`
- `failure-mode-evidence-present`
- `owner-approval-present`
- `rollback-evidence-present`
- `evidence-is-safe`
- `verification-recorded`
- `release-gate-verification-recorded`
- `active-claim-denied`

Evidence is unsafe if any evidence string contains secret-shaped terms such as
`secret=`, `token=`, `ghp_`, `sk-`, `password=`, `BEGIN PRIVATE KEY`, or denied
claim markers such as `github_api_mutation_enabled=true`,
`branch_protection_mutation_by_tool_enabled=true`,
`ci_required_status_check_enabled=true`, `production_health=proven`,
`durable_write_enabled=true`, or `nendb_write_enabled=true`.

- [ ] **Step 3: Add report rendering**

Render JSON and text with:

- schema metadata;
- source policy metadata;
- reviewer decision;
- readiness status;
- `ready_for_next_branch`;
- `active_enforcement_claim_allowed=false`;
- `merge_blocker_claim_allowed=false`;
- `mutation_authority="none"`;
- all disabled authority booleans;
- required check names;
- evidence arrays;
- evidence requirements;
- checks;
- denied inference rules;
- negative fixtures;
- blocked claims;
- required and verified commands;
- generated output paths;
- agent guidance.

- [ ] **Step 4: Add report tests**

Test:

- approved applied source plus complete evidence emits ready JSON/text and the future enforcement application-boundary branch;
- approved planned source emits blocked JSON/text and design-only guidance;
- reject emits blocked status;
- missing required check name blocks readiness;
- missing branch-protection evidence blocks readiness;
- missing workflow/check-run evidence blocks readiness;
- missing failure-mode, owner approval, rollback, or verification evidence blocks readiness;
- unsafe evidence blocks readiness;
- text output names active enforcement and merge blocker claims as denied.

## Task 5: Add File IO, Main, Build Wiring, And Schema Governance

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness.zig`
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

In `packages/zigeffect/build.zig`, add after the required-status-check policy
tool:

- module for `tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness.zig`;
- executable named `zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness`;
- run step named `causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness`;
- test artifact wired into `test_step`.

- [ ] **Step 3: Update schema governance**

Add schema:

`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-readiness.v1`

Use compatibility tags:

- `strict-v1`
- `record-only`
- `required-status-check-enforcement-readiness`
- `applied-source-required-for-ready`
- `active-enforcement-claim-denied`
- `merge-blocker-claim-denied`
- `branch-protection-evidence`
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

Update schema count from `72` to `73` and test expectations.

- [ ] **Step 4: Run focused verification**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness.zig
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness -- --help
zig build test
```

Expected: all commands exit 0.

## Task 6: Update Backlog, Docs, README, Operations, And Roadmaps

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Create: `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-readiness.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Modify: predecessor required-status-check docs that name this branch.

- [ ] **Step 1: Update production hardening backlog tool**

Set:

```zig
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary";
```

Add delivered item:

`production-telemetry-ci-gate-required-status-check-enforcement-readiness`

Add dependency order entry after required-status-check policy.

Add verification commands for positive and negative enforcement-readiness
artifacts.

Update tests that assert current recommendation, next branch, delivered items,
dependency order, and command listing.

- [ ] **Step 2: Add user-facing docs**

Create the enforcement-readiness doc with sections:

- command;
- source policy contract;
- planned versus applied policy sources;
- enforcement evidence checks;
- denied inferences;
- handoff;
- verification.

- [ ] **Step 3: Update summary docs**

Update README, operations, roadmap, schema-governance, production-hardening
backlog docs, and the master roadmap to mark enforcement-readiness delivered
and name the next enforcement application-boundary branch.

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
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness -- \
  --from-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-policy.json \
  approve \
  --reason "required status check enforcement readiness reviewed" \
  --required-check-name "zigeffect causal release gate" \
  --branch-protection-evidence "reviewed branch protection required status check evidence" \
  --workflow-evidence "reviewed release gate workflow evidence" \
  --failure-mode-evidence "reviewed failing release gate blocks future required check" \
  --owner-approval "reviewed owner approval for future required check enforcement" \
  --rollback-evidence "reviewed rollback removes required status check from branch protection" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-policy" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness -- \
  --from-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-policy-negative.json \
  reject \
  --reason "negative required status check enforcement readiness path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-readiness-negative
```

Expected: the first command may emit blocked readiness if the local source
policy is still planned; that is correct. The second command emits blocked
readiness. Both commands must exit 0 and write JSON/text artifacts.

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
  packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-readiness.md \
  packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-policy.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git diff --cached --check
git diff --cached --stat
```

Expected: no ignored `.zig-cache` output is staged, and staged diff check exits
0.

- [ ] **Step 4: Commit**

Run:

```sh
git commit -m "feat(zigeffect): add required status check enforcement readiness"
```

Expected: commit succeeds.

## Plan Self-Review

- Spec coverage: every design requirement maps to a task: CLI/source parsing in
  Tasks 2-3, evidence gates/rendering in Task 4, build/schema in Task 5,
  backlog/docs in Task 6, verification/commit in Task 7.
- Placeholder scan: no `TBD`, `TODO`, or deferred implementation markers are
  present.
- Type consistency: branch names, schema names, command names, and status field
  names match the design spec.
