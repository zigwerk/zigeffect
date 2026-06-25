# zigeffect-std

`zigeffect-std` is the one-import standard library facade for zigeffect
applications. It depends on `packages/zigeffect` and keeps application-facing
tooling outside the pure engine package.

```zig
const zstd = @import("zigeffect_std");
```

## Verify

```sh
cd packages/zigeffect-std
zig build test
zig build examples
```

From the repository root:

```sh
bun run zigeffect:std:test
```

## Modules

- `Cli` parses deterministic command specs and emits command run receipts.
- `Console` provides a captured console service for testable command output.
- `Env` provides an owned environment map for deterministic local runs.
- `FileSystem` provides an in-memory file system for tests and local tools.
- `fx` re-exports the base zigeffect engine facade.

## Example

The first example is intentionally small: it proves the one-import facade can
parse a command and write output through a testable service.

```sh
cd packages/zigeffect-std
zig build examples
```
