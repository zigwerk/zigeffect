# Zigeffect Causal App-Facing Production Integration NenDB Handoff Fixtures Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the app-facing NenDB handoff fixtures artifact that consumes ready app-facing local fixtures and emits record-only NenDB node/edge handoff records without production writes or adapter execution.

**Architecture:** Follow the existing artifact-review CLI pattern used by `causal-production-telemetry-nendb-retention-fixtures`, but specialize the source parser for `zigeffect.causal.app-facing-production-integration-local-fixtures.v1` and the output catalog for app-facing NenDB handoff records. The tool remains deterministic, local, schema-governed, and authority-disabled.

**Tech Stack:** Zig build tools, `std.json`, existing `packages/zigeffect/build.zig` build-step wiring, markdown docs, Bun root checks.

---

## File Structure

- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_nendb_handoff_fixtures.zig`
  - CLI, JSON parser, handoff evaluator, text/JSON formatter, unit tests.
- Modify: `packages/zigeffect/build.zig`
  - Add executable, build step, and tool tests for `causal-app-facing-production-integration-nendb-handoff-fixtures`.
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
  - Add schema entry and update schema-count assertions from 87 to 88.
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Mark NenDB handoff fixtures delivered, update next branch to audit/remediation bridge, add dependency order and verification commands.
- Create: `packages/zigeffect/docs/app-facing-production-integration-nendb-handoff-fixtures.md`
  - User-facing docs for approved and rejected handoff artifacts.
- Modify: `packages/zigeffect/docs/app-facing-production-integration-local-fixtures.md`
  - Add handoff section to the NenDB handoff fixtures command.
- Modify: `packages/zigeffect/docs/schema-governance.md`
  - Regenerate with schema count 88.
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
  - Regenerate with delivered item and audit/remediation bridge recommendation.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark branch 52 delivered and add branch 53 for audit/remediation bridge.

## Task 1: Tool Red Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_nendb_handoff_fixtures.zig`

- [ ] **Step 1: Add constants and an intentional red test**

Create the file with this scaffold:

```zig
const std = @import("std");

pub const app_facing_production_integration_nendb_handoff_fixtures_schema = "zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1";
pub const app_facing_production_integration_nendb_handoff_fixtures_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures";
pub const recommendation = "start-app-facing-production-integration-audit-remediation-bridge";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge";

test "app-facing nendb handoff constants preserve the branch boundary" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1", app_facing_production_integration_nendb_handoff_fixtures_schema);
    try std.testing.expectEqual(@as(u32, 1), app_facing_production_integration_nendb_handoff_fixtures_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-production-integration-audit-remediation-bridge", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge", next_branch_if_ready);
}

test "app-facing nendb handoff intentionally needs implementation" {
    return error.ExpectedRedFailure;
}
```

- [ ] **Step 2: Run the red test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_nendb_handoff_fixtures.zig
```

Expected: FAIL with `ExpectedRedFailure`.

- [ ] **Step 3: Replace the intentional failure with option/output path tests**

Add tests for:

```zig
try std.testing.expectError(error.MissingLocalFixturesPath, parseOptions(std.testing.allocator, &.{"tool"}));
try std.testing.expectError(error.InvalidLocalFixturesPath, parseOptions(std.testing.allocator, &.{ "tool", "--from-local-fixtures", "local-fixtures.txt", "approve", "--reason", "reviewed" }));
try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{ "tool", "--from-local-fixtures", "local-fixtures.json", "approve" }));
```

Add a successful parse case with:

```zig
const parsed = try parseOptions(std.testing.allocator, &.{ "tool", "--from-local-fixtures", "local-fixtures.json", "approve", "--reason", "reviewed", "--verified-command", "zig build test" });
defer parsed.deinit(std.testing.allocator);
try std.testing.expectEqualStrings("local-fixtures.json", parsed.local_fixtures_path);
try std.testing.expectEqual(Decision.approve, parsed.decision);
try std.testing.expectEqualStrings("reviewed", parsed.reason);
try std.testing.expectEqual(@as(usize, 1), parsed.verified_commands.len);
```

Add output path expectations:

```zig
const parsed = try parseOptions(std.testing.allocator, &.{ "tool", "--from-local-fixtures", "local-fixtures.json", "approve", "--reason", "reviewed" });
defer parsed.deinit(std.testing.allocator);
const paths = try outputPathsForOptions(std.testing.allocator, parsed);
defer paths.deinit(std.testing.allocator);
try std.testing.expectEqualStrings("local-fixtures-nendb-handoff-fixtures.json", paths.json_path);
try std.testing.expectEqualStrings("local-fixtures-nendb-handoff-fixtures.txt", paths.text_path);
```

- [ ] **Step 4: Run the option tests red**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_nendb_handoff_fixtures.zig
```

