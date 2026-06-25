# zigeffect-std SQL and Postgres Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `zstd.Sql` an effect-native SQL contract and add a real local `zigeffect-postgres` adapter package that can execute through `psql`.

**Architecture:** `packages/zigeffect-std/src/sql/root.zig` remains driver-neutral: values, rows, owned query results, fake database, query effects, transaction facts, migrations, and a small pool contract. `packages/zigeffect-postgres` imports `zigeffect_std` and implements a local adapter that formats safe `psql` invocations, parses JSON output, and never exposes connection strings in receipts. This milestone does not embed a wire-protocol Postgres client in std; it provides a real local adapter path using the standard `psql` executable and keeps driver replacement possible.

**Tech Stack:** Zig, zigeffect `Effect`/`Runtime`/`Context`, `zstd.Service`, `zstd.Secrets`, `std.process.run`, `std.json`, Bun-driven Zig test scripts.

---

### Task 1: Effect-Native SQL Contract

**Files:**
- Modify: `packages/zigeffect-std/src/sql/root.zig`

- [ ] **Step 1: Write the failing test**

Add a test proving SQL queries run through service effects and emit redacted causal facts:

```zig
test "Sql queryEffect uses database services and records redacted causal facts" {
    const zstd = @import("../root.zig");

    const fields = [_]Field{
        .{ .name = "id", .value = .{ .integer = 42 } },
    };
    const rows = [_]Row{.{ .fields = fields[0..] }};
    var database = try FakeDatabase.initOwned(std.testing.allocator, .{ .rows = rows[0..] });
    defer database.deinit();

    var provider = zstd.Service.Provider(.{FakeDatabase}).init(.{&database});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{FakeDatabase})
        .withCausalStore(&store);

    var result = try runtime.run(queryEffect(@TypeOf(provider), FakeDatabase, .{
        .sql = "select * from projects where token = $1",
        .binds = &.{.{ .text = "token=abc123" }},
    }));
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), result.rows.len);
    try std.testing.expectEqual(@as(i64, 42), result.rows[0].fields[0].value.integer);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    const event_index = zstd.Service.findOperation(snapshot, FakeDatabase, "sql.query", "success");
    try std.testing.expect(event_index != null);
    try std.testing.expect(std.mem.indexOf(u8, snapshot.events[event_index.?].redacted_detail, "abc123") == null);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun run zigeffect:std:test`

Expected: FAIL because `initOwned`, owned result deinit, `Statement`, and `queryEffect` are missing.

- [ ] **Step 3: Implement contract**

Implement:

- `Value.cloneAlloc` and `Value.deinit`.
- `Field`, `Row`, and `QueryResult` clone/deinit helpers.
- `Statement { sql, binds }`.
- `FakeDatabase.initOwned`, `deinit`, `queryAlloc`.
- `QueryEffect(Env, Database)` and `queryEffect`.
- redacted query diagnostics that include SQL and bind count, never raw secret-shaped bind values.

- [ ] **Step 4: Run test to verify it passes**

Run: `bun run zigeffect:std:test`

Expected: PASS.

### Task 2: Transactions, Migrations, Pool Contract

**Files:**
- Modify: `packages/zigeffect-std/src/sql/root.zig`

- [ ] **Step 1: Write the failing test**

Add a test covering transaction and migration effects:

```zig
test "Sql transactions migrations and pool service record lifecycle facts" {
    const zstd = @import("../root.zig");

    var database = try FakeDatabase.initOwned(std.testing.allocator, .{ .rows = &.{} });
    defer database.deinit();
    var pool = Pool(FakeDatabase).init(&database, 2);

    var provider = zstd.Service.Provider(.{Pool(FakeDatabase)}).init(.{&pool});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{Pool(FakeDatabase)})
        .withCausalStore(&store);

    const checkout = try runtime.run(checkoutEffect(@TypeOf(provider), FakeDatabase));
    try std.testing.expect(checkout == &database);
    try runtime.run(releaseEffect(@TypeOf(provider), FakeDatabase));
    try runtime.run(beginEffect(@TypeOf(provider), FakeDatabase));
    try runtime.run(commitEffect(@TypeOf(provider), FakeDatabase));

    const migrations = [_]Migration{
        .{ .id = "001", .sql = "create table projects(id int)" },
    };
    try runtime.run(migrateEffect(@TypeOf(provider), FakeDatabase, migrations[0..]));

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(zstd.Service.hasOperation(snapshot, Pool(FakeDatabase), "sql.checkout", "success"));
    try std.testing.expect(zstd.Service.hasOperation(snapshot, Pool(FakeDatabase), "sql.release", "success"));
    try std.testing.expect(zstd.Service.hasOperation(snapshot, Pool(FakeDatabase), "sql.begin", "success"));
    try std.testing.expect(zstd.Service.hasOperation(snapshot, Pool(FakeDatabase), "sql.commit", "success"));
    try std.testing.expect(zstd.Service.hasOperation(snapshot, Pool(FakeDatabase), "sql.migrate", "success"));
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun run zigeffect:std:test`

