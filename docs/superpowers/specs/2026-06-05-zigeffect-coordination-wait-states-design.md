# zigeffect Coordination Wait States Design

Date: 2026-06-05

## Goal

Define deterministic backpressure semantics for `Deferred`, `Queue`, and
`Semaphore` without claiming real suspension.

## Design

Add explicit wait-state inspection APIs to
`packages/zigeffect/src/runtime/coordination.zig`:

- `DeferredAwaitState`: `ready`, `pending`
- `QueueOfferState`: `ready`, `backpressured`, `shutdown`
- `QueueTakeState`: `ready`, `empty`, `shutdown`
- `SemaphoreAcquireState`: `ready`, `unavailable`

Expose methods:

- `Deferred.awaitState()`
- `Queue.offerState()`
- `Queue.takeState()`
- `Semaphore.acquireState(permits)`

Existing operations keep deterministic behavior:

- `Deferred.awaitExit()` returns `DeferredNotCompleted` while pending
- `Queue.offer()` returns `QueueFull` when `offerState()` is `backpressured`
- `Queue.take()` returns `QueueEmpty` or `QueueShutdown` based on `takeState()`
- `Semaphore.acquire()` returns `SemaphoreUnavailable` when the acquire state is
  unavailable

This gives tests, agents, and future async backends a shared contract for what
would suspend in a real backend.

## Non-Goals

- Do not add real blocking or suspend/resume.
- Do not add wait queues.
- Do not change deterministic fiber join semantics.

## Tests

Add tests in `packages/zigeffect/test/fiber_test.zig` that verify state
transitions for pending/completed deferreds, bounded queue backpressure,
shutdown, and semaphore availability.
