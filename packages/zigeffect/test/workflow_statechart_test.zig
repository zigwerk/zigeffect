const std = @import("std");
const fx = @import("zigeffect");

const State = enum { idle, running, done };
const Event = union(enum) { start: u64, finish };
const Context = struct { total: u64 = 0 };
const Command = union(enum) { execute: u64 };
const Def = fx.statechart.Definition(State, Event, Context, Command);
const Durable = fx.workflow.DurableStatechart(Def);

fn start(context: *Context, event: *const Event, sink: *Def.CommandSink) anyerror!void {
    context.total += event.start;
    try sink.emit(.{ .execute = event.start });
}

const definition = Def.init(.{
    .id = "agent.durable",
    .version = 1,
    .initial = .idle,
    .states = &.{
        .{ .id = .idle },
        .{ .id = .running },
        .{ .id = .done, .kind = .final },
    },
    .transitions = &.{
        .{ .id = "start", .source = .idle, .event = .start, .target = .running, .actions = &.{.{ .id = "start", .execute = start }} },
        .{ .id = "finish", .source = .running, .event = .finish, .target = .done },
    },
});

test "durable statecharts commit replayable snapshots and typed commands" {
    const allocator = std.testing.allocator;
    var memory = Durable.InMemoryJournal.init(allocator);
    defer memory.deinit();
    var durable = Durable.init(allocator, &definition, memory.store());

    const started = try durable.handle(.{}, 44, 1001, .{ .start = 7 });
    try std.testing.expectEqual(Durable.HandleStatus.committed, started.status);
    try std.testing.expectEqual(State.running, started.snapshot.state);
    try std.testing.expectEqual(@as(u64, 7), started.snapshot.context.total);
    try std.testing.expectEqual(@as(usize, 1), started.commands().len);
    try std.testing.expectEqual(@as(u64, 7), started.commands()[0].execute);
    try std.testing.expectEqual(@as(usize, 1), memory.count());

    const restored = (try durable.restore(44)).?;
    try std.testing.expectEqual(State.running, restored.state);
    try std.testing.expectEqual(@as(u64, 1), restored.revision);

    const finished = try durable.handle(.{}, 44, 1002, .finish);
    try std.testing.expectEqual(State.done, finished.snapshot.state);
    try std.testing.expectEqual(fx.statechart.SnapshotStatus.done, finished.snapshot.status);
    try std.testing.expectEqual(@as(usize, 2), memory.count());
}

test "durable statechart event ids are idempotent across retries" {
    const allocator = std.testing.allocator;
    var memory = Durable.InMemoryJournal.init(allocator);
    defer memory.deinit();
    var durable = Durable.init(allocator, &definition, memory.store());

    const committed = try durable.handle(.{}, 5, 77, .{ .start = 3 });
    const retried = try durable.handle(.{}, 5, 77, .{ .start = 999 });

    try std.testing.expectEqual(Durable.HandleStatus.committed, committed.status);
    try std.testing.expectEqual(Durable.HandleStatus.duplicate, retried.status);
    try std.testing.expectEqual(committed.sequence, retried.sequence);
    try std.testing.expectEqual(@as(u64, 3), retried.snapshot.context.total);
    try std.testing.expectEqual(@as(usize, 1), memory.count());
}

test "durable command receipts are idempotent and use stable command ids" {
    const allocator = std.testing.allocator;
    var memory = Durable.InMemoryJournal.init(allocator);
    defer memory.deinit();
    var durable = Durable.init(allocator, &definition, memory.store());
    _ = try durable.handle(.{}, 9, 88, .{ .start = 4 });

    const first = try durable.markCommand(9, 88, 0, .completed);
    const repeated = try durable.markCommand(9, 88, 0, .completed);
    try std.testing.expectEqual(Durable.ReceiptStatus.committed, first.status);
    try std.testing.expectEqual(Durable.ReceiptStatus.duplicate, repeated.status);
    try std.testing.expectEqual(first.sequence, repeated.sequence);
    try std.testing.expectEqual(@as(usize, 2), memory.count());

    const left = Durable.commandId(9, 88, 0);
    const right = Durable.commandId(9, 88, 0);
    try std.testing.expect(left != 0);
    try std.testing.expectEqual(left, right);
    try std.testing.expect(left != Durable.commandId(9, 88, 1));
}

