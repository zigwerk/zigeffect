const std = @import("std");
const Secrets = @import("../secrets/root.zig");

pub const workflow_plan_schema = "zigeffect.statechart.workflow-plan.v1";
pub const workflow_plan_schema_version: u32 = 1;
pub const max_plan_states: usize = 256;
pub const max_plan_transitions: usize = 1024;

pub const PlanError = error{
    UnsupportedSchema,
    InvalidPlan,
    InvalidIdentifier,
    DuplicateState,
    DuplicateTransition,
    UnknownState,
    MissingInitialState,
    SecretDetected,
    PlanLimitExceeded,
};

pub const StateKind = enum { atomic, final, compound, parallel, history_shallow, history_deep };

pub const PlanState = struct {
    id: []const u8,
    kind: StateKind = .atomic,
    parent: ?[]const u8 = null,
    initial: ?[]const u8 = null,
    description: []const u8 = "",
};

pub const PlanTransition = struct {
    id: []const u8,
    source: []const u8,
    event: ?[]const u8 = null,
    target: ?[]const u8 = null,
    guard: ?[]const u8 = null,
    actions: []const []const u8 = &.{},
    description: []const u8 = "",
};

pub const PlanInvariant = struct {
    id: []const u8,
    kind: []const u8,
    state: []const u8,
    before: ?[]const u8 = null,
};

pub const WorkflowPlan = struct {
    schema: []const u8,
    schema_version: u32,
    id: []const u8,
    version: u32,
    initial: []const u8,
    description: []const u8 = "",
    states: []PlanState,
    transitions: []PlanTransition,
    invariants: []PlanInvariant = &.{},

    pub fn validate(self: WorkflowPlan) !void {
        if (!std.mem.eql(u8, self.schema, workflow_plan_schema) or self.schema_version != workflow_plan_schema_version) return error.UnsupportedSchema;
        try validateIdentifier(self.id);
        try validateIdentifier(self.initial);
        try validateText(self.description);
        if (self.version == 0 or self.states.len == 0) return error.InvalidPlan;
        if (self.states.len > max_plan_states or self.transitions.len > max_plan_transitions) return error.PlanLimitExceeded;
        var initial_found = false;
        for (self.states, 0..) |state, index| {
            try validateIdentifier(state.id);
            try validateText(state.description);
            if (std.mem.eql(u8, state.id, self.initial)) initial_found = true;
            for (self.states[0..index]) |previous| if (std.mem.eql(u8, previous.id, state.id)) return error.DuplicateState;
            if (state.parent) |parent| {
                try validateIdentifier(parent);
                if (!hasState(self.states, parent)) return error.UnknownState;
                if (std.mem.eql(u8, parent, state.id)) return error.InvalidPlan;
                const parent_state = findState(self.states, parent).?;
                if (parent_state.kind != .compound and parent_state.kind != .parallel) return error.InvalidPlan;
            }
            if (state.initial) |initial| {
                try validateIdentifier(initial);
                if (!hasState(self.states, initial)) return error.UnknownState;
                const initial_state = findState(self.states, initial).?;
                if (initial_state.parent == null or !std.mem.eql(u8, initial_state.parent.?, state.id)) return error.InvalidPlan;
            }
            switch (state.kind) {
                .compound => if (state.initial == null) return error.InvalidPlan,
                .parallel => if (state.initial != null) return error.InvalidPlan,
                .history_shallow, .history_deep => if (state.initial != null or state.parent == null) return error.InvalidPlan,
                .atomic, .final => if (state.initial != null) return error.InvalidPlan,
            }
            var ancestor = state.parent;
            var depth: usize = 0;
            while (ancestor) |parent| {
                if (std.mem.eql(u8, parent, state.id) or depth >= self.states.len) return error.InvalidPlan;
                ancestor = findState(self.states, parent).?.parent;
                depth += 1;
            }
        }
        if (!initial_found) return error.MissingInitialState;
        for (self.transitions, 0..) |transition, index| {
            try validateIdentifier(transition.id);
            try validateIdentifier(transition.source);
            try validateText(transition.description);
            if (!hasState(self.states, transition.source)) return error.UnknownState;
            if (findState(self.states, transition.source).?.kind == .final) return error.InvalidPlan;
            if (transition.target) |target| {
                try validateIdentifier(target);
                if (!hasState(self.states, target)) return error.UnknownState;
            }
            if (transition.event) |event| try validateIdentifier(event);
            if (transition.guard) |guard| try validateIdentifier(guard);
            for (transition.actions, 0..) |action, action_index| {
                try validateIdentifier(action);
                for (transition.actions[0..action_index]) |prior| if (std.mem.eql(u8, prior, action)) return error.InvalidPlan;
            }
            for (self.transitions[0..index]) |previous| if (std.mem.eql(u8, previous.id, transition.id)) return error.DuplicateTransition;
        }
        for (self.invariants) |invariant| {
            try validateIdentifier(invariant.id);
            try validateIdentifier(invariant.kind);
            try validateIdentifier(invariant.state);
            if (!hasState(self.states, invariant.state)) return error.UnknownState;
            if (invariant.before) |before| if (!hasState(self.states, before)) return error.UnknownState;
        }
    }
};

