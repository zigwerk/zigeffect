# Zigeffect Causal App-Facing Production Integration Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the guarded app-facing production integration boundary artifact that consumes an approved implementation proposal and hands off to local fixtures without granting app, deployment, CI, live telemetry, or durable write authority.

**Architecture:** Reuse the existing causal artifact-review pattern: a Zig CLI parses an approved source artifact, evaluates deterministic checks, and emits paired JSON/text reports. The new boundary specializes that pattern for app-runtime references, bounded agent-query projection, NenDB-only handoff, and SolidJS workbench direction.

**Tech Stack:** Zig build tools, `std.json`, existing `packages/zigeffect/build.zig` build-step wiring, markdown docs, Bun root checks.

---

## File Structure

- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_boundary.zig`
  - CLI, JSON parser, boundary evaluator, text/JSON formatter, unit tests.
- Modify: `packages/zigeffect/build.zig`
  - Add executable, build step, and tool tests for `causal-app-facing-production-integration-boundary`.
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
  - Add schema entry and update schema-count assertions from 85 to 86.
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Mark boundary delivered, update next branch to local fixtures, add dependency order and verification commands.
- Create: `packages/zigeffect/docs/app-facing-production-integration-boundary.md`
  - User-facing docs for approved and rejected boundary artifacts.
- Modify: `packages/zigeffect/docs/app-facing-production-integration-implementation-proposal.md`
  - Add handoff to the boundary command.
- Modify: `packages/zigeffect/docs/schema-governance.md`
  - Add the new app-runtime schema.
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
  - Refresh next branch and delivered boundary item.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark branch 50 delivered and add branch 51 for local fixtures.

## Task 1: Boundary Tool Red Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_boundary.zig`

- [ ] **Step 1: Add the first failing boundary constants and option tests**

Create the file with enough declarations for intentional red tests:

```zig
const std = @import("std");

pub const app_facing_production_integration_boundary_schema = "zigeffect.causal.app-facing-production-integration-boundary.v1";
pub const app_facing_production_integration_boundary_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-boundary";
pub const recommendation = "start-app-facing-production-integration-local-fixtures";
pub const next_branch_if_approved = "codex/zigeffect-causal-app-facing-production-integration-local-fixtures";

test "app-facing production integration boundary constants preserve the branch boundary" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-boundary.v1",
        app_facing_production_integration_boundary_schema,
    );
    try std.testing.expectEqual(@as(u32, 1), app_facing_production_integration_boundary_schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-boundary",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-app-facing-production-integration-local-fixtures",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-local-fixtures",
        next_branch_if_approved,
    );
}

test "app-facing production integration boundary intentionally needs implementation" {
    return error.ExpectedRedFailure;
}
```

- [ ] **Step 2: Run the red test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_boundary.zig
```

Expected: FAIL with `ExpectedRedFailure`.

- [ ] **Step 3: Replace the intentional failure with real option tests**

Replace the intentional failure with tests that assert:

```zig
test "parse options requires proposal json decision and reason" {
    try std.testing.expectError(error.MissingProposalPath, parseOptions(std.testing.allocator, &.{"tool"}));
    try std.testing.expectError(error.InvalidProposalPath, parseOptions(std.testing.allocator, &.{ "tool", "--from-proposal", "proposal.txt", "approve", "--reason", "reviewed" }));
    try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{ "tool", "--from-proposal", "proposal.json", "approve" }));

    const parsed = try parseOptions(std.testing.allocator, &.{ "tool", "--from-proposal", "proposal.json", "approve", "--reason", "reviewed", "--verified-command", "zig build test" });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("proposal.json", parsed.proposal_path);
    try std.testing.expectEqual(Decision.approve, parsed.decision);
    try std.testing.expectEqualStrings("reviewed", parsed.reason);
    try std.testing.expectEqual(@as(usize, 1), parsed.verified_commands.len);
    try std.testing.expectEqualStrings("zig build test", parsed.verified_commands[0]);
}

test "output paths append app-facing boundary suffix" {
    const parsed = try parseOptions(std.testing.allocator, &.{ "tool", "--from-proposal", "proposal.json", "approve", "--reason", "reviewed" });
    defer parsed.deinit(std.testing.allocator);
    const paths = try outputPathsForOptions(std.testing.allocator, parsed);
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("proposal-app-facing-boundary.json", paths.json_path);
    try std.testing.expectEqualStrings("proposal-app-facing-boundary.txt", paths.text_path);
}
```

- [ ] **Step 4: Run the red tests again**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_boundary.zig
```

