const std = @import("std");
const fx = @import("zigeffect");

const State = enum {
    idle,
    running,
    done,
};

const Event = union(enum) {
    start: struct { request_id: u64 },
    finish,
};

const Context = struct {
    attempts: u32 = 0,
};

const Command = union(enum) {
    begin_work: u64,
    publish_result,
};

const Def = fx.statechart.Definition(State, Event, Context, Command);

fn canStart(context: *const Context, event: *const Event) bool {
    return context.attempts < 3 and event.* == .start;
}

fn incrementAttempts(context: *Context, _: *const Event, _: *Def.CommandSink) anyerror!void {
    context.attempts += 1;
}

const start_guard = Def.Guard{
    .id = "can-start",
    .evaluate = canStart,
};

const increment_attempts = Def.Action{
    .id = "increment-attempts",
    .execute = incrementAttempts,
};

const valid_definition = Def.init(.{
    .id = "agent.job",
    .version = 1,
    .initial = .idle,
    .states = &.{
        .{ .id = .idle, .description = "Waiting for work" },
        .{ .id = .running, .description = "Executing typed commands" },
        .{ .id = .done, .kind = .final, .description = "Completed" },
    },
    .transitions = &.{
        .{
            .id = "start",
            .source = .idle,
            .event = .start,
            .target = .running,
            .guard = start_guard,
            .actions = &.{increment_attempts},
            .description = "Accept a bounded unit of agent work",
        },
        .{
            .id = "finish",
            .source = .running,
            .event = .finish,
            .target = .done,
        },
    },
});

test "statechart definition exposes typed metadata and stable event tags" {
    const metadata = valid_definition.metadata();

    try std.testing.expectEqualStrings("agent.job", metadata.id);
    try std.testing.expectEqual(@as(u32, 1), metadata.version);
    try std.testing.expectEqualStrings(@typeName(State), metadata.state_type_name);
    try std.testing.expectEqualStrings(@typeName(Event), metadata.event_type_name);
    try std.testing.expectEqualStrings(@typeName(Context), metadata.context_type_name);
    try std.testing.expectEqualStrings(@typeName(Command), metadata.command_type_name);
    try std.testing.expectEqual(@as(usize, 3), metadata.state_count);
    try std.testing.expectEqual(@as(usize, 2), metadata.transition_count);

    const start = Event{ .start = .{ .request_id = 42 } };
    try std.testing.expectEqual(Def.EventTag.start, Def.eventTag(start));
    try std.testing.expectEqual(Def.EventTag.finish, Def.eventTag(.finish));
}

test "statechart context value semantics are recursively enforced" {
    const Valid = struct {
        count: u64,
        flags: [4]bool,
        mode: ?enum { safe, fast },
        result: union(enum) { pending, complete: u32 },
    };
    const NestedSlice = struct { payload: struct { bytes: []const u8 } };
    const NestedPointer = struct { payload: ?*u64 };
    const FunctionAlias = struct { callback: *const fn () void };

    try std.testing.expect(fx.statechart.isValueContext(Valid));
    try std.testing.expect(!fx.statechart.isValueContext(NestedSlice));
    try std.testing.expect(!fx.statechart.isValueContext(NestedPointer));
    try std.testing.expect(!fx.statechart.isValueContext(FunctionAlias));
}

test "valid statechart definition has no findings and a stable fingerprint" {
    const report = valid_definition.validate();
    try std.testing.expect(report.isValid());
    try std.testing.expectEqual(@as(usize, 0), report.findings().len);
    try std.testing.expect(valid_definition.fingerprint() != 0);
    try std.testing.expectEqual(valid_definition.fingerprint(), valid_definition.fingerprint());

    const identical = Def.init(.{
        .id = "agent.job",
        .version = 1,
        .initial = .idle,
        .states = valid_definition.states,
        .transitions = valid_definition.transitions,
    });
    try std.testing.expectEqual(valid_definition.fingerprint(), identical.fingerprint());
}

