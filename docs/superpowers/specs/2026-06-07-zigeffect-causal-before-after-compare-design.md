# zigeffect Causal Before/After Compare Design

## Summary

Add a local causal artifact comparison tool for `zigeffect` development. The
tool compares two saved causal JSON artifacts and produces an agent-readable
before/after report with event count deltas, finding count deltas, added
events, removed events, and changed events.

This gives development agents a concrete way to justify claims like "this patch
reduced causal findings" or "this fix removed the missing-service event" using
artifact evidence instead of intuition.

## Problem

The current self-improving harness can:

- emit causal artifacts;
- query individual artifacts;
- run registered scenarios;
- list scenario invariants.

It cannot compare two artifacts. That means an agent can inspect before and
after states, but cannot produce a stable report that explains what changed.

## Goals

- Add `zig build causal-compare -- <before.json> <after.json>`.
- Compare event counts, finding counts, added events, removed events, and
  changed events.
- Recompute finding counts from JSON events so any saved artifact can be
  compared without rerunning the original scenario.
- Keep output stable and concise enough for CI artifacts.
- Document how agents use comparison after a fix.

## Non-Goals

- Do not automate before/after capture around a patch yet.
- Do not write comparison artifacts to disk yet.
- Do not compare DOT graphs or text reports.
- Do not require schema metadata beyond the existing JSON event shape.

## Tool Shape

Create:

```txt
packages/zigeffect/tools/causal_compare.zig
```

Add build step:

```sh
zig build causal-compare -- <before.json> <after.json>
```

The command reads both JSON artifacts, computes a comparison report, prints it
to stdout, and exits zero when both files parse.

## Comparison Rules

Events are matched by `id`.

An event is:

- added if its id exists only in the after artifact;
- removed if its id exists only in the before artifact;
- changed if the id exists in both artifacts but any event field differs.

Finding counts are recomputed from JSON events using the same rules as
`CausalStore.findings`:

- `resource_acquired` without a matching `resource_finalized`;
- pending/running fiber when the owning scope closes;
- failed `resource_finalized`;
- exhausted `schedule_decision`;
- missing `service_required`;
- failed `assertion_recorded`.

## Output Shape

The report should start with:

```txt
zigeffect causal compare report
before events: <n>
after events: <n>
event delta: <signed>
before findings: <n>
after findings: <n>
finding delta: <signed>
```

Then sections:

```txt
added events:
removed events:
changed events:
```

Each event line should cite id, kind, run, scope, fiber, label, type, and status
when present.

Changed events should include the before and after summaries for the same id.

## Testing

Tests should cover:

- finding count recomputation from JSON;
- added events;
- removed events;
- changed events;
- finding delta;
- missing argument usage behavior through pure compare argument validation or
  focused CLI behavior.

## Acceptance Criteria

- `cd packages/zigeffect && zig build causal-compare -- <before> <after>` works
  for two valid causal JSON files.
- The report includes event and finding deltas.
- The report includes added, removed, and changed event sections.
- `zig build causal-test` followed by comparing a sample before/after fixture
  works in local development.
- `zig build examples`, `zig build test`, and `bun run zig:test` pass.

## Roadmap Position

This implements the first concrete slice of Milestone 6. The next milestone
should automate before/after capture around scenario runs and package tests, but
that loop should reuse this comparison engine rather than invent a separate
diff format.