pub const ParsedPlan = std.json.Parsed(WorkflowPlan);

pub fn parse(allocator: std.mem.Allocator, json: []const u8) !ParsedPlan {
    var parsed = try std.json.parseFromSlice(WorkflowPlan, allocator, json, .{ .ignore_unknown_fields = false });
    errdefer parsed.deinit();
    try parsed.value.validate();
    return parsed;
}

pub fn generateZig(allocator: std.mem.Allocator, plan: WorkflowPlan) ![]u8 {
    try plan.validate();
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "const zstd = @import(\"zigeffect_std\");\n\n");
    try output.appendSlice(allocator, "pub const State = enum { ");
    for (plan.states, 0..) |state, index| {
        if (index != 0) try output.appendSlice(allocator, ", ");
        try appendZigTagDeclaration(&output, allocator, state.id);
    }
    try output.appendSlice(allocator, " };\n");

    try output.appendSlice(allocator, "pub const Event = enum { ");
    var event_count: usize = 0;
    for (plan.transitions, 0..) |transition, index| {
        const event = transition.event orelse continue;
        if (firstEventIndex(plan.transitions, event) != index) continue;
        if (event_count != 0) try output.appendSlice(allocator, ", ");
        try appendZigTagDeclaration(&output, allocator, event);
        event_count += 1;
    }
    if (event_count == 0) try appendZigTagDeclaration(&output, allocator, "internal");
    try output.appendSlice(allocator, " };\n");

    const action_count = uniqueActionCount(plan.transitions);
    if (action_count == 0) {
        try output.appendSlice(allocator, "pub const Command = void;\n");
    } else {
        try output.appendSlice(allocator, "pub const Command = enum { ");
        var action_index: usize = 0;
        for (plan.transitions) |transition| for (transition.actions) |action| {
            if (!isFirstAction(plan.transitions, action, transition.id)) continue;
            if (action_index != 0) try output.appendSlice(allocator, ", ");
            try appendZigTagDeclaration(&output, allocator, action);
            action_index += 1;
        };
        try output.appendSlice(allocator, " };\n");
    }
    try output.appendSlice(allocator, "pub const Context = void;\n");
    try output.appendSlice(allocator, "pub const Definition = zstd.fx.statechart.Definition(State, Event, Context, Command);\n\n");

    var guard_index: usize = 0;
    for (plan.transitions, 0..) |transition, index| {
        const guard = transition.guard orelse continue;
        if (firstGuardIndex(plan.transitions, guard) != index) continue;
        try output.print(allocator, "fn guard_{d}(_: *const Context, _: *const Event) bool {{\n    // Fail closed until the generated guard is implemented: ", .{guard_index});
        try appendZigString(&output, allocator, guard);
        try output.appendSlice(allocator, "\n    return false;\n}\n\n");
        guard_index += 1;
    }

    if (action_count != 0) {
        var generated_action: usize = 0;
        for (plan.transitions) |transition| for (transition.actions) |action| {
            if (!isFirstAction(plan.transitions, action, transition.id)) continue;
            try output.print(allocator, "fn action_{d}(_: *Context, _: *const Event, sink: *Definition.CommandSink) anyerror!void {{\n    try sink.emit(", .{generated_action});
            try appendZigIdentifier(&output, allocator, action);
            try output.appendSlice(allocator, ");\n}\n\n");
            generated_action += 1;
        };
    }

    try output.appendSlice(allocator, "pub const definition = Definition.init(.{\n    .id = ");
    try appendZigString(&output, allocator, plan.id);
    try output.print(allocator, ",\n    .version = {d},\n    .initial = ", .{plan.version});
    try appendZigIdentifier(&output, allocator, plan.initial);
    try output.appendSlice(allocator, ",\n    .description = ");
    try appendZigString(&output, allocator, plan.description);
    try output.appendSlice(allocator, ",\n    .states = &.{\n");
    for (plan.states) |state| {
        try output.appendSlice(allocator, "        .{ .id = ");
        try appendZigIdentifier(&output, allocator, state.id);
        if (state.kind != .atomic) try output.print(allocator, ", .kind = .{s}", .{@tagName(state.kind)});
        if (state.parent) |parent| {
            try output.appendSlice(allocator, ", .parent = ");
            try appendZigIdentifier(&output, allocator, parent);
        }
        if (state.initial) |initial| {
            try output.appendSlice(allocator, ", .initial = ");
            try appendZigIdentifier(&output, allocator, initial);
        }
        if (state.description.len != 0) {
            try output.appendSlice(allocator, ", .description = ");
            try appendZigString(&output, allocator, state.description);
        }
        try output.appendSlice(allocator, " },\n");
    }
    try output.appendSlice(allocator, "    },\n    .transitions = &.{\n");
    for (plan.transitions) |transition| {
        try output.appendSlice(allocator, "        .{ .id = ");
        try appendZigString(&output, allocator, transition.id);
        try output.appendSlice(allocator, ", .source = ");
        try appendZigIdentifier(&output, allocator, transition.source);
        if (transition.event) |event| {
            try output.appendSlice(allocator, ", .event = ");
            try appendZigIdentifier(&output, allocator, event);
        }
        if (transition.target) |target| {
            try output.appendSlice(allocator, ", .target = ");
            try appendZigIdentifier(&output, allocator, target);
        }
        if (transition.guard) |guard| {
            try output.appendSlice(allocator, ", .guard = .{ .id = ");
            try appendZigString(&output, allocator, guard);
            try output.print(allocator, ", .evaluate = guard_{d} }}", .{firstGuardIndex(plan.transitions, guard)});
        }
        if (transition.actions.len != 0) {
            try output.appendSlice(allocator, ", .actions = &.{ ");
            for (transition.actions, 0..) |action, index| {
                if (index != 0) try output.appendSlice(allocator, ", ");
                try output.appendSlice(allocator, ".{ .id = ");
                try appendZigString(&output, allocator, action);
                try output.print(allocator, ", .execute = action_{d} }}", .{actionOrdinal(plan.transitions, action)});
            }
            try output.appendSlice(allocator, " }");
        }
        try output.appendSlice(allocator, " },\n");
    }
    try output.appendSlice(allocator, "    },\n});\n\npub const Runtime = zstd.fx.statechart.ConfigurationMachine(Definition);\n");
    return output.toOwnedSlice(allocator);
}

