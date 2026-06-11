# Zigeffect Causal App-Facing Production Integration Audit Remediation Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the app-facing audit/remediation bridge artifact that consumes ready app-facing NenDB handoff fixtures and emits a record-only audit/remediation evidence bridge for agents and reviewers.

**Architecture:** Follow the existing zigeffect causal artifact CLI pattern: a standalone Zig tool owns parsing, validation, report formatting, file output, and focused in-file tests. The tool reads only the previous NenDB handoff JSON artifact, emits a strict v1 schema artifact, and keeps every mutation, write, adapter execution, production-health, deployment, and auto-apply authority disabled.

**Tech Stack:** Zig build tools, `std.json`, existing `packages/zigeffect/build.zig` build-step wiring, generated markdown docs, Bun root checks.

---

## File Structure

- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_audit_remediation_bridge.zig`
  - CLI, source handoff parser, audit/remediation bridge evaluator, JSON/text formatter, file writer, and unit tests.
- Modify: `packages/zigeffect/build.zig`
  - Add executable, build step, and tool test step named `causal-app-facing-production-integration-audit-remediation-bridge`.
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
  - Add schema entry and update schema-count assertions from 88 to 89.
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Mark the audit/remediation bridge delivered, update next recommendation to the SolidJS read-only preview branch, and add verification commands.
- Create: `packages/zigeffect/docs/app-facing-production-integration-audit-remediation-bridge.md`
  - User-facing docs for approved and rejected bridge artifacts.
- Modify: `packages/zigeffect/docs/app-facing-production-integration-nendb-handoff-fixtures.md`
  - Add a next-step section linking the handoff artifact to this bridge command.
- Modify: `packages/zigeffect/docs/schema-governance.md`
  - Regenerate with schema count 89 and the bridge schema entry.
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
  - Regenerate with the delivered bridge item and SolidJS read-only preview recommendation.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark branch 53 delivered and add branch 54 for app-facing SolidJS read-only preview.

## Task 1: Tool Red Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_audit_remediation_bridge.zig`

- [ ] **Step 1: Add constants and an intentional red test**

Create the file with this scaffold:

```zig
const std = @import("std");

pub const app_facing_production_integration_audit_remediation_bridge_schema = "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1";
pub const app_facing_production_integration_audit_remediation_bridge_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge";
pub const recommendation = "start-app-facing-production-integration-solid-webui-readonly-preview";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview";

test "app-facing audit remediation bridge constants preserve the branch boundary" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1", app_facing_production_integration_audit_remediation_bridge_schema);
    try std.testing.expectEqual(@as(u32, 1), app_facing_production_integration_audit_remediation_bridge_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-production-integration-solid-webui-readonly-preview", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview", next_branch_if_ready);
}

test "app-facing audit remediation bridge intentionally needs implementation" {
    return error.ExpectedRedFailure;
}
```

