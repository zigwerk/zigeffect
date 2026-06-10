# zigeffect Causal Production Telemetry Exporter Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a no-network exporter-boundary artifact that consumes an approved production telemetry implementation proposal and hands off to local pipeline fixtures without enabling live telemetry.

**Architecture:** Add one deterministic Zig tool that parses a proposal artifact, evaluates exporter-boundary checks, and emits text/JSON boundary artifacts. Wire it through `build.zig`, schema governance, docs, and the production hardening backlog while preserving `mutation_authority=none`, disabled network/collector/OTLP authority, NenDB-only durable scope, and SolidJS `zig-webui` workbench direction.

**Tech Stack:** Zig 0.16 build modules/tests, zigeffect causal artifact conventions, Bun verification commands, Markdown docs.

---

## File Structure

- Create `packages/zigeffect/tools/causal_production_telemetry_exporter_boundary.zig`: CLI parser, proposal JSON parser, boundary evaluator, text/JSON formatters, and unit tests.
- Modify `packages/zigeffect/build.zig`: register the new executable, build step, examples dependency, and tests.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`: register schema `zigeffect.causal.production-telemetry-exporter-boundary.v1`, update schema count tests, and add coverage assertions.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`: mark exporter-boundary delivered, update recommendation/next branch to local pipeline fixtures, add dependency order and verification commands.
- Create `packages/zigeffect/docs/production-telemetry-exporter-boundary.md`: command contract, no-network boundary, statuses, checks, local envelope fixtures, output paths, agent guidance, and verification commands.
- Modify existing zigeffect docs and roadmap files listed in the spec so the current next branch becomes `codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures`.
- Modify `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`: add the delivered exporter-boundary milestone and local-pipeline-fixtures handoff.

## Task 1: Red Test For Exporter Boundary Tool Contract

**Files:**

- Create: `packages/zigeffect/tools/causal_production_telemetry_exporter_boundary.zig`

- [ ] **Step 1: Add a compileable red-test scaffold**

Create the file with only constants and red tests:

```zig
const std = @import("std");

pub const production_telemetry_exporter_boundary_schema = "zigeffect.causal.production-telemetry-exporter-boundary.v1";
pub const production_telemetry_exporter_boundary_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-exporter-boundary";
pub const recommendation = "start-production-telemetry-local-pipeline-fixtures";
pub const next_branch_if_approved = "codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures";

test "exporter boundary schema and no-network constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-exporter-boundary.v1", production_telemetry_exporter_boundary_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_exporter_boundary_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-exporter-boundary", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-local-pipeline-fixtures", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures", next_branch_if_approved);
    return error.ExpectedRedFailure;
}

test "parses approve boundary options with verified commands and output prefix" {
    return error.ExpectedRedFailure;
}

test "rejects missing proposal path decision and reason" {
    return error.ExpectedRedFailure;
}

test "derives exporter boundary output paths from proposal json path" {
    return error.ExpectedRedFailure;
}

test "approved and blocked boundary reports preserve no-network authority" {
    return error.ExpectedRedFailure;
}
```

- [ ] **Step 2: Run the focused red test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_exporter_boundary.zig
```

Expected: FAIL with `ExpectedRedFailure`.

## Task 2: Implement Parser, Evaluator, And Reports

**Files:**

- Modify: `packages/zigeffect/tools/causal_production_telemetry_exporter_boundary.zig`

- [ ] **Step 1: Replace the scaffold with the full data model**

Use these core types:

```zig
const Decision = enum { approve, reject };
const BoundaryStatus = enum { approved, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    proposal_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "local-boundary-reviewer",
    policy: []const u8 = "manual-production-telemetry-exporter-boundary",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,
};

const ProposalCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8 = "",
};

const ProposalSummary = struct {
    source_contract_count: usize = 0,
    positive_fixture_count: usize = 0,
    negative_fixture_count: usize = 0,
    validation_check_count: usize = 0,
};

const ProposalArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_readiness: []const u8 = "",
    source_fixtures: []const u8 = "",
    decision: []const u8,
    proposal_status: []const u8,
    approved_for_next_branch: bool,
    applied: bool,
    mutation_authority: []const u8,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    durable_write_enabled: bool,
    ci_gate_enabled: bool,
    readiness_summary: ProposalSummary = .{},
    checks: []const ProposalCheck = &.{},
    proposal_phases: []const []const u8 = &.{},
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
`causal_production_telemetry_implementation_proposal.zig`.

Parser behavior:

- `--from-proposal <proposal.json>` is required.
- Input path must end with `.json`.
- Decision must be `approve` or `reject`.
- `--reason <reason>` is required and non-empty.
- `--by`, `--policy`, `--verified-command`, and `--out-prefix` are optional.
- Unknown flags and missing flag values fail closed.

- [ ] **Step 3: Add fixed boundary constants**

Use these constants:

```zig
const proposal_schema = "zigeffect.causal.production-telemetry-implementation-proposal.v1";
const generated_by = "causal-production-telemetry-exporter-boundary";
const applied = false;
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const durable_write_enabled = false;
const ci_gate_enabled = false;

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for exporter boundary planning\" --verified-command \"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const exporter_boundary_contract: []const []const u8 = &.{
    "boundary_id=exporter-neutral-no-network",
    "input_contract=redacted-causal-otel-record-or-fixture-ref",
    "output_contract=local-export-envelope-fixture",
    "transport_state=disabled",
    "network_state=disabled",
    "collector_endpoint_state=not-configured",
    "serialization_state=boundary-json-only-not-otlp",
    "durable_write_state=disabled",
    "review_gate=local-pipeline-fixtures-review",
};

const local_envelope_fixtures: []const []const u8 = &.{
    "runtime-span-event-envelope",
    "app-semantic-ref-envelope",
    "backend-otel-record-envelope",
    "redaction-access-envelope",
    "sampling-boundary-envelope",
};
```

- [ ] **Step 4: Implement boundary checks**

Implement `evaluateBoundary` with these checks:

- `proposal-schema`
- `proposal-status`
- `proposal-decision-approved`
- `boundary-decision`
- `decision-approved`
- `authority-boundary`
- `no-network-boundary`
- `no-otlp-serialization`
- `source-chain-linked`
- `proposal-checks-passed`
- `proposal-phase-handoff`
- `proposal-verification-recorded`
- `boundary-verification-recorded`
- `nendb-only-scope`
- `solid-webui-scope`

Return `BoundaryStatus.approved` only when every check passes. Return
`BoundaryStatus.blocked` otherwise.

- [ ] **Step 5: Implement text and JSON reports**

The JSON report must include:

```json
{
  "schema": "zigeffect.causal.production-telemetry-exporter-boundary.v1",
  "schema_version": 1,
  "source_proposal": "<input path>",
  "source_readiness": "<proposal source_readiness>",
  "source_fixtures": "<proposal source_fixtures>",
  "decision": "approve",
  "boundary_status": "approved",
  "approved_for_next_branch": true,
  "reviewed_by": "local-boundary-reviewer",
  "policy": "manual-production-telemetry-exporter-boundary",
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
  "source_branch": "codex/zigeffect-causal-production-telemetry-exporter-boundary",
  "recommendation": "start-production-telemetry-local-pipeline-fixtures",
  "next_branch_if_approved": "codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures",
  "checks": [],
  "exporter_boundary_contract": [],
  "local_envelope_fixtures": [],
  "implementation_gates": [],
  "non_goals": [],
  "blocked_claims": [],
  "required_verification_commands": [],
  "verified_commands": [],
  "agent_guidance": []
}
```

The text report must include schema, source proposal/readiness/fixtures,
boundary status, authority fields, no-network fields, checks, boundary
contract, local envelope fixtures, non-goals, blocked claims, required
commands, verified commands, and agent guidance.

