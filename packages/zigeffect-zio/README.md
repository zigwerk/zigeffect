# zigeffect-zio

Optional adapter that gives `zigeffect` real stackful-coroutine concurrency by
implementing the core `AsyncBackend` vtable on top of
[zio](https://github.com/lalinsky/zio) v0.14.0 (stackful coroutines + a full
`std.Io` implementation over io_uring / epoll / kqueue; the `main` branch targets
Zig 0.16).

The core `packages/zigeffect` stays **zio-free** and is the deterministic
reference; this package is the only place the zio dependency lives.

## Status — Stage 1 scaffold

What is real and verified here:

- The package builds (`zig build test`) and its conformance test passes.
- The boundary is wired: `src/zio_backend.zig` imports `zigeffect`, defines
  `ZioAsyncBackendState`, and produces a valid `AsyncBackend` via the 9-method
  vtable.
- The zio v0.14.0 dependency resolves (declared with its content hash in
  `build.zig.zon`, `lazy = true`).

What is **not** done yet (the Stage 1 implementation):

- Every vtable method currently returns `error.UnsupportedBackendCapability` —
  it is a registered-but-unimplemented backend that fails loudly rather than
  faking suspension. Each method's doc comment records the exact zio mapping:
  `fork → group.spawn`, scoped fiber → `zio.Group` lifetime,
  `interrupt → group.cancel`, `schedule_timer → zio timer`, IO wait → `std.Io`.

## Activate Stage 1

```bash
cd packages/zigeffect-zio
zig fetch --save "git+https://github.com/lalinsky/zio#v0.14.0"   # refresh the hash if needed
# enable the zio import in build.zig (the commented lazyDependency block)
# implement suspend_runtime / wake / schedule_timer against zio, starting with
# the timer primitive, then verify causal-trace equivalence vs the deterministic
# LocalAsyncBackendState (same program -> same structural causal trace).
```

## Design and plan

- Design: [docs/superpowers/specs/2026-06-20-zigeffect-zio-backend-design.md](../../docs/superpowers/specs/2026-06-20-zigeffect-zio-backend-design.md)
- Delivery roadmap: [docs/superpowers/plans/2026-06-20-zigeffect-zio-async-delivery-roadmap.md](../../docs/superpowers/plans/2026-06-20-zigeffect-zio-async-delivery-roadmap.md)
- Engine roadmap: [packages/zigeffect/docs/roadmap.md](../zigeffect/docs/roadmap.md)

The deterministic suspension foundation this backend plugs into (the
`fiber_suspended`/`fiber_resumed`/`timer_scheduled`/`timer_fired` causal events
and the `SuspensionCoordinator`) is delivered and verified in the core package
(Stage 0).
