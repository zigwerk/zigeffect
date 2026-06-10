# Production Telemetry CI Gate Required Status Check Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `causal-production-telemetry-ci-gate-required-status-check-policy`, a record-only interpretation policy for planned or externally applied required-status-check application-boundary artifacts.

**Architecture:** Add one Zig policy tool following the existing production telemetry policy pattern. The tool parses a required-status-check application-boundary artifact, validates planned-or-applied source evidence, records an approve/reject reviewer decision, renders deterministic JSON/text reports, and updates build wiring, schema governance, backlog, roadmap, README, and operations docs. It never mutates GitHub, workflows, branch protection, CI, storage, telemetry, or runtime state.

**Tech Stack:** Zig 0.16.0, `std.json`, `std.crypto.hash.sha2.Sha256`, existing zigeffect build steps, Bun root verification.

---

## File Structure

- Create `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig`
  - CLI parsing, source application-boundary parsing, policy checks, interpretation rules, required-check surface policy, deterministic JSON/text rendering, file IO, and focused tests.
- Modify `packages/zigeffect/build.zig`
  - Add module, executable, build step, and test integration after the required-status-check application-boundary tool.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Add the new schema entry and update schema count from `71` to `72`.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Mark required-status-check policy delivered and recommend the required-status-check enforcement-readiness branch.
- Create `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-policy.md`
  - Document command, source contract, planned/applied interpretation, denied inferences, handoff, and verification.
- Modify `packages/zigeffect/README.md`
  - Add command example after required-status-check application boundary.
- Modify `packages/zigeffect/docs/operations.md`
  - Add operations guidance and update current next branch.
- Modify `packages/zigeffect/docs/production-hardening-backlog.md`
  - Add delivered backlog item, dependency order item, and verification commands.
- Modify `packages/zigeffect/docs/schema-governance.md`
  - Add schema matrix prose and schema count.
- Modify `packages/zigeffect/docs/roadmap.md` and `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark this milestone delivered and add the enforcement-readiness handoff.
- Update predecessor docs that currently name this branch as the next branch.

## Task 1: Create Red Constants Test

**Files:**
- Create: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig`

- [ ] **Step 1: Write the failing constants test**

Create the file with this initial content:

```zig
const std = @import("std");

test "ci gate required status check policy schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1", production_telemetry_ci_gate_required_status_check_policy_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_required_status_check_policy_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-required-status-check-enforcement-readiness", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness", next_branch_if_ready);
}
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig
```

Expected: fail with an undeclared identifier for `production_telemetry_ci_gate_required_status_check_policy_schema`.

- [ ] **Step 3: Commit is not allowed yet**

Do not commit after a red test. Continue to Task 2 to make the test pass.

## Task 2: Implement Constants, Decisions, Options, And Parser

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig`

- [ ] **Step 1: Add constants and enums**

Add these constants above the test:

```zig
pub const production_telemetry_ci_gate_required_status_check_policy_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1";
pub const production_telemetry_ci_gate_required_status_check_policy_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy";
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-enforcement-readiness";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness";

