# zigeffect Runtime Shared Scope Design

## Goal

Add an explicit long-lived runtime scope for applications that want resources to
outlive a single `Runtime.run` call.

## Chosen Approach

Add `Runtime.withScope(scope)` as an opt-in shared-scope mode. The default
runtime behavior stays unchanged: `Runtime.run` creates and closes a fresh
per-run scope. A runtime configured with `withScope` runs effects against the
provided scope and leaves cleanup to the caller.

This keeps graph startup scopes, per-run scopes, and application scopes distinct
while reusing the same `Scope` and `Context` machinery.

## Contract

- `Runtime.run` without `withScope` keeps closing resources at the end of each
  run.
- `Runtime.withScope(&scope).run(effect)` registers effect resources into the
  supplied scope and does not close it.
- The caller closes the shared scope when the application lifecycle ends.
- `Runtime.exit` also respects `withScope`; it returns the program exit but does
  not include finalizer failures until the caller closes the shared scope.
- Registering a finalizer through a context whose scope is already closed
  returns `error.MissingScope`. Resource helpers then release immediately through
  their existing error path.

## Implementation Shape

- Add `shared_scope: ?*Scope` to `Runtime`.
- Add `withScope(self, scope: *Scope) Self`.
- Route `run` and `exit` through the shared scope when configured.
- Guard `Context.addFinalizer*` methods against closed scopes.

## Tests

- A resource acquired through a shared runtime scope stays open after `run` and
  releases when the caller closes the shared scope.
- Default `Runtime.run` still closes resources per run.
- A resource run against an already-closed shared scope returns
  `error.MissingScope` and releases immediately.
