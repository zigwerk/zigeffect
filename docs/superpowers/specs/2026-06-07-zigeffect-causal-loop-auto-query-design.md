# zigeffect Causal Loop Auto-Query Design

## Summary

Extend the causal development loop so every `after` phase writes an automatic
query report:

```sh
zig build causal-dev-loop -- after
zig build causal-dev-loop -- after causal-scoped-fiber
```

The report should run the most useful `causal-query` helpers against the saved
after JSON artifact and write the results to a stable `*-queries.txt` artifact.

## Problem

The loop now captures before/after artifacts and writes a comparison report, but
it still prints static next-query suggestions. Agents must manually choose and
run follow-up queries before understanding the causal evidence.

This leaves the self-improving feedback loop half-automatic: it finds the
evidence but does not yet perform the next investigation step.

## Goals

- Add stable query report paths to loop artifacts.
- Generate query reports during the `after` phase.
- Reuse `causal_query.runQuery` instead of duplicating query execution.
- Select queries from actual after-artifact events and finding patterns.
- Include query report paths in loop summaries.
- Preserve existing CLI behavior and exit policy.

## Non-Goals

- Do not add an LLM, natural-language diagnosis, or patch recommendation.
- Do not run query reports during the `baseline` phase.
- Do not require changed findings to be nonzero; no-finding artifacts should
  produce a clear empty query report.
- Do not add CI upload or retention policy.

## Artifact Paths

Default dogfood loop:

- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt`

Scenario loop:

- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-queries.txt`

These paths sit beside the existing before, after, and compare artifacts.

## Query Selection

Parse the saved after JSON artifact and select queries from evidence events.

For any selected finding event:

- run `cause <event_id>`;
- run `lineage <event_id>`.

Additional context:

- `service_required` with `status = "missing"` runs
  `requirements <run_id>`.
- `resource_acquired` without a matching `resource_finalized` in the same scope
  and type runs `resources <scope_id>`.
- `fiber_forked` or `fiber_started` with `status = "pending"` or `status =
  "running"` runs `fibers <status>`.
- `schedule_decision` with `status = "exhausted"` runs `retries <run_id>`.
- `assertion_recorded` with `status = "failure"` runs `cause <event_id>` and
  `lineage <event_id>`.
- `resource_finalized` with `status = "failure"` runs `resources <scope_id>`.

The first slice may allow duplicate query classes if multiple findings have the
same shape, but it should avoid duplicate exact query commands in a single
report.

## Output Shape

The query report should start with:

```txt
zigeffect causal query report
queries: <n>
```

For each query:

```txt
query: causal-query -- --file <artifact> <query> [argument]
causal.query: <query> [argument]
events: <n>
...
```

When there are no selected queries:

```txt
zigeffect causal query report
queries: 0
- no follow-up queries selected
```

## Testing

Tests should cover:

- default and scenario query report paths;
- query report selection for the dogfood artifact shape;
- empty query report when no finding-shaped events exist;
- summary output includes the query report path.

## Acceptance Criteria

- `zig build causal-dev-loop -- after` writes a default query report.
- `zig build causal-dev-loop -- after missing-service-compile-fail` writes a
  scenario-specific query report.
- Query reports contain executed `causal.query` output, not only suggestions.
- `zig build examples`, `zig build test`, and `bun run zig:test` pass.

## Roadmap Position

This is the next Milestone 7 slice after scenario-aware loops. It closes the
gap where agents had to manually run query helpers after comparing causal
artifacts. The remaining Milestone 7 gap is app-facing development loops once
applications emit causal runtime artifacts.
