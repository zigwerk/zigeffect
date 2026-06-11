# zigeffect Causal App-Facing Production Integration Implementation Proposal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a proposal-only app-facing production integration artifact that consumes a ready readiness-review JSON and hands off to the guarded app-facing integration boundary without enabling telemetry, durable writes, app mutation, CI gates, Cockroach scope, or alternate renderer work.

**Architecture:** Add one deterministic Zig tool that parses the app-facing readiness-review artifact, evaluates fixed proposal checks, and emits text/JSON proposal artifacts. Wire it through `build.zig`, schema governance, docs, and the production hardening backlog while preserving `mutation_authority=none`, `app_mutation_enabled=false`, NenDB-only durable direction, and SolidJS `zig-webui` workbench direction.

**Tech Stack:** Zig 0.16 build modules/tests, zigeffect causal artifact conventions, Bun verification commands, Markdown docs.

---

## File Structure

- Create `packages/zigeffect/tools/causal_app_facing_production_integration_implementation_proposal.zig`: CLI parser, readiness JSON parser, proposal evaluator, text/JSON formatters, fixed proposal arrays, and unit tests.
- Modify `packages/zigeffect/build.zig`: register the new executable, build step, and tests after the app-facing readiness-review tool.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`: register schema `zigeffect.causal.app-facing-production-integration-implementation-proposal.v1`, update schema count tests from `84` to `85`, and add coverage assertions.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`: mark the implementation-proposal milestone delivered, update recommendation/next branch to the guarded app-facing integration boundary, add dependency order and verification commands.
- Create `packages/zigeffect/docs/app-facing-production-integration-implementation-proposal.md`: operator guide, command examples, boundaries, checks, phases, output paths, agent guidance, and verification.
- Modify `packages/zigeffect/docs/app-facing-production-integration-readiness-review.md`: add the implementation-proposal handoff command.
- Modify `packages/zigeffect/docs/agent-observable-runtime.md`: explain the app-facing proposal artifact as the next record-only agent evidence boundary.
- Modify `packages/zigeffect/docs/schema-governance.md`: add the app-facing implementation-proposal schema.
- Modify `packages/zigeffect/docs/production-hardening-backlog.md`: add delivered milestone and new recommendation.
- Modify `packages/zigeffect/docs/operations.md`: add the app-facing proposal command sequence.
- Modify `packages/zigeffect/README.md`: add the app-facing implementation-proposal command and boundary summary.
- Modify `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`: mark branch 49 delivered and add the next guarded boundary branch.

## Task 1: Red Test For Proposal Tool Contract

**Files:**

- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_implementation_proposal.zig`

- [ ] **Step 1: Add a compileable red-test scaffold**

Create the file with only constants and tests that intentionally fail:

```zig
const std = @import("std");

pub const app_facing_production_integration_implementation_proposal_schema =
    "zigeffect.causal.app-facing-production-integration-implementation-proposal.v1";
pub const app_facing_production_integration_implementation_proposal_schema_version: u32 = 1;
pub const source_branch =
    "codex/zigeffect-causal-app-facing-production-integration-implementation-proposal";
pub const recommendation =
    "start-app-facing-production-integration-boundary";
pub const next_branch_if_approved =
    "codex/zigeffect-causal-app-facing-production-integration-boundary";

test "app-facing implementation proposal schema and authority constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-implementation-proposal.v1",
        app_facing_production_integration_implementation_proposal_schema,
    );
    try std.testing.expectEqual(@as(u32, 1), app_facing_production_integration_implementation_proposal_schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-implementation-proposal",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-app-facing-production-integration-boundary",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-boundary",
        next_branch_if_approved,
    );
    return error.ExpectedRedFailure;
}

test "app-facing implementation proposal parses approve options with verified commands and output prefix" {
    return error.ExpectedRedFailure;
}

test "app-facing implementation proposal rejects missing required arguments" {
    return error.ExpectedRedFailure;
}

test "app-facing implementation proposal output paths derive from readiness path and out prefix" {
    return error.ExpectedRedFailure;
}

test "app-facing implementation proposal reports approved and blocked status" {
    return error.ExpectedRedFailure;
}
```

- [ ] **Step 2: Run the focused red test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_implementation_proposal.zig
```

