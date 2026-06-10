const std = @import("std");
const fx = @import("zigeffect");
const journal_conformance = @import("support/journal_store_conformance.zig");
const message_conformance = @import("support/message_storage_conformance.zig");
const runner_conformance = @import("support/runner_storage_conformance.zig");

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
