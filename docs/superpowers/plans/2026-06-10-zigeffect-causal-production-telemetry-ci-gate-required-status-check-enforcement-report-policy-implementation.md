# Zigeffect Required Status Check Enforcement Report Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a record-only required status check enforcement report policy tool that consumes report application-boundary artifacts and emits reviewed interpretation policy artifacts.

**Architecture:** Follow the existing required-status-check policy and enforcement-policy tool pattern. The new tool is a standalone Zig CLI with embedded tests, registered in `build.zig`, and discoverable through schema governance, hardening backlog, operations docs, roadmap docs, and README entries.

**Tech Stack:** Zig build system and `std.json`, Bun root verification, existing zigeffect causal tooling conventions.

---

## File Structure

- Create: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy.zig`
  - Owns CLI parsing, source artifact parsing, policy evaluation, JSON/text rendering, tests, and output path derivation.
- Create: `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-report-policy.md`
  - User-facing command, authority boundary, output fields, examples, and verification commands.
- Modify: `packages/zigeffect/build.zig`
  - Registers the executable, build step, and test artifact.
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
  - Adds schema governance entry and schema-count assertions.
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Marks the application-boundary dependency complete, adds the report-policy item, updates dependency order, commands, recommendation, and tests.
- Modify: `packages/zigeffect/docs/schema-governance.md`
  - Documents the schema contract.
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
  - Adds the delivered report-policy item and new conservative next branch.
- Modify: `packages/zigeffect/docs/roadmap.md`
  - Adds the report-policy milestone.
- Modify: `packages/zigeffect/docs/operations.md`
  - Adds operational usage and authority constraints.
- Modify: `packages/zigeffect/README.md`
  - Adds the tool to the CLI surface.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Marks branch 42 delivered and names the backlog refresh handoff.

### Task 1: Write Failing Tool Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy.zig`

- [x] **Step 1: Add a test-first Zig file**

Create the file with constants, temporary type declarations, and tests that describe the full desired behavior. The implementation functions should be absent or return minimal blocked values so the tests fail for behavior, not syntax.

```zig
const std = @import("std");

pub const production_telemetry_ci_gate_required_status_check_enforcement_report_policy_schema =
    "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-policy.v1";
pub const production_telemetry_ci_gate_required_status_check_enforcement_report_policy_schema_version: u32 = 1;
pub const source_branch =
    "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy";
pub const recommendation = "refresh-production-hardening-backlog";
pub const next_branch_if_ready =
    "codex/zigeffect-causal-production-hardening-backlog-refresh";

test "required status check enforcement report policy schema and branch constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-policy.v1",
        production_telemetry_ci_gate_required_status_check_enforcement_report_policy_schema,
    );
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_required_status_check_enforcement_report_policy_schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
        source_branch,
    );
    try std.testing.expectEqualStrings("refresh-production-hardening-backlog", recommendation);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-production-hardening-backlog-refresh",
        next_branch_if_ready,
    );
}
```

Add tests with these exact names:

```zig
test "parses required status check enforcement report policy options" {}
test "default output path replaces report application boundary suffix" {}
test "approved planned report application boundary yields ready policy without published report readiness" {}
test "approved applied report application boundary yields published report policy readiness" {}
test "blocked reject missing verification failed checks and authority enabled sources block policy" {}
test "reports include required policy fields and guidance" {}
```

- [x] **Step 2: Run the failing tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy.zig
```

Expected: FAIL because `parseOptions`, `outputPathsForOptions`, `evaluatePolicy`, and `formatReports` are not implemented.

### Task 2: Implement The Policy Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy.zig`

- [x] **Step 1: Add CLI model and parser**

Implement:

```zig
const source_application_boundary_schema =
    "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1";
const generated_by =
    "causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy";

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary",
    "zig build causal-artifacts",
    "zig build release-gate --summary none",
    "zig build release-gate-report",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const Decision = enum { approve, reject };
const PolicyStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };
```

Implement `Options` with:

```zig
application_boundary_path: []const u8,
decision: Decision,
reviewed_by: []const u8 = "ci-gate-required-status-check-enforcement-report-policy-reviewer",
policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
reason: []const u8,
verified_commands: []const []const u8 = &.{},
out_prefix: ?[]const u8 = null,
```

Parser contract:

```sh
--from-application-boundary <path.json> approve|reject --reason <reason>
```

with optional `--by`, `--policy`, repeated `--verified-command`, and `--out-prefix`.

- [x] **Step 2: Add source and result structs**

Implement source structs with unknown-field tolerant parsing:

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

const ApplicationBoundaryArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_enforcement_report: []const u8 = "",
    source_report_status: []const u8 = "",
    mode: []const u8,
    report_application_boundary_status: []const u8,
    applied: bool,
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
    application_changes: []const []const u8 = &.{},
    before_evidence: []const []const u8 = &.{},
    after_evidence: []const []const u8 = &.{},
    application_checks: []const SourceCheck = &.{},
    denied_application_claims: []const []const u8 = &.{},
    negative_fixtures: []const SourceNegativeFixture = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};
```

Result struct:

```zig
const PolicyResult = struct {
    status: PolicyStatus,
    ready_for_next_branch: bool,
    published_report_policy_ready: bool,
    checks: []const PolicyCheck,
};
```

- [x] **Step 3: Implement checks**

`evaluatePolicy` must append these check names:

```text
source-schema
source-boundary-status-valid
source-application-state-consistent
source-tool-authority-disabled
source-runtime-and-storage-disabled
source-checks-passed
source-catalogs-present
source-verification-recorded
reviewer-decision-approved
policy-verification-recorded
release-gate-verification-recorded
interpretation-policy-present
evidence-requirements-present
negative-fixtures-present
```

Rules:

```zig
ready_for_next_branch = allChecksPassed(checks);
published_report_policy_ready =
    ready_for_next_branch and
    std.mem.eql(u8, source.report_application_boundary_status, "applied") and
    std.mem.eql(u8, source.mode, "record-applied") and
    source.applied;
```

Planned source consistency:

```zig
report_application_boundary_status == "planned"
mode == "plan"
applied == false
mutation_authority == "none"
```

Applied source consistency:

```zig
report_application_boundary_status == "applied"
mode == "record-applied"
applied == true
mutation_authority == "record-only"
application_changes.len > 0
before_evidence.len > 0
after_evidence.len > 0
```

- [x] **Step 4: Render JSON and text**

JSON fields must include:

```text
schema
schema_version
source_report_application_boundary
source_report_application_boundary_status
source_mode
source_applied
decision
reviewed_by
policy
reason
required_status_check_enforcement_report_policy_status
ready_for_next_branch
published_report_policy_ready
ci_gate_enabled
ci_gate_enforcement_enabled
ci_required_status_check_enabled
ci_workflow_mutation_enabled
ci_upload_execution_enabled
ci_report_publication_enabled
github_api_mutation_enabled
github_check_run_creation_enabled
branch_protection_mutation_by_tool_enabled
github_step_summary_write_enabled
pull_request_comment_enabled
production_telemetry_ingestion
live_exporter_enabled
network_send_enabled
collector_endpoint_configured
otlp_serialization_enabled
runtime_pipeline_enabled
durable_write_enabled
nendb_write_enabled
mutation_authority
report_interpretation_policy
evidence_requirements
checks
denied_inference_rules
negative_fixtures
blocked_claims
required_verification_commands
verified_commands
generated_by
source_branch
recommendation
next_branch_if_ready
json_output
text_output
agent_guidance
```

Text output must include human-readable equivalents and the check list.

- [x] **Step 5: Run the green tool tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy.zig
```

Expected: PASS with all report-policy tests.

### Task 3: Register Build Step

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [x] **Step 1: Add the module, executable, run step, and tests**

Add the new tool near the report application-boundary registration:

```zig
const causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool = b.addExecutable(.{
    .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
    .root_module = causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool_module,
});
const run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool);
if (b.args) |args| run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool.addArgs(args);
const causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_step = b.step("causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy", "Review production telemetry CI gate required status check enforcement report policy");
causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool.step);

const causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy-tests",
    .root_module = causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool_module,
});
const run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool_tests);
test_step.dependOn(&run_causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy_tool_tests.step);
```

