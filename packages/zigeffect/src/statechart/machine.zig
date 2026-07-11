const std = @import("std");
const value_hash = @import("../traits/hash.zig");

pub const max_decision_commands: usize = 64;
pub const max_decision_internal_events: usize = 64;
pub const max_decision_actions: usize = 256;
pub const max_decision_guards: usize = 128;

pub const SnapshotStatus = enum {
    active,
    done,
    failed,
    stopped,
};

pub const DecisionOutcome = enum {
    transitioned,
    ignored,
};

pub const ActionPhase = enum {
    exit,
    invoke_stop,
    transition,
    entry,
    invoke_start,
};

pub const StepError = error{
    InvalidDefinition,
    DefinitionMismatch,
    SnapshotNotActive,
    UnknownSnapshotState,
    CommandLimitExceeded,
    InternalEventLimitExceeded,
    ActionRecordLimitExceeded,
    GuardRecordLimitExceeded,
    ActionFailed,
    MissingInitializationEvent,
};

pub fn Machine(comptime DefinitionType: type) type {
    const State = DefinitionType.StateType;
    const Event = DefinitionType.EventType;
    const Context = DefinitionType.ContextType;
    const Command = DefinitionType.CommandType;
    const SnapshotStatusT = SnapshotStatus;
    const DecisionOutcomeT = DecisionOutcome;
    const ActionPhaseT = ActionPhase;
    const StepErrorT = StepError;

    return struct {
        const Self = @This();

        pub const Definition = DefinitionType;
        pub const SnapshotStatus = SnapshotStatusT;
        pub const DecisionOutcome = DecisionOutcomeT;
        pub const ActionPhase = ActionPhaseT;
        pub const StepError = StepErrorT;

        pub const Snapshot = struct {
            definition_fingerprint: u64,
            instance_id: u64,
            state: State,
            context: Context,
            status: SnapshotStatusT = .active,
            revision: u64 = 0,
            last_event_sequence: u64 = 0,
        };

        pub const ActionRecord = struct {
            phase: ActionPhaseT,
            action_id: []const u8,
        };

        pub const GuardRecord = struct {
            guard_id: []const u8,
            transition_id: []const u8,
            accepted: bool,
        };

        pub const Decision = struct {
            outcome: DecisionOutcomeT = .ignored,
            previous: Snapshot,
            next: Snapshot,
            selected_transition_id: []const u8 = "",
            selected_transition_index: ?usize = null,
            action_storage: [max_decision_actions]ActionRecord = undefined,
            action_count: usize = 0,
            guard_storage: [max_decision_guards]GuardRecord = undefined,
            guard_count: usize = 0,
            command_storage: [max_decision_commands]Command = undefined,
            command_count: usize = 0,
            internal_event_storage: [max_decision_internal_events]Event = undefined,
            internal_event_count: usize = 0,
            fingerprint: u64 = 0,

            pub fn actions(self: *const Decision) []const ActionRecord {
                return self.action_storage[0..self.action_count];
            }

            pub fn guards(self: *const Decision) []const GuardRecord {
                return self.guard_storage[0..self.guard_count];
            }

            pub fn commands(self: *const Decision) []const Command {
                return self.command_storage[0..self.command_count];
            }

            pub fn internalEvents(self: *const Decision) []const Event {
                return self.internal_event_storage[0..self.internal_event_count];
            }

            fn recordAction(self: *Decision, phase: ActionPhaseT, action_id: []const u8) StepErrorT!void {
                if (self.action_count >= self.action_storage.len) return error.ActionRecordLimitExceeded;
                self.action_storage[self.action_count] = .{ .phase = phase, .action_id = action_id };
                self.action_count += 1;
            }

            fn recordGuard(
                self: *Decision,
                guard_id: []const u8,
                transition_id: []const u8,
                accepted: bool,
            ) StepErrorT!void {
                if (self.guard_count >= self.guard_storage.len) return error.GuardRecordLimitExceeded;
                self.guard_storage[self.guard_count] = .{
                    .guard_id = guard_id,
                    .transition_id = transition_id,
                    .accepted = accepted,
                };
                self.guard_count += 1;
            }
        };

        pub const Initialization = struct {
            snapshot: Snapshot,
            action_storage: [max_decision_actions]ActionRecord = undefined,
            action_count: usize = 0,
            command_storage: [max_decision_commands]Command = undefined,
            command_count: usize = 0,
            internal_event_storage: [max_decision_internal_events]Event = undefined,
            internal_event_count: usize = 0,
            fingerprint: u64 = 0,

            pub fn actions(self: *const Initialization) []const ActionRecord {
                return self.action_storage[0..self.action_count];
            }

            pub fn commands(self: *const Initialization) []const Command {
                return self.command_storage[0..self.command_count];
            }

            pub fn internalEvents(self: *const Initialization) []const Event {
                return self.internal_event_storage[0..self.internal_event_count];
            }

            fn recordAction(self: *Initialization, phase: ActionPhaseT, action_id: []const u8) StepErrorT!void {
                if (self.action_count >= self.action_storage.len) return error.ActionRecordLimitExceeded;
                self.action_storage[self.action_count] = .{ .phase = phase, .action_id = action_id };
                self.action_count += 1;
            }
        };

        pub fn initial(
            definition: *const DefinitionType,
            context: Context,
            instance_id: u64,
        ) Snapshot {
            return .{
                .definition_fingerprint = definition.fingerprint(),
                .instance_id = instance_id,
                .state = definition.initial,
                .context = context,
                .status = if (definition.stateKind(definition.initial) == .final) .done else .active,
            };
        }

        pub fn requiresInitializationEvent(definition: *const DefinitionType) bool {
            const node = findStateNode(definition, definition.initial) orelse return false;
            return node.entry_actions.len != 0 or node.invocations.len != 0;
        }

        /// Enters a flat machine transactionally. The explicit typed event is
        /// required because entry actions and invocation adapters may inspect
        /// event payloads or emit internal events and commands.
        pub fn initialize(
            definition: *const DefinitionType,
            context: Context,
            instance_id: u64,
            init_event: Event,
        ) StepErrorT!Initialization {
            const validation = definition.validate();
            if (!validation.isValid()) return error.InvalidDefinition;
            var result = Initialization{ .snapshot = initial(definition, context, instance_id) };
            const configured_command_limit = @min(definition.bounds.max_commands, max_decision_commands);
            const configured_event_limit = @min(definition.bounds.max_internal_events, max_decision_internal_events);
            var command_sink = DefinitionType.CommandSink.initWithEvents(
                result.command_storage[0..configured_command_limit],
                result.internal_event_storage[0..configured_event_limit],
            );
            const node = findStateNode(definition, definition.initial) orelse return error.UnknownSnapshotState;
            for (node.entry_actions) |action| {
                action.execute(&result.snapshot.context, &init_event, &command_sink) catch |action_error| {
                    if (action_error == error.CommandLimitExceeded) return error.CommandLimitExceeded;
                    if (action_error == error.InternalEventLimitExceeded) return error.InternalEventLimitExceeded;
                    return error.ActionFailed;
                };
                try result.recordAction(.entry, action.id);
            }
            for (node.invocations) |invocation| {
                invocation.start.execute(&result.snapshot.context, &init_event, &command_sink) catch |action_error| {
                    if (action_error == error.CommandLimitExceeded) return error.CommandLimitExceeded;
                    if (action_error == error.InternalEventLimitExceeded) return error.InternalEventLimitExceeded;
                    return error.ActionFailed;
                };
                try result.recordAction(.invoke_start, invocation.start.id);
            }
            result.command_count = command_sink.len;
            result.internal_event_count = command_sink.event_len;
            result.fingerprint = initializationFingerprint(definition, &result, init_event);
            return result;
        }

        pub fn step(
            definition: *const DefinitionType,
            snapshot: Snapshot,
            event: Event,
        ) StepErrorT!Decision {
            return stepWithTrigger(definition, snapshot, event, .event);
        }

        pub fn stepEventless(
            definition: *const DefinitionType,
            snapshot: Snapshot,
            last_event: Event,
        ) StepErrorT!Decision {
            return stepWithTrigger(definition, snapshot, last_event, .eventless);
        }

        const TriggerMode = enum { event, eventless };

        fn stepWithTrigger(
            definition: *const DefinitionType,
            snapshot: Snapshot,
            event: Event,
            trigger_mode: TriggerMode,
        ) StepErrorT!Decision {
            const validation = definition.validate();
            if (!validation.isValid()) return error.InvalidDefinition;
            if (snapshot.definition_fingerprint != definition.fingerprint()) return error.DefinitionMismatch;
            if (snapshot.status != .active) return error.SnapshotNotActive;
            if (!definition.hasState(snapshot.state)) return error.UnknownSnapshotState;

            var decision = Decision{
                .previous = snapshot,
                .next = snapshot,
            };

            const event_tag = DefinitionType.eventTag(event);
            var selected_index: ?usize = null;
            for (definition.transitions, 0..) |transition, transition_index| {
                if (transition.source != snapshot.state) continue;
                switch (trigger_mode) {
                    .event => if (transition.event == null or transition.event.? != event_tag) continue,
                    .eventless => if (transition.event != null) continue,
                }

                if (transition.guard) |guard| {
                    const accepted = guard.evaluate(&snapshot.context, &event);
                    try decision.recordGuard(guard.id, transition.id, accepted);
                    if (!accepted) continue;
                }

                selected_index = transition_index;
                break;
            }

            if (selected_index == null) {
                decision.fingerprint = decisionFingerprint(definition, &decision, event);
                return decision;
            }

            const transition_index = selected_index.?;
            const transition = definition.transitions[transition_index];
            decision.outcome = .transitioned;
            decision.selected_transition_id = transition.id;
            decision.selected_transition_index = transition_index;

            const configured_command_limit = @min(definition.bounds.max_commands, max_decision_commands);
            const configured_event_limit = @min(definition.bounds.max_internal_events, max_decision_internal_events);
            var command_sink = DefinitionType.CommandSink.initWithEvents(
                decision.command_storage[0..configured_command_limit],
                decision.internal_event_storage[0..configured_event_limit],
            );

            const exits_and_enters = if (transition.target) |target|
                target != snapshot.state or transition.reenter
            else
                false;

            if (exits_and_enters) {
                const source_node = findStateNode(definition, snapshot.state) orelse return error.UnknownSnapshotState;
                try executeActions(&decision, &command_sink, source_node.exit_actions, .exit, &event);
                for (source_node.invocations) |invocation| {
                    if (invocation.stop) |stop| {
                        try executeActions(&decision, &command_sink, &.{stop}, .invoke_stop, &event);
                    }
                }
            }

            try executeActions(&decision, &command_sink, transition.actions, .transition, &event);

            if (transition.target) |target| {
                decision.next.state = target;
                if (exits_and_enters) {
                    const target_node = findStateNode(definition, target) orelse return error.UnknownSnapshotState;
                    try executeActions(&decision, &command_sink, target_node.entry_actions, .entry, &event);
                    for (target_node.invocations) |invocation| {
                        try executeActions(&decision, &command_sink, &.{invocation.start}, .invoke_start, &event);
                    }
                }
                if (definition.stateKind(target) == .final) decision.next.status = .done;
            }

            decision.next.revision +%= 1;
            decision.next.last_event_sequence +%= 1;
            decision.command_count = command_sink.len;
            decision.internal_event_count = command_sink.event_len;
            decision.fingerprint = decisionFingerprint(definition, &decision, event);
            return decision;
        }

        fn executeActions(
            decision: *Decision,
            command_sink: *DefinitionType.CommandSink,
            actions: []const DefinitionType.Action,
            phase: ActionPhaseT,
            event: *const Event,
        ) StepErrorT!void {
            for (actions) |action| {
                action.execute(&decision.next.context, event, command_sink) catch |action_error| {
                    if (action_error == error.CommandLimitExceeded) return error.CommandLimitExceeded;
                    if (action_error == error.InternalEventLimitExceeded) return error.InternalEventLimitExceeded;
                    return error.ActionFailed;
                };
                try decision.recordAction(phase, action.id);
            }
        }

        fn findStateNode(definition: *const DefinitionType, state: State) ?DefinitionType.StateNode {
            for (definition.states) |node| {
                if (node.id == state) return node;
            }
            return null;
        }

        fn initializationFingerprint(
            definition: *const DefinitionType,
            initialization: *const Initialization,
            event: Event,
        ) u64 {
            var hasher = std.hash.Fnv1a_64.init();
            hashInt(&hasher, definition.fingerprint());
            hashInt(&hasher, initialization.snapshot.instance_id);
            hashInt(&hasher, @intFromEnum(initialization.snapshot.state));
            hashInt(&hasher, value_hash.hash(Context, initialization.snapshot.context));
            hashInt(&hasher, value_hash.hash(Event, event));
            for (initialization.actions()) |action| {
                hashInt(&hasher, @intFromEnum(action.phase));
                hashText(&hasher, action.action_id);
            }
            for (initialization.commands()) |command| hashInt(&hasher, value_hash.hash(Command, command));
            const fingerprint = hasher.final();
            return if (fingerprint == 0) 1 else fingerprint;
        }

        fn decisionFingerprint(
            definition: *const DefinitionType,
            decision: *const Decision,
            event: Event,
        ) u64 {
            var hasher = std.hash.Fnv1a_64.init();
            hashInt(&hasher, definition.fingerprint());
            hashInt(&hasher, decision.previous.instance_id);
            hashInt(&hasher, decision.previous.revision);
            hashInt(&hasher, value_hash.hash(Event, event));
            hashInt(&hasher, @intFromEnum(decision.outcome));
            hashText(&hasher, decision.selected_transition_id);
            hashInt(&hasher, @intFromEnum(decision.next.state));
            hashInt(&hasher, @intFromEnum(decision.next.status));
            hashInt(&hasher, decision.next.revision);
            hashInt(&hasher, value_hash.hash(Context, decision.next.context));
            for (decision.guards()) |guard| {
                hashText(&hasher, guard.guard_id);
                hashText(&hasher, guard.transition_id);
                hashInt(&hasher, @intFromBool(guard.accepted));
            }
            for (decision.actions()) |action| {
                hashInt(&hasher, @intFromEnum(action.phase));
                hashText(&hasher, action.action_id);
            }
            for (decision.commands()) |command| {
                hashInt(&hasher, value_hash.hash(Command, command));
            }
            for (decision.internalEvents()) |internal_event| {
                hashInt(&hasher, value_hash.hash(Event, internal_event));
            }
            const result = hasher.final();
            return if (result == 0) 1 else result;
        }
    };
}

fn hashText(hasher: *std.hash.Fnv1a_64, text: []const u8) void {
    hashInt(hasher, text.len);
    hasher.update(text);
}

fn hashInt(hasher: *std.hash.Fnv1a_64, value: anytype) void {
    var widened: u64 = @intCast(value);
    hasher.update(std.mem.asBytes(&widened));
}