Expected: FAIL because `Decision`, `parseOptions`, and `outputPathsForOptions` are missing.

## Task 2: Tool Implementation

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_nendb_handoff_fixtures.zig`
- Reference: `packages/zigeffect/tools/causal_app_facing_production_integration_local_fixtures.zig`
- Reference: `packages/zigeffect/tools/causal_production_telemetry_nendb_retention_fixtures.zig`

- [ ] **Step 1: Implement constants, option parsing, and source structs**

Use these constants:

```zig
const local_fixtures_schema = "zigeffect.causal.app-facing-production-integration-local-fixtures.v1";
const generated_by = "causal-app-facing-production-integration-nendb-handoff-fixtures";
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
const local_fixture_mode = true;
const nendb_handoff_fixture_mode = true;
```

Implement:

- `Decision`, `FixtureStatus`, `CheckStatus`
- `Options` with `local_fixtures_path`
- `OutputPaths`
- `parseOptions`
- `outputPathsForOptions`
- `parseDecision`, `decisionText`, `fixtureStatusText`, `checkStatusText`
- source structs mirroring local-fixtures output:
  - `LocalFixturesArtifact`
  - `LocalFixturesCheck`
  - `LocalFixturesSummary`
  - `LocalFixture`

- [ ] **Step 2: Run option tests green**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_nendb_handoff_fixtures.zig
```

Expected: constants, parse, and path tests pass.

- [ ] **Step 3: Add evaluator/report tests**

Add a sample ready local-fixtures JSON artifact with:

- schema `zigeffect.causal.app-facing-production-integration-local-fixtures.v1`
- `fixture_status="ready"`
- `ready_for_next_branch=true`
- all source authority booleans disabled
- `local_fixture_mode=true`
- all required source check names present as `pass`
- `fixture_catalog` containing the seven local fixture ids
- source `required_verification_commands` and `verified_commands` matching

Assert approved reports contain:

- `"schema": "zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1"`
- `"nendb_handoff_status": "ready"`
- `"ready_for_next_branch": true`
- `"nendb_write_enabled": false`
- `"nendb_adapter_execution_enabled": false`
- `"nendb_handoff_fixture_mode": true`
- `"nendb_handoff_fixtures"`
- `nendb-worker-request-node-handoff-fixture`
- `nendb-agent-query-projection-node-handoff-fixture`
- `nendb-runtime-to-agent-query-edge-handoff-fixture`

Assert rejected reports contain:

- `"nendb_handoff_status": "blocked"`
- `"ready_for_next_branch": false`
- authority booleans still disabled

- [ ] **Step 4: Run evaluator tests red**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_nendb_handoff_fixtures.zig
```

Expected: FAIL because evaluator/report formatting is incomplete.

- [ ] **Step 5: Implement evaluator, handoff catalog, formatters, and main**

Implement:

- `NendbHandoffFixture`
- `FixtureCheck`
- `FixtureResult`
- `evaluateFixtures`
- `formatFixtureJson`
- `formatFixtureText`
- `appendNendbHandoffFixtureCatalogJson`
- `appendNendbHandoffFixtureCatalogText`
- `run`, `readRequiredArtifact`, `writeArtifact`, `usage`, `failUsage`

Required emitted check names:

```zig
&.{
    "local-fixtures-schema",
    "local-fixtures-status",
    "local-fixtures-decision-approved",
    "handoff-decision",
    "decision-approved",
    "authority-boundary",
    "source-chain-linked",
    "local-fixtures-checks-passed",
    "local-fixtures-verification-recorded",
    "source-fixture-catalog-present",
    "nendb-handoff-catalog-present",
    "nendb-node-handoffs-present",
    "nendb-edge-handoffs-present",
    "runtime-ref-handoff-covered",
    "agent-query-handoff-covered",
    "audit-remediation-handoff-covered",
    "solid-webui-handoff-covered",
    "ci-advisory-handoff-covered",
    "handoff-validation-passed",
    "handoff-verification-recorded",
    "nendb-write-disabled",
    "nendb-adapter-execution-disabled",
    "durable-write-disabled",
    "nendb-only-scope",
    "solid-webui-scope",
}
```

Use this handoff catalog:

- `nendb-worker-request-node-handoff-fixture`
- `nendb-background-job-node-handoff-fixture`
- `nendb-agent-query-projection-node-handoff-fixture`
- `nendb-audit-remediation-node-handoff-fixture`
- `nendb-solid-webui-preview-node-handoff-fixture`
- `nendb-ci-advisory-node-handoff-fixture`
- `nendb-runtime-to-agent-query-edge-handoff-fixture`
- `nendb-runtime-to-audit-remediation-edge-handoff-fixture`
- `nendb-artifact-preview-edge-handoff-fixture`

Validation checks:

```zig
&.{
    "source-local-fixtures-ready",
    "source-authority-disabled",
    "source-fixture-catalog-covered",
    "nendb-node-handoff-fixtures-present",
    "nendb-edge-handoff-fixtures-present",
    "runtime-ref-handoff-covered",
    "agent-query-handoff-covered",
    "audit-remediation-handoff-covered",
    "solid-webui-handoff-covered",
    "ci-advisory-handoff-covered",
    "nendb-write-disabled",
    "nendb-adapter-execution-disabled",
    "durable-write-disabled",
    "raw-sensitive-fields-blocked",
    "production-mutation-fields-blocked",
    "non-nendb-scope-rejected",
    "cockroach-scope-rejected",
    "audit-remediation-bridge-next-only",
}
```

- [ ] **Step 6: Add negative tests and run green**

Add tests for:

- unsupported source schema
- failed source check
- source authority drift
- missing source verification evidence
- missing handoff verification evidence
- missing source fixture catalog id

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_nendb_handoff_fixtures.zig
```

