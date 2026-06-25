# zigeffect-postgres

`zigeffect-postgres` is the local Postgres adapter package for
`zigeffect-std`. The standard library keeps the driver-neutral SQL contract in
`zstd.Sql`; this package provides a real local adapter path through the `psql`
executable.

```zig
const pg = @import("zigeffect_postgres");
const zstd = @import("zigeffect_std");
```

## Verify

From the repository root:

```sh
bun run zigeffect:postgres:test
```

The package tests do not require a running database. They prove command
construction, redacted receipts, and JSON row parsing. A real query requires a
working `psql` executable and a reachable connection URL.
