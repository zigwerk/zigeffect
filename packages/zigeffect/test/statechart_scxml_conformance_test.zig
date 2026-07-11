const std = @import("std");
const fx = @import("zigeffect");

const State = enum {
    root,
    outside,
    parallel_work,
    left,
    left_idle,
    left_target,
    right,
    right_idle,
    right_target,
    finished,
};
const Event = enum { enter_descendant, advance, leave };
const Def = fx.statechart.Definition(State, Event, void, void);
const Runtime = fx.statechart.ConfigurationMachine(Def);

const parallel_entry_definition = Def.init(.{
    .id = "scxml.parallel-descendant-entry",
    .version = 1,
    .initial = .root,
    .states = &.{
        .{ .id = .root, .kind = .compound, .initial = .outside },
        .{ .id = .outside, .parent = .root },
        .{ .id = .parallel_work, .kind = .parallel, .parent = .root },
        .{ .id = .left, .kind = .compound, .parent = .parallel_work, .initial = .left_idle },
        .{ .id = .left_idle, .parent = .left },
        .{ .id = .left_target, .parent = .left },
        .{ .id = .right, .kind = .compound, .parent = .parallel_work, .initial = .right_idle },
        .{ .id = .right_idle, .parent = .right },
        .{ .id = .right_target, .parent = .right },
        .{ .id = .finished, .kind = .final, .parent = .root },
    },
    .transitions = &.{
        .{ .id = "enter-left-target", .source = .outside, .event = .enter_descendant, .target = .left_target },
    },
});

test "SCXML entering one descendant of a parallel state enters every sibling region" {
    const initial = try Runtime.initial(&parallel_entry_definition, {}, 40);
    const decision = try Runtime.step(&parallel_entry_definition, initial, .enter_descendant);

    try std.testing.expect(decision.next.isActive(.parallel_work));
    try std.testing.expect(decision.next.isActive(.left_target));
    try std.testing.expect(decision.next.isActive(.right_idle));
    try std.testing.expectEqualSlices(State, &.{ .left_target, .right_idle }, decision.next.activeAtomicStates());
}

const ReentryState = enum { active };
const ReentryEvent = enum { boot, cycle };
const ReentryContext = struct { order: u32 = 0 };
const ReentryDef = fx.statechart.Definition(ReentryState, ReentryEvent, ReentryContext, void);
const ReentryRuntime = fx.statechart.ConfigurationMachine(ReentryDef);

fn append(comptime digit: u32) *const fn (*ReentryContext, *const ReentryEvent, *ReentryDef.CommandSink) anyerror!void {
    return struct {
        fn run(context: *ReentryContext, _: *const ReentryEvent, _: *ReentryDef.CommandSink) anyerror!void {
            context.order = context.order * 10 + digit;
        }
    }.run;
}

const external_self_definition = ReentryDef.init(.{
    .id = "scxml.external-self-reentry",
    .version = 1,
    .initial = .active,
    .states = &.{.{
        .id = .active,
        .entry_actions = &.{.{ .id = "enter", .execute = append(3) }},
        .exit_actions = &.{.{ .id = "exit", .execute = append(1) }},
    }},
    .transitions = &.{.{
        .id = "cycle",
        .source = .active,
        .event = .cycle,
        .target = .active,
        .actions = &.{.{ .id = "transition", .execute = append(2) }},
    }},
});

test "SCXML external self transition exits, executes content, and re-enters" {
    const initialized = try ReentryRuntime.initialize(&external_self_definition, .{}, 41, .boot);
    const decision = try ReentryRuntime.step(&external_self_definition, initialized.snapshot, .cycle);

    try std.testing.expectEqual(@as(u32, 3123), decision.next.context.order);
    try std.testing.expectEqual(@as(usize, 3), decision.actions().len);
    try std.testing.expectEqual(ReentryRuntime.ActionPhase.exit, decision.actions()[0].phase);
    try std.testing.expectEqual(ReentryRuntime.ActionPhase.transition, decision.actions()[1].phase);
    try std.testing.expectEqual(ReentryRuntime.ActionPhase.entry, decision.actions()[2].phase);
}

const ConflictState = enum { root, work, left, left_idle, right, right_idle, right_done, outside };
const ConflictEvent = enum { go };
const ConflictDef = fx.statechart.Definition(ConflictState, ConflictEvent, void, void);
const ConflictRuntime = fx.statechart.ConfigurationMachine(ConflictDef);

const conflict_definition = ConflictDef.init(.{
    .id = "scxml.parallel-conflicting-exit-set",
    .version = 1,
    .initial = .root,
    .states = &.{
        .{ .id = .root, .kind = .compound, .initial = .work },
        .{ .id = .work, .kind = .parallel, .parent = .root },
        .{ .id = .left, .kind = .compound, .parent = .work, .initial = .left_idle },
        .{ .id = .left_idle, .parent = .left },
        .{ .id = .right, .kind = .compound, .parent = .work, .initial = .right_idle },
        .{ .id = .right_idle, .parent = .right },
        .{ .id = .right_done, .parent = .right },
        .{ .id = .outside, .parent = .root },
    },
    .transitions = &.{
        .{ .id = "advance-right", .source = .right_idle, .event = .go, .target = .right_done },
        .{ .id = "leave-parallel", .source = .left_idle, .event = .go, .target = .outside },
    },
});

