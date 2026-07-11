const std = @import("std");
const machine_mod = @import("machine.zig");
const configuration_mod = @import("configuration.zig");

pub const Allocator = std.mem.Allocator;
pub const statechart_snapshot_schema = "zigeffect.statechart.snapshot.v2";
pub const statechart_execution_schema = "zigeffect.statechart.execution.v2";
pub const statechart_coverage_schema = "zigeffect.statechart.coverage.v2";
pub const statechart_artifact_schema_version: u32 = 2;
pub const statechart_snapshot_legacy_schema = "zigeffect.statechart.snapshot.v1";
pub const statechart_execution_legacy_schema = "zigeffect.statechart.execution.v1";
pub const statechart_coverage_legacy_schema = "zigeffect.statechart.coverage.v1";
pub const statechart_redaction_marker = "<redacted>";
pub const ArtifactError = Allocator.Error || error{ArtifactSizeLimitExceeded};

pub fn Artifacts(comptime DefinitionType: type) type {
    const Runtime = machine_mod.Machine(DefinitionType);
    const State = DefinitionType.StateType;
    const EventTag = DefinitionType.EventTag;
    const Command = DefinitionType.CommandType;

    return struct {
        const Self = @This();

        pub fn formatDefinitionJson(allocator: Allocator, definition: *const DefinitionType) Allocator.Error![]const u8 {
            var output = std.ArrayList(u8).empty;
            errdefer output.deinit(allocator);

            try output.appendSlice(allocator, "{\"schema\":");
            try appendJsonString(&output, allocator, @import("definition.zig").statechart_definition_schema);
            try output.print(allocator, ",\"schema_version\":{d},\"id\":", .{statechart_artifact_schema_version});
            try appendJsonString(&output, allocator, definition.id);
            try output.print(allocator, ",\"version\":{d},\"fingerprint\":\"{d}\",\"initial\":", .{ definition.version, definition.fingerprint() });
            try appendJsonString(&output, allocator, @tagName(definition.initial));
            try output.appendSlice(allocator, ",\"description\":");
            try appendJsonString(&output, allocator, definition.description);
            try output.appendSlice(allocator, ",\"state_type\":");
            try appendJsonString(&output, allocator, @typeName(State));
            try output.appendSlice(allocator, ",\"event_type\":");
            try appendJsonString(&output, allocator, @typeName(DefinitionType.EventType));
            try output.appendSlice(allocator, ",\"context_type\":");
            try appendJsonString(&output, allocator, @typeName(DefinitionType.ContextType));
            try output.appendSlice(allocator, ",\"command_type\":");
            try appendJsonString(&output, allocator, @typeName(Command));
            try output.appendSlice(allocator, ",\"completion\":");
            if (definition.completion) |completion| try appendJsonString(&output, allocator, completion.id) else try output.appendSlice(allocator, "null");
            try output.appendSlice(allocator, ",\"states\":[");

            for (definition.states, 0..) |state, index| {
                if (index != 0) try output.append(allocator, ',');
                try output.appendSlice(allocator, "{\"id\":");
                try appendJsonString(&output, allocator, @tagName(state.id));
                try output.appendSlice(allocator, ",\"kind\":");
                try appendJsonString(&output, allocator, @tagName(state.kind));
                try output.appendSlice(allocator, ",\"parent\":");
                try appendOptionalEnumName(&output, allocator, state.parent);
                try output.appendSlice(allocator, ",\"initial\":");
                try appendOptionalEnumName(&output, allocator, state.initial);
                try output.appendSlice(allocator, ",\"description\":");
                try appendJsonString(&output, allocator, state.description);
                try output.appendSlice(allocator, ",\"entry\":");
                try appendActionIds(&output, allocator, state.entry_actions);
                try output.appendSlice(allocator, ",\"exit\":");
                try appendActionIds(&output, allocator, state.exit_actions);
                try output.appendSlice(allocator, ",\"invoke\":");
                try appendInvocations(&output, allocator, state.invocations);
                try output.appendSlice(allocator, ",\"source\":");
                try appendSourceRef(&output, allocator, state.source);
                try output.append(allocator, '}');
            }

            try output.appendSlice(allocator, "],\"transitions\":[");
            for (definition.transitions, 0..) |transition, index| {
                if (index != 0) try output.append(allocator, ',');
                try output.appendSlice(allocator, "{\"id\":");
                try appendJsonString(&output, allocator, transition.id);
                try output.appendSlice(allocator, ",\"source\":");
                try appendJsonString(&output, allocator, @tagName(transition.source));
                try output.appendSlice(allocator, ",\"event\":");
                try appendOptionalEnumName(&output, allocator, transition.event);
                try output.appendSlice(allocator, ",\"target\":");
                try appendOptionalEnumName(&output, allocator, transition.target);
                try output.appendSlice(allocator, ",\"kind\":");
                try appendJsonString(&output, allocator, @tagName(transition.kind));
                try output.appendSlice(allocator, ",\"reenter\":");
                try output.appendSlice(allocator, if (transition.reenter) "true" else "false");
                try output.appendSlice(allocator, ",\"guard\":");
                if (transition.guard) |guard| try appendJsonString(&output, allocator, guard.id) else try output.appendSlice(allocator, "null");
                try output.appendSlice(allocator, ",\"actions\":");
                try appendActionIds(&output, allocator, transition.actions);
                try output.appendSlice(allocator, ",\"description\":");
                try appendJsonString(&output, allocator, transition.description);
                try output.appendSlice(allocator, ",\"source_ref\":");
                try appendSourceRef(&output, allocator, transition.source_ref);
                try output.append(allocator, '}');
            }
            try output.appendSlice(allocator, "]}");
            return output.toOwnedSlice(allocator);
        }

        pub fn formatDefinitionJsonLimited(allocator: Allocator, definition: *const DefinitionType, max_bytes: usize) ArtifactError![]const u8 {
            const output = try formatDefinitionJson(allocator, definition);
            if (output.len > max_bytes) {
                allocator.free(output);
                return error.ArtifactSizeLimitExceeded;
            }
            return output;
        }

        pub fn formatSnapshotJson(allocator: Allocator, snapshot: Runtime.Snapshot) Allocator.Error![]const u8 {
            var output = std.ArrayList(u8).empty;
            errdefer output.deinit(allocator);

            try output.appendSlice(allocator, "{\"schema\":");
            try appendJsonString(&output, allocator, statechart_snapshot_schema);
            try output.print(allocator, ",\"schema_version\":{d},\"definition_fingerprint\":\"{d}\",\"instance_id\":\"{d}\",\"state\":", .{
                statechart_artifact_schema_version,
                snapshot.definition_fingerprint,
                snapshot.instance_id,
            });
            try appendJsonString(&output, allocator, @tagName(snapshot.state));
            try output.appendSlice(allocator, ",\"status\":");
            try appendJsonString(&output, allocator, @tagName(snapshot.status));
            try output.print(allocator, ",\"revision\":\"{d}\",\"last_event_sequence\":\"{d}\",\"context_redacted\":true,\"context\":", .{
                snapshot.revision,
                snapshot.last_event_sequence,
            });
            try appendJsonString(&output, allocator, statechart_redaction_marker);
            try output.append(allocator, '}');
            return output.toOwnedSlice(allocator);
        }

        pub fn formatSnapshotJsonLimited(allocator: Allocator, snapshot: Runtime.Snapshot, max_bytes: usize) ArtifactError![]const u8 {
            const output = try formatSnapshotJson(allocator, snapshot);
            if (output.len > max_bytes) {
                allocator.free(output);
                return error.ArtifactSizeLimitExceeded;
            }
            return output;
        }

        pub fn formatDecisionJson(
            allocator: Allocator,
            decision: *const Runtime.Decision,
            event_tag: EventTag,
        ) Allocator.Error![]const u8 {
            var output = std.ArrayList(u8).empty;
            errdefer output.deinit(allocator);

            try output.appendSlice(allocator, "{\"schema\":");
            try appendJsonString(&output, allocator, statechart_execution_schema);
            try output.print(allocator, ",\"schema_version\":{d},\"instance_id\":\"{d}\",\"decision_fingerprint\":\"{d}\",\"outcome\":", .{
                statechart_artifact_schema_version,
                decision.previous.instance_id,
                decision.fingerprint,
            });
            try appendJsonString(&output, allocator, @tagName(decision.outcome));
            try output.appendSlice(allocator, ",\"event\":");
            try appendJsonString(&output, allocator, @tagName(event_tag));
            try output.appendSlice(allocator, ",\"transition_id\":");
            try appendJsonString(&output, allocator, decision.selected_transition_id);
            try output.appendSlice(allocator, ",\"from\":");
            try appendJsonString(&output, allocator, @tagName(decision.previous.state));
            try output.appendSlice(allocator, ",\"to\":");
            try appendJsonString(&output, allocator, @tagName(decision.next.state));
            try output.print(allocator, ",\"revision\":\"{d}\",\"context_redacted\":true,\"actions\":[", .{decision.next.revision});
            for (decision.actions(), 0..) |action, index| {
                if (index != 0) try output.append(allocator, ',');
                try output.appendSlice(allocator, "{\"phase\":");
                try appendJsonString(&output, allocator, @tagName(action.phase));
                try output.appendSlice(allocator, ",\"id\":");
                try appendJsonString(&output, allocator, action.action_id);
                try output.append(allocator, '}');
            }
            try output.appendSlice(allocator, "],\"guards\":[");
            for (decision.guards(), 0..) |guard, index| {
                if (index != 0) try output.append(allocator, ',');
                try output.appendSlice(allocator, "{\"id\":");
                try appendJsonString(&output, allocator, guard.guard_id);
                try output.appendSlice(allocator, ",\"transition_id\":");
                try appendJsonString(&output, allocator, guard.transition_id);
                try output.appendSlice(allocator, ",\"accepted\":");
                try output.appendSlice(allocator, if (guard.accepted) "true" else "false");
                try output.append(allocator, '}');
            }
            try output.appendSlice(allocator, "],\"commands\":[");
            for (decision.commands(), 0..) |command, index| {
                if (index != 0) try output.append(allocator, ',');
                try appendJsonString(&output, allocator, valueTagName(Command, command));
            }
            try output.appendSlice(allocator, "],\"internal_events\":[");
            for (decision.internalEvents(), 0..) |internal_event, index| {
                if (index != 0) try output.append(allocator, ',');
                try appendJsonString(&output, allocator, valueTagName(DefinitionType.EventType, internal_event));
            }
            try output.appendSlice(allocator, "]}");
            return output.toOwnedSlice(allocator);
        }

        pub fn formatDecisionJsonLimited(
            allocator: Allocator,
            decision: *const Runtime.Decision,
            event_tag: EventTag,
            max_bytes: usize,
        ) ArtifactError![]const u8 {
            const output = try formatDecisionJson(allocator, decision, event_tag);
            if (output.len > max_bytes) {
                allocator.free(output);
                return error.ArtifactSizeLimitExceeded;
            }
            return output;
        }

        pub fn formatXStateJson(allocator: Allocator, definition: *const DefinitionType) Allocator.Error![]const u8 {
            var output = std.ArrayList(u8).empty;
            errdefer output.deinit(allocator);

            try output.appendSlice(allocator, "{\"id\":");
            try appendJsonString(&output, allocator, definition.id);
            try output.appendSlice(allocator, ",\"initial\":");
            try appendJsonString(&output, allocator, @tagName(definition.initial));
            try output.appendSlice(allocator, ",\"description\":");
            try appendJsonString(&output, allocator, definition.description);
            try output.appendSlice(allocator, ",\"states\":{");

            var top_level_index: usize = 0;
            for (definition.states) |state| {
                if (state.parent != null) continue;
                if (top_level_index != 0) try output.append(allocator, ',');
                try appendJsonString(&output, allocator, @tagName(state.id));
                try output.append(allocator, ':');
                try appendStateNode(&output, allocator, definition, state);
                top_level_index += 1;
            }

            try output.appendSlice(allocator, "}}");
            return output.toOwnedSlice(allocator);
        }

        fn appendStateNode(
            output: *std.ArrayList(u8),
            allocator: Allocator,
            definition: *const DefinitionType,
            state: DefinitionType.StateNode,
        ) Allocator.Error!void {
            try output.append(allocator, '{');
            var wrote_field = false;
            try appendObjectFieldPrefix(output, allocator, &wrote_field, "id");
            try appendJsonString(output, allocator, @tagName(state.id));

            switch (state.kind) {
                .final => {
                    try appendObjectFieldPrefix(output, allocator, &wrote_field, "type");
                    try appendJsonString(output, allocator, "final");
                },
                .parallel => {
                    try appendObjectFieldPrefix(output, allocator, &wrote_field, "type");
                    try appendJsonString(output, allocator, "parallel");
                },
                .history_shallow, .history_deep => {
                    try appendObjectFieldPrefix(output, allocator, &wrote_field, "type");
                    try appendJsonString(output, allocator, "history");
                    try appendObjectFieldPrefix(output, allocator, &wrote_field, "history");
                    try appendJsonString(output, allocator, if (state.kind == .history_deep) "deep" else "shallow");
                },
                .atomic, .compound => {},
            }
            if (state.kind == .compound) {
                if (state.initial) |initial| {
                    try appendObjectFieldPrefix(output, allocator, &wrote_field, "initial");
                    try appendJsonString(output, allocator, @tagName(initial));
                }
            }
            if (state.description.len != 0) {
                try appendObjectFieldPrefix(output, allocator, &wrote_field, "description");
                try appendJsonString(output, allocator, state.description);
            }
            if (state.entry_actions.len != 0) {
                try appendObjectFieldPrefix(output, allocator, &wrote_field, "entry");
                try appendActionIds(output, allocator, state.entry_actions);
            }
            if (state.exit_actions.len != 0) {
                try appendObjectFieldPrefix(output, allocator, &wrote_field, "exit");
                try appendActionIds(output, allocator, state.exit_actions);
            }
            if (state.invocations.len != 0) {
                try appendObjectFieldPrefix(output, allocator, &wrote_field, "invoke");
                try output.append(allocator, '[');
                for (state.invocations, 0..) |invocation, index| {
                    if (index != 0) try output.append(allocator, ',');
                    try output.appendSlice(allocator, "{\"id\":");
                    try appendJsonString(output, allocator, invocation.id);
                    try output.appendSlice(allocator, ",\"src\":");
                    try appendJsonString(output, allocator, invocation.id);
                    try output.appendSlice(allocator, ",\"startAction\":");
                    try appendJsonString(output, allocator, invocation.start.id);
                    try output.appendSlice(allocator, ",\"stopAction\":");
                    if (invocation.stop) |stop| try appendJsonString(output, allocator, stop.id) else try output.appendSlice(allocator, "null");
                    try output.append(allocator, '}');
                }
                try output.append(allocator, ']');
            }

            const always_count = transitionCount(definition, state.id, null);
            if (always_count != 0) {
                try appendObjectFieldPrefix(output, allocator, &wrote_field, "always");
                try appendTransitionGroup(output, allocator, definition, state.id, null, always_count);
            }

            var wrote_on = false;
            for (std.meta.tags(EventTag)) |event_tag| {
                const count = transitionCount(definition, state.id, event_tag);
                if (count == 0) continue;
                if (!wrote_on) {
                    try appendObjectFieldPrefix(output, allocator, &wrote_field, "on");
                    try output.append(allocator, '{');
                    wrote_on = true;
                } else {
                    try output.append(allocator, ',');
                }
                try appendJsonString(output, allocator, @tagName(event_tag));
                try output.append(allocator, ':');
                try appendTransitionGroup(output, allocator, definition, state.id, event_tag, count);
            }
            if (wrote_on) try output.append(allocator, '}');

            if (definition.hasDirectChildren(state.id)) {
                try appendObjectFieldPrefix(output, allocator, &wrote_field, "states");
                try output.append(allocator, '{');
                var child_index: usize = 0;
                for (definition.states) |child| {
                    if (child.parent == null or child.parent.? != state.id) continue;
                    if (child_index != 0) try output.append(allocator, ',');
                    try appendJsonString(output, allocator, @tagName(child.id));
                    try output.append(allocator, ':');
                    try appendStateNode(output, allocator, definition, child);
                    child_index += 1;
                }
                try output.append(allocator, '}');
            }
            try output.append(allocator, '}');
        }

        pub fn formatMermaid(allocator: Allocator, definition: *const DefinitionType) Allocator.Error![]const u8 {
            var output = std.ArrayList(u8).empty;
            errdefer output.deinit(allocator);
            try output.appendSlice(allocator, "stateDiagram-v2\n");
            try output.print(allocator, "  [*] --> {s}\n", .{@tagName(definition.initial)});
            for (definition.transitions) |transition| {
                const target = transition.target orelse transition.source;
                try output.print(allocator, "  {s} --> {s} : ", .{ @tagName(transition.source), @tagName(target) });
                if (transition.event) |event_tag| try output.appendSlice(allocator, @tagName(event_tag)) else try output.appendSlice(allocator, "always");
                if (transition.guard) |guard| try output.print(allocator, " [{s}]", .{guard.id});
                if (transition.actions.len != 0) {
                    try output.appendSlice(allocator, " /");
                    for (transition.actions) |action| try output.print(allocator, " {s}", .{action.id});
                }
                try output.append(allocator, '\n');
            }
            for (definition.states) |state| {
                if (state.kind == .final) try output.print(allocator, "  {s} --> [*]\n", .{@tagName(state.id)});
            }
            return output.toOwnedSlice(allocator);
        }

        pub fn formatDot(allocator: Allocator, definition: *const DefinitionType) Allocator.Error![]const u8 {
            var output = std.ArrayList(u8).empty;
            errdefer output.deinit(allocator);
            try output.appendSlice(allocator, "digraph statechart {\n  rankdir=LR;\n  __start [shape=point];\n  __start -> ");
            try appendDotString(&output, allocator, @tagName(definition.initial));
            try output.appendSlice(allocator, ";\n");
            for (definition.states) |state| {
                try output.appendSlice(allocator, "  ");
                try appendDotString(&output, allocator, @tagName(state.id));
                try output.appendSlice(allocator, if (state.kind == .final) " [shape=doublecircle];\n" else " [shape=circle];\n");
            }
            for (definition.transitions) |transition| {
                const target = transition.target orelse transition.source;
                try output.appendSlice(allocator, "  ");
                try appendDotString(&output, allocator, @tagName(transition.source));
                try output.appendSlice(allocator, " -> ");
                try appendDotString(&output, allocator, @tagName(target));
                try output.appendSlice(allocator, " [label=");
                if (transition.event) |event_tag| try appendDotString(&output, allocator, @tagName(event_tag)) else try appendDotString(&output, allocator, "always");
                try output.appendSlice(allocator, "];\n");
            }
            try output.appendSlice(allocator, "}\n");
            return output.toOwnedSlice(allocator);
        }

        fn transitionCount(definition: *const DefinitionType, state: State, event: ?EventTag) usize {
            var count: usize = 0;
            for (definition.transitions) |transition| {
                if (transition.source == state and transition.event == event) count += 1;
            }
            return count;
        }

        fn appendTransitionGroup(
            output: *std.ArrayList(u8),
            allocator: Allocator,
            definition: *const DefinitionType,
            state: State,
            event: ?EventTag,
            count: usize,
        ) Allocator.Error!void {
            if (count > 1) try output.append(allocator, '[');
            var index: usize = 0;
            for (definition.transitions) |transition| {
                if (transition.source != state or transition.event != event) continue;
                if (index != 0) try output.append(allocator, ',');
                try appendXStateTransition(output, allocator, definition, transition);
                index += 1;
            }
            if (count > 1) try output.append(allocator, ']');
        }

        fn appendXStateTransition(
            output: *std.ArrayList(u8),
            allocator: Allocator,
            definition: *const DefinitionType,
            transition: DefinitionType.Transition,
        ) Allocator.Error!void {
            try output.append(allocator, '{');
            var wrote_field = false;
            if (transition.target) |target| {
                try appendObjectFieldPrefix(output, allocator, &wrote_field, "target");
                const source_parent = (definition.stateNode(transition.source) orelse unreachable).parent;
                const target_parent = (definition.stateNode(target) orelse unreachable).parent;
                if (source_parent == target_parent) {
                    try appendJsonString(output, allocator, @tagName(target));
                } else {
                    try output.appendSlice(allocator, "\"#");
                    try output.appendSlice(allocator, @tagName(target));
                    try output.append(allocator, '"');
                }
            }
            if (transition.guard) |guard| {
                try appendObjectFieldPrefix(output, allocator, &wrote_field, "guard");
                try appendJsonString(output, allocator, guard.id);
            }
            if (transition.actions.len != 0) {
                try appendObjectFieldPrefix(output, allocator, &wrote_field, "actions");
                try appendActionIds(output, allocator, transition.actions);
            }
            if (transition.reenter) {
                try appendObjectFieldPrefix(output, allocator, &wrote_field, "reenter");
                try output.appendSlice(allocator, "true");
            }
            if (transition.description.len != 0) {
                try appendObjectFieldPrefix(output, allocator, &wrote_field, "description");
                try appendJsonString(output, allocator, transition.description);
            }
            try output.append(allocator, '}');
        }
    };
}

