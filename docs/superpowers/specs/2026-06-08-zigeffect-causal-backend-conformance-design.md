# zigeffect Causal Backend Conformance Design

Date: 2026-06-08

## Purpose

This is the first M4 durable-backend slice after M3 production hardening. The
goal is not to build a production JSONL, OpenTelemetry, graph, Cockroach, or
async backend yet. The goal is to make the backend adapter contract executable
so every future backend must prove it behaves like a safe sink behind the
deterministic `CausalStore`.

The immediate branch is:

```text
codex/zigeffect-causal-backend-conformance
```

## Current Baseline

The current backend boundary is small:

```zig
pub const CausalBackend = struct {
    kind: CausalBackendKind,
    state: ?*anyopaque = null,
    record: *const fn (?*anyopaque, causal.CausalEvent) anyerror!void,
};
```

`CausalStore.record` assigns event ids, applies sampling, clones/redacts/bounds
event strings, stores the event, calls the attached backend, then trims retained
events. Existing tests cover basic forwarding and prove retention can drop all
events while an attached backend still receives the events that passed
sampling.

The missing piece is a reusable conformance harness that adapter tests can call
before an adapter is considered compatible.

## Approaches Considered

### Approach A: Test Each Adapter Independently

Each adapter branch would write its own tests for ordering, sampling,
redaction, truncation, and failure behavior.

This is fast for the first adapter, but it guarantees drift. The JSONL backend
might test ordering, the OpenTelemetry backend might test failure swallowing,
and the durable history backend might forget sampling.

### Approach B: Add A Production Backend Trait

Replace the current callback shape with a richer interface that includes
flush, close, failure state, and query methods.

This may be useful later, but it is too early. The current boundary is
intentionally small and keeps the runtime core deterministic. Expanding it
before there are real adapters would freeze speculative API.

### Approach C: Add A Reusable Test-Support Contract

Keep the production `CausalBackend` callback shape, add a reusable test harness
under `test/support`, and add an explicit build step that runs the conformance
fixture.

This is the chosen approach. It hardens the contract without prematurely
expanding adapter APIs.

## Contract To Codify

The conformance harness should prove these facts:

- Backends receive only events that entered the deterministic store.
- Sampled-out observability events consume ids but are not sent to backends.
- Backends receive assigned event ids and parent/run metadata.
- Backends receive redacted and bounded strings, not raw event strings.
- Backend callbacks are invoked before retention trimming can erase an event
  from the in-memory store.
- The in-memory store remains authoritative: backend failures must not make
  `CausalStore.record` fail or lose the stored event.
- Backend write failures are counted so agents can distinguish "core trace
  complete" from "sink writes incomplete."

## Runtime Metadata

Add bounded, additive backend failure metadata to `CausalStore`:

```zig
backend_failure_count: u64 = 0,

pub fn backendFailureCount(self: *const CausalStore) u64
```

When `backend.record` returns an error, `CausalStore` increments
`backend_failure_count` and continues. This preserves the existing failure
swallowing behavior while making the failure observable.

Add one-line report metadata:

```text
backend: kind=none failed_writes=0
backend: kind=memory failed_writes=2
```

Add JSON root metadata:

```json
{
  "backend": {
    "kind": null,
    "failed_writes": 0
  }
}
```

The JSON field is additive under `zigeffect.causal.v1`; older tools ignore it.

## Test Harness Shape

Add:

```text
packages/zigeffect/test/support/causal_backend_conformance.zig
packages/zigeffect/test/causal_backend_conformance_test.zig
```

The support module owns reusable fixtures:

- `standardStoreOptions()`: returns a store configuration with event retention,
  deterministic sampling, and string truncation enabled.
- `recordStandardTrace(store)`: records a trace with structural events, a
  sampled-out log event, a retained log event, and a completed event.
- `expectStandardStorePosture(store, ids)`: asserts sampling, retention,
  truncation, and retained-event state.
- `CaptureBackendState`: a test backend that copies every received stored event
  so future adapter tests have a reference sink.
- `FailingBackendState`: a test backend that always fails writes so failure
  policy can be tested.

The standalone test module uses the harness to assert the reference contract.
Future adapter tests can reuse the same `standardStoreOptions`,
`recordStandardTrace`, and `expectStandardStorePosture` helpers, then add
adapter-specific assertions over JSONL rows, spans, graph records, or database
rows.

## Build Integration

Add a direct build step:

```bash
zig build causal-backend-conformance
```

The normal `zig build test --summary none` path should also depend on the
conformance test so CI catches regressions automatically.

## Documentation Updates

Update:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/agent-guide.md`
- `packages/zigeffect/docs/agent-observable-runtime.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

Docs should explain:

- adapters are sinks, never the source of truth;
- future adapter branches must run `zig build causal-backend-conformance`;
- `backend.failed_writes` means the deterministic store can still be used, but
  backend durability/export evidence may be incomplete;
- M4 moves from planned to in progress once this conformance suite lands.

## Out Of Scope

- Implementing JSONL, DOT, OpenTelemetry, graph, Cockroach, or async adapters.
- Adding flush or close lifecycle methods.
- Retrying backend writes.
- Persisting backend failure details beyond a count.
- Turning backend callbacks into queryable stores.
- Changing event schema version numbers.