test "SCXML document-order priority resolves conflicting parallel exit sets" {
    const initial = try ConflictRuntime.initial(&conflict_definition, {}, 42);
    const decision = try ConflictRuntime.step(&conflict_definition, initial, .go);

    try std.testing.expectEqualSlices([]const u8, &.{"leave-parallel"}, decision.transitionIds());
    try std.testing.expect(decision.next.isActive(.outside));
    try std.testing.expect(!decision.next.isActive(.right_done));
}

const InternalState = enum { root, first, second };
const InternalEvent = enum { boot, switch_child };
const InternalContext = struct { order: u32 = 0 };
const InternalDef = fx.statechart.Definition(InternalState, InternalEvent, InternalContext, void);
const InternalRuntime = fx.statechart.ConfigurationMachine(InternalDef);

fn appendInternal(comptime digit: u32) *const fn (*InternalContext, *const InternalEvent, *InternalDef.CommandSink) anyerror!void {
    return struct {
        fn run(context: *InternalContext, _: *const InternalEvent, _: *InternalDef.CommandSink) anyerror!void {
            context.order = context.order * 10 + digit;
        }
    }.run;
}

const internal_descendant_definition = InternalDef.init(.{
    .id = "scxml.internal-descendant-domain",
    .version = 1,
    .initial = .root,
    .states = &.{
        .{
            .id = .root,
            .kind = .compound,
            .initial = .first,
            .entry_actions = &.{.{ .id = "enter-root", .execute = appendInternal(3) }},
            .exit_actions = &.{.{ .id = "exit-root", .execute = appendInternal(1) }},
        },
        .{ .id = .first, .parent = .root, .exit_actions = &.{.{ .id = "exit-first", .execute = appendInternal(4) }} },
        .{ .id = .second, .parent = .root, .entry_actions = &.{.{ .id = "enter-second", .execute = appendInternal(5) }} },
    },
    .transitions = &.{.{
        .id = "switch-child",
        .source = .root,
        .event = .switch_child,
        .target = .second,
        .kind = .internal,
        .actions = &.{.{ .id = "transition", .execute = appendInternal(2) }},
    }},
});

test "SCXML internal descendant transition preserves its compound source" {
    const initialized = try InternalRuntime.initialize(&internal_descendant_definition, .{}, 43, .boot);
    const decision = try InternalRuntime.step(&internal_descendant_definition, initialized.snapshot, .switch_child);

    try std.testing.expectEqual(@as(u32, 3425), decision.next.context.order);
    try std.testing.expectEqual(@as(usize, 3), decision.actions().len);
    try std.testing.expectEqualStrings("exit-first", decision.actions()[0].action_id);
    try std.testing.expectEqualStrings("transition", decision.actions()[1].action_id);
    try std.testing.expectEqualStrings("enter-second", decision.actions()[2].action_id);
}

const CompletionState = enum { root, container, complete };
const CompletionEvent = union(enum) { boot, cycle, done: CompletionState };
const CompletionDef = fx.statechart.Definition(CompletionState, CompletionEvent, void, void);
const CompletionRuntime = fx.statechart.ConfigurationMachine(CompletionDef);

fn completionEvent(state: CompletionState) ?CompletionEvent {
    return .{ .done = state };
}

const completion_reentry_definition = CompletionDef.init(.{
    .id = "scxml.completion-reentry",
    .version = 1,
    .initial = .root,
    .completion = .{ .id = "done-state", .event_for = completionEvent },
    .states = &.{
        .{ .id = .root, .kind = .compound, .initial = .container },
        .{ .id = .container, .kind = .compound, .parent = .root, .initial = .complete },
        .{ .id = .complete, .kind = .final, .parent = .container },
    },
    .transitions = &.{.{ .id = "reenter-complete", .source = .container, .event = .cycle, .target = .complete }},
});

test "SCXML completion events are emitted once per completed boundary entry" {
    const initialized = try CompletionRuntime.initialize(&completion_reentry_definition, {}, 44, .boot);
    try std.testing.expectEqual(@as(usize, 1), initialized.internalEvents().len);
    try std.testing.expectEqual(CompletionState.container, initialized.internalEvents()[0].done);

    const decision = try CompletionRuntime.step(&completion_reentry_definition, initialized.snapshot, .cycle);
    try std.testing.expectEqual(@as(usize, 1), decision.internalEvents().len);
    try std.testing.expectEqual(CompletionState.container, decision.internalEvents()[0].done);
}
