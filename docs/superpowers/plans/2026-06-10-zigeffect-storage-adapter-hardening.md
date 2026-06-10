# zigeffect Storage Adapter Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add shared storage conformance suites, schema catalog APIs, SQL-shaped migration plans, and a local storage migration command for zigeffect durable stores.

**Architecture:** Keep current storage vtables intact and add reusable conformance helpers around them. Add a new `storage` namespace for schema metadata and SQL plan generation, then expose it through the public facade and a deterministic local CLI.

**Tech Stack:** Zig, Bun task runner, zigeffect workflow and cluster stores, `bun:test` only for repo-level package scripts, Zig build steps for focused storage gates.

---

Date: 2026-06-10

Milestone: 41 - Storage Adapter Hardening

Spec: `docs/superpowers/specs/2026-06-10-zigeffect-storage-adapter-hardening-design.md`

## Files

Create:

- `packages/zigeffect/src/storage/root.zig`
- `packages/zigeffect/src/storage/schema.zig`
- `packages/zigeffect/src/storage/sql.zig`
- `packages/zigeffect/test/support/journal_store_conformance.zig`
- `packages/zigeffect/test/support/runner_storage_conformance.zig`
- `packages/zigeffect/test/support/message_storage_conformance.zig`
- `packages/zigeffect/test/storage_conformance_test.zig`
- `packages/zigeffect/tools/storage_migrate.zig`

Modify:

- `packages/zigeffect/src/zigeffect.zig`
- `packages/zigeffect/build.zig`
- `packages/zigeffect/test/all_test.zig`
- `packages/zigeffect/docs/architecture.md`
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- `docs/superpowers/plans/2026-06-10-zigeffect-storage-adapter-hardening.md`

## Task 1: Journal Store Conformance

- [ ] **Step 1: Write failing journal conformance tests**

Create `packages/zigeffect/test/storage_conformance_test.zig`:

```zig
const std = @import("std");
const fx = @import("zigeffect");
const journal_conformance = @import("support/journal_store_conformance.zig");

test "in-memory journal store passes shared conformance" {
    var store_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer store_state.deinit();
    try journal_conformance.expectJournalStoreConformance(store_state.asJournalStore());
}

test "file journal store passes shared conformance" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var store_state = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer store_state.deinit();
    try journal_conformance.expectJournalStoreConformance(store_state.asJournalStore());
}

test "file journal store shared conformance survives reopen" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    {
        var first = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer first.deinit();
        try journal_conformance.appendStandardJournalEvents(first.asJournalStore());
    }

    var reopened = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer reopened.deinit();
    try journal_conformance.expectStandardJournalEvents(reopened.asJournalStore());
}
```

Import it from `packages/zigeffect/test/all_test.zig` near the existing workflow
tests:

```zig
_ = @import("storage_conformance_test.zig");
```

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: compile failure because `support/journal_store_conformance.zig` is
absent.

- [ ] **Step 3: Implement journal conformance helper**

Create `packages/zigeffect/test/support/journal_store_conformance.zig`:

```zig
const std = @import("std");
const fx = @import("zigeffect");

fn event(sequence: fx.workflow.JournalSequence, kind: fx.workflow.WorkflowEventKind, key: []const u8) fx.workflow.WorkflowEvent {
    return .{
        .sequence = sequence,
        .kind = kind,
        .workflow_id = 41,
        .execution_id = 410,
        .name = "storage-conformance",
        .status = @tagName(kind),
        .idempotency_key = key,
    };
}

pub fn appendStandardJournalEvents(store: fx.workflow.JournalStore) !void {
    _ = try store.append(.{ .expected_next_sequence = 1, .event = event(1, .workflow_started, "journal-1") });
    _ = try store.append(.{ .expected_next_sequence = 2, .event = event(2, .step_started, "journal-2") });
    _ = try store.append(.{ .expected_next_sequence = 3, .event = event(3, .workflow_completed, "journal-3") });
}

pub fn expectStandardJournalEvents(store: fx.workflow.JournalStore) !void {
    var all = try store.readAll(std.testing.allocator);
    defer all.deinit();
    try std.testing.expectEqual(@as(usize, 3), all.events.len);
    try std.testing.expectEqual(@as(fx.workflow.JournalSequence, 1), all.events[0].sequence);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_started, all.events[0].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_completed, all.events[2].kind);

    var from_two = try store.readFromSequence(std.testing.allocator, 2);
    defer from_two.deinit();
    try std.testing.expectEqual(@as(usize, 2), from_two.events.len);
    try std.testing.expectEqual(@as(fx.workflow.JournalSequence, 2), from_two.events[0].sequence);

    var latest = try store.latestState(std.testing.allocator);
    defer latest.deinit();
    try std.testing.expectEqual(@as(fx.workflow.JournalSequence, 3), latest.last_sequence);
}

pub fn expectJournalStoreConformance(store: fx.workflow.JournalStore) !void {
    try appendStandardJournalEvents(store);
    try expectStandardJournalEvents(store);

    try std.testing.expectError(error.SequenceConflict, store.append(.{
        .expected_next_sequence = 99,
        .event = event(4, .step_completed, "journal-conflict"),
    }));
    try std.testing.expectError(error.DuplicateEvent, store.append(.{
        .expected_next_sequence = 4,
        .event = event(4, .step_completed, "journal-3"),
    }));

    store.reset();
    var after_reset = try store.readAll(std.testing.allocator);
    defer after_reset.deinit();
    try std.testing.expectEqual(@as(usize, 0), after_reset.events.len);
}
```

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/test/storage_conformance_test.zig packages/zigeffect/test/support/journal_store_conformance.zig packages/zigeffect/test/all_test.zig
```

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/test/storage_conformance_test.zig packages/zigeffect/test/support/journal_store_conformance.zig packages/zigeffect/test/all_test.zig
git commit -m "test(zigeffect): add journal store conformance"
```

## Task 2: Runner Storage Conformance

- [ ] **Step 1: Write failing runner conformance tests**

Append to `packages/zigeffect/test/storage_conformance_test.zig`:

```zig
const runner_conformance = @import("support/runner_storage_conformance.zig");

test "in-memory runner storage passes shared conformance" {
    var store_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer store_state.deinit();
    try runner_conformance.expectRunnerStorageConformance(store_state.asRunnerStorage());
}

test "file runner storage passes shared conformance" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var store_state = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer store_state.deinit();
    try runner_conformance.expectRunnerStorageConformance(store_state.asRunnerStorage());
}

test "file runner storage shared conformance survives reopen" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const owner = fx.runnerAddress("machine-storage", "runner-a");

    {
        var first = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer first.deinit();
        _ = try first.asRunnerStorage().acquire(.{ .shard_id = 44, .owner = owner, .now_ms = 1_000, .ttl_ms = 500 });
    }

    var reopened = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer reopened.deinit();
    const lease = (try reopened.asRunnerStorage().lease(44)).?;
    try std.testing.expect(lease.owner.eql(owner));
    try std.testing.expectEqual(@as(u64, 1_500), lease.expires_at_ms);
}
```

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: compile failure because `support/runner_storage_conformance.zig` is
absent.

- [ ] **Step 3: Implement runner conformance helper**

Create `packages/zigeffect/test/support/runner_storage_conformance.zig`:

```zig
const std = @import("std");
const fx = @import("zigeffect");

pub fn expectRunnerStorageConformance(store: fx.RunnerStorage) !void {
    const owner = fx.runnerAddress("machine-storage", "runner-a");
    const contender = fx.runnerAddress("machine-storage", "runner-b");
    const other = fx.runnerAddress("machine-other", "runner-c");

    const lease = try store.acquire(.{ .shard_id = 3, .owner = owner, .now_ms = 1_000, .ttl_ms = 500 });
    try std.testing.expect(lease.owner.eql(owner));
    try std.testing.expectEqual(@as(u64, 1_500), lease.expires_at_ms);
    try std.testing.expectEqual(@as(u64, 1), lease.version);

    try std.testing.expectError(error.LeaseConflict, store.acquire(.{
        .shard_id = 3,
        .owner = contender,
        .now_ms = 1_100,
        .ttl_ms = 500,
    }));

    const replacement = try store.acquire(.{ .shard_id = 3, .owner = contender, .now_ms = 1_500, .ttl_ms = 100 });
    try std.testing.expect(replacement.owner.eql(contender));
    try std.testing.expectEqual(@as(u64, 2), replacement.version);

    try std.testing.expectError(error.LeaseNotOwned, store.refresh(.{
        .shard_id = 3,
        .owner = owner,
        .now_ms = 1_525,
        .ttl_ms = 100,
    }));
    const refreshed = try store.refresh(.{ .shard_id = 3, .owner = contender, .now_ms = 1_525, .ttl_ms = 200 });
    try std.testing.expectEqual(@as(u64, 1_725), refreshed.expires_at_ms);

    _ = try store.acquire(.{ .shard_id = 4, .owner = contender, .now_ms = 1_525, .ttl_ms = 200 });
    _ = try store.acquire(.{ .shard_id = 5, .owner = other, .now_ms = 1_525, .ttl_ms = 200 });

    try std.testing.expectError(error.LeaseNotOwned, store.release(.{ .shard_id = 4, .owner = owner }));
    const released = try store.releaseAll(contender);
    try std.testing.expectEqual(@as(usize, 2), released);

    var leases = try store.leases(std.testing.allocator);
    defer leases.deinit();
    try std.testing.expectEqual(@as(usize, 1), leases.leases.len);
    try std.testing.expect(leases.leases[0].owner.eql(other));

    store.reset();
    var after_reset = try store.leases(std.testing.allocator);
    defer after_reset.deinit();
    try std.testing.expectEqual(@as(usize, 0), after_reset.leases.len);
}
```

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/test/storage_conformance_test.zig packages/zigeffect/test/support/runner_storage_conformance.zig
```

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/test/storage_conformance_test.zig packages/zigeffect/test/support/runner_storage_conformance.zig
git commit -m "test(zigeffect): add runner storage conformance"
```

## Task 3: Message Storage Conformance

- [ ] **Step 1: Write failing message conformance tests**

Append to `packages/zigeffect/test/storage_conformance_test.zig`:

```zig
const message_conformance = @import("support/message_storage_conformance.zig");

test "in-memory message storage passes shared conformance" {
    var store_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer store_state.deinit();
    try message_conformance.expectMessageStorageConformance(store_state.asMessageStorage());
}

test "file message storage passes shared conformance" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var store_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer store_state.deinit();
    try message_conformance.expectMessageStorageConformance(store_state.asMessageStorage());
}

test "file message storage shared conformance survives reopen" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const address = fx.entityAddress("storage-message", "reopen");
    var message_id: fx.MessageId = 0;

    {
        var first = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer first.deinit();
        var submitted = try first.asMessageStorage().submit(.{
            .shard_id = 6,
            .now_ms = 2_000,
            .envelope = .{ .kind = .tell, .address = address, .idempotency_key = "message-reopen", .payload = "work" },
        });
        defer submitted.deinit(std.testing.allocator);
        message_id = submitted.envelope.id;
    }

    var reopened = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer reopened.deinit();
    var found = (try reopened.asMessageStorage().unprocessedById(message_id, std.testing.allocator)).?;
    defer found.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(fx.ShardId, 6), found.shard_id);
    try std.testing.expectEqualStrings("work", found.envelope.payload);
}
```

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: compile failure because `support/message_storage_conformance.zig` is
absent.

- [ ] **Step 3: Implement message conformance helper**

Create `packages/zigeffect/test/support/message_storage_conformance.zig`:

```zig
const std = @import("std");
const fx = @import("zigeffect");

pub fn expectMessageStorageConformance(store: fx.MessageStorage) !void {
    const first_address = fx.entityAddress("storage-message", "one");
    const second_address = fx.entityAddress("storage-message", "two");

    var first = try store.submit(.{
        .shard_id = 9,
        .now_ms = 3_000,
        .envelope = .{
            .kind = .request,
            .address = first_address,
            .idempotency_key = "message-one",
            .payload_type_name = "text",
            .payload = "get",
        },
    });
    defer first.deinit(std.testing.allocator);

    var duplicate = try store.submit(.{
        .shard_id = 9,
        .now_ms = 3_001,
        .envelope = .{
            .kind = .request,
            .address = first_address,
            .idempotency_key = "message-one",
            .payload_type_name = "text",
            .payload = "again",
        },
    });
    defer duplicate.deinit(std.testing.allocator);
    try std.testing.expect(duplicate.duplicate);
    try std.testing.expectEqual(first.envelope.id, duplicate.envelope.id);

    var second = try store.submit(.{
        .shard_id = 9,
        .now_ms = 3_002,
        .envelope = .{ .kind = .request, .address = second_address, .idempotency_key = "message-two", .payload = "set" },
    });
    defer second.deinit(std.testing.allocator);

    var by_shard = try store.unprocessedByShard(9, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 2), by_shard.records.len);

    const claimed = try store.claim(.{ .shard_id = 9, .message_id = first.envelope.id, .now_ms = 3_010 });
    defer fx.deinitMessageEnvelope(std.testing.allocator, claimed);
    try std.testing.expectEqual(@as(fx.MessageAttempt, 1), claimed.attempt);

    const stored_reply = try store.storeReply(.{
        .shard_id = 9,
        .now_ms = 3_020,
        .envelope = .{ .kind = .reply, .address = first_address, .correlation_id = first.envelope.correlation_id.?, .payload = "value" },
    });
    defer fx.deinitMessageEnvelope(std.testing.allocator, stored_reply);

    const found_reply = (try store.reply(first.envelope.correlation_id.?, std.testing.allocator)).?;
    defer fx.deinitMessageEnvelope(std.testing.allocator, found_reply);
    try std.testing.expectEqualStrings("value", found_reply.payload);
    try std.testing.expectError(error.DuplicateReply, store.storeReply(.{
        .shard_id = 9,
        .now_ms = 3_021,
        .envelope = .{ .kind = .reply, .address = first_address, .correlation_id = first.envelope.correlation_id.?, .payload = "again" },
    }));

    try store.ack(.{ .message_id = second.envelope.id, .now_ms = 3_030 });
    try std.testing.expect((try store.unprocessedById(second.envelope.id, std.testing.allocator)) == null);

    store.reset();
    var after_reset = try store.unprocessedByShard(9, std.testing.allocator);
    defer after_reset.deinit();
    try std.testing.expectEqual(@as(usize, 0), after_reset.records.len);
}
```

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/test/storage_conformance_test.zig packages/zigeffect/test/support/message_storage_conformance.zig
```

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/test/storage_conformance_test.zig packages/zigeffect/test/support/message_storage_conformance.zig
git commit -m "test(zigeffect): add message storage conformance"
```

## Task 4: Focused Storage Conformance Build Step

- [ ] **Step 1: Write failing build-step expectation**

Run:

```bash
cd packages/zigeffect && zig build storage-conformance --summary all
```

Expected: failure because no `storage-conformance` step exists.

- [ ] **Step 2: Add storage conformance build step**

Modify `packages/zigeffect/build.zig` near the causal backend conformance step:

```zig
const storage_conformance_test_module = b.createModule(.{
    .root_source_file = b.path("test/storage_conformance_test.zig"),
    .target = target,
    .optimize = optimize,
});
storage_conformance_test_module.addImport("zigeffect", zigeffect);

const storage_conformance_tests = b.addTest(.{
    .name = "zigeffect-storage-conformance-tests",
    .root_module = storage_conformance_test_module,
});
const run_storage_conformance_tests = b.addRunArtifact(storage_conformance_tests);
const storage_conformance_step = b.step("storage-conformance", "Run workflow and cluster storage conformance contract tests");
storage_conformance_step.dependOn(&run_storage_conformance_tests.step);
```

Also add the focused tests to the regular causal-wrapped `test` step:

```zig
test_step.dependOn(&run_storage_conformance_tests.step);
```

- [ ] **Step 3: Verify green**

Run:

```bash
cd packages/zigeffect && zig build storage-conformance --summary all
bun run zigeffect:test
zig fmt --check packages/zigeffect/build.zig
```

- [ ] **Step 4: Commit**

```bash
git add packages/zigeffect/build.zig
git commit -m "build(zigeffect): add storage conformance step"
```

## Task 5: Storage Schema Catalog API

- [ ] **Step 1: Write failing schema catalog tests**

Append to `packages/zigeffect/test/storage_conformance_test.zig`:

```zig
test "storage schema catalog exposes durable record schemas" {
    const catalog = fx.storageSchemaCatalog();
    try std.testing.expect(catalog.items.len >= 6);
    try expectStorageSchema(catalog, fx.workflow.workflow_journal_event_schema);
    try expectStorageSchema(catalog, fx.workflow.workflow_checkpoint_schema);
    try expectStorageSchema(catalog, fx.workflow.workflow_snapshot_commit_schema);
    try expectStorageSchema(catalog, fx.runner_lease_schema);
    try expectStorageSchema(catalog, fx.message_record_schema);
    try expectStorageSchema(catalog, fx.message_reply_schema);

    const current = fx.classifyStorageSchema(fx.message_record_schema, fx.message_record_schema_version);
    try std.testing.expectEqual(fx.StorageSchemaCompatibility.current, current.compatibility);
    const newer = fx.classifyStorageSchema(fx.message_record_schema, fx.message_record_schema_version + 1);
    try std.testing.expectEqual(fx.StorageSchemaCompatibility.newer, newer.compatibility);
    const unknown = fx.classifyStorageSchema("zigeffect.unknown.v1", 1);
    try std.testing.expectEqual(fx.StorageSchemaCompatibility.unknown, unknown.compatibility);
}

test "storage schema catalog formats text and json" {
    const text = try fx.formatStorageSchemaCatalogText(std.testing.allocator, fx.storageSchemaCatalog());
    defer std.testing.allocator.free(text);
    try expectContains(text, "zigeffect storage schema catalog");
    try expectContains(text, fx.message_record_schema);

    const json = try fx.formatStorageSchemaCatalogJson(std.testing.allocator, fx.storageSchemaCatalog());
    defer std.testing.allocator.free(json);
    try expectContains(json, "\"schema\":\"zigeffect.storage.catalog.v1\"");
    try expectContains(json, fx.runner_lease_schema);
}

fn expectStorageSchema(catalog: fx.StorageSchemaCatalog, schema: []const u8) !void {
    try std.testing.expect(catalog.find(schema) != null);
    try std.testing.expect(fx.findStorageSchema(schema) != null);
}

fn expectContains(haystack: []const u8, needle: []const u8) !void {
    try std.testing.expect(std.mem.indexOf(u8, haystack, needle) != null);
}
```

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: compile failure because `fx.storageSchemaCatalog` and related storage
types are absent.

- [ ] **Step 3: Implement storage schema module**

Create `packages/zigeffect/src/storage/schema.zig`:

```zig
const std = @import("std");
const workflow_journal = @import("../workflow/journal.zig");
const workflow_store = @import("../workflow/store.zig");
const runner_storage = @import("../cluster/runner_storage.zig");
const message_storage = @import("../cluster/message_storage.zig");

pub const Allocator = std.mem.Allocator;
pub const storage_catalog_schema = "zigeffect.storage.catalog.v1";
pub const storage_catalog_schema_version: u32 = 1;

pub const StorageAdapterKind = enum { journal, runner, message };
pub const StorageRecordKind = enum {
    workflow_event,
    workflow_checkpoint,
    workflow_snapshot_commit,
    runner_lease,
    message_record,
    message_reply,
};
pub const StorageSchemaCompatibility = enum { current, older, newer, unknown };

pub const StorageSchemaDescriptor = struct {
    adapter: StorageAdapterKind,
    record: StorageRecordKind,
    schema: []const u8,
    version: u32,
    description: []const u8,
};

pub const StorageSchemaCompatibilityReport = struct {
    schema: []const u8,
    expected_version: ?u32 = null,
    found_version: u32,
    compatibility: StorageSchemaCompatibility,
};

pub const StorageSchemaCatalog = struct {
    items: []const StorageSchemaDescriptor,

    pub fn find(self: StorageSchemaCatalog, schema: []const u8) ?StorageSchemaDescriptor {
        for (self.items) |item| {
            if (std.mem.eql(u8, item.schema, schema)) return item;
        }
        return null;
    }
};
```

Add a static catalog using the existing schema constants, plus:

```zig
pub fn storageSchemaCatalog() StorageSchemaCatalog {
    return .{ .items = &schema_catalog };
}

pub fn findStorageSchema(schema: []const u8) ?StorageSchemaDescriptor {
    return storageSchemaCatalog().find(schema);
}

pub fn classifyStorageSchema(schema: []const u8, version: u32) StorageSchemaCompatibilityReport {
    const descriptor = findStorageSchema(schema) orelse return .{
        .schema = schema,
        .found_version = version,
        .compatibility = .unknown,
    };
    return .{
        .schema = schema,
        .expected_version = descriptor.version,
        .found_version = version,
        .compatibility = if (version == descriptor.version) .current else if (version < descriptor.version) .older else .newer,
    };
}
```

Implement `formatStorageSchemaCatalogText` and
`formatStorageSchemaCatalogJson` with deterministic ordering from the static
catalog.

Create `packages/zigeffect/src/storage/root.zig`:

```zig
pub const domain = "storage";
pub const schema = @import("schema.zig");

pub const StorageAdapterKind = schema.StorageAdapterKind;
pub const StorageRecordKind = schema.StorageRecordKind;
pub const StorageSchemaDescriptor = schema.StorageSchemaDescriptor;
pub const StorageSchemaCompatibility = schema.StorageSchemaCompatibility;
pub const StorageSchemaCompatibilityReport = schema.StorageSchemaCompatibilityReport;
pub const StorageSchemaCatalog = schema.StorageSchemaCatalog;
pub const storageSchemaCatalog = schema.storageSchemaCatalog;
pub const findStorageSchema = schema.findStorageSchema;
pub const classifyStorageSchema = schema.classifyStorageSchema;
pub const formatStorageSchemaCatalogText = schema.formatStorageSchemaCatalogText;
pub const formatStorageSchemaCatalogJson = schema.formatStorageSchemaCatalogJson;
```

Modify `packages/zigeffect/src/zigeffect.zig`:

```zig
pub const storage = @import("storage/root.zig");
```

Add top-level aliases listed in the spec.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/storage/root.zig packages/zigeffect/src/storage/schema.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/storage_conformance_test.zig
```

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/storage/root.zig packages/zigeffect/src/storage/schema.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/storage_conformance_test.zig
git commit -m "feat(zigeffect): add storage schema catalog"
```

## Task 6: SQL-Shaped Storage Migration Plan

- [ ] **Step 1: Write failing SQL plan tests**

Append to `packages/zigeffect/test/storage_conformance_test.zig`:

```zig
test "sql storage migration plan describes durable tables" {
    const plan = fx.sqlStorageMigrationPlan(.cockroachdb);
    try std.testing.expectEqual(fx.SqlStorageDialect.cockroachdb, plan.dialect);
    try std.testing.expect(plan.statements.len >= 6);
    try expectSqlStatement(plan, "create_workflow_journal_events");
    try expectSqlStatement(plan, "create_workflow_checkpoints");
    try expectSqlStatement(plan, "create_workflow_snapshot_commits");
    try expectSqlStatement(plan, "create_cluster_runner_leases");
    try expectSqlStatement(plan, "create_cluster_messages");
    try expectSqlStatement(plan, "create_cluster_replies");
}

test "sql storage migration plan formats text and json" {
    const plan = fx.sqlStorageMigrationPlan(.postgresql);
    const text = try fx.formatSqlStorageMigrationPlanText(std.testing.allocator, plan);
    defer std.testing.allocator.free(text);
    try expectContains(text, "zigeffect storage migration plan");
    try expectContains(text, "postgresql");
    try expectContains(text, "zigeffect_cluster_messages");

    const json = try fx.formatSqlStorageMigrationPlanJson(std.testing.allocator, plan);
    defer std.testing.allocator.free(json);
    try expectContains(json, "\"schema\":\"zigeffect.storage.sql-plan.v1\"");
    try expectContains(json, "create_cluster_runner_leases");
}

fn expectSqlStatement(plan: fx.SqlStorageMigrationPlan, name: []const u8) !void {
    for (plan.statements) |statement| {
        if (std.mem.eql(u8, statement.name, name)) return;
    }
    return error.ExpectedSqlStorageStatement;
}
```

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: compile failure because SQL storage migration types and functions are
absent.

- [ ] **Step 3: Implement SQL storage module**

Create `packages/zigeffect/src/storage/sql.zig`:

```zig
const std = @import("std");
const schema_mod = @import("schema.zig");

pub const Allocator = std.mem.Allocator;
pub const storage_sql_plan_schema = "zigeffect.storage.sql-plan.v1";
pub const storage_sql_plan_schema_version: u32 = 1;

pub const SqlStorageDialect = enum { postgresql, cockroachdb };
pub const SqlStorageStatementKind = enum { create_schema, create_table, create_index };

pub const SqlStorageStatement = struct {
    name: []const u8,
    adapter: schema_mod.StorageAdapterKind,
    kind: SqlStorageStatementKind,
    sql: []const u8,
};

pub const SqlStorageMigrationPlan = struct {
    dialect: SqlStorageDialect,
    schemas: []const schema_mod.StorageSchemaDescriptor,
    statements: []const SqlStorageStatement,
};

pub fn sqlStorageMigrationPlan(dialect: SqlStorageDialect) SqlStorageMigrationPlan {
    return .{
        .dialect = dialect,
        .schemas = schema_mod.storageSchemaCatalog().items,
        .statements = &sql_statements,
    };
}
```

