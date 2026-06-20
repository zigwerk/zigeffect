# zigeffect-zio

Optional adapter that gives `zigeffect` real stackful-coroutine concurrency by
implementing the core `AsyncBackend` vtable on top of
[zio](https://github.com/lalinsky/zio) v0.14.0 (stackful coroutines + a full
`std.Io` implementation over io_uring / epoll / kqueue; the `main` branch targets
Zig 0.16).

The core `packages/zigeffect` stays **zio-free** and is the deterministic
reference; this package is the only place the zio dependency lives.

## Status — deep integration shipped (D1 + D2 productized)

What is real and verified here:

- The package builds (`zig build test`) and every test passes against real
  zio v0.14.0 (Zig 0.16). Verified across repeated forced re-runs (no timing
  flakiness in the interleaving proofs).
- **D1 — unified pluggable wait.** `AsyncBackend.blockingSleep` is implemented
  on zio via real `zio.sleep` (parks the coroutine on io_uring / epoll / kqueue).
  The SAME engine code (`SuspensionCoordinator.delay`) drives both
  deterministic and zio backends and produces **structurally equal causal
  traces** (proven via `causalStructurallyEquivalent`).
- **D2 — engine fibers as real coroutines.** Two engine fibers, each driven by
  `coordinator.delay`, run as real interleaving zio coroutines and yet remain
  structurally equal to the deterministic *sequential* run.
- **Productized executor.** `ZioFiberExecutor` is a `FiberExecutor` vtable
  backed by `zio.spawn` + `JoinHandle`. Attach it via
  `Runtime(Env).withExecutor` or `FiberRuntime.withExecutor`, and an ordinary
  `Effect.fork` spawns a real stackful coroutine transparently.
- **Z1 / Z2 / Z3 / Z3b** primitives verified — real timer suspension, real
  socket IO via `zio.net`, real cancellation via `zio.Group`, real coordination
  via `zio.Channel`.
- **Cancellation correctness.** A `delay` cancelled mid-wait records
  `fiber_interrupted` — never a fabricated `timer_fired` / `fiber_resumed`.

What is **not** done yet (tracked in
[Track 7](../../docs/superpowers/plans/2026-06-20-zigeffect-vision-completion-roadmap.md)):

- 6 of 9 `AsyncBackend` vtable methods still return
  `error.UnsupportedBackendCapability`: `suspend_runtime` / `wake` /
  `schedule_timer` / `interrupt` / `register_io_wait` / `complete_io`. The Z1/Z2/
  Z3 proofs work because the scenarios drive zio directly; the vtable seam
  itself isn't yet exercised end-to-end. Filling these is Track 7 of the
  vision-completion roadmap.

## Run it

```bash
cd packages/zigeffect-zio
zig build test         # full suite — Z1/Z2/Z3/Z3b + D1/D2 + cancellation regression
```

## Design and plan

- Design: [docs/superpowers/specs/2026-06-20-zigeffect-zio-backend-design.md](../../docs/superpowers/specs/2026-06-20-zigeffect-zio-backend-design.md)
- Delivery roadmap: [docs/superpowers/plans/2026-06-20-zigeffect-zio-async-delivery-roadmap.md](../../docs/superpowers/plans/2026-06-20-zigeffect-zio-async-delivery-roadmap.md)
- Engine roadmap: [packages/zigeffect/docs/roadmap.md](../zigeffect/docs/roadmap.md)

The deterministic suspension foundation this backend plugs into (the
`fiber_suspended`/`fiber_resumed`/`timer_scheduled`/`timer_fired` causal events
and the `SuspensionCoordinator`) is delivered and verified in the core package
(Stage 0).
