# zigeffect-postgres

`zigeffect-postgres` is the local Postgres adapter package for
`zigeffect-std`. The standard library keeps the driver-neutral SQL contract in
`zstd.Sql`; this package provides both a local `psql` adapter and a native
PostgreSQL wire adapter backed by a pinned `pg.zig` revision.

```zig
const pg = @import("zigeffect_postgres");
const zstd = @import("zigeffect_std");
```

## Verify

From the repository root:

```sh
bun run zigeffect:postgres:test
```

The default package tests do not require a running database. They prove command
construction, JSON query wrapping, redacted receipts, migration planning,
native pool policy, sample CLI builds, and row conversion.

The native gate starts a disposable secure CockroachDB v26.2.3 container,
generates a private test CA, creates password users, runs the package tests
through `sslmode=verify-full`, and executes Ziac's database, grant, and migration
lifecycles:

```sh
bun run zigeffect:postgres:cockroach-live-test
```

It requires Docker and OpenSSL development libraries. The container and test
certificates are always removed on exit. Set `COCKROACH_TEST_IMAGE` to test a
different explicitly selected CockroachDB image.

## Native pool

`Native.Pool` owns a bounded `pg.Pool`, requires a PostgreSQL URI with exact
`sslmode=verify-full`, enables the driver's TCP keepalive defaults, validates
idle generations with `SELECT 1`, and rotates an idle pool generation after a
bounded jittered lifetime. A replacement generation connects before the old
generation is released.

Only SQLSTATE and outcome category cross the diagnostic boundary. Connection
URIs are retained only while a pool needs them for reconnect and are never
included in state or diagnostics. The owned URI and the driver's duplicated
reconnect password are securely zeroed when the generation is destroyed. The
driver runs through a zeroing allocator, so failed initialization, arena
teardown, connection buffers, and pool rotation scrub memory before release.

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
