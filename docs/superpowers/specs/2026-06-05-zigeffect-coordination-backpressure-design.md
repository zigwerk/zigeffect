# zigeffect Coordination Backpressure Design

Date: 2026-06-05

## Goal

Deliver a deterministic roadmap section 8 slice that improves queue and
semaphore lifecycle semantics without pretending the current runtime can
suspend fibers.

## Contracts

- `Queue.shutdown()` prevents new offers.
- A shut down queue still drains already buffered items.
- Taking from an empty shut down queue returns `error.QueueShutdown`.
- `Semaphore.acquireScoped(scope, permits)` acquires permits and registers a
  scope finalizer that releases them when the scope closes.
- If scoped permit finalizer registration fails, acquired permits are released
  immediately.

## Non-Goals

- No blocking producer/consumer suspension yet.
- No async wakeup queues yet.
- No queue interruption propagation yet beyond deterministic shutdown errors.

## Tests

- Queue shutdown rejects new offers and drains buffered items before reporting
  shutdown.
- Scoped semaphore permits release on scope close and preserve over-release
  protection.