Expected: FAIL with `ExpectedRedFailure`.

- [ ] **Step 3: Keep the red scaffold uncommitted**

Do not commit the red scaffold. Continue directly to Task 2 and replace it with
the implementation that makes the tests pass.

## Task 2: Implement Proposal Parser, Evaluator, Formatters, And Unit Tests

**Files:**

- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_implementation_proposal.zig`

- [ ] **Step 1: Add the production implementation**

Replace the red scaffold with a full implementation that follows this exact
contract:

```zig
pub const app_facing_production_integration_implementation_proposal_schema =
    "zigeffect.causal.app-facing-production-integration-implementation-proposal.v1";
pub const app_facing_production_integration_implementation_proposal_schema_version: u32 = 1;
pub const source_branch =
    "codex/zigeffect-causal-app-facing-production-integration-implementation-proposal";
pub const recommendation =
    "start-app-facing-production-integration-boundary";
pub const next_branch_if_approved =
    "codex/zigeffect-causal-app-facing-production-integration-boundary";

const readiness_schema =
    "zigeffect.causal.app-facing-production-integration-readiness-review.v1";
const generated_by =
    "causal-app-facing-production-integration-implementation-proposal";
const applied = false;
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const durable_write_enabled = false;
const app_mutation_enabled = false;
const ci_gate_enabled = false;
```

The tool must expose:

```zig
const Decision = enum { approve, reject };
const ProposalStatus = enum { approved, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    readiness_path: []const u8,
    decision: Decision,
    proposed_by: []const u8 = "local-proposer",
    policy: []const u8 = "manual-app-facing-production-integration-implementation-proposal",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        if (self.verified_commands.len > 0) allocator.free(self.verified_commands);
    }
};
```

Readiness parsing must accept the app-facing readiness fields:

```zig
const ReadinessArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    generated_by: []const u8 = "",
    source_fixtures: []const u8 = "",
    decision: []const u8,
    readiness_status: []const u8,
    ready_for_implementation_proposal: bool,
    applied: bool,
    mutation_authority: []const u8,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    durable_write_enabled: bool,
    app_mutation_enabled: bool,
    ci_gate_enabled: bool,
    fixture_summary: ReadinessSummary = .{},
    checks: []const ReadinessCheck = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};
