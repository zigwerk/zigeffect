# zigeffect Causal Human-Agent Feedback Loop Design

Date: 2026-06-10

## Purpose

This branch turns the existing causal development pieces into a record-only
feedback loop that humans and agents can both follow while improving
`zigeffect` and apps built with it.

The previous branches delivered the ingredients:

- causal test and dev-loop artifacts;
- schema-stable agent query reports;
- before/after causal comparison;
- remediation audit, decision, proposal, readiness, and application records;
- durable retention contracts;
- a SolidJS workbench running inside `webui-dev/zig-webui`;
- Visual Graph perspectives for cause, topology, ownership, and lineage.

The missing piece is the loop contract. A maintainer should be able to select a
failure or suspicious event in the workbench, an agent should be able to ask the
right bounded queries, the resulting evidence should compare before and after a
candidate fix, repeated regressions should be grouped into stable signatures,
and any remediation should hand off to guarded proposal and application records.

This branch keeps mutation authority at `none`. It records what should happen
and what evidence exists. It does not apply patches, update registries, change
apps, write durable history, or train a learning system.

## Existing Evidence

The handoff comes from:

- `packages/zigeffect/docs/production-hardening-backlog.md`, which names
  `codex/zigeffect-causal-human-agent-feedback-loop` as the recommended next
  branch;
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`,
  which asks this branch to connect the human WebUI and agent query interface
  into a self-improving loop;
- `packages/zigeffect/docs/agent-observable-runtime.md`, which defines Phase 0
  dogfood development feedback;
- `packages/zigeffect/docs/agent-guide.md`, which documents the current causal
  query, compare, audit, registry, and app application commands;
- existing tools under `packages/zigeffect/tools/`:
  - `causal_test`, `causal_check`, `causal_dev_loop`,
    `causal_dev_session`, and `causal_dev_agent`;
  - `causal_query`;
  - `causal_compare`;
  - `causal_remediation_audit`, `causal_remediation_decision`,
    `causal_remediation_plan`, and related proposal tools;
  - `causal_registry_application_readiness` and `causal_registry_apply`;
  - `causal_app_apply`;
  - `causal_durable_production_retention`;
  - `causal_workbench` and the SolidJS workbench model.

## Design Brief

- Product: local and CI zigeffect causal feedback system.
- Human surface: SolidJS workbench inside `webui-dev/zig-webui`.
- Agent surface: bounded JSON command reports, especially
  `zigeffect.causal.agent-query.v1`.
- Durable direction: future NenDB adapter only.
- Work mode: record-only, deterministic, local-first.
- Mutation authority: `none`.
- Primary users: zigeffect core maintainers, development agents, app teams using
  zigeffect, and CI/handoff automation.

## Core Idea

The feedback loop is a shared evidence spine:

```text
failure or human selection
  -> bounded agent query plan
  -> query evidence bundle
  -> before/after comparison posture
  -> regression cluster record
  -> guarded remediation handoff
  -> future durable history handoff
