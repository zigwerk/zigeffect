const std = @import("std");
const fx = @import("zigeffect");

const State = enum {
    root,
    working,
    left,
    left_idle,
    left_done,
    right,
    right_idle,
    right_done,
    cancelled,
};
const Event = enum { advance, cancel };
const Context = struct { actions: u32 = 0 };
const Command = enum { observed };
const Def = fx.statechart.Definition(State, Event, Context, Command);
const Runtime = fx.statechart.ConfigurationMachine(Def);

fn count(context: *Context, _: *const Event, _: *Def.CommandSink) anyerror!void {
    context.actions += 1;
}

const count_action = Def.Action{ .id = "count", .execute = count };

const definition = Def.init(.{
    .id = "agent.parallel-review",
    .version = 1,
    .initial = .root,
    .states = &.{
        .{ .id = .root, .kind = .compound, .initial = .working },
        .{ .id = .working, .kind = .parallel, .parent = .root },
        .{ .id = .left, .kind = .compound, .parent = .working, .initial = .left_idle },
        .{ .id = .left_idle, .parent = .left },
        .{ .id = .left_done, .kind = .final, .parent = .left },
        .{ .id = .right, .kind = .compound, .parent = .working, .initial = .right_idle },
        .{ .id = .right_idle, .parent = .right },
        .{ .id = .right_done, .kind = .final, .parent = .right },
        .{ .id = .cancelled, .kind = .final, .parent = .root },
    },
    .transitions = &.{
        .{ .id = "advance-left", .source = .left_idle, .event = .advance, .target = .left_done, .actions = &.{count_action} },
        .{ .id = "advance-right", .source = .right_idle, .event = .advance, .target = .right_done, .actions = &.{count_action} },
        .{ .id = "cancel-all", .source = .working, .event = .cancel, .target = .cancelled },
    },
});

const HistoryState = enum { root, app, section, a, b, shallow, deep, away };
const HistoryEvent = enum { advance, leave, resume_shallow, resume_deep };
const HistoryContext = struct { order: u64 = 0 };
const HistoryDef = fx.statechart.Definition(HistoryState, HistoryEvent, HistoryContext, void);
const HistoryRuntime = fx.statechart.ConfigurationMachine(HistoryDef);

fn appendHistoryDigit(comptime digit: u64) *const fn (*HistoryContext, *const HistoryEvent, *HistoryDef.CommandSink) anyerror!void {
    return struct {
        fn run(context: *HistoryContext, _: *const HistoryEvent, _: *HistoryDef.CommandSink) anyerror!void {
            context.order = context.order * 10 + digit;
        }
    }.run;
}

const exit_b = HistoryDef.Action{ .id = "exit-b", .execute = appendHistoryDigit(1) };
const exit_section = HistoryDef.Action{ .id = "exit-section", .execute = appendHistoryDigit(2) };
const exit_app = HistoryDef.Action{ .id = "exit-app", .execute = appendHistoryDigit(3) };
const leave_action = HistoryDef.Action{ .id = "leave", .execute = appendHistoryDigit(4) };
const enter_away = HistoryDef.Action{ .id = "enter-away", .execute = appendHistoryDigit(5) };
const history_default_action = HistoryDef.Action{ .id = "history-default", .execute = appendHistoryDigit(6) };

fn allowHistoryDefault(_: *const HistoryContext, event: *const HistoryEvent) bool {
    return event.* == .resume_shallow;
}