Expected: FAIL because `parseOptions`, `Decision`, and `outputPathsForOptions` are missing.

## Task 2: Boundary Tool Implementation

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_boundary.zig`
- Reference: `packages/zigeffect/tools/causal_production_telemetry_exporter_boundary.zig`
- Reference: `packages/zigeffect/tools/causal_app_facing_production_integration_implementation_proposal.zig`

- [ ] **Step 1: Implement option parsing and output paths**

Add:

```zig
const proposal_schema = "zigeffect.causal.app-facing-production-integration-implementation-proposal.v1";
const generated_by = "causal-app-facing-production-integration-boundary";
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

const Decision = enum { approve, reject };
const BoundaryStatus = enum { approved, blocked };
const CheckStatus = enum { pass, fail };
```

Implement `Options`, `parseOptions`, `outputPathsForOptions`, `parseDecision`,
and `decisionText` using the exporter boundary as the local pattern, with default
policy `manual-app-facing-production-integration-boundary`.

- [ ] **Step 2: Run the option tests green**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_boundary.zig
```

Expected: PASS for constants, option parsing, and output path tests.

- [ ] **Step 3: Add source artifact and evaluator tests**

Add tests with an approved source proposal JSON string containing:

```json
{
  "schema": "zigeffect.causal.app-facing-production-integration-implementation-proposal.v1",
  "schema_version": 1,
  "source_readiness": "app-facing-production-integration-fixtures-readiness-review.json",
  "source_fixtures": "app-facing-production-integration-fixtures.json",
  "decision": "approve",
  "proposal_status": "approved",
  "approved_for_next_branch": true,
  "applied": false,
  "mutation_authority": "none",
  "production_telemetry_ingestion": false,
  "live_exporter_enabled": false,
  "durable_write_enabled": false,
  "app_mutation_enabled": false,
  "ci_gate_enabled": false,
  "checks": [
    { "name": "readiness-schema", "status": "pass" },
    { "name": "readiness-status", "status": "pass" },
    { "name": "readiness-decision-approved", "status": "pass" },
    { "name": "proposal-decision", "status": "pass" },
    { "name": "decision-approved", "status": "pass" },
    { "name": "authority-boundary", "status": "pass" },
    { "name": "source-fixtures-linked", "status": "pass" },
    { "name": "readiness-checks-passed", "status": "pass" },
    { "name": "readiness-verification-recorded", "status": "pass" },
    { "name": "proposal-verification-recorded", "status": "pass" },
    { "name": "nendb-only-scope", "status": "pass" },
    { "name": "solid-webui-scope", "status": "pass" },
    { "name": "app-runtime-scope", "status": "pass" },
    { "name": "agent-query-scope", "status": "pass" }
  ],
  "proposal_phases": [
    "app-runtime-boundary",
    "agent-query-projection",
    "nendb-history-handoff",
    "audit-remediation-bridge",
    "solid-webui-readonly-preview",
    "ci-artifact-preview"
  ],
  "verified_commands": [
    "zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-app-facing-production-integration-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test"
  ]
}
```

Assert that an approved boundary report contains:

- `"schema": "zigeffect.causal.app-facing-production-integration-boundary.v1"`
- `"boundary_status": "approved"`
- `"approved_for_next_branch": true`
- `"app_mutation_enabled": false`
- `"raw_payload_capture_enabled": false`
- `"nendb_write_enabled": false`
- `"app_boundary_contract"`
- `"local_projection_fixtures"`
- `"app-runtime-ref-boundary"`
- `"agent-query-projection-boundary"`
- `"nendb-handoff-boundary"`

- [ ] **Step 4: Run the evaluator tests red**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_boundary.zig
```

Expected: FAIL because evaluator and report formatting are incomplete.

- [ ] **Step 5: Implement evaluator, JSON report, text report, and main**

Implement:

- `ProposalArtifact`, `ProposalCheck`, and `ProposalSummary`.
- `BoundaryCheck`, `BoundaryResult`, and `formatReports`.
- `evaluateBoundary` with deterministic checks from the design doc.
- `formatBoundaryJson` and `formatBoundaryText`.
- `main`, `run`, `writeFile`, and `failUsage`.

Required boundary check names:

```zig
&.{
    "proposal-schema",
    "proposal-status",
    "proposal-decision-approved",
    "boundary-decision",
    "decision-approved",
    "authority-boundary",
    "source-chain-linked",
    "proposal-checks-passed",
    "proposal-phase-handoff",
    "proposal-verification-recorded",
    "boundary-verification-recorded",
    "app-runtime-ref-boundary",
    "agent-query-projection-boundary",
    "nendb-handoff-boundary",
    "audit-remediation-boundary",
    "no-production-mutation-boundary",
    "nendb-only-scope",
    "solid-webui-scope",
}
```

- [ ] **Step 6: Run boundary tool tests green**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_boundary.zig
```

