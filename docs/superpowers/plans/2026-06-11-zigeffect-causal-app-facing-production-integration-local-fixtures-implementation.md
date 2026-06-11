# Zigeffect Causal App-Facing Production Integration Local Fixtures Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the app-facing production integration local-fixtures artifact that consumes an approved guarded boundary and emits local evidence fixtures for app runtime refs, bounded agent-query projections, NenDB handoff refs, audit/remediation links, SolidJS read-only preview handoff, and advisory CI artifact previews without production mutation authority.

**Architecture:** Follow the existing artifact-review CLI pattern used by `causal-production-telemetry-local-pipeline-fixtures`: parse an approved source boundary artifact, run deterministic checks, and emit paired JSON/text reports. The new tool specializes the fixture catalog around app-facing boundary labels and keeps all app, deployment, NenDB write, CI, and workbench-live authority disabled.

**Tech Stack:** Zig build tools, `std.json`, existing `packages/zigeffect/build.zig` build-step wiring, markdown docs, Bun root checks.

---

## File Structure

- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_local_fixtures.zig`
  - CLI, JSON parser, local fixture evaluator, text/JSON formatter, unit tests.
- Modify: `packages/zigeffect/build.zig`
  - Add executable, build step, and tool tests for `causal-app-facing-production-integration-local-fixtures`.
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
  - Add schema entry and update schema-count assertions from 86 to 87.
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Mark local fixtures delivered, update next branch to NenDB handoff fixtures, add dependency order and verification commands.
- Create: `packages/zigeffect/docs/app-facing-production-integration-local-fixtures.md`
  - User-facing docs for approved and rejected local-fixture artifacts.
- Modify: `packages/zigeffect/docs/app-facing-production-integration-boundary.md`
  - Add handoff to local fixtures.
- Modify: `packages/zigeffect/docs/schema-governance.md`
  - Regenerate with the new schema.
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
  - Regenerate with the new delivered item and recommendation.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark branch 51 delivered and add branch 52 for app-facing NenDB handoff fixtures.

## Task 1: Local Fixtures Tool Red Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_local_fixtures.zig`

- [ ] **Step 1: Add initial constants plus intentional red test**

Create the file with:

```zig
const std = @import("std");

pub const app_facing_production_integration_local_fixtures_schema = "zigeffect.causal.app-facing-production-integration-local-fixtures.v1";
pub const app_facing_production_integration_local_fixtures_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-local-fixtures";
pub const recommendation = "start-app-facing-production-integration-nendb-handoff-fixtures";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures";

test "app-facing local fixtures constants preserve the branch boundary" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-local-fixtures.v1", app_facing_production_integration_local_fixtures_schema);
    try std.testing.expectEqual(@as(u32, 1), app_facing_production_integration_local_fixtures_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-local-fixtures", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-production-integration-nendb-handoff-fixtures", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures", next_branch_if_ready);
}

test "app-facing local fixtures intentionally need implementation" {
    return error.ExpectedRedFailure;
}
```

- [ ] **Step 2: Run the red test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_local_fixtures.zig
```

Expected: FAIL with `ExpectedRedFailure`.

- [ ] **Step 3: Replace the intentional failure with option/output path tests**

Add tests that assert:

```zig
test "parse options requires boundary json decision and reason" {
    try std.testing.expectError(error.MissingBoundaryPath, parseOptions(std.testing.allocator, &.{"tool"}));
    try std.testing.expectError(error.InvalidBoundaryPath, parseOptions(std.testing.allocator, &.{ "tool", "--from-boundary", "boundary.txt", "approve", "--reason", "reviewed" }));
    try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{ "tool", "--from-boundary", "boundary.json", "approve" }));

    const parsed = try parseOptions(std.testing.allocator, &.{ "tool", "--from-boundary", "boundary.json", "approve", "--reason", "reviewed", "--verified-command", "zig build test" });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("boundary.json", parsed.boundary_path);
    try std.testing.expectEqual(Decision.approve, parsed.decision);
    try std.testing.expectEqualStrings("reviewed", parsed.reason);
    try std.testing.expectEqual(@as(usize, 1), parsed.verified_commands.len);
    try std.testing.expectEqualStrings("zig build test", parsed.verified_commands[0]);
}

