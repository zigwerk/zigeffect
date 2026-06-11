# zigeffect Causal Agent Query Compare Runs Design

Date: 2026-06-11
Branch: `codex/zigeffect-causal-agent-query-compare-runs`
Status: Approved for implementation

## Summary

This branch completes the missing cross-run query in the agent-facing causal
runtime surface. It adds bounded `compare_runs` support to
`causal-query --agent` so agents can compare two retained run slices without
parsing human text, reading unbounded artifacts, or gaining mutation authority.

The feature consumes the durable NenDB history hardening milestone: causal
artifacts can now represent retained, redacted, bounded runtime evidence well
enough for an agent to ask whether a run improved, regressed, or changed shape
between two observations.

This is intentionally not a new compare command. The command already has a
schema-stable agent envelope, query names, bounded slices, policy metadata,
warnings, limitations, relationships, and next-query hints. `compare_runs`
belongs inside that envelope as an additive extension of
`zigeffect.causal.agent-query.v1`.

## Goals

- Add `compare_runs(left_run_id, right_run_id)` to `causal-query --agent`.
- Support comparing two run ids in one artifact or across two artifact files.
- Keep the response bounded by the existing `--limit` cap.
- Report run-level event counts, failure counts, status counts, event-kind
  counts, finding evidence counts, and selected evidence ids.
- Include compact delta fields that help agents answer:
  - did the run gain or lose failures;
  - did event volume change materially;
  - which event kinds appeared or disappeared;
  - which status classes appeared or disappeared;
  - which evidence ids should be queried next.
- Preserve schema compatibility with `zigeffect.causal.agent-query.v1`.
- Update docs and governance so `compare_runs` is no longer marked future work.
- Hand off to the next production-hardening milestone after cross-run
  comparison exists.

## Non-Goals

- No new schema version unless the additive shape cannot fit v1.
- No durable writes, registry updates, source edits, remediation, CI mutation,
  workbench UI mutation, or app mutation.
- No Cockroach adapter work.
- No non-NenDB durable backend work.
- No live telemetry ingestion, network calls, or production trace collection.
- No arbitrary snapshot manifest comparison. Snapshot/audit-chain comparison
  remains a later milestone.
- No fuzzy semantic diff engine. This branch compares bounded observed event
  fields, not inferred intent.

## Current Context

`packages/zigeffect/tools/causal_query.zig` already exposes:

- text queries for `snapshot`, `cause`, `lineage`, `resources`, `fibers`,
  `requirements`, `retries`, `workflow`, and `workflow-findings`;
- agent JSON mode with schema `zigeffect.causal.agent-query.v1`;
- bounded result limits through `--limit`, default `32`, max `256`;
- policy metadata for retention, sampling, and truncation;
- compatibility warnings for future schemas, future taxonomies, unsupported
  schema families, and unknown event kinds;
- selected events and derived relationships;
- `next_queries` hints.

The docs currently list `compare_runs(left_run_id, right_run_id)` but explicitly
mark it future because it needs cross-artifact comparison semantics. This branch
implements those semantics in the smallest useful form.

`packages/zigeffect/tools/causal_compare.zig` already compares two whole
artifacts for human text. It is useful precedent, but not the right API surface
for agents because it is artifact-wide, unbounded, and text-oriented.

## CLI Design

Keep existing single-file usage working:

```sh
zig build causal-query -- --agent --file <artifact.json> summarize_run 1
```

Add an optional second artifact path:

```sh
zig build causal-query -- --agent \
  --file <before.json> \
  --compare-file <after.json> \
  compare_runs 1:2
```

The argument format is `left_run_id:right_run_id`. This avoids changing the
existing query parser into a positional command parser and keeps usage compact.

If `--compare-file` is omitted, both run ids are selected from `--file`:

```sh
zig build causal-query -- --agent --file <artifact.json> compare_runs 1:2
```

The feature is agent-mode first. Text mode may print a compact human report for
debugging, but the required surface is the JSON envelope.

## Query Semantics

`compare_runs` parses:

- `left_run_id`;
- `right_run_id`;
- left artifact from `--file`;
- right artifact from `--compare-file` when provided, otherwise the left
  artifact.

For each side it selects events where `event.run_id` equals the requested run
id. It never selects every artifact event unless every artifact event belongs to
the run.

The selected event arrays in the root `events` field remain bounded. The first
half of the limit is reserved for left evidence and the second half for right
evidence. If the limit is odd, the right side gets the extra item because it is
usually the candidate or after run.

The comparison summary should still count all matched run events before
truncation. Bounded output affects returned evidence, not the comparison
counters.

## Agent JSON Extension

The root envelope remains:

- `schema = "zigeffect.causal.agent-query.v1"`;
- `schema_version = 1`;
- `query = "compare_runs"`;
- `arguments = ["<left_run_id>:<right_run_id>"]`;
- `bounded = true`;
- `truncated`;
- `limit`;
- `total_matched_events`;
- `returned_events`;
- `confidence`;
- `policy`;
- `warnings`;
- `limitations`;
- `events`;
- `relationships`;
- `next_queries`.

Add a query-specific object:

```json
{
  "comparison": {
    "left": {
      "artifact_label": "left",
      "run_id": 1,
      "matched_events": 7,
      "returned_events": 3,
      "failure_events": 3,
      "finding_events": 3
    },
    "right": {
      "artifact_label": "right",
      "run_id": 2,
      "matched_events": 9,
      "returned_events": 4,
      "failure_events": 1,
      "finding_events": 1
    },
    "deltas": {
      "event_delta": 2,
      "failure_delta": -2,
      "finding_delta": -2
    },
    "left_only_kinds": ["resource_finalized"],
    "right_only_kinds": ["exit_recorded"],
    "left_only_statuses": ["missing"],
    "right_only_statuses": ["success"],
    "selected_left_event_ids": [1, 3, 5],
    "selected_right_event_ids": [10, 11, 12, 13]
  }
}
```

The exact field order should be deterministic. Arrays should preserve first
observed order in the compared run slice.

## Warnings, Limitations, And Confidence

The response must keep compatibility warnings from both artifacts. Warning text
should label the source artifact as `left` or `right`.

Limitations should include:

- `result limited by query limit` when either side is truncated;
- missing retention/sampling/truncation metadata for either side;
- `compare-file not provided; both runs selected from same artifact` when the
  right artifact is implicit;
- `left run has no retained events` or `right run has no retained events` when
  a requested run id is absent.

Confidence should be `partial` when either side is truncated, any artifact has
dropped/sampled/truncated metadata, or either run has no retained events.
Otherwise it can remain `complete`.

## Next Queries

`next_queries` should guide an agent to inspect both sides:

```sh
zig build causal-query -- --agent --file <left-artifact.json> summarize_run <left_run_id>
zig build causal-query -- --agent --file <right-artifact.json> summarize_run <right_run_id>
zig build causal-query -- --agent --file <left-artifact.json> find_failures <left_run_id>
zig build causal-query -- --agent --file <right-artifact.json> find_failures <right_run_id>
```

If selected evidence exists, the usual `explain_event` and `trace_cause` hints
remain useful. For cross-file comparison, command hints must name the left/right
artifact placeholder so agents do not accidentally query both events against the
same file.

## Use Cases

### Self-Improving zigeffect Development Agent

When a zigeffect change modifies runtime behavior, the agent can compare a
baseline run to a candidate run and ask whether failure evidence disappeared,
new failure kinds appeared, or runtime shape changed. This is the direct path
toward the self-improving development harness.

### Causal CI Failure Triage

When a test fails and emits causal artifacts, the agent can compare the failing
run to the last known good retained run. It can then focus on the new finding
kinds and the first changed event ids instead of scanning a whole artifact.

### Regression Clustering

Repeated failing runs can be compared pairwise or against a selected baseline.
The deltas expose stable signatures: missing service requirements, resource
finalizer failures, retry exhaustion, interrupted fibers, or app data-lineage
differences.

### App-Facing Runtime Understanding

As applications emit semantic app events, agents can compare a previous request
or workflow run to a current one and surface changes in data reads, writes,
transforms, emitted artifacts, or response status.

### Workbench Drilldown

The SolidJS `zig-webui` workbench can consume the same JSON object later. The UI
can display left/right run summaries, kind/status deltas, and selected evidence
without inventing a separate browser-only model.

## Test Strategy

Add red tests first in `packages/zigeffect/tools/causal_query.zig`:

- `agent compare_runs compares two runs from one artifact`;
- `agent compare_runs compares two files with bounded evidence`;
- `agent compare_runs reports missing run evidence`;
- `agent compare_runs rejects malformed pair arguments`;
- `agent compare_runs preserves future-schema and unknown-kind warnings for both
  artifacts`;
- `agent compare_runs next queries distinguish left and right artifact
  placeholders`.

Then implement parser, selection, comparison summary, formatter, docs, and
governance updates until the tests pass.

## Documentation Updates

Update:

- `packages/zigeffect/docs/agent-observable-runtime.md`;
- `packages/zigeffect/docs/schema-governance.md`;
- `packages/zigeffect/docs/agent-guide.md` if it references the query surface;
- `packages/zigeffect/docs/production-hardening-backlog.md`;
- `packages/zigeffect/docs/roadmap.md`;
- `packages/zigeffect/README.md`;
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`.

The documentation should say `compare_runs` is delivered as a bounded
agent-query extension, not a production mutation mechanism.

## Open Decisions

- Keep `agent-query.v1` if the implementation is additive and older consumers
  can ignore `comparison`.
- Use `--compare-file`, not `--right-file`, because it describes the command
  role and avoids implying a persistent left/right data model.
- Use `left_run_id:right_run_id` because the current parser treats everything
  after the query name as query args and this avoids broader CLI churn.

## Success Criteria

- `causal-query --agent compare_runs` returns valid bounded JSON.
- Same-artifact and cross-artifact comparisons both work.
- Missing runs produce explicit partial evidence, not crashes.
- Compatibility warnings are preserved for both artifacts.
- Docs no longer mark `compare_runs` as future work.
- Schema governance still validates.
- The production hardening backlog hands off to the next milestone.
- The branch verifies with focused Zig tests, schema governance, zigeffect build
  tests, and root Bun checks.
