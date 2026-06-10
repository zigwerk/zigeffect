# Human-Agent Feedback Loop

`causal-human-agent-feedback-loop` is the record-only contract that connects the
human SolidJS workbench, bounded agent query reports, before/after causal
comparison, local regression clustering, guarded remediation handoffs, and a
future NenDB durable-history handoff.

It emits `zigeffect.causal.human-agent-feedback-loop.v1`.

```sh
zig build causal-human-agent-feedback-loop
zig build causal-human-agent-feedback-loop -- --format json
```

The report is deterministic. It does not read live systems, edit source, update
registries, apply app changes, write durable history, run deployments, or grant
mutation authority. It always keeps:

```text
applied=false
mutation_authority=none
workbench_mutation=false
agent_mutation=false
durable_target=future-nendb-adapter
```

## When To Use It

Use the feedback-loop report when a human or agent needs to turn causal evidence
into a disciplined next step:

- a zigeffect core test fails;
- a CI handoff names causal artifacts;
- a maintainer selects a suspicious event in the workbench;
- an app built on zigeffect emits semantic app events;
- a candidate fix needs before/after comparison;
- a repeated failure should become a local regression cluster;
- evidence should hand off to an audit, proposal, readiness, or application
  record without claiming mutation.

## The Five Stages

### 1. Failure To Query

Start from a causal artifact, CI verdict, dev-loop verdict, or workbench
selection. The stage tells agents which bounded queries to run before proposing
edits.

```sh
zig build causal-query -- --agent --file <artifact.json> explain_event <event_id>
zig build causal-query -- --agent --file <artifact.json> trace_cause <event_id>
zig build causal-query -- --agent --file <artifact.json> next_queries 3
```

For app semantic data-lineage events:

```sh
zig build causal-query -- --agent --file <artifact.json> trace_data <data_subject_ref>
```

Agent outputs use `zigeffect.causal.agent-query.v1` and should cite event ids,
policy state, truncation state, limitations, and recommended next queries.

### 2. Before/After Trace Comparison

After a candidate fix, compare the baseline and after artifacts:

```sh
zig build causal-compare -- <before.json> <after.json>
```

Use the compare report to cite finding deltas, event deltas, added events,
removed events, and changed events. Do not claim a fix improved behavior just
because the command is listed. The feedback loop distinguishes planned,
captured, and verified comparison evidence.

### 3. Regression Clustering Records

Repeated failures should be grouped locally before any durable history exists.
The report defines a deterministic advisory cluster shape:

```text
cluster:<target>:<finding-kind>:<event-kind>:<owner-or-scope>:<semantic-ref-or-none>
```

This is not persistent learning and does not train anything. It is a compact
way to help humans and agents notice that the same invariant is failing again.
Future durable history belongs behind the NenDB adapter handoff.

### 4. Guarded Remediation Proposal Handoff

The loop can point to existing governance artifacts:

- `zigeffect.causal.remediation-audit.v1`;
- `zigeffect.causal.remediation-decision.v1`;
- `zigeffect.causal.patch-proposal.v1`;
- `zigeffect.causal.registry-application-readiness.v1`;
- `zigeffect.causal.app-application-readiness.v1`;
- registry or app application records, when they already exist.

The feedback-loop command never upgrades a proposal to applied. Application
claims must come from the existing guarded registry or app application boundary.

### 5. Durable History Learning Handoff

The durable target is future NenDB adapter handoff only. The report records the
fields a later durable branch needs:

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

This branch performs no durable writes.

## Human Workbench Workflow

Open a saved artifact in the local workbench:

```sh
zig build causal-workbench -- .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
```

The workbench is a SolidJS app launched through `webui-dev/zig-webui`. It is a
read-only human control room for timeline, findings, artifacts, remediation
records, live samples, and Visual Graph perspectives.

When a human selects an event or graph node, the feedback loop gives the agent
side of the same evidence:

```sh
zig build causal-human-agent-feedback-loop -- --format json
zig build causal-query -- --agent --file <artifact.json> explain_event <event_id>
zig build causal-query -- --agent --file <artifact.json> trace_cause <event_id>
```

The selection is evidence context, not approval to edit.

## Core zigeffect Dogfood Workflow

For a local zigeffect failure:

```sh
zig build causal-test
zig build causal-query -- --agent --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json find_failures 1
zig build causal-human-agent-feedback-loop -- --format json
```

For a fix attempt:

```sh
zig build causal-dev-loop -- baseline <scenario>
# make the reviewed code change
zig build causal-dev-loop -- after <scenario>
zig build causal-compare -- .zig-cache/causal-artifacts/<scenario>-before.json .zig-cache/causal-artifacts/<scenario>-after.json
```

Agents should cite the failing event id, query output, compare output, and
verification command before claiming improvement.

## App-Facing Workflow

Apps built on zigeffect can emit semantic refs such as `artifact_id`,
`domain_entity_ref`, `data_subject_ref`, and `schema_ref`.

For app incidents:

```sh
zig build causal-query -- --agent --file <app-artifact.json> trace_data <data_subject_ref>
zig build causal-human-agent-feedback-loop -- --format json
```

If remediation is needed, preserve the existing app governance chain:

```sh
zig build causal-app-remediation-audit -- --from-app-artifact <app-artifact.json>
zig build causal-app-policy-decision -- --from-audit <app-remediation-audit.json> approve|reject --reason <reason>
zig build causal-app-patch-proposal -- --from-decision <app-policy-decision.json>
zig build causal-app-application-readiness -- --from-proposal <app-patch-proposal.json> approve|reject --reason <reason>
zig build causal-app-apply -- --from-readiness <app-application-readiness.json> plan --reason <reason>
```

Use `record-applied` only when an actual reviewed app application happened and
before/after verification evidence exists.

## Agent Rules

Agents consuming the report should:

- run bounded `causal-query --agent` commands before proposing fixes;
- cite event ids, artifact paths, findings, and limitations;
- compare before/after artifacts before claiming a behavioral improvement;
- distinguish planned commands from executed evidence;
- use existing audit, decision, proposal, readiness, and application tools for
  remediation handoff;
- keep local regression clusters advisory;
- leave durable history to a future NenDB adapter branch.

Agents must not:

- infer that a proposal was applied;
- treat a workbench selection as edit approval;
- write source, registry, app, deployment, alert, ticket, or durable state from
  this report;
- claim durable learning happened;
- skip policy, review, readiness, or application records.

## Verification

Run the focused checks after changing the feedback-loop contract:

```sh
zig test tools/causal_human_agent_feedback_loop.zig
zig build causal-human-agent-feedback-loop
zig build causal-human-agent-feedback-loop -- --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Run the broader branch suite before handoff:

```sh
zig build examples
zig build test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
bun run check
bun run zig:test
git diff --check
```