test "output paths append local fixtures suffix" {
    const parsed = try parseOptions(std.testing.allocator, &.{ "tool", "--from-boundary", "boundary.json", "approve", "--reason", "reviewed" });
    defer parsed.deinit(std.testing.allocator);
    const paths = try outputPathsForOptions(std.testing.allocator, parsed);
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("boundary-local-fixtures.json", paths.json_path);
    try std.testing.expectEqualStrings("boundary-local-fixtures.txt", paths.text_path);
}
```

- [ ] **Step 4: Run the red tests again**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_local_fixtures.zig
```

Expected: FAIL because `parseOptions`, `Decision`, and `outputPathsForOptions` are missing.

## Task 2: Local Fixtures Tool Implementation

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_local_fixtures.zig`
- Reference: `packages/zigeffect/tools/causal_production_telemetry_local_pipeline_fixtures.zig`
- Reference: `packages/zigeffect/tools/causal_app_facing_production_integration_boundary.zig`

- [ ] **Step 1: Implement option parsing and constants**

Add constants:

```zig
const boundary_schema = "zigeffect.causal.app-facing-production-integration-boundary.v1";
const generated_by = "causal-app-facing-production-integration-local-fixtures";
const applied = false;
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const durable_write_enabled = false;
const app_mutation_enabled = false;
const ci_gate_enabled = false;
const raw_payload_capture_enabled = false;
const app_config_write_enabled = false;
const app_data_write_enabled = false;
const deployment_mutation_enabled = false;
const nendb_write_enabled = false;
const app_runtime_integration_enabled = false;
const agent_query_live_projection_enabled = false;
const solid_webui_preview_enabled = false;
const local_fixture_mode = true;
```

Implement `Decision`, `FixtureStatus`, `CheckStatus`, `Options`,
`parseOptions`, `outputPathsForOptions`, `parseDecision`, and `decisionText`
using default policy `manual-app-facing-production-integration-local-fixtures`.

- [ ] **Step 2: Run option tests green**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_local_fixtures.zig
```

Expected: PASS for constants, option parsing, and output path tests.

- [ ] **Step 3: Add evaluator/report tests**

Use a sample approved boundary JSON containing:

```json
{
  "schema": "zigeffect.causal.app-facing-production-integration-boundary.v1",
  "schema_version": 1,
  "source_proposal": "app-facing-production-integration-fixtures-readiness-review-implementation-proposal.json",
  "source_readiness": "app-facing-production-integration-fixtures-readiness-review.json",
  "source_fixtures": "app-facing-production-integration-fixtures.json",
  "decision": "approve",
  "boundary_status": "approved",
  "approved_for_next_branch": true,
  "applied": false,
  "mutation_authority": "none",
  "production_telemetry_ingestion": false,
  "live_exporter_enabled": false,
  "durable_write_enabled": false,
  "app_mutation_enabled": false,
  "ci_gate_enabled": false,
  "raw_payload_capture_enabled": false,
  "app_config_write_enabled": false,
  "app_data_write_enabled": false,
  "deployment_mutation_enabled": false,
  "nendb_write_enabled": false,
  "proposal_summary": { "source_contract_count": 6, "positive_fixture_count": 6, "negative_fixture_count": 15, "validation_check_count": 8 },
  "checks": [
    { "name": "proposal-schema", "status": "pass" },
    { "name": "proposal-status", "status": "pass" },
    { "name": "proposal-decision-approved", "status": "pass" },
    { "name": "boundary-decision", "status": "pass" },
    { "name": "decision-approved", "status": "pass" },
    { "name": "authority-boundary", "status": "pass" },
    { "name": "source-chain-linked", "status": "pass" },
    { "name": "proposal-checks-passed", "status": "pass" },
    { "name": "proposal-phase-handoff", "status": "pass" },
    { "name": "proposal-verification-recorded", "status": "pass" },
    { "name": "boundary-verification-recorded", "status": "pass" },
    { "name": "app-runtime-ref-boundary", "status": "pass" },
    { "name": "agent-query-projection-boundary", "status": "pass" },
    { "name": "nendb-handoff-boundary", "status": "pass" },
    { "name": "audit-remediation-boundary", "status": "pass" },
    { "name": "no-production-mutation-boundary", "status": "pass" },
    { "name": "nendb-only-scope", "status": "pass" },
    { "name": "solid-webui-scope", "status": "pass" }
  ],
  "app_boundary_contract": [
    "boundary_id=app-facing-production-integration-guarded",
    "source_contract=app-runtime",
    "trace_ref_state=ref-only",
    "raw_payload_state=blocked",
    "app_mutation_state=disabled",
    "agent_query_state=bounded-trace-data-only",
    "nendb_handoff_state=ref-only-no-production-write",
    "audit_compare_state=evidence-only-not-mutation-proof",
    "remediation_governance_state=handoff-only",
    "solid_webui_state=read-only-preview-only",
    "ci_state=advisory-artifacts-only"
  ],
  "local_projection_fixtures": [
    "worker-request-runtime-ref-boundary",
    "background-job-runtime-ref-boundary",
    "agent-query-bounded-projection-boundary",
    "nendb-history-handoff-ref-boundary",
    "audit-remediation-review-link-boundary",
    "solid-webui-readonly-handoff-boundary"
  ],
  "required_verification_commands": [
    "zig build causal-app-facing-production-integration-implementation-proposal",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test"
  ],
  "verified_commands": [
    "zig build causal-app-facing-production-integration-implementation-proposal",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test"
  ]
}
```

Assert a ready report contains:

- `"schema": "zigeffect.causal.app-facing-production-integration-local-fixtures.v1"`
- `"fixture_status": "ready"`
- `"ready_for_next_branch": true`
- `"local_fixture_mode": true`
- `"app_runtime_integration_enabled": false`
- `"agent_query_live_projection_enabled": false`
- `"solid_webui_preview_enabled": false`
- `"nendb_write_enabled": false`
- `"fixture_catalog"`
- `worker-request-runtime-ref-fixture`
- `agent-query-bounded-projection-fixture`
- `nendb-history-handoff-ref-fixture`
- `audit-remediation-review-link-fixture`
- `solid-webui-readonly-preview-fixture`

- [ ] **Step 4: Run evaluator tests red**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_local_fixtures.zig
```

Expected: FAIL because evaluator and report formatting are incomplete.

- [ ] **Step 5: Implement evaluator, fixture catalog, reports, and main**

Implement:

- `BoundaryArtifact`, `BoundaryCheck`, and `BoundarySummary`.
- `LocalFixture`, `FixtureCheck`, and `FixtureResult`.
- `evaluateFixtures`.
- `formatFixtureJson` and `formatFixtureText`.
- `main`, `run`, `readRequiredArtifact`, `writeArtifact`, and `failUsage`.

Required local check names:

```zig
&.{
    "boundary-schema",
    "boundary-status",
    "boundary-decision-approved",
    "fixture-decision",
    "decision-approved",
    "authority-boundary",
    "source-chain-linked",
    "boundary-checks-passed",
    "boundary-contract-present",
    "projection-fixtures-present",
    "fixture-catalog-present",
    "runtime-ref-fixtures-present",
    "agent-query-fixture-present",
    "nendb-handoff-fixture-present",
    "audit-remediation-fixture-present",
    "solid-webui-fixture-present",
    "ci-advisory-fixture-present",
    "fixture-validation-passed",
    "boundary-verification-recorded",
    "fixture-verification-recorded",
    "nendb-only-scope",
    "solid-webui-scope",
}
```

- [ ] **Step 6: Add negative tests and run green**

Add tests for unsupported source schema, failed boundary check, source authority
drift, missing source verification evidence, missing fixture verification
evidence, and missing fixture catalog labels.

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_local_fixtures.zig
```

