# zigeffect Resource Model Expansion Design

Date: 2026-06-05

## Goal

Deliver a focused slice of roadmap section 5 without changing existing pointer
resource semantics. The slice adds value-resource acquisition where safe, proves
nested cleanup ordering, and preserves both program failure and cleanup failure
in runtime exits.

## Contracts

- `acquireRelease` remains the pointer-resource helper. It returns `*Resource`
  and registers a typed finalizer against the active scope.
- `acquireReleaseValue` is for small handle-like values where copying the value
  into a finalizer box is acceptable. It returns `Resource` and registers a
  finalizer that releases the boxed copy when the scope closes.
- If finalizer registration fails, value resources are released immediately,
  matching the pointer-resource no-leak contract.
- Nested resources close in reverse acquisition order because they share the
  same `Scope` finalizer stack.
- Runtime exits preserve program failure plus cleanup failure through a direct,
  non-pointer cause variant. This avoids creating stack-local recursive cause
  links before the owned cause model is implemented.

## Non-Goals

- No long-lived application runtime scope helper yet.
- No owned recursive `Cause` tree yet; that remains roadmap section 6.
- No fallible value finalizer helper yet. Fallible cleanup remains available
  through direct `Scope` APIs.

## Tests

- Value resource is acquired, usable inside the run, and released by runtime
  cleanup.
- Value resource releases immediately if no active scope exists.
- Nested value resources release in reverse order.
- `Runtime.exit` reports `failure_then_finalizer_failure` when both the program
  and cleanup fail.
