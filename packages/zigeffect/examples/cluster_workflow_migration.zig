const std = @import("std");
const fx = @import("zigeffect");

const ClusterWorkflowMigrationReport = struct {
    workflow_id: fx.workflow.WorkflowId,
    execution_id: fx.workflow.ExecutionId,
    started_status: []const u8,
    recovered_executions: usize,
    completed_status: []const u8,
    final_status: fx.workflow.WorkflowStatus,
};

fn runClusterWorkflowMigrationExample(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: *std.Io.Dir,
) !ClusterWorkflowMigrationReport {
    var runner_storage_a = try fx.FileRunnerStorage.open(allocator, io, dir, .{});
    defer runner_storage_a.deinit();
    var runner_storage_b = try fx.FileRunnerStorage.open(allocator, io, dir, .{});
    defer runner_storage_b.deinit();
    var message_storage_a = try fx.FileMessageStorage.open(allocator, io, dir, .{});
    defer message_storage_a.deinit();
    var message_storage_b = try fx.FileMessageStorage.open(allocator, io, dir, .{});
    defer message_storage_b.deinit();
    var journal_state = try fx.workflow.FileJournalStore.open(allocator, io, dir, .{});
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    var runner_a = try fx.LocalClusterRunner.init(allocator, .{
        .runner = fx.runnerAddress("machine-workflow", "runner-a"),
        .runner_storage = runner_storage_a.asRunnerStorage(),
        .message_storage = message_storage_a.asMessageStorage(),
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 1,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
    defer runner_a.deinit();
    var plan_a = try runner_a.acquireBalancedShards(1_000);
    defer plan_a.deinit();

    var transport_state = try fx.InProcessClusterTransport.init(allocator, message_storage_a.asMessageStorage(), .{ .shard_count = 8 });
    defer transport_state.deinit();
    var engine = fx.ClusterWorkflowEngine.init(allocator, transport_state.asClusterTransport());
    defer engine.deinit();

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = fx.workflow.executionId("approval", "migration");
    var registry_a = fx.ClusterWorkflowEntityRegistry.init(allocator);
    defer registry_a.deinit();
    _ = try registry_a.registerExecution(&runner_a, journal_store, workflow_id, execution_id, 1_000);

    var started = try engine.start("approval", "migration");
    defer started.deinit(allocator);
    var start_result = try processWorkflowSubmission(allocator, &runner_a, message_storage_a.asMessageStorage(), started, 1_100);
    defer start_result.deinit(allocator);
    if (!start_result.appended) return error.ExpectedWorkflowStartAppend;
    if (!std.mem.eql(u8, start_result.status, "running")) return error.ExpectedWorkflowStartStatus;

    _ = try runner_a.shutdown(1_200);

    var runner_b = try fx.LocalClusterRunner.init(allocator, .{
        .runner = fx.runnerAddress("machine-workflow", "runner-b"),
        .runner_storage = runner_storage_b.asRunnerStorage(),
        .message_storage = message_storage_b.asMessageStorage(),
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 1,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
    defer runner_b.deinit();
    var plan_b = try runner_b.acquireBalancedShards(1_300);
    defer plan_b.deinit();
    var registry_b = fx.ClusterWorkflowEntityRegistry.init(allocator);
    defer registry_b.deinit();
    const recovery = try registry_b.recoverOwnedExecutions(&runner_b, journal_store, 1_300);
    if (recovery.registered != 1) return error.ExpectedWorkflowRecovery;

    var completed = try engine.complete(workflow_id, execution_id, "value=approved-after-migration");
    defer completed.deinit(allocator);
    var complete_result = try processWorkflowSubmission(allocator, &runner_b, message_storage_b.asMessageStorage(), completed, 1_400);
    defer complete_result.deinit(allocator);
    if (!complete_result.appended) return error.ExpectedWorkflowCompleteAppend;
    if (!std.mem.eql(u8, complete_result.status, "completed")) return error.ExpectedWorkflowCompleteStatus;

    var state = try journal_store.latestState(allocator);
    defer state.deinit();

    return .{
        .workflow_id = workflow_id,
        .execution_id = execution_id,
        .started_status = "running",
        .recovered_executions = recovery.registered,
        .completed_status = "completed",
        .final_status = state.workflow_status,
    };
}

fn processWorkflowSubmission(
    allocator: std.mem.Allocator,
    runner: *fx.LocalClusterRunner,
    message_storage: fx.MessageStorage,
    submission: fx.ClusterWorkflowCommandSubmission,
    now_ms: u64,
) !fx.ClusterWorkflowCommandResult {
    const report = try runner.tick(fx.ClusterWorkflowEntityHandler, now_ms);
    if (report.dispatched != 1) return error.ExpectedWorkflowDispatch;
    if (report.replied != 1) return error.ExpectedWorkflowReplyCount;
    if (report.acked != 1) return error.ExpectedWorkflowAck;

    const reply = (try message_storage.reply(submission.correlation_id, allocator)) orelse return error.ExpectedWorkflowReply;
    defer fx.deinitMessageEnvelope(allocator, reply);
    return fx.parseClusterWorkflowCommandResultFromReply(allocator, reply);
}

pub fn main(init: std.process.Init) !void {
    var cwd = std.Io.Dir.cwd();
    const path = ".zig-cache/zigeffect-examples/cluster-workflow-migration";
    try cwd.createDirPath(init.io, path);
    var dir = try cwd.openDir(init.io, path, .{});
    defer dir.close(init.io);

    const report = try runClusterWorkflowMigrationExample(init.gpa, init.io, &dir);
    std.debug.print(
        "cluster workflow migration: workflow_id={d} execution_id={d} recovered={d} final={s}\n",
        .{ report.workflow_id, report.execution_id, report.recovered_executions, @tagName(report.final_status) },
    );
}

test "cluster workflow migrates from runner a to runner b" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const report = try runClusterWorkflowMigrationExample(std.testing.allocator, std.testing.io, &tmp.dir);
    try std.testing.expectEqualStrings("running", report.started_status);
    try std.testing.expectEqual(@as(usize, 1), report.recovered_executions);
    try std.testing.expectEqualStrings("completed", report.completed_status);
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.completed, report.final_status);
}
