const std = @import("std");
const fx = @import("zigeffect");
const replay_assertions = @import("replay_assertions.zig");

pub fn expectFileJournalPrefixRecovers(
    events: []const fx.workflow.WorkflowEvent,
    prefix_len: usize,
) !void {
    try std.testing.expect(prefix_len <= events.len);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    {
        var file_state = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer file_state.deinit();
        try appendPrefix(file_state.asJournalStore(), events, prefix_len);
    }

    var reopened_state = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer reopened_state.deinit();
    try expectReplayMatchesPrefix(events, prefix_len, reopened_state.asJournalStore());
}

pub fn expectFileJournalPartialTailRecovers(
    events: []const fx.workflow.WorkflowEvent,
    prefix_len: usize,
) !void {
    try std.testing.expect(prefix_len < events.len);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    {
        var file_state = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer file_state.deinit();
        try appendPrefix(file_state.asJournalStore(), events, prefix_len);
    }

    try appendPartialTail(&tmp.dir, events[prefix_len]);

    var reopened_state = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer reopened_state.deinit();
    try std.testing.expect(reopened_state.recoveredPartialBytes() > 0);
    try expectReplayMatchesPrefix(events, prefix_len, reopened_state.asJournalStore());
}

fn appendPrefix(
    store: fx.workflow.JournalStore,
    events: []const fx.workflow.WorkflowEvent,
    prefix_len: usize,
) !void {
    for (events[0..prefix_len]) |event| {
        _ = try store.append(.{ .expected_next_sequence = event.sequence, .event = event });
    }
}

fn expectReplayMatchesPrefix(
    events: []const fx.workflow.WorkflowEvent,
    prefix_len: usize,
    store: fx.workflow.JournalStore,
) !void {
    var expected = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, events[0..prefix_len]);
    defer expected.deinit();

    var actual = try store.latestState(std.testing.allocator);
    defer actual.deinit();

    try replay_assertions.expectReplayStatesEqual(&expected, &actual);
}

fn appendPartialTail(dir: *std.Io.Dir, event: fx.workflow.WorkflowEvent) !void {
    const segment_name = try fx.workflow.segmentFileName(std.testing.allocator, 1);
    defer std.testing.allocator.free(segment_name);

    const row = try fx.workflow.formatWorkflowEventJson(std.testing.allocator, event);
    defer std.testing.allocator.free(row);
    const partial_len = @max(@as(usize, 1), row.len / 2);

    var file = try dir.openFile(std.testing.io, segment_name, .{ .mode = .read_write });
    defer file.close(std.testing.io);

    const offset = try file.length(std.testing.io);
    try file.writePositionalAll(std.testing.io, row[0..partial_len], offset);
}
