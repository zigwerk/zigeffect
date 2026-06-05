# Zig Effect And ZGroach Toolchain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build separate `zigeffect` and `zgroach` Zig packages, with tested foundations for a Zig-native Effect toolchain and a RoachGraph compiler package that depends on it.

**Architecture:** `zigeffect` owns reusable Effect-like primitives and service contracts. `zgroach` owns RoachGraph-specific compiler concerns and imports `zigeffect` as a path module. Both packages use standalone Zig build files and can be verified independently.

**Tech Stack:** Zig 0.16.0, Zig build system, local path modules, repository docs under `docs/superpowers/`.

---

### Task 1: Add Zigeffect Tests

**Files:**
- Create: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/src/zigeffect.zig`
- Create: `packages/zigeffect/test/core_test.zig`

- [ ] **Step 1: Create a minimal build file and empty source module**

Use `packages/zigeffect/build.zig` to expose a `zigeffect` module and a test
step rooted at `packages/zigeffect/test/core_test.zig`.

- [ ] **Step 2: Write failing tests for the public API**

Cover:

- effect execution returns success values
- failure exits preserve error causes
- scope finalizers run in reverse order
- context resolves logger/config/services
- fixed and exponential schedules make expected decisions
- test environment captures logs, files, metrics, and traces

- [ ] **Step 3: Verify tests fail before implementation**

Run:

```bash
bun run zigeffect:test
```

Expected: fails because the API is not implemented yet.

### Task 2: Implement Zigeffect Core

**Files:**
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/core_test.zig`

- [ ] **Step 1: Implement direct-style `Effect`**

Create `Effect(Success, Failure, Env)` wrapping a function pointer
`fn (*Context(Env)) Failure!Success`, with `run`, `exit`, and `retry` helpers.

- [ ] **Step 2: Implement `Exit` and `Cause`**

Represent success, failure, defect messages, and interruption ids as tagged
unions.

- [ ] **Step 3: Implement `Scope`**

Store finalizer callbacks and run them in reverse order.

- [ ] **Step 4: Implement service context and layer construction**

Support typed `Context(Env)` access and `Layer(Env)` construction around a
`Scope`.

- [ ] **Step 5: Implement schedules and test services**

Add fixed/exponential retry decisions, fake clock, memory filesystem, logger,
config, metrics, tracing, and `TestEnv`.

- [ ] **Step 6: Verify zigeffect**

Run:

```bash
bun run zigeffect:test
```

Expected: pass.

### Task 3: Add ZGroach Package

**Files:**
- Create: `packages/zgroach/build.zig`
- Create: `packages/zgroach/src/zgroach.zig`
- Create: `packages/zgroach/test/compiler_test.zig`

- [ ] **Step 1: Create package build file**

Expose a `zgroach` module and import the local `zigeffect` module from
`../zigeffect/src/zigeffect.zig`.

- [ ] **Step 2: Write failing compiler scaffold tests**

Cover:

- validating non-empty source succeeds
- validating empty source fails with a compiler error
- validation writes a trace/log entry through `zigeffect.TestEnv`

- [ ] **Step 3: Verify tests fail before implementation**

Run:

```bash
bun run zgroach:test
```

Expected: fails because `zgroach` is not implemented yet.

### Task 4: Implement ZGroach Scaffold

**Files:**
- Modify: `packages/zgroach/src/zgroach.zig`
- Modify: `packages/zgroach/test/compiler_test.zig`

- [ ] **Step 1: Implement compiler environment and validation**

Add `CompilerEnv`, `CompilerError`, and `validateSource`, using zigeffect
services for logs and traces.

- [ ] **Step 2: Verify zgroach**

Run:

```bash
bun run zgroach:test
```

Expected: pass.

### Task 5: Repository Verification

**Files:**
- Review all files touched in this plan.

- [ ] **Step 1: Run package checks**

Run:

```bash
bun run zig:test
```

Expected: both pass.

- [ ] **Step 2: Run TypeScript checks**

Run:

```bash
bun run typecheck
```

Expected: pass or report pre-existing failure exactly.

### Task 6: Zigeffect Bootstrap Expansion