pub const PatternKind = enum {
    human_approval,
    retry_escalation,
    tool_execution,
    parallel_research,
    consensus_review,
    saga_compensation,
    timeout_fallback,
    budget_enforcement,
    child_delegation,
    circuit_breaker,
    long_running_job,
    incident_remediation,
};

const TemplateTransition = struct { id: []const u8, source: usize, event: []const u8, target: usize };
const PatternTemplate = struct { states: []const []const u8, transitions: []const TemplateTransition, terminal_state: usize };

pub const PatternExpansion = struct {
    allocator: std.mem.Allocator,
    states: []PlanState,
    transitions: []PlanTransition,
    invariants: []PlanInvariant,

    pub fn deinit(self: *PatternExpansion) void {
        for (self.invariants) |invariant| self.allocator.free(invariant.id);
        for (self.transitions) |transition| {
            self.allocator.free(transition.id);
            if (transition.event) |event| self.allocator.free(event);
        }
        for (self.states) |state| self.allocator.free(state.id);
        self.allocator.free(self.invariants);
        self.allocator.free(self.transitions);
        self.allocator.free(self.states);
        self.* = undefined;
    }
};

pub fn expandPattern(allocator: std.mem.Allocator, kind: PatternKind, namespace: []const u8) !PatternExpansion {
    try validateIdentifier(namespace);
    const template = patternTemplate(kind);
    const states = try allocator.alloc(PlanState, template.states.len);
    errdefer allocator.free(states);
    var state_count: usize = 0;
    errdefer for (states[0..state_count]) |state| allocator.free(state.id);
    for (template.states, 0..) |suffix, index| {
        states[index] = .{ .id = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ namespace, suffix }), .kind = if (isFinalState(kind, index, template.terminal_state)) .final else .atomic };
        state_count += 1;
    }
    if (kind == .parallel_research) {
        states[0].kind = .compound;
        states[0].initial = states[1].id;
        states[1].parent = states[0].id;
        states[2].kind = .parallel;
        states[2].parent = states[0].id;
        states[3].kind = .compound;
        states[3].parent = states[2].id;
        states[3].initial = states[4].id;
        states[4].parent = states[3].id;
        states[5].parent = states[3].id;
        states[6].kind = .compound;
        states[6].parent = states[2].id;
        states[6].initial = states[7].id;
        states[7].parent = states[6].id;
        states[8].parent = states[6].id;
        states[9].parent = states[0].id;
    }

    const transitions = try allocator.alloc(PlanTransition, template.transitions.len);
    errdefer allocator.free(transitions);
    var transition_count: usize = 0;
    errdefer for (transitions[0..transition_count]) |transition| {
        allocator.free(transition.id);
        allocator.free(transition.event.?);
    };
    for (template.transitions, 0..) |source, index| {
        const id = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ namespace, source.id });
        const event = std.fmt.allocPrint(allocator, "{s}.{s}", .{ namespace, source.event }) catch |err| {
            allocator.free(id);
            return err;
        };
        transitions[index] = .{
            .id = id,
            .source = states[source.source].id,
            .event = event,
            .target = states[source.target].id,
        };
        transition_count += 1;
    }

    const invariants = try allocator.alloc(PlanInvariant, 1);
    errdefer allocator.free(invariants);
    invariants[0] = .{
        .id = try std.fmt.allocPrint(allocator, "{s}.eventually-terminal", .{namespace}),
        .kind = "terminal_reachable",
        .state = states[template.terminal_state].id,
    };
    return .{ .allocator = allocator, .states = states, .transitions = transitions, .invariants = invariants };
}