const history_definition = HistoryDef.init(.{
    .id = "agent.history",
    .version = 1,
    .initial = .root,
    .states = &.{
        .{ .id = .root, .kind = .compound, .initial = .app },
        .{ .id = .app, .kind = .compound, .parent = .root, .initial = .section, .exit_actions = &.{exit_app} },
        .{ .id = .section, .kind = .compound, .parent = .app, .initial = .a, .exit_actions = &.{exit_section} },
        .{ .id = .a, .parent = .section },
        .{ .id = .b, .parent = .section, .exit_actions = &.{exit_b} },
        .{ .id = .shallow, .kind = .history_shallow, .parent = .app },
        .{ .id = .deep, .kind = .history_deep, .parent = .app },
        .{ .id = .away, .parent = .root, .entry_actions = &.{enter_away} },
    },
    .transitions = &.{
        .{ .id = "advance", .source = .a, .event = .advance, .target = .b },
        .{ .id = "leave", .source = .b, .event = .leave, .target = .away, .actions = &.{leave_action} },
        .{ .id = "resume-shallow", .source = .away, .event = .resume_shallow, .target = .shallow },
        .{ .id = "resume-deep", .source = .away, .event = .resume_deep, .target = .deep },
        .{ .id = "shallow-default", .source = .shallow, .target = .section },
        .{ .id = "deep-default", .source = .deep, .target = .section },
    },
});

const history_default_definition = HistoryDef.init(.{
    .id = "agent.history-default",
    .version = 1,
    .initial = .root,
    .states = &.{
        .{ .id = .root, .kind = .compound, .initial = .away },
        .{ .id = .app, .kind = .compound, .parent = .root, .initial = .section },
        .{ .id = .section, .kind = .compound, .parent = .app, .initial = .a },
        .{ .id = .a, .parent = .section },
        .{ .id = .b, .parent = .section },
        .{ .id = .shallow, .kind = .history_shallow, .parent = .app },
        .{ .id = .deep, .kind = .history_deep, .parent = .app },
        .{ .id = .away, .parent = .root },
    },
    .transitions = &.{
        .{ .id = "resume-shallow", .source = .away, .event = .resume_shallow, .target = .shallow },
        .{
            .id = "shallow-default",
            .source = .shallow,
            .target = .section,
            .guard = .{ .id = "allow-history-default", .evaluate = allowHistoryDefault },
            .actions = &.{history_default_action},
        },
    },
});

const DoneState = enum { root, work, left, left_idle, left_done, right, right_idle, right_done, complete };
const DoneEvent = union(enum) { advance, done: DoneState };
const DoneDef = fx.statechart.Definition(DoneState, DoneEvent, void, void);
const DoneRuntime = fx.statechart.ConfigurationMachine(DoneDef);
const DoneMacrostep = fx.statechart.ConfigurationMacrostep(DoneDef);
const DoneActor = fx.statechart.ConfigurationActor(DoneDef);
const DoneActorSystem = fx.statechart.ConfigurationActorSystem(DoneDef);

fn completionEvent(state: DoneState) ?DoneEvent {
    return .{ .done = state };
}

const done_definition = DoneDef.init(.{
    .id = "agent.completion-events",
    .version = 1,
    .initial = .root,
    .completion = .{ .id = "done-state", .event_for = completionEvent },
    .states = &.{
        .{ .id = .root, .kind = .compound, .initial = .work },
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
        .{ .id = "left", .source = .left_idle, .event = .advance, .target = .left_done },
        .{ .id = "right", .source = .right_idle, .event = .advance, .target = .right_done },
        .{ .id = "complete", .source = .work, .event = .done, .target = .complete },
    },
});

const InitState = enum { root, idle };
const InitEvent = enum { boot };
const InitContext = struct { order: u32 = 0 };
const InitCommand = enum { entered_root, entered_idle };
const InitDef = fx.statechart.Definition(InitState, InitEvent, InitContext, InitCommand);
const InitRuntime = fx.statechart.ConfigurationMachine(InitDef);
const InitMacro = fx.statechart.ConfigurationMacrostep(InitDef);
const InitActor = fx.statechart.ConfigurationActor(InitDef);

const InitExecutor = struct {
    count: usize = 0,

    fn executeOpaque(context: *anyopaque, _: InitCommand) anyerror!void {
        const self: *InitExecutor = @ptrCast(@alignCast(context));
        self.count += 1;
    }
};

fn enterRoot(context: *InitContext, _: *const InitEvent, sink: *InitDef.CommandSink) anyerror!void {
    context.order = context.order * 10 + 1;
    try sink.emit(.entered_root);
}