```

Implement `parseOptions`, `parseDecision`, `decisionText`,
`proposalStatusText`, `checkStatusText`, `outputPathsForOptions`,
`formatReports`, `formatProposalJson`, `formatProposalText`, `run`, and
`main` using the same memory ownership and fail-closed conventions as the
existing `causal_production_telemetry_implementation_proposal.zig` tool.

- [ ] **Step 2: Add fixed proposal arrays**

Add this exact proposal verification list:

```zig
const required_verification_commands: []const []const u8 = &.{
    "zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-app-facing-production-integration-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};
```

Add proposal phases:

```zig
const proposal_phases: []const []const u8 = &.{
    "app-runtime-boundary: connect app runtime trace refs and source-contract guards without raw payload capture or app mutation",
    "agent-query-projection: expose bounded app trace-data query evidence and next-query hints without raw payload scraping",
    "nendb-history-handoff: map approved refs to NenDB durable-history handoff records without production writes",
    "audit-remediation-bridge: preserve audit-chain compare and app remediation governance handoffs without treating comparison evidence as mutation proof",
    "solid-webui-readonly-preview: prepare a future read-only SolidJS webui production app evidence view without production hosting or mutation",
    "ci-artifact-preview: allow optional local advisory artifacts only with no CI gate enforcement",
};
```

Add implementation gates:

```zig
const implementation_gates: []const []const u8 = &.{
    "source readiness artifact is ready and approved",
    "all app-facing readiness checks remain pass",
    "readiness verification commands are recorded",
    "proposal verification commands are recorded exactly",
    "no raw request header prompt credential PII tenant identity or payload capture is allowed",
    "no app source config migration data deployment rollout rollback or operational mutation is allowed",
    "live telemetry exporter durable production writes and CI gates remain disabled",
    "durable direction remains NenDB-only and Cockroach remains out of scope",
    "workbench direction remains SolidJS inside webui-dev/zig-webui",
};
```

Add non-goals and blocked claims exactly as the design lists them. Include
`Non-NenDB durable adapter work`, `Cockroach adapter work`, `React or alternate
renderer work`, `raw request body header prompt credential token tenant identity
or PII capture`, and `app source config migration data deployment rollout
rollback or operational mutation`.

- [ ] **Step 3: Implement proposal checks**

`evaluateProposal` must append checks in this order:

1. `readiness-schema`
2. `readiness-status`
3. `readiness-decision-approved`
4. `proposal-decision`
5. `decision-approved`
6. `authority-boundary`
7. `source-fixtures-linked`
8. `readiness-checks-passed`
9. `readiness-verification-recorded`
10. `proposal-verification-recorded`
11. `nendb-only-scope`
12. `solid-webui-scope`
13. `app-runtime-scope`
14. `agent-query-scope`

`authorityBoundaryIntact` must require both the source readiness artifact and
the proposal constants to keep `applied=false`, `mutation_authority=none`,
`production_telemetry_ingestion=false`, `live_exporter_enabled=false`,
`durable_write_enabled=false`, `app_mutation_enabled=false`, and
`ci_gate_enabled=false`.

`readinessChecksPassed` must require every app-facing readiness check from the
design and must return false if any source check has a status other than
`pass`.

`nendbOnlyScope`, `solidWebuiScope`, `appRuntimeScope`, and `agentQueryScope`
must inspect the fixed proposal arrays rather than the readiness fixture
catalog. These checks prove the proposal itself still blocks forbidden scope.

- [ ] **Step 4: Add unit test fixtures**

Add a `sample_readiness_json` string that contains:

- schema `zigeffect.causal.app-facing-production-integration-readiness-review.v1`
- `source_fixtures` pointing at
  `../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json`
- `decision: "approve"`
- `readiness_status: "ready"`
- `ready_for_implementation_proposal: true`
- all authority booleans false including `app_mutation_enabled`
- fixture summary counts `6`, `6`, `15`, and `8`
- all expected readiness checks with status `pass`
- readiness required commands and matching verified commands

Add unit tests for:

- stable schema and authority constants;
- approve option parsing with `--by`, `--policy`, `--verified-command`, and
  `--out-prefix`;
- missing readiness path, invalid readiness path, missing decision, unknown
  decision, and missing reason errors;
- default and custom output paths;
- approved and blocked reports preserving non-live authority and
  `app_mutation_enabled=false`;
- unsupported readiness schema blocks proposal;
- missing app mutation boundary blocks proposal;
- missing proposal verification blocks proposal.

- [ ] **Step 5: Run focused green test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_implementation_proposal.zig
```

Expected: PASS.

## Task 3: Register Build Step And Schema Governance With Red Checks

**Files:**

- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`

- [ ] **Step 1: Add schema governance failing assertions first**

In `packages/zigeffect/tools/causal_schema_governance.zig`, add assertions that
expect the new schema in the text and JSON reports, and update the JSON schema
count assertion from:

```zig
try std.testing.expect(std.mem.indexOf(u8, report, "\"schema_count\": 84") != null);
```

to:

```zig
try std.testing.expect(std.mem.indexOf(u8, report, "\"schema_count\": 85") != null);
```

Run:

```sh
cd packages/zigeffect
zig test tools/causal_schema_governance.zig
```

Expected: FAIL because the schema entry has not been registered yet.

- [ ] **Step 2: Register the schema entry**

Add a schema entry near the app-facing fixture and readiness entries:

```zig
.{
    .schema = "zigeffect.causal.app-facing-production-integration-implementation-proposal.v1",
    .version = 1,
    .category = "app-runtime",
    .status = "current",
    .emitted_by = &.{"causal-app-facing-production-integration-implementation-proposal"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future app-facing production integration boundary" },
    .compatibility = &.{ "strict-v1", "record-only", "implementation-proposal", "nendb-only", "no-cockroach", "no-live-telemetry", "no-production-mutation" },
    .governance_requirements = &.{ "implementation proposal tests", "readiness artifact checks", "verification command evidence", "next-branch handoff", "docs update" },
},
```

Run:

```sh
cd packages/zigeffect
zig test tools/causal_schema_governance.zig
```

Expected: PASS.

- [ ] **Step 3: Register the build step**

In `packages/zigeffect/build.zig`, add the module/executable/run step/test
block immediately after
`causal_app_facing_production_integration_readiness_review_tool_tests`:

```zig
const causal_app_facing_production_integration_implementation_proposal_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_app_facing_production_integration_implementation_proposal.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_app_facing_production_integration_implementation_proposal_tool = b.addExecutable(.{
    .name = "zigeffect-causal-app-facing-production-integration-implementation-proposal",
    .root_module = causal_app_facing_production_integration_implementation_proposal_tool_module,
});
const run_causal_app_facing_production_integration_implementation_proposal_tool = b.addRunArtifact(causal_app_facing_production_integration_implementation_proposal_tool);
if (b.args) |args| run_causal_app_facing_production_integration_implementation_proposal_tool.addArgs(args);
const causal_app_facing_production_integration_implementation_proposal_step = b.step("causal-app-facing-production-integration-implementation-proposal", "Review app-facing production integration implementation proposal");
causal_app_facing_production_integration_implementation_proposal_step.dependOn(&run_causal_app_facing_production_integration_implementation_proposal_tool.step);

const causal_app_facing_production_integration_implementation_proposal_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-app-facing-production-integration-implementation-proposal-tests",
    .root_module = causal_app_facing_production_integration_implementation_proposal_tool_module,
});
const run_causal_app_facing_production_integration_implementation_proposal_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_implementation_proposal_tool_tests);
test_step.dependOn(&run_causal_app_facing_production_integration_implementation_proposal_tool_tests.step);
```

Run:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-implementation-proposal -- --help
```

