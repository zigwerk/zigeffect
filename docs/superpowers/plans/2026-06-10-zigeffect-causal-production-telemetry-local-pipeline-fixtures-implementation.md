# zigeffect Causal Production Telemetry Local Pipeline Fixtures Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a fixture-only local telemetry pipeline artifact that consumes an approved exporter-boundary artifact and hands off to NenDB retention fixtures without enabling runtime telemetry.

**Architecture:** Add one deterministic Zig tool that parses exporter-boundary JSON, evaluates local fixture checks, and emits text/JSON fixture artifacts. Wire it through `build.zig`, schema governance, docs, and the production hardening backlog while preserving `mutation_authority=none`, disabled network/collector/OTLP authority, disabled runtime pipeline authority, NenDB-only durable scope, and SolidJS `zig-webui` workbench direction.

**Tech Stack:** Zig 0.16 build modules/tests, zigeffect causal artifact conventions, Bun verification commands, Markdown docs.

---

## File Structure

- Create `packages/zigeffect/tools/causal_production_telemetry_local_pipeline_fixtures.zig`: CLI parser, boundary JSON parser, local fixture evaluator, text/JSON formatters, and unit tests.
- Modify `packages/zigeffect/build.zig`: register the new executable, build step, examples dependency, and tests after exporter-boundary wiring.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`: register schema `zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1`, update schema count tests, and add report assertions.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`: mark local-pipeline-fixtures delivered, update recommendation/next branch to NenDB retention fixtures, add dependency order and verification commands.
- Create `packages/zigeffect/docs/production-telemetry-local-pipeline-fixtures.md`: command contract, fixture-only boundary, statuses, checks, fixture catalog, validation checks, output paths, agent guidance, and verification commands.
- Modify existing zigeffect docs and roadmap files listed in the design spec so the current next branch becomes `codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures`.
- Modify `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`: add the delivered local-pipeline-fixtures milestone and NenDB-retention-fixtures handoff.

## Task 1: Red Test For Local Pipeline Fixture Tool Contract

**Files:**

- Create: `packages/zigeffect/tools/causal_production_telemetry_local_pipeline_fixtures.zig`

- [ ] **Step 1: Add a compileable red-test scaffold**

Create the file with only constants and red tests:

```zig
const std = @import("std");

pub const production_telemetry_local_pipeline_fixtures_schema = "zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1";
pub const production_telemetry_local_pipeline_fixtures_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures";
pub const recommendation = "start-production-telemetry-nendb-retention-fixtures";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures";

test "local pipeline fixture schema and authority constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1", production_telemetry_local_pipeline_fixtures_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_local_pipeline_fixtures_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-nendb-retention-fixtures", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures", next_branch_if_ready);
    return error.ExpectedRedFailure;
}

test "parses approve fixture options with verified commands and output prefix" {
    return error.ExpectedRedFailure;
}

test "rejects missing boundary path decision and reason" {
    return error.ExpectedRedFailure;
}

test "derives local pipeline output paths from boundary json path" {
    return error.ExpectedRedFailure;
}

test "ready and blocked local pipeline reports preserve fixture-only authority" {
    return error.ExpectedRedFailure;
}
```

- [ ] **Step 2: Run the focused red test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_local_pipeline_fixtures.zig
```

Expected: FAIL with `ExpectedRedFailure`.

## Task 2: Implement Parser, Evaluator, And Reports

**Files:**

- Modify: `packages/zigeffect/tools/causal_production_telemetry_local_pipeline_fixtures.zig`

- [ ] **Step 1: Replace the scaffold with the full data model**

Use these core types:

```zig
const Decision = enum { approve, reject };
const FixtureStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    boundary_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "local-pipeline-reviewer",
    policy: []const u8 = "manual-production-telemetry-local-pipeline-fixtures",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,
};

const BoundaryCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8 = "",
};

const BoundarySummary = struct {
    source_contract_count: usize = 0,
    positive_fixture_count: usize = 0,
    negative_fixture_count: usize = 0,
    validation_check_count: usize = 0,
};

const BoundaryArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_proposal: []const u8 = "",
    source_readiness: []const u8 = "",
    source_fixtures: []const u8 = "",
    decision: []const u8,
    boundary_status: []const u8,
    approved_for_next_branch: bool,
    applied: bool,
    mutation_authority: []const u8,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    network_send_enabled: bool,
    collector_endpoint_configured: bool,
    otlp_serialization_enabled: bool,
    durable_write_enabled: bool,
    ci_gate_enabled: bool,
    proposal_summary: BoundarySummary = .{},
    checks: []const BoundaryCheck = &.{},
    exporter_boundary_contract: []const []const u8 = &.{},
    local_envelope_fixtures: []const []const u8 = &.{},
    implementation_gates: []const []const u8 = &.{},
    non_goals: []const []const u8 = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};
```

- [ ] **Step 2: Add parser and output path behavior**

Implement `parseOptions`, `parseDecision`, `outputPathsForOptions`, `main`,
`readRequiredArtifact`, `writeArtifact`, and `run` using the conventions from
`causal_production_telemetry_exporter_boundary.zig`.

Parser behavior:

- `--from-boundary <boundary.json>` is required.
- Input path must end with `.json`.
- Decision must be `approve` or `reject`.
- `--reason <reason>` is required and non-empty.
- `--by`, `--policy`, `--verified-command`, and `--out-prefix` are optional.
- Unknown flags and missing flag values fail closed.

- [ ] **Step 3: Add fixed fixture constants**

Use these constants:

```zig
const boundary_schema = "zigeffect.causal.production-telemetry-exporter-boundary.v1";
const generated_by = "causal-production-telemetry-local-pipeline-fixtures";
const applied = false;
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const durable_write_enabled = false;
const ci_gate_enabled = false;
const runtime_pipeline_enabled = false;
const local_pipeline_fixture_mode = true;

const exporter_boundary_approve_command =
    "zig build causal-production-telemetry-exporter-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json approve --reason \"proposal evidence reviewed for local pipeline fixtures\" --verified-command \"zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \\\"ready evidence reviewed for exporter boundary planning\\\" --verified-command \\\"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\\\\\"fixtures reviewed for implementation proposal\\\\\\\" --verified-command \\\\\\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-schema-governance -- --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-production-hardening-backlog -- --format json\\\\\\\" --verified-command \\\\\\\"zig build examples\\\\\\\" --verified-command \\\\\\\"zig build test\\\\\\\"\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"";

const required_verification_commands: []const []const u8 = &.{
    exporter_boundary_approve_command,
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};
```

- [ ] **Step 4: Add pipeline fixture catalog constants**

Use this catalog shape:

```zig
const PipelineFixture = struct {
    id: []const u8,
    input_envelope: []const u8,
    output_envelope: []const u8,
    output_fields: []const []const u8,
    blocked_fields: []const []const u8,
};

