# zgroach

`zgroach` is the separate Zig RoachGraph compiler/toolchain package.

It depends on `zigeffect`, but `zigeffect` stays generic and RoachGraph-free.
The current package is only a compiler scaffold. The active production
RoachGraph implementation remains the TypeScript package at `packages/roachgraph`.

Current surface:

- `validateSource(ctx, source)`: validates non-empty source and records
  telemetry through `zigeffect` services.
- `validateCurrentSource()`: returns a `zigeffect.Effect` that reads
  `schema.path` from config, reads the source from the memory filesystem, and
  validates it.

Run tests:

```bash
bun run zgroach:test
```