test "durable statechart journals isolate instances" {
    const allocator = std.testing.allocator;
    var memory = Durable.InMemoryJournal.init(allocator);
    defer memory.deinit();
    var durable = Durable.init(allocator, &definition, memory.store());

    _ = try durable.handle(.{}, 1, 10, .{ .start = 2 });
    _ = try durable.handle(.{}, 2, 10, .{ .start = 8 });
    try std.testing.expectEqual(@as(u64, 2), (try durable.restore(1)).?.context.total);
    try std.testing.expectEqual(@as(u64, 8), (try durable.restore(2)).?.context.total);
}

test "durable statechart rejects replay with another definition fingerprint" {
    const allocator = std.testing.allocator;
    var memory = Durable.InMemoryJournal.init(allocator);
    defer memory.deinit();
    var durable = Durable.init(allocator, &definition, memory.store());
    _ = try durable.handle(.{}, 7, 1, .{ .start = 1 });

    const changed = Def.init(.{
        .id = "agent.durable",
        .version = 2,
        .initial = .idle,
        .states = definition.states,
        .transitions = definition.transitions,
    });
    var changed_durable = Durable.init(allocator, &changed, memory.store());
    try std.testing.expectError(error.DefinitionMismatch, changed_durable.restore(7));
}

test "durable statechart record schema is public" {
    try std.testing.expectEqualStrings("zigeffect.workflow.statechart-record.v1", fx.workflow.statechart_record_schema);
    try std.testing.expectEqual(@as(u32, 1), fx.workflow.statechart_record_schema_version);
}

const HierState = enum { root, work, left, left_idle, left_done, right, right_idle, right_done, complete };
const HierEvent = union(enum) { boot, advance, done: HierState };
const HierCommand = enum { initialized };
const HierDef = fx.statechart.Definition(HierState, HierEvent, void, HierCommand);
const HierDurable = fx.workflow.DurableConfigurationStatechart(HierDef);

fn initializeHierarchy(_: *void, _: *const HierEvent, sink: *HierDef.CommandSink) anyerror!void {
    try sink.emit(.initialized);
}

fn hierarchyCompletion(state: HierState) ?HierEvent {
    return .{ .done = state };
}

const hierarchical_definition = HierDef.init(.{
    .id = "agent.durable-hierarchy",
    .version = 1,
    .initial = .root,
    .completion = .{ .id = "done-state", .event_for = hierarchyCompletion },
    .states = &.{
        .{ .id = .root, .kind = .compound, .initial = .work, .entry_actions = &.{.{ .id = "initialize", .execute = initializeHierarchy }} },
        .{ .id = .work, .kind = .parallel, .parent = .root },
        .{ .id = .left, .kind = .compound, .parent = .work, .initial = .left_idle },
        .{ .id = .left_idle, .parent = .left },
        .{ .id = .left_done, .kind = .final, .parent = .left },
        .{ .id = .right, .kind = .compound, .parent = .work, .initial = .right_idle },
        .{ .id = .right_idle, .parent = .right },
        .{ .id = .right_done, .kind = .final, .parent = .right },
        .{ .id = .complete, .kind = .final, .parent = .root },
    },
    .transitions = &.{
        .{ .id = "advance-left", .source = .left_idle, .event = .advance, .target = .left_done },
        .{ .id = "advance-right", .source = .right_idle, .event = .advance, .target = .right_done },
        .{ .id = "complete-work", .source = .work, .event = .done, .target = .complete },
    },
});

test "durable configuration statecharts journal initialization parallel configuration and completion" {
    const allocator = std.testing.allocator;
    var memory = HierDurable.InMemoryJournal.init(allocator);
    defer memory.deinit();
    var durable = HierDurable.init(allocator, &hierarchical_definition, memory.store());

    const initialized = try durable.initialize({}, 60, 6000, .boot);
    try std.testing.expectEqual(HierDurable.HandleStatus.committed, initialized.status);
    try std.testing.expectEqualSlices(HierCommand, &.{.initialized}, initialized.commands());
    try std.testing.expect(initialized.snapshot.isActive(.left_idle));
    try std.testing.expect(initialized.snapshot.isActive(.right_idle));

    const advanced = try durable.handle({}, 60, 6001, .advance);
    try std.testing.expect(advanced.snapshot.isActive(.complete));
    try std.testing.expectEqual(fx.statechart.SnapshotStatus.done, advanced.snapshot.status);

    const restored = (try durable.restore(60)).?;
    try std.testing.expect(restored.isActive(.complete));
    try std.testing.expectEqual(@as(usize, 2), memory.count());

    const duplicate = try durable.handle({}, 60, 6001, .advance);
    try std.testing.expectEqual(HierDurable.HandleStatus.duplicate, duplicate.status);
    try std.testing.expectEqual(@as(usize, 2), memory.count());
}