const pipeline_fixture_catalog: []const PipelineFixture = &.{
    .{
        .id = "runtime-span-normalized-envelope",
        .input_envelope = "runtime-span-event-envelope",
        .output_envelope = "runtime-span-local-json-envelope",
        .output_fields = &.{ "event_id", "trace_id_ref", "span_id_ref", "parent_span_id_ref", "causal_event_ref", "redaction_state", "sample_state" },
        .blocked_fields = &.{ "raw_payload", "headers", "prompts", "credentials", "raw_tenant_id", "raw_user_id", "collector_endpoint", "network_address" },
    },
    .{
        .id = "app-semantic-normalized-envelope",
        .input_envelope = "app-semantic-ref-envelope",
        .output_envelope = "app-semantic-local-json-envelope",
        .output_fields = &.{ "event_id", "domain_entity_ref", "schema_ref", "data_subject_ref", "operation_ref", "redaction_state", "sample_state" },
        .blocked_fields = &.{ "raw_request_body", "raw_response_body", "prompt_text", "credential_material", "raw_pii" },
    },
    .{
        .id = "backend-otel-local-envelope",
        .input_envelope = "backend-otel-record-envelope",
        .output_envelope = "backend-otel-local-json-envelope",
        .output_fields = &.{ "otel_schema_ref", "trace_id_ref", "span_id_ref", "attribute_refs", "redaction_state", "sample_state" },
        .blocked_fields = &.{ "collector_endpoint", "auth_headers", "wire_payload_bytes", "exporter_sdk_configuration" },
    },
    .{
        .id = "redaction-access-reviewed-envelope",
        .input_envelope = "redaction-access-envelope",
        .output_envelope = "redaction-access-local-json-envelope",
        .output_fields = &.{ "visibility_class", "redaction_state", "access_policy_ref", "denied_raw_fields" },
        .blocked_fields = &.{ "raw_secrets", "raw_credentials", "raw_headers", "raw_prompts", "raw_tenant_id", "raw_user_id" },
    },
    .{
        .id = "sampling-kept-envelope",
        .input_envelope = "sampling-boundary-envelope",
        .output_envelope = "sampling-kept-local-json-envelope",
        .output_fields = &.{ "sample_state=kept", "sample_policy_ref", "sample_reason" },
        .blocked_fields = &.{ "wall_clock_randomness", "production_traffic_rates", "production_capacity_claims" },
    },
    .{
        .id = "sampling-dropped-envelope",
        .input_envelope = "sampling-boundary-envelope",
        .output_envelope = "sampling-dropped-local-json-envelope",
        .output_fields = &.{ "sample_state=dropped", "sample_policy_ref", "retained_fields" },
        .blocked_fields = &.{ "unsampled_raw_payload_fields" },
    },
    .{
        .id = "correlation-link-envelope",
        .input_envelope = "runtime-span-event-envelope+app-semantic-ref-envelope+backend-otel-record-envelope+redaction-access-envelope+sampling-boundary-envelope",
        .output_envelope = "correlation-link-local-json-envelope",
        .output_fields = &.{ "event_id", "trace_id_ref", "causal_event_ref", "artifact_id_ref", "schema_ref" },
        .blocked_fields = &.{ "raw_payload_joins", "source_database_reads" },
    },
};
```

- [ ] **Step 5: Add validation check constants**

Use these validation check names:

```zig
const pipeline_validation_checks: []const []const u8 = &.{
    "fixture-references-source-envelope",
    "fixture-declares-output-envelope",
    "fixture-declares-redaction-state",
    "fixture-declares-sample-state",
    "raw-sensitive-fields-blocked",
    "network-and-exporter-fields-blocked",
    "otlp-protobuf-absent",
    "durable-write-fields-absent",
    "sampled-out-retains-metadata-only",
    "correlation-uses-refs-only",
};
```

- [ ] **Step 6: Implement fixture checks**

Implement `evaluateFixtures` with these checks:

- `boundary-schema`
- `boundary-status`
- `boundary-decision-approved`
- `fixture-decision`
- `decision-approved`
- `authority-boundary`
- `no-network-pipeline`
- `no-otlp-serialization`
- `no-durable-write`
- `source-chain-linked`
- `boundary-checks-passed`
- `boundary-contract-present`
- `envelope-fixtures-present`
- `pipeline-fixtures-present`
- `redaction-fixtures-present`
- `sampling-fixtures-present`
- `pipeline-validation-passed`
- `boundary-verification-recorded`
- `fixture-verification-recorded`
- `nendb-only-scope`
- `solid-webui-scope`

Return `FixtureStatus.ready` only when every check passes. Return
`FixtureStatus.blocked` otherwise.

- [ ] **Step 7: Implement text and JSON reports**

The JSON report must include:

```json
{
  "schema": "zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1",
  "schema_version": 1,
  "source_boundary": "<input path>",
  "source_proposal": "<boundary source_proposal>",
  "source_readiness": "<boundary source_readiness>",
  "source_fixtures": "<boundary source_fixtures>",
  "decision": "approve",
  "fixture_status": "ready",
  "ready_for_next_branch": true,
  "reviewed_by": "local-pipeline-reviewer",
  "policy": "manual-production-telemetry-local-pipeline-fixtures",
  "reason": "<reason>",
  "applied": false,
  "mutation_authority": "none",
  "production_telemetry_ingestion": false,
  "live_exporter_enabled": false,
  "network_send_enabled": false,
  "collector_endpoint_configured": false,
  "otlp_serialization_enabled": false,
  "durable_write_enabled": false,
  "ci_gate_enabled": false,
  "runtime_pipeline_enabled": false,
  "local_pipeline_fixture_mode": true,
  "source_branch": "codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures",
  "recommendation": "start-production-telemetry-nendb-retention-fixtures",
  "next_branch_if_ready": "codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures",
  "checks": [],
  "pipeline_fixture_catalog": [],
  "pipeline_validation_checks": [],
  "implementation_gates": [],
  "non_goals": [],
  "blocked_claims": [],
  "required_verification_commands": [],
  "verified_commands": [],
  "agent_guidance": []
}
```

The text report must include the same fields with headings:

- `zigeffect production telemetry local pipeline fixtures`
- `fixture_status`
- `ready_for_next_branch`
- authority fields
- `pipeline fixture catalog`
- `pipeline validation checks`
- `checks`
- `required verification commands`
- `verified commands`
- `agent guidance`

- [ ] **Step 8: Add unit tests using a sample boundary artifact**

Create `sample_boundary_json` in the test section with:

- schema `zigeffect.causal.production-telemetry-exporter-boundary.v1`
- `source_proposal` ending in `.json`
- `source_readiness` ending in `.json`
- `source_fixtures` ending in `.json`
- `decision="approve"`
- `boundary_status="approved"`
- `approved_for_next_branch=true`
- all authority booleans false
- source checks with every exporter-boundary required check set to `pass`
- exporter boundary contract fields from the previous branch
- local envelope fixture names from the previous branch
- non-goals containing `Non-NenDB durable adapter work`, `Cockroach adapter work`, and `React or alternate renderer work`
- blocked claims containing `non-nendb-durable-storage`, `cockroach-adapter-work`, and `react-or-alternate-renderer`
- required and verified commands containing the exporter-boundary command, schema governance, backlog, examples, and test commands

Assert that approved reports contain:

- `"fixture_status": "ready"`
- `"ready_for_next_branch": true`
- `"runtime_pipeline_enabled": false`
- `"local_pipeline_fixture_mode": true`
- `"network_send_enabled": false`
- `"collector_endpoint_configured": false`
- `"otlp_serialization_enabled": false`
- `"pipeline_fixture_catalog"`
- `runtime-span-normalized-envelope`
- `sampling-dropped-envelope`
- `next branch if ready: codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures`

Assert that reject reports contain:

- `"fixture_status": "blocked"`
- `"ready_for_next_branch": false`
- `"runtime_pipeline_enabled": false`
- `"local_pipeline_fixture_mode": true`

- [ ] **Step 9: Run the focused green test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_local_pipeline_fixtures.zig
```

