# ZigEffect compositional developer experience and causal hot path

Date: 2026-07-15
Status: accepted for implementation

## Problem

The canonical kernel has the right service, layer, managed-runtime, and
application-inspection foundations, but application code cannot yet be written
as a fluent effect program. `Effect` supports one `map`; it has no typed
`flatMap`, recovery, observation, sequencing, zipping, or semantic naming.
Real examples therefore call `runIn` from inside another effect and leak the
interpreter into application code. The project generator also still emits the
legacy `EffectEnv` / `LayerGraph` model, so a new user is taught the architecture
we are replacing.

The causal store compounds this with ten separately owned strings per retained
event. A normal runtime event therefore performs and retains several small heap
allocations even when most fields are empty. This is unnecessary pressure on
the instrumentation hot path.

## Design

### One compositional effect protocol

Every canonical effect value exposes the same fluent operations:

- `map` for pure success transformation;
- `flatMap` for effectful sequencing with inferred success, error, and service
  requirements;
- `tap` for effectful observation while preserving the original success;
- `andThen` for sequencing when the first result is not needed;
- `catchAll` for typed recovery with the same success type;
- `mapError` for typed failure translation;
- `zip` for sequentially combining independent effect descriptions;
- `named` for a stable semantic causal boundary.

Combinators remain lazy descriptions. They do not receive a runtime or access a
registry until interpreted by `ManagedRuntime` or `RuntimeHandle`. Required
service tuples are combined at compile time, and failure sets are combined with
Zig error-set union. Application code must not call `runIn`.

`named` is the explicit semantic graph boundary. It emits one parent start /
completion pair and nests the underlying primitive effect events beneath it.
Pure structural combinators do not emit additional events, avoiding a graph
full of implementation-only nodes and keeping instrumentation cost proportional
to executed operations rather than syntax.

### Generated application contract

The starter template is the executable documentation for the framework. It
must use only canonical public APIs:

1. define service interfaces and tags;
2. implement them with layers;
3. compose a program with fluent effects;
4. build one `ManagedRuntime` from the root layer;
5. run programs through the runtime and dispose it once;
6. expose application/causal inspection without a separately wired causal
   service.

No generated canonical starter may mention `EffectEnv`, `LayerGraph`,
`LayerWithError`, `ValueProvider`, `ctx.runEffect`, or a hand-provided
`CausalStore` service.

### Causal event storage

Each owned `CausalEvent` stores all non-empty text fields in one backing
allocation. Field slices point into that allocation. Redaction and truncation
remain mandatory before retention, and snapshot/inspection clones use the same
packed representation. This changes allocation shape, not the public event
schema or evidence semantics.

Live callers use `inspect`, which captures one locked, internally consistent
view. Historical query methods retain their documented quiescent-barrier
contract in this slice; broad lock retrofitting is deferred because recursive
query helpers must first be split into locked and unlocked forms.

## Performance and safety constraints

- Empty event text performs no text-buffer allocation.
- A retained or cloned event with any text performs one persistent text-buffer
  allocation, rather than up to ten.
- Redaction, truncation counters, retention, sampling, backend delivery, and
  deinitialization behavior remain unchanged.
- Combinators add no allocation by themselves.
- Service requirements missing from a runtime continue to fail at compile time.
- Managed runtime layer construction and memoization remain once per runtime,
  never once per effect run.

## Acceptance

- A multi-service program composes with `flatMap`, `tap`, `zip`, recovery, and
  semantic naming without any `runIn` in application code.
- Its inferred `RequiredServices` is the union of all composed operations and
  its inferred `FailureType` contains every unrecovered typed failure.
- Causal inspection contains the stable program name and the primitive service
  operations below it.
- The generated starter contains a canonical service/layer/runtime program and
  none of the prohibited legacy architecture tokens.
- A deterministic allocator test proves one persistent text allocation per
  owned event (plus the event-array allocation), and all existing causal
  redaction/retention tests pass.
- ZigEffect, ZigEffect standard-library, CLI template, examples, downstream
  transport, Testing v2, hygiene, and changed-file gates pass with complete
  receipts.

## Deliberate non-goals

- Parallel execution semantics for `zip` (this slice is deterministic and
  sequential).
- Generator migration for production integrations whose canonical adapters are
  not yet public.
- A new causal reporting tool. The capability belongs in runtime `src/` and
  existing application inspection.
- Compatibility shims for the legacy environment-generic application model.
