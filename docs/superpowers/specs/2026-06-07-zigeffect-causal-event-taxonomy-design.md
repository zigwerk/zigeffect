# zigeffect Causal Event Taxonomy Design

Date: 2026-06-07

## Problem

The causal runtime now has retention, redaction, schema versioning, and
observability sampling. Sampling introduced an important compatibility rule:
only high-volume observability events may be sampled. Runtime structure and
finding evidence must remain retained unless bounded retention trims them.

Today that rule is implicit in switches inside `CausalStore`. Future event-kind
additions could accidentally become sampleable, disappear from artifacts, or be
misread by development agents. The runtime needs a small public taxonomy layer
that states how each event kind participates in causal evidence.

## Goals

- Make event-kind roles explicit and testable.
- Distinguish sampleable observability from structural runtime evidence.
- Distinguish finding evidence from pure observability.
- Keep sampling wired through the taxonomy helper instead of an ad hoc kind
  switch.
- Add a taxonomy version marker so artifacts can identify the event-kind
  semantics they were emitted under.
- Keep the JSON artifact shape backward compatible through additive root
  metadata.

## Non-Goals

- Do not redesign the `CausalEventKind` enum.
- Do not add new event kinds in this slice.
- Do not change existing finding derivation behavior.
- Do not require local JSON query, compare, or loop tools to understand the new
  metadata before they can parse artifacts.
- Do not make sampling adaptive or probabilistic.

## Taxonomy API

Add a compact role struct:

```zig
pub const CausalEventTaxonomy = struct {
    structural: bool,
    finding_evidence: bool,
    sampleable: bool,
};
```

Add public helpers:

```zig
pub fn causalEventTaxonomy(kind: CausalEventKind) CausalEventTaxonomy;
pub fn isCausalStructuralEvent(kind: CausalEventKind) bool;
pub fn isCausalFindingEvidenceEvent(kind: CausalEventKind) bool;
pub fn isCausalSampleableEvent(kind: CausalEventKind) bool;
```

The helpers are intentionally value-level functions rather than build-time
tables. This keeps the current code style and makes every event-kind decision
obvious in one switch.

## Role Rules

Sampleable events:

- `log_recorded`
- `metric_recorded`
- `span_recorded`

Finding evidence events:

- `service_required`
- `scope_closed`
- `resource_acquired`
- `resource_finalized`
- `fiber_forked`
- `fiber_started`
- `fiber_joined`
- `fiber_interrupted`
- `schedule_decision`
- `assertion_recorded`

Structural events are all non-sampleable events. This includes finding evidence
and ordinary runtime lifecycle events such as runs, effects, layers, services,
scopes, exits, fibers, resources, and schedules.

The central invariant is:

- `sampleable` and `finding_evidence` must be disjoint.

This ensures sampling cannot remove event kinds that findings need.

## Artifact Contract

Add a taxonomy version constant:

```zig
pub const causal_event_taxonomy_version: u32 = 1;
```

JSON artifacts include it at the root:

```json
{
  "schema": "zigeffect.causal.v1",
  "schema_version": 1,
  "event_taxonomy_version": 1,
  "retention": {},
  "sampling": {},
  "events": []
}
```

`schema_version` remains the artifact shape version. `event_taxonomy_version`
identifies the semantics assigned to event kinds. This lets future agents or
tools warn when they see an artifact from an unknown taxonomy version even if
the JSON shape is still parseable.

## Sampling Integration

`CausalStore.record` should continue to sample only logs, metrics, and spans,
but `shouldRecordBySampling` should check `isCausalSampleableEvent(kind)` before
kind-specific counters. Unknown future kinds are structural by default because
the taxonomy switch must be updated at the same time the enum changes.

## Documentation

Update the agent runtime docs and guide to describe:

- the taxonomy version;
- structural versus sampleable events;
- finding evidence events;
- the invariant that finding evidence is never sampled.

## Acceptance Criteria

- Public taxonomy helpers are exported through `zigeffect.zig`.
- Tests cover sampleable, structural, and finding-evidence roles.
- Tests prove sampleable and finding-evidence roles are disjoint for every
  current event kind.
- Tests prove sampling still does not remove finding evidence.
- JSON artifacts emit `"event_taxonomy_version": 1`.
- Existing JSON readers keep accepting artifacts because they already ignore
  unknown root fields.
- Full zigeffect verification continues to pass.

## Future Directions

- Add role-aware artifact summaries such as event counts by role.
- Add string-level taxonomy helpers for JSON tools that operate without a typed
  `CausalEventKind`.
- Add compatibility warnings to query/compare tools when a future taxonomy
  version is newer than the tool understands.
- Add event-kind review checklist items to the roadmap before introducing new
  runtime events.
