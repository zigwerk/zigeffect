# zigeffect Causal Production Telemetry Implementation Proposal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a proposal-only production telemetry implementation artifact that consumes a ready readiness-review JSON and hands off to the exporter-boundary branch without enabling telemetry.

**Architecture:** Add one deterministic Zig tool that parses a readiness-review artifact, evaluates fixed proposal checks, and emits text/JSON proposal artifacts. Wire it through `build.zig`, schema governance, docs, and the production hardening backlog while preserving `mutation_authority=none`, NenDB-only durable scope, and SolidJS `zig-webui` workbench direction.

**Tech Stack:** Zig 0.16 build modules/tests, zigeffect causal artifact conventions, Bun verification commands, Markdown docs.

---

## File Structure

- Create `packages/zigeffect/tools/causal_production_telemetry_implementation_proposal.zig`: CLI parser, readiness JSON parser, proposal evaluator, text/JSON formatters, and unit tests.
- Modify `packages/zigeffect/build.zig`: register the new executable, build step, and tests.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`: register schema `zigeffect.causal.production-telemetry-implementation-proposal.v1`, update schema count tests, and add coverage assertions.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`: mark the implementation-proposal milestone delivered, update recommendation/next branch to exporter boundary, add dependency order and verification commands.
- Create `packages/zigeffect/docs/production-telemetry-implementation-proposal.md`: human operator guide and verification command examples.
- Modify existing zigeffect docs and roadmap files listed in the spec so the current next branch becomes `codex/zigeffect-causal-production-telemetry-exporter-boundary`.
- Modify `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`: add the delivered implementation-proposal milestone and next exporter-boundary handoff.

## Task 1: Red Test For Proposal Tool Contract

**Files:**

- Create: `packages/zigeffect/tools/causal_production_telemetry_implementation_proposal.zig`

- [ ] **Step 1: Add a compileable red-test scaffold**

Create the file with only tests and sentinel definitions:

```zig
const std = @import("std");

pub const production_telemetry_implementation_proposal_schema = "zigeffect.causal.production-telemetry-implementation-proposal.v1";
pub const production_telemetry_implementation_proposal_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-implementation-proposal";
pub const recommendation = "start-production-telemetry-exporter-boundary";
pub const next_branch_if_approved = "codex/zigeffect-causal-production-telemetry-exporter-boundary";

test "implementation proposal schema and authority constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-implementation-proposal.v1", production_telemetry_implementation_proposal_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_implementation_proposal_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-implementation-proposal", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-exporter-boundary", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-exporter-boundary", next_branch_if_approved);
    return error.ExpectedRedFailure;
}

test "parses approve proposal options with verified commands and output prefix" {
    return error.ExpectedRedFailure;
}

test "rejects missing readiness path decision and reason" {
    return error.ExpectedRedFailure;
}

test "derives implementation proposal output paths from readiness json path" {
    return error.ExpectedRedFailure;
}

test "approved and blocked proposal reports preserve non-live authority" {
    return error.ExpectedRedFailure;
}
```

- [ ] **Step 2: Run the focused red test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_implementation_proposal.zig
```

Expected: FAIL with `ExpectedRedFailure`.

- [ ] **Step 3: Commit is not allowed yet**

Do not commit the red scaffold. Continue directly to implementation in Task 2.

## Task 2: Implement Proposal Parser, Evaluator, And Formatters

**Files:**

- Modify: `packages/zigeffect/tools/causal_production_telemetry_implementation_proposal.zig`

- [ ] **Step 1: Add data model and parser**

Replace the red scaffold with a full implementation that provides:

```zig
const Decision = enum { approve, reject };
const ProposalStatus = enum { approved, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    readiness_path: []const u8,
    decision: Decision,
    proposed_by: []const u8 = "local-proposer",
    policy: []const u8 = "manual-production-telemetry-implementation-proposal",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,
};

const ReadinessCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8 = "",
};

const ReadinessSummary = struct {
    source_contract_count: usize = 0,
    positive_fixture_count: usize = 0,
    negative_fixture_count: usize = 0,
    validation_check_count: usize = 0,
};

const ReadinessArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_fixtures: []const u8 = "",
    decision: []const u8,
    readiness_status: []const u8,
    ready_for_implementation_proposal: bool,
    applied: bool,
    mutation_authority: []const u8,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    durable_write_enabled: bool,
    ci_gate_enabled: bool,
    fixture_summary: ReadinessSummary = .{},
    checks: []const ReadinessCheck = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};
```

Implement `parseOptions`, `parseDecision`, `outputPathsForOptions`, and
`main` using the same fail-closed conventions as
`causal_production_telemetry_readiness_review.zig`. Required parser behavior:

- `--from-readiness <readiness.json>` is required.
- Input path must end with `.json`.
- Decision must be `approve` or `reject`.
- `--reason <reason>` is required and non-empty.
- `--by`, `--policy`, `--verified-command`, and `--out-prefix` are optional.
- Unknown flags and missing flag values return errors.

- [ ] **Step 2: Add fixed proposal arrays**

Add these constants:

```zig
const readiness_schema = "zigeffect.causal.production-telemetry-readiness-review.v1";
const generated_by = "causal-production-telemetry-implementation-proposal";
const applied = false;
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const durable_write_enabled = false;
const ci_gate_enabled = false;

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-production-telemetry-capture-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const proposal_phases: []const []const u8 = &.{
    "exporter-boundary: add exporter-neutral no-network boundary fixtures while live export remains disabled",
    "local-pipeline-fixtures: route approved fixture shapes through local in-process redaction and sampling checks",
    "nendb-retention-fixtures: map retained telemetry fixture records to NenDB node edge and retention records without production writes",
    "workbench-readonly-preview: expose proposal and fixture status in SolidJS zig-webui without live streaming or mutation",
    "ci-artifact-preview: emit advisory local artifacts CI may archive later without failing telemetry thresholds",
};

const implementation_gates: []const []const u8 = &.{
    "source readiness artifact is ready and approved",
    "all readiness checks remain pass",
    "proposal verification commands are recorded exactly",
    "no live exporter collector endpoint or network send is configured",
    "durable work remains NenDB-only future scope",
    "workbench work remains SolidJS inside webui-dev/zig-webui",
};
```

- [ ] **Step 3: Implement proposal checks**

Implement `evaluateProposal` with these checks and status rules:

- `readiness-schema`
- `readiness-status`
- `readiness-decision-approved`
- `proposal-decision`
- `decision-approved`
- `authority-boundary`
- `source-fixtures-linked`
- `readiness-checks-passed`
- `readiness-verification-recorded`
- `proposal-verification-recorded`
- `nendb-only-scope`
- `solid-webui-scope`

Return `ProposalStatus.approved` only when every check passes. Return
`ProposalStatus.blocked` otherwise.

- [ ] **Step 4: Implement JSON and text reports**

The JSON report must include:

```json
{
  "schema": "zigeffect.causal.production-telemetry-implementation-proposal.v1",
  "schema_version": 1,
  "source_readiness": "<input path>",
  "source_fixtures": "<readiness source_fixtures>",
  "decision": "approve",
  "proposal_status": "approved",
  "approved_for_next_branch": true,
  "proposed_by": "local-proposer",
  "policy": "manual-production-telemetry-implementation-proposal",
  "reason": "<reason>",
  "applied": false,
  "mutation_authority": "none",
  "production_telemetry_ingestion": false,
  "live_exporter_enabled": false,
  "durable_write_enabled": false,
  "ci_gate_enabled": false,
  "source_branch": "codex/zigeffect-causal-production-telemetry-implementation-proposal",
  "recommendation": "start-production-telemetry-exporter-boundary",
  "next_branch_if_approved": "codex/zigeffect-causal-production-telemetry-exporter-boundary",
  "readiness_summary": { "source_contract_count": 7, "positive_fixture_count": 6, "negative_fixture_count": 14, "validation_check_count": 8 },
  "checks": [],
  "proposal_phases": [],
  "implementation_gates": [],
  "non_goals": [],
  "blocked_claims": [],
  "required_verification_commands": [],
  "verified_commands": [],
  "agent_guidance": []
}
```

The text report must include schema, source readiness, source fixtures,
proposal status, approved flag, authority fields, checks, proposal phases,
implementation gates, non-goals, blocked claims, required verification
commands, verified commands, and agent guidance.

- [ ] **Step 5: Run focused green test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_implementation_proposal.zig
```