const source_application_boundary_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1";
const generated_by = "causal-production-telemetry-ci-gate-required-status-check-policy";
const output_prefix_suffix = "-ci-gate-required-status-check-policy";
const compact_output_prefix_name = "production-telemetry-ci-gate-required-status-check-policy";
```

Add:

```zig
const Decision = enum { approve, reject };
const PolicyStatus = enum { ready, blocked };
const SourceState = enum { planned, applied, blocked };
const CheckStatus = enum { pass, fail };
const OutputFormat = enum { json, text };
```

- [ ] **Step 2: Add `Options`**

Add:

```zig
const Options = struct {
    application_boundary_path: []const u8,
    decision: Decision,
    reason: []const u8,
    reviewed_by: []const u8 = "required-status-check-policy-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-policy",
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,
};
```

- [ ] **Step 3: Add parser**

Support this CLI shape:

```sh
--from-application-boundary <required-status-check-application-boundary.json> approve|reject --reason <reason>
```

Also support:

- `--by <actor>`
- `--policy <policy>`
- `--verified-command <command>`
- `--out-prefix <path-prefix>`
- `--help`

Return these stable errors:

```zig
error.MissingApplicationBoundaryPath
error.InvalidApplicationBoundaryPath
error.UnknownDecision
error.MissingReason
error.MissingOptionValue
error.UnknownOption
```

- [ ] **Step 4: Add parser tests**

Add tests with this shape:

```zig
test "parses ci gate required status check policy approval and rejection options" {
    const approve_options = try parseOptions(&.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy",
        "--from-application-boundary",
        "source.json",
        "approve",
        "--reason",
        "required status check policy reviewed",
        "--by",
        "reviewer-a",
        "--policy",
        "policy-a",
        "--verified-command",
        "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary",
        "--verified-command",
        "zig build causal-artifacts",
        "--out-prefix",
        ".zig-cache/causal-artifacts/policy",
    });

    try std.testing.expectEqual(Decision.approve, approve_options.decision);
    try std.testing.expectEqualStrings("source.json", approve_options.application_boundary_path);
    try std.testing.expectEqualStrings("required status check policy reviewed", approve_options.reason);
    try std.testing.expectEqualStrings("reviewer-a", approve_options.reviewed_by);
    try std.testing.expectEqualStrings("policy-a", approve_options.policy);
    try std.testing.expectEqual(@as(usize, 2), approve_options.verified_commands.len);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/policy", approve_options.out_prefix.?);

    const reject_options = try parseOptions(&.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy",
        "--from-application-boundary",
        "source.json",
        "reject",
        "--reason",
        "negative required status check policy path",
    });

    try std.testing.expectEqual(Decision.reject, reject_options.decision);
}
```

Add error tests:

```zig
test "rejects invalid ci gate required status check policy options" {
    try std.testing.expectError(error.MissingApplicationBoundaryPath, parseOptions(&.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy",
    }));
    try std.testing.expectError(error.InvalidApplicationBoundaryPath, parseOptions(&.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy",
        "--from-application-boundary",
        "source.txt",
        "approve",
        "--reason",
        "policy reviewed",
    }));
    try std.testing.expectError(error.UnknownDecision, parseOptions(&.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy",
        "--from-application-boundary",
        "source.json",
        "maybe",
        "--reason",
        "policy reviewed",
    }));
    try std.testing.expectError(error.MissingReason, parseOptions(&.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy",
        "--from-application-boundary",
        "source.json",
        "approve",
    }));
}
```

- [ ] **Step 5: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig
```

Expected: constants and parser tests pass.

