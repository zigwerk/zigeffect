# zigeffect Causal Production Telemetry NenDB Retention Fixtures Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a fixture-only NenDB retention artifact that consumes ready local-pipeline telemetry fixtures and hands off to read-only workbench preview without writing NenDB records.

**Architecture:** Add one deterministic Zig tool that parses local-pipeline fixture JSON, validates authority boundaries, emits text/JSON NenDB mapping fixtures, and updates schema/backlog/docs. Preserve disabled runtime pipeline, network, OTLP, durable writes, NenDB writes, CI gates, non-NenDB adapter scope, alternate renderer scope, and mutation authority.

**Tech Stack:** Zig 0.16 build modules/tests, zigeffect causal artifact conventions, existing NenDB backend schemas, Bun verification commands, Markdown docs.

---

## File Structure

- Create `packages/zigeffect/tools/causal_production_telemetry_nendb_retention_fixtures.zig`: CLI parser, local-pipeline JSON parser, NenDB mapping fixture evaluator, text/JSON formatters, and unit tests.
- Modify `packages/zigeffect/build.zig`: register the new executable, build step, examples dependency, and tests after local-pipeline wiring.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`: register schema `zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1`, update schema count tests, and add report assertions.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`: mark `production-telemetry-nendb-retention-fixtures` delivered, update recommendation/next branch to workbench read-only preview, add dependency order and verification commands.
- Create `packages/zigeffect/docs/production-telemetry-nendb-retention-fixtures.md`: command contract, fixture-only boundary, statuses, NenDB mapping catalog, validation checks, output paths, agent guidance, and verification commands.
- Modify existing zigeffect docs and roadmap files so the current next branch becomes `codex/zigeffect-causal-production-telemetry-workbench-readonly-preview`.
- Modify `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`: add the delivered NenDB-retention-fixtures milestone and workbench-readonly-preview handoff.

## Task 1: Red Test For NenDB Retention Fixture Tool Contract

**Files:**

- Create: `packages/zigeffect/tools/causal_production_telemetry_nendb_retention_fixtures.zig`

- [ ] **Step 1: Add a compileable red-test scaffold**

Create the file with constants and red tests:

```zig
const std = @import("std");

pub const production_telemetry_nendb_retention_fixtures_schema = "zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1";
pub const production_telemetry_nendb_retention_fixtures_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures";
pub const recommendation = "start-production-telemetry-workbench-readonly-preview";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-workbench-readonly-preview";

test "nendb retention fixture schema and authority constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1", production_telemetry_nendb_retention_fixtures_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_nendb_retention_fixtures_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-workbench-readonly-preview", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-workbench-readonly-preview", next_branch_if_ready);
    return error.ExpectedRedFailure;
}

test "parses approve retention options with verified commands and output prefix" {
    return error.ExpectedRedFailure;
}

test "rejects missing local pipeline path decision and reason" {
    return error.ExpectedRedFailure;
}

test "derives nendb retention output paths from local pipeline json path" {
    return error.ExpectedRedFailure;
}

test "ready and blocked retention reports preserve fixture-only authority" {
    return error.ExpectedRedFailure;
}
```

- [ ] **Step 2: Run the focused red test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_nendb_retention_fixtures.zig
```

Expected: FAIL with five `ExpectedRedFailure` failures.

## Task 2: Implement Parser, Evaluator, And Reports

**Files:**

- Modify: `packages/zigeffect/tools/causal_production_telemetry_nendb_retention_fixtures.zig`

- [ ] **Step 1: Replace the scaffold with the full data model**

Use these core types and constants:

```zig
const local_pipeline_schema = "zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1";
const generated_by = "causal-production-telemetry-nendb-retention-fixtures";
const applied = false;
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const runtime_pipeline_enabled = false;
const durable_write_enabled = false;
const nendb_write_enabled = false;
const ci_gate_enabled = false;
const local_pipeline_fixture_mode = true;
const nendb_retention_fixture_mode = true;

const Decision = enum { approve, reject };
const RetentionFixtureStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    local_pipeline_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "nendb-retention-reviewer",
    policy: []const u8 = "manual-production-telemetry-nendb-retention-fixtures",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        if (self.verified_commands.len > 0) allocator.free(self.verified_commands);
    }
};

const SourceCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8 = "",
};

const SourceSummary = struct {
    source_contract_count: usize = 0,
    positive_fixture_count: usize = 0,
    negative_fixture_count: usize = 0,
    validation_check_count: usize = 0,
};

const LocalPipelineArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_boundary: []const u8 = "",
    source_proposal: []const u8 = "",
    source_readiness: []const u8 = "",
    source_fixtures: []const u8 = "",
    decision: []const u8,
    fixture_status: []const u8,
    ready_for_next_branch: bool,
    applied: bool,
    mutation_authority: []const u8,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    network_send_enabled: bool,
    collector_endpoint_configured: bool,
    otlp_serialization_enabled: bool,
    durable_write_enabled: bool,
    ci_gate_enabled: bool,
    runtime_pipeline_enabled: bool,
    local_pipeline_fixture_mode: bool,
    boundary_summary: SourceSummary = .{},
    checks: []const SourceCheck = &.{},
    pipeline_fixture_catalog: []const PipelineFixture = &.{},
    pipeline_validation_checks: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};
```

- [ ] **Step 2: Add parser and output path behavior**

Implement `parseOptions`, `parseDecision`, `outputPathsForOptions`, `main`,
`readRequiredArtifact`, `writeArtifact`, and `run` using the conventions from
`causal_production_telemetry_local_pipeline_fixtures.zig`.

Parser behavior:

- `--from-local-pipeline <local-pipeline.json>` is required.
- Input path must end with `.json`.
- Decision must be `approve` or `reject`.
- `--reason <reason>` is required and non-empty.
- `--by`, `--policy`, `--verified-command`, and `--out-prefix` are optional.
- Unknown flags and missing flag values fail closed.

- [ ] **Step 3: Add fixed verification command constants**

Use these required commands:

```zig
const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-local-pipeline-fixtures",
    "zig build causal-nendb-storage-backend",
    "zig build causal-durable-production-retention -- --format json",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};
```

- [ ] **Step 4: Add NenDB mapping fixture constants**

Use a catalog with these ids:

```zig
const NendbMappingFixture = struct {
    id: []const u8,
    source_envelope: []const u8,
    target_schema: []const u8,
    label: []const u8,
    retained_fields: []const []const u8,
    blocked_fields: []const []const u8,
};

