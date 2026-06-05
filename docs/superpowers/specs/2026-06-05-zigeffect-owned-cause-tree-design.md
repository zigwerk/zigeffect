# zigeffect Owned Cause Tree Design

Date: 2026-06-05

## Goal

Add an allocator-owned recursive cause representation without breaking the
existing by-value `Exit` API.

## Context

`Cause(Failure)` currently supports recursive `sequential`, `parallel`, and
`annotated` variants through `*const Self` child pointers. That is fine for
literal test fixtures, but it cannot safely represent runtime-generated nested
causes when the base cause is itself a `.cause` and cleanup also fails: a helper
cannot return pointers to stack-local child causes.

`Exit` is intentionally lightweight and returned by value from runtime, fiber,
layer, and test APIs. Changing `Exit.cause` to hold heap-owned nodes would force
every `exit()` caller to manage cleanup. This slice avoids that API break.

## Design

Add `CauseTree(Failure)` in `packages/zigeffect/src/core/result.zig`. It owns
allocated cause nodes through an allocator and exposes explicit `deinit`.

The tree has node variants for failure, defect, interruption, finalizer
failure, sequential, parallel, and annotation. Builders return node pointers
owned by the tree:

- `failure(err)`
- `defect(message)`
- `interrupted(fiber_id)`
- `finalizerFailure(name)`
- `sequential(left, right)`
- `parallel(left, right)`
- `annotated(cause, annotation)`
- `copyFromCause(cause)`

The tree also exposes `hasFinalizerFailure`, `hasDefect`, `hasInterruption`,
and `format(label)` so tests and tooling do not need to know whether they are
inspecting pointer-backed `Cause` fixtures or owned cause trees.

Add `causeTreeWithFinalizerFailure(allocator, Success, Failure, exit, name)`.
It builds an owned tree from an `Exit` plus a finalizer failure. If the base
exit is already `.cause`, the helper preserves the nested base cause and appends
the finalizer failure as a sequential node.

## Non-Goals

- Do not change the shape or ownership semantics of `Exit` in this slice.
- Do not remove existing flat cleanup-combination variants from `Cause`.
- Do not introduce async runtime behavior or scheduler changes.

## Tests

Add tests in `packages/zigeffect/test/effect_test.zig`:

- owned trees preserve nested cause data through helper assertions
- owned trees format sequential cause reports
- `causeTreeWithFinalizerFailure` preserves an existing nested cause when a
  finalizer failure is appended

Run `bun run zigeffect:test`, `bun run zig:test`, and `bun run typecheck`.