- [ ] **Step 2: Run the red test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_audit_remediation_bridge.zig
```

Expected: FAIL with `ExpectedRedFailure`.

- [ ] **Step 3: Replace the intentional failure with parser and output-path tests**

Add tests for missing handoff path, invalid extension, missing decision, and missing reason:

```zig
try std.testing.expectError(error.MissingHandoffPath, parseOptions(std.testing.allocator, &.{"tool"}));
try std.testing.expectError(error.UnknownFlag, parseOptions(std.testing.allocator, &.{ "tool", "--from-local-fixtures", "handoff.json", "approve", "--reason", "reviewed" }));
try std.testing.expectError(error.InvalidHandoffPath, parseOptions(std.testing.allocator, &.{ "tool", "--from-handoff", "handoff.txt", "approve", "--reason", "reviewed" }));
try std.testing.expectError(error.MissingDecision, parseOptions(std.testing.allocator, &.{ "tool", "--from-handoff", "handoff.json" }));
try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{ "tool", "--from-handoff", "handoff.json", "approve" }));
```

Add a successful parse case:

```zig
const parsed = try parseOptions(std.testing.allocator, &.{ "tool", "--from-handoff", "handoff.json", "approve", "--reason", "reviewed", "--verified-command", "zig build test" });
defer parsed.deinit(std.testing.allocator);
try std.testing.expectEqualStrings("handoff.json", parsed.handoff_path);
try std.testing.expectEqual(Decision.approve, parsed.decision);
try std.testing.expectEqualStrings("reviewed", parsed.reason);
try std.testing.expectEqual(@as(usize, 1), parsed.verified_commands.len);
try std.testing.expectEqualStrings("zig build test", parsed.verified_commands[0]);
```

Add output path expectations:

```zig
const parsed = try parseOptions(std.testing.allocator, &.{ "tool", "--from-handoff", "handoff.json", "approve", "--reason", "reviewed" });
defer parsed.deinit(std.testing.allocator);
const paths = try outputPathsForOptions(std.testing.allocator, parsed);
defer paths.deinit(std.testing.allocator);
try std.testing.expectEqualStrings("handoff-audit-remediation-bridge.json", paths.json_path);
try std.testing.expectEqualStrings("handoff-audit-remediation-bridge.txt", paths.text_path);
```

- [ ] **Step 4: Run the parser tests red**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_audit_remediation_bridge.zig
```

Expected: FAIL because `Decision`, `parseOptions`, and `outputPathsForOptions` are missing.

## Task 2: Tool Core Implementation

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_audit_remediation_bridge.zig`
- Reference: `packages/zigeffect/tools/causal_app_facing_production_integration_nendb_handoff_fixtures.zig`
- Reference: `packages/zigeffect/tools/causal_app_facing_production_integration_local_fixtures.zig`

- [ ] **Step 1: Implement constants, option parsing, and source structs**

Use these constants:

```zig
const handoff_fixtures_schema = "zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1";
const generated_by = "causal-app-facing-production-integration-audit-remediation-bridge";
const applied = false;
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const durable_write_enabled = false;
const app_mutation_enabled = false;
const ci_gate_enabled = false;
const raw_payload_capture_enabled = false;
const app_config_write_enabled = false;
const app_data_write_enabled = false;
const deployment_mutation_enabled = false;
const nendb_write_enabled = false;
const nendb_adapter_execution_enabled = false;
const app_runtime_integration_enabled = false;
const agent_query_live_projection_enabled = false;
const solid_webui_preview_enabled = false;
const audit_remediation_bridge_mode = true;
const mutation_proof_claim_enabled = false;
const auto_apply_enabled = false;
const production_health_claim_enabled = false;
```

Implement:

```zig
const Decision = enum { approve, reject };
const BridgeStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    handoff_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "audit-remediation-bridge-reviewer",
    policy: []const u8 = "manual-app-facing-production-integration-audit-remediation-bridge",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        if (self.verified_commands.len > 0) allocator.free(self.verified_commands);
    }
};

const OutputPaths = struct {
    json_path: []const u8,
    text_path: []const u8,

    fn deinit(self: OutputPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json_path);
        allocator.free(self.text_path);
    }
};
```

Mirror the previous source artifact with a `HandoffArtifact` struct containing:

```zig
schema: []const u8,
schema_version: u32,
source_boundary: []const u8 = "",
source_proposal: []const u8 = "",
source_readiness: []const u8 = "",
source_fixtures: []const u8 = "",
decision: []const u8,
nendb_handoff_status: []const u8,
ready_for_next_branch: bool,
applied: bool,
mutation_authority: []const u8,
production_telemetry_ingestion: bool,
live_exporter_enabled: bool,
network_send_enabled: bool,
collector_endpoint_configured: bool,
otlp_serialization_enabled: bool,
durable_write_enabled: bool,
app_mutation_enabled: bool,
ci_gate_enabled: bool,
raw_payload_capture_enabled: bool,
app_config_write_enabled: bool,
app_data_write_enabled: bool,
deployment_mutation_enabled: bool,
nendb_write_enabled: bool,
nendb_adapter_execution_enabled: bool,
app_runtime_integration_enabled: bool,
agent_query_live_projection_enabled: bool,
solid_webui_preview_enabled: bool,
local_fixture_mode: bool,
nendb_handoff_fixture_mode: bool,
checks: []const HandoffCheck = &.{},
nendb_handoff_fixtures: []const HandoffFixture = &.{},
handoff_validation_checks: []const []const u8 = &.{},
required_verification_commands: []const []const u8 = &.{},
verified_commands: []const []const u8 = &.{},
```

- [ ] **Step 2: Run parser tests green**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_audit_remediation_bridge.zig
```