fn enterIdle(context: *InitContext, _: *const InitEvent, sink: *InitDef.CommandSink) anyerror!void {
    context.order = context.order * 10 + 2;
    try sink.emit(.entered_idle);
}

fn failIdle(context: *InitContext, _: *const InitEvent, sink: *InitDef.CommandSink) anyerror!void {
    context.order = 999;
    try sink.emit(.entered_idle);
    return error.SimulatedInitializationFailure;
}

const init_definition = InitDef.init(.{
    .id = "agent.initial-entry",
    .version = 1,
    .initial = .root,
    .states = &.{
        .{ .id = .root, .kind = .compound, .initial = .idle, .entry_actions = &.{.{ .id = "enter-root", .execute = enterRoot }} },
        .{ .id = .idle, .parent = .root, .entry_actions = &.{.{ .id = "enter-idle", .execute = enterIdle }} },
    },
    .transitions = &.{},
});

const failing_init_definition = InitDef.init(.{
    .id = "agent.initial-entry-failure",
    .version = 1,
    .initial = .root,
    .states = &.{
        .{ .id = .root, .kind = .compound, .initial = .idle, .entry_actions = &.{.{ .id = "enter-root", .execute = enterRoot }} },
        .{ .id = .idle, .parent = .root, .entry_actions = &.{.{ .id = "fail-idle", .execute = failIdle }} },
    },
    .transitions = &.{},
});

const InvokeState = enum { root, running, idle };
const InvokeEvent = enum { boot, stop };
const InvokeCommand = enum { start_child, stop_child };
const InvokeDef = fx.statechart.Definition(InvokeState, InvokeEvent, void, InvokeCommand);
const InvokeActor = fx.statechart.ConfigurationActor(InvokeDef);

fn startChild(_: *void, _: *const InvokeEvent, sink: *InvokeDef.CommandSink) anyerror!void {
    try sink.emit(.start_child);
}

fn stopChild(_: *void, _: *const InvokeEvent, sink: *InvokeDef.CommandSink) anyerror!void {
    try sink.emit(.stop_child);
}

const invoke_definition = InvokeDef.init(.{
    .id = "agent.invoked-child",
    .version = 1,
    .initial = .root,
    .states = &.{
        .{ .id = .root, .kind = .compound, .initial = .running },
        .{ .id = .running, .parent = .root, .invocations = &.{.{
            .id = "researcher",
            .start = .{ .id = "start-researcher", .execute = startChild },
            .stop = .{ .id = "stop-researcher", .execute = stopChild },
        }} },
        .{ .id = .idle, .parent = .root },
    },
    .transitions = &.{.{ .id = "stop", .source = .running, .event = .stop, .target = .idle }},
});

const InvokeExecutor = struct {
    commands: [2]InvokeCommand = undefined,
    count: usize = 0,

    fn executeOpaque(context: *anyopaque, command: InvokeCommand) anyerror!void {
        const self: *InvokeExecutor = @ptrCast(@alignCast(context));
        self.commands[self.count] = command;
        self.count += 1;
    }
};

test "configuration machine resolves compound initials and every parallel region" {
    const snapshot = try Runtime.initial(&definition, .{}, 17);

    try std.testing.expect(snapshot.isActive(.root));
    try std.testing.expect(snapshot.isActive(.working));
    try std.testing.expect(snapshot.isActive(.left_idle));
    try std.testing.expect(snapshot.isActive(.right_idle));
    try std.testing.expectEqual(@as(usize, 2), snapshot.activeAtomicStates().len);
    try std.testing.expectEqual(State.left_idle, snapshot.activeAtomicStates()[0]);
    try std.testing.expectEqual(State.right_idle, snapshot.activeAtomicStates()[1]);
}

test "parallel regions select and commit conflict-free transitions in definition order" {
    const snapshot = try Runtime.initial(&definition, .{}, 18);
    const decision = try Runtime.step(&definition, snapshot, .advance);

    try std.testing.expectEqualSlices([]const u8, &.{ "advance-left", "advance-right" }, decision.transitionIds());
    try std.testing.expect(decision.next.isActive(.left_done));
    try std.testing.expect(decision.next.isActive(.right_done));
    try std.testing.expect(!decision.next.isActive(.left_idle));
    try std.testing.expectEqual(@as(u32, 2), decision.next.context.actions);
}