const nendb_mapping_fixtures: []const NendbMappingFixture = &.{
    .{ .id = "nendb-runtime-event-node-fixture", .source_envelope = "runtime-span-normalized-envelope", .target_schema = "zigeffect.causal.nendb_node.v1", .label = "causal.telemetry.runtime_span", .retained_fields = &.{ "event_id_ref", "trace_id_ref", "span_id_ref", "parent_span_id_ref", "causal_event_ref", "redaction_state", "sample_state" }, .blocked_fields = &.{ "raw_payload", "headers", "prompts", "credentials", "raw_tenant_id", "raw_user_id", "collector_endpoint", "network_address" } },
    .{ .id = "nendb-app-semantic-node-fixture", .source_envelope = "app-semantic-normalized-envelope", .target_schema = "zigeffect.causal.nendb_node.v1", .label = "causal.telemetry.app_semantic", .retained_fields = &.{ "event_id_ref", "domain_entity_ref", "schema_ref", "data_subject_ref", "operation_ref", "redaction_state", "sample_state" }, .blocked_fields = &.{ "raw_request_body", "raw_response_body", "prompt_text", "credential_material", "raw_pii" } },
    .{ .id = "nendb-otel-attribute-node-fixture", .source_envelope = "backend-otel-local-envelope", .target_schema = "zigeffect.causal.nendb_node.v1", .label = "causal.telemetry.otel_ref", .retained_fields = &.{ "otel_schema_ref", "trace_id_ref", "span_id_ref", "attribute_refs", "redaction_state", "sample_state" }, .blocked_fields = &.{ "collector_endpoint", "auth_headers", "wire_payload_bytes", "exporter_sdk_configuration", "otlp_protobuf_bytes" } },
    .{ .id = "nendb-redaction-access-node-fixture", .source_envelope = "redaction-access-reviewed-envelope", .target_schema = "zigeffect.causal.nendb_node.v1", .label = "causal.telemetry.redaction_access", .retained_fields = &.{ "visibility_class", "redaction_state", "access_policy_ref", "denied_raw_fields" }, .blocked_fields = &.{ "raw_secrets", "raw_credentials", "raw_headers", "raw_prompts", "raw_tenant_id", "raw_user_id" } },
    .{ .id = "nendb-sampling-retention-node-fixture", .source_envelope = "sampling-kept-envelope+sampling-dropped-envelope", .target_schema = "zigeffect.causal.nendb_node.v1", .label = "causal.telemetry.sampling", .retained_fields = &.{ "sample_state", "sample_policy_ref", "sample_reason", "retained_fields" }, .blocked_fields = &.{ "unsampled_raw_payload_fields", "wall_clock_randomness", "production_traffic_rates", "production_capacity_claims" } },
    .{ .id = "nendb-correlation-edge-fixture", .source_envelope = "correlation-link-envelope", .target_schema = "zigeffect.causal.nendb_edge.v1", .label = "causal.telemetry.correlates", .retained_fields = &.{ "from_event_ref", "to_artifact_ref", "causal_event_ref", "trace_id_ref", "schema_ref" }, .blocked_fields = &.{ "raw_payload_joins", "source_database_reads" } },
    .{ .id = "nendb-retention-policy-record-fixture", .source_envelope = "durable-production-retention-policy", .target_schema = "zigeffect.causal.nendb-retention-report.v1", .label = "causal.telemetry.retention_policy", .retained_fields = &.{ "ttl_days=14", "max_events=4096", "compaction_trigger_events=2048", "compact_to_events=1024", "backup_required=true", "recovery_required=true" }, .blocked_fields = &.{ "production_byte_estimates", "production_cost_estimates", "live_deletion_decisions" } },
    .{ .id = "nendb-compaction-window-fixture", .source_envelope = "durable-production-retention-policy", .target_schema = "zigeffect.causal.nendb-retention-report.v1", .label = "causal.telemetry.compaction_window", .retained_fields = &.{ "compaction_required_ref", "preserve_run_roots", "preserve_terminal_failures", "preserve_governance_artifacts" }, .blocked_fields = &.{ "compaction_execution", "destructive_deletion" } },
    .{ .id = "nendb-backup-recovery-marker-fixture", .source_envelope = "durable-production-retention-policy", .target_schema = "zigeffect.causal.nendb-retention-report.v1", .label = "causal.telemetry.backup_recovery", .retained_fields = &.{ "backup_required", "recovery_required", "oldest_retained_event_id_ref", "newest_retained_event_id_ref", "lineage_recovery_check_ref" }, .blocked_fields = &.{ "backup_execution", "restore_execution", "live_credentials" } },
};
```

- [ ] **Step 5: Add retention validation check constants**

Use:

```zig
const retention_validation_checks: []const []const u8 = &.{
    "source-local-pipeline-ready",
    "source-authority-disabled",
    "source-fixture-catalog-covered",
    "nendb-node-mappings-present",
    "nendb-edge-mappings-present",
    "retention-policy-constants-match",
    "ttl-policy-record-only",
    "compaction-policy-record-only",
    "backup-recovery-markers-present",
    "nendb-write-disabled",
    "durable-write-disabled",
    "non-nendb-scope-rejected",
    "cockroach-scope-rejected",
    "workbench-preview-next-only",
};
```

- [ ] **Step 6: Implement fixture evaluation**

Implement checks named:

- `local-pipeline-schema`
- `local-pipeline-status`
- `local-pipeline-decision-approved`
- `retention-fixture-decision`
- `decision-approved`
- `authority-boundary`
- `no-network-retention`
- `no-otlp-serialization`
- `no-runtime-pipeline`
- `no-durable-write`
- `no-nendb-write`
- `source-chain-linked`
- `local-pipeline-checks-passed`
- `local-pipeline-verification-recorded`
- `mapping-fixtures-present`
- `nendb-node-mappings-present`
- `nendb-edge-mappings-present`
- `retention-policy-fixture-present`
- `retention-validation-passed`
- `nendb-only-scope`
- `solid-webui-scope`

`ready_for_next_branch` must be true only when every check passes.

- [ ] **Step 7: Implement text and JSON formatters**

Text output must include schema, source path, decision, status, authority
fields, mapping fixtures, validation checks, implementation gates, non-goals,
blocked claims, required commands, verified commands, and agent guidance.

JSON output must include the same data under stable machine-readable keys.

- [ ] **Step 8: Run the focused green test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_nendb_retention_fixtures.zig
```

Expected: PASS.

## Task 3: Build, Schema Governance, And Backlog Wiring

**Files:**

- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Wire the build target**

In `build.zig`, add module/executable/test wiring after
`causal-production-telemetry-local-pipeline-fixtures`.

Use target name:

```zig
"zigeffect-causal-production-telemetry-nendb-retention-fixtures"
```

Use build step:

```zig
"causal-production-telemetry-nendb-retention-fixtures"
```

