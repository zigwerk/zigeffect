const std = @import("std");
const fx = @import("zigeffect");

const ApprovalReport = struct {
    workflow_id: fx.workflow.WorkflowId,
    execution_id: fx.workflow.ExecutionId,
    first_pass_suspended: bool,
    approved_value: u64,
    final_status: fx.workflow.WorkflowStatus,
    event_count: usize,
};

const Approval = fx.workflow.Signal("approval", u64);

const approval_codec = fx.Codec(u64){
    .encode = struct {
        fn encode(allocator: std.mem.Allocator, value: u64) ![]const u8 {
            return std.fmt.allocPrint(allocator, "{d}", .{value});
        }
    }.encode,
    .decode = struct {
        fn decode(_: std.mem.Allocator, bytes: []const u8) !u64 {
            return std.fmt.parseInt(u64, bytes, 10);
        }
    }.decode,
};

fn runApprovalWorkflowExample(allocator: std.mem.Allocator, io: std.Io, dir: *std.Io.Dir) !ApprovalReport {
    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = fx.workflow.executionId("approval", "case-42");
    var first_pass_suspended = false;

    {
        var file_store = try fx.workflow.FileJournalStore.open(allocator, io, dir, .{});
        defer file_store.deinit();
        const journal = file_store.asJournalStore();

        _ = try journal.append(.{ .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
            .name = "approval",
            .status = "running",
            .idempotency_key = "approval:case-42",
        } });

        var context = try fx.workflow.WorkflowContext.init(allocator, journal, .{
            .workflow_id = workflow_id,
            .execution_id = execution_id,
        });
        defer context.deinit();

        const result = try context.waitForSignal(Approval, approval_codec);
        switch (result) {
            .suspended => first_pass_suspended = true,
            else => return error.ExpectedApprovalSuspension,
        }
    }

    {
        var reopened = try fx.workflow.FileJournalStore.open(allocator, io, dir, .{});
        defer reopened.deinit();
        const journal = reopened.asJournalStore();

        var external = fx.workflow.DurableSignal.init(allocator, journal, workflow_id, execution_id);
        if (!try external.send(Approval, approval_codec, 42, "operator:42")) {
            return error.ExpectedApprovalSignalAppend;
        }
    }

    var reopened = try fx.workflow.FileJournalStore.open(allocator, io, dir, .{});
    defer reopened.deinit();
    const journal = reopened.asJournalStore();

    var context = try fx.workflow.WorkflowContext.init(allocator, journal, .{
        .workflow_id = workflow_id,
        .execution_id = execution_id,
    });
    defer context.deinit();

    const approval = switch (try context.waitForSignal(Approval, approval_codec)) {
        .received => |value| value,
        else => return error.ExpectedApprovalReceived,
    };

    var state = try journal.latestState(allocator);
    defer state.deinit();
    var events = try journal.readAll(allocator);
    defer events.deinit();

    return .{
        .workflow_id = workflow_id,
        .execution_id = execution_id,
        .first_pass_suspended = first_pass_suspended,
        .approved_value = approval,
        .final_status = state.workflow_status,
        .event_count = events.events.len,
    };
}

pub fn main(init: std.process.Init) !void {
    var cwd = std.Io.Dir.cwd();
    const path = ".zig-cache/zigeffect-examples/workflow-approval";
    try cwd.createDirPath(init.io, path);
    var dir = try cwd.openDir(init.io, path, .{});
    defer dir.close(init.io);

    const report = try runApprovalWorkflowExample(init.gpa, init.io, &dir);
    std.debug.print(
        "approval workflow: workflow_id={d} execution_id={d} approved={d} events={d}\n",
        .{ report.workflow_id, report.execution_id, report.approved_value, report.event_count },
    );
}

test "approval workflow suspends then resumes from a durable signal after reopen" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const report = try runApprovalWorkflowExample(std.testing.allocator, std.testing.io, &tmp.dir);
    try std.testing.expect(report.first_pass_suspended);
    try std.testing.expectEqual(@as(u64, 42), report.approved_value);
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.running, report.final_status);
    try std.testing.expect(report.event_count >= 4);
}
