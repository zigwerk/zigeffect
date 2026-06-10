# zigeffect Causal Production Hardening Completion Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a deterministic, schema-governed production-hardening completion audit that verifies delivered hardening milestones, preserves record-only/NenDB/SolidJS boundaries, and hands off to a local load-test observation harness branch.

**Architecture:** Implement one static Zig report tool with text and JSON outputs, then wire it into build steps, schema governance, backlog handoff, README, operations, roadmap, and dedicated docs. The tool cites authoritative evidence instead of reading live files or generated artifacts.

**Tech Stack:** Zig 0.16 build steps and tests, existing zigeffect causal tool patterns, Markdown docs, Bun verification commands, SolidJS workbench docs hosted by `webui-dev/zig-webui`, NenDB-only durable direction.

---

## Files And Responsibilities

- Create `packages/zigeffect/tools/causal_production_hardening_completion_audit.zig`
  - Owns `zigeffect.causal.production-hardening-completion-audit.v1`.
  - Provides static milestone checks, boundary checks, remaining evidence gaps,
    negative audit fixtures, agent guidance, non-goals, verification commands,
    and text/JSON formatters.
  - Tests option parsing, schema metadata, milestone coverage, boundary
    coverage, remaining gap coverage, negative fixtures, text output, JSON
    output, and next-branch recommendation.

- Modify `packages/zigeffect/build.zig`
  - Adds `causal-production-hardening-completion-audit` executable step.
  - Adds tool tests to `zig build test`.

- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Registers `zigeffect.causal.production-hardening-completion-audit.v1`.
  - Updates schema-count expectations from `48` to `49`.
  - Adds `completion-audit` compatibility posture text and tests.

- Modify `packages/zigeffect/docs/schema-governance.md`
  - Adds the compatibility posture and schema entry.

- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Adds `production-hardening-completion-audit` as delivered.
  - Updates recommendation to `start-load-test-observation-harness`.
  - Updates recommended next branch to
    `codex/zigeffect-causal-load-test-observation-harness`.
  - Adds the new command to verification commands.

- Create `packages/zigeffect/docs/production-hardening-completion-audit.md`
  - Documents command usage, schema, milestone checks, boundary checks,
    remaining gaps, negative fixtures, verification, and next branch.

- Modify `packages/zigeffect/README.md`
  - Adds the new command near the production-hardening backlog and capacity
    planning commands.

- Modify `packages/zigeffect/docs/operations.md`
  - Adds the command to the command map and a section for completion-audit use.

- Modify `packages/zigeffect/docs/production-hardening-backlog.md`
  - Marks completion audit delivered and updates the next branch.

- Modify `packages/zigeffect/docs/roadmap.md`
  - Records completion-audit delivery and new next branch.

- Modify `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Marks the completion-audit branch delivered and names the load-test
    observation harness as the current next branch.

## TDD Strategy

1. Create the audit tool with schema constants, type declarations, stub
   inventory functions, stub formatters, and tests that describe the desired
   inventory and boundaries.
2. Run `zig test tools/causal_production_hardening_completion_audit.zig` and
   confirm expected red failures.
3. Implement the static records and text/JSON formatters.
4. Run the focused tool test until it passes.
5. Wire the build step and run the command in text/JSON modes.
6. Register schema governance and backlog handoff tests.
7. Update docs and run full verification.

## Task 1: Add Failing Tool Tests

**Files:**

- Create `packages/zigeffect/tools/causal_production_hardening_completion_audit.zig`

- [ ] Add constants:

```zig
pub const production_hardening_completion_audit_schema = "zigeffect.causal.production-hardening-completion-audit.v1";
pub const production_hardening_completion_audit_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-hardening-completion-audit";
pub const recommendation = "start-load-test-observation-harness";
pub const next_branch = "codex/zigeffect-causal-load-test-observation-harness";
```

- [ ] Add type declarations:

```zig
const MilestoneCheck = struct {
    id: []const u8,
    status: []const u8,
    schema: []const u8,
    command: []const u8,
    doc: []const u8,
    evidence: []const u8,
    completion_boundary: []const u8,
    agent_guidance: []const u8,
};

const BoundaryCheck = struct {
    id: []const u8,
    decision: []const u8,
    evidence: []const u8,
    blocked_claim: []const u8,
    agent_guidance: []const u8,
};