Expected: PASS.

## Task 3: Wire Build Step And Build Tests

**Files:**

- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add module, executable, run step, and test artifact**

Near the readiness-review build block, add:

```zig
const causal_production_telemetry_implementation_proposal_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_telemetry_implementation_proposal.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_production_telemetry_implementation_proposal_tool = b.addExecutable(.{
    .name = "zigeffect-causal-production-telemetry-implementation-proposal",
    .root_module = causal_production_telemetry_implementation_proposal_tool_module,
});
const run_causal_production_telemetry_implementation_proposal_tool = b.addRunArtifact(causal_production_telemetry_implementation_proposal_tool);
if (b.args) |args| run_causal_production_telemetry_implementation_proposal_tool.addArgs(args);
const causal_production_telemetry_implementation_proposal_step = b.step("causal-production-telemetry-implementation-proposal", "Review production telemetry implementation proposal");
causal_production_telemetry_implementation_proposal_step.dependOn(&run_causal_production_telemetry_implementation_proposal_tool.step);

const causal_production_telemetry_implementation_proposal_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-production-telemetry-implementation-proposal-tests",
    .root_module = causal_production_telemetry_implementation_proposal_tool_module,
});
const run_causal_production_telemetry_implementation_proposal_tool_tests = b.addRunArtifact(causal_production_telemetry_implementation_proposal_tool_tests);
test_step.dependOn(&run_causal_production_telemetry_implementation_proposal_tool_tests.step);
```

- [ ] **Step 2: Run build step red/green check**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-implementation-proposal
```

Expected before a readiness path: usage error is acceptable only when invoked
without required args. The step itself must build the executable.

## Task 4: Register Schema Governance

**Files:**

- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`

- [ ] **Step 1: Add schema entry**

Add after the readiness-review schema entry:

```zig
.{
    .schema = "zigeffect.causal.production-telemetry-implementation-proposal.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-production-telemetry-implementation-proposal"},
    .consumed_by = &.{ "agents", "production hardening backlog", "future exporter boundary" },
    .compatibility = &.{ "record-only", "strict-v1" },
    .governance_requirements = &.{ "proposal tests", "backlog entry", "docs", "authority boundary checks" },
},
```

- [ ] **Step 2: Update schema tests**

Update tests to expect the new schema and increment the JSON schema count from
`53` to `54`.

- [ ] **Step 3: Verify governance command**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance -- --format json
```

Expected: PASS and JSON contains `"schema_count": 54`.

## Task 5: Update Backlog And Docs

**Files:**

- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Create: `packages/zigeffect/docs/production-telemetry-implementation-proposal.md`
- Modify: `packages/zigeffect/docs/production-telemetry-readiness-review.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/production-hardening-completion-audit.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update backlog constants and entry**

In `causal_production_hardening_backlog.zig` set:

```zig
pub const recommendation = "start-production-telemetry-exporter-boundary";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-exporter-boundary";
```

Append a delivered backlog item:

```zig
.{
    .id = "production-telemetry-implementation-proposal",
    .title = "Production Telemetry Implementation Proposal",
    .gap_id = "production-telemetry-implementation-proposal",
    .priority = "P5",
    .status = "delivered",
    .summary = "Consumes a ready telemetry readiness-review artifact and emits a proposal-only implementation sequence before exporter-boundary work.",
    .depends_on = &.{ "production-telemetry-readiness-review", "production-telemetry-capture-fixtures", "production-telemetry-capture-design" },
    .deliverables = &.{
        "readiness JSON proposal review",
        "approved and blocked proposal artifacts",
        "implementation phase plan",
        "exporter boundary handoff",
        "non-live authority checks",
    },
    .evidence_sources = &.{
        "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-implementation-proposal-design.md",
        "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-implementation-proposal-implementation.md",
        "packages/zigeffect/tools/causal_production_telemetry_implementation_proposal.zig",
        "packages/zigeffect/docs/production-telemetry-implementation-proposal.md",
    },
    .branch = "codex/zigeffect-causal-production-telemetry-implementation-proposal",
    .agent_guidance = "Use approved proposal artifacts to start the exporter-boundary branch only; do not infer live telemetry, durable writes, CI gates, non-NenDB adapters, alternate renderers, or mutation authority.",
},
```

