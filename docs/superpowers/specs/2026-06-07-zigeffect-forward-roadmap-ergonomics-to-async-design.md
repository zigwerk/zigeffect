# zigeffect Forward Roadmap: Ergonomics To Async Backend

Date: 2026-06-07

## Purpose

Turn the next `zigeffect` direction into a concrete roadmap. The project should
become easier to compose without becoming an EffectTS API clone, then use that
excellent deterministic core as the compatibility suite for a future async
backend.

This roadmap supersedes ad hoc next-step discussion for the next major slices:

- Milestone 1: Effect ergonomics without API cloning.
- Milestone 2: deterministic dogfood and compatibility hardening.
- Milestone 3: async backend contract.
- Milestone 4 and beyond: real async runtime, parallel composition, and
  production adapters.

## Current Baseline

`zigeffect` already has the deterministic core that makes the project worth
protecting:

- direct-style programs: `fn(ctx) Error!A`;
- `Effect.fromFn`, `succeed`, `fail`, `sync`;
- method-chain composition: `map`, `flatMap`, `tap`;
- recovery: `mapError`, `catchAll`, `orElse`, `tapError`;
- lifecycle: `onExit`, `ensuring`;
- schedules for `retry` and `repeat`;
- typed `Context` service lookup and requirement/provider metadata;
- scoped resources and structured `Exit` / `Cause`;
- deterministic fibers, queues, deferreds, semaphores, and wait-state
  inspection;
- `BackendCapabilities` with a deterministic backend marker;
- causal artifacts and local/CI agent diagnostics.

The current Zig toolchain in this workspace is `0.16.0`.

## Direction

`zigeffect` should be Zig-native Effect, not EffectTS-in-Zig.

That means:

- prefer normal Zig `try`, `if`, `switch`, `while`, and `for` inside program
  bodies;
- use effect composition at module, layer, runtime, test, and workflow
  boundaries;
- add only the operators that make composition clearer than direct Zig;
- keep allocation and ownership explicit;
- keep deterministic semantics as the reference behavior for future async
  backends.

## Principles

### 1. Direct Style First

Do not add a generator equivalent. Zig already has direct-style error flow
through `try`, explicit loops, and exhaustive `switch`.

### 2. Same Env And Failure First

The first ergonomics milestone should compose effects with the same `Env` and
`Failure` type. Error-union and environment-union combinators can come later
only when real code needs them.

### 3. Sequential Before Parallel

`zip`, `all`, and `forEach` should be sequential in the deterministic core.
Parallel options wait until the async backend has proven interruption, cleanup,
and cause semantics.

### 4. No Hidden Allocation

Helpers that allocate must take an allocator or write into caller-owned storage.
Do not smuggle heap ownership into innocent-looking combinators.

### 5. Causal Evidence For Behavior Changes

New runtime behavior should have a causal scenario or artifact path when it
changes failure, cleanup, requirement, schedule, fiber, or coordination
semantics.

### 6. Small Public API, Good Diagnostics

Prefer a small set of useful names plus excellent compile errors over a large
ported operator catalog.

## Milestone 0: Lock The Current Deterministic Baseline

Status: current baseline.

Goal: make sure the next work starts from a known green point and a crisp public
surface.

Deliverables:

- a short public API inventory for `Effect`, `Runtime`, `FiberRuntime`,
  coordination primitives, `Schedule`, `Layer`, and causal tooling;
- confirmation that current backend capabilities are deterministic only;
- compile-fail tests kept stable for invalid effect functions, environments,
  layers, service tuples, and resource error sets;
- docs that state direct-style Zig remains the default.

Exit criteria:

- `bun run zigeffect:test` passes;
- `cd packages/zigeffect && zig build examples` passes;
- no new public API is introduced before it has a milestone owner.

## Milestone 1: Effect Ergonomics Without API Cloning

Goal: make `Effect` easier to compose at boundaries while preserving Zig-shaped
direct style inside programs.

### Proposed API Additions

Add these only after a small design note and tests for each shape.

#### Value Replacement

- `as` or `replace`: run the parent effect and replace its success value with a
  constant.
- `asVoid` or `discard`: run the parent effect and return `void`.

Decision point: choose names that read naturally in Zig. `as` matches EffectTS,
but `replace` / `discard` may be clearer and less surprising.

#### Sequencing