Expected: exits with usage error code `2` because `--help` is not a supported
flag, and prints the tool usage text. Then run:

```sh
cd packages/zigeffect
zig build test
```

Expected: PASS once the new tool and schema tests are wired correctly.

## Task 4: Update Production Hardening Backlog With Red Checks

**Files:**

- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Update tests first**

Change recommendation assertions to expect:

```text
start-app-facing-production-integration-boundary
codex/zigeffect-causal-app-facing-production-integration-boundary
```

Add test assertions that the text and JSON reports include:

```text
app-facing-production-integration-implementation-proposal
causal-app-facing-production-integration-implementation-proposal
zig build causal-app-facing-production-integration-implementation-proposal
codex/zigeffect-causal-app-facing-production-integration-implementation-proposal
```

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: FAIL because the backlog item and constants are not updated yet.

- [ ] **Step 2: Update constants, item, dependency order, and commands**

At the top of the backlog tool, set:

```zig
pub const recommendation = "start-app-facing-production-integration-boundary";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-production-integration-boundary";
```

Add a delivered item after `app-facing-production-integration-readiness-review`:

```zig
.{
    .id = "app-facing-production-integration-implementation-proposal",
    .title = "App-Facing Production Integration Implementation Proposal",
    .gap_id = "app-facing-production-integration-implementation-proposal",
    .priority = "P1",
    .status = "delivered",
    .summary = "Consumes a ready app-facing production integration readiness-review artifact and emits a proposal-only implementation sequence before guarded boundary work.",
    .depends_on = &.{ "app-facing-production-integration-readiness-review", "app-facing-production-integration-fixtures", "agent-query-interface", "audit-chain-snapshot-compare", "nendb-durable-history-hardening", "production-telemetry-capture-fixtures" },
    .deliverables = &.{
        "ready readiness-review artifact consumption",
        "proposal decision and reason recording",
        "app runtime and bounded agent-query phase plan",
        "NenDB-only durable handoff guardrails",
        "app mutation telemetry durable CI Cockroach and renderer blocked claims",
    },
    .evidence_sources = &.{
        "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-implementation-proposal-design.md",
        "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-implementation-proposal-implementation.md",
        "packages/zigeffect/tools/causal_app_facing_production_integration_implementation_proposal.zig",
        "packages/zigeffect/docs/app-facing-production-integration-implementation-proposal.md",
        "packages/zigeffect/docs/app-facing-production-integration-readiness-review.md",
        "packages/zigeffect/docs/schema-governance.md",
    },
    .branch = "codex/zigeffect-causal-app-facing-production-integration-implementation-proposal",
    .agent_guidance = "Use approved implementation proposal artifacts to start the guarded app-facing production integration boundary only. Do not infer app mutation, live telemetry, durable production writes, Cockroach scope, CI gates, alternate renderer work, or applied=true from proposal evidence.",
},
```

