# zigeffect Workflow Journal Schema Migration Design

Date: 2026-06-09

## Purpose

Milestone 20 makes durable workflow histories explicit about reader
compatibility. The current journal rows already carry `schema` and
`schema_version`, but parsing treats every non-current version as the same
schema error. That is not enough for runtime upgrades, because a future journal
written by a newer runtime must not be mistaken for corruption and must not be
mutated by an older runtime.

## Design

Keep workflow event rows at schema version 1 for this milestone. Add a
version-aware reader layer around the existing v1 parser:

- parse a small row header first;
- classify the row as current, future-version, missing migration, invalid
  schema, or unknown event kind;
- route current v1 rows through an explicit migration registry;
- reject future versions with a named downgrade error before appending anything
  to the in-memory replay store;
- keep unknown event kinds as a policy decision, with durable replay defaulting
  to fail because skipping unknown rows would create sequence gaps and unsafe
  state.

The migration registry starts with an identity v1 migration. This is useful
even before v2 exists because call sites stop hard-coding direct v1 parsing and
tests can prove where a future v2 migration will attach.

## APIs

Add journal-level compatibility types:

```zig
pub const WorkflowEventCompatibility = enum {
    current,
    future_schema_version,
    missing_migration,
    invalid_schema,
    unknown_event_kind,
};

pub const WorkflowUnknownEventPolicy = enum {
    fail,
};

pub const WorkflowEventReadOptions = struct {
    unknown_event_policy: WorkflowUnknownEventPolicy = .fail,
};

pub const WorkflowEventMigrationRegistry = struct {
    pub fn current() WorkflowEventMigrationRegistry;
    pub fn migrateJsonToCurrent(self: WorkflowEventMigrationRegistry, allocator: Allocator, row_json: []const u8) ![]const u8;
};
```

`parseWorkflowEventJson` remains the ergonomic public reader, but it delegates
through `parseWorkflowEventJsonWithOptions` and the current registry. Current
version rows continue to return `WorkflowEvent`. Future rows return
`FutureWorkflowEventSchemaVersion`; version 0 rows return
`MissingWorkflowEventMigration`; unknown event kinds return
`UnknownWorkflowEventKind`.

## Store Behavior

`FileJournalStore.recover` distinguishes future-version rows from corrupt rows.
A future-version row returns `JournalRequiresNewerRuntime` and leaves the
journal file untouched. This is the downgrade/read-only failure mode: the older
runtime refuses to acquire a usable writable store for that journal, and callers
must upgrade the runtime before resuming.

Malformed JSON, invalid schemas, duplicate rows, and sequence conflicts remain
corruption paths with `JournalCorruptionReport` populated as before.

## Fixtures

Add `packages/zigeffect/test/fixtures/workflow-journal-v1-golden.jsonl`. It is
a stable v1 history with workflow start, activity scheduling/completion, and
workflow completion. Tests load it through the public parser and replay it to a
completed state. Tool tests also load it through the same fixture path used by
CLI tools.

## Acceptance

- Current v1 rows parse through the migration registry.
- Future event versions fail with a named newer-runtime error, not generic
  corruption.
- Version 0 rows fail with a missing-migration error.
- Unknown event kinds fail through the explicit unknown-event policy.
- A v1 golden fixture replays under the new reader.
- `FileJournalStore` refuses future-version histories without truncating or
  appending to the journal.