- [ ] **Step 6: Run focused green test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_exporter_boundary.zig
```

Expected: PASS.

## Task 3: Wire Build Step And Examples Aggregate

**Files:**

- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add module, executable, run step, and test artifact**

Near the implementation-proposal build block, add:

```zig
const causal_production_telemetry_exporter_boundary_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_telemetry_exporter_boundary.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_production_telemetry_exporter_boundary_tool = b.addExecutable(.{
    .name = "zigeffect-causal-production-telemetry-exporter-boundary",
    .root_module = causal_production_telemetry_exporter_boundary_tool_module,
});
const run_causal_production_telemetry_exporter_boundary_tool = b.addRunArtifact(causal_production_telemetry_exporter_boundary_tool);
if (b.args) |args| run_causal_production_telemetry_exporter_boundary_tool.addArgs(args);
const causal_production_telemetry_exporter_boundary_step = b.step("causal-production-telemetry-exporter-boundary", "Review production telemetry exporter boundary");
causal_production_telemetry_exporter_boundary_step.dependOn(&run_causal_production_telemetry_exporter_boundary_tool.step);

const causal_production_telemetry_exporter_boundary_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-production-telemetry-exporter-boundary-tests",
    .root_module = causal_production_telemetry_exporter_boundary_tool_module,
});
const run_causal_production_telemetry_exporter_boundary_tool_tests = b.addRunArtifact(causal_production_telemetry_exporter_boundary_tool_tests);
test_step.dependOn(&run_causal_production_telemetry_exporter_boundary_tool_tests.step);
```

- [ ] **Step 2: Add examples dependencies**

Near the other telemetry example dependencies, add:

```zig
examples_step.dependOn(&causal_production_telemetry_exporter_boundary_tool.step);
examples_step.dependOn(&run_causal_production_telemetry_exporter_boundary_tool_tests.step);
```

## Task 4: Register Schema Governance

**Files:**

- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`

- [ ] **Step 1: Add schema entry**

Add after the implementation-proposal schema entry:

```zig
.{
    .schema = "zigeffect.causal.production-telemetry-exporter-boundary.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-production-telemetry-exporter-boundary"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry local pipeline fixtures" },
    .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "exporter-boundary", "no-live-ingestion", "no-network" },
    .governance_requirements = &.{ "boundary tests", "proposal evidence checks", "no-network checks", "next-branch handoff" },
},
```

- [ ] **Step 2: Update schema count and assertions**

Update schema count assertions from `54` to `55` and assert the new schema is
present in inventory, text output, and JSON output.

- [ ] **Step 3: Verify governance command**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance -- --format json 2> ../../.zig-cache/causal-artifacts/schema-governance.json
rg '"schema_count": 55|production-telemetry-exporter-boundary' ../../.zig-cache/causal-artifacts/schema-governance.json
```

Expected: command exits 0 and the captured JSON includes schema count `55`.

## Task 5: Update Backlog And Docs

**Files:**

- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Create: `packages/zigeffect/docs/production-telemetry-exporter-boundary.md`
- Modify: `packages/zigeffect/docs/production-telemetry-implementation-proposal.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/production-hardening-completion-audit.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update backlog constants and item**

Set:

```zig
pub const recommendation = "start-production-telemetry-local-pipeline-fixtures";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures";
```

Append delivered backlog item:

```zig
.{
    .id = "production-telemetry-exporter-boundary",
    .title = "Production Telemetry Exporter Boundary",
    .gap_id = "production-telemetry-exporter-boundary",
    .priority = "P5",
    .status = "delivered",
    .summary = "Consumes an approved implementation proposal and emits a no-network exporter-neutral boundary contract before local pipeline fixture work.",
    .depends_on = &.{ "production-telemetry-implementation-proposal", "production-telemetry-readiness-review", "production-telemetry-capture-fixtures" },
    .deliverables = &.{
        "proposal JSON boundary review",
        "approved and blocked exporter-boundary artifacts",
        "no-network exporter boundary contract",
        "local envelope fixture names",
        "local pipeline fixture handoff",
    },
    .evidence_sources = &.{
        "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-exporter-boundary-design.md",
        "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-exporter-boundary-implementation.md",
        "packages/zigeffect/tools/causal_production_telemetry_exporter_boundary.zig",
        "packages/zigeffect/docs/production-telemetry-exporter-boundary.md",
    },
    .branch = "codex/zigeffect-causal-production-telemetry-exporter-boundary",
    .agent_guidance = "Use approved exporter-boundary artifacts to start local pipeline fixture work only; do not infer live telemetry, OTLP serialization, collector endpoints, network sends, durable writes, CI gates, non-NenDB adapters, alternate renderers, or mutation authority.",
},
```

