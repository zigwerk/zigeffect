const std = @import("std");
const machine_mod = @import("machine.zig");
const artifact_mod = @import("artifact.zig");

pub const max_coverage_states: usize = 256;
pub const max_coverage_transitions: usize = 1024;
pub const max_coverage_events: usize = 256;

pub const CoverageError = error{
    InvalidDefinition,
    DefinitionMismatch,
    CoverageLimitExceeded,
    UnknownTransition,
    UnknownEvent,
};

pub fn Coverage(comptime DefinitionType: type) type {
    const Runtime = machine_mod.Machine(DefinitionType);
    const State = DefinitionType.StateType;
    const EventTag = DefinitionType.EventTag;

    return struct {
        const Self = @This();

        pub const Summary = struct {
            total_states: usize,
            visited_states: usize,
            total_transitions: usize,
            visited_transitions: usize,
            total_events: usize,
            observed_events: usize,
        };

        definition_fingerprint: u64,
        definition: *const DefinitionType,
        state_total: usize,
        transition_total: usize,
        event_total: usize,
        state_counts: [max_coverage_states]u64 = [_]u64{0} ** max_coverage_states,
        transition_counts: [max_coverage_transitions]u64 = [_]u64{0} ** max_coverage_transitions,
        event_counts: [max_coverage_events]u64 = [_]u64{0} ** max_coverage_events,

        pub fn init(definition: *const DefinitionType) CoverageError!Self {
            if (!definition.validate().isValid()) return error.InvalidDefinition;
            const event_total = std.meta.tags(EventTag).len;
            if (definition.states.len > max_coverage_states or
                definition.transitions.len > max_coverage_transitions or
                event_total > max_coverage_events)
            {
                return error.CoverageLimitExceeded;
            }
            return .{
                .definition_fingerprint = definition.fingerprint(),
                .definition = definition,
                .state_total = definition.states.len,
                .transition_total = definition.transitions.len,
                .event_total = event_total,
            };
        }

        pub fn recordDecision(
            self: *Self,
            definition: *const DefinitionType,
            decision: *const Runtime.Decision,
            event: EventTag,
        ) CoverageError!void {
            try self.ensureDefinition(definition);
            try self.recordState(definition, decision.previous.state);
            try self.recordState(definition, decision.next.state);
            try self.recordEvent(event);
            if (decision.selected_transition_index) |index| {
                if (index >= self.transition_total) return error.UnknownTransition;
                self.transition_counts[index] +|= 1;
            }
        }

        pub fn recordConfigurationDecision(
            self: *Self,
            definition: *const DefinitionType,
            decision: anytype,
            event: EventTag,
        ) CoverageError!void {
            try self.ensureDefinition(definition);
            for (decision.previous.configuration()) |state| try self.recordState(definition, state);
            for (decision.next.configuration()) |state| try self.recordState(definition, state);
            try self.recordEvent(event);
            for (decision.transitionIds()) |id| {
                const index = transitionIndex(definition, id) orelse return error.UnknownTransition;
                self.transition_counts[index] +|= 1;
            }
        }

        pub fn transitionCount(self: *const Self, id: []const u8) u64 {
            return self.transitionCountFor(self.definition, id);
        }

        pub fn transitionCountFor(self: *const Self, definition: *const DefinitionType, id: []const u8) u64 {
            const index = transitionIndex(definition, id) orelse return 0;
            return self.transition_counts[index];
        }

        pub fn eventCount(self: *const Self, event: EventTag) u64 {
            const index = eventIndex(event) orelse return 0;
            return self.event_counts[index];
        }

        pub fn summary(self: *const Self) Summary {
            return .{
                .total_states = self.state_total,
                .visited_states = nonZeroCount(self.state_counts[0..self.state_total]),
                .total_transitions = self.transition_total,
                .visited_transitions = nonZeroCount(self.transition_counts[0..self.transition_total]),
                .total_events = self.event_total,
                .observed_events = nonZeroCount(self.event_counts[0..self.event_total]),
            };
        }

        pub fn formatJsonAlloc(self: *const Self, allocator: std.mem.Allocator, definition: *const DefinitionType) ![]u8 {
            try self.ensureDefinition(definition);
            var output = std.ArrayList(u8).empty;
            errdefer output.deinit(allocator);
            const totals = self.summary();
            try output.appendSlice(allocator, "{\"schema\":");
            try appendJsonString(&output, allocator, artifact_mod.statechart_coverage_schema);
            try output.print(allocator,
                ",\"schema_version\":{d},\"definition_id\":", .{artifact_mod.statechart_artifact_schema_version});
            try appendJsonString(&output, allocator, definition.id);
            try output.print(allocator,
                ",\"definition_fingerprint\":\"{d}\",\"summary\":{{\"total_states\":{d},\"visited_states\":{d},\"total_transitions\":{d},\"visited_transitions\":{d},\"total_events\":{d},\"observed_events\":{d}}},\"states\":[",
                .{ self.definition_fingerprint, totals.total_states, totals.visited_states, totals.total_transitions, totals.visited_transitions, totals.total_events, totals.observed_events });
            for (definition.states, 0..) |state, index| {
                if (index != 0) try output.append(allocator, ',');
                try output.appendSlice(allocator, "{\"id\":");
                try appendJsonString(&output, allocator, @tagName(state.id));
                try output.print(allocator, ",\"count\":\"{d}\"}}", .{self.state_counts[index]});
            }
            try output.appendSlice(allocator, "],\"transitions\":[");
            for (definition.transitions, 0..) |transition, index| {
                if (index != 0) try output.append(allocator, ',');
                try output.appendSlice(allocator, "{\"id\":");
                try appendJsonString(&output, allocator, transition.id);
                try output.print(allocator, ",\"count\":\"{d}\"}}", .{self.transition_counts[index]});
            }
            try output.appendSlice(allocator, "],\"events\":[");
            for (std.meta.tags(EventTag), 0..) |event, index| {
                if (index != 0) try output.append(allocator, ',');
                try output.appendSlice(allocator, "{\"id\":");
                try appendJsonString(&output, allocator, @tagName(event));
                try output.print(allocator, ",\"count\":\"{d}\"}}", .{self.event_counts[index]});
            }
            try output.appendSlice(allocator, "]}");
            return output.toOwnedSlice(allocator);
        }

        fn ensureDefinition(self: *const Self, definition: *const DefinitionType) CoverageError!void {
            if (self.definition_fingerprint != definition.fingerprint()) return error.DefinitionMismatch;
        }

        fn recordState(self: *Self, definition: *const DefinitionType, state: State) CoverageError!void {
            for (definition.states, 0..) |node, index| {
                if (node.id != state) continue;
                self.state_counts[index] +|= 1;
                return;
            }
            return error.InvalidDefinition;
        }

        fn recordEvent(self: *Self, event: EventTag) CoverageError!void {
            const index = eventIndex(event) orelse return error.UnknownEvent;
            self.event_counts[index] +|= 1;
        }

        fn eventIndex(event: EventTag) ?usize {
            for (std.meta.tags(EventTag), 0..) |candidate, index| {
                if (candidate == event) return index;
            }
            return null;
        }

        fn transitionIndex(definition: *const DefinitionType, id: []const u8) ?usize {
            for (definition.transitions, 0..) |transition, index| {
                if (std.mem.eql(u8, transition.id, id)) return index;
            }
            return null;
        }
    };
}

fn nonZeroCount(values: []const u64) usize {
    var count: usize = 0;
    for (values) |value| if (value != 0) {
        count += 1;
    };
    return count;
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| switch (byte) {
        '"' => try output.appendSlice(allocator, "\\\""),
        '\\' => try output.appendSlice(allocator, "\\\\"),
        '\n' => try output.appendSlice(allocator, "\\n"),
        '\r' => try output.appendSlice(allocator, "\\r"),
        '\t' => try output.appendSlice(allocator, "\\t"),
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}