```

The loop does not require every artifact to exist on day one. It should be able
to emit a useful record when only a source artifact and selected event are
known, then become richer as query, compare, audit, proposal, readiness, and
durable references are supplied.

## In Scope

- Add a deterministic feedback-loop report schema:
  `zigeffect.causal.human-agent-feedback-loop.v1`.
- Add a build command:

  ```sh
  zig build causal-human-agent-feedback-loop
  zig build causal-human-agent-feedback-loop -- --format json
  ```

- Emit text and JSON reports for maintainers and agents.
- Model five loop stages:
  - failure-to-query workflow;
  - before/after trace comparison workflow;
  - regression clustering records;
  - guarded remediation proposal handoff;
  - durable history learning handoff.
- Register the new schema in schema governance.
- Mark the production-hardening backlog item delivered after implementation.
- Document exact commands for local development agents.
- Keep the branch compatible with the existing SolidJS workbench, without
  requiring new workbench mutation features.
- Preserve future WebUI affordances by including stable ids and stage names that
  a workbench tab or inspector can consume later.

## Out Of Scope

- Autonomous source edits.
- Registry mutation.
- App mutation.
- Database, queue, R2, deployment, alert, ticket, page, or external service
  mutation.
- Durable writes.
- Durable clustering storage.
- Non-NenDB durable backend integration.
- React support.
- Training, fine-tuning, or background learning.
- Automatically running query commands from the workbench.
- Marking any remediation as applied without an existing reviewed application
  record.

## Use Cases

### 1. Core zigeffect Development Agent

A test fails while building core zigeffect. The agent reads the causal CI
handoff, opens the artifact named by the failing scenario, and asks bounded
queries before proposing a code change.

The feedback-loop record should name:

- the source artifact;
- the selected or failing event id;
- the first query to run;
- follow-up query commands;
- the compare command to run after a fix;
- any expected audit or proposal handoff.

### 2. Human Workbench Selection

A maintainer opens the SolidJS workbench and selects an event in the Visual
Graph lineage, ownership, topology, or cause perspective. The selection should
map into the same evidence model an agent uses.

The feedback-loop record should preserve:

- the workbench surface;
- the selected perspective;
- the selected event or graph node;
- the recommended agent query sequence;
- the read-only posture.

This branch does not need to add a new Workbench tab yet, but the record shape
should be ready for one.

### 3. App Team Issue Investigation

An app built with zigeffect emits semantic app runtime events. The agent should
be able to explain an app failure, trace data refs, cite event ids, and hand off
to guarded app remediation records.

The feedback-loop record should support:

- app artifact source paths;
- semantic refs such as `artifact_id`, `domain_entity_ref`,
  `data_subject_ref`, and `schema_ref`;
- app audit, decision, review, proposal, readiness, and application artifact
  references;
- a clear statement that app application is external to this loop.

### 4. Before/After Patch Review

After a candidate fix lands locally, a maintainer or agent should compare the
baseline and after artifacts. The feedback-loop record should explain what
evidence proves the fix, what changed, and what should still be queried.

The first branch can record compare intent and known compare artifacts. Later
branches can deepen this into run-to-run diff queries.

### 5. Regression Learning Without Durable Mutation

Repeated failures should begin forming stable signatures before any durable
learning backend exists. The loop can compute or record a cluster id using
bounded fields:

- source schema;
- scenario or target;
- finding kind;
- event kind;
- subsystem or owner lane;
- invariant or policy name;
- semantic data refs, when present.

The cluster record is local and advisory. Future NenDB retention can store
cluster histories behind a separate adapter and policy gate.

### 6. Guarded Remediation Handoff

The loop should make it natural to move from evidence to proposals without
blurring authority. A record can reference an audit, policy decision, proposal,
registry readiness, app readiness, or application artifact, but it cannot claim
the proposal was applied unless an existing application record says so.

## Architecture

The branch adds a new record-only tool:

```text
tools/causal_human_agent_feedback_loop.zig
```

It produces a report from a built-in baseline contract first. Later versions can
accept `--from-*` paths as inputs, but the first deterministic command should
prove the schema, stage names, guardrails, documentation, and backlog handoff.

The first implementation should follow the precedent set by production
hardening, schema governance, unified spine contract, and app application tools:

- small static data model;
- `--format text|json`;
- tests for usage, format parsing, schema, stage coverage, guardrails, and
  machine-readable output;
- registered `zig build` command;
- registered schema governance entry.

## Output Schema

Schema:

```text
zigeffect.causal.human-agent-feedback-loop.v1
```

Required top-level fields:

```json
{
  "schema": "zigeffect.causal.human-agent-feedback-loop.v1",
  "schema_version": 1,
  "producer": "causal-human-agent-feedback-loop",
  "mode": "local-record",
  "applied": false,
  "mutation_authority": "none",
  "source_branch": "codex/zigeffect-causal-human-agent-feedback-loop",
  "surface_contract": {
    "human_surface": "solidjs-webui-workbench",
    "agent_surface": "causal-query-agent-json",
    "durable_target": "future-nendb-adapter",
    "workbench_mutation": false,
    "agent_mutation": false
  },
  "stages": [],
  "regression_clusters": [],
  "guarded_handoffs": [],
  "durable_history_handoffs": [],
  "verification_commands": [],
  "guardrails": [],
  "next_branch": "codex/zigeffect-causal-rollout-automation-guardrails"
}
```

Stage fields:

```json
{
  "id": "failure-to-query",
  "title": "Failure To Query",
  "status": "ready",
  "consumes": ["zigeffect.causal.v1", "zigeffect.causal.workbench-session.v1"],
  "produces": ["zigeffect.causal.agent-query.v1"],
  "human_action": "select failed event or graph node",
  "agent_action": "run bounded causal-query commands before proposing edits",
  "commands": [
    "zig build causal-query -- --agent --file <artifact.json> explain_event <event_id>"
  ],
  "evidence_refs": [],
  "guardrails": ["read-only", "bounded", "cite-event-ids"]
}
```

## Stage Design

### Stage 1: Failure To Query

Inputs:

- causal artifact;
- causal CI verdict or handoff;
- dev-loop verdict;
- workbench session;
- selected event id or selected graph node.

Outputs:

- recommended `causal-query --agent` commands;
- bounded context expectations;
- limitations for missing selections or legacy artifacts.

Default command sequence:

```sh
zig build causal-query -- --agent --file <artifact.json> explain_event <event_id>
zig build causal-query -- --agent --file <artifact.json> trace_cause <event_id>
zig build causal-query -- --agent --file <artifact.json> next_queries 3
```

For semantic app events:

```sh
zig build causal-query -- --agent --file <artifact.json> trace_data <data_subject_ref>
```

### Stage 2: Before/After Trace Comparison

Inputs:

- baseline artifact;
- after artifact;
- optional compare report.

Outputs:

- compare command;
- fields to cite in summaries;
- limitations when compare artifacts do not exist yet.

Default command:

```sh
zig build causal-compare -- <before.json> <after.json>
```

The feedback-loop record should not pretend comparison happened when only a
command is listed. It should distinguish:

- `planned`: command is known;
- `captured`: compare artifact exists;
- `verified`: compare artifact and verification command were recorded.

### Stage 3: Regression Clustering Records

Inputs:

- findings;
- event kinds;
- selected event ids;
- scenario or target;
- app semantic refs when present.

Outputs:

- local cluster id;
- pattern signature;
- evidence ids;
- learning priority;
- future durable handoff target.

Cluster ids should be deterministic enough for agents to cite. A recommended
shape:

```text
cluster:<target>:<finding-kind>:<event-kind>:<owner-or-scope>:<semantic-ref-or-none>
```

This is a record, not persistent learning. It becomes durable only in the future
NenDB adapter milestone.

### Stage 4: Guarded Remediation Proposal Handoff

Inputs:

- remediation audit;
- policy decision;
- human review, when required;
- patch proposal;
- registry or app readiness;
- registry or app application record, when one already exists.

Outputs:

- handoff status;
- required next reviewed command;
- application boundary warning.

The stage should preserve this distinction:

- `proposal-ready`: evidence supports preparing a proposal;
- `ready-for-application`: readiness artifact says application can proceed;
- `record-applied`: an external reviewed application record says the change was
  applied;
- `blocked`: policy, review, verification, or readiness failed.

The feedback-loop command never upgrades a proposal to applied.

### Stage 5: Durable History Learning Handoff

Inputs:

- feedback-loop record;
- regression cluster record;
- retention policy;
- future durable backend policy.

Outputs:

- handoff target;
- minimum durable fields;
- policy constraints.

The durable direction is NenDB adapter only. This branch should not add another
durable backend, infrastructure bridge, or production durable write path.

Minimum future fields:

- feedback-loop record id;
- cluster id;
- scenario or target;
- source artifact refs;
- query report refs;
- compare report refs;
- proposal and readiness refs;
- redaction posture;
- retention class;
- expiration or pruning policy.

## Human Surface Contract

The workbench should remain read-only. The first implementation can document the
surface contract without adding UI. Later UI work can expose:

- a selected event's query commands;
- a feedback-loop stage checklist;
- compare artifact slots;
- cluster signature preview;
- guarded handoff summary;
- copyable CLI commands.

The UI should never trigger source, registry, app, deployment, alert, ticket, or
durable mutation without a separate reviewed boundary.

## Agent Surface Contract

Agents should treat the feedback-loop record as a plan and evidence index.

Required agent behavior:

- run bounded queries before proposing fixes;
- cite event ids and artifact paths;
- distinguish planned commands from executed evidence;
- compare before/after artifacts before claiming behavioral improvement;
- preserve limitations and compatibility warnings;
- hand off remediation through existing guarded tools.

Prohibited agent behavior:

- infer that a proposed fix has been applied;
- infer that durable learning happened;
- mutate app source from the feedback-loop record alone;
- skip policy, review, readiness, or application records.

## Documentation Changes

Add:

- `packages/zigeffect/docs/human-agent-feedback-loop.md`

Update:

- `packages/zigeffect/docs/agent-observable-runtime.md`;
- `packages/zigeffect/docs/agent-guide.md`;
- `packages/zigeffect/docs/operations.md`;
- `packages/zigeffect/docs/production-hardening-backlog.md`;
- `packages/zigeffect/docs/roadmap.md`;
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`.