Expected: constants, parse, and output path tests pass.

- [ ] **Step 3: Add evaluator/report red tests**

Add a sample ready handoff JSON artifact with:

- schema `zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1`
- `nendb_handoff_status="ready"`
- `ready_for_next_branch=true`
- `decision="approve"`
- all source authority booleans disabled
- `local_fixture_mode=true`
- `nendb_handoff_fixture_mode=true`
- all required source check names present as `pass`
- `nendb_handoff_fixtures` containing the nine handoff fixture ids
- `handoff_validation_checks` containing every required source validation name
- source `required_verification_commands` and `verified_commands` matching

Assert an approved report contains:

```zig
try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1\"") != null);
try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"audit_remediation_bridge_status\": \"ready\"") != null);
try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": true") != null);
try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"audit_remediation_bridge_mode\": true") != null);
try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation_proof_claim_enabled\": false") != null);
try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"auto_apply_enabled\": false") != null);
try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"nendb_adapter_execution_enabled\": false") != null);
try std.testing.expect(std.mem.indexOf(u8, reports.json, "audit-chain-comparison-review-bridge") != null);
try std.testing.expect(std.mem.indexOf(u8, reports.json, "remediation-review-policy-gate-bridge") != null);
try std.testing.expect(std.mem.indexOf(u8, reports.json, "solid-webui-review-preview-bridge") != null);
```

Assert a rejected report contains:

```zig
try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"audit_remediation_bridge_status\": \"blocked\"") != null);
try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": false") != null);
try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"app_data_write_enabled\": false") != null);
```

- [ ] **Step 4: Run evaluator tests red**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_audit_remediation_bridge.zig
```

Expected: FAIL because `formatReports` and evaluator helpers are missing.

- [ ] **Step 5: Implement evaluator and report structs**

Implement:

```zig
const BridgeRecord = struct {
    id: []const u8,
    source_handoff_fixture: []const u8,
    audit_ref: []const u8,
    remediation_ref: []const u8,
    bridge_kind: []const u8,
    review_state: []const u8,
    retained_refs: []const []const u8,
    blocked_claims: []const []const u8,
};

const BridgeCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const BridgeResult = struct {
    status: BridgeStatus,
    ready_for_next_branch: bool,
    checks: []const BridgeCheck,
    source_boundary: []const u8,
    source_proposal: []const u8,
    source_readiness: []const u8,
    source_fixtures: []const u8,

    fn deinit(self: BridgeResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};
```

Add `audit_remediation_bridge_records` with exactly these ids:

```zig
const audit_remediation_bridge_records = [_]BridgeRecord{
    .{ .id = "audit-chain-comparison-review-bridge", .source_handoff_fixture = "nendb-audit-remediation-node-handoff-fixture", .audit_ref = "audit_chain_ref", .remediation_ref = "remediation_review_ref", .bridge_kind = "audit-chain-comparison", .review_state = "review-only", .retained_refs = &.{ "audit_chain_ref", "comparison_ref", "nendb-runtime-to-audit-remediation-edge-handoff-fixture" }, .blocked_claims = &.{ "mutation-proof", "fixed-claim", "deployed-claim" } },
    .{ .id = "remediation-review-policy-gate-bridge", .source_handoff_fixture = "nendb-audit-remediation-node-handoff-fixture", .audit_ref = "policy_gate_ref", .remediation_ref = "remediation_review_ref", .bridge_kind = "remediation-policy-gate", .review_state = "review-only", .retained_refs = &.{ "remediation_review_ref", "policy_gate_ref", "review_status_ref" }, .blocked_claims = &.{ "auto-apply", "app-config-write", "app-data-write" } },
    .{ .id = "runtime-to-remediation-evidence-bridge", .source_handoff_fixture = "nendb-runtime-to-audit-remediation-edge-handoff-fixture", .audit_ref = "runtime_trace_ref", .remediation_ref = "remediation_review_ref", .bridge_kind = "runtime-remediation-evidence", .review_state = "review-only", .retained_refs = &.{ "trace_id_ref", "causal_event_ref", "remediation_review_ref" }, .blocked_claims = &.{ "raw-payload-join", "source-database-read" } },
    .{ .id = "agent-query-to-remediation-next-query-bridge", .source_handoff_fixture = "nendb-runtime-to-agent-query-edge-handoff-fixture", .audit_ref = "agent_query_ref", .remediation_ref = "remediation_review_ref", .bridge_kind = "agent-query-remediation", .review_state = "review-only", .retained_refs = &.{ "trace_data_refs", "finding_refs", "next_query_refs", "remediation_review_ref" }, .blocked_claims = &.{ "raw-prompt", "raw-response", "unbounded-query" } },
    .{ .id = "solid-webui-review-preview-bridge", .source_handoff_fixture = "nendb-solid-webui-preview-node-handoff-fixture", .audit_ref = "solid_view_ref", .remediation_ref = "review_state_ref", .bridge_kind = "solid-webui-preview", .review_state = "read-only-preview-next", .retained_refs = &.{ "webui_sample_ref", "solid_view_ref", "review_state_ref" }, .blocked_claims = &.{ "live-dashboard-host", "app-mutation-button", "react-renderer", "alternate-renderer" } },
    .{ .id = "ci-advisory-remediation-report-bridge", .source_handoff_fixture = "nendb-ci-advisory-node-handoff-fixture", .audit_ref = "ci_artifact_ref", .remediation_ref = "advisory_status_ref", .bridge_kind = "ci-advisory-report", .review_state = "advisory-only", .retained_refs = &.{ "ci_artifact_ref", "advisory_status_ref", "review_state_ref" }, .blocked_claims = &.{ "required-status-check", "ci-enforcement", "workflow-mutation", "github-api-mutation" } },
};
```

Add evaluator checks in this order:

```zig
"handoff-schema"
"handoff-status"
"handoff-decision-approved"
"bridge-decision"
"decision-approved"
"authority-boundary"
"source-chain-linked"
"handoff-checks-passed"
"handoff-verification-recorded"
"handoff-catalog-present"
"audit-remediation-handoff-present"
"audit-chain-comparison-ref-present"
"remediation-review-ref-present"
"runtime-remediation-edge-present"
"agent-query-remediation-edge-present"
"solid-webui-review-preview-covered"
"ci-advisory-remediation-covered"
"bridge-catalog-present"
"bridge-validation-passed"
"bridge-verification-recorded"
"mutation-proof-disabled"
"auto-apply-disabled"
"app-writes-disabled"
"nendb-write-disabled"
"nendb-adapter-execution-disabled"
"durable-write-disabled"
"deployment-mutation-disabled"
"production-health-claim-disabled"
"nendb-only-scope"
"solid-webui-scope"
```

Add bridge validation names:

```zig
"source-handoff-ready"
"source-authority-disabled"
"source-handoff-catalog-covered"
"audit-remediation-node-handoff-present"
"runtime-to-audit-remediation-edge-present"
"audit-chain-comparison-ref-present"
"remediation-review-ref-present"
"runtime-remediation-evidence-linked"
"agent-query-remediation-evidence-linked"
"solid-webui-review-preview-linked"
"ci-advisory-remediation-linked"
"mutation-proof-disabled"
"auto-apply-disabled"
"app-writes-disabled"
"nendb-write-disabled"
"nendb-adapter-execution-disabled"
"durable-write-disabled"
"deployment-mutation-disabled"
"production-health-claim-disabled"
"raw-sensitive-fields-blocked"
"production-mutation-fields-blocked"
"non-nendb-scope-rejected"
"cockroach-scope-rejected"
"solid-webui-readonly-preview-next-only"
```

- [ ] **Step 6: Run evaluator tests green**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_audit_remediation_bridge.zig
```

Expected: all tool tests pass.

## Task 3: CLI Output and Build Step Wiring

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_audit_remediation_bridge.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Implement JSON/text formatting and file output**

Add `formatBridgeJson`, `formatBridgeText`, `formatReports`, `run`, and `main` using the same ownership pattern as `causal_app_facing_production_integration_nendb_handoff_fixtures.zig`.

The JSON report must include:

```json
{
  "schema": "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1",
  "schema_version": 1,
  "generated_by": "causal-app-facing-production-integration-audit-remediation-bridge",
  "source_branch": "codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge",
  "recommendation": "start-app-facing-production-integration-solid-webui-readonly-preview",
  "next_branch_if_ready": "codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview",
  "audit_remediation_bridge_status": "ready",
  "ready_for_next_branch": true,
  "applied": false,
  "mutation_authority": "none",
  "audit_remediation_bridge_records": []
}
```

The text report must include:

```text
Zigeffect Causal App-Facing Production Integration Audit Remediation Bridge
schema: zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1
status: ready
recommendation: start-app-facing-production-integration-solid-webui-readonly-preview
next branch: codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview
applied: false
mutation authority: none
```

- [ ] **Step 2: Run the tool tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_audit_remediation_bridge.zig
```

Expected: all tool tests pass.

- [ ] **Step 3: Add the build executable and test step**

In `packages/zigeffect/build.zig`, add the executable near the other app-facing production integration tools:

```zig
const causal_app_facing_production_integration_audit_remediation_bridge_exe = b.addExecutable(.{
    .name = "zigeffect-causal-app-facing-production-integration-audit-remediation-bridge",
    .root_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_audit_remediation_bridge.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
const causal_app_facing_production_integration_audit_remediation_bridge_run = b.addRunArtifact(causal_app_facing_production_integration_audit_remediation_bridge_exe);
if (b.args) |args| causal_app_facing_production_integration_audit_remediation_bridge_run.addArgs(args);
const causal_app_facing_production_integration_audit_remediation_bridge_step = b.step("causal-app-facing-production-integration-audit-remediation-bridge", "Review app-facing production integration audit/remediation bridge");
causal_app_facing_production_integration_audit_remediation_bridge_step.dependOn(&causal_app_facing_production_integration_audit_remediation_bridge_run.step);

const causal_app_facing_production_integration_audit_remediation_bridge_tests = b.addTest(.{
    .name = "zigeffect-causal-app-facing-production-integration-audit-remediation-bridge-tests",
    .root_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_facing_production_integration_audit_remediation_bridge.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
test_step.dependOn(&b.addRunArtifact(causal_app_facing_production_integration_audit_remediation_bridge_tests).step);
```

- [ ] **Step 4: Verify build wiring**

Run:

```sh
cd packages/zigeffect
zig build test
```

Expected: package test build succeeds and includes the new tool test step.

## Task 4: Governance, Backlog, Docs, and Roadmap

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-audit-remediation-bridge.md`
- Modify: `packages/zigeffect/docs/app-facing-production-integration-nendb-handoff-fixtures.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add the schema governance entry**

Add this entry after the NenDB handoff schema:

```zig
.{
    .schema = "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1",
    .version = 1,
    .category = "app-runtime",
    .status = "current",
    .emitted_by = &.{"causal-app-facing-production-integration-audit-remediation-bridge"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future app-facing SolidJS read-only preview", "future guarded app remediation planning" },
    .compatibility = &.{ "strict-v1", "record-only", "audit-remediation-bridge", "evidence-only", "nendb-handoff-fixture-source", "no-cockroach", "no-live-telemetry", "no-production-mutation", "no-nendb-write", "no-auto-apply" },
    .governance_requirements = &.{ "bridge tests", "NenDB handoff artifact checks", "audit/remediation bridge catalog checks", "verification command evidence", "next-branch handoff", "docs update" },
},
```

Update tests that assert schema count from 88 to 89 and add an assertion that JSON output contains the bridge schema.

- [ ] **Step 2: Run schema governance tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_schema_governance.zig
```

Expected: schema governance tests pass with count 89.

- [ ] **Step 3: Add the backlog item and next recommendation**

Append a delivered backlog item after `app-facing-production-integration-nendb-handoff-fixtures`:

```zig
.{
    .id = "app-facing-production-integration-audit-remediation-bridge",
    .title = "App-Facing Production Integration Audit Remediation Bridge",
    .gap_id = "app-facing-production-integration-audit-remediation-bridge",
    .priority = "P1",
    .status = "delivered",
    .summary = "Consumes ready app-facing NenDB handoff fixtures and emits a record-only audit/remediation bridge linking audit-chain comparison refs, remediation review refs, runtime evidence refs, agent-query next-query refs, SolidJS read-only preview refs, and advisory CI refs without app writes or auto-apply authority.",
    .depends_on = &.{ "app-facing-production-integration-nendb-handoff-fixtures", "app-facing-production-integration-local-fixtures", "audit-chain-snapshot-compare", "agent-query-interface", "nendb-durable-history-hardening" },
    .deliverables = &.{ "audit-chain comparison review bridge", "remediation review policy gate bridge", "runtime-to-remediation evidence bridge", "agent-query-to-remediation next-query bridge", "SolidJS review preview bridge", "CI advisory remediation report bridge" },
    .evidence_sources = &.{
        "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-audit-remediation-bridge-design.md",
        "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-audit-remediation-bridge-implementation.md",
        "packages/zigeffect/tools/causal_app_facing_production_integration_audit_remediation_bridge.zig",
        "packages/zigeffect/docs/app-facing-production-integration-audit-remediation-bridge.md",
        "packages/zigeffect/docs/schema-governance.md",
    },
    .branch = "codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge",
    .agent_guidance = "Use ready audit/remediation bridge artifacts to start the app-facing SolidJS read-only preview only. Do not infer app runtime integration, live agent projection, raw payload capture, app mutation, NenDB production writes, NenDB adapter execution, Cockroach scope, CI enforcement, deployment mutation, production health, mutation proof, auto-apply, or applied=true.",
},
```

Update the recommendation constants to:

```zig
"start-app-facing-production-integration-solid-webui-readonly-preview"
"codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview"
```

Add verification commands:

```text
zig build causal-app-facing-production-integration-audit-remediation-bridge -- --from-handoff ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures.json approve --reason "ready app-facing NenDB handoff fixtures reviewed for audit remediation bridge" --verified-command "zig build causal-app-facing-production-integration-nendb-handoff-fixtures" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
zig build causal-app-facing-production-integration-audit-remediation-bridge -- --from-handoff ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures.json reject --reason "negative audit remediation bridge path" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-audit-remediation-bridge-negative
```

- [ ] **Step 4: Run backlog tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: backlog tests pass and mention the new bridge id plus SolidJS read-only preview recommendation.

- [ ] **Step 5: Add bridge docs**

Create `packages/zigeffect/docs/app-facing-production-integration-audit-remediation-bridge.md` with sections:

````markdown
# App-Facing Production Integration Audit Remediation Bridge

`causal-app-facing-production-integration-audit-remediation-bridge` consumes a ready app-facing NenDB handoff fixtures artifact and emits `zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1`.

## Authority Boundary

- `applied=false`
- `mutation_authority="none"`
- `nendb_write_enabled=false`
- `nendb_adapter_execution_enabled=false`
- `app_mutation_enabled=false`
- `auto_apply_enabled=false`
- `mutation_proof_claim_enabled=false`
- `production_health_claim_enabled=false`

## Approved Artifact

```sh
zig build causal-app-facing-production-integration-audit-remediation-bridge -- \
  --from-handoff ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures.json \
  approve \
  --reason "ready app-facing NenDB handoff fixtures reviewed for audit remediation bridge" \
  --verified-command "zig build causal-app-facing-production-integration-nendb-handoff-fixtures" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

## Rejected Artifact

```sh
zig build causal-app-facing-production-integration-audit-remediation-bridge -- \
  --from-handoff ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures.json \
  reject \
  --reason "negative audit remediation bridge path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-audit-remediation-bridge-negative
```
````

- [ ] **Step 6: Update the handoff docs and master roadmap**

In `packages/zigeffect/docs/app-facing-production-integration-nendb-handoff-fixtures.md`, add a "Next Step" section naming the audit/remediation bridge command and branch.

In `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`:

- mark branch 53 delivered with the bridge schema and docs;
- add branch 54 `codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview`;
- state branch 54 consumes ready bridge artifacts and builds only a read-only SolidJS preview model inside `webui-dev/zig-webui`.

- [ ] **Step 7: Regenerate generated docs**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance -- --format text 2> docs/schema-governance.md
zig build causal-production-hardening-backlog -- --format text 2> docs/production-hardening-backlog.md
```

Expected: generated docs include schema count 89 and next recommendation `start-app-facing-production-integration-solid-webui-readonly-preview`.

## Task 5: Artifact Generation and Full Verification

**Files:**
- Verify all modified files.

- [ ] **Step 1: Run package verification**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_audit_remediation_bridge.zig
zig test tools/causal_schema_governance.zig
zig test tools/causal_production_hardening_backlog.zig
zig build test
zig build examples
```

Expected: all commands exit 0.

- [ ] **Step 2: Generate and inspect the approved artifact**

Run:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-audit-remediation-bridge -- \
  --from-handoff ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures.json \
  approve \
  --reason "ready app-facing NenDB handoff fixtures reviewed for audit remediation bridge" \
  --verified-command "zig build causal-app-facing-production-integration-nendb-handoff-fixtures" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Then inspect:

```sh
rg -n '"audit_remediation_bridge_status": "ready"|"ready_for_next_branch": true|"audit_remediation_bridge_mode": true|"nendb_adapter_execution_enabled": false|solid-webui-review-preview-bridge' ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-audit-remediation-bridge.json
```

Expected: every searched string is present.

- [ ] **Step 3: Generate and inspect the rejected artifact**

Run:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-audit-remediation-bridge -- \
  --from-handoff ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures.json \
  reject \
  --reason "negative audit remediation bridge path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-audit-remediation-bridge-negative
```

Then inspect:

```sh
rg -n '"audit_remediation_bridge_status": "blocked"|"ready_for_next_branch": false|"applied": false|"auto_apply_enabled": false|"production_health_claim_enabled": false' ../../.zig-cache/causal-artifacts/app-facing-production-integration-audit-remediation-bridge-negative.json
```

Expected: every searched string is present.

- [ ] **Step 4: Run root verification**

Run:

```sh
bun run check
bun run zig:test
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 5: Review and commit**

Run:

```sh
git status --short
git diff --stat
git diff -- docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md packages/zigeffect/build.zig packages/zigeffect/tools/causal_schema_governance.zig packages/zigeffect/tools/causal_production_hardening_backlog.zig packages/zigeffect/docs/app-facing-production-integration-nendb-handoff-fixtures.md
git add packages/zigeffect/tools/causal_app_facing_production_integration_audit_remediation_bridge.zig packages/zigeffect/build.zig packages/zigeffect/tools/causal_schema_governance.zig packages/zigeffect/tools/causal_production_hardening_backlog.zig packages/zigeffect/docs/app-facing-production-integration-audit-remediation-bridge.md packages/zigeffect/docs/app-facing-production-integration-nendb-handoff-fixtures.md packages/zigeffect/docs/schema-governance.md packages/zigeffect/docs/production-hardening-backlog.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): add app-facing audit remediation bridge"
```

Expected: commit succeeds after full verification.
