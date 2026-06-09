# zigeffect Causal Agent Query Interface Design

Date: 2026-06-09
Branch: `codex/zigeffect-causal-agent-query-interface`
Status: Approved for implementation

## Goal

Add the first bounded, schema-stable agent query envelope over the unified
causal spine so agents can consume runtime facts without parsing human-oriented
text.

This branch is the runtime query boundary after deep runtime internals. It
consumes the newly emitted `layer_id`, `service_key`, `resource_id`,
`cause_event_id`, and `schedule_id` fields. It does not implement the future app
semantic trace API, but it leaves explicit room for `trace_data` once app
semantic refs exist.

## Problem

`causal-query` currently gives agents useful local text:

- `snapshot`
- `cause`
- `lineage`
- `resources`
- `fibers`
- `requirements`
- `retries`

That text is good for humans and quick debugging, but it is not enough for the
next self-improving loop. Agents need compact responses with:

- a stable response schema;
- query name and arguments;
- bounded result counts;
- selected event ids;
- explicit relationship records;
- retention, sampling, truncation, and compatibility limitations;
- recommended next queries.

Without this boundary, later remediation, workbench, and self-improvement tools
must keep re-parsing ad hoc text and reconstructing relationships from labels.

## Selected Approach

Extend `packages/zigeffect/tools/causal_query.zig` with an `--agent` output
mode.

The existing text output remains the default for compatibility. `--agent`
returns JSON using a new schema:

`zigeffect.causal.agent-query.v1`

The first branch keeps the command surface small and close to current queries:

- `summarize_run <run_id>`
- `find_failures <run_id>`
- `explain_event <event_id>`
- `trace_cause <event_id>`
- `list_findings <run_id>`
- `next_queries <event_id>`

It also keeps existing text aliases working:

- `trace_cause` shares selection behavior with current `cause`.
- `explain_event` returns the event, its cause chain, direct children, and
  relationship edges.
- `find_failures` returns finding-evidence events for failures, missing
  requirements, retry exhaustion, finalizer failures, failed assertions, defects,
  and interruptions in the run.
- `summarize_run` returns all events for the run, bounded by a default limit,
  plus summary counts and next-query hints.
- `list_findings` returns the same failure/finding evidence in a finding-focused
  envelope.
- `next_queries` returns query hints for a selected event id without needing the
  agent to infer commands.

## Agent JSON Shape

The agent response should include:

- `schema`
- `schema_version`
- `query`
- `arguments`
- `bounded`
- `limit`
- `total_matched_events`
- `returned_events`
- `events`
- `relationships`
- `policy`
- `warnings`
- `limitations`
- `next_queries`

Events are compact records containing:

- `id`
- `kind`
- `run_id`
- `parent_id`
- `cause_event_id`
- `fiber_id`
- `scope_id`
- `layer_id`
- `service_key`
- `resource_id`
- `schedule_id`
- `label`
- `type_name`
- `status`

Relationships are derived records:

- `parent_of`: from `parent_id` to `id`
- `caused_by`: from `cause_event_id` to `id`
- `requires`: layer/service requirement events
- `provides`: layer/service provider events
- `owns`: scope/resource and fiber/scope ownership hints
- `finalizes`: resource finalizer events

The relationship index is rebuildable from source events. It is not a new
mutation authority.

## Bounded Behavior

Agent mode must be bounded by default. Use a conservative default limit of 32
events. Support `--limit <n>` with a small maximum cap of 256.

When more events match than are returned, set:

- `bounded = true`
- `total_matched_events` to the full matched count
- `returned_events` to the returned count
- a limitation noting that the slice was truncated by query limit

Policy metadata must reflect artifact-level:

- retention limits and dropped count when present;
- sampling limits and sampled count when present;
- truncation limits and truncated count when present;
- compatibility warnings from schema/taxonomy checks.

Legacy artifacts without policy metadata remain readable, but the response must
say the policy metadata is unavailable.

## CLI Compatibility

The existing usage remains valid:

```sh
zig build causal-query -- --file <artifact.json> cause 3
```

Agent mode adds:

```sh
zig build causal-query -- --agent --file <artifact.json> explain_event 3
zig build causal-query -- --agent --limit 16 --file <artifact.json> summarize_run 1
```

Option parsing should allow `--agent`, `--limit`, and `--file` before the query
name. Unknown options and invalid limits fail with typed usage errors.

## Non-Goals

- App semantic trace emission.
- Real `trace_data(data_subject_ref)` behavior.
- Comparing separate artifacts or separate run ids across files.
- Workbench UI changes.
- NenDB relationship edge projection changes.
- Cockroach adapter work.
- React workbench support.
- Mutation authority.

## Future Hooks

After app semantic trace events exist, a later branch should add:

- `trace_data <data_subject_ref>`
- `compare_runs <left_run_id> <right_run_id>`
- app semantic relationship types: `reads`, `writes`, `transforms`, `emits`
- workbench and agent shared graph-slice model alignment

## Success Criteria

- `causal-query --agent` emits deterministic JSON.
- Existing text `causal-query` behavior remains compatible.
- Agent responses include events, relationships, policy state, warnings,
  limitations, and next-query hints.
- Responses are bounded by default and by explicit `--limit`.
- Deep runtime identity fields survive parsing and output.
- Tests cover legacy artifacts, deep runtime artifacts, failure queries, next
  queries, and invalid option handling.