## Tests And Verification

New focused tests:

- usage names `causal-human-agent-feedback-loop`;
- format parser accepts text and JSON;
- unknown formats fail closed;
- report schema is `zigeffect.causal.human-agent-feedback-loop.v1`;
- report contains all five stages;
- report keeps `applied=false`;
- report keeps `mutation_authority=none`;
- report names SolidJS WebUI and agent JSON surfaces;
- report names future NenDB durable handoff;
- report names only the future NenDB adapter as the durable target;
- JSON report is machine readable enough for agents to locate stages,
  commands, clusters, handoffs, guardrails, and next branch.

Branch verification:

```sh
zig build causal-human-agent-feedback-loop
zig build causal-human-agent-feedback-loop -- --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
bun run check
bun run zig:test
git diff --check
```

## Implementation Tasks

1. Add `tools/causal_human_agent_feedback_loop.zig` with static stage, cluster,
   handoff, durable handoff, verification, and guardrail records.
2. Add a `causal-human-agent-feedback-loop` build step and tests in
   `packages/zigeffect/build.zig`.
3. Register the schema in `causal_schema_governance.zig`.
4. Add `packages/zigeffect/docs/human-agent-feedback-loop.md`.
5. Update agent, operations, runtime, backlog, roadmap, and master roadmap docs.
6. Mark the production-hardening backlog item delivered and hand off to
   `codex/zigeffect-causal-rollout-automation-guardrails`.
