const std = @import("std");
const value_hash = @import("../traits/hash.zig");
const machine_mod = @import("machine.zig");

pub const max_configuration_states: usize = 256;
pub const max_active_atomic_states: usize = 64;
pub const max_selected_transitions: usize = 64;
pub const max_history_records: usize = 32;
pub const max_history_states: usize = 64;

pub const ConfigurationError = error{
    InvalidDefinition,
    DefinitionMismatch,
    MissingInitializationEvent,
    SnapshotNotActive,
    ConfigurationLimitExceeded,
    ActiveAtomicLimitExceeded,
    HierarchyDepthExceeded,
    CommandLimitExceeded,
    InternalEventLimitExceeded,
    ActionRecordLimitExceeded,
    GuardRecordLimitExceeded,
    TransitionLimitExceeded,
    ActionFailed,
};

pub fn ConfigurationMachine(comptime DefinitionType: type) type {
    const State = DefinitionType.StateType;
    const Event = DefinitionType.EventType;
    const Context = DefinitionType.ContextType;
    const Command = DefinitionType.CommandType;

    return struct {
        const Self = @This();

        pub const Definition = DefinitionType;
        pub const SnapshotStatus = machine_mod.SnapshotStatus;
        pub const DecisionOutcome = machine_mod.DecisionOutcome;
        pub const ActionPhase = machine_mod.ActionPhase;
        pub const Error = ConfigurationError;

        pub const HistoryRecord = struct {
            parent: State,
            shallow_storage: [max_history_states]State = undefined,
            shallow_count: usize = 0,
            deep_storage: [max_history_states]State = undefined,
            deep_count: usize = 0,

            pub fn shallowStates(self: *const HistoryRecord) []const State {
                return self.shallow_storage[0..self.shallow_count];
            }

            pub fn deepStates(self: *const HistoryRecord) []const State {
                return self.deep_storage[0..self.deep_count];
            }
        };

        pub const Snapshot = struct {
            definition_fingerprint: u64,
            instance_id: u64,
            context: Context,
            status: SnapshotStatus = .active,
            revision: u64 = 0,
            last_event_sequence: u64 = 0,
            configuration_storage: [max_configuration_states]State = undefined,
            configuration_count: usize = 0,
            atomic_storage: [max_active_atomic_states]State = undefined,
            atomic_count: usize = 0,
            history_storage: [max_history_records]HistoryRecord = undefined,
            history_count: usize = 0,

            pub fn configuration(self: *const Snapshot) []const State {
                return self.configuration_storage[0..self.configuration_count];
            }

            pub fn activeAtomicStates(self: *const Snapshot) []const State {
                return self.atomic_storage[0..self.atomic_count];
            }

            pub fn isActive(self: *const Snapshot, state: State) bool {
                for (self.configuration()) |active| {
                    if (active == state) return true;
                }
                return false;
            }

            pub fn historyFor(self: *const Snapshot, parent: State) ?*const HistoryRecord {
                for (self.history_storage[0..self.history_count]) |*record| {
                    if (record.parent == parent) return record;
                }
                return null;
            }
        };

        pub const ActionRecord = struct {
            phase: ActionPhase,
            action_id: []const u8,
            state: ?State = null,
        };

        /// The atomic result of entering a machine's initial configuration.
        ///
        /// Initial entry actions are allowed to mutate only this result's local
        /// context and buffers. If any action fails, no snapshot or command list
        /// is returned to the caller, preserving transactional initialization.
        pub const Initialization = struct {
            snapshot: Snapshot,
            action_storage: [machine_mod.max_decision_actions]ActionRecord = undefined,
            action_count: usize = 0,
            command_storage: [machine_mod.max_decision_commands]Command = undefined,
            command_count: usize = 0,
            internal_event_storage: [machine_mod.max_decision_internal_events]Event = undefined,
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

            fn recordAction(self: *Initialization, phase: ActionPhase, action_id: []const u8, state: State) Error!void {
                if (self.action_count >= self.action_storage.len) return error.ActionRecordLimitExceeded;
                self.action_storage[self.action_count] = .{
                    .phase = phase,
                    .action_id = action_id,
                    .state = state,
                };
                self.action_count += 1;
            }
        };

        pub const GuardRecord = struct {
            guard_id: []const u8,
            transition_id: []const u8,
            accepted: bool,
        };

        pub const Decision = struct {
            outcome: DecisionOutcome = .ignored,
            previous: Snapshot,
            next: Snapshot,
            transition_storage: [max_selected_transitions][]const u8 = undefined,
            transition_count: usize = 0,
            action_storage: [machine_mod.max_decision_actions]ActionRecord = undefined,
            action_count: usize = 0,
            guard_storage: [machine_mod.max_decision_guards]GuardRecord = undefined,
            guard_count: usize = 0,
            command_storage: [machine_mod.max_decision_commands]Command = undefined,
            command_count: usize = 0,
            internal_event_storage: [machine_mod.max_decision_internal_events]Event = undefined,
            internal_event_count: usize = 0,
            fingerprint: u64 = 0,

            pub fn transitionIds(self: *const Decision) []const []const u8 {
                return self.transition_storage[0..self.transition_count];
            }

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

            fn recordAction(self: *Decision, phase: ActionPhase, action_id: []const u8, state: ?State) Error!void {
                if (self.action_count >= self.action_storage.len) return error.ActionRecordLimitExceeded;
                self.action_storage[self.action_count] = .{ .phase = phase, .action_id = action_id, .state = state };
                self.action_count += 1;
            }

            fn recordGuard(self: *Decision, guard_id: []const u8, transition_id: []const u8, accepted: bool) Error!void {
                if (self.guard_count >= self.guard_storage.len) return error.GuardRecordLimitExceeded;
                self.guard_storage[self.guard_count] = .{
                    .guard_id = guard_id,
                    .transition_id = transition_id,
                    .accepted = accepted,
                };
                self.guard_count += 1;
            }
        };

        const Candidate = struct {
            transition_index: usize,
            selection_order: usize,
            source: State,
            domain: ?State,
            exit_mask: [max_configuration_states]bool,
        };

        pub fn initial(definition: *const DefinitionType, context: Context, instance_id: u64) Error!Snapshot {
            const snapshot = try initialRaw(definition, context, instance_id);
            for (definition.states) |node| {
                if (snapshot.isActive(node.id) and node.entry_actions.len != 0) {
                    return error.MissingInitializationEvent;
                }
            }
            if (initialCompletionEventCount(definition, &snapshot) != 0) {
                return error.MissingInitializationEvent;
            }
            return snapshot;
        }

        /// Enters the initial configuration and executes every active state's
        /// entry actions from shallow to deep, preserving definition order for
        /// states at the same depth. The caller supplies the event visible to
        /// those actions so initialization never fabricates an Event value.
        pub fn initialize(
            definition: *const DefinitionType,
            context: Context,
            instance_id: u64,
            init_event: Event,
        ) Error!Initialization {
            var result = Initialization{
                .snapshot = try initialRaw(definition, context, instance_id),
            };
            const command_limit = @min(definition.bounds.max_commands, machine_mod.max_decision_commands);
            const event_limit = @min(definition.bounds.max_internal_events, machine_mod.max_decision_internal_events);
            var command_sink = DefinitionType.CommandSink.initWithEvents(
                result.command_storage[0..command_limit],
                result.internal_event_storage[0..event_limit],
            );

            var depth: usize = 0;
            while (depth <= definition.bounds.max_hierarchy_depth) : (depth += 1) {
                for (definition.states) |node| {
                    if (!result.snapshot.isActive(node.id)) continue;
                    if (stateDepth(definition, node.id) != depth) continue;
                    for (node.entry_actions) |action| {
                        action.execute(&result.snapshot.context, &init_event, &command_sink) catch |action_error| {
                            if (action_error == error.CommandLimitExceeded) return error.CommandLimitExceeded;
                            if (action_error == error.InternalEventLimitExceeded) return error.InternalEventLimitExceeded;
                            return error.ActionFailed;
                        };
                        try result.recordAction(.entry, action.id, node.id);
                    }
                    for (node.invocations) |invocation| {
                        invocation.start.execute(&result.snapshot.context, &init_event, &command_sink) catch |action_error| {
                            if (action_error == error.CommandLimitExceeded) return error.CommandLimitExceeded;
                            if (action_error == error.InternalEventLimitExceeded) return error.InternalEventLimitExceeded;
                            return error.ActionFailed;
                        };
                        try result.recordAction(.invoke_start, invocation.start.id, node.id);
                    }
                }
            }
            try raiseInitialCompletionEvents(definition, &result.snapshot, &command_sink);

            result.snapshot.status = completionStatus(definition, &result.snapshot);
            result.command_count = command_sink.len;
            result.internal_event_count = command_sink.event_len;
            result.fingerprint = initializationFingerprint(definition, &result, init_event);
            return result;
        }

        fn initialRaw(definition: *const DefinitionType, context: Context, instance_id: u64) Error!Snapshot {
            const validation = definition.validate();
            if (!validation.isValid()) return error.InvalidDefinition;
            if (definition.states.len > max_configuration_states) return error.ConfigurationLimitExceeded;

            var snapshot = Snapshot{
                .definition_fingerprint = definition.fingerprint(),
                .instance_id = instance_id,
                .context = context,
            };
            try enterInitialAtomic(definition, &snapshot, definition.initial, 0);
            try rebuildConfiguration(definition, &snapshot);
            snapshot.status = completionStatus(definition, &snapshot);
            return snapshot;
        }

        pub fn step(definition: *const DefinitionType, snapshot: Snapshot, event: Event) Error!Decision {
            return stepWithTrigger(definition, snapshot, event, .event);
        }

        pub fn stepEventless(definition: *const DefinitionType, snapshot: Snapshot, last_event: Event) Error!Decision {
            return stepWithTrigger(definition, snapshot, last_event, .eventless);
        }

        const TriggerMode = enum { event, eventless };

        fn stepWithTrigger(
            definition: *const DefinitionType,
            snapshot: Snapshot,
            event: Event,
            trigger_mode: TriggerMode,
        ) Error!Decision {
            const validation = definition.validate();
            if (!validation.isValid()) return error.InvalidDefinition;
            if (snapshot.definition_fingerprint != definition.fingerprint()) return error.DefinitionMismatch;
            if (snapshot.status != .active) return error.SnapshotNotActive;

            var decision = Decision{ .previous = snapshot, .next = snapshot };
            var candidates: [max_selected_transitions]Candidate = undefined;
            var candidate_count: usize = 0;

            for (snapshot.activeAtomicStates(), 0..) |leaf, selection_order| {
                const candidate_index = try selectForLeaf(definition, &decision, leaf, &event, trigger_mode);
                if (candidate_index) |transition_index| {
                    if (containsCandidate(candidates[0..candidate_count], transition_index)) continue;
                    if (candidate_count >= candidates.len) return error.TransitionLimitExceeded;
                    const transition = definition.transitions[transition_index];
                    const domain = transitionDomain(definition, transition.source, transition.target, transition.kind, transition.reenter);
                    var candidate = Candidate{
                        .transition_index = transition_index,
                        .selection_order = selection_order,
                        .source = transition.source,
                        .domain = domain,
                        .exit_mask = [_]bool{false} ** max_configuration_states,
                    };
                    fillExitMask(definition, &snapshot, domain, transition.target != null, &candidate.exit_mask);
                    insertCandidate(definition, &candidate_count, &candidates, candidate);
                }
            }

            if (candidate_count == 0) {
                decision.fingerprint = decisionFingerprint(definition, &decision, event);
                return decision;
            }

            sortCandidates(&candidates, candidate_count);
            decision.outcome = .transitioned;
            for (candidates[0..candidate_count]) |candidate| {
                if (decision.transition_count >= decision.transition_storage.len) return error.TransitionLimitExceeded;
                decision.transition_storage[decision.transition_count] = definition.transitions[candidate.transition_index].id;
                decision.transition_count += 1;
            }

            const command_limit = @min(definition.bounds.max_commands, machine_mod.max_decision_commands);
            const event_limit = @min(definition.bounds.max_internal_events, machine_mod.max_decision_internal_events);
            var command_sink = DefinitionType.CommandSink.initWithEvents(
                decision.command_storage[0..command_limit],
                decision.internal_event_storage[0..event_limit],
            );

            var union_exit_mask = [_]bool{false} ** max_configuration_states;
            for (candidates[0..candidate_count]) |candidate| {
                for (candidate.exit_mask, 0..) |exits, state_index| {
                    union_exit_mask[state_index] = union_exit_mask[state_index] or exits;
                }
            }
            try captureHistory(definition, &decision.next, union_exit_mask);
            try executeExitActions(definition, &decision, &command_sink, union_exit_mask, &event);

            for (candidates[0..candidate_count]) |candidate| {
                const transition = definition.transitions[candidate.transition_index];
                try executeActions(&decision, &command_sink, transition.actions, .transition, null, &event);
            }

            for (candidates[0..candidate_count]) |candidate| {
                const transition = definition.transitions[candidate.transition_index];
                if (candidate.domain) |domain| {
                    removeAtomicDescendants(definition, &decision.next, domain);
                } else if (transition.target != null) {
                    decision.next.atomic_count = 0;
                }
                if (transition.target) |target| {
                    try enterTransitionTarget(definition, &decision, &command_sink, target, &event, 0);
                }
            }
            try ensureParallelRegions(definition, &decision.next);
            try normalizeAtomicOrder(definition, &decision.next);
            try rebuildConfiguration(definition, &decision.next);
            try executeEntryActions(definition, &decision, &command_sink, union_exit_mask, &event);
            try raiseCompletionEvents(definition, &decision, &command_sink, union_exit_mask);

            decision.next.revision +%= 1;
            decision.next.last_event_sequence +%= 1;
            decision.next.status = completionStatus(definition, &decision.next);
            decision.command_count = command_sink.len;
            decision.internal_event_count = command_sink.event_len;
            decision.fingerprint = decisionFingerprint(definition, &decision, event);
            return decision;
        }

        fn selectForLeaf(
            definition: *const DefinitionType,
            decision: *Decision,
            leaf: State,
            event: *const Event,
            trigger_mode: TriggerMode,
        ) Error!?usize {
            var source = leaf;
            var depth: usize = 0;
            while (true) {
                for (definition.transitions, 0..) |transition, transition_index| {
                    if (transition.source != source) continue;
                    switch (trigger_mode) {
                        .event => {
                            if (transition.event == null or transition.event.? != DefinitionType.eventTag(event.*)) continue;
                        },
                        .eventless => if (transition.event != null) continue,
                    }
                    if (transition.guard) |guard| {
                        const accepted = guard.evaluate(&decision.previous.context, event);
                        try decision.recordGuard(guard.id, transition.id, accepted);
                        if (!accepted) continue;
                    }
                    return transition_index;
                }
                const node = definition.stateNode(source) orelse return null;
                source = node.parent orelse return null;
                depth += 1;
                if (depth > definition.bounds.max_hierarchy_depth) return error.HierarchyDepthExceeded;
            }
        }

        fn insertCandidate(
            definition: *const DefinitionType,
            count: *usize,
            candidates: *[max_selected_transitions]Candidate,
            candidate: Candidate,
        ) void {
            var index: usize = 0;
            while (index < count.*) {
                if (!masksIntersect(candidates[index].exit_mask, candidate.exit_mask)) {
                    index += 1;
                    continue;
                }
                const candidate_is_descendant = definition.isDescendant(candidate.source, candidates[index].source);
                const existing_is_descendant = definition.isDescendant(candidates[index].source, candidate.source);
                const candidate_has_priority = candidate_is_descendant or
                    (!existing_is_descendant and candidate.selection_order < candidates[index].selection_order) or
                    (!existing_is_descendant and candidate.selection_order == candidates[index].selection_order and
                        candidate.transition_index < candidates[index].transition_index);
                if (candidate_has_priority) {
                    var shift = index;
                    while (shift + 1 < count.*) : (shift += 1) candidates[shift] = candidates[shift + 1];
                    count.* -= 1;
                    continue;
                }
                return;
            }
            candidates[count.*] = candidate;
            count.* += 1;
        }

        fn transitionDomain(
            definition: *const DefinitionType,
            source: State,
            target: ?State,
            kind: @import("definition.zig").TransitionKind,
            reenter: bool,
        ) ?State {
            const destination = target orelse return null;
            if (kind == .internal and definition.isDescendant(destination, source)) return source;
            if (source == destination or reenter or definition.isDescendant(destination, source)) {
                return (definition.stateNode(source) orelse return null).parent;
            }
            return leastCommonAncestor(definition, source, destination);
        }

        fn leastCommonAncestor(definition: *const DefinitionType, left: State, right: State) ?State {
            var cursor: ?State = left;
            var depth: usize = 0;
            while (cursor) |candidate| {
                if (candidate == right or definition.isDescendant(right, candidate)) return candidate;
                cursor = (definition.stateNode(candidate) orelse return null).parent;
                depth += 1;
                if (depth > definition.bounds.max_hierarchy_depth) return null;
            }
            return null;
        }

        fn fillExitMask(
            definition: *const DefinitionType,
            snapshot: *const Snapshot,
            domain: ?State,
            has_target: bool,
            mask: *[max_configuration_states]bool,
        ) void {
            const exit_domain = domain orelse {
                if (has_target) {
                    for (definition.states, 0..) |node, index| {
                        if (snapshot.isActive(node.id)) mask[index] = true;
                    }
                }
                return;
            };
            for (definition.states, 0..) |node, index| {
                if (!snapshot.isActive(node.id)) continue;
                if (definition.isDescendant(node.id, exit_domain)) mask[index] = true;
            }
        }

        fn executeExitActions(
            definition: *const DefinitionType,
            decision: *Decision,
            sink: *DefinitionType.CommandSink,
            exit_mask: [max_configuration_states]bool,
            event: *const Event,
        ) Error!void {
            var depth = definition.bounds.max_hierarchy_depth + 1;
            while (depth > 0) {
                depth -= 1;
                var index = definition.states.len;
                while (index > 0) {
                    index -= 1;
                    if (!exit_mask[index]) continue;
                    const node = definition.states[index];
                    if (stateDepth(definition, node.id) != depth) continue;
                    try executeActions(decision, sink, node.exit_actions, .exit, node.id, event);
                    for (node.invocations) |invocation| {
                        if (invocation.stop) |stop| {
                            try executeActions(decision, sink, &.{stop}, .invoke_stop, node.id, event);
                        }
                    }
                }
            }
        }

        fn executeEntryActions(
            definition: *const DefinitionType,
            decision: *Decision,
            sink: *DefinitionType.CommandSink,
            exit_mask: [max_configuration_states]bool,
            event: *const Event,
        ) Error!void {
            var depth: usize = 0;
            while (depth <= definition.bounds.max_hierarchy_depth) : (depth += 1) {
                for (definition.states, 0..) |node, index| {
                    if (!decision.next.isActive(node.id)) continue;
                    if (decision.previous.isActive(node.id) and !exit_mask[index]) continue;
                    if (stateDepth(definition, node.id) != depth) continue;
                    try executeActions(decision, sink, node.entry_actions, .entry, node.id, event);
                    for (node.invocations) |invocation| {
                        try executeActions(decision, sink, &.{invocation.start}, .invoke_start, node.id, event);
                    }
                }
            }
        }

        fn raiseCompletionEvents(
            definition: *const DefinitionType,
            decision: *Decision,
            sink: *DefinitionType.CommandSink,
            exit_mask: [max_configuration_states]bool,
        ) Error!void {
            const completion = definition.completion orelse return;
            var depth = definition.bounds.max_hierarchy_depth + 1;
            while (depth > 0) {
                depth -= 1;
                for (definition.states, 0..) |node, node_index| {
                    if (stateDepth(definition, node.id) != depth) continue;
                    if (node.kind != .compound and node.kind != .parallel) continue;
                    if (!nodeComplete(definition, &decision.next, node.id, 0)) continue;
                    if (nodeComplete(definition, &decision.previous, node.id, 0) and
                        !completionBoundaryReentered(definition, &decision.next, node.id, node_index, exit_mask)) continue;
                    if (completion.event_for(node.id)) |done_event| {
                        sink.raise(done_event) catch return error.InternalEventLimitExceeded;
                    }
                }
            }
        }

        fn initialCompletionEventCount(definition: *const DefinitionType, snapshot: *const Snapshot) usize {
            const completion = definition.completion orelse return 0;
            var count: usize = 0;
            for (definition.states) |node| {
                if (node.kind != .compound and node.kind != .parallel) continue;
                if (!nodeComplete(definition, snapshot, node.id, 0)) continue;
                if (completion.event_for(node.id) != null) count += 1;
            }
            return count;
        }

        fn raiseInitialCompletionEvents(
            definition: *const DefinitionType,
            snapshot: *const Snapshot,
            sink: *DefinitionType.CommandSink,
        ) Error!void {
            const completion = definition.completion orelse return;
            var depth = definition.bounds.max_hierarchy_depth + 1;
            while (depth > 0) {
                depth -= 1;
                for (definition.states) |node| {
                    if (stateDepth(definition, node.id) != depth) continue;
                    if (node.kind != .compound and node.kind != .parallel) continue;
                    if (!nodeComplete(definition, snapshot, node.id, 0)) continue;
                    if (completion.event_for(node.id)) |done_event| {
                        sink.raise(done_event) catch return error.InternalEventLimitExceeded;
                    }
                }
            }
        }

        fn completionBoundaryReentered(
            definition: *const DefinitionType,
            snapshot: *const Snapshot,
            boundary: State,
            boundary_index: usize,
            exit_mask: [max_configuration_states]bool,
        ) bool {
            if (exit_mask[boundary_index] and snapshot.isActive(boundary)) return true;
            for (definition.states, 0..) |node, index| {
                if (!exit_mask[index] or !snapshot.isActive(node.id)) continue;
                if (definition.isDescendant(node.id, boundary)) return true;
            }
            return false;
        }

        fn executeActions(
            decision: *Decision,
            sink: *DefinitionType.CommandSink,
            actions: []const DefinitionType.Action,
            phase: ActionPhase,
            state: ?State,
            event: *const Event,
        ) Error!void {
            for (actions) |action| {
                action.execute(&decision.next.context, event, sink) catch |action_error| {
                    if (action_error == error.CommandLimitExceeded) return error.CommandLimitExceeded;
                    if (action_error == error.InternalEventLimitExceeded) return error.InternalEventLimitExceeded;
                    return error.ActionFailed;
                };
                try decision.recordAction(phase, action.id, state);
            }
        }

        fn enterTransitionTarget(
            definition: *const DefinitionType,
            decision: *Decision,
            sink: *DefinitionType.CommandSink,
            target: State,
            event: *const Event,
            depth: usize,
        ) Error!void {
            if (depth > definition.bounds.max_hierarchy_depth) return error.HierarchyDepthExceeded;
            const node = definition.stateNode(target) orelse return error.InvalidDefinition;
            if (node.kind != .history_shallow and node.kind != .history_deep) {
                return enterInitialAtomic(definition, &decision.next, target, depth);
            }

            const parent = node.parent orelse return error.InvalidDefinition;
            if (decision.next.historyFor(parent)) |record| {
                const saved = if (node.kind == .history_shallow) record.shallowStates() else record.deepStates();
                if (saved.len != 0) return enterInitialAtomic(definition, &decision.next, target, depth);
            }

            // SCXML history defaults are executable transitions, not aliases for
            // their target. Evaluate and record their guard and actions using the
            // triggering event and the transaction's current context.
            for (definition.transitions) |history_transition| {
                if (history_transition.source != target or history_transition.event != null) continue;
                if (history_transition.guard) |guard| {
                    const accepted = guard.evaluate(&decision.next.context, event);
                    try decision.recordGuard(guard.id, history_transition.id, accepted);
                    if (!accepted) continue;
                }
                if (decision.transition_count >= decision.transition_storage.len) return error.TransitionLimitExceeded;
                decision.transition_storage[decision.transition_count] = history_transition.id;
                decision.transition_count += 1;
                try executeActions(decision, sink, history_transition.actions, .transition, null, event);
                const history_target = history_transition.target orelse return error.InvalidDefinition;
                return enterTransitionTarget(definition, decision, sink, history_target, event, depth + 1);
            }
            return error.InvalidDefinition;
        }

        fn enterInitialAtomic(
            definition: *const DefinitionType,
            snapshot: *Snapshot,
            state: State,
            depth: usize,
        ) Error!void {
            if (depth > definition.bounds.max_hierarchy_depth) return error.HierarchyDepthExceeded;
            const node = definition.stateNode(state) orelse return error.InvalidDefinition;
            switch (node.kind) {
                .atomic, .final => try addAtomic(snapshot, state),
                .compound => try enterInitialAtomic(definition, snapshot, node.initial orelse return error.InvalidDefinition, depth + 1),
                .parallel => {
                    for (definition.states) |child| {
                        if (child.parent == null or child.parent.? != state) continue;
                        if (child.kind == .history_shallow or child.kind == .history_deep) continue;
                        try enterInitialAtomic(definition, snapshot, child.id, depth + 1);
                    }
                },
                .history_shallow, .history_deep => {
                    const parent = node.parent orelse return error.InvalidDefinition;
                    if (snapshot.historyFor(parent)) |record| {
                        const saved = if (node.kind == .history_shallow) record.shallowStates() else record.deepStates();
                        if (saved.len != 0) {
                            for (saved) |saved_state| {
                                if (node.kind == .history_shallow) {
                                    try enterInitialAtomic(definition, snapshot, saved_state, depth + 1);
                                } else {
                                    try addAtomic(snapshot, saved_state);
                                }
                            }
                            return;
                        }
                    }
                    for (definition.transitions) |transition| {
                        if (transition.source != state or transition.event != null) continue;
                        try enterInitialAtomic(definition, snapshot, transition.target orelse continue, depth + 1);
                        return;
                    }
                    return error.InvalidDefinition;
                },
            }
        }

        fn captureHistory(
            definition: *const DefinitionType,
            snapshot: *Snapshot,
            exit_mask: [max_configuration_states]bool,
        ) Error!void {
            for (definition.states, 0..) |container, container_index| {
                if (!exit_mask[container_index] or !hasHistoryChild(definition, container.id)) continue;
                var record = historyRecordMut(snapshot, container.id) orelse blk: {
                    if (snapshot.history_count >= snapshot.history_storage.len) return error.ConfigurationLimitExceeded;
                    snapshot.history_storage[snapshot.history_count] = .{ .parent = container.id };
                    snapshot.history_count += 1;
                    break :blk &snapshot.history_storage[snapshot.history_count - 1];
                };
                record.shallow_count = 0;
                record.deep_count = 0;
                for (snapshot.activeAtomicStates()) |leaf| {
                    if (!definition.isDescendant(leaf, container.id)) continue;
                    const shallow = directChildUnder(definition, leaf, container.id) orelse continue;
                    try appendUniqueHistory(&record.shallow_storage, &record.shallow_count, shallow);
                    try appendUniqueHistory(&record.deep_storage, &record.deep_count, leaf);
                }
            }
        }

        fn hasHistoryChild(definition: *const DefinitionType, parent: State) bool {
            for (definition.states) |node| {
                if (node.parent == null or node.parent.? != parent) continue;
                if (node.kind == .history_shallow or node.kind == .history_deep) return true;
            }
            return false;
        }

        fn historyRecordMut(snapshot: *Snapshot, parent: State) ?*HistoryRecord {
            for (snapshot.history_storage[0..snapshot.history_count]) |*record| {
                if (record.parent == parent) return record;
            }
            return null;
        }

        fn directChildUnder(definition: *const DefinitionType, leaf: State, parent: State) ?State {
            var cursor = leaf;
            var remaining = definition.bounds.max_hierarchy_depth;
            while (remaining > 0) : (remaining -= 1) {
                const node = definition.stateNode(cursor) orelse return null;
                const node_parent = node.parent orelse return null;
                if (node_parent == parent) return cursor;
                cursor = node_parent;
            }
            return null;
        }

        fn appendUniqueHistory(storage: *[max_history_states]State, count: *usize, state: State) Error!void {
            for (storage[0..count.*]) |existing| {
                if (existing == state) return;
            }
            if (count.* >= storage.len) return error.ConfigurationLimitExceeded;
            storage[count.*] = state;
            count.* += 1;
        }

        fn addAtomic(snapshot: *Snapshot, state: State) Error!void {
            for (snapshot.activeAtomicStates()) |active| {
                if (active == state) return;
            }
            if (snapshot.atomic_count >= snapshot.atomic_storage.len) return error.ActiveAtomicLimitExceeded;
            snapshot.atomic_storage[snapshot.atomic_count] = state;
            snapshot.atomic_count += 1;
        }

        fn removeAtomicDescendants(definition: *const DefinitionType, snapshot: *Snapshot, domain: State) void {
            var write: usize = 0;
            for (snapshot.activeAtomicStates()) |leaf| {
                if (leaf == domain or definition.isDescendant(leaf, domain)) continue;
                snapshot.atomic_storage[write] = leaf;
                write += 1;
            }
            snapshot.atomic_count = write;
        }

        fn ensureParallelRegions(definition: *const DefinitionType, snapshot: *Snapshot) Error!void {
            for (definition.states) |parallel| {
                if (parallel.kind != .parallel or !hasActiveDescendant(definition, snapshot, parallel.id)) continue;
                for (definition.states) |region| {
                    if (region.parent == null or region.parent.? != parallel.id) continue;
                    if (region.kind == .history_shallow or region.kind == .history_deep) continue;
                    if (hasActiveDescendantOrSelf(definition, snapshot, region.id)) continue;
                    try enterInitialAtomic(definition, snapshot, region.id, 0);
                }
            }
        }

        fn hasActiveDescendant(definition: *const DefinitionType, snapshot: *const Snapshot, state: State) bool {
            for (snapshot.activeAtomicStates()) |leaf| {
                if (definition.isDescendant(leaf, state)) return true;
            }
            return false;
        }

        fn hasActiveDescendantOrSelf(definition: *const DefinitionType, snapshot: *const Snapshot, state: State) bool {
            for (snapshot.activeAtomicStates()) |leaf| {
                if (leaf == state or definition.isDescendant(leaf, state)) return true;
            }
            return false;
        }

        fn normalizeAtomicOrder(definition: *const DefinitionType, snapshot: *Snapshot) Error!void {
            var ordered: [max_active_atomic_states]State = undefined;
            var count: usize = 0;
            for (definition.states) |node| {
                for (snapshot.activeAtomicStates()) |active| {
                    if (active != node.id) continue;
                    if (count >= ordered.len) return error.ActiveAtomicLimitExceeded;
                    ordered[count] = active;
                    count += 1;
                }
            }
            snapshot.atomic_storage = ordered;
            snapshot.atomic_count = count;
        }

        fn rebuildConfiguration(definition: *const DefinitionType, snapshot: *Snapshot) Error!void {
            snapshot.configuration_count = 0;
            for (definition.states) |node| {
                var active = false;
                for (snapshot.activeAtomicStates()) |leaf| {
                    if (leaf == node.id or definition.isDescendant(leaf, node.id)) {
                        active = true;
                        break;
                    }
                }
                if (!active) continue;
                if (snapshot.configuration_count >= snapshot.configuration_storage.len) return error.ConfigurationLimitExceeded;
                snapshot.configuration_storage[snapshot.configuration_count] = node.id;
                snapshot.configuration_count += 1;
            }
        }

        fn completionStatus(definition: *const DefinitionType, snapshot: *const Snapshot) SnapshotStatus {
            const root = definition.stateNode(definition.initial) orelse return .failed;
            return if (nodeComplete(definition, snapshot, root.id, 0)) .done else .active;
        }

        fn nodeComplete(
            definition: *const DefinitionType,
            snapshot: *const Snapshot,
            state: State,
            depth: usize,
        ) bool {
            if (depth > definition.bounds.max_hierarchy_depth) return false;
            const node = definition.stateNode(state) orelse return false;
            return switch (node.kind) {
                .final => snapshot.isActive(state),
                .atomic, .history_shallow, .history_deep => false,
                .compound => complete: {
                    for (definition.states) |child| {
                        if (child.parent == null or child.parent.? != state or !snapshot.isActive(child.id)) continue;
                        break :complete child.kind == .final;
                    }
                    break :complete false;
                },
                .parallel => complete: {
                    var region_count: usize = 0;
                    for (definition.states) |child| {
                        if (child.parent == null or child.parent.? != state) continue;
                        if (child.kind == .history_shallow or child.kind == .history_deep) continue;
                        region_count += 1;
                        if (!nodeComplete(definition, snapshot, child.id, depth + 1)) break :complete false;
                    }
                    break :complete region_count != 0;
                },
            };
        }

        fn stateDepth(definition: *const DefinitionType, state: State) usize {
            var cursor = definition.stateNode(state) orelse return 0;
            var depth: usize = 0;
            while (cursor.parent) |parent| {
                depth += 1;
                if (depth > definition.bounds.max_hierarchy_depth) return depth;
                cursor = definition.stateNode(parent) orelse return depth;
            }
            return depth;
        }

        fn containsCandidate(candidates: []const Candidate, transition_index: usize) bool {
            for (candidates) |candidate| {
                if (candidate.transition_index == transition_index) return true;
            }
            return false;
        }

        fn masksIntersect(left: [max_configuration_states]bool, right: [max_configuration_states]bool) bool {
            for (left, right) |left_item, right_item| {
                if (left_item and right_item) return true;
            }
            return false;
        }

        fn sortCandidates(candidates: *[max_selected_transitions]Candidate, count: usize) void {
            var index: usize = 1;
            while (index < count) : (index += 1) {
                const value = candidates[index];
                var cursor = index;
                while (cursor > 0 and candidates[cursor - 1].transition_index > value.transition_index) : (cursor -= 1) {
                    candidates[cursor] = candidates[cursor - 1];
                }
                candidates[cursor] = value;
            }
        }

        fn decisionFingerprint(definition: *const DefinitionType, decision: *const Decision, event: Event) u64 {
            var hasher = std.hash.Fnv1a_64.init();
            hashInt(&hasher, definition.fingerprint());
            hashInt(&hasher, decision.previous.instance_id);
            hashInt(&hasher, decision.previous.revision);
            hashInt(&hasher, value_hash.hash(Event, event));
            for (decision.transitionIds()) |id| hashText(&hasher, id);
            for (decision.next.activeAtomicStates()) |state| hashInt(&hasher, @intFromEnum(state));
            hashInt(&hasher, value_hash.hash(Context, decision.next.context));
            for (decision.commands()) |command| hashInt(&hasher, value_hash.hash(Command, command));
            const result = hasher.final();
            return if (result == 0) 1 else result;
        }

        fn initializationFingerprint(
            definition: *const DefinitionType,
            initialization: *const Initialization,
            event: Event,
        ) u64 {
            var hasher = std.hash.Fnv1a_64.init();
            hashInt(&hasher, definition.fingerprint());
            hashInt(&hasher, initialization.snapshot.instance_id);
            hashInt(&hasher, value_hash.hash(Event, event));
            for (initialization.snapshot.activeAtomicStates()) |state| hashInt(&hasher, @intFromEnum(state));
            hashInt(&hasher, value_hash.hash(Context, initialization.snapshot.context));
            for (initialization.actions()) |action| {
                hashText(&hasher, action.action_id);
                if (action.state) |state| hashInt(&hasher, @intFromEnum(state));
            }
            for (initialization.commands()) |command| hashInt(&hasher, value_hash.hash(Command, command));
            for (initialization.internalEvents()) |raised| hashInt(&hasher, value_hash.hash(Event, raised));
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
