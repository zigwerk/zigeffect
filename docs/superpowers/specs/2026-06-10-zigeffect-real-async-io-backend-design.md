# zigeffect Real Async IO Backend Design

Date: 2026-06-10

Milestone: 47 - Real Async IO Backend

## Goal

Add a real local async backend to zigeffect that can own suspended work,
register timer, network, file, and cancellation waits, wake or interrupt those
waits exactly once, and integrate with runtime, workflow scheduler, durable
timers, durable queues, and cluster transport boundaries without changing the
deterministic backend contract.

## Current Context

The package already has the contracts from the async-backend milestone:

- `BackendCapabilities` names deterministic, durable-local, async-local, and
  clustered capability sets.
- `AsyncBackend` exposes suspend, wake, schedule-timer, and interrupt vtable
  operations.
- `UnsupportedAsyncBackendState` proves deterministic backends reject async-only
  operations.
- `WorkflowContext.sleep`, `awaitDeferred`, signal waits, and durable queue
  awaits already return a `Suspension`.
- `WorkflowScheduler.tick` already has separate workflow, timer, queue retry,
  and queue claim phases.
- Cluster transport has a durable request/response schema and synchronous
  in-process and loopback HTTP implementations.

The missing production pieces are an implementation behind the async backend
contract, a way to poll backend wake events, typed IO wait registration for
file and network waits, scope cleanup that interrupts suspended backend waits,
and scheduler integration that wakes durable workflow suspensions without
duplicating completed work.

## Selected Architecture

Add `LocalAsyncBackendState` in `packages/zigeffect/src/runtime/async_backend.zig`.
It is an owned event-loop state object with an `AsyncBackend` facade. It stores
pending waits, ready wake events, completed wake ids, interrupt counts, duplicate
operation counts, and next-due timer metadata.

The backend remains dependency-free Zig code:

- timers are scheduled by millisecond due time and become ready when the local
  backend time reaches that point;
- network and file waits are registered as typed IO waits and completed by the
  IO owner through `completeIo`;
- cancellation is represented through `interrupt`, which moves a wait to the
  ready queue with interrupted status;
- duplicate suspend, timer, IO, wake, and interrupt operations are idempotent
  once a suspension has reached a terminal backend state.

This gives zigeffect a real backend-owned suspension and wake engine without
requiring every direct-style `Effect` to become a coroutine in the same change.
Direct-style code can opt into suspension by returning `RuntimeDecision` or a
workflow suspension result. A later coroutine lowering layer can target this
backend without changing the wait registry semantics.

## Public API Additions

Extend `runtime/async_backend.zig` with:

- `AsyncWaitKind`: runtime, timer, network, file, cancellation.
- `AsyncWaitStatus`: pending, ready, interrupted.
- `AsyncIoWaitKind`: network or file.
- `AsyncIoInterest`: readable, writable, completion.
- `BackendIoWaitRequest`.
- `BackendIoCompleteRequest`.
- `BackendWakeEvent`.
- `AsyncBackendSnapshot`.
- `LocalAsyncBackendState`.

Extend `AsyncBackend.VTable` with:

- `register_io_wait`
- `complete_io`
- `poll_wake`
- `snapshot`

Keep existing methods:

- `suspend_runtime`
- `wake`
- `schedule_timer`
- `interrupt`

The unsupported backend implements every method with
`UnsupportedBackendCapability`, except `snapshot`, which returns a zeroed
snapshot for diagnostics.

## Runtime And Context Integration

Add an optional `AsyncBackend` handle to `Context`, `Runtime`, and
`FiberRuntime`.

New runtime APIs:

- `Runtime.withAsyncBackend(backend: AsyncBackend)`
- `FiberRuntime.withAsyncBackend(backend: AsyncBackend)`
- `Context.async_backend`

`withAsyncBackend` also sets backend capabilities from
`backend.capabilities`, so callers do not need to pass two separate backend
values for the common case.

Add context helpers:

- `Context.requireAsyncBackend()`
- `Context.suspendRuntime(suspension, reason)`
- `Context.registerIoWait(suspension, kind, interest, descriptor, reason)`

These helpers return `UnsupportedBackendCapability` if no async backend is
attached or if the attached backend rejects the operation.

## Async-Safe Scope Finalization

Add a scoped backend wait finalizer helper in `runtime/async_backend.zig`:

- `attachAsyncInterruptFinalizer(scope, backend, suspension_id, reason)`

The helper registers a finalizer that calls `backend.interrupt` with the
suspension id. This makes cleanup explicit and testable: when a scope closes
before an IO wait completes, the backend records an interrupted wake exactly
once and the scope still reports finalizer failures through the existing
`Scope` machinery.

## Workflow Scheduler Integration

Add optional async backend support to `WorkflowScheduler`:

- `WorkflowScheduler.initWithAsyncBackend`
- `WorkflowScheduler.withAsyncBackend`
- `WorkflowScheduler.tickAsync`

`tickAsync` performs these phases:

1. Register all pending timer waits for registered timer watches.
2. Advance the local backend time to the scheduler clock when the backend is a
   local backend.
3. Poll ready backend wake events up to the timer and queue budgets.
4. For ready timer wakes, call `DurableClock.fireDueTimers(now_ms)`.
5. For interrupted timer wakes, call `DurableClock.cancel(label)`.
6. Run the existing queue retry and queue claim phases.
7. Wake queue suspensions after queue worker completion or failure.
8. Run the existing workflow worker polling phase.

The existing `tick` method remains unchanged and remains the deterministic
compatibility surface.

Add `DurableClock.pendingTimers()` so the scheduler can register future timer
waits without firing them early.

## Durable Queue And Activity Idempotency

Queue worker completion and failure already append terminal queue events and
`workflow_resumed`. The async scheduler wakes the backend suspension after the
journal append succeeds. A duplicate backend wake must not append a duplicate
queue terminal event because replay checks journal terminal events before
running work again.

Add a focused test proving a completed activity result is replayed when the
async backend receives duplicate wake events for the same suspension id. This
guards the high-risk interaction between async wake dedupe and durable replay.

## Cluster Transport Boundary

Add async wait integration without replacing transport schemas:

- `ClusterTransportAsyncWait` records a transport request waiting on a network
  suspension id.
- `registerClusterTransportWait` registers the network wait with an async
  backend using the transport policy timeout and idempotency key.
- `completeClusterTransportWait` completes the network wait, polls the backend
  wake, and submits through the existing `ClusterTransport.send`.

This preserves request/response schemas, retry policy, and idempotency behavior
while giving the later multi-runner transport milestone a real backend wait
surface to bind to sockets.

## Testing

Add `packages/zigeffect/test/async_backend_test.zig` and import it from
`test/all_test.zig`.

Coverage:

- unsupported deterministic backend still rejects suspend, wake, timers,
  interrupts, and IO wait registration;
- local async backend registers and wakes runtime suspensions exactly once;
- local async backend schedules timers and only releases them when time reaches
  the due millisecond;
- local async backend registers network and file waits and releases them through
  `completeIo`;
- interrupt moves a pending wait to interrupted status and duplicate interrupts
  are idempotent;
- scope close calls the async interrupt finalizer and produces one interrupted
  wake;
- `Runtime` and `FiberRuntime` propagate the attached async backend into
  `Context`;
- workflow scheduler `tickAsync` registers durable timers, wakes them through
  the backend, and appends one durable `timer_fired` plus one
  `workflow_resumed`;
- queue completion under `tickAsync` wakes the queue suspension after the
  journal terminal event;
- completed durable activity results are not duplicated when a wake is repeated;
- cluster transport wait registration and completion submit through existing
  transport storage once.

## Documentation

Update:

- `packages/zigeffect/docs/architecture.md`
- `packages/zigeffect/docs/usage.md`
- `packages/zigeffect/docs/effectts-parity.md`
- `packages/zigeffect/docs/public-api-review.md`
- `packages/zigeffect/README.md`

The docs should state that zigeffect now has a local async backend for
backend-owned suspension, wake polling, timers, typed IO waits, and cancellation.
They should also state that direct-style `Effect` code remains synchronous
unless it explicitly opts into async backend operations.

## Acceptance

Milestone 47 is accepted when:

- local async backend tests pass;
- deterministic unsupported backend tests still pass;
- workflow scheduler async tests pass;
- cluster transport async wait tests pass;
- durable activity replay dedupe test passes;
- docs describe the async backend strategy and user-facing boundary;
- `bun run zigeffect:test` passes;
- `bun run zig:test` passes;
- `cd packages/zigeffect && zig build examples` passes;
- Milestone 47 roadmap deliverables and acceptance boxes are marked complete.