Add static statements for the six durable tables named in the test. Use
PostgreSQL-compatible SQL that is accepted as a CockroachDB starting point:

```sql
CREATE TABLE IF NOT EXISTS zigeffect_cluster_messages (
  message_id INTEGER PRIMARY KEY,
  shard_id INTEGER NOT NULL,
  status TEXT NOT NULL,
  schema TEXT NOT NULL,
  schema_version INTEGER NOT NULL,
  payload_json JSONB NOT NULL,
  updated_at_ms INTEGER NOT NULL
)
```

Implement text and JSON formatters. JSON should include plan schema, schema
version, dialect, statement names, kinds, adapter names, and SQL text.

Update `packages/zigeffect/src/storage/root.zig` and
`packages/zigeffect/src/zigeffect.zig` to export SQL types and functions.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/storage/root.zig packages/zigeffect/src/storage/sql.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/storage_conformance_test.zig
```

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/storage/root.zig packages/zigeffect/src/storage/sql.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/storage_conformance_test.zig
git commit -m "feat(zigeffect): add sql storage migration plan"
```

## Task 7: Storage Migration CLI

- [ ] **Step 1: Write failing storage migration tool tests**

Create `packages/zigeffect/tools/storage_migrate.zig`:

```zig
const std = @import("std");
const fx = @import("zigeffect");

pub fn runStorageMigrate(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
    _ = allocator;
    _ = args;
    return error.StorageMigrateToolMissing;
}

test "storage migrate schemas command formats text and json" {
    const text_args = [_][]const u8{"schemas"};
    const text = try runStorageMigrate(std.testing.allocator, &text_args);
    defer std.testing.allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect storage schema catalog") != null);

    const json_args = [_][]const u8{ "schemas", "--format", "json" };
    const json = try runStorageMigrate(std.testing.allocator, &json_args);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.storage.catalog.v1\"") != null);
}

test "storage migrate plan command formats selected dialect" {
    const args = [_][]const u8{ "plan", "--dialect", "cockroachdb" };
    const text = try runStorageMigrate(std.testing.allocator, &args);
    defer std.testing.allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "cockroachdb") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "create_cluster_messages") != null);
}
```

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig test tools/storage_migrate.zig --dep zigeffect -Mzigeffect=src/zigeffect.zig
```

Expected: test failure from `StorageMigrateToolMissing`.

- [ ] **Step 3: Implement storage migration tool**

Replace the tool body with:

```zig
const std = @import("std");
const fx = @import("zigeffect");

const OutputFormat = enum { text, json };

pub const StorageMigrateError = error{
    UnknownCommand,
    UnknownFlag,
    MissingFlagValue,
    UnknownFormat,
    UnknownDialect,
};

pub fn runStorageMigrate(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
    if (args.len == 0) return usage(allocator);
    if (std.mem.eql(u8, args[0], "schemas")) {
        const format = try parseFormat(args[1..]);
        return switch (format) {
            .text => fx.formatStorageSchemaCatalogText(allocator, fx.storageSchemaCatalog()),
            .json => fx.formatStorageSchemaCatalogJson(allocator, fx.storageSchemaCatalog()),
        };
    }
    if (std.mem.eql(u8, args[0], "plan")) {
        const parsed = try parsePlanArgs(args[1..]);
        const plan = fx.sqlStorageMigrationPlan(parsed.dialect);
        return switch (parsed.format) {
            .text => fx.formatSqlStorageMigrationPlanText(allocator, plan),
            .json => fx.formatSqlStorageMigrationPlanJson(allocator, plan),
        };
    }
    return error.UnknownCommand;
}
```

Add helpers `usage`, `parseFormat`, `parsePlanArgs`, `parseDialect`, and
`main(init: std.process.Init) !void` following the simple style in
`tools/workflow_journal_inspect.zig`.

- [ ] **Step 4: Add build step**

Modify `packages/zigeffect/build.zig` near `cluster_runner_tool_module`:

```zig
const storage_migrate_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/storage_migrate.zig"),
    .target = target,
    .optimize = optimize,
});
storage_migrate_tool_module.addImport("zigeffect", zigeffect);

