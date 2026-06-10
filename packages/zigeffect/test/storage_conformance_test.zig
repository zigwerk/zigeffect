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