const TimerAdapter = struct {
    fn execute(
        _: *anyopaque,
        workflow: *fx.workflow.WorkflowContext,
        _: u64,
        _: Command,
    ) anyerror!Durable.CommandExecution {
        return switch (try workflow.sleep("statechart-command-timer", 25)) {
            .suspended => .suspended,
            .fired => .{ .completed = .finish },
            .cancelled => .{ .failed = null },
        };
    }
};

test "statechart commands suspend on durable workflow timers and completion feeds a typed event back" {
    const allocator = std.testing.allocator;
    var statechart_memory = Durable.InMemoryJournal.init(allocator);
    defer statechart_memory.deinit();
    var durable = Durable.init(allocator, &definition, statechart_memory.store());

    var workflow_memory = fx.workflow.InMemoryJournalStore.init(allocator);
    defer workflow_memory.deinit();
    const workflow_store = workflow_memory.asJournalStore();
    var clock = fx.FakeClock.fake(1_000);
    var workflow = try fx.workflow.WorkflowContext.init(allocator, workflow_store, .{
        .workflow_id = 70,
        .execution_id = 700,
        .clock = &clock,
    });
    defer workflow.deinit();

    const started = try durable.handle(.{}, 70, 7000, .{ .start = 5 });
    var adapter_context: u8 = 0;
    const adapter = Durable.CommandAdapter{ .context = &adapter_context, .execute_fn = TimerAdapter.execute };
    const suspended = try durable.dispatchCommands(.{}, &started, &workflow, adapter, 8);
    try std.testing.expectEqual(@as(usize, 1), suspended.commands_suspended);
    try std.testing.expectEqual(State.running, suspended.snapshot.state);

    clock.sleep(25);
    var durable_clock = fx.workflow.DurableClock.init(allocator, workflow_store, 70, 700);
    try std.testing.expectEqual(@as(usize, 1), try durable_clock.fireDueTimers(clock.nowMs()));

    const completed = try durable.dispatchCommands(.{}, &started, &workflow, adapter, 8);
    try std.testing.expectEqual(@as(usize, 1), completed.commands_completed);
    try std.testing.expectEqual(@as(usize, 1), completed.outcome_events);
    try std.testing.expectEqual(State.done, completed.snapshot.state);
    try std.testing.expectEqual(@as(usize, 3), statechart_memory.count());
}

fn migrateStatechartRecord(record: *Durable.JournalRecord) anyerror!void {
    record.schema = fx.workflow.statechart_record_schema;
    record.schema_version = fx.workflow.statechart_record_schema_version;
}

test "durable statechart records fail closed on future schemas and require explicit migration for old schemas" {
    const allocator = std.testing.allocator;
    var memory = Durable.InMemoryJournal.init(allocator);
    defer memory.deinit();
    var durable = Durable.init(allocator, &definition, memory.store());
    _ = try durable.handle(.{}, 90, 9000, .{ .start = 1 });

    memory.records.items[0].schema_version = fx.workflow.statechart_record_schema_version + 1;
    try std.testing.expectError(error.FutureRecordSchemaVersion, durable.restore(90));

    memory.records.items[0].schema_version = 0;
    try std.testing.expectError(error.MissingRecordMigration, durable.restore(90));

    var migrated = Durable.initWithMigration(allocator, &definition, memory.store(), migrateStatechartRecord);
    const restored = (try migrated.restore(90)).?;
    try std.testing.expectEqual(State.running, restored.state);
}

const RecoveryAdapter = struct {
    fn execute(
        _: *anyopaque,
        _: *fx.workflow.WorkflowContext,
        _: u64,
        _: Command,
    ) anyerror!Durable.CommandExecution {
        return error.AdapterMustNotRepeatReceiptedCommand;
    }
};