const storage_migrate_tool = b.addExecutable(.{
    .name = "zigeffect-storage-migrate",
    .root_module = storage_migrate_tool_module,
});
const run_storage_migrate_tool = b.addRunArtifact(storage_migrate_tool);
if (b.args) |args| run_storage_migrate_tool.addArgs(args);
const storage_migrate_step = b.step("storage-migrate", "Print zigeffect storage schema and SQL migration plans");
storage_migrate_step.dependOn(&run_storage_migrate_tool.step);

const storage_migrate_tool_tests = b.addTest(.{
    .name = "zigeffect-storage-migrate-tests",
    .root_module = storage_migrate_tool_module,
});
const run_storage_migrate_tool_tests = b.addRunArtifact(storage_migrate_tool_tests);
test_step.dependOn(&run_storage_migrate_tool_tests.step);
```

Add the tool and tests to `examples_step` so `zig build examples` compiles it.

- [ ] **Step 5: Verify green**

Run:

```bash
cd packages/zigeffect && zig build storage-migrate -- schemas
cd packages/zigeffect && zig build storage-migrate -- plan --dialect cockroachdb
bun run zigeffect:test
zig fmt --check packages/zigeffect/tools/storage_migrate.zig packages/zigeffect/build.zig
```

- [ ] **Step 6: Commit**

```bash
git add packages/zigeffect/tools/storage_migrate.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): add storage migration cli"
```

## Task 8: Architecture Docs, Roadmap, And Full Gate

- [ ] **Step 1: Update architecture docs**

In `packages/zigeffect/docs/architecture.md`, add a `src/storage/` section:

```md
### src/storage/

Owns durable storage adapter metadata.

- `root.zig`: storage namespace facade and public aliases.
- `schema.zig`: durable storage schema catalog, compatibility reports, and
  text/JSON formatting.
- `sql.zig`: SQL-shaped storage migration plans for PostgreSQL-compatible and
  Cockroach-compatible deployments.

Storage adapter metadata, schema compatibility, and migration planning belong
in this folder. Concrete workflow and cluster storage implementations remain in
their own domain folders.
```

Add one sentence to the `src/workflow/` and `src/cluster/` sections that
storage conformance is shared through `src/storage/` metadata and
`test/support/*_conformance.zig` helpers.

- [ ] **Step 2: Mark M41 complete in roadmap and plan**

In `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`,
mark the M41 deliverables and acceptance checked.

In this plan, mark completed task steps with `- [x]`.

- [ ] **Step 3: Run full verification gate**

Run:

```bash
bun run zigeffect:test
(cd packages/zigeffect && zig build storage-conformance)
(cd packages/zigeffect && zig build storage-migrate -- schemas)
(cd packages/zigeffect && zig build storage-migrate -- plan --dialect cockroachdb)
(cd packages/zigeffect && zig build examples)
(cd packages/zigeffect && zig build cluster-runner -- --help)
bun run zig:test
zig fmt --check packages/zigeffect/src/storage/root.zig packages/zigeffect/src/storage/schema.zig packages/zigeffect/src/storage/sql.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/storage_conformance_test.zig packages/zigeffect/test/support/journal_store_conformance.zig packages/zigeffect/test/support/runner_storage_conformance.zig packages/zigeffect/test/support/message_storage_conformance.zig packages/zigeffect/test/all_test.zig packages/zigeffect/tools/storage_migrate.zig packages/zigeffect/build.zig
git diff --check
rg "TO""DO|FIX""ME|st""ub|place""holder|not imple""mented|unimple""mented" packages/zigeffect/src packages/zigeffect/test packages/zigeffect/tools packages/zigeffect/docs docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/specs/2026-06-10-zigeffect-storage-adapter-hardening-design.md docs/superpowers/plans/2026-06-10-zigeffect-storage-adapter-hardening.md
```

- [ ] **Step 4: Commit docs**

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/plans/2026-06-10-zigeffect-storage-adapter-hardening.md
git commit -m "docs(zigeffect): mark storage adapter hardening complete"
```

## Self-Review

- Spec coverage: shared conformance, file-backed conformance, SQL-shaped
  contract, migration command, public API, docs, and roadmap each map to tasks.
- Marker scan: marker words are split in the full gate command.
- Type consistency: `StorageSchemaCatalog`, `StorageSchemaCompatibility`,
  `SqlStorageMigrationPlan`, and `storage-migrate` names match the design spec.
