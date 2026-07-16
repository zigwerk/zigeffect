# ZigEffect Canonical Kernel Migration Plan

Date: 2026-07-15
Design: `docs/superpowers/specs/2026-07-15-zigeffect-developer-experience-redesign.md`

## Goal

Replace environment-coupled dependency injection with the canonical
service/effect/layer/runtime model before migrating first-party libraries and
applications. Compatibility is not a delivery requirement; migration safety,
deterministic evidence, and a coherent final API are.

## Guardrails

- New code must not depend on `Context(Env)`, `ServiceEnv`, `LayerGraphEnv`, or
  automatic environment projection.
- Do not add an adapter that converts legacy effects or layers into canonical
  ones.
- Keep old internals only as a temporary migration island.
- Write each kernel behavior as a failing Testing v2 test first.
- Preserve the scheduler, scope, causal, and testing engines where their model
  is independent of concrete environments.
- Add no report-only tools and no new `causal_*` tools.
- Do not begin std/gRPC/Ziac application migration until the reference runtime
  demonstrates graph reuse and correct finalization.

## Phase 1: Prove the dependency kernel

### Task 1: Stable services and runtime Context

Add a canonical kernel module containing:

- `Service(key, API)` tags;
- a tag-indexed, type-checked service registry;
- duplicate-key/type diagnostics;
- owned service storage with deterministic cleanup; and
- a requirements-limited context view.

Tests:

1. two implementations of one tag can be selected by different contexts;
2. a duplicate key with a different API is rejected;
3. missing service lookup is a typed runtime error at the interpreter boundary;
4. an effect context cannot request an undeclared tag (compile-fail test); and
5. structural service provision/access facts require no program instrumentation.

### Task 2: Requirement-typed Effect

Implement `Effect(Success, Failure, Requirements)` independently of the legacy
effect. It stores no concrete environment type. Add base constructors and the
smallest composition algebra needed by the reference application.

Tests:

1. effect requirements are tag tuples;
2. `map`, `flatMap`, error recovery, and finalization preserve/union types;
3. a concrete runtime context is not present in the effect type;
4. live and fake implementations execute the same effect unchanged; and
5. start/success/failure events are emitted by the interpreter.

### Task 3: Output/Error/Input Layer algebra

Implement leaf layers plus `mergeAll`, `provide`, and `provideMerge`.

Tests:

1. constructors expose exact output/error/input metadata;
2. `mergeAll` unions inputs but does not satisfy sibling dependencies;
3. `provide` removes satisfied inputs and hides dependency outputs;
4. `provideMerge` keeps dependency outputs; and
5. startup failure closes already-acquired resources in reverse order.

### Task 4: Identity-based memoization

Assign a stable identity to every constructed leaf layer and add a build-scope
memo table.

Tests:

1. copying/reusing one layer value across branches acquires it once;
2. invoking the same constructor twice produces two identities;
3. memoization does not cross managed-runtime instances; and
4. shared layers finalize exactly once.

### Task 5: ManagedRuntime

Implement `ManagedRuntime.make(root_layer)` as the normal application
interpreter. It owns the root scope/context and supports repeated `run`/`exit`
operations with per-run child scopes.

Tests:

1. the root layer builds once across multiple endpoint programs;
2. only programs whose requirements are included in root outputs compile;
3. per-run resources close after each run while application resources remain;
4. disposal is idempotent and finalizes application resources once; and
5. causal receipts connect runtime, layer, service, effect, and scope events;
6. runtime state is heap-stable across return/move of the ManagedRuntime value;
   and
7. a running server/worker effect derives `RuntimeHandle(R)` and uses it to run
   multiple requirement-compatible child effects in fresh scopes.

## Phase 2: Complete the runtime experience

### Task 6: Default services and scoped overrides

Add runtime-owned reference defaults for Clock, ConfigProvider, Console,
Random, and Tracer. Their accessors must not change an effect's requirements.
Add lexical override operations, copy overrides into derived RuntimeHandles,
and prove that nested child runs inherit them without mutating the root
runtime. Keep process-backed construction at the application boundary and
provide deterministic test implementations.

### Task 7: Runtime aspects

Define one interpreter lifecycle interface and attach logger, metrics, tracer,
supervisor, and causal aspects. Remove application-facing manual structural
recording from the canonical path.

The first aspect slice records every interpreter lifecycle event through
runtime-installed logger, metrics, and tracer adapters. Allocation or exporter
failure in an observer is best-effort and cannot change the typed result of the
program. Fiber supervision is added with the child-run API rather than being
simulated by log events.

### Task 8: Service definition helper

Add the Zig-native all-in-one service declaration with `Default()` and
`DefaultWithoutDependencies()`. Ensure the expanded tag/layer form remains
available.

### Task 9: Compile-checked multi-endpoint reference app

Build a small service with:

- abstract repository and API contracts;
- live and fake implementations;
- explicitly provided construction dependencies;
- a shared layer used by two branches;
- one managed runtime;
- multiple endpoint effects; and
- automatic causal evidence for a selected request slice.

This application is the migration oracle. If a public API makes the example
mechanical or permits dependency leakage, change the kernel before moving on.

## Phase 3: First-party migration

1. Rewrite `zigeffect-std` services and defaults on the canonical kernel.
2. Change scaffolds to generate contracts, live/test layers, a root layer, and
   one managed-runtime entry point.
3. Rewrite gRPC servers, channels, clients, middleware, and handlers as layers
   and effects; create one runtime per service process, not per RPC.
4. Rewrite Ziac planning, provider discovery, execution, state, and CLI roots as
   explicit services/layers.
5. Migrate product applications by vertical domain.
6. Delete legacy Effect/Context/Layer/Runtime dependency machinery and rename
   canonical kernel exports to the top-level final API.

## Verification Per Phase

From `packages/zigeffect`:

```bash
zig build test-raw
zig build public-api-review
```

When build files or templates change:

```bash
packages/zigeffect/scripts/check_testing_v2_migration.sh
```

Inspect `.zigeffect/tests/suites/*.json`. Required receipts must report pass,
complete discovery/execution, zero pending tests, zero leaks, and zero logged
errors. Compile-fail diagnostics must assert the intended dependency error, not
an incidental compiler failure.

## Immediate Slice

The first implementation slice is Tasks 1, 2, 3, 4, and 5 at the minimum
surface required to prove:

- tag-based runtime resolution;
- requirements-limited effects;
- explicit layer provision;
- shared-layer memoization; and
- one managed runtime executing multiple programs.

Default-service overrides and the complete aspect set follow only after this
structural proof passes.

## Current Slice: Runtime Admission Gates

1. Implement the five runtime reference defaults and inherited lexical
   overrides.
2. Add automatic logger, metrics, tracer, and causal consumers to the existing
   `RuntimeAspect` lifecycle.
3. Add supervised child-run/fiber lifecycle to `RuntimeHandle`.
4. Add a compile-checked multi-endpoint reference server that constructs one
   runtime, derives one bounded handle, and executes every request in a child
   scope.
5. Revisit memo entries before nested/dynamic layer construction: Effect's
   reference implementation uses identity keys plus observer-counted
   finalizers, so the current root-only boolean memo table is not the final
   general memo model.
