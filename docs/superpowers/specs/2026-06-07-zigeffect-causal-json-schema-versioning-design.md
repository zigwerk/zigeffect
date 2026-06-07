# zigeffect Causal JSON Schema Versioning Design

## Purpose

`zigeffect` causal JSON artifacts are now used by the dogfood harness, query
helper, compare helper, development loop, and agent-facing docs. The artifact
needs a stable, explicit schema marker before more agents and CI systems depend
on it.

This slice adds a small root-level schema/version header to generated causal
JSON while preserving compatibility with legacy artifacts that only contain
`events`.

## Current Shape

`formatCausalJson` currently emits:

```json
{
  "events": []
}
```

Local consumers parse this with `std.json.parseFromSlice` into an `Artifact`
struct containing `events`. The consumers use `ignore_unknown_fields = true`,
so additive root fields are the lowest-risk way to evolve the format.

## Design Decision

Use an additive root contract:

```json
{
  "schema": "zigeffect.causal.v1",
  "schema_version": 1,
  "retention": {
    "max_events": null,
    "dropped_events": 0,
    "oldest_retained_event_id": null
  },
  "events": []
}
```

`schema` is a stable human-readable artifact family. `schema_version` is a
machine-readable integer for future compatibility checks. Version `1` covers
the current root object, retention metadata, and event field names.

## Alternatives Considered

### Add a nested metadata object

Example: `"metadata": { "schema": "...", "version": 1 }`.

This is tidy, but it adds an extra level without immediate value. The current
tools only need to know the artifact family and version.

### Require version fields in every parser

This would make mismatches fail early, but it would break existing saved
artifacts and tests. The first schema hardening slice should identify generated
artifacts without invalidating older evidence.

### Publish a full external JSON Schema now

Useful later for CI upload validation, but premature for this slice. The event
taxonomy and bounded-store policy are still evolving.

## Compatibility

- New generated artifacts include `schema` and `schema_version`.
- New generated artifacts include root retention metadata.
- Existing artifacts without those fields remain parseable by query, compare,
  and loop tools.
- Existing root-level unknown fields remain ignored by local tools.
- The event array shape is unchanged.

## Testing Strategy

- Add a service test expectation that `formatCausalJson` emits both schema
  fields before `events`.
- Add parser compatibility coverage for a generated-style versioned artifact
  and a legacy artifact without schema metadata.
- Keep query and compare behavior unchanged.

## Scope

In scope:

- `formatCausalJson` root metadata.
- exported constants for the current schema name and version.
- local parser structs accepting optional metadata.
- docs updates naming the artifact contract.

Out of scope:

- full JSON Schema files;
- strict rejection of unknown future versions;
- bounded memory policy;
- event sampling;
- artifact upload/retention.

## Acceptance Criteria

- `formatCausalJson` emits `"schema": "zigeffect.causal.v1"`.
- `formatCausalJson` emits `"schema_version": 1`.
- `causal-query`, `causal-compare`, and `causal-dev-loop` can still parse
  legacy artifacts.
- package tests, examples, and causal development loop checks pass.