test "ancestor transition exits the complete parallel configuration" {
    const snapshot = try Runtime.initial(&definition, .{}, 19);
    const decision = try Runtime.step(&definition, snapshot, .cancel);

    try std.testing.expectEqual(@as(usize, 1), decision.transitionIds().len);
    try std.testing.expectEqualStrings("cancel-all", decision.transitionIds()[0]);
    try std.testing.expect(decision.next.isActive(.cancelled));
    try std.testing.expect(!decision.next.isActive(.working));
    try std.testing.expect(!decision.next.isActive(.left_idle));
    try std.testing.expect(!decision.next.isActive(.right_idle));
    try std.testing.expectEqual(Runtime.SnapshotStatus.done, decision.next.status);
}

test "a descendant transition preempts a conflicting ancestor transition" {
    const with_specific = Def.init(.{
        .id = "agent.preemption",
        .version = 1,
        .initial = .root,
        .states = definition.states,
        .transitions = &.{
            .{ .id = "left-cancel", .source = .left_idle, .event = .cancel, .target = .left_done },
            .{ .id = "cancel-all", .source = .working, .event = .cancel, .target = .cancelled },
        },
    });
    const snapshot = try Runtime.initial(&with_specific, .{}, 20);
    const decision = try Runtime.step(&with_specific, snapshot, .cancel);

    try std.testing.expectEqualSlices([]const u8, &.{"left-cancel"}, decision.transitionIds());
    try std.testing.expect(decision.next.isActive(.left_done));
    try std.testing.expect(decision.next.isActive(.right_idle));
}

test "shallow and deep history restore the documented configuration depth" {
    var snapshot = try HistoryRuntime.initial(&history_definition, .{}, 21);
    snapshot = (try HistoryRuntime.step(&history_definition, snapshot, .advance)).next;
    const left = try HistoryRuntime.step(&history_definition, snapshot, .leave);
    try std.testing.expectEqual(@as(u64, 12345), left.next.context.order);

    const shallow = try HistoryRuntime.step(&history_definition, left.next, .resume_shallow);
    try std.testing.expect(shallow.next.isActive(.a));
    try std.testing.expect(!shallow.next.isActive(.b));

    snapshot = (try HistoryRuntime.step(&history_definition, shallow.next, .advance)).next;
    snapshot = (try HistoryRuntime.step(&history_definition, snapshot, .leave)).next;
    const deep = try HistoryRuntime.step(&history_definition, snapshot, .resume_deep);
    try std.testing.expect(deep.next.isActive(.b));
    try std.testing.expect(!deep.next.isActive(.a));
}

test "history default transition evaluates its guard and executes its actions" {
    const snapshot = try HistoryRuntime.initial(&history_default_definition, .{}, 27);
    const decision = try HistoryRuntime.step(&history_default_definition, snapshot, .resume_shallow);

    try std.testing.expect(decision.next.isActive(.a));
    try std.testing.expectEqual(@as(u64, 6), decision.next.context.order);
    try std.testing.expectEqualSlices([]const u8, &.{ "resume-shallow", "shallow-default" }, decision.transitionIds());
    try std.testing.expectEqual(@as(usize, 1), decision.guards().len);
    try std.testing.expect(decision.guards()[0].accepted);
    try std.testing.expectEqualStrings("history-default", decision.actions()[0].action_id);
}

test "parallel and compound completion raise typed done events" {
    const snapshot = try DoneRuntime.initial(&done_definition, {}, 22);
    const decision = try DoneRuntime.step(&done_definition, snapshot, .advance);

    try std.testing.expectEqual(@as(usize, 3), decision.internalEvents().len);
    try std.testing.expectEqual(DoneState.left, decision.internalEvents()[0].done);
    try std.testing.expectEqual(DoneState.right, decision.internalEvents()[1].done);
    try std.testing.expectEqual(DoneState.work, decision.internalEvents()[2].done);

    const stabilized = try DoneMacrostep.run(&done_definition, snapshot, .advance);
    try std.testing.expect(stabilized.next.isActive(.complete));
    try std.testing.expectEqual(DoneRuntime.SnapshotStatus.done, stabilized.next.status);
    try std.testing.expectEqual(@as(usize, 2), stabilized.microsteps().len);
    try std.testing.expectEqualStrings("complete", stabilized.microsteps()[1].transitionIds()[0]);
}

