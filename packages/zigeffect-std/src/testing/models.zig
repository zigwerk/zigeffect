const std = @import("std");
const fx = @import("zigeffect");
const Contract = @import("contract.zig");

pub const ModelOptions = struct {
    max_transitions: usize = 1024,
    max_steps: usize = 256,
};

pub fn StatechartExplorer(comptime DefinitionType: type) type {
    const Machine = fx.statechart.Machine(DefinitionType);
    const Analyzer = fx.statechart.Analyzer(DefinitionType);
    const EventType = DefinitionType.EventType;
    const EventTag = DefinitionType.EventTag;
    const Transition = DefinitionType.Transition;

    return struct {
        const Self = @This();

        pub const Snapshot = Machine.Snapshot;
        pub const Invariant = *const fn (*const Snapshot) bool;
        pub const EventFactory = *const fn (EventTag) ?EventType;

        pub const Report = struct {
            allocator: std.mem.Allocator,
            status: Contract.TestStatus,
            transitions_total: usize,
            transitions_covered: usize,
            explored_paths: usize,
            truncated: bool,
            covered_transition_ids: []const []const u8,
            gaps: []const []const u8,
            failure_kind: []const u8 = "",
            failure_trace: []const []const u8,
            source_file: []const u8 = "",
            source_line: u32 = 0,
            source_column: u32 = 0,

            pub fn deinit(self: *Report) void {
                self.allocator.free(self.covered_transition_ids);
                self.allocator.free(self.gaps);
                self.allocator.free(self.failure_trace);
            }

            pub fn jsonAlloc(self: Report, allocator: std.mem.Allocator) ![]u8 {
                return std.json.Stringify.valueAlloc(allocator, .{
                    .schema = "zigeffect.test-statechart-model.v1",
                    .schema_version = 1,
                    .status = self.status,
                    .transitions_total = self.transitions_total,
                    .transitions_covered = self.transitions_covered,
                    .explored_paths = self.explored_paths,
                    .truncated = self.truncated,
                    .covered_transition_ids = self.covered_transition_ids,
                    .gaps = self.gaps,
                    .failure_kind = self.failure_kind,
                    .failure_trace = self.failure_trace,
                    .source = .{ .file = self.source_file, .line = self.source_line, .column = self.source_column },
                }, .{});
            }

            pub fn evidenceSummary(self: Report) Contract.EvidenceSummary {
                const failed: usize = if (self.status == .failed) 1 else 0;
                const executed = @min(self.transitions_total, self.explored_paths);
                const unsupported = executed -| self.transitions_covered -| failed;
                return .{
                    .attempted = true,
                    .status = self.status,
                    .planned = self.transitions_total,
                    .executed = executed,
                    .passed = self.transitions_covered,
                    .failed = failed,
                    .unsupported = unsupported,
                    .truncated = self.truncated or self.gaps.len != 0,
                    .replay_token = if (self.failure_trace.len == 0) "" else self.failure_trace[self.failure_trace.len - 1],
                };
            }
        };

        pub fn exploreEnum(
            allocator: std.mem.Allocator,
            definition_value: *const DefinitionType,
            context: DefinitionType.ContextType,
            options: ModelOptions,
            invariant: ?Invariant,
        ) !Report {
            comptime switch (@typeInfo(EventType)) {
                .@"enum" => {},
                else => @compileError("exploreEnum requires an enum statechart event; use exploreWithFactory for tagged unions"),
            };
            const Factory = struct {
                fn make(tag: EventTag) ?EventType {
                    return @enumFromInt(@intFromEnum(tag));
                }
            };
            return exploreWithFactory(allocator, definition_value, context, options, Factory.make, invariant);
        }

        pub fn exploreWithFactory(
            allocator: std.mem.Allocator,
            definition_value: *const DefinitionType,
            context: DefinitionType.ContextType,
            options: ModelOptions,
            factory: EventFactory,
            invariant: ?Invariant,
        ) !Report {
            if (options.max_transitions == 0 or options.max_steps == 0) {
                const empty_covered = try allocator.alloc([]const u8, 0);
                errdefer allocator.free(empty_covered);
                const all_gaps = try allocator.alloc([]const u8, definition_value.transitions.len);
                errdefer allocator.free(all_gaps);
                for (definition_value.transitions, 0..) |transition, index| all_gaps[index] = transition.id;
                return .{
                    .allocator = allocator,
                    .status = .incomplete,
                    .transitions_total = definition_value.transitions.len,
                    .transitions_covered = 0,
                    .explored_paths = 0,
                    .truncated = true,
                    .covered_transition_ids = empty_covered,
                    .gaps = all_gaps,
                    .failure_trace = try allocator.alloc([]const u8, 0),
                };
            }
            const validation = definition_value.validate();
            if (!validation.isValid()) return error.InvalidDefinition;
            const paths = Analyzer.shortestPaths(definition_value);
            var covered = std.ArrayList([]const u8).empty;
            errdefer covered.deinit(allocator);
            var gaps = std.ArrayList([]const u8).empty;
            errdefer gaps.deinit(allocator);
            var failure_trace: []const []const u8 = try allocator.alloc([]const u8, 0);
            errdefer allocator.free(failure_trace);
            var failure_kind: []const u8 = "";
            var source_file: []const u8 = "";
            var source_line: u32 = 0;
            var source_column: u32 = 0;
            var explored_paths: usize = 0;
            var truncated = paths.truncated or definition_value.transitions.len > options.max_transitions;
            const limit = @min(definition_value.transitions.len, options.max_transitions);

            for (definition_value.transitions[0..limit]) |candidate| {
                explored_paths += 1;
                var path_storage: [256][]const u8 = undefined;
                const prefix = paths.pathTo(candidate.source, &path_storage) catch {
                    try gaps.append(allocator, candidate.id);
                    continue;
                };
                if (prefix.len + 1 > options.max_steps) {
                    truncated = true;
                    try gaps.append(allocator, candidate.id);
                    continue;
                }
                var trace = std.ArrayList([]const u8).empty;
                defer trace.deinit(allocator);
                var snapshot = Machine.initial(definition_value, context, 1);
                var path_ok = true;
                for (prefix) |transition_id| {
                    const transition = findTransition(definition_value.transitions, transition_id) orelse {
                        path_ok = false;
                        break;
                    };
                    try trace.append(allocator, transition.id);
                    const decision = applyTransition(definition_value, snapshot, transition, factory) catch {
                        try recordFailure(allocator, &failure_trace, &failure_kind, trace.items, "step_error");
                        source_file = transition.source_ref.file;
                        source_line = transition.source_ref.line;
                        source_column = transition.source_ref.column;
                        path_ok = false;
                        break;
                    };
                    if (!std.mem.eql(u8, decision.selected_transition_id, transition.id)) {
                        path_ok = false;
                        break;
                    }
                    snapshot = decision.next;
                    if (invariant) |check| if (!check(&snapshot)) {
                        try recordFailure(allocator, &failure_trace, &failure_kind, trace.items, "invariant_failed");
                        source_file = transition.source_ref.file;
                        source_line = transition.source_ref.line;
                        source_column = transition.source_ref.column;
                        path_ok = false;
                        break;
                    };
                }
                if (!path_ok) {
                    try gaps.append(allocator, candidate.id);
                    continue;
                }

                try trace.append(allocator, candidate.id);
                const decision = applyTransition(definition_value, snapshot, candidate, factory) catch {
                    try recordFailure(allocator, &failure_trace, &failure_kind, trace.items, "step_error");
                    source_file = candidate.source_ref.file;
                    source_line = candidate.source_ref.line;
                    source_column = candidate.source_ref.column;
                    try gaps.append(allocator, candidate.id);
                    continue;
                };
                if (!std.mem.eql(u8, decision.selected_transition_id, candidate.id)) {
                    try gaps.append(allocator, candidate.id);
                    continue;
                }
                snapshot = decision.next;
                if (invariant) |check| if (!check(&snapshot)) {
                    try recordFailure(allocator, &failure_trace, &failure_kind, trace.items, "invariant_failed");
                    source_file = candidate.source_ref.file;
                    source_line = candidate.source_ref.line;
                    source_column = candidate.source_ref.column;
                    try gaps.append(allocator, candidate.id);
                    continue;
                };
                try covered.append(allocator, candidate.id);
            }
            for (definition_value.transitions[limit..]) |transition| try gaps.append(allocator, transition.id);

            const status: Contract.TestStatus = if (failure_trace.len != 0)
                .failed
            else if (truncated or gaps.items.len != 0)
                .incomplete
            else
                .passed;
            return .{
                .allocator = allocator,
                .status = status,
                .transitions_total = definition_value.transitions.len,
                .transitions_covered = covered.items.len,
                .explored_paths = explored_paths,
                .truncated = truncated,
                .covered_transition_ids = try covered.toOwnedSlice(allocator),
                .gaps = try gaps.toOwnedSlice(allocator),
                .failure_kind = failure_kind,
                .failure_trace = failure_trace,
                .source_file = source_file,
                .source_line = source_line,
                .source_column = source_column,
            };
        }

        fn applyTransition(
            definition_value: *const DefinitionType,
            snapshot: Snapshot,
            transition: Transition,
            factory: EventFactory,
        ) !Machine.Decision {
            if (transition.event) |tag| {
                const event = factory(tag) orelse return error.UnsupportedEventPayload;
                return Machine.step(definition_value, snapshot, event);
            }
            const tags = std.meta.tags(EventTag);
            if (tags.len == 0) return error.UnsupportedEventPayload;
            const last_event = factory(tags[0]) orelse return error.UnsupportedEventPayload;
            return Machine.stepEventless(definition_value, snapshot, last_event);
        }

        fn findTransition(transitions: []const Transition, id: []const u8) ?Transition {
            for (transitions) |transition| if (std.mem.eql(u8, transition.id, id)) return transition;
            return null;
        }

        fn recordFailure(
            allocator: std.mem.Allocator,
            current: *[]const []const u8,
            kind: *[]const u8,
            candidate: []const []const u8,
            failure_kind: []const u8,
        ) !void {
            if (current.*.len != 0 and current.*.len <= candidate.len) return;
            const owned = try allocator.dupe([]const u8, candidate);
            allocator.free(current.*);
            current.* = owned;
            kind.* = failure_kind;
        }
    };
}