Expected: PASS.

## Task 3: Build Step Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add build step after local fixtures**

Add module, executable, run step, and test artifact for:

```zig
tools/causal_app_facing_production_integration_nendb_handoff_fixtures.zig
```

Public step:

```zig
causal-app-facing-production-integration-nendb-handoff-fixtures
```

Executable:

```zig
zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures
```

- [ ] **Step 2: Verify build graph**

Run:

```sh
cd packages/zigeffect
zig build test
```

Expected: PASS with the new tool tests included.

## Task 4: Schema Governance

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/docs/schema-governance.md`

- [ ] **Step 1: Write failing schema expectations**

Update schema count assertions from 87 to 88.

Add expectations for:

```zig
try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1");
try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1\"") != null);
```

- [ ] **Step 2: Run red through build graph**

Run:

```sh
cd packages/zigeffect
zig build test
```

Expected: FAIL in schema governance because the new entry is missing.

- [ ] **Step 3: Add schema entry after local fixtures**

Add:

```zig
.{
    .schema = "zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1",
    .version = 1,
    .category = "app-runtime",
    .status = "current",
    .emitted_by = &.{"causal-app-facing-production-integration-nendb-handoff-fixtures"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future app-facing audit remediation bridge", "future SolidJS workbench production app views" },
    .compatibility = &.{ "strict-v1", "record-only", "nendb-handoff-fixtures", "fixture-only", "nendb-only", "no-cockroach", "no-live-telemetry", "no-production-mutation", "no-nendb-write" },
    .governance_requirements = &.{ "handoff fixture tests", "local fixture artifact checks", "NenDB node and edge handoff checks", "verification command evidence", "next-branch handoff", "docs update" },
},
```

- [ ] **Step 4: Run schema governance green**

Run:

```sh
cd packages/zigeffect
zig build test
```

Expected: PASS.

## Task 5: Backlog, Docs, And Roadmap

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-nendb-handoff-fixtures.md`
- Modify: `packages/zigeffect/docs/app-facing-production-integration-local-fixtures.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Write failing backlog expectations**

Update:

```zig
try std.testing.expectEqualStrings("start-app-facing-production-integration-audit-remediation-bridge", recommendation);
try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge", recommended_next_branch);
try expectBacklogItem("app-facing-production-integration-nendb-handoff-fixtures");
try expectBacklogItemStatus("app-facing-production-integration-nendb-handoff-fixtures", "delivered");
```

Add text/JSON expectations for:

- `recommended next branch: codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge`
- `"recommended_next_branch": "codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge"`
- `causal-app-facing-production-integration-nendb-handoff-fixtures`

- [ ] **Step 2: Run backlog red**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: FAIL because the delivered item and commands are missing.

- [ ] **Step 3: Add delivered backlog item**

Add after `app-facing-production-integration-local-fixtures`:

```zig
.{
    .id = "app-facing-production-integration-nendb-handoff-fixtures",
    .title = "App-Facing Production Integration NenDB Handoff Fixtures",
    .gap_id = "app-facing-production-integration-nendb-handoff-fixtures",
    .priority = "P1",
    .status = "delivered",
    .summary = "Consumes ready app-facing local-fixtures evidence and emits record-only NenDB node and edge handoff fixtures for app runtime refs, bounded agent queries, audit/remediation review links, SolidJS read-only preview refs, and advisory CI artifact refs without production writes.",
    .depends_on = &.{ "app-facing-production-integration-local-fixtures", "app-facing-production-integration-boundary", "agent-query-interface", "audit-chain-snapshot-compare", "nendb-durable-history-hardening" },
    .deliverables = &.{ "NenDB node handoff fixture catalog", "NenDB edge handoff fixture catalog", "source local-fixtures validation", "no-write adapter execution guardrails", "audit/remediation bridge handoff" },
    .evidence_sources = &.{ "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures-design.md", "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures-implementation.md", "packages/zigeffect/tools/causal_app_facing_production_integration_nendb_handoff_fixtures.zig", "packages/zigeffect/docs/app-facing-production-integration-nendb-handoff-fixtures.md", "packages/zigeffect/docs/schema-governance.md" },
    .branch = "codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures",
    .agent_guidance = "Use ready NenDB handoff fixture artifacts to start the app-facing audit/remediation bridge only. Do not infer NenDB adapter execution, NenDB production writes, app runtime integration, live agent projection, raw payload capture, app mutation, Cockroach scope, CI enforcement, deployment mutation, or applied=true.",
},
```

Add the id to `dependency_order` after local fixtures and add approved/rejected verification commands to `verification_commands`.

- [ ] **Step 4: Add docs and roadmap**

Create `packages/zigeffect/docs/app-facing-production-integration-nendb-handoff-fixtures.md` documenting command, authority fields, handoff catalog, checks, blocked claims, and next branch.

Add a handoff section to `packages/zigeffect/docs/app-facing-production-integration-local-fixtures.md`.

Mark branch 52 delivered and add branch 53 in the master roadmap:

```markdown
53. `codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge`
    - Next: consume ready app-facing NenDB handoff fixtures and connect audit-chain comparison refs plus remediation review refs into an evidence-only bridge without mutation proof, auto-apply, deployment, app writes, or production health claims.
```

- [ ] **Step 5: Regenerate generated docs**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance 2> docs/schema-governance.md
zig build causal-production-hardening-backlog 2> docs/production-hardening-backlog.md
```

Expected: schema count 88 and audit/remediation bridge recommendation.

## Task 6: End-To-End Verification And Commit

**Files:**
- Generated artifacts in `.zig-cache/causal-artifacts`.

- [ ] **Step 1: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_nendb_handoff_fixtures.zig
zig test tools/causal_production_hardening_backlog.zig
```

Expected: PASS.

- [ ] **Step 2: Generate approved artifact chain**

Run the existing app-facing chain through local fixtures, then run:

```sh
zig build causal-app-facing-production-integration-nendb-handoff-fixtures -- \
  --from-local-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures.json \
  approve \
  --reason "ready local app-facing fixtures reviewed for NenDB handoff fixtures" \
  --verified-command "zig build causal-app-facing-production-integration-local-fixtures" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Expected: JSON/text artifacts are written with `nendb_handoff_status=ready`.

- [ ] **Step 3: Generate rejected path**

Run:

```sh
zig build causal-app-facing-production-integration-nendb-handoff-fixtures -- \
  --from-local-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures.json \
  reject \
  --reason "negative nendb handoff path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-nendb-handoff-fixtures-negative
```

Expected: JSON/text artifacts are written with `nendb_handoff_status=blocked`.

- [ ] **Step 4: Run full verification**

Run:

```sh
cd packages/zigeffect
zig build test
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: all commands pass.

- [ ] **Step 5: Commit**

Run:

```sh
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures-implementation.md packages/zigeffect/build.zig packages/zigeffect/docs/app-facing-production-integration-local-fixtures.md packages/zigeffect/docs/app-facing-production-integration-nendb-handoff-fixtures.md packages/zigeffect/docs/production-hardening-backlog.md packages/zigeffect/docs/schema-governance.md packages/zigeffect/tools/causal_app_facing_production_integration_nendb_handoff_fixtures.zig packages/zigeffect/tools/causal_production_hardening_backlog.zig packages/zigeffect/tools/causal_schema_governance.zig
git commit -m "feat(zigeffect): add app-facing nendb handoff fixtures"
```
