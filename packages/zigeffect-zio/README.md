# zigeffect-zio

Optional adapter that gives `zigeffect` real stackful-coroutine concurrency by
implementing the core `AsyncBackend` vtable on top of
[zio](https://github.com/lalinsky/zio) v0.14.0 (stackful coroutines + a full
`std.Io` implementation over io_uring / epoll / kqueue; the `main` branch targets
Zig 0.16).

The core `packages/zigeffect` stays **zio-free** and is the deterministic
reference; this package is the only place the zio dependency lives.

## Status — low-level integration shipped

The executor and async backend are real and tested, but their public attachment
point still belongs to the legacy environment-shaped runtime. Canonical
`kernel.ManagedRuntime` executor selection is a remaining migration boundary;
new application roots should not adopt `Runtime(Env)` merely to select zio.

What is real and verified here:

- The package builds (`zig build test`) and every test passes against real
  zio v0.14.0 (Zig 0.16). Verified across repeated forced re-runs (no timing
  flakiness in the interleaving proofs).
- **D1 — unified pluggable wait.** `AsyncBackend.blockingSleep` is implemented
  on zio via real `zio.sleep` (parks the coroutine on io_uring / epoll / kqueue).
  The SAME engine code (`SuspensionCoordinator.delay`) drives both
  deterministic and zio backends and produces **structurally equal causal
  traces** (same event kinds, cause and parent edge kinds, id-insensitive
  scope/resource/fiber ownership facts, finding-evidence owner states, and
  per-fiber terminal lifecycle states, proven via `causalStructurallyEquivalent`).
- **D2 — engine fibers as real coroutines.** Two engine fibers, each driven by
  `coordinator.delay`, run as real interleaving zio coroutines and yet remain
  structurally equal to the deterministic *sequential* run.
- **Compatibility executor adapter.** `ZioFiberExecutor` is a real
  `FiberExecutor` vtable backed by `zio.spawn` + `JoinHandle`. Existing engine
  modules attach it through `Runtime(Env).withExecutor` or
  `FiberRuntime.withExecutor`; canonical managed-runtime integration is still
  pending. On that compatibility path, `Effect.fork` spawns a real stackful
  coroutine transparently.
- **Z1 / Z2 / Z3 / Z3b** primitives verified — real timer suspension, real
  socket IO via `zio.net`, real cancellation via `zio.Group`, real coordination
  via `zio.Channel`.
- **AsyncBackend vtable filled.** `suspend_runtime` / `wake` / `schedule_timer` /
  `interrupt` / `register_io_wait` / `complete_io` / `poll_wake` are implemented
  as a registration + wake-queue backed by real zio timer coroutines where needed.
- **Workflow scheduler on zio.** The scheduler reconciles deterministic virtual
  time with zio's real-clock timer model via the `real_clock` capability and
  `pumpAsyncUntilIdle`.
- **Cancellation correctness.** A `delay` cancelled mid-wait records
  `fiber_interrupted` — never a fabricated `timer_fired` / `fiber_resumed`.

What is **not** done yet:

- Production cluster transports are still not remote deployment transports. The
  core package now has `LoopbackSocketClusterTransport`, which crosses localhost
  TCP once behind `ClusterTransport`; the zio adapter can build on that for
  long-lived remote sockets later.
- Browser rendering of a live stream has a captured proof in
  `docs/superpowers/specs/2026-06-24-zigeffect-live-debugging-browser-proof.md`;
  turning that browser proof into CI still needs an accepted browser/DOM test
  dependency.

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