Expected: PASS.

## Task 3: Build Step Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add the build step after the app-facing implementation proposal step**

Insert:

```zig
const causal_app_facing_production_integration_boundary_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_app_facing_production_integration_boundary.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_app_facing_production_integration_boundary_tool = b.addExecutable(.{
    .name = "zigeffect-causal-app-facing-production-integration-boundary",
    .root_module = causal_app_facing_production_integration_boundary_tool_module,
});
const run_causal_app_facing_production_integration_boundary_tool = b.addRunArtifact(causal_app_facing_production_integration_boundary_tool);
if (b.args) |args| run_causal_app_facing_production_integration_boundary_tool.addArgs(args);
const causal_app_facing_production_integration_boundary_step = b.step("causal-app-facing-production-integration-boundary", "Review app-facing production integration boundary");
causal_app_facing_production_integration_boundary_step.dependOn(&run_causal_app_facing_production_integration_boundary_tool.step);

const causal_app_facing_production_integration_boundary_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-app-facing-production-integration-boundary-tests",
    .root_module = causal_app_facing_production_integration_boundary_tool_module,
});
const run_causal_app_facing_production_integration_boundary_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_boundary_tool_tests);
test_step.dependOn(&run_causal_app_facing_production_integration_boundary_tool_tests.step);
```

- [ ] **Step 2: Verify the build step exists**

Run:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-boundary -- --help
```

Expected: usage output from the tool.

## Task 4: Schema Governance

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/docs/schema-governance.md`

- [ ] **Step 1: Write failing schema governance expectations**

Update tests from 85 to 86 and add:

```zig
try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-boundary.v1");
try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-boundary.v1") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-boundary.v1\"") != null);
```