## Task 3: Parse Source Application Boundary Artifacts

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig`

- [ ] **Step 1: Add source structs**

Add structs that match the consumed application-boundary artifact:

```zig
const SourceCheck = struct {
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

const SourceNegativeFixture = struct {
    id: []const u8,
    artifact_state: []const u8,
    decision: []const u8,
    failed_gate: []const u8,
    reason: []const u8,
};

const ApplicationBoundaryArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    generated_by: []const u8 = "",
    source_branch: []const u8 = "",
    recommendation: []const u8 = "",
    next_branch_if_ready: []const u8 = "",
    mode: []const u8,
    required_status_check_application_status: []const u8,
    applied: bool,
    mutation_authority: []const u8,
    ci_gate_enabled: bool,
    ci_gate_enforcement_enabled: bool,
    ci_required_status_check_enabled: bool,
    ci_workflow_mutation_enabled: bool,
    ci_upload_execution_enabled: bool,
    ci_report_publication_enabled: bool,
    github_api_mutation_enabled: bool,
    github_check_run_creation_enabled: bool,
    branch_protection_mutation_by_tool_enabled: bool,
    github_step_summary_write_enabled: bool,
    pull_request_comment_enabled: bool,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    network_send_enabled: bool,
    collector_endpoint_configured: bool,
    otlp_serialization_enabled: bool,
    runtime_pipeline_enabled: bool,
    durable_write_enabled: bool,
    nendb_write_enabled: bool,
    required_check_profile: ?[]const u8 = null,
    branch_protection_changes: []const []const u8 = &.{},
    workflow_changes: []const []const u8 = &.{},
    check_run_changes: []const []const u8 = &.{},
    before_evidence: []const []const u8 = &.{},
    after_evidence: []const []const u8 = &.{},
    application_checks: []const SourceCheck = &.{},
    source_required_status_check_profiles: []const SourceRequiredStatusCheckProfile = &.{},
    denied_inference_rules: []const []const u8 = &.{},
    negative_fixtures: []const SourceNegativeFixture = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    agent_guidance: []const []const u8 = &.{},
};
```

Use `std.json.parseFromSlice(ApplicationBoundaryArtifact, allocator, bytes, .{ .ignore_unknown_fields = true })`.

- [ ] **Step 2: Add source parsing helper**

Add:

```zig
fn parseSourceApplicationBoundary(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(ApplicationBoundaryArtifact) {
    return std.json.parseFromSlice(ApplicationBoundaryArtifact, allocator, bytes, .{ .ignore_unknown_fields = true });
}
```

- [ ] **Step 3: Add source fixture builders**

Add test fixtures:

```zig
const planned_source_fixture =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1",
    \\  "schema_version": 1,
    \\  "mode": "plan",
    \\  "required_status_check_application_status": "planned",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_report_publication_enabled": false,
    \\  "github_api_mutation_enabled": false,
    \\  "github_check_run_creation_enabled": false,
    \\  "branch_protection_mutation_by_tool_enabled": false,
    \\  "github_step_summary_write_enabled": false,
    \\  "pull_request_comment_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "application_checks": [{ "name": "source-readiness-ready", "status": "pass", "detail": "ready" }],
    \\  "source_required_status_check_profiles": [{ "id": "release-gate", "activation_enabled": false, "source": "release gate", "intended_future_signal": "release gate passes", "denied_claim": "active required check" }],
    \\  "denied_inference_rules": ["required-status-check-active", "github-mutation-by-tool"],
    \\  "negative_fixtures": [{ "id": "blocked-source-denied", "artifact_state": "blocked", "decision": "deny", "failed_gate": "source-boundary-status-valid", "reason": "blocked source denied" }],
    \\  "blocked_claims": ["production-health", "mutation-authority"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary"],
    \\  "verified_commands": ["zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary"],
    \\  "agent_guidance": ["Use planned artifacts to prepare policy work only."]
    \\}
;
```

Add an applied fixture by changing these fields:

```json
"mode": "record-applied",
"required_status_check_application_status": "applied",
"applied": true,
"mutation_authority": "record-only",
"required_check_profile": "release-gate",
"branch_protection_changes": ["required check configured externally"],
"workflow_changes": ["workflow emits release gate status externally"],
"before_evidence": ["before branch protection did not require release gate"],
"after_evidence": ["after branch protection requires release gate"]
```

- [ ] **Step 4: Add parser tests**

Add:

```zig
test "parses planned and applied required status check application boundary sources" {
    var planned = try parseSourceApplicationBoundary(std.testing.allocator, planned_source_fixture);
    defer planned.deinit();

    try std.testing.expectEqualStrings("planned", planned.value.required_status_check_application_status);
    try std.testing.expect(!planned.value.applied);
    try std.testing.expectEqualStrings("none", planned.value.mutation_authority);
    try std.testing.expectEqual(@as(usize, 1), planned.value.source_required_status_check_profiles.len);

    var applied = try parseSourceApplicationBoundary(std.testing.allocator, applied_source_fixture);
    defer applied.deinit();

    try std.testing.expectEqualStrings("applied", applied.value.required_status_check_application_status);
    try std.testing.expect(applied.value.applied);
    try std.testing.expectEqualStrings("record-only", applied.value.mutation_authority);
    try std.testing.expectEqual(@as(usize, 1), applied.value.branch_protection_changes.len);
}
```

- [ ] **Step 5: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig
```

Expected: source parser tests pass.

## Task 4: Evaluate Policy Checks

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig`

- [ ] **Step 1: Add policy check model**

Add:

```zig
const PolicyCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const PolicyResult = struct {
    status: PolicyStatus,
    ready_for_next_branch: bool,
    source_state: SourceState,
    source_applied: bool,
    checks: []const PolicyCheck,
};
```

- [ ] **Step 2: Add required verification commands**

Add:

```zig
const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary",
    "zig build causal-artifacts",
    "zig build release-gate --summary none",
    "zig build release-gate-report",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};
