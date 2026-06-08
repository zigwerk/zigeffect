# zigeffect Causal Artifact Size Limits Design

Date: 2026-06-08

## Purpose

This is the final M3 production-hardening slice before durable backend work.
The goal is to make causal artifacts bounded not only by retained event count
and sampling policy, but also by event string payload size.

The runtime already discloses:

- retained event limits through `retention`;
- sampled observability drops through `sampling`;
- schema and taxonomy compatibility through root metadata and tool warnings;
- redaction posture through store-time sanitization.

This branch adds explicit truncation metadata so agents can tell when labels,
type names, statuses, or details were shortened before export or backend
emission.

## Current Baseline

`CausalStore` currently owns all causal event storage. On `record`, it:

1. applies deterministic sampling for sampleable observability events;
2. clones and redacts event strings before storage;
3. forwards the stored event to an attached backend;
4. trims retained events by `max_events`.

Generated causal JSON has stable root metadata:

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

Text and CI reports include one-line retention and sampling summaries. DOT
exports use the stored event labels directly.

## Approaches Considered

### Approach A: Truncate Formatted Artifacts

Format JSON, text, or DOT normally, then cut the final byte stream to a target
size.

This creates a hard final file cap, but it can produce invalid JSON, broken DOT,
and missing metadata precisely when agents need the metadata most. It also lets
large payloads reach attached backends before truncation.

### Approach B: Drop Events Until The Formatted Artifact Fits

Estimate or format artifacts repeatedly, dropping older retained events until a
configured byte budget is met.

This keeps output valid, but it duplicates retention semantics and makes event
count retention harder for agents to reason about. It also changes which
events are retained based on formatter choice and escaping overhead.

### Approach C: Bound Stored Event String Fields

Redact event strings, then apply an optional byte cap to each stored event
string field. Record how many fields were truncated and disclose the cap in all
agent-facing reports.

This is the chosen approach. Combined with existing `max_events` and sampling,
it gives deterministic bounded artifact growth while keeping JSON and DOT
syntactically valid. It also ensures attached backends receive the same bounded
strings that artifacts expose.

## Design Decision

Add opt-in store-time string truncation:

```zig
pub const CausalStoreOptions = struct {
    max_events: ?usize = null,
    sampling: CausalSamplingPolicy = .{},
    max_event_string_bytes: ?usize = null,
};
```

Default behavior remains unchanged: `max_event_string_bytes = null` means no
string truncation.

When enabled, the store applies the cap to every causal event string field after
redaction and before storage:

- `label`
- `type_name`
- `status`
- `redacted_detail`

The stored string length is always less than or equal to the configured byte
cap. If the marker fits, truncated strings end with:

```text
<truncated>
```

If the cap is smaller than the marker, the marker itself is shortened to fit.
If the cap is zero, any non-empty truncated field becomes an empty string. The
metadata still records that truncation occurred.

## Redaction And Truncation Order

The ordering is non-negotiable:

```text
raw event string -> redaction -> truncation -> store -> backend/artifact
```

This preserves the redaction safety property. A secret must never survive just
because a truncation boundary cut around a key/value shape. Tests should prove
that raw secret values are absent from snapshots, reports, JSON artifacts, and
attached backends when truncation is enabled.

## Metadata

Add runtime state to `CausalStore`:

```zig
max_event_string_bytes: ?usize = null,
truncated_field_count: u64 = 0,
```

Add an accessor:

```zig
pub fn truncatedFieldCount(self: *const CausalStore) u64
```

Generated JSON adds an additive root object:

```json
{
  "truncation": {
    "max_event_string_bytes": null,
    "truncated_fields": 0
  }
}
```

Text and CI reports add:

```text
truncation: max_event_string_bytes=off truncated_fields=0
```

or:

```text
truncation: max_event_string_bytes=64 truncated_fields=3
```

This is an additive field in `zigeffect.causal.v1`, so the causal schema version
does not change. Older tools ignore the extra root key; updated docs tell
agents how to cite it.

## Query And Compatibility Behavior

Saved-artifact query, compare, advice, and dev-loop tools should keep parsing
artifacts permissively. They do not need a new warning class in this branch
because truncation is not a compatibility problem; it is declared evidence
incompleteness.

Agents should treat `truncated_fields > 0` similarly to `dropped_events > 0` or
`sampled_events > 0`:

- event ids remain valid;
- findings remain usable;
- payload text may be incomplete;
- summaries should cite the truncation metadata before making claims that rely
  on event string detail.

## Backend Behavior

Attached causal backends receive already-redacted and already-truncated event
strings. Backend adapters should not re-expand, re-fetch, or infer omitted
payloads. Durable backend-specific rotation and file-size policies remain M4
work.

## Testing Strategy

Use TDD in `packages/zigeffect/test/services_test.zig`.

Add tests that prove:

- default stores do not truncate event strings and report truncation as off;
- opt-in stores truncate long event string fields before snapshots, reports,
  JSON, DOT labels, and backend emission;
- the final stored string length is less than or equal to the configured cap;
- truncation metadata is emitted in JSON, text, and CI reports;
- redaction happens before truncation, so raw secrets are absent even when a
  long field is capped.

## Documentation Updates

Update:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/agent-guide.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

Docs should explain that bounded artifact growth requires choosing both:

- `max_events` for retained event count;
- `max_event_string_bytes` for per-event string payloads.

## Out Of Scope

- Post-format byte slicing of JSON, text, or DOT artifacts.
- A global exact artifact file-size budget.
- Durable backend rotation.
- Compression.
- Changing schema version from `1`.
- Changing default runtime behavior.
- Adding free-text PII classification beyond the existing redaction policy.
