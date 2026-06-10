# zigeffect Storage Adapter Hardening Design

Date: 2026-06-10

Milestone: 41 - Storage Adapter Hardening

Roadmap: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

## Goal

Make workflow and cluster storage adapters prove the same behavioral contract
before they are trusted by durable workflows, sharding, queues, timers, or
future deployment adapters.

## Context

`JournalStore`, `RunnerStorage`, and `MessageStorage` already expose vtable
contracts. Each has in-memory and file-backed implementations, and each file
format carries schema metadata. Current tests cover concrete stores directly,
but the behavior is repeated across individual test files instead of living in
shared conformance suites.

The repo also has a useful pattern in
`test/support/causal_backend_conformance.zig`: a reusable test support module
generates standard traces and assertions, and one test file applies those
assertions to concrete implementations. M41 should apply that pattern to the
storage layer.

No production PostgreSQL or CockroachDB Zig driver is selected in this package.
`packages/zgroach` is currently an Effect-backed compiler scaffold, not a
database connection runtime. The SQL deliverable should therefore define the
adapter-facing schema and migration contract in Zig, plus deterministic local
commands that emit and check schema plans, without opening a network
connection.

## Approaches Considered

### Preferred: Shared Harnesses Plus Schema Catalog

Add focused conformance helpers under `packages/zigeffect/test/support/`, then
drive memory and file stores through those helpers from a single
`storage_conformance_test.zig`. Add a `src/storage/` namespace for schema
descriptors, SQL-shaped migration plans, and a local `storage-migrate` tool.

This gives immediate value to existing adapters and creates a contract for a
later live SQL adapter without binding the package to an immature driver.

### Alternative: Expand Existing Concrete Tests

Keep adding cases to `workflow_test.zig`, `runner_storage_test.zig`, and
`message_storage_test.zig`. This is small at first, but it keeps behavior
duplicated and makes it easy for future adapters to miss required cases.

### Alternative: Build Live SQL First

Start with a Cockroach/PostgreSQL adapter and let conformance emerge from it.
This creates the riskiest dependency path because the repo does not yet have a
selected Zig database driver, transaction API, or connection lifecycle contract.

## Scope

In scope:

- Shared conformance helpers for `JournalStore`, `RunnerStorage`, and
  `MessageStorage`.
- In-memory and file-backed conformance tests using the same helper functions.
- A storage namespace with schema descriptors for workflow journal, workflow
  checkpoint, workflow snapshot commit, runner lease, cluster message record,
  and cluster message reply records.
- SQL-shaped schema and migration plan structs for PostgreSQL-compatible and
  Cockroach-compatible storage.
- A local storage migration command that prints schema catalog and plan output
  for deterministic review.
- Public facade exports for schema catalog and migration plan APIs.
- Architecture and roadmap updates.

Out of scope:

- Opening database sockets or executing SQL against CockroachDB/PostgreSQL.
- Replacing current file stores.
- Changing existing vtable method names or storage semantics.
- Adding generated property or crash tests; those belong to M42.

## Design

### Conformance Helpers

Create:

- `packages/zigeffect/test/support/journal_store_conformance.zig`
- `packages/zigeffect/test/support/runner_storage_conformance.zig`
- `packages/zigeffect/test/support/message_storage_conformance.zig`

Each helper exposes named assertion functions that accept the public vtable
contract. The helpers own only deterministic test data and assertions; concrete
store setup stays in `storage_conformance_test.zig`.

Journal store conformance covers:

- appending sequential workflow events
- expected-next-sequence conflicts
- idempotency key duplicate rejection
- `readAll` ordering
- `readFromSequence` filtering
- `latestState` replay posture
- `reset` clearing retained events

Runner storage conformance covers:

- lease acquisition and listing
- active lease conflict rejection
- expired lease replacement
- owner-checked refresh and release
- expired refresh rejection
- `releaseAll` owner filtering
- `reset` clearing leases

Message storage conformance covers:

- idempotent submit
- unprocessed lookup by shard and id
- claim attempt increments
- ack removes messages from unprocessed queries
- reply storage and duplicate reply rejection
- reply lookup after storage
- `reset` clearing messages and replies

### File-Backed Participation

`storage_conformance_test.zig` runs the same conformance helpers against:

- `InMemoryJournalStore`
- `FileJournalStore`
- `InMemoryRunnerStorage`
- `FileRunnerStorage`
- `InMemoryMessageStorage`
- `FileMessageStorage`

File-backed tests use `std.testing.tmpDir` and open a fresh store per test.
Persistence-specific tests still belong in the existing concrete test files,
but M41 adds at least one reopen scenario per file-backed store through the
conformance test file to prove the shared contract survives a new store handle.

### Storage Namespace

Create `packages/zigeffect/src/storage/root.zig` and
`packages/zigeffect/src/storage/schema.zig`.

