# zigeffect Backend Boundary Design

Date: 2026-06-05

## Goal

Deliver the first roadmap section 12 slice by making the runtime backend
boundary explicit. The current implementation remains deterministic and
run-to-completion; future zio/`std.Io` work can add real suspension behind the
same capability contract.

## Contracts

- `BackendKind.deterministic` is the only backend available today.
- `BackendCapabilities` names whether a backend can suspend, interrupt blocking
  IO, supervise fibers, and run parallel work.
- `deterministicBackend()` returns the current backend capabilities.
- `Runtime` and `FiberRuntime` expose their backend capabilities.
- No runtime behavior changes in this slice.

## Non-Goals

- No async scheduler.
- No event loop.
- No blocking IO cancellation.
- No parallel composition.

## Tests

- The deterministic backend reports all async capabilities as false.
- Regular and fiber runtimes expose deterministic backend capabilities by
  default.
