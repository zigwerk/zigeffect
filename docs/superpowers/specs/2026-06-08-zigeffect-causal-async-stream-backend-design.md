# Zigeffect Causal Async Stream Backend Design

## Context

`zigeffect` already has causal backend adapters for JSON Lines export, DOT graph
rendering, OpenTelemetry-shaped records, local graph-history queries, and a
NenDB-shaped storage writer contract. The next backend adapter should cover a
different runtime need: event streams that an agent, local tool, or app runtime
can drain incrementally while execution is still happening.

This branch is NenDB-only for durable graph storage. It does not add CockroachDB,
Cockroach history, Hyperdrive, or any database dependency. The async stream
backend is an in-process stream boundary that can later feed a NenDB writer,
watch UI, CI process, or app-local agent loop.

## Goals

- Add a concrete `CausalAsyncStreamBackendState` for
  `CausalBackendKind.async_stream`.
- Keep the adapter dependency-free and runtime-neutral.
- Accept only stored causal events from `CausalStore`, after event ids,
  redaction, truncation, sampling, and retention posture are applied.
- Retain a bounded in-memory queue of cloned events for incremental agent
  consumers.
- Optionally forward every accepted event to a caller-provided sink callback.
- Fail closed on bounded queue capacity and sink rejection.
- Preserve the deterministic in-memory `CausalStore` behavior when the backend
  fails.
- Provide focused tests and a focused build step:
  `zig build causal-async-stream-backend`.

## Non-Goals

- No language-level Zig async scheduling.
- No thread, mutex, channel, event loop, socket, filesystem, or database work.
- No direct NenDB package integration in this branch.
- No durable history semantics; graph history and NenDB storage own that lane.
- No implicit background draining. Callers drain explicitly.

## Design Options Considered

### Option A: Callback-Only Sink

The backend would simply call a sink callback and store no events.

This is small, but too weak for agent workflows. A dev agent needs to inspect
the stream after a command completes, and callback-only output makes tests and
local tooling depend on an injected fake sink for every use.

### Option B: Bounded In-Memory Queue With Optional Sink

The backend stores cloned events in an adapter-owned queue and can also call an
optional sink for every accepted event. Consumers can `peekSnapshot()` without
mutating the queue or `drain()` to take owned events.

This is the recommended option. It is dependency-free, deterministic, easy to
test, and immediately useful for local dev agents. It also leaves room for
future adapters to bridge the drained stream into NenDB, a UI, or a process
pipe without changing `CausalStore`.

### Option C: Real Async Runtime Adapter

The backend would introduce a scheduler/channel abstraction and send events to
an async task.

This is premature. It would entangle causal storage with runtime scheduling
before zigeffect's agent harness needs it. It also raises thread-safety and
lifetime concerns that are outside the current backend contract.

## Selected Architecture

Implement Option B.

`CausalAsyncStreamBackendState` owns:

- an allocator
- an optional `CausalAsyncStreamSink`
- a bounded queue of cloned `CausalEvent` values
- counters for accepted, drained, failed, dropped, and flushed events
- queue capacity configured with `CausalAsyncStreamBackendOptions.max_events`

The backend record path:

1. Receives a stored event from `CausalStore`.
2. Checks queue capacity before cloning or invoking the sink.
3. Reserves one queue slot.
4. Clones the event and all owned string fields.
5. Calls the optional sink with the cloned event.
6. Appends the cloned event to the queue only after the sink succeeds.
7. Increments `accepted_event_count`.

If capacity is full, cloning fails, or the sink rejects the event, the backend
increments failure counters and returns an error. `CausalStore` catches that
error and increments its backend failure count without dropping the stored event
from the core in-memory trace.

## Public API

The branch should export these symbols at `fx.*`:

- `CausalAsyncStreamSink`
- `CausalAsyncStreamBackendOptions`
- `CausalAsyncStreamBackendError`
- `CausalAsyncStreamBackendState`

`CausalAsyncStreamSink`:

```zig
pub const CausalAsyncStreamSink = struct {
    state: ?*anyopaque = null,
    on_event: *const fn (?*anyopaque, causal.CausalEvent) anyerror!void,
    flush: ?*const fn (?*anyopaque) anyerror!void = null,
};
```

`CausalAsyncStreamBackendOptions`:

```zig
pub const CausalAsyncStreamBackendOptions = struct {
    max_events: ?usize = null,
    sink: ?CausalAsyncStreamSink = null,
};
```

`CausalAsyncStreamBackendState` should expose:

- `init(allocator, options)`
- `deinit()`
- `backend()`
- `eventCount()`
- `acceptedEventCount()`
- `drainedEventCount()`
- `failedEventCount()`
- `droppedEventCount()`
- `flushedCount()`
- `peekSnapshot(allocator)`
- `drain(allocator)`
- `clear()`
- `flush()`

`peekSnapshot` returns cloned events and leaves the queue untouched. `drain`
returns cloned events and clears the queued originals. `clear` discards queued
events without returning them. `flush` invokes the optional sink flush hook and
increments `flushed_count` when the hook succeeds.

## Data Ownership

The backend must copy `label`, `type_name`, `status`, and `redacted_detail`
before returning from `record`. Snapshots and drains must return owned
`CausalSnapshot` values so callers can deinit them independently.

The sink receives the owned cloned event while the backend is recording. The
sink must copy any strings it keeps after `on_event` returns. This matches the
existing backend contract and avoids hidden aliasing.

## Error Handling

Errors are intentionally visible but non-fatal to `CausalStore`.

- Full queue returns `error.CausalAsyncStreamBackendFull`.
- Sink rejection returns the sink's error after incrementing failed and dropped
  counters.
- Allocator failure returns the allocator error after incrementing failed and
  dropped counters.
- Flush rejection returns the sink's error without incrementing `flushed_count`.

`dropped_event_count` means "events accepted by the core store but not accepted
by this stream backend." That includes full-queue, allocation, and sink failure
cases.

## Agent Use Cases

- A development agent drains the stream after `zig build causal-test` and
  groups events by run, scope, fiber, or finding evidence without needing a
  durable store.
- A watch-mode tool peeks at the queue repeatedly during a long-running command
  and drains only after rendering or forwarding.
- A future UI workbench can attach a sink that mirrors stream events into a
  local UI model while still leaving the adapter queue available for assertions.
- A future NenDB bridge can drain accepted events into a package-backed writer
  without changing the causal backend contract.

## Tests

Focused tests should prove:

- The stream backend receives the conformance trace, stores only retained
  unsampled events, and exposes `CausalBackendKind.async_stream`.
- `peekSnapshot` leaves events queued and `drain` returns events in order.
- Sink callbacks see accepted stored events and can flush.
- Sink failure fails closed without queueing the rejected event.
- `max_events = 0` fails before calling the sink.
- Redaction and truncation markers appear in streamed events while raw secrets
  do not.
- `clear` releases queued events and updates no acceptance counters.

## Documentation

Update:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/agent-guide.md`
- `packages/zigeffect/docs/agent-observable-runtime.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

Documentation should describe async stream as a non-durable, bounded,
dependency-free event stream for agents and tools, not as a durable history
adapter.

## Verification

Focused gates:

- `zig build causal-async-stream-backend`
- `zig build causal-backend-conformance`
- `zig build test-raw --summary none`
- `zig build test --summary none`

Full branch gates:

- `zig build causal-test-matrix`
- `zig build examples`
- `bun run check`
- `bun run zig:test`
- `git diff --check HEAD`