const RemainingEvidenceGap = struct {
    id: []const u8,
    status: []const u8,
    reason: []const u8,
    recommended_branch: []const u8,
    blocked_until: []const u8,
};

const NegativeAuditFixture = struct {
    id: []const u8,
    attempted_claim: []const u8,
    decision: []const u8,
    reason: []const u8,
};

const AgentGuidance = struct {
    id: []const u8,
    guidance: []const u8,
};
```

- [ ] Add stub functions returning empty slices or `error.ExpectedRedFailure`:

```zig
fn parseOptions(args: []const []const u8) !OutputFormat {
    _ = args;
    return error.ExpectedRedFailure;
}

fn milestoneChecks() []const MilestoneCheck { return &.{}; }
fn boundaryChecks() []const BoundaryCheck { return &.{}; }
fn remainingEvidenceGaps() []const RemainingEvidenceGap { return &.{}; }
fn negativeAuditFixtures() []const NegativeAuditFixture { return &.{}; }
fn agentGuidance() []const AgentGuidance { return &.{}; }
fn nonGoals() []const []const u8 { return &.{}; }
fn verificationCommands() []const []const u8 { return &.{}; }

fn formatProductionHardeningCompletionAuditText(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return error.ExpectedRedFailure;
}

fn formatProductionHardeningCompletionAuditJson(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return error.ExpectedRedFailure;
}
```

- [ ] Add tests that should fail until implementation exists:
  - usage names `causal-production-hardening-completion-audit` and
    `--format text|json`;
  - parser accepts default, `text`, and `json`, and rejects unknown formats and
    flags;
  - milestone checks include all 16 current backlog dependency items;
  - status for `agent-query-interface` is `partial`;
  - boundary checks include record-only, mutation-authority-none, NenDB-only,
    SolidJS webui, capacity non-claim, alert/rollout preview, and production
    telemetry absent checks;
  - remaining gaps include `load-test-observation-harness` as
    `recommended-next`;
  - negative fixtures block Cockroach/non-NenDB, React/alternate renderer,
    capacity claims, live RBAC claims, and mutation authority;
  - text output includes recommendation, next branch, and record-only boundary;
  - JSON output includes schema, `applied=false`, `mutation_authority="none"`,
    milestone checks, boundary checks, remaining gaps, and next branch.

- [ ] Run expected red:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_completion_audit.zig
```

Expected: tests fail because parser, inventories, and formatters are stubs.

## Task 2: Implement The Static Audit Report

**Files:**

- Modify `packages/zigeffect/tools/causal_production_hardening_completion_audit.zig`

- [ ] Implement parser:

```zig
fn parseOptions(args: []const []const u8) !OutputFormat {
    if (args.len == 1) return .text;
    if (args.len == 3 and std.mem.eql(u8, args[1], "--format")) {
        if (std.mem.eql(u8, args[2], "text")) return .text;
        if (std.mem.eql(u8, args[2], "json")) return .json;
        return error.UnknownFormat;
    }
    if (args.len == 2 and std.mem.eql(u8, args[1], "--format")) return error.MissingFormat;
    return error.UnknownFlag;
}
```

- [ ] Fill `milestone_checks` with 16 entries:
  - `production-artifact-aggregation`
  - `durable-production-retention`
  - `production-deployment-runbooks`
  - `artifact-access-control`
  - `unified-causal-spine-contract`
  - `deep-runtime-internals`
  - `app-semantic-trace-api`
  - `agent-query-interface`
  - `encryption-at-rest-policy`
  - `alerting-integrations`
  - `live-dashboard-streaming-workbench`
  - `workbench-graph-visual-debugging`
  - `human-agent-feedback-loop`
  - `rollout-automation-guardrails`
  - `wall-clock-benchmark-baselines`
  - `production-capacity-planning`

- [ ] Fill `boundary_checks` with 11 entries:
  - `record-only-authority`
  - `mutation-authority-none`
  - `nendb-only-durable-direction`
  - `solidjs-webui-workbench-direction`
  - `capacity-planning-non-claim`
  - `wall-clock-advisory-only`
  - `alerting-and-rollout-preview-only`
  - `access-control-policy-only`
  - `encryption-policy-only`
  - `agent-query-bounded-read-only`
  - `production-telemetry-absent`

