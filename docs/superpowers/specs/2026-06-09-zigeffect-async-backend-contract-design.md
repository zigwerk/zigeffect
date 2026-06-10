# zigeffect Async Backend Contract Design

Date: 2026-06-09

## Purpose

Milestone 22 prepares durable workflows for real suspension without changing the
workflow API. It expands the runtime backend contract from broad capability
flags into operation-specific async backend requirements, adds a vtable-shaped
async backend interface, adds deterministic conformance tests, and gives the
workflow engine clear diagnostics when a feature needs a backend capability that
is unavailable.

## Scope

This milestone does not implement real async I/O, a scheduler, network
transport, or clustered ownership. It defines the contracts those later
milestones must satisfy. The deterministic backend remains the default and must
continue to pass all existing tests.

## Existing Context

`packages/zigeffect/src/runtime/backend.zig` already defines:

- `BackendKind`: `deterministic`, `durable_local`, `async_local`, `clustered`.
- `BackendCapabilities`: broad flags for suspension, blocking-I/O interrupt,
  supervision, parallelism, persistence, and distribution.
- Constructors for deterministic, durable-local, async-local, and clustered
  capability sets.

`Runtime` and `FiberRuntime` already expose `backendCapabilities()` and default
to the deterministic backend. `WorkflowEngine` currently has no backend field,
no backend validation, and no diagnostic helper.

## Capability Model

Keep existing broad capability fields for compatibility, then add
operation-specific workflow async flags:

- `can_wake`: backend can wake a suspended runtime/workflow.
- `can_schedule_timers`: backend can register timer wakeups.
- `can_interrupt`: backend can request workflow/fiber interruption.
- `can_durable_suspend`: backend can persist enough state for durable
  suspension and later resume.

Backend constructor expectations:

- deterministic: all new async flags are `false`;
- durable local: wake, timer scheduling, interrupt, and durable suspend are
  `true`; blocking-I/O interrupt remains `false`;
- async local: wake, timer scheduling, and interrupt are `true`; durable
  suspend remains `false`;
- clustered: all new async flags are `true`.

## Async Backend Trait Shape

Add `packages/zigeffect/src/runtime/async_backend.zig` with:

- `AsyncBackend`;
- `AsyncBackend.VTable`;
- `AsyncBackendError`;
- `BackendSuspendRequest`;
- `BackendWakeRequest`;
- `BackendTimerRequest`;
- `BackendInterruptRequest`;
- `UnsupportedAsyncBackendState`;
- `unsupportedAsyncBackend`.

The trait is synchronous Zig code for now, but models async operations:

- `suspend`: receive a `runtime.Suspension` and optional workflow/execution ids;
- `wake`: wake a suspension id with a reason;
- `scheduleTimer`: arrange a wake at a deterministic millisecond timestamp;
- `interrupt`: interrupt a target id with a reason.

The deterministic unsupported backend implements the vtable and returns
`error.UnsupportedBackendCapability` for every operation. This gives future
real backends a contract while keeping deterministic behavior explicit.

## Diagnostics

Add `packages/zigeffect/src/runtime/backend_diagnostics.zig` with:

- `BackendFeature`: `suspension`, `wake`, `timer`, `interrupt`,
  `durable_suspend`, `persistence`, `distribution`, `supervision`,
  `parallelism`.
- `BackendCapabilityRequirement`.
- `BackendCapabilityDiagnostic`.
- `backendSupportsFeature`.
- `requireBackendFeature`.
- `formatBackendCapabilityDiagnostic`.

Diagnostics must name:

- backend kind;
- missing feature;
- operation name;
- optional workflow name;
- short remediation hint.

Example text:

```text
backend capability unavailable: backend=deterministic operation=workflow.sleep feature=timer workflow=approval hint=use durableLocalBackend, asyncLocalBackend, or clusteredBackend
```

## Workflow Engine Requirements

`WorkflowEngine` gains:

- `backend: BackendCapabilities`;
- `initWithBackend`;
- `backendCapabilities`;
- `requireBackendFeature`;
- `formatBackendRequirementDiagnostic`.

`WorkflowEngineError` gains `UnsupportedBackendCapability`. The engine does not
infer workflow body behavior yet. Instead it exposes explicit requirement
checks that workflow modules and later scheduler milestones can call before
using sleep, signal wait, queue await, external wake, or interrupt behaviors.

This avoids pretending that workflow registration can statically inspect
arbitrary user workflow bodies. Later milestones can attach typed workflow
metadata to call these checks automatically.

## Tests

Add `packages/zigeffect/test/backend_conformance_test.zig` and import it from
`packages/zigeffect/test/all_test.zig`.

Conformance coverage:

- deterministic backend exposes all async operation-specific flags as false;
- durable local, async local, and clustered expose the expected async flags;
- unsupported deterministic async backend returns
  `UnsupportedBackendCapability` for suspend, wake, timer, and interrupt;
- diagnostics format backend kind, operation, feature, workflow, and hint;
- `WorkflowEngine.initWithBackend` stores backend capabilities;
- `WorkflowEngine.requireBackendFeature` succeeds for supported durable-local
  timer capability and fails with `UnsupportedBackendCapability` under the
  deterministic backend.

## Public Exports

Update `packages/zigeffect/src/zigeffect.zig`:

- add `runtime.async_backend` and `runtime.backend_diagnostics`;
- re-export async backend request, trait, unsupported backend, feature, and
  diagnostic helpers at the root facade.

Update `packages/zigeffect/docs/architecture.md` to describe backend
capability diagnostics and the async backend trait boundary.

## Acceptance

- Deterministic backend remains green.
- Unsupported async-only behavior fails with clear diagnostics.
- Workflow engine can expose and enforce backend requirements without changing
  workflow execution APIs.
- Async backend trait shape exists for suspend, wake, timer, and interrupt.
- `bun run zigeffect:test` passes.
- `cd packages/zigeffect && zig build examples` passes.
- `bun run zig:test` passes.