```

- [ ] **Step 3: Add source check helpers**

Implement helpers with these exact behaviors:

```zig
fn sourceState(source: ApplicationBoundaryArtifact) SourceState {
    if (std.mem.eql(u8, source.required_status_check_application_status, "planned")) return .planned;
    if (std.mem.eql(u8, source.required_status_check_application_status, "applied")) return .applied;
    return .blocked;
}

fn sourceApplicationStateConsistent(source: ApplicationBoundaryArtifact) bool {
    if (sourceState(source) == .planned) {
        return !source.applied and std.mem.eql(u8, source.mode, "plan") and std.mem.eql(u8, source.mutation_authority, "none");
    }
    if (sourceState(source) == .applied) {
        return source.applied and std.mem.eql(u8, source.mode, "record-applied") and std.mem.eql(u8, source.mutation_authority, "record-only");
    }
    return false;
}
```

Add helpers for:

- schema/version match;
- tool authority disabled;
- CI enforcement disabled;
- runtime and storage disabled;
- source checks passed;
- catalogs present;
- applied evidence present when `sourceState(source) == .applied`;
- verified commands contain every required command.

- [ ] **Step 4: Add `evaluatePolicy`**

Add:

```zig
fn evaluatePolicy(allocator: std.mem.Allocator, source: ApplicationBoundaryArtifact, options: Options) !PolicyResult {
    var checks = std.ArrayListUnmanaged(PolicyCheck){};
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-schema", if (source.schema_version == 1 and std.mem.eql(u8, source.schema, source_application_boundary_schema)) .pass else .fail, "source application-boundary schema is supported");
    try appendCheck(allocator, &checks, "source-boundary-status-valid", if (sourceState(source) != .blocked) .pass else .fail, "source status is planned or applied");
    try appendCheck(allocator, &checks, "source-application-state-consistent", if (sourceApplicationStateConsistent(source)) .pass else .fail, "source mode, applied flag, and mutation authority match");
    try appendCheck(allocator, &checks, "source-tool-authority-disabled", if (sourceToolAuthorityDisabled(source)) .pass else .fail, "source keeps GitHub, branch protection, workflow, check-run, CI upload, step summary, and PR comment authority disabled");
    try appendCheck(allocator, &checks, "source-ci-enforcement-disabled", if (sourceCiEnforcementDisabled(source)) .pass else .fail, "source keeps CI gate enforcement and required checks disabled by the tool");
    try appendCheck(allocator, &checks, "source-runtime-and-storage-disabled", if (sourceRuntimeAndStorageDisabled(source)) .pass else .fail, "source keeps live telemetry, network, collector, OTLP, runtime, durable, and NenDB writes disabled");
    try appendCheck(allocator, &checks, "source-checks-passed", if (sourceChecksPassed(source)) .pass else .fail, "source application checks have no failing status");
    try appendCheck(allocator, &checks, "source-catalogs-present", if (sourceCatalogsPresent(source)) .pass else .fail, "source catalogs required by agents are present");
    try appendCheck(allocator, &checks, "source-applied-evidence-present", if (sourceAppliedEvidenceValid(source)) .pass else .fail, "applied sources include branch-protection, before, after, and workflow or check-run evidence");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "reviewer approved the required-status-check policy");
    try appendCheck(allocator, &checks, "policy-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "policy recorded every required verification command");
    try appendCheck(allocator, &checks, "interpretation-rules-present", if (interpretationRulesPresent()) .pass else .fail, "allowed and denied interpretation rules are present");
    try appendCheck(allocator, &checks, "required-check-surface-policy-present", if (requiredCheckSurfacePolicyPresent()) .pass else .fail, "required-check surface policy is present and non-mutating");

    const owned_checks = try checks.toOwnedSlice(allocator);
    const ready = checksPass(owned_checks);

    return .{
        .status = if (ready) .ready else .blocked,
        .ready_for_next_branch = ready,
        .source_state = sourceState(source),
        .source_applied = source.applied,
        .checks = owned_checks,
    };
}
```

- [ ] **Step 5: Add evaluation tests**

Add tests:

```zig
test "approved planned source policy is ready and keeps source_applied false" {
    var parsed = try parseSourceApplicationBoundary(std.testing.allocator, planned_source_fixture);
    defer parsed.deinit();

    const result = try evaluatePolicy(std.testing.allocator, parsed.value, .{
        .application_boundary_path = "source.json",
        .decision = .approve,
        .reason = "required status check policy reviewed",
        .verified_commands = required_verification_commands,
    });
    defer std.testing.allocator.free(result.checks);

    try std.testing.expectEqual(PolicyStatus.ready, result.status);
    try std.testing.expect(result.ready_for_next_branch);
    try std.testing.expectEqual(SourceState.planned, result.source_state);
    try std.testing.expect(!result.source_applied);
}