- [ ] Fill `remaining_evidence_gaps` with 10 entries:
  - `load-test-observation-harness` status `recommended-next`;
  - `production-telemetry-capture-design` status `future`;
  - `reviewed-production-capacity-sizing` status `future`;
  - `live-alert-delivery` status `future`;
  - `live-rollout-automation` status `future`;
  - `live-rbac-enforcement` status `future`;
  - `encryption-implementation` status `future`;
  - `production-dashboard-hosting` status `future`;
  - `agent-query-cross-run-comparison` status `future`;
  - `nendb-durable-history-hardening` status `future`.

- [ ] Fill negative fixtures:
  - `contract-reports-as-production-ready`
  - `capacity-plan-as-capacity-claim`
  - `cockroach-or-non-nendb-adapter`
  - `react-or-alternate-renderer`
  - `alert-preview-as-sent-alert`
  - `rollout-guardrail-as-traffic-shift`
  - `access-policy-as-live-rbac`
  - `encryption-policy-as-encrypted-bytes`
  - `wall-clock-baseline-as-ci-gate`
  - `completion-audit-as-mutation-authority`

- [ ] Implement text and JSON formatters using the existing helper style from
  `causal_production_capacity_planning.zig`: `std.ArrayList(u8).empty`,
  `appendJsonStringProperty`, `appendStringArray`, and explicit array loops.

- [ ] Run focused green:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_completion_audit.zig
```

Expected: all tests pass.

## Task 3: Add Build Integration

**Files:**

- Modify `packages/zigeffect/build.zig`

- [ ] Add module, executable, run step, and test step after
  `causal-production-capacity-planning`:

```zig
const causal_production_hardening_completion_audit_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_hardening_completion_audit.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_production_hardening_completion_audit_tool = b.addExecutable(.{
    .name = "zigeffect-causal-production-hardening-completion-audit",
    .root_module = causal_production_hardening_completion_audit_tool_module,
});
const run_causal_production_hardening_completion_audit_tool = b.addRunArtifact(causal_production_hardening_completion_audit_tool);
if (b.args) |args| run_causal_production_hardening_completion_audit_tool.addArgs(args);
const causal_production_hardening_completion_audit_step = b.step("causal-production-hardening-completion-audit", "Print causal production-hardening completion audit");
causal_production_hardening_completion_audit_step.dependOn(&run_causal_production_hardening_completion_audit_tool.step);

const causal_production_hardening_completion_audit_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-production-hardening-completion-audit-tests",
    .root_module = causal_production_hardening_completion_audit_tool_module,
});
const run_causal_production_hardening_completion_audit_tool_tests = b.addRunArtifact(causal_production_hardening_completion_audit_tool_tests);
test_step.dependOn(&run_causal_production_hardening_completion_audit_tool_tests.step);
```

- [ ] Run:

```sh
cd packages/zigeffect
zig build causal-production-hardening-completion-audit
zig build causal-production-hardening-completion-audit -- --format json
zig build test
```

Expected: commands succeed.

## Task 4: Register Schema Governance

**Files:**

- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify `packages/zigeffect/docs/schema-governance.md`

- [ ] Add schema entry:

```zig
.{
    .schema = "zigeffect.causal.production-hardening-completion-audit.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-production-hardening-completion-audit"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future load-test observation harness" },
    .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "completion-audit" },
    .governance_requirements = &.{ "completion audit tests", "boundary docs", "remaining gap docs", "next-branch handoff" },
},
```

- [ ] Add compatibility posture text:

```text
- completion-audit: deterministic milestone closure evidence with explicit
  remaining gaps and no production mutation authority
```

- [ ] Update schema count tests from `48` to `49`.

- [ ] Add expectations for the new schema and `completion-audit` posture in
  text and JSON tests.

- [ ] Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance -- --format json
zig build test
```

Expected: commands succeed and schema count is `49`.

## Task 5: Update Backlog Handoff

**Files:**

- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] Update constants:

```zig
pub const recommendation = "start-load-test-observation-harness";
pub const recommended_next_branch = "codex/zigeffect-causal-load-test-observation-harness";
```

- [ ] Add a delivered backlog item:

```zig
.{
    .id = "production-hardening-completion-audit",
    .title = "Production Hardening Completion Audit",
    .gap_id = "production-hardening-completion-audit",
    .priority = "P5",
    .status = "delivered",
    .summary = "Audits delivered production-hardening reports, confirms record-only NenDB-only and SolidJS webui boundaries, records remaining evidence gaps, and hands off to the load-test observation harness.",
    .depends_on = &.{ "production-capacity-planning", "wall-clock-benchmark-baselines", "rollout-automation-guardrails", "human-agent-feedback-loop" },
    .deliverables = &.{ "completion audit schema", "milestone evidence matrix", "authority boundary matrix", "remaining evidence gap register", "negative completion fixtures", "load-test observation harness handoff" },
    .evidence_sources = &.{ "packages/zigeffect/tools/causal_production_hardening_completion_audit.zig", "packages/zigeffect/docs/production-hardening-completion-audit.md", "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-hardening-completion-audit-design.md" },
    .branch = "codex/zigeffect-causal-production-hardening-completion-audit",
    .agent_guidance = "Use causal-production-hardening-completion-audit to close the contract sweep and start only the next local observation harness; do not claim production capacity or mutation authority.",
},
```

- [ ] Append `production-hardening-completion-audit` to `dependency_order`.

- [ ] Add verification commands:

```text
zig build causal-production-hardening-completion-audit
zig build causal-production-hardening-completion-audit -- --format json
```

- [ ] Update tests for the new recommendation, branch, delivered item, and
  command strings.

- [ ] Update the Markdown backlog to mark completion audit delivered and the
  next branch as `codex/zigeffect-causal-load-test-observation-harness`.

- [ ] Run:

```sh
cd packages/zigeffect
zig build causal-production-hardening-backlog -- --format json
zig build test
```

Expected: commands succeed.

## Task 6: Documentation Updates

**Files:**

- Create `packages/zigeffect/docs/production-hardening-completion-audit.md`
- Modify `packages/zigeffect/README.md`
- Modify `packages/zigeffect/docs/operations.md`
- Modify `packages/zigeffect/docs/roadmap.md`
- Modify `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] Create the completion-audit guide with:
  - command usage;
  - schema;
  - authority boundary;
  - milestone checks;
  - boundary checks;
  - remaining evidence gaps;
  - negative audit fixtures;
  - next branch;
  - verification commands.

- [ ] Add README command:

```sh
cd packages/zigeffect
zig build causal-production-hardening-completion-audit
zig build causal-production-hardening-completion-audit -- --format json
```

- [ ] Add operations command-map entries and a
  `## Production Hardening Completion Audit` section.

- [ ] Update roadmap and master roadmap:
  - mark completion audit delivered;
  - set current next branch to
    `codex/zigeffect-causal-load-test-observation-harness`;
  - preserve future gaps for production telemetry, reviewed capacity sizing,
    live alerting, rollout automation, RBAC, encryption implementation, dashboard
    hosting, cross-run comparison, and NenDB durable history hardening.

- [ ] Run stale-reference searches:

```sh
rg -n 'start-production-hardening-completion-audit|codex/zigeffect-causal-production-hardening-completion-audit`\\. It should audit|Current next branch: audit the delivered production-hardening reports' packages/zigeffect docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
rg -n 'codex/zigeffect-causal-load-test-observation-harness|start-load-test-observation-harness|causal-production-hardening-completion-audit' packages/zigeffect docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Expected: first command finds no stale next-branch language; second command
finds the new command and handoff references.

## Task 7: Final Verification And Commit

**Files:**

- All files from earlier tasks.

- [ ] Format Zig files:

```sh
zig fmt packages/zigeffect/tools/causal_production_hardening_completion_audit.zig packages/zigeffect/build.zig packages/zigeffect/tools/causal_schema_governance.zig packages/zigeffect/tools/causal_production_hardening_backlog.zig
```

- [ ] Run focused verification:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_completion_audit.zig
zig build causal-production-hardening-completion-audit
zig build causal-production-hardening-completion-audit -- --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

- [ ] Run broad verification:

```sh
cd packages/zigeffect
zig build examples
zig build test
cd ../..
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
bun run check
bun run zig:test
git diff --check
```

- [ ] Stage only completion-audit files and leave unrelated dirty files
  unstaged:

```sh
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  docs/superpowers/plans/2026-06-10-zigeffect-causal-production-hardening-completion-audit-implementation.md \
  packages/zigeffect/README.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/production-hardening-completion-audit.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_production_hardening_completion_audit.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
```

- [ ] Commit implementation:

```sh
git commit -m "feat(zigeffect): add production hardening completion audit"
```

Expected: one implementation commit on
`codex/zigeffect-causal-production-hardening-completion-audit`.
