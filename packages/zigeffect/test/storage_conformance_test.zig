const std = @import("std");
const fx = @import("zigeffect");
const journal_conformance = @import("support/journal_store_conformance.zig");
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
