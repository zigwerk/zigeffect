const std = @import("std");

pub const max_analysis_states: usize = 256;
pub const max_analysis_findings: usize = 256;

pub const AnalysisFindingKind = enum {
    analysis_limit_exceeded,
    unreachable_state,
    non_final_dead_end,
    ambiguous_unguarded_transition,
    eventless_cycle,
};

pub fn analysisFindingMessage(kind: AnalysisFindingKind) []const u8 {
    return switch (kind) {
        .analysis_limit_exceeded => "statechart analysis exceeds the bounded state capacity",
        .unreachable_state => "statechart state is unreachable from the initial state",
        .non_final_dead_end => "statechart non-final state has no transition to another state",
        .ambiguous_unguarded_transition => "statechart contains multiple unguarded transitions for the same state and event",
        .eventless_cycle => "statechart contains a potential eventless transition cycle",
    };
}

pub fn Analyzer(comptime DefinitionType: type) type {
    const State = DefinitionType.StateType;

    return struct {
        const Self = @This();

        pub const Finding = struct {
            id: u64,
            kind: AnalysisFindingKind,
            state: State,
            transition_id: []const u8 = "",
            related_transition_id: []const u8 = "",
            message: []const u8,
        };

        pub const Report = struct {
            items: [max_analysis_findings]Finding = undefined,
            count: usize = 0,
            truncated: bool = false,

            pub fn findings(self: *const Report) []const Finding {
                return self.items[0..self.count];
            }

            pub fn has(self: *const Report, kind: AnalysisFindingKind) bool {
                for (self.findings()) |finding| {
                    if (finding.kind == kind) return true;
                }
                return false;
            }

            pub fn hasState(self: *const Report, kind: AnalysisFindingKind, state: State) bool {
                for (self.findings()) |finding| {
                    if (finding.kind == kind and finding.state == state) return true;
                }
                return false;
            }

            fn add(
                self: *Report,
                machine_id: []const u8,
                kind: AnalysisFindingKind,
                state: State,
                transition_id: []const u8,
                related_transition_id: []const u8,
                ordinal: usize,
            ) void {
                if (self.count >= self.items.len) {
                    self.truncated = true;
                    return;
                }
                self.items[self.count] = .{
                    .id = findingId(machine_id, kind, state, transition_id, related_transition_id, ordinal),
                    .kind = kind,
                    .state = state,
                    .transition_id = transition_id,
                    .related_transition_id = related_transition_id,
                    .message = analysisFindingMessage(kind),
                };
                self.count += 1;
            }
        };

        pub const PathError = error{
            UnknownState,
            UnreachableState,
            PathBufferTooSmall,
        };

        pub const PathEntry = struct {
            state: State,
            reachable: bool = false,
            distance: usize = 0,
            predecessor_index: ?usize = null,
            transition_id: []const u8 = "",
        };

        pub const ShortestPaths = struct {
            entries: [max_analysis_states]PathEntry = undefined,
            count: usize = 0,
            truncated: bool = false,

            pub fn isReachable(self: *const ShortestPaths, state: State) bool {
                const entry = self.find(state) orelse return false;
                return entry.reachable;
            }

            pub fn distanceTo(self: *const ShortestPaths, state: State) ?usize {
                const entry = self.find(state) orelse return null;
                if (!entry.reachable) return null;
                return entry.distance;
            }

            pub fn pathTo(
                self: *const ShortestPaths,
                state: State,
                storage: [][]const u8,
            ) PathError![]const []const u8 {
                const target_index = self.findIndex(state) orelse return error.UnknownState;
                const target = self.entries[target_index];
                if (!target.reachable) return error.UnreachableState;
                if (storage.len < target.distance) return error.PathBufferTooSmall;

                var cursor = target_index;
                var remaining = target.distance;
                while (remaining > 0) {
                    const entry = self.entries[cursor];
                    remaining -= 1;
                    storage[remaining] = entry.transition_id;
                    cursor = entry.predecessor_index orelse return error.UnreachableState;
                }
                return storage[0..target.distance];
            }

            fn find(self: *const ShortestPaths, state: State) ?PathEntry {
                const index = self.findIndex(state) orelse return null;
                return self.entries[index];
            }

            fn findIndex(self: *const ShortestPaths, state: State) ?usize {
                for (self.entries[0..self.count], 0..) |entry, index| {
                    if (entry.state == state) return index;
                }
                return null;
            }
        };

        pub fn analyze(definition: *const DefinitionType) Report {
            var report = Report{};
            if (definition.states.len > max_analysis_states) {
                report.add(definition.id, .analysis_limit_exceeded, definition.initial, "", "", definition.states.len);
                return report;
            }

            const paths = shortestPaths(definition);
            for (definition.states, 0..) |node, state_index| {
                if (!paths.isReachable(node.id)) {
                    report.add(definition.id, .unreachable_state, node.id, "", "", state_index);
                }
                if (node.kind != .final and !hasEscapingTransition(definition, node.id)) {
                    report.add(definition.id, .non_final_dead_end, node.id, "", "", state_index);
                }
                if (hasEventlessCycle(definition, node.id)) {
                    report.add(definition.id, .eventless_cycle, node.id, "", "", state_index);
                }
            }

            for (definition.transitions, 0..) |transition, transition_index| {
                if (transition.guard != null) continue;
                for (definition.transitions[transition_index + 1 ..], transition_index + 1..) |candidate, candidate_index| {
                    if (candidate.guard != null) continue;
                    if (candidate.source != transition.source) continue;
                    if (candidate.event != transition.event) continue;
                    report.add(
                        definition.id,
                        .ambiguous_unguarded_transition,
                        transition.source,
                        transition.id,
                        candidate.id,
                        candidate_index,
                    );
                }
            }

            return report;
        }

        pub fn shortestPaths(definition: *const DefinitionType) ShortestPaths {
            var result = ShortestPaths{};
            if (definition.states.len > result.entries.len) {
                result.truncated = true;
                return result;
            }

            result.count = definition.states.len;
            for (definition.states, 0..) |node, index| {
                result.entries[index] = .{ .state = node.id };
            }

            var queue: [max_analysis_states]usize = undefined;
            var head: usize = 0;
            var len: usize = 0;
            markInitialConfiguration(definition, &result, &queue, &len, definition.initial, 0, null, "");

            while (head < len) {
                const source_index = queue[head];
                head += 1;
                const source = result.entries[source_index];

                for (definition.transitions) |transition| {
                    if (transition.source != source.state) continue;
                    const target = transition.target orelse continue;
                    markTargetAncestors(definition, &result, &queue, &len, target, source.distance + 1, source_index, transition.id);
                    markInitialConfiguration(definition, &result, &queue, &len, target, source.distance + 1, source_index, transition.id);
                }
            }

            return result;
        }

        fn hasEscapingTransition(definition: *const DefinitionType, state: State) bool {
            for (definition.transitions) |transition| {
                if (transition.source != state and !definition.isDescendant(transition.source, state)) continue;
                const target = transition.target orelse continue;
                if (target != state) return true;
            }
            return false;
        }

        fn markInitialConfiguration(
            definition: *const DefinitionType,
            result: *ShortestPaths,
            queue: *[max_analysis_states]usize,
            len: *usize,
            state: State,
            distance: usize,
            predecessor_index: ?usize,
            transition_id: []const u8,
        ) void {
            const index = stateIndex(definition, state) orelse return;
            if (!result.entries[index].reachable) {
                result.entries[index].reachable = true;
                result.entries[index].distance = distance;
                result.entries[index].predecessor_index = predecessor_index;
                result.entries[index].transition_id = transition_id;
                if (len.* < queue.len) {
                    queue[len.*] = index;
                    len.* += 1;
                } else {
                    result.truncated = true;
                    return;
                }
            }
            const node = definition.stateNode(state) orelse return;
            switch (node.kind) {
                .compound => if (node.initial) |initial| {
                    markInitialConfiguration(definition, result, queue, len, initial, distance, predecessor_index, transition_id);
                },
                .parallel => {
                    for (definition.states) |child| {
                        if (child.parent == null or child.parent.? != state) continue;
                        if (child.kind == .history_shallow or child.kind == .history_deep) continue;
                        markInitialConfiguration(definition, result, queue, len, child.id, distance, predecessor_index, transition_id);
                    }
                },
                .atomic, .final, .history_shallow, .history_deep => {},
            }
        }

        fn markTargetAncestors(
            definition: *const DefinitionType,
            result: *ShortestPaths,
            queue: *[max_analysis_states]usize,
            len: *usize,
            target: State,
            distance: usize,
            predecessor_index: usize,
            transition_id: []const u8,
        ) void {
            var cursor = (definition.stateNode(target) orelse return).parent;
            var remaining = definition.bounds.max_hierarchy_depth;
            while (cursor) |ancestor| {
                const index = stateIndex(definition, ancestor) orelse return;
                if (!result.entries[index].reachable) {
                    result.entries[index].reachable = true;
                    result.entries[index].distance = distance;
                    result.entries[index].predecessor_index = predecessor_index;
                    result.entries[index].transition_id = transition_id;
                    if (len.* >= queue.len) {
                        result.truncated = true;
                        return;
                    }
                    queue[len.*] = index;
                    len.* += 1;
                }
                if (remaining == 0) return;
                remaining -= 1;
                cursor = (definition.stateNode(ancestor) orelse return).parent;
            }
        }

        fn hasEventlessCycle(definition: *const DefinitionType, start: State) bool {
            if (definition.states.len > max_analysis_states) return false;
            var visited = [_]bool{false} ** max_analysis_states;
            var queue: [max_analysis_states]State = undefined;
            var head: usize = 0;
            var len: usize = 0;

            for (definition.transitions) |transition| {
                if (transition.source != start or transition.event != null) continue;
                const target = transition.target orelse continue;
                if (target == start) return true;
                const target_index = stateIndex(definition, target) orelse continue;
                if (!visited[target_index]) {
                    visited[target_index] = true;
                    queue[len] = target;
                    len += 1;
                }
            }

            while (head < len) {
                const state = queue[head];
                head += 1;
                for (definition.transitions) |transition| {
                    if (transition.source != state or transition.event != null) continue;
                    const target = transition.target orelse continue;
                    if (target == start) return true;
                    const target_index = stateIndex(definition, target) orelse continue;
                    if (!visited[target_index]) {
                        visited[target_index] = true;
                        queue[len] = target;
                        len += 1;
                    }
                }
            }
            return false;
        }

        fn stateIndex(definition: *const DefinitionType, state: State) ?usize {
            for (definition.states, 0..) |node, index| {
                if (node.id == state) return index;
            }
            return null;
        }

        fn findingId(
            machine_id: []const u8,
            kind: AnalysisFindingKind,
            state: State,
            transition_id: []const u8,
            related_transition_id: []const u8,
            ordinal: usize,
        ) u64 {
            var hasher = std.hash.Fnv1a_64.init();
            hashText(&hasher, machine_id);
            hashText(&hasher, @tagName(kind));
            hashInt(&hasher, @intFromEnum(state));
            hashText(&hasher, transition_id);
            hashText(&hasher, related_transition_id);
            hashInt(&hasher, ordinal);
            const id = hasher.final();
            return if (id == 0) 1 else id;
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