fn patternTemplate(kind: PatternKind) PatternTemplate {
    return switch (kind) {
        .human_approval => .{ .states = &.{ "awaiting", "approved", "rejected", "expired" }, .transitions = &.{ .{ .id = "approve", .source = 0, .event = "approve", .target = 1 }, .{ .id = "reject", .source = 0, .event = "reject", .target = 2 }, .{ .id = "expire", .source = 0, .event = "approval_expired", .target = 3 } }, .terminal_state = 1 },
        .retry_escalation => .{ .states = &.{ "attempting", "backoff", "completed", "escalated" }, .transitions = &.{ .{ .id = "retry", .source = 0, .event = "failed", .target = 1 }, .{ .id = "resume", .source = 1, .event = "delay_elapsed", .target = 0 }, .{ .id = "complete", .source = 0, .event = "succeeded", .target = 2 }, .{ .id = "escalate", .source = 0, .event = "retry_exhausted", .target = 3 } }, .terminal_state = 2 },
        .tool_execution => .{ .states = &.{ "ready", "executing", "completed", "failed", "cancelled" }, .transitions = &.{ .{ .id = "execute", .source = 0, .event = "execute", .target = 1 }, .{ .id = "complete", .source = 1, .event = "tool_completed", .target = 2 }, .{ .id = "fail", .source = 1, .event = "tool_failed", .target = 3 }, .{ .id = "cancel", .source = 1, .event = "cancel", .target = 4 } }, .terminal_state = 2 },
        .parallel_research => .{ .states = &.{ "root", "planning", "researching", "source_a", "source_a_running", "source_a_done", "source_b", "source_b_running", "source_b_done", "synthesized" }, .transitions = &.{ .{ .id = "dispatch", .source = 1, .event = "dispatch", .target = 2 }, .{ .id = "source_a_complete", .source = 4, .event = "source_a_completed", .target = 5 }, .{ .id = "source_b_complete", .source = 7, .event = "source_b_completed", .target = 8 }, .{ .id = "synthesize", .source = 2, .event = "all_completed", .target = 9 } }, .terminal_state = 9 },
        .consensus_review => .{ .states = &.{ "collecting", "reviewing", "consensus", "rejected" }, .transitions = &.{ .{ .id = "review", .source = 0, .event = "quorum", .target = 1 }, .{ .id = "accept", .source = 1, .event = "accepted", .target = 2 }, .{ .id = "reject", .source = 1, .event = "rejected", .target = 3 } }, .terminal_state = 2 },
        .saga_compensation => .{ .states = &.{ "executing", "compensating", "settled" }, .transitions = &.{ .{ .id = "compensate", .source = 0, .event = "failed", .target = 1 }, .{ .id = "settle", .source = 1, .event = "compensated", .target = 2 } }, .terminal_state = 2 },
        .timeout_fallback => .{ .states = &.{ "waiting", "fallback", "completed" }, .transitions = &.{ .{ .id = "timeout", .source = 0, .event = "timed_out", .target = 1 }, .{ .id = "complete", .source = 1, .event = "fallback_completed", .target = 2 } }, .terminal_state = 2 },
        .budget_enforcement => .{ .states = &.{ "available", "exhausted", "closed" }, .transitions = &.{ .{ .id = "exhaust", .source = 0, .event = "budget_exhausted", .target = 1 }, .{ .id = "close", .source = 1, .event = "acknowledged", .target = 2 } }, .terminal_state = 2 },
        .child_delegation => .{ .states = &.{ "ready", "delegated", "joined" }, .transitions = &.{ .{ .id = "delegate", .source = 0, .event = "delegate", .target = 1 }, .{ .id = "join", .source = 1, .event = "child_completed", .target = 2 } }, .terminal_state = 2 },
        .circuit_breaker => .{ .states = &.{ "closed", "open", "recovered" }, .transitions = &.{ .{ .id = "open", .source = 0, .event = "threshold_reached", .target = 1 }, .{ .id = "recover", .source = 1, .event = "probe_succeeded", .target = 2 } }, .terminal_state = 2 },
        .long_running_job => .{ .states = &.{ "queued", "running", "completed", "failed", "cancelled" }, .transitions = &.{ .{ .id = "start", .source = 0, .event = "started", .target = 1 }, .{ .id = "complete", .source = 1, .event = "completed", .target = 2 }, .{ .id = "fail", .source = 1, .event = "failed", .target = 3 }, .{ .id = "cancel", .source = 1, .event = "cancelled", .target = 4 } }, .terminal_state = 2 },
        .incident_remediation => .{ .states = &.{ "detected", "remediating", "resolved", "escalated" }, .transitions = &.{ .{ .id = "remediate", .source = 0, .event = "approved", .target = 1 }, .{ .id = "resolve", .source = 1, .event = "verified", .target = 2 }, .{ .id = "escalate", .source = 1, .event = "verification_failed", .target = 3 } }, .terminal_state = 2 },
    };
}