test "approved applied source policy is ready and keeps source_applied true" {
    var parsed = try parseSourceApplicationBoundary(std.testing.allocator, applied_source_fixture);
    defer parsed.deinit();

    const result = try evaluatePolicy(std.testing.allocator, parsed.value, .{
        .application_boundary_path = "source.json",
        .decision = .approve,
        .reason = "required status check policy reviewed",
        .verified_commands = required_verification_commands,
    });
    defer std.testing.allocator.free(result.checks);

    try std.testing.expectEqual(PolicyStatus.ready, result.status);
    try std.testing.expectEqual(SourceState.applied, result.source_state);
    try std.testing.expect(result.source_applied);
}
```

Add blocked-path tests for reject, missing verification, unsafe authority, and applied source missing branch-protection evidence.

- [ ] **Step 6: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig
```

Expected: policy evaluation tests pass.

## Task 5: Add Interpretation Catalogs And Renderers

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig`

- [ ] **Step 1: Add catalogs**

Add allowed interpretation rules:

```zig
const allowed_interpretation_rules: []const []const u8 = &.{
    "planned-policy-design-input",
    "applied-evidence-review-input",
    "agent-readonly-context",
    "before-after-review-evidence",
    "future-enforcement-readiness-input",
};
```

Add denied inference rules:

```zig
const denied_inference_rules: []const []const u8 = &.{
    "planned-policy-is-not-active-required-status-check",
    "applied-source-is-not-tool-github-mutation-proof",
    "policy-readiness-is-not-branch-protection-mutation",
    "policy-readiness-is-not-workflow-mutation",
    "policy-readiness-is-not-check-run-creation",
    "policy-readiness-is-not-github-api-mutation",
    "policy-readiness-is-not-ci-artifact-upload-execution",
    "policy-readiness-is-not-github-step-summary-or-pr-comment-proof-by-tool",
    "policy-readiness-is-not-production-health-proof",
    "policy-readiness-is-not-deployment-success-proof",
    "policy-readiness-is-not-capacity-proof",
    "policy-readiness-is-not-customer-impact-proof",
    "policy-readiness-is-not-production-cluster-readiness-proof",
    "policy-readiness-is-not-live-telemetry-coverage-proof",
    "policy-readiness-is-not-durable-or-nendb-write-proof",
    "policy-readiness-grants-no-mutation-authority",
};
```

Add required-check surface policies with `tool_mutation_enabled=false` and `merge_blocker_claim_allowed=false`.

- [ ] **Step 2: Add JSON renderer**

Render fields in this order:

1. `schema`
2. `schema_version`
3. `generated_by`
4. `source_branch`
5. `source_application_boundary_path`
6. `source_application_boundary_schema`
7. `source_application_status`
8. `source_mode`
9. `source_applied`
10. `source_mutation_authority`
11. `decision`
12. `reviewed_by`
13. `policy`
14. `reason`
15. `required_status_check_policy_status`
16. `ready_for_next_branch`
17. all disabled authority booleans
18. `allowed_interpretation_rules`
19. `denied_inference_rules`
20. `required_check_surface_policy`
21. `policy_checks`
22. `required_verification_commands`
23. `verified_commands`
24. `negative_fixtures`
25. `blocked_claims`
26. `agent_guidance`
27. `recommendation`
28. `next_branch_if_ready`

Authority booleans in the policy artifact must all render as false:

```json
"applied": false,
"ci_gate_enabled": false,
"ci_gate_enforcement_enabled": false,
"ci_required_status_check_enabled": false,
"ci_workflow_mutation_enabled": false,
"ci_upload_execution_enabled": false,
"ci_report_publication_enabled": false,
"github_api_mutation_enabled": false,
"github_check_run_creation_enabled": false,
"branch_protection_mutation_by_tool_enabled": false,
"github_step_summary_write_enabled": false,
"pull_request_comment_enabled": false,
"production_telemetry_ingestion": false,
"live_exporter_enabled": false,
"network_send_enabled": false,
"collector_endpoint_configured": false,
"otlp_serialization_enabled": false,
"runtime_pipeline_enabled": false,
"durable_write_enabled": false,
"nendb_write_enabled": false
```

- [ ] **Step 3: Add text renderer**

Render these lines near the top:

```text
zigeffect production telemetry CI gate required status check policy
schema: zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1
source application boundary: <path>
source application status: planned|applied|blocked
source applied: true|false
required_status_check_policy_status: ready|blocked
ready_for_next_branch: true|false
mutation authority: none
next branch if ready: codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness
```

- [ ] **Step 4: Add renderer tests**

Add tests asserting JSON and text contain:

- `"required_status_check_policy_status": "ready"`;
- `"source_applied": false` for planned source;
- `"source_applied": true` for applied source;
- `"merge_blocker_claim_allowed": false`;
- `"next_branch_if_ready": "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness"`;
- `source applied: false` in text for planned source;
- `source applied: true` in text for applied source.

- [ ] **Step 5: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig
```

