const std = @import("std");
const fx = @import("zigeffect");

const TimerSignalReport = struct {
    timer_id: fx.workflow.TimerId,
    fired_timers: usize,
    signal_value: u64,
    timer_events: usize,
    signal_events: usize,
};

const Approval = fx.workflow.Signal("approval", u64);

const signal_codec = fx.Codec(u64){
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

fn runTimerSignalExample(allocator: std.mem.Allocator) !TimerSignalReport {
    var clock = fx.FakeClock.fake(1_000);
    const workflow_id = fx.workflow.workflowId("timer-signal");
    const execution_id = fx.workflow.executionId("timer-signal", "case-7");

    var journal_memory = fx.workflow.InMemoryJournalStore.init(allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = workflow_id,
        .execution_id = execution_id,
        .name = "timer-signal",
        .status = "running",
        .idempotency_key = "timer-signal:case-7",
    } });

    {
        var context = try fx.workflow.WorkflowContext.init(allocator, journal, .{
            .workflow_id = workflow_id,
            .execution_id = execution_id,
            .clock = &clock,
        });
        defer context.deinit();

        switch (try context.sleep("review-timeout", 250)) {
            .suspended => {},
            else => return error.ExpectedTimerSuspension,
        }
    }

    var durable_clock = fx.workflow.DurableClock.init(allocator, journal, workflow_id, execution_id);
    var early = try durable_clock.dueTimers(1_249);
    defer early.deinit();
    if (early.timers.len != 0) return error.ExpectedNoEarlyTimers;

    const fired_timers = try durable_clock.fireDueTimers(1_250);
    if (fired_timers != 1) return error.ExpectedOneTimer;

    {
        var context = try fx.workflow.WorkflowContext.init(allocator, journal, .{
            .workflow_id = workflow_id,
            .execution_id = execution_id,
            .clock = &clock,
        });
        defer context.deinit();

        switch (try context.sleep("review-timeout", 250)) {
            .fired => {},
            else => return error.ExpectedTimerFired,
        }
    }

    {
        var context = try fx.workflow.WorkflowContext.init(allocator, journal, .{
            .workflow_id = workflow_id,
            .execution_id = execution_id,
        });
        defer context.deinit();

        switch (try context.waitForSignal(Approval, signal_codec)) {
            .suspended => {},
            else => return error.ExpectedSignalSuspension,
        }
    }

    var durable_signal = fx.workflow.DurableSignal.init(allocator, journal, workflow_id, execution_id);
    if (!try durable_signal.send(Approval, signal_codec, 7, "signal:approval:7")) {
        return error.ExpectedSignalAppend;
    }

    const signal_value = blk: {
        var context = try fx.workflow.WorkflowContext.init(allocator, journal, .{
            .workflow_id = workflow_id,
            .execution_id = execution_id,
        });
        defer context.deinit();

        break :blk switch (try context.waitForSignal(Approval, signal_codec)) {
            .received => |value| value,
            else => return error.ExpectedSignalReceived,
        };
    };

    var events = try journal.readAll(allocator);
    defer events.deinit();

    var timer_events: usize = 0;
    var signal_events: usize = 0;
    for (events.events) |event| {
        switch (event.kind) {
            .timer_scheduled, .timer_fired => timer_events += 1,
            .signal_received => signal_events += 1,
            else => {},
        }
    }

    return .{
        .timer_id = fx.workflow.timerId("review-timeout"),
        .fired_timers = fired_timers,
        .signal_value = signal_value,
        .timer_events = timer_events,
        .signal_events = signal_events,
    };
}

pub fn main() !void {
    const report = try runTimerSignalExample(std.heap.page_allocator);
    std.debug.print(
        "timer signal workflow: timer_id={d} fired={d} signal={d}\n",
        .{ report.timer_id, report.fired_timers, report.signal_value },
    );
}

test "timer and signal workflow resumes both durable waits" {
    const report = try runTimerSignalExample(std.testing.allocator);
    try std.testing.expectEqual(fx.workflow.timerId("review-timeout"), report.timer_id);
    try std.testing.expectEqual(@as(usize, 1), report.fired_timers);
    try std.testing.expectEqual(@as(u64, 7), report.signal_value);
    try std.testing.expect(report.timer_events >= 2);
    try std.testing.expect(report.signal_events >= 1);
}
