const std = @import("std");

pub const statechart_definition_schema = "zigeffect.statechart.definition.v2";
pub const statechart_definition_schema_version: u32 = 2;
pub const statechart_definition_legacy_schema = "zigeffect.statechart.definition.v1";
pub const max_validation_findings: usize = 256;

pub const StateKind = enum {
    atomic,
    final,
    compound,
    parallel,
    history_shallow,
    history_deep,
};

pub const TransitionKind = enum {
    external,
    internal,
};

pub const SourceRef = struct {
    file: []const u8 = "",
    declaration: []const u8 = "",
    line: u32 = 0,
    column: u32 = 0,
};

pub const DefinitionBounds = struct {
    max_states: usize = 256,
    max_transitions: usize = 1024,
    max_commands: usize = 64,
    max_internal_events: usize = 64,
    max_microsteps: usize = 256,
    max_hierarchy_depth: usize = 32,

    pub fn isValid(self: DefinitionBounds) bool {
        return self.max_states > 0 and
            self.max_transitions > 0 and
            self.max_commands > 0 and
            self.max_internal_events > 0 and
            self.max_microsteps > 0 and
            self.max_hierarchy_depth > 0;
    }
};

pub const ValidationFindingKind = enum {
    empty_machine_id,
    invalid_version,
    no_states,
    invalid_bounds,
    state_limit_exceeded,
    transition_limit_exceeded,
    missing_initial_state,
    state_not_declared,
    duplicate_state,
    duplicate_transition_id,
    empty_transition_id,
    transition_source_not_declared,
    transition_target_not_declared,
    final_state_has_outgoing_transition,
    empty_guard_id,
    empty_action_id,
    state_parent_not_declared,
    state_parent_is_self,
    state_parent_cycle,
    hierarchy_depth_exceeded,
    compound_missing_initial,
    compound_initial_not_child,
    atomic_state_has_initial,
    parallel_state_has_initial,
    non_container_has_children,
    history_missing_parent,
    empty_completion_id,
    empty_invocation_id,
    duplicate_invocation_id,
};

pub fn validationFindingMessage(kind: ValidationFindingKind) []const u8 {
    return switch (kind) {
        .empty_machine_id => "statechart machine id must not be empty",
        .invalid_version => "statechart definition version must be greater than zero",
        .no_states => "statechart definition must declare at least one state",
        .invalid_bounds => "statechart runtime bounds must all be greater than zero",
        .state_limit_exceeded => "statechart definition exceeds its configured state limit",
        .transition_limit_exceeded => "statechart definition exceeds its configured transition limit",
        .missing_initial_state => "statechart initial state is not declared",
        .state_not_declared => "statechart enum state is missing from the definition",
        .duplicate_state => "statechart state is declared more than once",
        .duplicate_transition_id => "statechart transition id is declared more than once",
        .empty_transition_id => "statechart transition id must not be empty",
        .transition_source_not_declared => "statechart transition source is not declared",
        .transition_target_not_declared => "statechart transition target is not declared",
        .final_state_has_outgoing_transition => "statechart final state must not have outgoing transitions",
        .empty_guard_id => "statechart guard id must not be empty",
        .empty_action_id => "statechart action id must not be empty",
        .state_parent_not_declared => "statechart state parent is not declared",
        .state_parent_is_self => "statechart state cannot be its own parent",
        .state_parent_cycle => "statechart state hierarchy contains a parent cycle",
        .hierarchy_depth_exceeded => "statechart state hierarchy exceeds its configured depth limit",
        .compound_missing_initial => "statechart compound state must declare an initial child",
        .compound_initial_not_child => "statechart compound initial state must be a direct child",
        .atomic_state_has_initial => "statechart atomic, final, or history state cannot declare an initial state",
        .parallel_state_has_initial => "statechart parallel state enters every region and cannot declare one initial state",
        .non_container_has_children => "statechart children require a compound or parallel parent",
        .history_missing_parent => "statechart history state must belong to a compound or parallel parent",
        .empty_completion_id => "statechart completion event mapping id must not be empty",
        .empty_invocation_id => "statechart invocation id must not be empty",
        .duplicate_invocation_id => "statechart invocation id must be unique within the definition",
    };
}