Expected: FAIL because pool, transaction, and migration APIs are missing.

- [ ] **Step 3: Implement lifecycle contracts**

Implement:

- `Pool(Database)` with capacity, checked-out count, checkout/release.
- transaction state on `FakeDatabase`: begin/commit/rollback.
- `Migration { id, sql }`.
- `migrateAlloc` on fake database storing applied migration ids.
- `checkoutEffect`, `releaseEffect`, `beginEffect`, `commitEffect`, `rollbackEffect`, and `migrateEffect`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bun run zigeffect:std:test`

Expected: PASS.

### Task 3: zigeffect-postgres Package

**Files:**
- Create: `packages/zigeffect-postgres/build.zig.zon`
- Create: `packages/zigeffect-postgres/build.zig`
- Create: `packages/zigeffect-postgres/README.md`
- Create: `packages/zigeffect-postgres/src/root.zig`
- Modify: `package.json`

- [ ] **Step 1: Write the failing package test**

Add `packages/zigeffect-postgres/src/root.zig` tests expecting:

```zig
test "Postgres adapter redacts connections and builds psql argv" {
    const config = ConnectionConfig{
        .url = "postgres://user:pass@localhost/db",
        .psql_path = "psql",
    };
    const argv = try buildPsqlArgv(std.testing.allocator, config, "select 1");
    defer freeArgv(std.testing.allocator, argv);

    try std.testing.expectEqualStrings("psql", argv[0]);
    try std.testing.expectEqualStrings("postgres://user:pass@localhost/db", argv[1]);
    try std.testing.expectEqualStrings("-X", argv[2]);
    try std.testing.expectEqualStrings("-A", argv[3]);
    try std.testing.expectEqualStrings("-t", argv[4]);
    try std.testing.expectEqualStrings("-c", argv[5]);
    try std.testing.expectEqualStrings("select 1", argv[6]);

    const receipt = try queryReceiptAlloc(std.testing.allocator, config, "select token=abc123");
    defer std.testing.allocator.free(receipt);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "pass@localhost") == null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "abc123") == null);
}
```

Add a second test for parsing `psql` JSON output into `zstd.Sql.QueryResult`.

- [ ] **Step 2: Run test to verify it fails**

Run: `bun run zigeffect:postgres:test`

Expected: FAIL because the package and script do not exist.

- [ ] **Step 3: Implement package**

Implement:

- Zig package metadata depending on `../zigeffect-std`.
- `ConnectionConfig { url, psql_path }`.
- `buildPsqlArgv`, `freeArgv`, `queryReceiptAlloc`.
- `PsqlClient` using `std.process.run` to execute `psql`.
- `parseJsonRowsAlloc` for JSON array output.
- tests that do not require a live database but prove command construction, redaction, and row parsing.

- [ ] **Step 4: Add script and run test**

Add to root `package.json`:

```json
"zigeffect:postgres:test": "cd packages/zigeffect-postgres && zig build test"
```

Run: `bun run zigeffect:postgres:test`

Expected: PASS.

### Task 4: Docs, Verification, Commit

**Files:**
- Modify: `packages/zigeffect-std/README.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-25-zigeffect-std-effectts-grade-roadmap-design.md`

- [ ] **Step 1: Update docs**

Document M9 as delivered: std SQL contracts, fake database, transactions, migrations, pool contract, and local Postgres adapter package.

- [ ] **Step 2: Run full gate**

Run:

```bash
bun run zigeffect:std:test
bun run zigeffect:postgres:test
bun run zigeffect:local-agent-gate
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 3: Commit**

Run:

```bash
git add package.json \
  docs/superpowers/plans/2026-06-25-zigeffect-std-sql-postgres.md \
  docs/superpowers/specs/2026-06-25-zigeffect-std-effectts-grade-roadmap-design.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect-std/README.md \
  packages/zigeffect-std/src/sql/root.zig \
  packages/zigeffect-postgres
git commit -m "Add zigeffect std SQL and Postgres adapter"
```

Expected: commit succeeds after the verification gate.