Expected: PASS.

## Task 3: Build Step Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add build step after the app-facing boundary step**

Insert a module, executable, run step, and test artifact for:

```zig
tools/causal_app_facing_production_integration_local_fixtures.zig
```

The public step is:

```zig
causal-app-facing-production-integration-local-fixtures
```

The executable name is:

```zig
zigeffect-causal-app-facing-production-integration-local-fixtures
```

- [ ] **Step 2: Verify the build graph**

Run:

```sh
cd packages/zigeffect
zig build test
```

Expected: PASS, including the new local-fixtures tool tests.

## Task 4: Schema Governance

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/docs/schema-governance.md`

- [ ] **Step 1: Write failing schema governance expectations**

Update schema count expectations from 86 to 87 and add:

```zig
try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-local-fixtures.v1");
try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-local-fixtures.v1") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-local-fixtures.v1\"") != null);
```

- [ ] **Step 2: Run schema governance red through the build graph**

Run:

```sh
cd packages/zigeffect
zig build test
```

Expected: FAIL in schema governance because the new entry is missing.

- [ ] **Step 3: Add the schema entry**

Add after the boundary schema:

```zig
.{
    .schema = "zigeffect.causal.app-facing-production-integration-local-fixtures.v1",
    .version = 1,
    .category = "app-runtime",
    .status = "current",
    .emitted_by = &.{"causal-app-facing-production-integration-local-fixtures"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future app-facing NenDB handoff fixtures", "future SolidJS workbench production app views" },
    .compatibility = &.{ "strict-v1", "record-only", "local-fixtures", "fixture-only", "nendb-only", "no-cockroach", "no-live-telemetry", "no-production-mutation" },
    .governance_requirements = &.{ "local fixture tests", "boundary artifact checks", "fixture validation checks", "verification command evidence", "next-branch handoff", "docs update" },
},
```

- [ ] **Step 4: Run schema governance green**

Run:

```sh
cd packages/zigeffect
zig build test
```

Expected: PASS.

## Task 5: Production Hardening Backlog

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Write failing backlog expectations**

Update recommendation tests to:

```zig
try std.testing.expectEqualStrings(
    "start-app-facing-production-integration-nendb-handoff-fixtures",
    recommendation,
);
try std.testing.expectEqualStrings(
    "codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures",
    recommended_next_branch,
);
try expectBacklogItem("app-facing-production-integration-local-fixtures");
try expectBacklogItemStatus("app-facing-production-integration-local-fixtures", "delivered");
```

Update text and JSON tests to look for:

```zig
"recommended next branch: codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures"
"\"recommended_next_branch\": \"codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures\""
"causal-app-facing-production-integration-local-fixtures"
```

- [ ] **Step 2: Run backlog tests red**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: FAIL because the local-fixtures item and recommendation are not implemented yet.

- [ ] **Step 3: Add delivered backlog item and verification commands**

Add a delivered item after `app-facing-production-integration-boundary` with:

```zig
.id = "app-facing-production-integration-local-fixtures",
.title = "App-Facing Production Integration Local Fixtures",
.branch = "codex/zigeffect-causal-app-facing-production-integration-local-fixtures",
```

Deliverables include runtime-ref fixtures, agent-query bounded projection
fixtures, NenDB handoff ref fixtures, audit/remediation review link fixtures,
SolidJS read-only preview fixture, and advisory CI artifact fixture.

Add the id after boundary in `dependency_order`.

Add approved and rejected verification commands after the boundary commands.

- [ ] **Step 4: Run backlog tests green**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: PASS.

## Task 6: Documentation And Roadmap

**Files:**
- Create: `packages/zigeffect/docs/app-facing-production-integration-local-fixtures.md`
- Modify: `packages/zigeffect/docs/app-facing-production-integration-boundary.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add local-fixtures docs**

Document command shape, approved chain, rejected path, authority fields,
fixture catalog, validation checks, implementation gates, non-goals, and next
branch handoff.

- [ ] **Step 2: Update boundary docs**

Add a handoff section showing the local-fixtures command and clarifying that an
approved boundary only unlocks local fixture review.

- [ ] **Step 3: Regenerate generated docs**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance 2> docs/schema-governance.md
zig build causal-production-hardening-backlog 2> docs/production-hardening-backlog.md
```

Expected: generated docs include schema count 87 and the NenDB handoff fixtures
recommendation.

- [ ] **Step 4: Update the master roadmap**

Mark branch 51 delivered and add:

```markdown
52. `codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures`
    - Next: consume the ready app-facing local-fixtures artifact and build
      NenDB handoff fixture records for app runtime refs, bounded agent-query
      projection refs, audit/remediation evidence refs, and SolidJS read-only
      preview refs without production writes.
```

## Task 7: End-To-End Verification

**Files:**
- Generated artifacts in `.zig-cache/causal-artifacts`.

- [ ] **Step 1: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_local_fixtures.zig
zig test tools/causal_production_hardening_backlog.zig
```

Expected: PASS.

- [ ] **Step 2: Generate approved artifact chain**

Run:

```sh
cd packages/zigeffect
mkdir -p ../../.zig-cache/causal-artifacts
zig build causal-app-facing-production-integration-fixtures -- --format json \
  2> ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json
zig build causal-app-facing-production-integration-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json \
  approve \
  --reason "fixtures reviewed for implementation proposal" \
  --verified-command "zig build causal-app-facing-production-integration-fixtures -- validate --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-app-facing-production-integration-implementation-proposal -- \
  --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json \
  approve \
  --reason "ready evidence reviewed for app-facing integration planning" \
  --verified-command "zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-app-facing-production-integration-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-app-facing-production-integration-boundary -- \
  --from-proposal ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal.json \
  approve \
  --reason "proposal evidence reviewed for app-facing local fixtures" \
  --verified-command "zig build causal-app-facing-production-integration-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for app-facing integration planning\" --verified-command \"zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-app-facing-production-integration-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-app-facing-production-integration-local-fixtures -- \
  --from-boundary ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary.json \
  approve \
  --reason "guarded boundary reviewed for local app-facing fixtures" \
  --verified-command "zig build causal-app-facing-production-integration-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal.json approve --reason \"proposal evidence reviewed for app-facing local fixtures\" --verified-command \"zig build causal-app-facing-production-integration-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json approve --reason \\\"ready evidence reviewed for app-facing integration planning\\\" --verified-command \\\"zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \\\\\\\"fixtures reviewed for implementation proposal\\\\\\\" --verified-command \\\\\\\"zig build causal-app-facing-production-integration-fixtures -- validate --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-schema-governance -- --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-production-hardening-backlog -- --format json\\\\\\\" --verified-command \\\\\\\"zig build examples\\\\\\\" --verified-command \\\\\\\"zig build test\\\\\\\"\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Expected: local-fixtures JSON and text files are written with status `ready`.

- [ ] **Step 3: Generate rejected local-fixtures path**

Run:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-local-fixtures -- \
  --from-boundary ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary.json \
  reject \
  --reason "negative local fixtures path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-local-fixtures-negative
```

Expected: negative local-fixtures JSON and text files are written with status
`blocked`.

- [ ] **Step 4: Run full verification**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: all commands PASS.

## Task 8: Commit Implementation

**Files:**
- All changed files from Tasks 1-7.

- [ ] **Step 1: Inspect final diff**

Run:

```sh
git status --short
git diff --stat
```

Expected: only local-fixtures milestone files are changed.

- [ ] **Step 2: Commit**

Run:

```sh
git add packages/zigeffect/build.zig \
  packages/zigeffect/tools/causal_app_facing_production_integration_local_fixtures.zig \
  packages/zigeffect/tools/causal_schema_governance.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/docs/app-facing-production-integration-local-fixtures.md \
  packages/zigeffect/docs/app-facing-production-integration-boundary.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): add app-facing local fixtures"
```

Expected: implementation commit created after verification passes.
