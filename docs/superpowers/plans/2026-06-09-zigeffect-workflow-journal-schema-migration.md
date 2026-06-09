# zigeffect Workflow Journal Schema Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add workflow journal schema compatibility classification, migration registry plumbing, downgrade-safe file-store recovery, and v1 golden replay fixtures.

**Architecture:** Keep v1 as the current durable row format and insert a small version-aware reader layer in `workflow/journal.zig`. `workflow/store.zig` consumes the new errors to distinguish future-version downgrade failures from corrupt journals. Tests use both inline JSON rows and a named v1 golden fixture so future migrations have a stable regression anchor.

**Tech Stack:** Zig 0.16, existing workflow journal/replay/store modules, `bun:test` command wrappers, `zig build` package gates.

---

## File Structure

- Modify `packages/zigeffect/src/workflow/journal.zig`
  - Add compatibility classification, unknown-event policy, migration registry,
    and version-aware parser entry points.
- Modify `packages/zigeffect/src/workflow/store.zig`
  - Add `JournalRequiresNewerRuntime` downgrade failure during file recovery.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Export the new journal compatibility and migration APIs.
- Modify `packages/zigeffect/test/workflow_test.zig`
  - Add parser compatibility, registry, file-store downgrade, and golden replay
    tests.
- Modify `packages/zigeffect/tools/workflow_tool_support.zig`
  - Add fixture-loader coverage for the v1 golden fixture through CLI support.
- Add `packages/zigeffect/test/fixtures/workflow-journal-v1-golden.jsonl`
  - Stable v1 JSONL history for upgrade compatibility checks.
- Modify `packages/zigeffect/docs/architecture.md`
  - Document the version-aware journal reader and file-store downgrade behavior.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Mark Milestone 20 complete after verification.

## Task 1: Journal Header Classification And Registry

**Files:**
- Modify `packages/zigeffect/src/workflow/journal.zig`
- Modify `packages/zigeffect/src/workflow/root.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing compatibility tests**

Add tests named:

- `workflow journal classifies schema headers before full parse`
- `workflow journal migration registry parses current v1 rows`

The tests should build JSON rows from `formatWorkflowEventJson`, then mutate
`schema_version` to `2`, `0`, and mutate `kind` to `future_event`. Assert:

```zig
try std.testing.expectEqual(fx.workflow.WorkflowEventCompatibility.current, try fx.workflow.classifyWorkflowEventJson(current_json));
try std.testing.expectEqual(fx.workflow.WorkflowEventCompatibility.future_schema_version, try fx.workflow.classifyWorkflowEventJson(future_json));
try std.testing.expectEqual(fx.workflow.WorkflowEventCompatibility.missing_migration, try fx.workflow.classifyWorkflowEventJson(version_zero_json));
try std.testing.expectEqual(fx.workflow.WorkflowEventCompatibility.unknown_event_kind, try fx.workflow.classifyWorkflowEventJson(unknown_kind_json));

var parsed = try fx.workflow.parseWorkflowEventJsonWithOptions(std.testing.allocator, current_json, .{});
defer fx.workflow.deinitWorkflowEventStrings(std.testing.allocator, parsed);
try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_started, parsed.kind);
try std.testing.expectError(error.FutureWorkflowEventSchemaVersion, fx.workflow.parseWorkflowEventJson(std.testing.allocator, future_json));
try std.testing.expectError(error.MissingWorkflowEventMigration, fx.workflow.parseWorkflowEventJson(std.testing.allocator, version_zero_json));
try std.testing.expectError(error.UnknownWorkflowEventKind, fx.workflow.parseWorkflowEventJson(std.testing.allocator, unknown_kind_json));
```

- [x] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL because the compatibility API and parser options are missing.

- [x] **Step 3: Implement compatibility reader**

Add to `journal.zig`:

```zig
pub const WorkflowEventCompatibility = enum {
    current,
    future_schema_version,
    missing_migration,
    invalid_schema,
    unknown_event_kind,
};

pub const WorkflowUnknownEventPolicy = enum { fail };
pub const WorkflowEventReadOptions = struct {
    unknown_event_policy: WorkflowUnknownEventPolicy = .fail,
};

pub const WorkflowEventMigrationRegistry = struct {
    pub fn current() WorkflowEventMigrationRegistry { return .{}; }
    pub fn migrateJsonToCurrent(_: WorkflowEventMigrationRegistry, allocator: Allocator, row_json: []const u8) ![]const u8 {
        const compatibility = try classifyWorkflowEventJson(row_json);
        return switch (compatibility) {
            .current => allocator.dupe(u8, row_json),
            .future_schema_version => error.FutureWorkflowEventSchemaVersion,
            .missing_migration => error.MissingWorkflowEventMigration,
            .invalid_schema => error.InvalidWorkflowEventSchema,
            .unknown_event_kind => error.UnknownWorkflowEventKind,
        };
    }
};
```

Then split the existing body of `parseWorkflowEventJson` into a private
`parseWorkflowEventJsonV1` helper. Implement
`classifyWorkflowEventJson`, `parseWorkflowEventJsonWithOptions`, and make
`parseWorkflowEventJson` delegate to `parseWorkflowEventJsonWithOptions`.

Export the new types and functions in `workflow/root.zig`.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: File Store Downgrade Failure Mode

**Files:**
- Modify `packages/zigeffect/src/workflow/store.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing file-store test**

Add `file journal refuses future schema versions without truncating`. Create a
temporary directory, write `workflow-0000000000000001.jsonl` with a complete
future-version row and trailing newline, then call:

```zig
try std.testing.expectError(
    error.JournalRequiresNewerRuntime,
    fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{}),
);
```

Read the file back and assert it still contains `"schema_version":2`.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL because future-version rows currently surface as corrupt journal
errors.

- [ ] **Step 3: Implement downgrade-safe recovery**

Add `JournalRequiresNewerRuntime` to `FileJournalStoreError`. In
`FileJournalStore.recover`, catch `error.FutureWorkflowEventSchemaVersion`
separately and return `error.JournalRequiresNewerRuntime` without calling
`recordCorruption` or truncating the file. Keep malformed JSON, invalid schema,
unknown kind, sequence conflict, and duplicate event on the existing corruption
path.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 3: V1 Golden Fixture Replay

**Files:**
- Add `packages/zigeffect/test/fixtures/workflow-journal-v1-golden.jsonl`
- Modify `packages/zigeffect/test/workflow_test.zig`
- Modify `packages/zigeffect/tools/workflow_tool_support.zig`

- [ ] **Step 1: Add failing golden fixture tests**

Create the fixture with three rows:

```jsonl
{"schema":"zigeffect.workflow.journal-event.v1","schema_version":1,"sequence":1,"kind":"workflow_started","workflow_id":11,"execution_id":12,"parent_sequence":null,"activity_id":null,"timer_id":null,"deferred_id":null,"queue_id":null,"compensation_id":null,"attempt":0,"name":"v1-golden","status":"running","redacted_detail":"","idempotency_key":"v1-golden-start"}
{"schema":"zigeffect.workflow.journal-event.v1","schema_version":1,"sequence":2,"kind":"activity_completed","workflow_id":11,"execution_id":12,"parent_sequence":1,"activity_id":21,"timer_id":null,"deferred_id":null,"queue_id":null,"compensation_id":null,"attempt":1,"name":"charge","status":"completed","redacted_detail":"","idempotency_key":"v1-golden-activity"}
{"schema":"zigeffect.workflow.journal-event.v1","schema_version":1,"sequence":3,"kind":"workflow_completed","workflow_id":11,"execution_id":12,"parent_sequence":2,"activity_id":null,"timer_id":null,"deferred_id":null,"queue_id":null,"compensation_id":null,"attempt":0,"name":"v1-golden","status":"completed","redacted_detail":"","idempotency_key":"v1-golden-complete"}
```

Add `workflow v1 golden fixture replays under versioned reader` in
`workflow_test.zig`. Load the fixture with `std.Io.Dir.cwd().readFileAlloc`,
parse each row with `fx.workflow.parseWorkflowEventJson`, fold with
`WorkflowReplayState.fold`, and assert status `completed`, workflow id `11`,
execution id `12`, last sequence `3`, and one completed activity.

Add `workflow tool fixture loader accepts v1 golden histories` in
`workflow_tool_support.zig`, using `loadFixtureEvents` with the fixture path and
asserting three events.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
cd packages/zigeffect && zig build examples --summary all
```

Expected: FAIL before the fixture exists and before helper expectations are
implemented.

- [ ] **Step 3: Implement fixture support**

Add the fixture exactly as shown. Add the tests and, if needed, a small local
test helper in `workflow_test.zig` to parse JSONL rows into a
`std.ArrayList(fx.workflow.WorkflowEvent)` and deinitialize owned strings.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples --summary all
```

Expected: PASS.

## Task 4: Docs, Roadmap, Full Gate, And Commit

**Files:**
- Modify `packages/zigeffect/docs/architecture.md`
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Modify `docs/superpowers/plans/2026-06-09-zigeffect-workflow-journal-schema-migration.md`

- [ ] **Step 1: Update architecture docs**

Document that `workflow/journal.zig` owns version-aware row compatibility and
that `workflow/store.zig` treats future versions as newer-runtime failures
rather than corrupt journals.

- [ ] **Step 2: Run full gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build workflow-replay -- --fixture test/fixtures/workflow-journal-v1-golden.jsonl
bun run zig:test
zig fmt --check packages/zigeffect/src/workflow/journal.zig packages/zigeffect/src/workflow/store.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/tools/workflow_tool_support.zig packages/zigeffect/test/workflow_test.zig
git diff --check
rg -n 'T''BD|TO''DO|implement la''ter|fill in de''tails|appropriate error hand''ling|handle edge ca''ses|Similar to Ta''sk|deferred bu''cket|par''ked' packages/zigeffect/src/workflow packages/zigeffect/tools/workflow_tool_support.zig packages/zigeffect/test/workflow_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-workflow-journal-schema-migration-design.md docs/superpowers/plans/2026-06-09-zigeffect-workflow-journal-schema-migration.md
```

Expected: compile/test commands PASS, the workflow replay command prints a
completed v1 golden workflow, format and diff checks exit 0, and the placeholder
scan exits 1 with no matches.

- [ ] **Step 3: Mark Milestone 20 complete**

After the full gate passes, mark all Milestone 20 deliverables and acceptance
boxes complete in
`docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`.

- [ ] **Step 4: Commit**

Run:

```bash
git add docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/plans/2026-06-09-zigeffect-workflow-journal-schema-migration.md docs/superpowers/specs/2026-06-09-zigeffect-workflow-journal-schema-migration-design.md packages/zigeffect/docs/architecture.md packages/zigeffect/src/workflow/journal.zig packages/zigeffect/src/workflow/store.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/tools/workflow_tool_support.zig packages/zigeffect/test/workflow_test.zig packages/zigeffect/test/fixtures/workflow-journal-v1-golden.jsonl
git commit -m "feat(zigeffect): add workflow journal schema migration"
```
