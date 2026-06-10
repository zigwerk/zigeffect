const std = @import("std");
const fx = @import("zigeffect");

const CrashRecoveryReport = struct {
    workflow_id: fx.workflow.WorkflowId,
    execution_id: fx.workflow.ExecutionId,
    committed_events: usize,
    recovered_partial_bytes: u64,
    final_status: fx.workflow.WorkflowStatus,
    segment_line_count: usize,
    active_segment_trimmed: bool,
};

const partial_marker = "partial-row-that-must-disappear";
const partial_row =
    "{\"schema\":\"zigeffect.workflow.journal-event.v1\",\"schema_version\":1,\"sequence\":4,\"kind\":\"workflow_completed\",\"idempotency_key\":\"" ++
    partial_marker ++
    "\"";

fn recoveryEvents(workflow_id: fx.workflow.WorkflowId, execution_id: fx.workflow.ExecutionId) [3]fx.workflow.WorkflowEvent {
    return .{
        .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
            .name = "crash-recovery",
            .status = "running",
            .idempotency_key = "crash-recovery:start",
        },
        .{
            .sequence = 2,
            .kind = .activity_scheduled,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
            .parent_sequence = 1,
            .activity_id = 10,
            .attempt = 1,
            .name = "charge-card",
            .status = "scheduled",
            .idempotency_key = "crash-recovery:activity:scheduled",
        },
        .{
            .sequence = 3,
            .kind = .activity_completed,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
            .parent_sequence = 2,
            .activity_id = 10,
            .attempt = 1,
            .name = "charge-card",
            .status = "completed",
            .redacted_detail = "result=approved",
            .idempotency_key = "crash-recovery:activity:completed",
        },
    };
}

fn appendCommittedPrefix(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: *std.Io.Dir,
    events: []const fx.workflow.WorkflowEvent,
) !void {
    var store_state = try fx.workflow.FileJournalStore.open(allocator, io, dir, .{});
    defer store_state.deinit();
    const journal = store_state.asJournalStore();
    for (events) |event| {
        _ = try journal.append(.{ .expected_next_sequence = event.sequence, .event = event });
    }
}

fn appendPartialTail(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: *std.Io.Dir,
) !void {
    const segment_name = try fx.workflow.segmentFileName(allocator, 1);
    defer allocator.free(segment_name);

    var file = try dir.openFile(io, segment_name, .{ .mode = .read_write });
    defer file.close(io);

    const offset = try file.length(io);
    try file.writePositionalAll(io, partial_row, offset);
}

fn runWorkflowCrashRecoveryExample(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: *std.Io.Dir,
) !CrashRecoveryReport {
    const workflow_id = fx.workflow.workflowId("crash-recovery");
    const execution_id = fx.workflow.executionId("crash-recovery", "case-46");
    const events = recoveryEvents(workflow_id, execution_id);

    try appendCommittedPrefix(allocator, io, dir, &events);
    try appendPartialTail(allocator, io, dir);

    var reopened = try fx.workflow.FileJournalStore.open(allocator, io, dir, .{ .fsync_policy = .after_recovery });
    defer reopened.deinit();

    var state = try reopened.latestState(allocator);
    defer state.deinit();

    var replay_events = try reopened.readAll(allocator);
    defer replay_events.deinit();

    const segment_name = try fx.workflow.segmentFileName(allocator, 1);
    defer allocator.free(segment_name);

    const segment = try dir.readFileAlloc(io, segment_name, allocator, std.Io.Limit.limited(64 * 1024));
    defer allocator.free(segment);

    return .{
        .workflow_id = workflow_id,
        .execution_id = execution_id,
        .committed_events = replay_events.events.len,
        .recovered_partial_bytes = reopened.recoveredPartialBytes(),
        .final_status = state.workflow_status,
        .segment_line_count = std.mem.count(u8, segment, "\n"),
        .active_segment_trimmed = std.mem.indexOf(u8, segment, partial_marker) == null,
    };
}

pub fn main(init: std.process.Init) !void {
    var cwd = std.Io.Dir.cwd();
    const path = ".zig-cache/zigeffect-examples/workflow-crash-recovery";
    cwd.deleteTree(init.io, path) catch {};
    try cwd.createDirPath(init.io, path);
    var dir = try cwd.openDir(init.io, path, .{});
    defer dir.close(init.io);

    const report = try runWorkflowCrashRecoveryExample(init.gpa, init.io, &dir);
    std.debug.print(
        "workflow crash recovery: workflow_id={d} execution_id={d} events={d} recovered_partial_bytes={d} final={s} trimmed={}\n",
        .{
            report.workflow_id,
            report.execution_id,
            report.committed_events,
            report.recovered_partial_bytes,
            @tagName(report.final_status),
            report.active_segment_trimmed,
        },
    );
}

test "file workflow journal trims partial row and replays committed state" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const report = try runWorkflowCrashRecoveryExample(std.testing.allocator, std.testing.io, &tmp.dir);
    try std.testing.expectEqual(@as(usize, 3), report.committed_events);
    try std.testing.expect(report.recovered_partial_bytes >= partial_row.len);
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.running, report.final_status);
    try std.testing.expectEqual(@as(usize, 3), report.segment_line_count);
    try std.testing.expect(report.active_segment_trimmed);
}
