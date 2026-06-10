# zigeffect Durable Core Prerequisites Design

Date: 2026-06-09

## Purpose

Milestone 0.5 adds the smallest core vocabulary needed before durable workflows
and clustering. This is not the workflow engine. The workflow layer will own
journals, activities, timers, deferreds, queues, signals, and replay. The core
should only provide shared contracts that would otherwise be reinvented by
workflow, cluster, testing, and storage code.

## Current Context

The deterministic runtime already exposes `Effect`, `Runtime`, `FiberRuntime`,
`Scope`, `Exit`, `Cause`, `Schedule`, `LayerGraph`, `Clock`, `CausalStore`,
`Deferred`, `Queue`, and `Semaphore`. The backend contract currently has only
`BackendKind.deterministic` and cannot suspend, persist, supervise, interrupt
blocking IO, run in parallel, or distribute work.

Durable workflows need more shared vocabulary before the first journal module:

- encode/decode contracts for persisted payloads, results, failures, messages,
  and snapshots;
- stable deterministic ids for workflows, activities, timers, deferreds,
  queues, runners, shards, and messages;
- a way to name controlled suspension without confusing it with success or
  typed failure;
- cooperative cancellation state for durable waits and compensation;
- backend capability names that distinguish deterministic, durable-local,
  async-local, and clustered execution;
- causal extension naming for future workflow and cluster events.

## Design

### Codec Contract

Add a small generic `Codec(Value)` contract under `src/traits/codec.zig` and
export it through `fx.traits.Codec` plus a root `fx.Codec` alias. The contract
uses allocator-explicit `encode` and `decode` callbacks and intentionally does
not prescribe ownership of decoded nested data yet. Workflow definitions can
choose value types and deinit policies later.

This belongs in `traits` because it is a typeclass-style contract shared by
data, workflow, cluster messages, snapshots, and storage adapters.

### IdGenerator Service

Add `src/services/id_generator.zig` with a deterministic monotonic
`IdGenerator`. It should expose `init(start)`, `next()`, `peek()`, and
`reset(start)`. Add it to `TestServices` so tests and future workflow engines
can request it through `Context`.

This starts intentionally deterministic. Production snowflake-style ids can be
added later behind the same service shape.

### Runtime Control Vocabulary

Add `src/runtime/control.zig` with:

- `SuspensionKind`: `timer`, `deferred`, `queue`, `signal`, `activity`,
  `external`;
- `Suspension`: kind plus stable id and label;
- `RuntimeDecision`: `completed`, `suspended`, `cancelled`;
- `Cancellation`: cooperative cancellation flag with reason text.

This does not change `Effect.run` semantics yet. It gives workflow code a core
type for "waiting" and gives later backend work a shared cancellation service.

### Backend Capabilities

Expand `BackendKind` to:

- `deterministic`;
- `durable_local`;
- `async_local`;
- `clustered`.

Add capability booleans:

- `can_suspend`;
- `can_interrupt_blocking_io`;
- `can_supervise`;
- `can_parallel`;
- `can_persist`;
- `can_distribute`.

Keep `deterministicBackend()` unchanged except for the two new booleans being
false. Add `durableLocalBackend()`, `asyncLocalBackend()`, and
`clusteredBackend()` constructors. These constructors are capability labels,
not implementations of workflow or cluster behavior.

### Causal Extension Points

Add a tiny causal extension domain contract to `services/causal.zig`:

- `CausalExtensionDomain`: `workflow`, `cluster`;
- `causalExtensionDomainName(domain)`.

Do not add workflow or cluster event kinds yet. The workflow and cluster
milestones should introduce real event shapes when they have concrete journal
or message semantics. This milestone only prevents each layer from inventing
different names.

## Public Surface

Add root/facade exports:

- `fx.Codec`;
- `fx.IdGenerator`;
- `fx.SuspensionKind`;
- `fx.Suspension`;
- `fx.RuntimeDecision`;
- `fx.Cancellation`;
- `fx.durableLocalBackend`;
- `fx.asyncLocalBackend`;
- `fx.clusteredBackend`;
- `fx.CausalExtensionDomain`;
- `fx.causalExtensionDomainName`.

Also expose the same names under their domain namespaces where appropriate.

## Testing

Use TDD for every code slice:

- architecture tests for facade exports and backend capability constructors;
- trait tests for codec round trips and decode errors;
- service tests for deterministic id generation and context access;
- runtime tests for suspension and cancellation vocabulary;
- causal tests for extension domain names.

Verification commands:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
```

## Non-Goals

- No workflow engine.
- No journal store.
- No durable timers, deferreds, queues, or signals.
- No actor runtime.
- No real async backend.
- No distributed clustering.
- No `CausalEventKind` workflow or cluster taxonomy expansion before real
  workflow and cluster event semantics exist.

## Acceptance

- The core exposes the durable prerequisites without changing existing
  deterministic runtime behavior.
- Existing package tests, examples, and zgroach tests pass.
- The durable workflows/clustering roadmap marks Milestone 0.5 complete.
