# zigeffect Fiber Workflow Assertions Design

## Goal

Add deterministic fiber workflow coverage for queue producer/consumer flows and
small test helpers that make those workflows easy to assert.

## Chosen Approach

Keep coordination primitives synchronous and deterministic. A producer fiber can
offer items and shut down a queue; a consumer fiber can drain those items and
observe shutdown. The workflow test joins fibers explicitly because the current
backend does not suspend or resume work yet.

Add test helpers in `fx.testing`:

- `expectFiberStatus(fiber, status)`
- `expectQueueLen(queue, expected)`
- `expectQueueShutdown(queue, expected)`

## Contract

- Producer/consumer tests use real `FiberRuntime`, `Fiber`, and `Queue` values.
- Helpers are assertions only; they do not mutate fibers or queues.
- Queue shutdown semantics remain: shutdown rejects offers, drains buffered
  items, then returns `QueueShutdown`.

## Tests

- A producer fiber offers two items and shuts the queue down.
- A consumer fiber drains the two items and observes shutdown.
- Test helpers assert pending/done fiber status, queue length, and queue
  shutdown state during the workflow.