The namespace defines:

- `StorageAdapterKind`: `journal`, `runner`, `message`
- `StorageRecordKind`: concrete record family names
- `StorageSchemaDescriptor`: adapter kind, record kind, schema string,
  version, and description
- `StorageSchemaCatalog`: a static slice plus helper lookup functions
- `StorageSchemaCompatibility`: `current`, `older`, `newer`, `unknown`
- `StorageSchemaCompatibilityReport`: schema string, expected version, found
  version, and compatibility status
- `storageSchemaCatalog()`
- `findStorageSchema(schema: []const u8)`
- `classifyStorageSchema(schema: []const u8, version: u32)`
- `formatStorageSchemaCatalogText`
- `formatStorageSchemaCatalogJson`

The catalog references existing constants instead of duplicating string
literals.

### SQL-Shaped Contract

Create `packages/zigeffect/src/storage/sql.zig`.

The SQL surface is a pure contract:

- `SqlStorageDialect`: `postgresql`, `cockroachdb`
- `SqlStorageStatementKind`: `create_schema`, `create_table`, `create_index`
- `SqlStorageStatement`: name, dialect, adapter kind, statement kind, SQL text
- `SqlStorageMigrationPlan`: schema descriptors and ordered statements
- `sqlStorageMigrationPlan(dialect: SqlStorageDialect)`
- `formatSqlStorageMigrationPlanText`
- `formatSqlStorageMigrationPlanJson`

The SQL emitted in M41 is a conservative schema plan for durable storage tables:

- `zigeffect_workflow_journal_events`
- `zigeffect_workflow_checkpoints`
- `zigeffect_workflow_snapshot_commits`
- `zigeffect_cluster_runner_leases`
- `zigeffect_cluster_messages`
- `zigeffect_cluster_replies`

The plan uses JSON payload columns and explicit schema/schema-version columns.
This matches current file-backed formats and gives a future adapter a stable
starting contract without prematurely designing a full query builder.

### Migration Command

Create `packages/zigeffect/tools/storage_migrate.zig`.

The command supports:

- `schemas [--format text|json]`
- `plan [--dialect postgresql|cockroachdb] [--format text|json]`

`schemas` prints the storage schema catalog. `plan` prints the SQL-shaped
migration plan. The command exits with a usage message for unknown commands or
bad flags.

Add a build step:

```text
zig build storage-migrate -- schemas
zig build storage-migrate -- plan --dialect cockroachdb
```

### Public API

Expose a new top-level namespace:

- `fx.storage`

Expose top-level aliases for:

- `StorageAdapterKind`
- `StorageRecordKind`
- `StorageSchemaDescriptor`
- `StorageSchemaCatalog`
- `StorageSchemaCompatibility`
- `StorageSchemaCompatibilityReport`
- `storageSchemaCatalog`
- `findStorageSchema`
- `classifyStorageSchema`
- `formatStorageSchemaCatalogText`
- `formatStorageSchemaCatalogJson`
- `SqlStorageDialect`
- `SqlStorageStatementKind`
- `SqlStorageStatement`
- `SqlStorageMigrationPlan`
- `sqlStorageMigrationPlan`
- `formatSqlStorageMigrationPlanText`
- `formatSqlStorageMigrationPlanJson`

### Error Handling

Conformance helpers should assert public contract behavior through existing
errors. They should not depend on concrete implementation internals.

Schema lookup returns `null` for unknown schemas. SQL dialect parsing returns a
specific error for unknown dialects. Formatting functions allocate owned output
and leave freeing to callers.

The storage migration command returns usage text instead of panicking on invalid
input. Build-step execution should produce deterministic text suitable for
tests and agent review.

## Testing

Add:

- `packages/zigeffect/test/storage_conformance_test.zig`
- three support files under `packages/zigeffect/test/support/`
- focused storage schema and SQL plan tests in `storage_conformance_test.zig`
- tool tests in `tools/storage_migrate.zig`

Coverage:

- Memory and file-backed stores pass the same journal conformance functions.
- Memory and file-backed stores pass the same runner conformance functions.
- Memory and file-backed stores pass the same message conformance functions.
- File-backed stores prove at least one reopen path in the conformance file.
- Schema catalog includes all current durable record schemas.
- SQL migration plan includes workflow, runner, message, reply, checkpoint, and
  snapshot commit tables.
- `storage-migrate` text and JSON output include schema ids and SQL plan names.

## Acceptance

M41 is complete when:

- `zig build storage-conformance` passes.
- `bun run zigeffect:test` passes with the conformance test imported into
  `all_test.zig`.
- `zig build storage-migrate -- schemas` and
  `zig build storage-migrate -- plan --dialect cockroachdb` succeed.
- Roadmap M41 deliverables and acceptance are checked.
- Full milestone gate passes.