**Files:**
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/core_test.zig`
- Create: `packages/zigeffect/README.md`

- [x] **Step 1: Add failing tests for composition helpers**

Covered `map`, `flatMap`, and `tap` on direct-style effects.

- [x] **Step 2: Add failing tests for scoped typed finalizers**

Covered `Context.addFinalizerFor` and reverse-order scope cleanup.

- [x] **Step 3: Add failing tests for service helpers**

Covered logger warn/error, config overwrite/require, metrics gauge, tracing
span markers, memory filesystem overwrite/delete/exists, and test assertions.

- [x] **Step 4: Implement the minimal API**

Implemented the composition wrappers, service helpers, typed finalizers, and
test environment assertions.

- [x] **Step 5: Verify zigeffect**

Run:

```bash
bun run zigeffect:test
```

Expected: pass.

### Task 7: ZGroach Consumes Expanded Zigeffect

**Files:**
- Modify: `packages/zgroach/src/zgroach.zig`
- Modify: `packages/zgroach/test/compiler_test.zig`
- Create: `packages/zgroach/README.md`

- [x] **Step 1: Add an effect-returning validation entry point**

Added `validateCurrentSource()` to read `schema.path` from config and source
content from the memory filesystem.

- [x] **Step 2: Verify zgroach**

Run:

```bash
bun run zgroach:test
```

Expected: pass.

### Task 8: Scoped Resource And Agent Documentation Expansion

**Files:**
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/core_test.zig`
- Modify: `packages/zigeffect/README.md`
- Create: `packages/zigeffect/docs/usage.md`
- Create: `packages/zigeffect/docs/agent-guide.md`
- Create: `packages/zigeffect/docs/devex-review.md`

- [x] **Step 1: Add failing scoped resource test**

Covered `acquireRelease` returning a typed pointer and registering release with
the active `Scope`.

- [x] **Step 2: Implement `acquireRelease`**

Implemented a direct-style effect helper that runs acquire, registers a typed
finalizer, and returns the resource.

- [x] **Step 3: Document usage and agent rules**

Added usage, agent, and devex review docs with typed error, service, test, and
scoped resource examples.

### Task 9: Runtime-Managed Cleanup

**Files:**
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/core_test.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/usage.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/devex-review.md`

- [x] **Step 1: Add failing tests for engine cleanup**

Covered runtime-managed resource cleanup on both success and failure paths.

- [x] **Step 2: Implement `Runtime` and `TestEnv.run`**

Added `Runtime(Env)` with fresh-scope `run`/`exit` and `TestEnv.run` helpers.

- [x] **Step 3: Make docs recommend runtime-managed cleanup**

Updated README, usage, agent, and devex docs to make engine-managed scope
cleanup the default path.

### Task 10: Diagnostics And Hand-Holding

**Files:**
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/core_test.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/usage.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/devex-review.md`
- Create: `packages/zigeffect/docs/errors.md`

- [x] **Step 1: Add failing tests for runtime diagnostics**

Cover:

- `formatExit` renders a failed program with the label, error name, and a hint.
- `formatCause` renders defects and interruptions with clear labels.
- `Context.addFinalizerFor` returns `error.MissingScope` when no scope is
  active.
- `acquireRelease` releases an acquired resource immediately when finalizer
  registration fails.

Run:

```bash
bun run zigeffect:test
```

Expected: fail because the diagnostics API is not implemented yet.

- [x] **Step 2: Implement minimal diagnostics API**

Add:

- `ScopeError = error{MissingScope}`
- `Context.addFinalizerFor` returning `Allocator.Error || ScopeError`
- `formatExit(allocator, label, exit)` and `formatCause(allocator, label, cause)`
- `serviceNotFound(Env, Service)` returning `noreturn` with a rich
  `@compileError`

- [x] **Step 3: Document error ergonomics**

Document how custom environments should use `fx.serviceNotFound`, why scoped
resources should run through `Runtime.run`/`TestEnv.run`, and how CLIs/tests can
print formatted exits.

- [x] **Step 4: Verify diagnostics**

Run:

```bash
bun run zigeffect:test
bun run zig:test
```

Expected: pass.

### Task 11: Repository Test Verification

**Files:**
- Review all touched repository files.

- [x] **Step 1: Run repository tests**

Run:

```bash
bun run test
```

Expected: pass or report pre-existing failure exactly.

### Task 12: Core Checklist Completion

**Files:**
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/core_test.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/usage.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/devex-review.md`
- Modify: `docs/superpowers/specs/2026-06-04-zigeffect-zgroach-toolchain-design.md`

- [x] **Step 1: Add failing tests for missing checklist APIs**

Covered `Layer.fromBuilder`, `Layer.buildContext`, `Schedule.repeat`,
`Schedule.backoff`, `Schedule.jitteredBackoff`, and `Effect.repeat`.

- [x] **Step 2: Implement missing checklist APIs**

Added scoped layer construction, successful effect repetition, backoff schedules,
and deterministic jitter schedules.

- [x] **Step 3: Update docs**

Updated README, usage, agent guide, devex review, and the design spec to show
layer construction and richer schedules as part of the core shape.

- [x] **Step 4: Verify checklist completion**

Run:

```bash
bun run zig:test
bun run typecheck
bun run test
```

Expected: pass.

### Task 13: Core Hardening V1

**Files:**
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/core_test.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/usage.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/devex-review.md`
- Modify: `packages/zigeffect/docs/errors.md`
- Modify: `docs/superpowers/specs/2026-06-04-zigeffect-zgroach-toolchain-design.md`

- [x] **Step 1: Add failing tests for hardening APIs**