Add `"app-facing-production-integration-implementation-proposal"` to
`dependency_order` after the readiness-review item.

Add approve and reject verification commands immediately after the readiness
review commands:

```zig
"zig build causal-app-facing-production-integration-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for app-facing integration planning\" --verified-command \"zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-app-facing-production-integration-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
"zig build causal-app-facing-production-integration-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json reject --reason \"negative proposal path\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-implementation-proposal-negative",
```

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: PASS.

## Task 5: Add Operator Documentation

**Files:**

- Create: `packages/zigeffect/docs/app-facing-production-integration-implementation-proposal.md`
- Modify: `packages/zigeffect/docs/app-facing-production-integration-readiness-review.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add the new operator guide**

Create `packages/zigeffect/docs/app-facing-production-integration-implementation-proposal.md` with sections:

- title `zigeffect Causal App-Facing Production Integration Implementation Proposal`;
- command sequence for fixtures, readiness review, and proposal approval;
- reject path;
- authority boundary fields including `app_mutation_enabled=false`;
- status definitions for `approved` and `blocked`;
- checks list including app runtime and agent-query scope;
- proposal phases;
- output paths;
- agent guidance;
- verification block.

- [ ] **Step 2: Update existing docs**

Add concise references to the new command and schema in the existing docs:

- `app-facing-production-integration-readiness-review.md`: state that ready
  artifacts feed the implementation proposal and show the proposal command.
- `agent-observable-runtime.md`: state that the proposal preserves bounded
  app trace/query evidence and forbids raw payload scraping.
- `schema-governance.md`: add the schema to the app-facing schema list and
  explain it is record-only, implementation-proposal, NenDB-only, no Cockroach,
  no live telemetry, and no production mutation.
- `production-hardening-backlog.md`: update the recommendation, delivered
  milestone list, and app-facing section.
- `operations.md`: add the app-facing proposal command after readiness review.
- `README.md`: add the app-facing proposal command and boundary summary after
  the readiness-review section.
- Master roadmap: change branch 49 from `Next` to `Delivered`, summarize the
  schema/tool, and add a new next branch for
  `codex/zigeffect-causal-app-facing-production-integration-boundary`.

- [ ] **Step 3: Run whitespace check**

Run:

```sh
git diff --check
```

Expected: PASS.

## Task 6: End-To-End Verification And Commit

**Files:**

- All files changed by Tasks 2-5

- [ ] **Step 1: Run focused proposal test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_implementation_proposal.zig
```

Expected: PASS.

- [ ] **Step 2: Run end-to-end artifact generation**

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
zig build causal-app-facing-production-integration-implementation-proposal -- \
  --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json \
  reject \
  --reason "negative proposal path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-implementation-proposal-negative
```

Expected: approved command emits `proposal_status: approved` and
`approved_for_next_branch: true`; reject command emits `proposal_status:
blocked`.

- [ ] **Step 3: Run schema, backlog, and package checks**

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

Expected: every command exits `0`.

- [ ] **Step 4: Inspect git diff**

Run:

```sh
git status --short
git diff --stat
```

Expected: only files listed in this plan are changed.

- [ ] **Step 5: Commit implementation**

Run:

```sh
git add docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-implementation-proposal-implementation.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  packages/zigeffect/README.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/agent-observable-runtime.md \
  packages/zigeffect/docs/app-facing-production-integration-implementation-proposal.md \
  packages/zigeffect/docs/app-facing-production-integration-readiness-review.md \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_app_facing_production_integration_implementation_proposal.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git commit -m "feat(zigeffect): add app-facing integration proposal"
```

Expected: commit succeeds after verification output has been read.