pub fn ConfigurationArtifacts(comptime DefinitionType: type) type {
    const Runtime = configuration_mod.ConfigurationMachine(DefinitionType);
    const State = DefinitionType.StateType;
    const EventTag = DefinitionType.EventTag;
    const Command = DefinitionType.CommandType;

    return struct {
        pub fn formatSnapshotJson(allocator: Allocator, snapshot: Runtime.Snapshot) Allocator.Error![]const u8 {
            var output = std.ArrayList(u8).empty;
            errdefer output.deinit(allocator);
            try output.appendSlice(allocator, "{\"schema\":");
            try appendJsonString(&output, allocator, statechart_snapshot_schema);
            try output.print(allocator, ",\"schema_version\":{d},\"definition_fingerprint\":\"{d}\",\"instance_id\":\"{d}\",\"configuration\":", .{
                statechart_artifact_schema_version,
                snapshot.definition_fingerprint,
                snapshot.instance_id,
            });
            try appendStateNames(&output, allocator, snapshot.configuration());
            try output.appendSlice(allocator, ",\"active_atomic_states\":");
            try appendStateNames(&output, allocator, snapshot.activeAtomicStates());
            try output.appendSlice(allocator, ",\"history\":[");
            for (snapshot.history_storage[0..snapshot.history_count], 0..) |record, index| {
                if (index != 0) try output.append(allocator, ',');
                try output.appendSlice(allocator, "{\"parent\":");
                try appendJsonString(&output, allocator, @tagName(record.parent));
                try output.appendSlice(allocator, ",\"shallow\":");
                try appendStateNames(&output, allocator, record.shallowStates());
                try output.appendSlice(allocator, ",\"deep\":");
                try appendStateNames(&output, allocator, record.deepStates());
                try output.append(allocator, '}');
            }
            try output.appendSlice(allocator, "],\"status\":");
            try appendJsonString(&output, allocator, @tagName(snapshot.status));
            try output.print(allocator, ",\"revision\":\"{d}\",\"last_event_sequence\":\"{d}\",\"context_redacted\":true,\"context\":", .{
                snapshot.revision,
                snapshot.last_event_sequence,
            });
            try appendJsonString(&output, allocator, statechart_redaction_marker);
            try output.append(allocator, '}');
            return output.toOwnedSlice(allocator);
        }

        pub fn formatSnapshotJsonLimited(allocator: Allocator, snapshot: Runtime.Snapshot, max_bytes: usize) ArtifactError![]const u8 {
            const output = try formatSnapshotJson(allocator, snapshot);
            if (output.len > max_bytes) {
                allocator.free(output);
                return error.ArtifactSizeLimitExceeded;
            }
            return output;
        }

        pub fn formatDecisionJson(
            allocator: Allocator,
            decision: *const Runtime.Decision,
            event_tag: EventTag,
        ) Allocator.Error![]const u8 {
            var output = std.ArrayList(u8).empty;
            errdefer output.deinit(allocator);
            try output.appendSlice(allocator, "{\"schema\":");
            try appendJsonString(&output, allocator, statechart_execution_schema);
            try output.print(allocator, ",\"schema_version\":{d},\"instance_id\":\"{d}\",\"decision_fingerprint\":\"{d}\",\"outcome\":", .{
                statechart_artifact_schema_version,
                decision.previous.instance_id,
                decision.fingerprint,
            });
            try appendJsonString(&output, allocator, @tagName(decision.outcome));
            try output.appendSlice(allocator, ",\"event\":");
            try appendJsonString(&output, allocator, @tagName(event_tag));
            try output.appendSlice(allocator, ",\"transition_ids\":[");
            for (decision.transitionIds(), 0..) |id, index| {
                if (index != 0) try output.append(allocator, ',');
                try appendJsonString(&output, allocator, id);
            }
            try output.appendSlice(allocator, "],\"from_configuration\":");
            try appendStateNames(&output, allocator, decision.previous.activeAtomicStates());
            try output.appendSlice(allocator, ",\"to_configuration\":");
            try appendStateNames(&output, allocator, decision.next.activeAtomicStates());
            try output.print(allocator, ",\"revision\":\"{d}\",\"context_redacted\":true,\"actions\":[", .{decision.next.revision});
            for (decision.actions(), 0..) |action, index| {
                if (index != 0) try output.append(allocator, ',');
                try output.appendSlice(allocator, "{\"phase\":");
                try appendJsonString(&output, allocator, @tagName(action.phase));
                try output.appendSlice(allocator, ",\"id\":");
                try appendJsonString(&output, allocator, action.action_id);
                try output.appendSlice(allocator, ",\"state\":");
                if (action.state) |state| try appendJsonString(&output, allocator, @tagName(state)) else try output.appendSlice(allocator, "null");
                try output.append(allocator, '}');
            }
            try output.appendSlice(allocator, "],\"guards\":[");
            for (decision.guards(), 0..) |guard, index| {
                if (index != 0) try output.append(allocator, ',');
                try output.appendSlice(allocator, "{\"id\":");
                try appendJsonString(&output, allocator, guard.guard_id);
                try output.appendSlice(allocator, ",\"transition_id\":");
                try appendJsonString(&output, allocator, guard.transition_id);
                try output.appendSlice(allocator, ",\"accepted\":");
                try output.appendSlice(allocator, if (guard.accepted) "true" else "false");
                try output.append(allocator, '}');
            }
            try output.appendSlice(allocator, "],\"commands\":[");
            for (decision.commands(), 0..) |command, index| {
                if (index != 0) try output.append(allocator, ',');
                try appendJsonString(&output, allocator, valueTagName(Command, command));
            }
            try output.appendSlice(allocator, "],\"internal_events\":[");
            for (decision.internalEvents(), 0..) |internal_event, index| {
                if (index != 0) try output.append(allocator, ',');
                try appendJsonString(&output, allocator, valueTagName(DefinitionType.EventType, internal_event));
            }
            try output.appendSlice(allocator, "]}");
            return output.toOwnedSlice(allocator);
        }

        pub fn formatDecisionJsonLimited(
            allocator: Allocator,
            decision: *const Runtime.Decision,
            event_tag: EventTag,
            max_bytes: usize,
        ) ArtifactError![]const u8 {
            const output = try formatDecisionJson(allocator, decision, event_tag);
            if (output.len > max_bytes) {
                allocator.free(output);
                return error.ArtifactSizeLimitExceeded;
            }
            return output;
        }

        fn appendStateNames(output: *std.ArrayList(u8), allocator: Allocator, states: []const State) Allocator.Error!void {
            try output.append(allocator, '[');
            for (states, 0..) |state, index| {
                if (index != 0) try output.append(allocator, ',');
                try appendJsonString(output, allocator, @tagName(state));
            }
            try output.append(allocator, ']');
        }
    };
}