Expected: renderer tests pass.

## Task 6: Add CLI Main, File IO, Help, And Output Paths

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig`

- [ ] **Step 1: Add output path helper**

Default path behavior:

```text
production-telemetry-ci-gate-required-status-check-application-boundary.json
production-telemetry-ci-gate-required-status-check-policy.json
```

For deep chained paths, use a compact prefix:

```text
production-telemetry-ci-gate-required-status-check-policy-<12-hex-source-digest>
```

Add tests for both replacement and compact digest behavior.

- [ ] **Step 2: Add help text**

Help output must include:

```text
Usage:
  causal-production-telemetry-ci-gate-required-status-check-policy --from-application-boundary <artifact.json> approve|reject --reason <reason>

Options:
  --from-application-boundary <artifact.json>
  --by <actor>
  --policy <policy>
  --verified-command <command>
  --out-prefix <path-prefix>
  --help
```

- [ ] **Step 3: Add `main`**

`main` should:

1. allocate with `std.heap.GeneralPurposeAllocator`;
2. parse args;
3. print help and exit 0 for `--help`;
4. read the source JSON;
5. parse and evaluate the artifact;
6. render JSON and text;
7. write `<prefix>.json` and `<prefix>.txt`;
8. print the text report to stderr or stdout following the closest existing policy tool pattern.

- [ ] **Step 4: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig
```

Expected: all tool unit tests pass.

## Task 7: Wire Build Step

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add module and executable after application-boundary wiring**

Insert after `causal_production_telemetry_ci_gate_required_status_check_application_boundary_tool_tests`:

```zig
const causal_production_telemetry_ci_gate_required_status_check_policy_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_production_telemetry_ci_gate_required_status_check_policy_tool = b.addExecutable(.{
    .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy",
    .root_module = causal_production_telemetry_ci_gate_required_status_check_policy_tool_module,
});
const run_causal_production_telemetry_ci_gate_required_status_check_policy_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_policy_tool);
if (b.args) |args| run_causal_production_telemetry_ci_gate_required_status_check_policy_tool.addArgs(args);
const causal_production_telemetry_ci_gate_required_status_check_policy_step = b.step("causal-production-telemetry-ci-gate-required-status-check-policy", "Review production telemetry CI gate required status check policy");
causal_production_telemetry_ci_gate_required_status_check_policy_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_policy_tool.step);

const causal_production_telemetry_ci_gate_required_status_check_policy_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy-tests",
    .root_module = causal_production_telemetry_ci_gate_required_status_check_policy_tool_module,
});
const run_causal_production_telemetry_ci_gate_required_status_check_policy_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_policy_tool_tests);
test_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_policy_tool_tests.step);
```