7. Run focused commands, then full branch verification.
8. Commit the implementation after verification.

## Risks

- Too much orchestration could imply autonomous authority. The schema must keep
  `applied=false` and `mutation_authority=none` visible.
- Regression clustering could be mistaken for durable learning. The cluster
  stage must call itself local and advisory.
- Human workbench selection could be mistaken for an execution trigger. The
  workbench contract must stay read-only.
- Compare commands could be mistaken for compare evidence. Status fields must
  distinguish planned, captured, and verified.
- Durable handoff could drift into unsupported backend scope. The durable
  target remains future NenDB adapter only.

## Acceptance Criteria

- `zig build causal-human-agent-feedback-loop` prints a human-readable report
  with all five stages.
- `zig build causal-human-agent-feedback-loop -- --format json` emits a
  schema-stable JSON report with `applied=false` and
  `mutation_authority=none`.
- Schema governance includes
  `zigeffect.causal.human-agent-feedback-loop.v1`.
- Production hardening backlog marks `human-agent-feedback-loop` delivered and
  recommends `codex/zigeffect-causal-rollout-automation-guardrails`.
- Docs teach the failure-to-query, before/after compare, regression cluster,
  guarded handoff, and NenDB durable handoff workflows.
- Full verification passes without touching unrelated pre-existing local docs.