Add the tool and test run to `examples_step` dependencies.

- [ ] **Step 2: Register schema governance**

Add this entry:

```zig
.{
    .schema = "zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-production-telemetry-nendb-retention-fixtures"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry workbench read-only preview" },
    .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "nendb-retention-fixtures", "fixtures-only", "no-live-ingestion", "no-network", "no-durable-write" },
    .governance_requirements = &.{ "NenDB mapping fixture tests", "local pipeline evidence checks", "retention policy checks", "next-branch handoff" },
},
```

Update schema count tests from `56` to `57`, and add assertions for the new
schema plus `nendb-retention-fixtures`.

- [ ] **Step 3: Update production hardening backlog**

Change:

```zig
pub const recommendation = "start-production-telemetry-workbench-readonly-preview";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-workbench-readonly-preview";
```

Add delivered item:

```zig
.{
    .id = "production-telemetry-nendb-retention-fixtures",
    .title = "Production Telemetry NenDB Retention Fixtures",
    .gap_id = "production-telemetry-nendb-retention-fixtures",
    .priority = "P6",
    .status = "delivered",
    .summary = "Consumes ready local-pipeline fixture artifacts and emits fixture-only NenDB node edge retention policy compaction backup and recovery mapping evidence.",
    .depends_on = &.{ "production-telemetry-local-pipeline-fixtures", "durable-production-retention" },
    .deliverables = &.{
        "approved and blocked NenDB retention fixture artifacts",
        "NenDB node mapping fixture catalog",
        "NenDB edge mapping fixture catalog",
        "retention policy fixture constants",
        "workbench read-only preview handoff",
    },
    .evidence_sources = &.{
        "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-nendb-retention-fixtures-design.md",
        "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-nendb-retention-fixtures-implementation.md",
        "packages/zigeffect/tools/causal_production_telemetry_nendb_retention_fixtures.zig",
        "packages/zigeffect/docs/production-telemetry-nendb-retention-fixtures.md",
    },
    .branch = "codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures",
    .agent_guidance = "Use ready NenDB retention fixture artifacts to start read-only workbench preview only; do not infer NenDB writes, durable production writes, live telemetry, CI gates, non-NenDB adapters, alternate renderers, or mutation authority.",
},
```

Append `production-telemetry-nendb-retention-fixtures` to dependency order.
Add approve/reject verification commands for the new tool.

- [ ] **Step 4: Run focused governance checks**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json 2> ../../.zig-cache/causal-artifacts/schema-governance.json
rg '"schema_count": 57|production-telemetry-nendb-retention-fixtures|nendb-retention-fixtures' ../../.zig-cache/causal-artifacts/schema-governance.json
zig build causal-production-hardening-backlog -- --format json 2> ../../.zig-cache/causal-artifacts/production-hardening-backlog.json
rg 'start-production-telemetry-workbench-readonly-preview|codex/zigeffect-causal-production-telemetry-workbench-readonly-preview|production-telemetry-nendb-retention-fixtures' ../../.zig-cache/causal-artifacts/production-hardening-backlog.json
```

Expected: all commands exit 0.

## Task 4: Documentation And Roadmap Updates

**Files:**

- Create: `packages/zigeffect/docs/production-telemetry-nendb-retention-fixtures.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/production-hardening-completion-audit.md`
- Modify: `packages/zigeffect/docs/production-telemetry-local-pipeline-fixtures.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Create dedicated feature docs**

Create `production-telemetry-nendb-retention-fixtures.md` with:

- command;
- authority boundary;
- status meanings;
- NenDB mapping catalog;
- retention validation checks;
- output paths;
- agent guidance;
- verification commands.

- [ ] **Step 2: Update schema docs**

Add compatibility posture `nendb-retention-fixtures` and a schema section for
`zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1`.

- [ ] **Step 3: Update backlog and audit docs**

Mark local-pipeline and NenDB-retention fixtures delivered. Make the current
next branch:

```text
codex/zigeffect-causal-production-telemetry-workbench-readonly-preview
```

- [ ] **Step 4: Update README, operations, and roadmap**

Add the new command after local-pipeline fixtures and move the backlog summary
to the workbench read-only preview branch.

- [ ] **Step 5: Update master roadmap**

Change item 20 to delivered and add item 21:

```text
codex/zigeffect-causal-production-telemetry-workbench-readonly-preview
```

- [ ] **Step 6: Search for stale next-branch language**

Run:

```sh
rg -n 'current next branch is `codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures`|current handoff is `codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures`|recommended next branch: codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures|start-production-telemetry-nendb-retention-fixtures' packages/zigeffect/docs packages/zigeffect/README.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
rg -n 'production-telemetry-workbench-readonly-preview|start-production-telemetry-workbench-readonly-preview|production-telemetry-nendb-retention-fixtures.v1' packages/zigeffect/docs packages/zigeffect/README.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Expected: no stale "current next" usages pointing at NenDB retention fixtures;
new workbench read-only preview handoff appears in current-next locations.

## Task 5: Artifact Chain And Full Verification

**Files:**

- Verify generated artifacts under `.zig-cache/causal-artifacts/`

- [ ] **Step 1: Generate approved source chain**

Run the existing chain through ready local-pipeline fixtures:

```sh
cd packages/zigeffect
mkdir -p ../../.zig-cache/causal-artifacts
zig build causal-production-telemetry-capture-fixtures -- --format json \
  2> ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json
zig build causal-production-telemetry-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json \
  approve \
  --reason "fixtures reviewed for implementation proposal" \
  --verified-command "zig build causal-production-telemetry-capture-fixtures -- validate --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
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
  --verified-command "zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for exporter boundary planning\" --verified-command \"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-local-pipeline-fixtures -- \
  --from-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json \
  approve \
  --reason "approved boundary reviewed for local pipeline fixtures" \
  --verified-command "zig build causal-production-telemetry-exporter-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json approve --reason \"proposal evidence reviewed for local pipeline fixtures\" --verified-command \"zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \\\"ready evidence reviewed for exporter boundary planning\\\" --verified-command \\\"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\\\\\"fixtures reviewed for implementation proposal\\\\\\\" --verified-command \\\\\\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-schema-governance -- --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-production-hardening-backlog -- --format json\\\\\\\" --verified-command \\\\\\\"zig build examples\\\\\\\" --verified-command \\\\\\\"zig build test\\\\\\\"\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

- [ ] **Step 2: Verify approved and blocked NenDB retention artifacts**

Run:

```sh
zig build causal-production-telemetry-nendb-retention-fixtures -- \
  --from-local-pipeline ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json \
  approve \
  --reason "ready local pipeline fixtures reviewed for NenDB retention mapping" \
  --verified-command "zig build causal-production-telemetry-local-pipeline-fixtures" \
  --verified-command "zig build causal-nendb-storage-backend" \
  --verified-command "zig build causal-durable-production-retention -- --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
rg '"retention_fixture_status": "ready"|"ready_for_next_branch": true|"nendb_write_enabled": false|"durable_write_enabled": false|"next_branch_if_ready": "codex/zigeffect-causal-production-telemetry-workbench-readonly-preview"' ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures.json
zig build causal-production-telemetry-nendb-retention-fixtures -- \
  --from-local-pipeline ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json \
  reject \
  --reason "negative NenDB retention fixture path"
rg '"retention_fixture_status": "blocked"|"ready_for_next_branch": false|"nendb_write_enabled": false|"durable_write_enabled": false' ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures.json
```

Rerun the approve command after the reject path so the default artifact is
ready for the next branch.

- [ ] **Step 3: Run full verification**

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

- [ ] **Step 4: Commit the implementation**

Run:

```sh
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md packages/zigeffect/README.md packages/zigeffect/build.zig packages/zigeffect/docs/load-test-observation-harness.md packages/zigeffect/docs/operations.md packages/zigeffect/docs/production-hardening-backlog.md packages/zigeffect/docs/production-hardening-completion-audit.md packages/zigeffect/docs/production-telemetry-local-pipeline-fixtures.md packages/zigeffect/docs/production-telemetry-nendb-retention-fixtures.md packages/zigeffect/docs/roadmap.md packages/zigeffect/docs/schema-governance.md packages/zigeffect/tools/causal_production_hardening_backlog.zig packages/zigeffect/tools/causal_production_telemetry_nendb_retention_fixtures.zig packages/zigeffect/tools/causal_schema_governance.zig
git commit -m "feat(zigeffect): add production telemetry nendb retention fixtures"
```

## Plan Self-Review

- Spec coverage: tasks cover parser, evaluator, output artifacts, build wiring,
  schema governance, backlog, docs, artifact-chain verification, and full
  verification.
- Placeholder scan: no placeholder task remains; every command and expected
  branch/schema name is explicit.
- Type consistency: schema, branch, command, status field, output suffix,
  authority fields, and next branch match the design spec.