fn appendObjectFieldPrefix(
    output: *std.ArrayList(u8),
    allocator: Allocator,
    wrote_field: *bool,
    name: []const u8,
) Allocator.Error!void {
    if (wrote_field.*) try output.append(allocator, ',');
    wrote_field.* = true;
    try appendJsonString(output, allocator, name);
    try output.append(allocator, ':');
}

fn appendActionIds(output: *std.ArrayList(u8), allocator: Allocator, actions: anytype) Allocator.Error!void {
    try output.append(allocator, '[');
    for (actions, 0..) |action, index| {
        if (index != 0) try output.append(allocator, ',');
        try appendJsonString(output, allocator, action.id);
    }
    try output.append(allocator, ']');
}

fn appendInvocations(output: *std.ArrayList(u8), allocator: Allocator, invocations: anytype) Allocator.Error!void {
    try output.append(allocator, '[');
    for (invocations, 0..) |invocation, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.appendSlice(allocator, "{\"id\":");
        try appendJsonString(output, allocator, invocation.id);
        try output.appendSlice(allocator, ",\"start\":");
        try appendJsonString(output, allocator, invocation.start.id);
        try output.appendSlice(allocator, ",\"stop\":");
        if (invocation.stop) |stop| try appendJsonString(output, allocator, stop.id) else try output.appendSlice(allocator, "null");
        try output.appendSlice(allocator, ",\"description\":");
        try appendJsonString(output, allocator, invocation.description);
        try output.appendSlice(allocator, ",\"source\":");
        try appendSourceRef(output, allocator, invocation.source);
        try output.append(allocator, '}');
    }
    try output.append(allocator, ']');
}

