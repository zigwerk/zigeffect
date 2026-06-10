# zigeffect Causal Human-Agent Feedback Loop Implementation Plan

Date: 2026-06-10

Spec:
`docs/superpowers/specs/2026-06-10-zigeffect-causal-human-agent-feedback-loop-design.md`

Branch:
`codex/zigeffect-causal-human-agent-feedback-loop`

## Objective

Deliver the first record-only human-agent feedback loop milestone for
`zigeffect`.

The branch should add a deterministic feedback-loop contract that connects:

- human workbench selections;
- bounded agent query commands;
- before/after causal comparison;
- local regression clustering records;
- guarded remediation handoffs;
- future NenDB durable history handoff.

Mutation authority remains `none`.

## Success Criteria

- `zig build causal-human-agent-feedback-loop` prints a human-readable report.
- `zig build causal-human-agent-feedback-loop -- --format json` prints
  `zigeffect.causal.human-agent-feedback-loop.v1`.
- The report contains all five stages:
  - `failure-to-query`;
  - `before-after-trace-comparison`;
  - `regression-clustering-records`;
  - `guarded-remediation-proposal-handoff`;
  - `durable-history-learning-handoff`.
- The report always says:
  - `applied=false`;
  - `mutation_authority=none`;
  - `workbench_mutation=false`;
  - `agent_mutation=false`;
  - durable target is the future NenDB adapter.
- Schema governance includes the new schema.
- Production hardening backlog marks the item delivered and recommends
  `codex/zigeffect-causal-rollout-automation-guardrails`.
- Docs explain how agents and humans use the loop.
- Full verification passes.

## Non-Goals

- No source mutation.
- No registry mutation.
- No app mutation.
- No durable writes.
- No durable backend other than future NenDB adapter handoff.
- No new Workbench mutation UI.
- No React work.
- No autonomous remediation.

## Test-Driven Implementation

### Red Phase

Add or update tests before the implementation is complete:

1. `tools/causal_human_agent_feedback_loop.zig`
   - usage names `causal-human-agent-feedback-loop`;
   - parser accepts default text format;
   - parser accepts `--format text`;
   - parser accepts `--format json`;
   - parser rejects unknown formats;
   - text report includes schema, mutation posture, all five stages, and next
     branch;
   - JSON report includes schema, version, producer, mode, `applied=false`,
     `mutation_authority=none`, stages, clusters, guarded handoffs, durable
     handoffs, verification commands, guardrails, and next branch;
   - JSON report names SolidJS WebUI, agent JSON, and future NenDB adapter;
   - JSON report does not name unsupported durable targets.

2. `tools/causal_schema_governance.zig`
   - inventory includes `zigeffect.causal.human-agent-feedback-loop.v1`;
   - schema count assertions update by one;
   - JSON report includes the new schema.

3. `tools/causal_production_hardening_backlog.zig`
   - recommendation changes to `start-rollout-automation-guardrails`;
   - recommended branch changes to
     `codex/zigeffect-causal-rollout-automation-guardrails`;
   - backlog includes `human-agent-feedback-loop` as `delivered`;
   - JSON report includes evidence sources for the new tool and docs.

Expected early failing commands:

```sh
zig test tools/causal_human_agent_feedback_loop.zig
zig build test
```

### Green Phase

Implement the smallest code that satisfies the tests:

1. Create `packages/zigeffect/tools/causal_human_agent_feedback_loop.zig`.
2. Add static records for:
   - stages;
   - regression clusters;
   - guarded handoffs;
   - durable history handoffs;
   - verification commands;
   - guardrails.
3. Implement `--format text|json`.
4. Add JSON string escaping using existing local helper style.
5. Add `main`, `run`, `buildTextReport`, and `buildJsonReport`.
6. Register the module, executable, build step, and tests in
   `packages/zigeffect/build.zig`.
7. Update schema governance.
8. Update production hardening backlog.

### Refactor Phase

After tests pass:

- simplify repeated text and JSON output helpers;
- keep the tool deterministic and dependency-free;
- avoid adding dynamic artifact parsing until a later branch;
- keep names aligned with docs and backlog.

## File Plan

Create:

- `packages/zigeffect/tools/causal_human_agent_feedback_loop.zig`;
- `packages/zigeffect/docs/human-agent-feedback-loop.md`.

Modify:

- `packages/zigeffect/build.zig`;
- `packages/zigeffect/tools/causal_schema_governance.zig`;
- `packages/zigeffect/tools/causal_production_hardening_backlog.zig`;
- `packages/zigeffect/docs/agent-observable-runtime.md`;
- `packages/zigeffect/docs/agent-guide.md`;
- `packages/zigeffect/docs/operations.md`;
- `packages/zigeffect/docs/production-hardening-backlog.md`;
- `packages/zigeffect/docs/roadmap.md`;
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`.

Do not touch unrelated dirty local files unless a verification command proves
they block this branch.

## Report Model

### Constants

```zig
pub const feedback_loop_schema = "zigeffect.causal.human-agent-feedback-loop.v1";
pub const feedback_loop_schema_version: u32 = 1;
pub const producer = "causal-human-agent-feedback-loop";
pub const mode = "local-record";
pub const source_branch = "codex/zigeffect-causal-human-agent-feedback-loop";
pub const next_branch = "codex/zigeffect-causal-rollout-automation-guardrails";
```

### Types

```zig
const LoopStage = struct {
    id: []const u8,
    title: []const u8,
    status: []const u8,
    consumes: []const []const u8,
    produces: []const []const u8,
    human_action: []const u8,
    agent_action: []const u8,
    commands: []const []const u8,
    evidence_refs: []const []const u8,
    guardrails: []const []const u8,
};