- `andThen`: run the parent effect, ignore its value, then run a second effect
  with the same `Env` and compatible `Failure`.

Do not overload existing `flatMap`. Today `flatMap` is a Zig direct-style
continuation: its binder returns `Failure!Next`, not another `Effect`. Keep that
semantics clear.

#### Pairing

- `zipWith`: run two effects sequentially and combine their success values with
  a pure mapper.
- `zip`: run two effects sequentially and return a small generated pair shape.

Start with the same `Env` and `Failure`. Add different failure/environment
support only after the error and requirement algebra are intentionally designed.

#### Small `all`

- `all2` / `all3`, or a comptime tuple-based `all(.{ ... })`, for sequential
  composition of small known effect groups.

Decision point: prefer the API that gives the clearest compile errors. A
tuple-based `all` is elegant, but fixed-arity helpers may be more maintainable
until the generated result and diagnostics are proven.

#### Sequential `forEach`

- `forEachAlloc`: map a slice through an effectful callback and return an owned
  output slice.
- `forEachDiscard`: map a slice through an effectful callback and return `void`.

Allocating variants must be allocator-explicit. The discard variant should not
allocate.

#### Optional Conditional Helpers

Lower priority:

- `when`: run a `void` effect when a boolean is true.
- `unless`: run a `void` effect when a boolean is false.

Do not add broad `Effect.if` or `whenEffect` clones until app code demonstrates
that raw Zig `if` is materially worse.

### Tests

Add focused tests in `packages/zigeffect/test/effect_test.zig`:

- success path for each helper;
- first-effect failure short-circuits;
- second-effect failure is preserved;
- `tap` / lifecycle hooks still compose after new helpers;
- `requires` metadata remains visible after composition where applicable;
- compile-fail coverage for mismatched environments and malformed callbacks.

### Documentation

Update:

- `packages/zigeffect/docs/usage.md`;
- `packages/zigeffect/docs/effectts-parity.md`;
- `packages/zigeffect/docs/roadmap.md`;
- one example that shows the intended composition style.

### Non-Goals

- no generator syntax;
- no general `pipe` helper;
- no parallel `all`;
- no hidden allocation;
- no full EffectTS control-flow catalog.

### Exit Criteria

- the new helpers are used in at least one package example;
- docs show "direct body, composed boundary" as the preferred style;
- package tests and examples pass;
- causal package-test harness stays green;
- public naming decisions are documented.

## Milestone 2: Deterministic Dogfood And Compatibility Hardening

Goal: make the synchronous deterministic core feel excellent before any real
async backend work begins.

Deliverables:

- a compact behavior matrix covering `Runtime`, `Layer.provide`,
  `layerGraph.run`, `FiberRuntime.fork/join`, and `TestEnv.run` for composed
  effects;
- at least one realistic module example that uses the Milestone 1 helpers with
  services, layers, schedules, scoped resources, and tests;
- causal scenarios for representative composition failures:
  - `zipWith` first effect fails;
  - `zipWith` second effect fails after first succeeds;
  - `forEachDiscard` stops on a failing item;
  - `all` preserves deterministic ordering;
- docs that define which helper semantics are stable enough for async backends
  to preserve.

Implementation cleanup is allowed here only if it reduces real maintenance
cost:

- reduce duplicated wrapper methods in `effect.zig` if the new helpers make the
  repetition hard to maintain;
- keep public behavior unchanged while doing so;
- preserve compile diagnostics before and after the cleanup.

Exit criteria:

- `bun run zigeffect:test` passes;
- `cd packages/zigeffect && zig build examples` passes;
- causal dev-loop artifacts show no new findings for the selected scenario;
- the deterministic backend remains the reference compatibility suite.

## Milestone 3: Async Backend Contract

Goal: design the async backend boundary before writing a production backend.
This milestone is about contracts, not real IO throughput.

Current state:

- `BackendKind` only has `deterministic`;
- `BackendCapabilities` only exposes capability flags;
- deterministic fibers run pending work to completion on `join`;
- coordination primitives expose wait states but do not suspend.

Deliverables:

- a backend design doc under `docs/superpowers/specs/`;
- an expanded backend contract that can describe:
  - spawn;
  - join;
  - interrupt;
  - sleep;
  - yield;
  - deferred await;
  - queue offer/take backpressure;
  - semaphore wait;
  - blocking IO interruption or detachment;
