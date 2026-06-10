# Required Status Check Enforcement Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a record-only zigeffect causal policy artifact that consumes required-status-check enforcement application-boundary artifacts and defines how later agents may interpret planned, externally applied active-enforcement, and merge-blocking evidence.

**Architecture:** Implement one Zig executable under `packages/zigeffect/tools/` using the existing causal production telemetry tool pattern: parse a bounded source JSON artifact, evaluate deterministic checks, emit JSON and text reports, and deny mutation or production-health inferences. Wire the executable into `build.zig`, register its schema and backlog milestone, and document the handoff to the next evaluator branch.

**Tech Stack:** Zig stdlib JSON parsing/stringify, zigeffect package `build.zig` tooling, existing causal hardening backlog/schema governance tools, Bun root verification.

---

## File Structure

- Create `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_policy.zig`: executable, parser, evaluator, JSON/text emitters, and unit tests.
- Modify `packages/zigeffect/build.zig`: add the executable step and include its test artifact in `zig build test`.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`: register schema `zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1` and update tests/counts.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`: mark the policy milestone delivered, change the recommended next branch to the evaluator branch, and update tests/verification commands.
- Create `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-policy.md`: user-facing artifact contract and command examples.
- Modify `packages/zigeffect/README.md`, `packages/zigeffect/docs/operations.md`, `packages/zigeffect/docs/production-hardening-backlog.md`, `packages/zigeffect/docs/schema-governance.md`, `packages/zigeffect/docs/roadmap.md`, and `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`: surface the delivered milestone and move next work to the evaluator branch.

## Task 1: Red Constants Test

**Files:**
- Create: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_policy.zig`

- [ ] **Step 1: Write the failing constants test**

Create the file with only imports and the public constants test:

```zig
const std = @import("std");

test "required status check enforcement policy constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1",
        production_telemetry_ci_gate_required_status_check_enforcement_policy_schema,
    );
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_required_status_check_enforcement_policy_schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-production-telemetry-ci-gate-required-status-check-enforcement-evaluator",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator",
        next_branch_if_ready,
    );
}
```

- [ ] **Step 2: Run the red test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_policy.zig
```

Expected: FAIL with undeclared identifier errors for the new constants. This proves the test is guarding the missing feature.

## Task 2: Minimal Constants and CLI Parser

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_policy.zig`

- [ ] **Step 1: Add constants and parser tests**

Add constants at the top:

```zig
pub const production_telemetry_ci_gate_required_status_check_enforcement_policy_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1";
pub const production_telemetry_ci_gate_required_status_check_enforcement_policy_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy";
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-enforcement-evaluator";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator";
```

Add parser tests for:

```zig
test "parseArgs requires source application boundary path" { ... }
test "parseArgs parses approve with reason and repeated verified commands" { ... }
test "deriveOutputPaths replaces application boundary suffix" { ... }
```

The parser must accept:

```sh
--from-application-boundary source.json approve --reason "reviewed" --verified-command "zig build test" --verified-command "bun run check" --out-prefix out/policy
```

and expose:

```zig
Options{
    .application_boundary_path = "source.json",
    .decision = .approve,
    .reason = "reviewed",
    .verified_commands = &.{ "zig build test", "bun run check" },
    .out_prefix = "out/policy",
}
```

- [ ] **Step 2: Implement the parser and output path helpers**

Implement:

```zig
const Decision = enum { approve, reject };

const Options = struct {
    application_boundary_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "ci-gate-required-status-check-enforcement-policy-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-enforcement-policy",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        freeSliceOnly(allocator, self.verified_commands);
    }
};
```

Use the same error vocabulary as the design:

```zig
error.MissingApplicationBoundaryPath
error.InvalidApplicationBoundaryPath
error.MissingDecision
error.UnknownDecision
error.MissingReason
error.MissingFlagValue
error.UnknownFlag
error.UnknownArgument
```

- [ ] **Step 3: Verify parser tests pass**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_policy.zig
```

Expected: PASS for constants, parser, and output path tests.