- [x] **Step 2: Verify build help**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy -- --help
```

Expected: usage string for the new tool.

### Task 4: Update Governance, Backlog, And Docs

**Files:**
- Create: `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-report-policy.md`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [x] **Step 1: Add schema governance**

Add schema entry:

```zig
.{
    .schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-policy.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy"},
    .consumed_by = &.{"agents", "reviewers", "production-hardening backlog", "future production hardening backlog refresh"},
    .compatibility = &.{ "strict-v1", "record-only", "required-status-check-enforcement-report-policy", "interpretation-policy", "planned-or-applied-source", "published-report-interpretation", "local-artifact-only", "no-tool-github-api-mutation", "no-tool-branch-protection-mutation", "no-tool-workflow-mutation", "no-tool-check-run-creation", "no-tool-ci-upload", "no-tool-github-step-summary-write", "no-tool-pr-comment", "no-live-ingestion", "no-durable-write", "no-nendb-write" },
    .governance_requirements = &.{ "source report application-boundary checks", "planned source interpretation tests", "applied source interpretation tests", "denied publication inference tests", "policy verification checks", "next-branch backlog refresh handoff" },
}
```

Increase schema count by one and add tests for text and JSON output containing the new schema.

- [x] **Step 2: Add backlog item and recommendation**

Add item id:

```text
production-telemetry-ci-gate-required-status-check-enforcement-report-policy
```

Set the backlog recommendation to:

```zig
pub const recommendation = "refresh-production-hardening-backlog";
pub const recommended_next_branch = "codex/zigeffect-causal-production-hardening-backlog-refresh";
```

Add this branch to dependency order and command catalog:

```sh
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy -- --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.json approve --reason "required status check enforcement report policy reviewed" --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary" --verified-command "zig build causal-artifacts" --verified-command "zig build release-gate --summary none" --verified-command "zig build release-gate-report" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy -- --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary-negative.json reject --reason "negative required status check enforcement report policy path" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-policy-negative
```

- [x] **Step 3: Update docs**

Write docs that state:

- source schema and output schema;
- planned versus applied source interpretation;
- `published_report_policy_ready` meaning;
- disabled mutation and production authority fields;
- CLI examples for approve and reject;
- verification commands;
- next branch is backlog refresh, not production rollout.

- [x] **Step 4: Run docs and governance checks**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected:

- schema count increases by one;
- backlog recommendation is `refresh-production-hardening-backlog`;
- recommended next branch is `codex/zigeffect-causal-production-hardening-backlog-refresh`.

### Task 5: Verify CLI Artifacts And Full Build

**Files:**
- All modified files from Tasks 2 through 4.

- [x] **Step 1: Run positive and negative CLI paths**

Run positive path:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.json \
  approve \
  --reason "required status check enforcement report policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Expected with current local artifacts: if the source application-boundary artifact is blocked, the policy artifact exits successfully but records `required_status_check_enforcement_report_policy_status=blocked`, `ready_for_next_branch=false`, and `published_report_policy_ready=false`.

Run negative path:

```sh
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary-negative.json \
  reject \
  --reason "negative required status check enforcement report policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-policy-negative
```

Expected: blocked output with reviewer rejection and missing verification checks.

- [x] **Step 2: Run focused and full verification**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy.zig
zig test tools/causal_production_hardening_backlog.zig
zig build examples
zig build test
zig fmt --check build.zig \
  tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy.zig \
  tools/causal_schema_governance.zig \
  tools/causal_production_hardening_backlog.zig
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: all commands exit 0.

- [x] **Step 3: Commit implementation**

Run:

```sh
git status --short --branch
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  packages/zigeffect/README.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-report-policy.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git diff --cached --check
git diff --cached --stat
git commit -m "feat(zigeffect): add required status check enforcement report policy"
```

Expected: implementation commit includes only the report-policy code and docs.