Append `production-telemetry-implementation-proposal` to `dependency_order`.

- [ ] **Step 2: Add backlog verification commands**

Append commands for:

```sh
zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason "ready evidence reviewed for exporter boundary planning" --verified-command "zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-production-telemetry-capture-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json reject --reason "negative proposal path"
```

- [ ] **Step 3: Update docs**

Create the new docs page with command contract, boundary, statuses, checks,
proposal phases, output paths, agent guidance, and verification commands.

Update existing docs so the current delivered sequence is:

```text
production-telemetry-capture-design -> production-telemetry-capture-fixtures -> production-telemetry-readiness-review -> production-telemetry-implementation-proposal -> production-telemetry-exporter-boundary
```

Keep all mentions of durable production work scoped to NenDB only. Keep
workbench direction SolidJS inside `webui-dev/zig-webui`.

- [ ] **Step 4: Run doc/backlog focused checks**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-hardening-backlog -- --format json
```

Expected: PASS and report recommends
`codex/zigeffect-causal-production-telemetry-exporter-boundary`.

## Task 6: End-To-End Artifact Verification

**Files:**

- No new files unless implementation requires fixture artifacts under
  `.zig-cache/causal-artifacts`, which must remain untracked.

- [ ] **Step 1: Generate fixture JSON**

Run:

```sh
cd packages/zigeffect
mkdir -p ../../.zig-cache/causal-artifacts
zig build causal-production-telemetry-capture-fixtures -- --format json \
  2> ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json
```

Expected: exit 0 and the JSON file is non-empty.

- [ ] **Step 2: Generate ready readiness JSON**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json \
  approve \
  --reason "fixtures reviewed for implementation proposal" \
  --verified-command "zig build causal-production-telemetry-capture-fixtures -- validate --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Expected: text output contains `readiness_status: ready` and default JSON
artifact is written beside the fixture JSON.

- [ ] **Step 3: Generate approved proposal JSON**

Run:

```sh
cd packages/zigeffect
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

Expected: text output contains `proposal_status: approved`,
`approved_for_next_branch: true`, `mutation_authority: none`,
`live exporter enabled: false`, and
`next branch if approved: codex/zigeffect-causal-production-telemetry-exporter-boundary`.

- [ ] **Step 4: Generate blocked proposal JSON**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-implementation-proposal -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json \
  reject \
  --reason "negative proposal path"
```

Expected: text output contains `proposal_status: blocked` and
`approved_for_next_branch: false`.

## Task 7: Full Verification And Commit

**Files:**

- All files touched by Tasks 1-6.

- [ ] **Step 1: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_implementation_proposal.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected: all commands exit 0. Schema governance reports `"schema_count": 54`.

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

- [ ] **Step 4: Review diff**

Run:

```sh
git status --short
git diff --stat
git diff -- packages/zigeffect/tools/causal_production_telemetry_implementation_proposal.zig
```

Expected: only intended zigeffect causal files and docs are changed.

- [ ] **Step 5: Commit implementation**

Run:

```sh
git add packages/zigeffect/build.zig \
  packages/zigeffect/tools/causal_production_telemetry_implementation_proposal.zig \
  packages/zigeffect/tools/causal_schema_governance.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/docs/production-telemetry-implementation-proposal.md \
  packages/zigeffect/docs/production-telemetry-readiness-review.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/production-hardening-completion-audit.md \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/README.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): add production telemetry implementation proposal"
```

Expected: commit succeeds on
`codex/zigeffect-causal-production-telemetry-implementation-proposal`.

## Plan Self-Review

- Spec coverage: every design goal maps to tool behavior, build wiring,
  schema governance, backlog/docs updates, or verification tasks.
- Placeholder scan: no placeholder instructions remain.
- Type consistency: schema, command, branch, recommendation, status, and field
  names match the design spec.
- Scope check: exporter implementation, live telemetry, durable production
  writes, CI gates, non-NenDB adapters, React/alternate renderers, and mutation
  authority are explicitly excluded.