Expected: all tests pass.

## Task 3: Wire Build, Schema Governance, And Backlog

**Files:**

- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Register the build target**

In `packages/zigeffect/build.zig`, after exporter-boundary wiring, add:

```zig
const causal_production_telemetry_local_pipeline_fixtures_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_telemetry_local_pipeline_fixtures.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_production_telemetry_local_pipeline_fixtures_tool = b.addExecutable(.{
    .name = "zigeffect-causal-production-telemetry-local-pipeline-fixtures",
    .root_module = causal_production_telemetry_local_pipeline_fixtures_tool_module,
});
const run_causal_production_telemetry_local_pipeline_fixtures_tool = b.addRunArtifact(causal_production_telemetry_local_pipeline_fixtures_tool);
if (b.args) |args| run_causal_production_telemetry_local_pipeline_fixtures_tool.addArgs(args);
const causal_production_telemetry_local_pipeline_fixtures_step = b.step("causal-production-telemetry-local-pipeline-fixtures", "Review production telemetry local pipeline fixtures");
causal_production_telemetry_local_pipeline_fixtures_step.dependOn(&run_causal_production_telemetry_local_pipeline_fixtures_tool.step);

const causal_production_telemetry_local_pipeline_fixtures_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-production-telemetry-local-pipeline-fixtures-tests",
    .root_module = causal_production_telemetry_local_pipeline_fixtures_tool_module,
});
const run_causal_production_telemetry_local_pipeline_fixtures_tool_tests = b.addRunArtifact(causal_production_telemetry_local_pipeline_fixtures_tool_tests);
test_step.dependOn(&run_causal_production_telemetry_local_pipeline_fixtures_tool_tests.step);
```

Add the executable and test run artifact to `examples_step` after
exporter-boundary dependencies.

- [ ] **Step 2: Register schema governance**

In `causal_schema_governance.zig`, add a schema entry after exporter-boundary:

```zig
.{
    .schema = "zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-production-telemetry-local-pipeline-fixtures"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry NenDB retention fixtures" },
    .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "local-pipeline-fixtures", "fixtures-only", "no-live-ingestion", "no-network" },
    .governance_requirements = &.{ "fixture catalog tests", "boundary evidence checks", "redaction and sampling fixture checks", "next-branch handoff" },
},
```

Update schema count assertions from `55` to `56`. Add assertions for:

- `zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1`
- `local-pipeline-fixtures`
- `fixtures-only`

- [ ] **Step 3: Update production hardening backlog**

In `causal_production_hardening_backlog.zig`:

- Change `recommendation` to `start-production-telemetry-nendb-retention-fixtures`.
- Change `recommended_next_branch` to `codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures`.
- Add delivered backlog item `production-telemetry-local-pipeline-fixtures`.
- Add it to `dependency_order` after `production-telemetry-exporter-boundary`.
- Add approved and rejected local-pipeline verification commands after exporter-boundary commands.
- Update tests for constants, item presence, text output, JSON output, and command presence.

Use this backlog item:

```zig
.{
    .id = "production-telemetry-local-pipeline-fixtures",
    .title = "Production Telemetry Local Pipeline Fixtures",
    .gap_id = "production-telemetry-local-pipeline-fixtures",
    .priority = "P5",
    .status = "delivered",
    .summary = "Consumes an approved exporter-boundary artifact and emits fixture-only local envelope redaction sampling and correlation evidence before NenDB retention fixtures.",
    .depends_on = &.{ "production-telemetry-exporter-boundary", "production-telemetry-implementation-proposal", "production-telemetry-readiness-review" },
    .deliverables = &.{
        "approved and blocked local pipeline fixture artifacts",
        "local envelope fixture catalog",
        "redaction and access fixture checks",
        "sampling fixture checks",
        "NenDB retention fixtures handoff",
    },
    .evidence_sources = &.{
        "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-local-pipeline-fixtures-design.md",
        "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-local-pipeline-fixtures-implementation.md",
        "packages/zigeffect/tools/causal_production_telemetry_local_pipeline_fixtures.zig",
        "packages/zigeffect/docs/production-telemetry-local-pipeline-fixtures.md",
    },
    .branch = "codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures",
    .agent_guidance = "Use approved local pipeline fixture artifacts to start NenDB retention fixtures only; do not infer runtime telemetry ingestion, network send, collector configuration, OTLP serialization, durable writes, CI gates, non-NenDB adapters, alternate renderers, or mutation authority.",
},
```

- [ ] **Step 4: Run focused wiring tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_local_pipeline_fixtures.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json 2> ../../.zig-cache/causal-artifacts/schema-governance.json
rg '"schema_count": 56|production-telemetry-local-pipeline-fixtures' ../../.zig-cache/causal-artifacts/schema-governance.json
zig build causal-production-hardening-backlog -- --format json
```

Expected: all commands exit 0 and schema governance reports count 56.

## Task 4: Update Documentation

**Files:**

- Create: `packages/zigeffect/docs/production-telemetry-local-pipeline-fixtures.md`
- Modify: `packages/zigeffect/docs/production-telemetry-exporter-boundary.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/production-hardening-completion-audit.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Create local pipeline fixture docs**

Create `packages/zigeffect/docs/production-telemetry-local-pipeline-fixtures.md` with:

- title `zigeffect Causal Production Telemetry Local Pipeline Fixtures`
- command sequence from the design spec
- authority fields including `runtime_pipeline_enabled=false` and `local_pipeline_fixture_mode=true`
- fixture status definitions `ready` and `blocked`
- required checks list
- pipeline fixture catalog with seven fixture ids
- validation checks list
- output paths
- agent guidance
- verification commands

- [ ] **Step 2: Update existing docs and roadmap**

Update the current chain everywhere it is summarized:

```text
production-telemetry-capture-design
-> production-telemetry-capture-fixtures
-> production-telemetry-readiness-review
-> production-telemetry-implementation-proposal
-> production-telemetry-exporter-boundary
-> production-telemetry-local-pipeline-fixtures
-> production-telemetry-nendb-retention-fixtures
```

Update current next branch to:

```text
codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures
```

Update the master roadmap with:

```markdown
20. `codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures`
   - Delivered: `causal-production-telemetry-local-pipeline-fixtures` emits
     `zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1` with
     approved exporter-boundary consumption, local envelope fixture catalog,
     redaction and sampling validation checks, approved and blocked fixture
     artifacts, and NenDB-retention-fixtures handoff.
21. `codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures`
   - Current next branch: use approved local-pipeline fixture artifacts to map
     retained fixture records into NenDB node edge and retention records without
     writing durable production storage.
```

- [ ] **Step 3: Run doc consistency scans**

Run:

```sh
rg -n 'start-production-telemetry-local-pipeline-fixtures|recommended next branch: codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures|current next branch is `codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures`' packages/zigeffect/docs packages/zigeffect/README.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
rg -n 'production-telemetry-nendb-retention-fixtures|start-production-telemetry-nendb-retention-fixtures|production-telemetry-local-pipeline-fixtures.v1' packages/zigeffect/docs packages/zigeffect/README.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Expected: first command exits 1 or shows only historical exporter-boundary artifact guidance. Second command shows the new next branch and new schema in current roadmap locations.

## Task 5: Full Artifact Verification

**Files:**

- No source edits.

- [ ] **Step 1: Run approved artifact chain**

Run:

```sh
cd packages/zigeffect
set -e
mkdir -p ../../.zig-cache/causal-artifacts
zig build causal-production-telemetry-capture-fixtures -- --format json 2> ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json
zig build causal-production-telemetry-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json \
  approve \
  --reason "fixtures reviewed for implementation proposal" \
  --verified-command "zig build causal-production-telemetry-capture-fixtures -- validate --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
implementation_proposal_command='zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason "ready evidence reviewed for exporter boundary planning" --verified-command "zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-production-telemetry-capture-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"'
zig build causal-production-telemetry-implementation-proposal -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json \
  approve \
  --reason "ready evidence reviewed for exporter boundary planning" \
  --verified-command "zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-production-telemetry-capture-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-exporter-boundary -- \
  --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json \
  approve \
  --reason "proposal evidence reviewed for local pipeline fixtures" \
  --verified-command "$implementation_proposal_command" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
exporter_boundary_command='zig build causal-production-telemetry-exporter-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json approve --reason "proposal evidence reviewed for local pipeline fixtures" --verified-command "zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for exporter boundary planning\" --verified-command \"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"'
zig build causal-production-telemetry-local-pipeline-fixtures -- \
  --from-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json \
  approve \
  --reason "approved boundary reviewed for local pipeline fixtures" \
  --verified-command "$exporter_boundary_command" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
rg '"fixture_status": "ready"|"ready_for_next_branch": true|"runtime_pipeline_enabled": false|"local_pipeline_fixture_mode": true|"next_branch_if_ready": "codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures"' ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json
```

Expected: command exits 0 and `rg` finds all expected approved fields.

- [ ] **Step 2: Run blocked artifact path**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-local-pipeline-fixtures -- \
  --from-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json \
  reject \
  --reason "negative local pipeline fixture path"
rg '"fixture_status": "blocked"|"ready_for_next_branch": false|"runtime_pipeline_enabled": false|"local_pipeline_fixture_mode": true' ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json
```

Expected: command exits 0 and `rg` finds all expected blocked fields.

- [ ] **Step 3: Restore approved artifact for next branch handoff**

Re-run the approved local-pipeline command from Step 1 and confirm:

```sh
rg '"fixture_status": "ready"|"ready_for_next_branch": true' ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json
```

Expected: command exits 0.

## Task 6: Broad Verification And Commit

**Files:**

- No source edits.

- [ ] **Step 1: Run broad Zig checks**

Run:

```sh
cd packages/zigeffect
zig build examples
zig build test
```

Expected: both commands exit 0.

- [ ] **Step 2: Run repo checks**

Run:

```sh
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: all commands exit 0. Existing guarded live database tests may skip
when live services are unavailable, but no required test may fail.

- [ ] **Step 3: Review and commit**

Run:

```sh
git status --short
git diff --stat
git add packages/zigeffect/build.zig \
  packages/zigeffect/tools/causal_production_telemetry_local_pipeline_fixtures.zig \
  packages/zigeffect/tools/causal_schema_governance.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/docs/production-telemetry-local-pipeline-fixtures.md \
  packages/zigeffect/docs/production-telemetry-exporter-boundary.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/production-hardening-completion-audit.md \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/README.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): add production telemetry local pipeline fixtures"
```

Expected: commit succeeds on
`codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures`.

## Plan Self-Review

- Spec coverage: every design goal maps to tool behavior, build wiring, schema
  governance, backlog/docs updates, artifact verification, or broad checks.
- Completion scan: no unfinished markers or vague implementation steps remain.
- Type consistency: schema, command, branch, recommendation, status, and field
  names match the design spec.
- Scope check: runtime pipeline execution, live telemetry, network send,
  collector configuration, OTLP serialization, durable production writes,
  NenDB writes, non-NenDB adapters, React/alternate renderers, CI gates, and
  mutation authority are explicitly excluded.