- [ ] **Step 2: Verify help command**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-policy -- --help
```

Expected: help text includes `--from-application-boundary`.

- [ ] **Step 3: Commit**

Run:

```sh
git add packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig packages/zigeffect/build.zig
git diff --cached --check
git commit -m "feat(zigeffect): add required status check policy tool"
```

## Task 8: Update Schema Governance

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/docs/schema-governance.md`

- [ ] **Step 1: Add schema entry**

Insert after the required-status-check application-boundary schema:

```zig
.{
    .schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-production-telemetry-ci-gate-required-status-check-policy"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate required status check enforcement readiness" },
    .compatibility = &.{ "strict-v1", "record-only", "required-status-check-policy", "interpretation-policy", "planned-or-applied-source", "branch-protection-evidence", "cluster-release-gate-aware", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-tool-github-api-mutation", "no-tool-branch-protection-mutation", "no-tool-workflow-mutation", "no-tool-ci-upload", "no-tool-github-step-summary-write", "no-tool-pr-comment" },
    .governance_requirements = &.{ "source application-boundary checks", "planned source interpretation tests", "applied source interpretation tests", "denied inference tests", "required-check surface policy tests", "next-branch enforcement-readiness handoff" },
},
```

- [ ] **Step 2: Update tests**

Change schema count assertions from `71` to `72`.

Add assertions for:

```zig
try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1");
try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1\"") != null);
```

- [ ] **Step 3: Update docs**

In `packages/zigeffect/docs/schema-governance.md`, update the schema count to `72` and add the new schema row or paragraph with the compatibility tags from Step 1.

- [ ] **Step 4: Verify schema governance**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_schema_governance.zig
zig build causal-schema-governance -- --format json 2>&1 | rg 'schema_count|required-status-check-policy|enforcement-readiness'
```

Expected: tests pass, `schema_count` is `72`, and the new schema appears.

## Task 9: Update Backlog, Docs, And Roadmap

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Create: `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-policy.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Modify predecessor docs that refer to the policy branch as next.

- [ ] **Step 1: Update backlog recommendation constants**

In `causal_production_hardening_backlog.zig`, change:

```zig
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-policy";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy";
```

to:

```zig
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-enforcement-readiness";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness";
```

- [ ] **Step 2: Add backlog item**

Add a delivered item:

```zig
.{
    .id = "production-telemetry-ci-gate-required-status-check-policy",
    .title = "Production Telemetry CI Gate Required Status Check Policy",
    .gap_id = "production-telemetry-ci-gate-required-status-check-policy",
    .priority = "P5",
    .status = "delivered",
    .summary = "Consumes planned or externally applied required-status-check application-boundary artifacts and defines record-only interpretation policy without mutating GitHub branch protection, workflows, check runs, CI uploads, telemetry, storage, or runtime state.",
    .depends_on = &.{ "production-telemetry-ci-gate-required-status-check-application-boundary", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
    .deliverables = &.{
        "ready and blocked required-status-check policy artifacts",
        "planned versus applied source interpretation",
        "required-check surface policy",
        "denied merge-blocking and GitHub mutation inferences",
        "required-status-check enforcement-readiness handoff",
    },
    .evidence_sources = &.{
        "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy-design.md",
        "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy-implementation.md",
        "packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig",
        "packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-policy.md",
    },
    .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy",
    .agent_guidance = "Use ready required-status-check policy artifacts to prepare enforcement-readiness work only; policy readiness does not prove active merge blocking, GitHub mutation by the tool, workflow mutation by the tool, CI upload execution by the tool, live telemetry, durable writes, NenDB writes, production cluster claims, or mutation authority.",
},
```

Add the id to `dependency_order` after `production-telemetry-ci-gate-required-status-check-application-boundary`.

- [ ] **Step 3: Update backlog command examples**

Add commands:

```zig
"zig build causal-production-telemetry-ci-gate-required-status-check-policy -- --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-application-boundary.json approve --reason \"required status check policy reviewed\" --verified-command \"zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary\" --verified-command \"zig build causal-artifacts\" --verified-command \"zig build release-gate --summary none\" --verified-command \"zig build release-gate-report\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
"zig build causal-production-telemetry-ci-gate-required-status-check-policy -- --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-application-boundary-negative.json reject --reason \"negative required status check policy path\" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-policy-negative",
```