fn appendOptionalEnumName(output: *std.ArrayList(u8), allocator: Allocator, value: anytype) Allocator.Error!void {
    if (value) |present| try appendJsonString(output, allocator, @tagName(present)) else try output.appendSlice(allocator, "null");
}

fn appendSourceRef(output: *std.ArrayList(u8), allocator: Allocator, source: @import("definition.zig").SourceRef) Allocator.Error!void {
    try output.appendSlice(allocator, "{\"file\":");
    try appendJsonString(output, allocator, source.file);
    try output.appendSlice(allocator, ",\"declaration\":");
    try appendJsonString(output, allocator, source.declaration);
    try output.print(allocator, ",\"line\":{d},\"column\":{d}}}", .{ source.line, source.column });
}

fn valueTagName(comptime T: type, value: T) []const u8 {
    return switch (@typeInfo(T)) {
        .@"enum" => @tagName(value),
        .@"union" => @tagName(std.meta.activeTag(value)),
        else => @typeName(T),
    };
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: Allocator, value: []const u8) Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            0x00...0x08, 0x0b, 0x0c, 0x0e...0x1f => try output.print(allocator, "\\u{x:0>4}", .{byte}),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

fn appendDotString(output: *std.ArrayList(u8), allocator: Allocator, value: []const u8) Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n', '\r' => try output.appendSlice(allocator, "\\n"),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}