const State = enum { idle, running, done };
const Event = enum { start, finish };
const Context = struct { healthy: bool = true };
const Definition = fx.statechart.Definition(State, Event, Context, void);
const definition = Definition.init(.{
    .id = "testing.model",
    .version = 1,
    .initial = .idle,
    .states = &.{
        .{ .id = .idle },
        .{ .id = .running },
        .{ .id = .done, .kind = .final },
    },
    .transitions = &.{
        .{ .id = "start", .source = .idle, .event = .start, .target = .running },
        .{ .id = "finish", .source = .running, .event = .finish, .target = .done },
    },
});

test "typed enum statechart model exploration covers every transition" {
    const Explorer = StatechartExplorer(Definition);
    var report = try Explorer.exploreEnum(std.testing.allocator, &definition, .{}, .{}, null);
    defer report.deinit();
    try std.testing.expectEqual(Contract.TestStatus.passed, report.status);
    try std.testing.expectEqual(@as(usize, 2), report.transitions_covered);
    try std.testing.expectEqual(@as(usize, 0), report.gaps.len);
}

test "statechart model exploration retains shortest invariant failure trace" {
    const Explorer = StatechartExplorer(Definition);
    const invariant = struct {
        fn check(snapshot: *const Explorer.Snapshot) bool {
            return snapshot.state != .running;
        }
    }.check;
    var report = try Explorer.exploreEnum(std.testing.allocator, &definition, .{}, .{}, invariant);
    defer report.deinit();
    try std.testing.expectEqual(Contract.TestStatus.failed, report.status);
    try std.testing.expectEqual(@as(usize, 1), report.failure_trace.len);
    try std.testing.expectEqualStrings("start", report.failure_trace[0]);
    try std.testing.expectEqualStrings("invariant_failed", report.failure_kind);
}

test "statechart model bounds are truthful incomplete evidence" {
    const Explorer = StatechartExplorer(Definition);
    var report = try Explorer.exploreEnum(std.testing.allocator, &definition, .{}, .{ .max_transitions = 1 }, null);
    defer report.deinit();
    try std.testing.expectEqual(Contract.TestStatus.incomplete, report.status);
    try std.testing.expect(report.truncated);
}