- [ ] **Step 4: Update backlog tests**

Change expected recommendation and branch strings to enforcement-readiness.

Add assertions for:

```zig
try expectBacklogItem("production-telemetry-ci-gate-required-status-check-policy");
try expectBacklogItemStatus("production-telemetry-ci-gate-required-status-check-policy", "delivered");
try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-gate-required-status-check-policy") != null);
```

- [ ] **Step 5: Create feature docs**

Create `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-policy.md` with sections:

```markdown
# Production Telemetry CI Gate Required Status Check Policy

`causal-production-telemetry-ci-gate-required-status-check-policy` consumes planned or applied required-status-check application-boundary artifacts and emits record-only interpretation policy.

It does not create GitHub required checks, update branch protection, mutate workflows, create check runs, call GitHub APIs, upload CI artifacts, write GitHub step summaries, post pull request comments, enable CI gate enforcement, ingest live telemetry, call networks, write NenDB, write durable production storage, or grant mutation authority.

## Command

## Source Application Boundary

## Planned Versus Applied Sources

## Denied Inferences

## Handoff

## Verification
```

Fill the sections with the command and verification sequence from the design spec.

- [ ] **Step 6: Update README, operations, roadmap, and backlog docs**

Use exact strings:

- current delivered milestone:
  `causal-production-telemetry-ci-gate-required-status-check-policy`;
- current next branch:
  `codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness`;
- current recommendation:
  `start-production-telemetry-ci-gate-required-status-check-enforcement-readiness`.

- [ ] **Step 7: Verify backlog**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-hardening-backlog -- --format json 2>&1 | rg 'required-status-check-policy|enforcement-readiness|recommended_next_branch'
```

Expected: tests pass and the backlog recommends enforcement-readiness.

## Task 10: Generate Positive And Negative Artifacts

**Files:**
- Generated ignored artifacts under `.zig-cache/causal-artifacts/`

- [ ] **Step 1: Ensure source artifacts exist**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-readiness.json \
  plan \
  --reason "required status check application boundary planned"
zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-readiness-negative.json \
  record-applied \
  --reason "negative required status check application boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-application-boundary-negative
```

Expected: planned and negative source artifacts are written.

- [ ] **Step 2: Generate ready policy artifact**

Run:

```sh
zig build causal-production-telemetry-ci-gate-required-status-check-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-application-boundary.json \
  approve \
  --reason "required status check policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Expected text includes:

```text
required_status_check_policy_status: ready
source applied: false
next branch if ready: codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness
```

- [ ] **Step 3: Generate negative policy artifact**

Run:

```sh
zig build causal-production-telemetry-ci-gate-required-status-check-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-application-boundary-negative.json \
  reject \
  --reason "negative required status check policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-policy-negative
```

Expected text includes:

```text
required_status_check_policy_status: blocked
ready_for_next_branch: false
```

## Task 11: Full Verification And Commit

**Files:**
- All modified files from previous tasks

- [ ] **Step 1: Run focused Zig tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig
zig test tools/causal_schema_governance.zig
zig test tools/causal_production_hardening_backlog.zig
```

Expected: all focused tests pass.

- [ ] **Step 2: Run build-step and artifact checks**

Run:

```sh
zig build causal-production-telemetry-ci-gate-required-status-check-policy -- --help
zig build causal-schema-governance -- --format json 2>&1 | rg 'schema_count|required-status-check-policy|enforcement-readiness'
zig build causal-production-hardening-backlog -- --format json 2>&1 | rg 'required-status-check-policy|enforcement-readiness|recommended_next_branch'
```

Expected: help works, schema count is `72`, and backlog names the enforcement-readiness branch.

- [ ] **Step 3: Run package verification**

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

- [ ] **Step 4: Inspect git diff**

Run:

```sh
git status --short
git diff --stat
git diff -- packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig | sed -n '1,220p'
```

Expected: only policy milestone files are changed, plus generated ignored artifacts are absent from `git status`.

- [ ] **Step 5: Commit**

Run:

```sh
git add packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/tools/causal_schema_governance.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-policy.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/README.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git diff --cached --check
git commit -m "feat(zigeffect): add required status check policy"
```

Expected: commit succeeds.
