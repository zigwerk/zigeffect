const std = @import("std");
const workflow_history_generator = @import("support/workflow_history_generator.zig");
const journal_crash_injection = @import("support/journal_crash_injection.zig");

test "file journal recovers generated prefixes" {
    const seeds = [_]u64{ 0x91, 0x5151, 0x7777 };
    for (seeds) |seed| {
        var history = try workflow_history_generator.generateWorkflowHistory(std.testing.allocator, seed, 0);
        defer history.deinit();

        var prefix_len: usize = 0;
        while (prefix_len <= history.events.len) : (prefix_len += 1) {
            try journal_crash_injection.expectFileJournalPrefixRecovers(history.events, prefix_len);
        }
    }
}

test "file journal trims generated partial trailing rows" {
    const seeds = [_]u64{ 0x92, 0x6161, 0x8888 };
    for (seeds) |seed| {
        var history = try workflow_history_generator.generateWorkflowHistory(std.testing.allocator, seed, 1);
        defer history.deinit();

        var prefix_len: usize = 0;
        while (prefix_len + 1 < history.events.len) : (prefix_len += 2) {
            try journal_crash_injection.expectFileJournalPartialTailRecovers(history.events, prefix_len);
        }
    }
}