Append `production-telemetry-exporter-boundary` to `dependency_order`.

- [ ] **Step 2: Add backlog verification commands**

Append commands for approved and blocked boundary paths:

```sh
zig build causal-production-telemetry-exporter-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json approve --reason "approved proposal reviewed for no-network exporter boundary" --verified-command "zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for exporter boundary planning\" --verified-command \"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
zig build causal-production-telemetry-exporter-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json reject --reason "negative exporter boundary path"
```

- [ ] **Step 3: Update docs**

Create the new docs page with command contract, boundary, statuses, checks,
exporter boundary contract, local envelope fixtures, output paths, agent
guidance, and verification commands.

Update current chain text to:

```text
production-telemetry-capture-design -> production-telemetry-capture-fixtures -> production-telemetry-readiness-review -> production-telemetry-implementation-proposal -> production-telemetry-exporter-boundary -> production-telemetry-local-pipeline-fixtures
```

Keep all durable production work scoped to NenDB only. Keep workbench direction
SolidJS inside `webui-dev/zig-webui`.

## Task 6: End-To-End Artifact Verification

**Files:**

- No tracked files under `.zig-cache/causal-artifacts`.

- [ ] **Step 1: Generate upstream artifacts**

Run:

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
```

Expected: fixture JSON is non-empty, readiness output contains
`readiness_status: ready`, and proposal output contains
`proposal_status: approved`.

- [ ] **Step 2: Generate approved boundary artifact**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-exporter-boundary -- \
  --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json \
  approve \
  --reason "approved proposal reviewed for no-network exporter boundary" \
  --verified-command "zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for exporter boundary planning\" --verified-command \"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Expected: text output contains `boundary_status: approved`,
`approved_for_next_branch: true`, `network send enabled: false`,
`collector endpoint configured: false`, `otlp serialization enabled: false`,
and `next branch if approved:
codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures`.

- [ ] **Step 3: Generate blocked boundary artifact**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-exporter-boundary -- \
  --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json \
  reject \
  --reason "negative exporter boundary path"
```

Expected: text output contains `boundary_status: blocked` and
`approved_for_next_branch: false`.

## Task 7: Full Verification And Commit

**Files:**

- All files touched by Tasks 1-6.

- [ ] **Step 1: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_exporter_boundary.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json 2> ../../.zig-cache/causal-artifacts/schema-governance.json
rg '"schema_count": 55|production-telemetry-exporter-boundary' ../../.zig-cache/causal-artifacts/schema-governance.json
zig build causal-production-hardening-backlog -- --format json
```

Expected: all commands exit 0.

- [ ] **Step 2: Run broad Zig checks**

Run:

```sh
cd packages/zigeffect
zig build examples
zig build test
```

Expected: both commands exit 0.

- [ ] **Step 3: Run repo checks**

Run:

```sh
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: all commands exit 0. Existing guarded live database tests may skip
when live services are unavailable, but no required test may fail.

- [ ] **Step 4: Review and commit**

Run:

```sh
git status --short
git diff --stat
git add packages/zigeffect/build.zig \
  packages/zigeffect/tools/causal_production_telemetry_exporter_boundary.zig \
  packages/zigeffect/tools/causal_schema_governance.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/docs/production-telemetry-exporter-boundary.md \
  packages/zigeffect/docs/production-telemetry-implementation-proposal.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/production-hardening-completion-audit.md \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/README.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): add production telemetry exporter boundary"
```

Expected: commit succeeds on
`codex/zigeffect-causal-production-telemetry-exporter-boundary`.

## Plan Self-Review

- Spec coverage: every design goal maps to tool behavior, build wiring,
  schema governance, backlog/docs updates, or verification tasks.
- Placeholder scan: no placeholder instructions remain.
- Type consistency: schema, command, branch, recommendation, status, and field
  names match the design spec.
- Scope check: local pipeline fixtures, NenDB retention fixtures, workbench
  preview, CI artifact preview, live telemetry, OTLP serialization, collector
  configuration, network send, durable production writes, CI gates, non-NenDB
  adapters, React/alternate renderers, and mutation authority are explicitly
  excluded.