const RegressionCluster = struct {
    id: []const u8,
    pattern_signature: []const u8,
    status: []const u8,
    evidence_refs: []const []const u8,
    learning_priority: []const u8,
    durable_target: []const u8,
};

const GuardedHandoff = struct {
    id: []const u8,
    status: []const u8,
    consumes: []const []const u8,
    produces: []const []const u8,
    required_boundary: []const u8,
    mutation_authority: []const u8,
};

const DurableHistoryHandoff = struct {
    id: []const u8,
    status: []const u8,
    target: []const u8,
    writes_now: bool,
    required_fields: []const []const u8,
    policy_constraints: []const []const u8,
};
```

Exact structure can be adjusted to local style while preserving the schema
fields and semantics.

## Stage Records

### `failure-to-query`

Consumes:

- `zigeffect.causal.v1`;
- `zigeffect.causal.workbench-session.v1`;
- `zigeffect.causal.ci-verdict.v1`;
- `zigeffect.causal.dev-loop-verdict.v1`.

Produces:

- `zigeffect.causal.agent-query.v1`.

Commands:

```sh
zig build causal-query -- --agent --file <artifact.json> explain_event <event_id>
zig build causal-query -- --agent --file <artifact.json> trace_cause <event_id>
zig build causal-query -- --agent --file <artifact.json> next_queries 3
```

### `before-after-trace-comparison`

Consumes:

- baseline causal artifact;
- after causal artifact;
- optional compare report.

Produces:

- compare posture;
- evidence checklist.

Command:

```sh
zig build causal-compare -- <before.json> <after.json>
```

Statuses:

- `planned`;
- `captured`;
- `verified`.

### `regression-clustering-records`

Consumes:

- findings;
- event kinds;
- scenario or target;
- semantic refs when present.

Produces:

- local cluster id;
- pattern signature;
- learning priority;
- future durable handoff target.

Pattern:

```text
cluster:<target>:<finding-kind>:<event-kind>:<owner-or-scope>:<semantic-ref-or-none>
```

### `guarded-remediation-proposal-handoff`

Consumes:

- audit;
- policy decision;
- human review;
- proposal;
- readiness;
- optional application record.

Produces:

- required next reviewed command;
- handoff status;
- warning that this loop cannot apply changes.

### `durable-history-learning-handoff`

Consumes:

- feedback-loop record;
- local regression cluster record;
- retention policy.

Produces:

- future NenDB adapter handoff fields;
- no write operation.

## Documentation Tasks

### New Guide

`packages/zigeffect/docs/human-agent-feedback-loop.md` should include:

- what the loop is;
- when to use it;
- command quick start;
- five-stage explanation;
- workbench selection workflow;
- core zigeffect dogfood workflow;
- app-facing workflow;
- before/after compare workflow;
- regression clustering explanation;
- guarded handoff explanation;
- future NenDB adapter handoff;
- non-goals and guardrails.

### Existing Docs

`agent-observable-runtime.md`

- Add this branch as the concrete loop contract for Phase 0.
- Explain that `causal-query` remains the bounded query primitive.
- Explain that cross-run comparison is still command-level via
  `causal-compare`, not a `causal-query compare_runs` implementation.

`agent-guide.md`

- Add command examples.
- Add agent rules for using the feedback-loop report before proposing fixes.
- Add app-facing examples that hand off to app readiness and app application
  records.

`operations.md`

- Add the command to local and CI evidence workflows.
- Keep operational posture read-only.

`production-hardening-backlog.md`

- Mark the item delivered.
- Name rollout automation guardrails as next.

`roadmap.md`

- Add a short milestone note and next branch handoff.

Master roadmap spec

- Mark this branch delivered after implementation.
- Update the next branch pointer.

## Verification Sequence

Focused:

```sh
zig test tools/causal_human_agent_feedback_loop.zig
zig build causal-human-agent-feedback-loop
zig build causal-human-agent-feedback-loop -- --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Workbench compatibility:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
```

Full branch:

```sh
zig build examples
zig build test
bun run check
bun run zig:test
git diff --check
```

## Commit Plan

Commit 1:

```text
docs(zigeffect): plan human agent feedback loop
```

Commit 2:

```text
feat(zigeffect): add human agent feedback loop contract
```

Commit 3, only if docs are substantial enough to separate:

```text
docs(zigeffect): document human agent feedback loop workflow
```

It is also acceptable to combine implementation and docs into one feature
commit after full verification if the diff stays coherent.