test "hierarchical actors and actor systems use configuration macrosteps" {
    var actor = try DoneActor.init(std.testing.allocator, &done_definition, {}, .{ .instance_id = 23 });
    defer actor.deinit();
    _ = try actor.send(.advance);
    const processed = try actor.processNext();
    try std.testing.expectEqual(DoneActor.ProcessStatus.processed, processed.status);
    try std.testing.expect(actor.snapshot().isActive(.complete));
    try std.testing.expectEqual(DoneActor.Status.completed, actor.status());

    var system = try DoneActorSystem.init(std.testing.allocator, &done_definition, .{ .capacity = 2, .dead_letter_capacity = 2 });
    defer system.deinit();
    try system.spawn({}, .{ .instance_id = 24, .name = "hierarchical-review" });
    _ = try system.send("hierarchical-review", .advance, .{});
    const system_result = try system.process("hierarchical-review");
    try std.testing.expect(system_result.snapshot.isActive(.complete));
}

test "initialization executes entry actions transactionally from shallow to deep" {
    try std.testing.expectError(error.MissingInitializationEvent, InitRuntime.initial(&init_definition, .{}, 25));

    const initialized = try InitRuntime.initialize(&init_definition, .{}, 25, .boot);
    try std.testing.expectEqual(@as(u32, 12), initialized.snapshot.context.order);
    try std.testing.expectEqualSlices(InitCommand, &.{ .entered_root, .entered_idle }, initialized.commands());
    try std.testing.expectEqual(@as(usize, 2), initialized.actions().len);
    try std.testing.expectEqual(InitState.root, initialized.actions()[0].state);
    try std.testing.expectEqual(InitState.idle, initialized.actions()[1].state);
}

test "failed initial entry action publishes no partial initialization" {
    try std.testing.expectError(
        error.ActionFailed,
        InitRuntime.initialize(&failing_init_definition, .{}, 26, .boot),
    );
}

test "configuration macrostep preserves initialization commands" {
    const initialized = try InitMacro.initialize(&init_definition, .{}, 28, .boot);
    try std.testing.expectEqual(@as(u32, 12), initialized.next.context.order);
    try std.testing.expectEqualSlices(InitCommand, &.{ .entered_root, .entered_idle }, initialized.commands());
    try std.testing.expect(initialized.fingerprint != 0);
}

test "configuration actor startup executes the complete initialization macrostep" {
    var executor = InitExecutor{};
    var actor = try InitActor.initWithEvent(std.testing.allocator, &init_definition, .{}, .boot, .{
        .instance_id = 29,
        .executor = .{ .context = &executor, .execute_fn = InitExecutor.executeOpaque },
    });
    defer actor.deinit();

    try std.testing.expectEqual(@as(u32, 12), actor.snapshot().context.order);
    try std.testing.expectEqual(@as(usize, 2), executor.count);
}

test "state lifetime automatically starts and stops invoked child actors through commands" {
    var executor = InvokeExecutor{};
    var actor = try InvokeActor.initWithEvent(std.testing.allocator, &invoke_definition, {}, .boot, .{
        .instance_id = 30,
        .executor = .{ .context = &executor, .execute_fn = InvokeExecutor.executeOpaque },
    });
    defer actor.deinit();
    try std.testing.expectEqualSlices(InvokeCommand, &.{.start_child}, executor.commands[0..executor.count]);

    _ = try actor.send(.stop);
    _ = try actor.processNext();
    try std.testing.expectEqualSlices(InvokeCommand, &.{ .start_child, .stop_child }, executor.commands[0..executor.count]);
    try std.testing.expect(actor.snapshot().isActive(.idle));
}
