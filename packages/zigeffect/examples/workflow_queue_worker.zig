const std = @import("std");
const fx = @import("zigeffect");

const QueueWorkerReport = struct {
    queue_id: fx.workflow.QueueId,
    account_id: u64,
    worker_id: []const u8,
    completed_value: u64,
    acked_once: bool,
    event_count: usize,
};

const QueuePayload = struct {
    account_id: u64,
};

const EmailQueue = fx.workflow
    .Queue("email", QueuePayload, u64, error{DeliveryFailed})
    .withIdempotencyKey(struct {
    fn key(allocator: std.mem.Allocator, payload: QueuePayload) ![]const u8 {
        return std.fmt.allocPrint(allocator, "email:{d}", .{payload.account_id});
    }
}.key);

const payload_codec = fx.Codec(QueuePayload){
    .encode = struct {
        fn encode(allocator: std.mem.Allocator, payload: QueuePayload) ![]const u8 {
            return std.fmt.allocPrint(allocator, "{d}", .{payload.account_id});
        }
    }.encode,
    .decode = struct {
        fn decode(_: std.mem.Allocator, bytes: []const u8) !QueuePayload {
            return .{ .account_id = try std.fmt.parseInt(u64, bytes, 10) };
        }
    }.decode,
};

const result_codec = fx.Codec(u64){
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

fn runQueueWorkerExample(allocator: std.mem.Allocator) !QueueWorkerReport {
    const workflow_id = fx.workflow.workflowId("email-workflow");
    const execution_id = fx.workflow.executionId("email-workflow", "account-42");
    const payload = QueuePayload{ .account_id = 42 };

    var journal_memory = fx.workflow.InMemoryJournalStore.init(allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = workflow_id,
        .execution_id = execution_id,
        .name = "email-workflow",
        .status = "running",
        .idempotency_key = "email-workflow:account-42",
    } });

    {
        var context = try fx.workflow.WorkflowContext.init(allocator, journal, .{
            .workflow_id = workflow_id,
            .execution_id = execution_id,
        });
        defer context.deinit();

        const result = try context.queue(EmailQueue, payload_codec, result_codec, payload);
        switch (result) {
            .suspended => {},
            else => return error.ExpectedQueueSuspension,
        }
    }

    var durable_queue = fx.workflow.DurableQueue.init(allocator, journal, workflow_id, execution_id);
    const claim = (try durable_queue.claim(EmailQueue, payload_codec, "worker-a")) orelse return error.ExpectedQueueClaim;
    if (claim.payload.account_id != payload.account_id) return error.ExpectedClaimPayload;
    try durable_queue.complete(EmailQueue, claim.item_id, result_codec, 99);

    const completed_value = blk: {
        var context = try fx.workflow.WorkflowContext.init(allocator, journal, .{
            .workflow_id = workflow_id,
            .execution_id = execution_id,
        });
        defer context.deinit();

        break :blk switch (try context.queue(EmailQueue, payload_codec, result_codec, payload)) {
            .completed => |value| value,
            else => return error.ExpectedQueueCompletion,
        };
    };

    {
        var context = try fx.workflow.WorkflowContext.init(allocator, journal, .{
            .workflow_id = workflow_id,
            .execution_id = execution_id,
        });
        defer context.deinit();

        switch (try context.queue(EmailQueue, payload_codec, result_codec, payload)) {
            .completed => |value| if (value != completed_value) return error.ExpectedQueueReplay,
            else => return error.ExpectedQueueReplay,
        }
    }

    var events = try journal.readAll(allocator);
    defer events.deinit();

    var ack_count: usize = 0;
    for (events.events) |event| {
        if (event.kind == .queue_acked and event.queue_id == claim.item_id) ack_count += 1;
    }

    return .{
        .queue_id = claim.item_id,
        .account_id = claim.payload.account_id,
        .worker_id = "worker-a",
        .completed_value = completed_value,
        .acked_once = ack_count == 1,
        .event_count = events.events.len,
    };
}

pub fn main() !void {
    const report = try runQueueWorkerExample(std.heap.page_allocator);
    std.debug.print(
        "queue worker: queue_id={d} account={d} worker={s} result={d} events={d}\n",
        .{ report.queue_id, report.account_id, report.worker_id, report.completed_value, report.event_count },
    );
}

test "durable queue worker offers claims completes and replays ack" {
    const report = try runQueueWorkerExample(std.testing.allocator);
    try std.testing.expectEqual(@as(u64, 42), report.account_id);
    try std.testing.expectEqualStrings("worker-a", report.worker_id);
    try std.testing.expectEqual(@as(u64, 99), report.completed_value);
    try std.testing.expect(report.acked_once);
    try std.testing.expect(report.event_count >= 6);
}
