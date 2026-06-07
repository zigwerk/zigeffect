# zigeffect Causal Bounded Store Design

## Purpose

The causal runtime is becoming the development feedback system for
`zigeffect`. That means agents will run causal harnesses repeatedly while
editing the runtime. The in-memory `CausalStore` must have an explicit bounded
retention mode before it is safe to leave causal capture enabled in longer
development and CI loops.

This slice adds an opt-in bounded store policy while preserving the existing
unbounded default used by current deterministic tests and examples.

## Current Shape

`CausalStore` owns a `std.ArrayList(CausalEvent)`. Each call to `record` clones
the event strings, assigns a monotonic event id, appends to the list, and then
forwards the stored event to an optional backend.

This is simple and deterministic, but memory grows with every retained event.
The docs already require causal storage to be opt-in, bounded, explicit about
retention, and deterministic under tests.

## Design Decision

Add opt-in bounded retention:

```zig
var store = fx.CausalStore.initBounded(allocator, 256);
defer store.deinit();
```

The bounded store keeps at most `max_events` retained events. When a new event
would exceed the bound, the oldest retained event is dropped and deinitialized.
Event ids remain monotonic, so gaps in retained ids are visible evidence that
older events were discarded.

The existing `CausalStore.init(allocator)` remains unbounded.

## Retention Metadata

Bounded stores must not silently truncate evidence. The store exposes:

- `droppedEventCount()`: number of events removed by retention;
- `oldestRetainedEventId()`: first retained event id, or `null` when empty;
- `max_events`: visible through the store options and formatted artifacts.

Causal text reports, CI reports, and JSON artifacts should include retention
state so an agent knows whether a query result is complete or truncated.

The JSON artifact keeps schema version `zigeffect.causal.v1` and adds an
additive root object:

```json
{
  "schema": "zigeffect.causal.v1",
  "schema_version": 1,
  "retention": {
    "max_events": 0,
    "dropped_events": 4,
    "oldest_retained_event_id": null
  },
  "events": []
}
```

For unbounded stores, `max_events` is `null` and `dropped_events` is `0`.

## Backend Boundary

Retention applies only to the in-memory reference store. Attached backends still
receive every event after the event id is assigned. This keeps future streaming
or durable adapters independent from the in-memory retention window.

If `max_events` is `0`, the store retains no events but still forwards every
recorded event to the backend and increments the dropped count.

## Query Semantics

Queries operate on retained events only. If a parent event was dropped, a cause
query starts at the oldest retained ancestor it can find. Retention metadata is
the signal that a missing parent may be truncation rather than a runtime bug.

No synthetic "dropped" event is inserted in this slice. A synthetic event would
complicate event taxonomy and finding logic before production sampling rules
exist.

## Alternatives Considered

### Change `CausalStore.init` To Be Bounded By Default

This would improve safety immediately but risks changing existing examples,
tests, and teaching fixtures. The first hardening slice should be opt-in so the
policy can be tested before becoming the default for specific harnesses.

### Implement A Physical Ring Buffer Immediately

A ring buffer avoids shifting memory on every drop. The current event lists are
small and query logic expects retained events in chronological order. Using an
ordered drop-oldest list gives the correct public semantics now; the storage
mechanism can be optimized later without changing callers.

### Emit Synthetic Retention Events

Synthetic events would make truncation queryable, but they also alter event
counts and can create misleading parent chains. Root/report metadata is clearer
for this first slice.

## Testing Strategy

- Verify `init` remains unbounded.
- Verify `initBounded` keeps the newest events, preserves monotonic ids, and
  reports dropped events.
- Verify `max_events = 0` forwards to an attached backend while retaining no
  events.
- Verify JSON and CI/text reports disclose retention state.
- Run the existing dogfood and development loop commands to ensure bounded
  support does not perturb current unbounded artifacts.

## Acceptance Criteria

- Existing `CausalStore.init` behavior remains unchanged.
- `CausalStore.initBounded(allocator, n)` retains at most `n` events.
- Dropping old events deinitializes their owned strings.
- Event ids remain monotonic across drops.
- Attached backends receive all recorded events, even when retained memory drops
  older events.
- Reports and JSON artifacts include retention metadata.
- Package tests, examples, and causal development loop checks pass.