test "dispatch recovers a typed outcome event after a crash between command receipt and machine event" {
    const allocator = std.testing.allocator;
    var statechart_memory = Durable.InMemoryJournal.init(allocator);
    defer statechart_memory.deinit();
    var durable = Durable.init(allocator, &definition, statechart_memory.store());
    const started = try durable.handle(.{}, 91, 9100, .{ .start = 2 });

    _ = try durable.recordCommandOutcome(91, 9100, 0, .completed, .finish);
    // Simulate process loss here: the receipt is durable, but the corresponding
    // machine event has not yet been appended.

    var workflow_memory = fx.workflow.InMemoryJournalStore.init(allocator);
    defer workflow_memory.deinit();
    var workflow = try fx.workflow.WorkflowContext.init(allocator, workflow_memory.asJournalStore(), .{
        .workflow_id = 91,
        .execution_id = 910,
    });
    defer workflow.deinit();
    var adapter_context: u8 = 0;
    const recovered = try durable.dispatchCommands(.{}, &started, &workflow, .{
        .context = &adapter_context,
        .execute_fn = RecoveryAdapter.execute,
    }, 8);

    try std.testing.expectEqual(@as(usize, 1), recovered.receipts_recovered);
    try std.testing.expectEqual(State.done, recovered.snapshot.state);
    try std.testing.expectEqual(@as(usize, 3), statechart_memory.count());
}

const LeaseValidator = struct {
    storage: fx.RunnerStorage,
    fence: fx.ShardLeaseFence,

    fn validateOpaque(context: *anyopaque) anyerror!u64 {
        const self: *LeaseValidator = @ptrCast(@alignCast(context));
        try fx.validateShardFence(self.storage, self.fence);
        return self.fence.epoch;
    }
};

test "durable statechart journal commits are fenced by the real cluster lease store" {
    const allocator = std.testing.allocator;
    var lease_memory = fx.InMemoryRunnerStorage.init(allocator);
    defer lease_memory.deinit();
    const storage = lease_memory.asRunnerStorage();
    const owner_a = fx.runnerAddress("statechart", "runner-a");
    const owner_b = fx.runnerAddress("statechart", "runner-b");
    const lease = try storage.acquire(.{ .shard_id = 3, .owner = owner_a, .now_ms = 1_000, .ttl_ms = 500 });
    var validator = LeaseValidator{ .storage = storage, .fence = fx.fenceFromLease(lease) };

    var statechart_memory = Durable.InMemoryJournal.init(allocator);
    defer statechart_memory.deinit();
    var fenced = Durable.FencedJournal.init(statechart_memory.store(), .{
        .context = &validator,
        .validate_fn = LeaseValidator.validateOpaque,
    });
    var durable = Durable.init(allocator, &definition, fenced.store());
    _ = try durable.handle(.{}, 92, 9200, .{ .start = 1 });
    try std.testing.expectEqual(lease.epoch, statechart_memory.records.items[0].fence_epoch);

    try storage.release(.{ .shard_id = 3, .owner = owner_a });
    _ = try storage.acquire(.{ .shard_id = 3, .owner = owner_b, .now_ms = 1_100, .ttl_ms = 500 });
    try std.testing.expectError(error.StaleShardFence, durable.handle(.{}, 92, 9201, .finish));
    try std.testing.expectEqual(@as(usize, 1), statechart_memory.count());
}

test "checkpoint compaction preserves latest state and event idempotency without re-emitting old commands" {
    const allocator = std.testing.allocator;
    var memory = Durable.InMemoryJournal.init(allocator);
    defer memory.deinit();
    var durable = Durable.init(allocator, &definition, memory.store());
    _ = try durable.handle(.{}, 93, 9300, .{ .start = 3 });

    const checkpoint_sequence = try durable.checkpointAndCompact(93, 9399);
    try std.testing.expectEqual(@as(u64, 2), checkpoint_sequence);
    try std.testing.expect(memory.records.items[0].snapshot == null);
    try std.testing.expect(memory.records.items[1].snapshot != null);

    const restored = (try durable.restore(93)).?;
    try std.testing.expectEqual(State.running, restored.state);
    const duplicate = try durable.handle(.{}, 93, 9300, .{ .start = 999 });
    try std.testing.expectEqual(Durable.HandleStatus.duplicate, duplicate.status);
    try std.testing.expectEqual(@as(usize, 0), duplicate.commands().len);
    try std.testing.expectEqual(@as(u64, 3), duplicate.snapshot.context.total);
    try std.testing.expectEqual(@as(usize, 2), memory.count());
}