pub fn EventTagType(comptime Event: type) type {
    return switch (@typeInfo(Event)) {
        .@"enum" => Event,
        .@"union" => |union_info| union_info.tag_type orelse @compileError(
            "zigeffect statechart Event must be an enum or tagged union(enum), got untagged union " ++ @typeName(Event),
        ),
        else => @compileError(
            "zigeffect statechart Event must be an enum or tagged union(enum), got " ++ @typeName(Event),
        ),
    };
}

fn assertStateType(comptime State: type) void {
    switch (@typeInfo(State)) {
        .@"enum" => {},
        else => @compileError("zigeffect statechart State must be an enum, got " ++ @typeName(State)),
    }
}

pub fn isValueContext(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .bool, .int, .float, .@"enum", .void => true,
        .array => |array| isValueContext(array.child),
        .vector => |vector| isValueContext(vector.child),
        .optional => |optional| isValueContext(optional.child),
        .@"struct" => |structure| value: {
            // Generational handles still identify external mutable resources;
            // they belong in command executors, not replayable machine context.
            if (@hasDecl(T, "ResourceType")) break :value false;
            inline for (structure.fields) |field| {
                if (!isValueContext(field.type)) break :value false;
            }
            break :value true;
        },
        .@"union" => |union_info| value: {
            if (union_info.tag_type == null) break :value false;
            inline for (union_info.fields) |field| {
                if (!isValueContext(field.type)) break :value false;
            }
            break :value true;
        },
        else => false,
    };
}

fn assertValueContext(comptime Context: type) void {
    if (!isValueContext(Context)) {
        @compileError(
            "zigeffect statechart Context must recursively contain only owned value data; " ++
                "pointers, slices, allocators, functions, untagged unions, and resource handles belong in command executors, got " ++
                @typeName(Context),
        );
    }
}