- [ ] **Step 2: Run schema governance tests red**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_schema_governance.zig
```

Expected: FAIL because the schema entry is missing.

- [ ] **Step 3: Add the schema entry**

Add after the implementation proposal schema:

```zig
.{
    .schema = "zigeffect.causal.app-facing-production-integration-boundary.v1",
    .version = 1,
    .category = "app-runtime",
    .status = "current",
    .emitted_by = &.{"causal-app-facing-production-integration-boundary"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future app-facing production integration local fixtures", "future SolidJS workbench production app views" },
    .compatibility = &.{ "strict-v1", "record-only", "guarded-boundary", "nendb-only", "no-cockroach", "no-live-telemetry", "no-production-mutation" },
    .governance_requirements = &.{ "boundary tests", "proposal artifact checks", "verification command evidence", "next-branch handoff", "docs update" },
},
```

- [ ] **Step 4: Run schema governance tests green**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_schema_governance.zig
```

Expected: PASS.

## Task 5: Production Hardening Backlog

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Write failing backlog expectations**

Update tests so they expect:

```zig
try std.testing.expectEqualStrings(
    "start-app-facing-production-integration-local-fixtures",
    recommendation,
);
try std.testing.expectEqualStrings(
    "codex/zigeffect-causal-app-facing-production-integration-local-fixtures",
    recommended_next_branch,
);
try expectBacklogItem("app-facing-production-integration-boundary");
try expectBacklogItemStatus("app-facing-production-integration-boundary", "delivered");
```

Update text and JSON tests to look for:

```zig
"recommended next branch: codex/zigeffect-causal-app-facing-production-integration-local-fixtures"
"\"recommended_next_branch\": \"codex/zigeffect-causal-app-facing-production-integration-local-fixtures\""
"causal-app-facing-production-integration-boundary"
```

- [ ] **Step 2: Run backlog tests red**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: FAIL because the backlog item and recommendation are missing.

- [ ] **Step 3: Add the delivered backlog item and verification commands**

Add a delivered item after the implementation proposal:

```zig
.{
    .id = "app-facing-production-integration-boundary",
    .title = "App-Facing Production Integration Boundary",
    .gap_id = "app-facing-production-integration-boundary",
    .priority = "P1",
    .status = "delivered",
    .summary = "Consumes an approved app-facing implementation-proposal artifact and emits a guarded boundary for app runtime refs, bounded agent-query projection, NenDB handoff, and SolidJS workbench direction without production mutation authority.",
    .depends_on = &.{ "app-facing-production-integration-implementation-proposal", "app-facing-production-integration-readiness-review", "app-facing-production-integration-fixtures", "agent-query-interface", "audit-chain-snapshot-compare", "nendb-durable-history-hardening" },
    .deliverables = &.{
        "approved implementation-proposal artifact consumption",
        "guarded app runtime reference-only boundary",
        "bounded agent-query projection boundary",
        "NenDB-only handoff without production writes",
        "audit remediation evidence-only bridge",
        "SolidJS webui read-only preview handoff",
    },
    .evidence_sources = &.{
        "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-boundary-design.md",
        "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-boundary-implementation.md",
        "packages/zigeffect/tools/causal_app_facing_production_integration_boundary.zig",
        "packages/zigeffect/docs/app-facing-production-integration-boundary.md",
        "packages/zigeffect/docs/app-facing-production-integration-implementation-proposal.md",
        "packages/zigeffect/docs/schema-governance.md",
    },
    .branch = "codex/zigeffect-causal-app-facing-production-integration-boundary",
    .agent_guidance = "Use approved boundary artifacts to start local app-facing integration fixtures only. Do not infer app mutation, live telemetry, durable production writes, Cockroach scope, CI gates, alternate renderer work, raw payload capture, NenDB production writes, deployment mutation, or applied=true from boundary evidence.",
},
```

Add the boundary id after `app-facing-production-integration-implementation-proposal`
in `dependency_order`.

Add approved and rejected verification commands after the implementation proposal
commands.

- [ ] **Step 4: Run backlog tests green**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: PASS.

## Task 6: Documentation And Roadmap

**Files:**
- Create: `packages/zigeffect/docs/app-facing-production-integration-boundary.md`
- Modify: `packages/zigeffect/docs/app-facing-production-integration-implementation-proposal.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add boundary docs**

Document:

- command shape
- approved artifact chain
- rejected artifact path
- authority fields
- app boundary contract
- local projection fixture labels
- implementation gates
- non-goals
- next branch handoff

- [ ] **Step 2: Update proposal docs**

Add the boundary command after the proposal approve/reject examples and state
that proposal evidence only unlocks boundary review.

- [ ] **Step 3: Update schema and backlog docs**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance > docs/schema-governance.md
zig build causal-production-hardening-backlog > docs/production-hardening-backlog.md
```

Expected: generated docs include the new schema count and next branch.

- [ ] **Step 4: Update the master roadmap**

Mark branch 50 delivered and add branch 51:

```markdown
51. `codex/zigeffect-causal-app-facing-production-integration-local-fixtures`
    - Next: consume the approved guarded app-facing boundary artifact and build
      local fixture reports for app runtime refs, bounded agent-query
      projections, NenDB handoff refs, audit remediation review links, and
      SolidJS read-only workbench previews without production mutation authority.
```

## Task 7: End-To-End Verification

**Files:**
- No new files unless generated artifacts in `.zig-cache/causal-artifacts`.

- [ ] **Step 1: Run the focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_boundary.zig
zig test tools/causal_schema_governance.zig
zig test tools/causal_production_hardening_backlog.zig
```

Expected: PASS.

- [ ] **Step 2: Generate the approved artifact chain**

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
```

Expected: boundary JSON and text files are written with status `approved`.

- [ ] **Step 3: Generate the rejected boundary path**

Run:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-boundary -- \
  --from-proposal ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal.json \
  reject \
  --reason "negative boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-boundary-negative
```

Expected: negative boundary JSON and text files are written with status
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

Expected: only boundary milestone files are changed.

- [ ] **Step 2: Commit**

Run:

```sh
git add packages/zigeffect/build.zig \
  packages/zigeffect/tools/causal_app_facing_production_integration_boundary.zig \
  packages/zigeffect/tools/causal_schema_governance.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/docs/app-facing-production-integration-boundary.md \
  packages/zigeffect/docs/app-facing-production-integration-implementation-proposal.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): add app-facing integration boundary"
```

Expected: implementation commit created after verification passes.