## Task 3: Source Artifact Evaluation

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_policy.zig`

- [ ] **Step 1: Add evaluation tests**

Add tests that construct in-memory JSON source artifacts:

```zig
test "approved planned application boundary yields ready policy without active claims" { ... }
test "approved applied active boundary yields active ready policy without merge blocker" { ... }
test "approved applied merge-blocking boundary yields merge blocker policy" { ... }
test "blocked source or reviewer reject blocks policy" { ... }
test "inconsistent source active claims block policy" { ... }
```

The ready planned case must assert:

```zig
try std.testing.expectEqual(PolicyStatus.ready, result.status);
try std.testing.expect(result.ready_for_next_branch);
try std.testing.expect(!result.active_enforcement_policy_ready);
try std.testing.expect(!result.merge_blocker_policy_ready);
```

The applied active case must assert:

```zig
try std.testing.expectEqual(PolicyStatus.ready, result.status);
try std.testing.expect(result.active_enforcement_policy_ready);
try std.testing.expect(!result.merge_blocker_policy_ready);
```

The applied merge-blocking case must assert:

```zig
try std.testing.expectEqual(PolicyStatus.ready, result.status);
try std.testing.expect(result.active_enforcement_policy_ready);
try std.testing.expect(result.merge_blocker_policy_ready);
```

- [ ] **Step 2: Implement JSON source structs and checks**

Implement source structs for application-boundary input fields:

```zig
const ApplicationBoundaryArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_enforcement_readiness: []const u8 = "",
    source_enforcement_readiness_status: []const u8 = "",
    source_decision: []const u8 = "",
    source_ready_for_next_branch: bool = false,
    mode: []const u8,
    required_status_check_enforcement_application_status: []const u8,
    applied: bool,
    active_enforcement_recorded: bool = false,
    merge_blocking_recorded: bool = false,
    active_enforcement_claim_allowed: bool = false,
    merge_blocker_claim_allowed: bool = false,
    mutation_authority: []const u8,
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
    branch_protection_before: []const []const u8 = &.{},
    branch_protection_after: []const []const u8 = &.{},
    workflow_evidence: []const []const u8 = &.{},
    check_run_evidence: []const []const u8 = &.{},
    failure_mode_evidence: []const []const u8 = &.{},
    owner_approvals: []const []const u8 = &.{},
    rollback_evidence: []const []const u8 = &.{},
    merge_blocking_evidence: []const []const u8 = &.{},
    evidence_requirements: []const SourceEvidenceRequirement = &.{},
    checks: []const SourceCheck = &.{},
    denied_inference_rules: []const []const u8 = &.{},
    negative_fixtures: []const SourceNegativeFixture = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};
```

Implement checks with these names:

```zig
source-schema
source-boundary-status-valid
source-application-state-consistent
source-tool-authority-disabled
source-runtime-and-storage-disabled
source-checks-passed
source-catalogs-present
source-verification-recorded
source-active-claims-consistent
source-merge-blocker-consistent
reviewer-decision-approved
policy-verification-recorded
release-gate-verification-recorded
interpretation-policy-present
evidence-requirements-present
negative-fixtures-present
```

- [ ] **Step 3: Verify evaluation tests pass**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_policy.zig
```

Expected: PASS.

## Task 4: JSON/Text Report Emission and CLI

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_policy.zig`

- [ ] **Step 1: Add report tests**

Add tests asserting generated reports include:

```json
"schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1"
"required_status_check_enforcement_policy_status": "ready"
"ready_for_next_branch": true
"active_enforcement_policy_ready": false
"merge_blocker_policy_ready": false
"mutation_authority": "none"
"next_branch_if_ready": "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator"
```

Also assert text output includes:

```text
required status check enforcement policy: ready
active enforcement policy ready: false
merge blocker policy ready: false
recommendation: start-production-telemetry-ci-gate-required-status-check-enforcement-evaluator
```

- [ ] **Step 2: Implement report structures and `main`**

`main` must:

1. parse args;
2. read `--from-application-boundary`;
3. generate reports;
4. create parent directories for JSON/text outputs;
5. write deterministic `.json` and `.txt` files;
6. print both output paths.

The JSON output must include every required top-level field listed in the design spec.

- [ ] **Step 3: Verify CLI help and tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_policy.zig
zig build-exe tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_policy.zig -femit-bin=.zig-cache/tmp/enforcement-policy
.zig-cache/tmp/enforcement-policy --help
```

Expected: unit tests pass and help prints the documented CLI contract.

## Task 5: Build Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add the build step after the application-boundary tool**

Add module/executable/run step:

```zig
const causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_policy.zig"),
    .target = target,
    .optimize = optimize,
});
const causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool = b.addExecutable(.{
    .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy",
    .root_module = causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool_module,
});
const run_causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool);
if (b.args) |args| run_causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool.addArgs(args);
const causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_step = b.step("causal-production-telemetry-ci-gate-required-status-check-enforcement-policy", "Review production telemetry CI gate required status check enforcement policy");
causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool.step);

const causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy-tests",
    .root_module = causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool_module,
});
const run_causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool_tests);
test_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_enforcement_policy_tool_tests.step);
```

- [ ] **Step 2: Verify the build step is discoverable**

Run:

```sh
cd packages/zigeffect
zig build --help | rg "causal-production-telemetry-ci-gate-required-status-check-enforcement-policy"
```

Expected: the new step appears in help.

## Task 6: Governance and Backlog Wiring

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Register schema governance entry**

Add a v1 schema entry with:

```zig
.schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1",
.owner = "zigeffect-causal-runtime",
.status = "active",
.emitted_by = &.{"causal-production-telemetry-ci-gate-required-status-check-enforcement-policy"},
.consumed_by = &.{ "agents", "reviewers", "production-hardening-backlog", "future-required-status-check-enforcement-evaluator" },
.compatibility = &.{ "strict-v1", "record-only", "required-status-check-enforcement-policy", "interpretation-policy", "active-enforcement-interpretation", "merge-blocker-interpretation", "planned-or-applied-source", "no-tool-github-api-mutation", "no-tool-branch-protection-mutation", "no-tool-workflow-mutation", "no-tool-check-run-creation", "no-tool-ci-upload", "no-live-ingestion", "no-durable-write", "no-nendb-write" },
```

Update tests from `74` schemas to `75`, and add `expectSchema`/string checks for the new schema.

- [ ] **Step 2: Add delivered backlog milestone and next branch**

Change:

```zig
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-enforcement-evaluator";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator";
```

Add a delivered backlog item:

```zig
.id = "production-telemetry-ci-gate-required-status-check-enforcement-policy",
.title = "Production Telemetry CI Gate Required Status Check Enforcement Policy",
.priority = "P5",
.status = "delivered",
.depends_on = &.{ "production-telemetry-ci-gate-required-status-check-enforcement-application-boundary", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
.branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy",
```

Add verification commands for approve/reject CLI paths and update tests that assert the recommended next branch.

- [ ] **Step 3: Verify governance and backlog tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_schema_governance.zig
zig test tools/causal_production_hardening_backlog.zig
```

Expected: PASS.

## Task 7: Documentation Updates

**Files:**
- Create: `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-policy.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Write the policy documentation**

The new doc must include:

```markdown
# Production Telemetry CI Gate Required Status Check Enforcement Policy

Schema: `zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1`

This artifact is record-only. It interprets a reviewed required-status-check
enforcement application-boundary artifact and decides whether later agents may
cite planned, externally applied active-enforcement, or merge-blocking evidence.
It does not mutate GitHub, branch protection, workflows, check runs, CI uploads,
step summaries, pull-request comments, live telemetry, runtime storage, durable
stores, or NenDB.
```

Include the positive and negative commands from the design spec and list the next branch as:

```markdown
`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator`
```

- [ ] **Step 2: Update index and roadmap docs**

Replace current “next branch is enforcement policy” guidance with “enforcement policy is delivered; next branch is enforcement evaluator.” Keep NenDB-only durable direction and SolidJS-inside-zig-webui workbench direction intact.

- [ ] **Step 3: Verify no old next-branch guidance remains**

Run:

```sh
rg -n "start-production-telemetry-ci-gate-required-status-check-enforcement-policy|recommended next branch: codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy" packages/zigeffect docs/superpowers
```

Expected: only historical design/plan records may mention enforcement-policy as the next branch; active docs/backlog should point to the evaluator branch.

## Task 8: Full Verification and Commit

**Files:**
- All files modified in prior tasks.

- [ ] **Step 1: Run focused verification**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_policy.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.json \
  approve \
  --reason "required status check enforcement policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary-negative.json \
  reject \
  --reason "negative required status check enforcement policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected: commands exit 0. Positive policy may report `blocked` if the source application-boundary artifact is blocked, but it must emit valid artifacts.

- [ ] **Step 2: Run full verification**

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

Expected: all commands pass.

- [ ] **Step 3: Commit implementation**

Run:

```sh
git status --short
git add packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_policy.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/tools/causal_schema_governance.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-policy.md \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/docs/roadmap.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): add required status check enforcement policy"
```

Expected: one implementation commit on `codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy`.
