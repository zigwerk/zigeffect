# zigeffect Resource Ownership Docs Design

## Goal

Document where resources should be acquired and released across graph startup,
per-run scopes, shared runtime scopes, and fiber scopes.

## Design

Add `packages/zigeffect/docs/resource-ownership.md` as a focused ownership
guide. Keep the guide operational: which scope owns the resource, when it
closes, what API to use, and which tests/docs to inspect.

Update existing docs to link the guide rather than duplicating long ownership
rules.

## Contract

- Graph startup resources live until `graph.deinit()`.
- Per-run resources live until `Runtime.run`, `Layer.provide`, or `graph.run`
  returns.
- Shared runtime resources live until the caller closes the supplied scope.
- Fiber resources live in child scopes and close on success, failure, or
  interruption.

## Verification

Docs-only change, followed by the normal test/typecheck gate.