test "definition validation reports duplicates missing states final transitions and invalid bounds" {
    const invalid = Def.init(.{
        .id = "agent.invalid",
        .version = 0,
        .initial = .idle,
        .bounds = .{
            .max_commands = 0,
            .max_internal_events = 0,
            .max_microsteps = 0,
        },
        .states = &.{
            .{ .id = .running, .kind = .final },
            .{ .id = .running },
        },
        .transitions = &.{
            .{ .id = "again", .source = .running, .event = .finish, .target = .done },
            .{ .id = "again", .source = .idle, .event = .start, .target = .running },
        },
    });

    const report = invalid.validate();
    try std.testing.expect(!report.isValid());
    try std.testing.expect(report.has(.invalid_version));
    try std.testing.expect(report.has(.missing_initial_state));
    try std.testing.expect(report.has(.duplicate_state));
    try std.testing.expect(report.has(.duplicate_transition_id));
    try std.testing.expect(report.has(.transition_source_not_declared));
    try std.testing.expect(report.has(.transition_target_not_declared));
    try std.testing.expect(report.has(.final_state_has_outgoing_transition));
    try std.testing.expect(report.has(.invalid_bounds));

    for (report.findings()) |finding| {
        try std.testing.expect(finding.id != 0);
        try std.testing.expect(finding.message.len != 0);
    }
}

test "definition fingerprints include symbolic guard and action ids" {
    const changed_guard = Def.Guard{
        .id = "can-start-v2",
        .evaluate = canStart,
    };
    const changed = Def.init(.{
        .id = "agent.job",
        .version = 1,
        .initial = .idle,
        .states = valid_definition.states,
        .transitions = &.{
            .{
                .id = "start",
                .source = .idle,
                .event = .start,
                .target = .running,
                .guard = changed_guard,
                .actions = &.{increment_attempts},
            },
            valid_definition.transitions[1],
        },
    });

    try std.testing.expect(valid_definition.fingerprint() != changed.fingerprint());
}

test "hierarchical definitions validate parent initial and node-kind invariants" {
    const HierState = enum { root, left, right, orphan, cycle_a, cycle_b };
    const HierEvent = enum { next };
    const HierDef = fx.statechart.Definition(HierState, HierEvent, void, void);
    const invalid = HierDef.init(.{
        .id = "agent.invalid-hierarchy",
        .version = 1,
        .initial = .root,
        .states = &.{
            .{ .id = .root, .kind = .compound, .initial = .orphan },
            .{ .id = .left, .parent = .root, .initial = .right },
            .{ .id = .right, .parent = .right },
            .{ .id = .orphan },
            .{ .id = .cycle_a, .kind = .compound, .parent = .cycle_b, .initial = .cycle_b },
            .{ .id = .cycle_b, .kind = .compound, .parent = .cycle_a, .initial = .cycle_a },
        },
        .transitions = &.{},
    });

    const report = invalid.validate();
    try std.testing.expect(report.has(.compound_initial_not_child));
    try std.testing.expect(report.has(.atomic_state_has_initial));
    try std.testing.expect(report.has(.state_parent_is_self));
    try std.testing.expect(report.has(.state_parent_cycle));
}

test "compound states require an initial child and non-container states reject children" {
    const HierState = enum { root, atomic_parent, child };
    const HierEvent = enum { next };
    const HierDef = fx.statechart.Definition(HierState, HierEvent, void, void);
    const invalid = HierDef.init(.{
        .id = "agent.missing-initial",
        .version = 1,
        .initial = .root,
        .states = &.{
            .{ .id = .root, .kind = .compound },
            .{ .id = .atomic_parent },
            .{ .id = .child, .parent = .atomic_parent },
        },
        .transitions = &.{},
    });

    const report = invalid.validate();
    try std.testing.expect(report.has(.compound_missing_initial));
    try std.testing.expect(report.has(.non_container_has_children));
}