pub fn Definition(
    comptime State: type,
    comptime Event: type,
    comptime Context: type,
    comptime Command: type,
) type {
    assertStateType(State);
    assertValueContext(Context);
    const EventTagT = EventTagType(Event);

    return struct {
        const Self = @This();

        pub const StateType = State;
        pub const EventType = Event;
        pub const EventTag = EventTagT;
        pub const ContextType = Context;
        pub const CommandType = Command;

        pub const CommandSink = struct {
            buffer: []Command,
            len: usize = 0,
            event_buffer: ?[]Event = null,
            event_len: usize = 0,

            pub const Error = error{ CommandLimitExceeded, InternalEventLimitExceeded };

            pub fn init(buffer: []Command) CommandSink {
                return .{ .buffer = buffer };
            }

            pub fn initWithEvents(buffer: []Command, event_buffer: []Event) CommandSink {
                return .{ .buffer = buffer, .event_buffer = event_buffer };
            }

            pub fn emit(self: *CommandSink, command: Command) Error!void {
                if (self.len >= self.buffer.len) return error.CommandLimitExceeded;
                self.buffer[self.len] = command;
                self.len += 1;
            }

            pub fn commands(self: *const CommandSink) []const Command {
                return self.buffer[0..self.len];
            }

            pub fn raise(self: *CommandSink, event: Event) Error!void {
                const target_buffer = self.event_buffer orelse return error.InternalEventLimitExceeded;
                if (self.event_len >= target_buffer.len) return error.InternalEventLimitExceeded;
                target_buffer[self.event_len] = event;
                self.event_len += 1;
            }

            pub fn events(self: *const CommandSink) []const Event {
                const target_buffer = self.event_buffer orelse return &.{};
                return target_buffer[0..self.event_len];
            }
        };

        pub const Guard = struct {
            id: []const u8,
            evaluate: *const fn (context: *const Context, event: *const Event) bool,
            description: []const u8 = "",
            source: SourceRef = .{},
        };

        pub const Action = struct {
            id: []const u8,
            execute: *const fn (context: *Context, event: *const Event, commands: *CommandSink) anyerror!void,
            description: []const u8 = "",
            source: SourceRef = .{},
        };

        pub const Completion = struct {
            id: []const u8,
            event_for: *const fn (completed_state: State) ?Event,
            description: []const u8 = "",
            source: SourceRef = .{},
        };

        /// A child actor/service lifecycle bound to a state's active lifetime.
        /// Start/stop reducers emit typed commands; external effects still run
        /// only after the statechart transaction commits.
        pub const Invocation = struct {
            id: []const u8,
            start: Action,
            stop: ?Action = null,
            description: []const u8 = "",
            source: SourceRef = .{},
        };

        pub const StateNode = struct {
            id: State,
            kind: StateKind = .atomic,
            parent: ?State = null,
            initial: ?State = null,
            entry_actions: []const Action = &.{},
            exit_actions: []const Action = &.{},
            invocations: []const Invocation = &.{},
            description: []const u8 = "",
            source: SourceRef = .{},
        };

        pub const Transition = struct {
            id: []const u8,
            source: State,
            event: ?EventTagT = null,
            target: ?State = null,
            kind: TransitionKind = .external,
            reenter: bool = false,
            guard: ?Guard = null,
            actions: []const Action = &.{},
            description: []const u8 = "",
            source_ref: SourceRef = .{},
        };

        pub const Config = struct {
            id: []const u8,
            version: u32,
            initial: State,
            states: []const StateNode,
            transitions: []const Transition,
            completion: ?Completion = null,
            bounds: DefinitionBounds = .{},
            description: []const u8 = "",
            source: SourceRef = .{},
        };

        pub const Metadata = struct {
            schema: []const u8 = statechart_definition_schema,
            schema_version: u32 = statechart_definition_schema_version,
            id: []const u8,
            version: u32,
            state_type_name: []const u8,
            event_type_name: []const u8,
            context_type_name: []const u8,
            command_type_name: []const u8,
            state_count: usize,
            transition_count: usize,
            fingerprint: u64,
        };

        pub const ValidationFinding = struct {
            id: u64,
            kind: ValidationFindingKind,
            state: ?State = null,
            transition_id: []const u8 = "",
            message: []const u8,
        };

        pub const ValidationReport = struct {
            items: [max_validation_findings]ValidationFinding = undefined,
            count: usize = 0,
            truncated: bool = false,

            pub fn isValid(self: *const ValidationReport) bool {
                return self.count == 0 and !self.truncated;
            }

            pub fn findings(self: *const ValidationReport) []const ValidationFinding {
                return self.items[0..self.count];
            }

            pub fn has(self: *const ValidationReport, kind: ValidationFindingKind) bool {
                for (self.findings()) |finding| {
                    if (finding.kind == kind) return true;
                }
                return false;
            }

            fn add(
                self: *ValidationReport,
                machine_id: []const u8,
                kind: ValidationFindingKind,
                state: ?State,
                transition_id: []const u8,
                ordinal: usize,
            ) void {
                if (self.count >= self.items.len) {
                    self.truncated = true;
                    return;
                }
                self.items[self.count] = .{
                    .id = validationFindingId(machine_id, kind, state, transition_id, ordinal),
                    .kind = kind,
                    .state = state,
                    .transition_id = transition_id,
                    .message = validationFindingMessage(kind),
                };
                self.count += 1;
            }
        };

        id: []const u8,
        version: u32,
        initial: State,
        states: []const StateNode,
        transitions: []const Transition,
        completion: ?Completion,
        bounds: DefinitionBounds,
        description: []const u8,
        source: SourceRef,

        pub fn init(comptime config: Config) Self {
            return .{
                .id = config.id,
                .version = config.version,
                .initial = config.initial,
                .states = config.states,
                .transitions = config.transitions,
                .completion = config.completion,
                .bounds = config.bounds,
                .description = config.description,
                .source = config.source,
            };
        }

        pub fn eventTag(event: Event) EventTagT {
            return switch (@typeInfo(Event)) {
                .@"enum" => event,
                .@"union" => std.meta.activeTag(event),
                else => unreachable,
            };
        }

        pub fn metadata(self: *const Self) Metadata {
            return .{
                .id = self.id,
                .version = self.version,
                .state_type_name = @typeName(State),
                .event_type_name = @typeName(Event),
                .context_type_name = @typeName(Context),
                .command_type_name = @typeName(Command),
                .state_count = self.states.len,
                .transition_count = self.transitions.len,
                .fingerprint = self.fingerprint(),
            };
        }

        pub fn validate(self: *const Self) ValidationReport {
            var report = ValidationReport{};
            if (self.id.len == 0) report.add(self.id, .empty_machine_id, null, "", 0);
            if (self.version == 0) report.add(self.id, .invalid_version, null, "", 0);
            if (self.states.len == 0) report.add(self.id, .no_states, null, "", 0);
            if (!self.bounds.isValid()) report.add(self.id, .invalid_bounds, null, "", 0);
            if (self.completion) |completion| {
                if (completion.id.len == 0) report.add(self.id, .empty_completion_id, null, "", 0);
            }
            if (self.states.len > self.bounds.max_states) report.add(self.id, .state_limit_exceeded, null, "", self.states.len);
            if (self.transitions.len > self.bounds.max_transitions) report.add(self.id, .transition_limit_exceeded, null, "", self.transitions.len);
            if (!self.hasState(self.initial)) report.add(self.id, .missing_initial_state, self.initial, "", 0);

            inline for (std.meta.tags(State), 0..) |state, ordinal| {
                if (!self.hasState(state)) report.add(self.id, .state_not_declared, state, "", ordinal);
            }

            for (self.states, 0..) |state, state_index| {
                for (self.states[state_index + 1 ..], state_index + 1..) |candidate, candidate_index| {
                    if (candidate.id == state.id) report.add(self.id, .duplicate_state, state.id, "", candidate_index);
                }
                if (state.parent) |parent| {
                    if (!self.hasState(parent)) {
                        report.add(self.id, .state_parent_not_declared, state.id, "", state_index);
                    } else if (parent == state.id) {
                        report.add(self.id, .state_parent_is_self, state.id, "", state_index);
                    }
                }

                switch (state.kind) {
                    .compound => {
                        if (state.initial) |initial| {
                            if (!self.isDirectChild(initial, state.id)) {
                                report.add(self.id, .compound_initial_not_child, state.id, "", state_index);
                            }
                        } else {
                            report.add(self.id, .compound_missing_initial, state.id, "", state_index);
                        }
                    },
                    .parallel => if (state.initial != null) {
                        report.add(self.id, .parallel_state_has_initial, state.id, "", state_index);
                    },
                    .atomic, .final, .history_shallow, .history_deep => if (state.initial != null) {
                        report.add(self.id, .atomic_state_has_initial, state.id, "", state_index);
                    },
                }

                if (self.hasDirectChildren(state.id) and state.kind != .compound and state.kind != .parallel) {
                    report.add(self.id, .non_container_has_children, state.id, "", state_index);
                }
                if ((state.kind == .history_shallow or state.kind == .history_deep) and state.parent == null) {
                    report.add(self.id, .history_missing_parent, state.id, "", state_index);
                }

                const hierarchy = self.hierarchyStatus(state.id);
                if (hierarchy.cycle) report.add(self.id, .state_parent_cycle, state.id, "", state_index);
                if (hierarchy.depth_exceeded) report.add(self.id, .hierarchy_depth_exceeded, state.id, "", state_index);
                validateActionIds(&report, self.id, state.entry_actions, state.id, "", state_index * 2);
                validateActionIds(&report, self.id, state.exit_actions, state.id, "", state_index * 2 + 1);
                for (state.invocations, 0..) |invocation, invocation_index| {
                    if (invocation.id.len == 0) {
                        report.add(self.id, .empty_invocation_id, state.id, "", state_index + invocation_index);
                    }
                    if (invocation.start.id.len == 0) {
                        report.add(self.id, .empty_action_id, state.id, "", state_index + invocation_index);
                    }
                    if (invocation.stop) |stop| {
                        if (stop.id.len == 0) report.add(self.id, .empty_action_id, state.id, "", state_index + invocation_index);
                    }
                    for (self.states[0..state_index]) |previous_state| {
                        for (previous_state.invocations) |previous| {
                            if (std.mem.eql(u8, previous.id, invocation.id)) {
                                report.add(self.id, .duplicate_invocation_id, state.id, "", state_index + invocation_index);
                            }
                        }
                    }
                    for (state.invocations[0..invocation_index]) |previous| {
                        if (std.mem.eql(u8, previous.id, invocation.id)) {
                            report.add(self.id, .duplicate_invocation_id, state.id, "", state_index + invocation_index);
                        }
                    }
                }
            }

            for (self.transitions, 0..) |transition, transition_index| {
                if (transition.id.len == 0) report.add(self.id, .empty_transition_id, transition.source, transition.id, transition_index);
                for (self.transitions[transition_index + 1 ..], transition_index + 1..) |candidate, candidate_index| {
                    if (std.mem.eql(u8, candidate.id, transition.id)) {
                        report.add(self.id, .duplicate_transition_id, transition.source, transition.id, candidate_index);
                    }
                }
                if (!self.hasState(transition.source)) {
                    report.add(self.id, .transition_source_not_declared, transition.source, transition.id, transition_index);
                } else if (self.stateKind(transition.source) == .final) {
                    report.add(self.id, .final_state_has_outgoing_transition, transition.source, transition.id, transition_index);
                }
                if (transition.target) |target| {
                    if (!self.hasState(target)) {
                        report.add(self.id, .transition_target_not_declared, target, transition.id, transition_index);
                    }
                }
                if (transition.guard) |guard| {
                    if (guard.id.len == 0) report.add(self.id, .empty_guard_id, transition.source, transition.id, transition_index);
                }
                validateActionIds(&report, self.id, transition.actions, transition.source, transition.id, transition_index);
            }

            return report;
        }

        pub fn fingerprint(self: *const Self) u64 {
            var hasher = std.hash.Fnv1a_64.init();
            hashText(&hasher, statechart_definition_schema);
            hashText(&hasher, self.id);
            hashInt(&hasher, self.version);
            hashEnum(&hasher, self.initial);
            hashBounds(&hasher, self.bounds);
            if (self.completion) |completion| {
                hashInt(&hasher, 1);
                hashText(&hasher, completion.id);
            } else {
                hashInt(&hasher, 0);
            }

            for (self.states) |state| {
                hashEnum(&hasher, state.id);
                hashEnum(&hasher, state.kind);
                hashOptionalEnum(&hasher, state.parent);
                hashOptionalEnum(&hasher, state.initial);
                hashActions(&hasher, state.entry_actions);
                hashActions(&hasher, state.exit_actions);
                hashInt(&hasher, state.invocations.len);
                for (state.invocations) |invocation| {
                    hashText(&hasher, invocation.id);
                    hashText(&hasher, invocation.start.id);
                    if (invocation.stop) |stop| {
                        hashInt(&hasher, 1);
                        hashText(&hasher, stop.id);
                    } else hashInt(&hasher, 0);
                }
            }

            for (self.transitions) |transition| {
                hashText(&hasher, transition.id);
                hashEnum(&hasher, transition.source);
                hashOptionalEnum(&hasher, transition.event);
                hashOptionalEnum(&hasher, transition.target);
                hashEnum(&hasher, transition.kind);
                hashInt(&hasher, @intFromBool(transition.reenter));
                if (transition.guard) |guard| {
                    hashInt(&hasher, 1);
                    hashText(&hasher, guard.id);
                } else {
                    hashInt(&hasher, 0);
                }
                hashActions(&hasher, transition.actions);
            }

            return hasher.final();
        }

        pub fn hasState(self: *const Self, id: State) bool {
            for (self.states) |state| {
                if (state.id == id) return true;
            }
            return false;
        }

        pub fn stateKind(self: *const Self, id: State) StateKind {
            for (self.states) |state| {
                if (state.id == id) return state.kind;
            }
            return .atomic;
        }

        pub fn stateNode(self: *const Self, id: State) ?StateNode {
            for (self.states) |state| {
                if (state.id == id) return state;
            }
            return null;
        }

        pub fn isDirectChild(self: *const Self, child: State, parent: State) bool {
            const node = self.stateNode(child) orelse return false;
            return node.parent != null and node.parent.? == parent;
        }

        pub fn hasDirectChildren(self: *const Self, parent: State) bool {
            for (self.states) |state| {
                if (state.parent != null and state.parent.? == parent) return true;
            }
            return false;
        }

        pub fn isDescendant(self: *const Self, child: State, ancestor: State) bool {
            var cursor = self.stateNode(child) orelse return false;
            var remaining = self.states.len;
            while (cursor.parent) |parent| {
                if (parent == ancestor) return true;
                if (remaining == 0) return false;
                remaining -= 1;
                cursor = self.stateNode(parent) orelse return false;
            }
            return false;
        }

        const HierarchyStatus = struct { cycle: bool = false, depth_exceeded: bool = false };

        fn hierarchyStatus(self: *const Self, start: State) HierarchyStatus {
            var cursor = self.stateNode(start) orelse return .{};
            var depth: usize = 0;
            while (cursor.parent) |parent| {
                if (parent == start) return .{ .cycle = true };
                depth += 1;
                if (depth > self.bounds.max_hierarchy_depth) return .{ .depth_exceeded = true };
                if (depth > self.states.len) return .{ .cycle = true };
                cursor = self.stateNode(parent) orelse return .{};
            }
            return .{};
        }

        fn validateActionIds(
            report: *ValidationReport,
            machine_id: []const u8,
            actions: []const Action,
            state: State,
            transition_id: []const u8,
            ordinal_base: usize,
        ) void {
            for (actions, 0..) |action, action_index| {
                if (action.id.len == 0) {
                    report.add(machine_id, .empty_action_id, state, transition_id, ordinal_base + action_index);
                }
            }
        }

        fn validationFindingId(
            machine_id: []const u8,
            kind: ValidationFindingKind,
            state: ?State,
            transition_id: []const u8,
            ordinal: usize,
        ) u64 {
            var hasher = std.hash.Fnv1a_64.init();
            hashText(&hasher, machine_id);
            hashText(&hasher, @tagName(kind));
            hashOptionalEnum(&hasher, state);
            hashText(&hasher, transition_id);
            hashInt(&hasher, ordinal);
            const result = hasher.final();
            return if (result == 0) 1 else result;
        }

        fn hashActions(hasher: *std.hash.Fnv1a_64, actions: []const Action) void {
            hashInt(hasher, actions.len);
            for (actions) |action| hashText(hasher, action.id);
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

fn hashEnum(hasher: *std.hash.Fnv1a_64, value: anytype) void {
    hashInt(hasher, @intFromEnum(value));
}

fn hashOptionalEnum(hasher: *std.hash.Fnv1a_64, value: anytype) void {
    if (value) |present| {
        hashInt(hasher, 1);
        hashEnum(hasher, present);
    } else {
        hashInt(hasher, 0);
    }
}

fn hashBounds(hasher: *std.hash.Fnv1a_64, bounds: DefinitionBounds) void {
    hashInt(hasher, bounds.max_states);
    hashInt(hasher, bounds.max_transitions);
    hashInt(hasher, bounds.max_commands);
    hashInt(hasher, bounds.max_internal_events);
    hashInt(hasher, bounds.max_microsteps);
    hashInt(hasher, bounds.max_hierarchy_depth);
}

test "definition module event tags work for enums and tagged unions" {
    const EnumEvent = enum { tick };
    const UnionEvent = union(enum) { tick: u32, stop };
    try std.testing.expect(EventTagType(EnumEvent) == EnumEvent);
    try std.testing.expect(EventTagType(UnionEvent) == std.meta.Tag(UnionEvent));
}