fn isFinalState(kind: PatternKind, index: usize, success_index: usize) bool {
    if (index == success_index) return true;
    return switch (kind) {
        .human_approval => index == 2 or index == 3,
        .retry_escalation, .consensus_review, .incident_remediation => index == 3,
        .tool_execution, .long_running_job => index == 3 or index == 4,
        .parallel_research => index == 5 or index == 8,
        else => false,
    };
}

fn hasState(states: []const PlanState, id: []const u8) bool {
    for (states) |state| if (std.mem.eql(u8, state.id, id)) return true;
    return false;
}

fn findState(states: []const PlanState, id: []const u8) ?PlanState {
    for (states) |state| if (std.mem.eql(u8, state.id, id)) return state;
    return null;
}

fn validateIdentifier(value: []const u8) !void {
    if (value.len == 0 or value.len > 128) return error.InvalidIdentifier;
    if (Secrets.containsSecret(value)) return error.SecretDetected;
    for (value) |byte| if (!(std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.' or byte == ':')) return error.InvalidIdentifier;
}

fn validateText(value: []const u8) !void {
    if (value.len > 4096) return error.InvalidPlan;
    if (Secrets.containsSecret(value)) return error.SecretDetected;
}

fn firstEventIndex(transitions: []const PlanTransition, event: []const u8) usize {
    for (transitions, 0..) |transition, index| if (transition.event != null and std.mem.eql(u8, transition.event.?, event)) return index;
    unreachable;
}

fn firstGuardIndex(transitions: []const PlanTransition, guard: []const u8) usize {
    var ordinal: usize = 0;
    for (transitions) |transition| {
        if (transition.guard) |candidate| {
            if (std.mem.eql(u8, candidate, guard)) return ordinal;
            if (firstGuardIndexRaw(transitions, candidate) == transitionIndex(transitions, transition.id)) ordinal += 1;
        }
    }
    unreachable;
}

fn firstGuardIndexRaw(transitions: []const PlanTransition, guard: []const u8) usize {
    for (transitions, 0..) |transition, index| if (transition.guard != null and std.mem.eql(u8, transition.guard.?, guard)) return index;
    unreachable;
}

fn transitionIndex(transitions: []const PlanTransition, id: []const u8) usize {
    for (transitions, 0..) |transition, index| if (std.mem.eql(u8, transition.id, id)) return index;
    unreachable;
}

fn uniqueActionCount(transitions: []const PlanTransition) usize {
    var count: usize = 0;
    for (transitions) |transition| for (transition.actions) |action| {
        if (isFirstAction(transitions, action, transition.id)) count += 1;
    };
    return count;
}

fn isFirstAction(transitions: []const PlanTransition, action: []const u8, current_transition_id: []const u8) bool {
    for (transitions) |transition| {
        for (transition.actions) |candidate| if (std.mem.eql(u8, candidate, action)) return std.mem.eql(u8, transition.id, current_transition_id);
    }
    return false;
}

fn actionOrdinal(transitions: []const PlanTransition, action: []const u8) usize {
    var ordinal: usize = 0;
    for (transitions) |transition| for (transition.actions) |candidate| {
        if (!isFirstAction(transitions, candidate, transition.id)) continue;
        if (std.mem.eql(u8, candidate, action)) return ordinal;
        ordinal += 1;
    };
    unreachable;
}

fn appendZigIdentifier(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    try output.appendSlice(allocator, ".@\"");
    for (value) |byte| {
        if (byte == '\\' or byte == '"') try output.append(allocator, '\\');
        try output.append(allocator, byte);
    }
    try output.append(allocator, '"');
}

fn appendZigTagDeclaration(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    try output.appendSlice(allocator, "@\"");
    for (value) |byte| {
        if (byte == '\\' or byte == '"') try output.append(allocator, '\\');
        try output.append(allocator, byte);
    }
    try output.append(allocator, '"');
}

fn appendZigString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| switch (byte) {
        '\\', '"' => {
            try output.append(allocator, '\\');
            try output.append(allocator, byte);
        },
        '\n' => try output.appendSlice(allocator, "\\n"),
        '\r' => try output.appendSlice(allocator, "\\r"),
        '\t' => try output.appendSlice(allocator, "\\t"),
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}