Cover:

- `Effect.succeed`, `Effect.fail`, and `Effect.sync`.
- `mapError`, `catchAll`, `orElse`, and `tapError`.
- nested `Cause` formatting plus finalizer failure causes.
- fallible finalizers recorded by `Scope` and surfaced by `Runtime.exit`.
- `Layer.merge` and `Layer.provide`.
- `Clock` service abstraction through `Context`, schedules, and `TestEnv`.

Run:

```bash
bun run zigeffect:test
```

Expected: fail because these APIs are not implemented yet.

- [x] **Step 2: Implement hardening APIs**

Add minimal, direct-style implementations that preserve the existing `Effect`
shape and keep typed Zig errors explicit.

- [x] **Step 3: Update docs**

Document recovery, fallible cleanup, layer composition, and clock service usage.

- [x] **Step 4: Verify hardening**

Run:

```bash
bun run zig:test
bun run typecheck
bun run test
```

Expected: pass.

### Task 14: Core Style Parity V2

**Files:**
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/core_test.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/usage.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/devex-review.md`
- Modify: `packages/zigeffect/docs/errors.md`
- Create: `packages/zigeffect/docs/effectts-parity.md`
- Modify: `docs/superpowers/specs/2026-06-04-zigeffect-zgroach-toolchain-design.md`

- [x] **Step 1: Research EffectTS maturity**

Reviewed official Effect docs for generators/direct style, services, layers,
cause/exit, schedules, logging, tracing, metrics, config, and test clocks.

- [x] **Step 2: Add failing tests for lifecycle and schedule parity**

Covered `Effect.onExit`, `Effect.ensuring`, `Scope.addFinalizerExit`,
`Scope.closeWithExit`, and schedule constructors `once`, `recurs`, `spaced`,
`duration`, and `fibonacci`.

Run:

```bash
bun run zigeffect:test
```

Expected: fail because the parity APIs are not implemented yet.

- [x] **Step 3: Implement parity APIs**

Added direct-style lifecycle combinators, exit-aware scope finalizers, runtime
and layer exit-aware scope closing, and schedule aliases/fibonacci delay.

- [x] **Step 4: Update docs**

Documented EffectTS style parity, lifecycle combinators, exit-aware cleanup, and
schedule vocabulary.

- [x] **Step 5: Verify parity**

Run:

```bash
bun run zig:test
bun run typecheck
bun run test
```

Expected: pass.

### Task 15: Production Core V1

**Files:**
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/core_test.zig`
- Create: `packages/zigeffect/test/compile_fail/missing_service.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/usage.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/devex-review.md`
- Modify: `packages/zigeffect/docs/errors.md`
- Modify: `packages/zigeffect/docs/effectts-parity.md`
- Modify: `docs/superpowers/specs/2026-06-04-zigeffect-zgroach-toolchain-design.md`

- [x] **Step 1: Add failing tests for dependency requirements**

Add tests proving an effect can declare required services, a layer/runtime can
declare provided services, missing requirements produce structured dependency
reports, and checked execution refuses to run when requirements are missing.

Run:

```bash
bun run zigeffect:test
```

Expected: fail because requirement metadata, reports, and gates are missing.

- [x] **Step 2: Add failing tests for layer graph validation**

Add tests proving a graph reports missing layer requirements and duplicate
service providers with human-readable diagnostics.

Run:

```bash
bun run zigeffect:test
```

Expected: fail because `LayerGraph` and dependency reports are missing.

- [x] **Step 3: Add failing tests for typed startup errors**

Add a `LayerWithError(Env, StartupError)` test that preserves an application
startup error from the layer builder through `provide`.

Run:

```bash
bun run zigeffect:test
```

Expected: fail because typed startup layers are missing.

- [x] **Step 4: Add compile-fail fixture test**

Create `packages/zigeffect/test/compile_fail/missing_service.zig` and add a test
that invokes `zig build-exe -fno-emit-bin` against it, expecting a non-zero exit
and stderr containing `zigeffect service not found`.

Run:

```bash
bun run zigeffect:test
```

Expected: fail until the fixture/harness is wired correctly.

- [x] **Step 5: Implement Production Core V1 APIs**

Add:

- `ServiceSet`
- `DependencyIssue`, `DependencyReport`, `formatDependencyReport`
- `validateLayerRequirements`
- `LayerGraph`
- `Effect.requires`
- checked `Layer.provide` and `Runtime.run`
- `Runtime.provides`
- `Layer.provides` / `Layer.requires`
- `LayerWithError(Env, StartupError)`

- [x] **Step 6: Update docs**

Document the production composition path, rich dependency reports, checked
runtime boundaries, typed startup errors, and compile-fail diagnostics fixture.

- [x] **Step 7: Verify Production Core V1**

Run:

```bash
bun run zig:test
bun run typecheck
bun run test
```

Expected: pass.