- a clear distinction between backend capability metadata and backend
  operations;
- causal event semantics for `suspended`, `resumed`, `interrupted`,
  `supervised`, and `cancelled_io`;
- proof that `Scope`, `Context`, `Exit`, `Cause`, services, layers, and
  schedules do not need new public shapes for the backend.

Recommended design shape:

- keep `deterministicBackend()` as a value-level capability marker;
- add a small backend operation vtable only when an executable async prototype
  needs it;
- use a deterministic simulator backend before a real `std.Io` backend, so
  suspension semantics are testable without nondeterministic IO.

Non-goals:

- no production zio adapter yet;
- no parallel combinator semantics yet;
- no durable workflow engine;
- no OS-thread pool policy baked into the core.

Exit criteria:

- backend contract is documented;
- deterministic backend tests remain unchanged or strictly clearer;
- simulator design can express pending, resumed, interrupted, and completed
  fibers;
- async work has a compatibility checklist before implementation begins.

## Milestone 4: Async Backend Prototype

Goal: prove real suspension and interruption behind the backend boundary.

Deliverables:

- an opt-in backend prototype, likely named `zio` if that remains the project
  direction;
- `BackendKind` extended without changing existing deterministic semantics;
- `FiberRuntime.withBackend` can run a small suspended workflow;
- fake-clock or backend-clock sleep integration;
- deferred await, queue backpressure, and semaphore wait can suspend and resume;
- scope close interrupts unfinished children through the backend;
- causal artifacts distinguish deterministic run-to-completion from async
  suspend/resume.

Constraints:

- keep `std.Io` at IO-facing boundaries;
- keep deterministic tests as the compatibility baseline;
- keep prototype code behind explicit package/example/test paths until it is
  stable.

Exit criteria:

- deterministic suite still passes;
- async prototype tests pass without wall-clock flakes;
- interruption closes child scopes and records causes consistently;
- docs tell users when they are using deterministic semantics versus async
  backend semantics.

## Milestone 5: Parallel Composition And Structured Concurrency

Goal: add parallel APIs only after async interruption and cleanup semantics are
proven.

Deliverables:

- parallel `all` option or a separate `allPar` name;
- `race` / `raceFirst` only if cancellation semantics are clear;
- supervised task groups;
- parallel cause accumulation that matches existing `Cause.parallel` reporting;
- scope-owned child cleanup for all parallel paths;
- causal timeline views for parallel branches.

Exit criteria:

- parallel children do not leak scopes or resources;
- loser interruption in race-like APIs is deterministic and observable;
- failures preserve enough cause structure for tests and agents;
- deterministic backend either rejects parallel APIs clearly or simulates them
  sequentially with documented semantics.

## Milestone 6: Production Adapters And Application Catalog

Goal: make `zigeffect` credible outside package examples.

Deliverables:

- production causal adapters for JSON Lines and OpenTelemetry first;
- durable causal history adapter only after event schema churn slows down;
- more app/module templates built from real Yachdee needs;
- examples for HTTP-ish request boundaries, database startup, background
  workers, config-driven layers, and graceful shutdown;
- optional workbench after artifacts and event schemas stabilize.

Exit criteria:

- at least one real Yachdee subsystem or service skeleton uses the recommended
  module shape;
- docs distinguish core runtime, stdlib services, optional adapters, and app
  patterns;
- CI captures enough artifacts for a failing runtime or app scenario to be
  diagnosable without rerunning locally.

## Backlog Outside This Roadmap

These are useful but should not block the ergonomics-to-async path:

- `fx.data`, `fx.match`, and structural pattern matching;
- richer config providers;
- broader observability exporters;
- deterministic replay/forking;
- remediation policy engines;
- patch application from causal audit chains.

Treat these as adjacent tracks. Pull them forward only when they directly
support Milestone 1 composition or Milestone 3 backend semantics.

## Recommended Immediate Next Slice

Start with the narrowest Milestone 1 slice:

1. Design and implement `andThen`, `replace` or `as`, and `discard` or
   `asVoid`.
2. Add `zipWith` before `zip`.
3. Add one sequential group helper after `zipWith` proves the type shape.
4. Add docs and one example.
5. Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
```

This makes composition better immediately while leaving the async backend
contract untouched until the deterministic core has earned the next step.
