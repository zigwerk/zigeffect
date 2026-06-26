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
construction, JSON query wrapping, redacted receipts, migration planning, sample
CLI builds, and JSON row parsing. A real query requires a working `psql`
executable and a reachable connection URL.

## Local migrations

Projects supply their own migration slice and call the CLI helper:

```zig
const pg = @import("zigeffect_postgres");

const migrations = [_]pg.Sql.Migration{
    .{ .id = "001_init", .sql = "create table if not exists projects(id bigint primary key)" },
};

const output = try pg.runMigrationCliAlloc(allocator, argv, migrations[0..], &.{});
```

Supported local commands:

- `plan --url <DATABASE_URL> --table <table>` emits a redacted JSON receipt.
- `apply-sql --url <DATABASE_URL> --table <table>` emits executable SQL that
  creates the migration table, wraps pending migrations in a transaction, and
  records applied migration IDs.

The copyable example lives at `examples/migrate.zig` and is built by
`bun run zigeffect:postgres:test`.
