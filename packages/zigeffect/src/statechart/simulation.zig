const std = @import("std");
const machine_mod = @import("machine.zig");
const macrostep_mod = @import("macrostep.zig");
const configuration_mod = @import("configuration.zig");
const configuration_macrostep_mod = @import("configuration_macrostep.zig");

pub const max_simulation_steps: usize = 256;
pub const max_simulation_transition_ids: usize = 64;
pub const max_simulation_invariants: usize = 128;

pub fn Simulation(comptime DefinitionType: type) type {
    const Runtime = machine_mod.Machine(DefinitionType);
    const Macro = macrostep_mod.Macrostep(DefinitionType);
    const State = DefinitionType.StateType;
    const Event = DefinitionType.EventType;

    return struct {
        pub const Error = Macro.Error || error{ InvalidSimulationBound, InvariantLimitExceeded };
        pub const StopReason = enum { exhausted, breakpoint, terminal, step_limit };

        pub const Options = struct {
            max_steps: usize = max_simulation_steps,
            state_breakpoints: []const State = &.{},
            transition_breakpoints: []const []const u8 = &.{},
        };

        pub const Step = struct {
            index: usize,
            event: Event,
            before: Runtime.Snapshot,
            after: Runtime.Snapshot,
            transition_storage: [max_simulation_transition_ids][]const u8 = undefined,
            transition_count: usize = 0,
            command_count: usize = 0,
            macrostep_fingerprint: u64 = 0,

            pub fn transitionIds(self: *const Step) []const []const u8 {
                return self.transition_storage[0..self.transition_count];
            }
        };

        pub const Result = struct {
            initial_snapshot: Runtime.Snapshot,
            final_snapshot: Runtime.Snapshot,
            step_storage: [max_simulation_steps]Step = undefined,
            step_count: usize = 0,
            stop_reason: StopReason = .exhausted,
            truncated: bool = false,

            pub fn steps(self: *const Result) []const Step {
                return self.step_storage[0..self.step_count];
            }

            /// Time-travel position zero is the initial snapshot; position N is
            /// the snapshot committed by step N.
            pub fn snapshotAt(self: *const Result, position: usize) ?Runtime.Snapshot {
                if (position == 0) return self.initial_snapshot;
                if (position > self.step_count) return null;
                return self.step_storage[position - 1].after;
            }
        };

        pub const InvariantKind = enum {
            always_active,
            eventually_active,
            never_active_after_first_step,
            precedes,
            terminal,
        };

        pub const Invariant = struct {
            id: []const u8,
            kind: InvariantKind,
            state: ?State = null,
            before: ?State = null,
        };

        pub const InvariantStatus = enum { passed, failed, incomplete };

        pub const InvariantResult = struct {
            id: []const u8,
            status: InvariantStatus,
            witness_step: ?usize = null,
        };

        pub const InvariantReport = struct {
            result_storage: [max_simulation_invariants]InvariantResult = undefined,
            result_count: usize = 0,
            truncated: bool = false,

            pub fn results(self: *const InvariantReport) []const InvariantResult {
                return self.result_storage[0..self.result_count];
            }

            pub fn complete(self: *const InvariantReport) bool {
                if (self.truncated) return false;
                for (self.results()) |result| if (result.status != .passed) return false;
                return true;
            }
        };

        pub fn run(
            definition: *const DefinitionType,
            initial_snapshot: Runtime.Snapshot,
            events: []const Event,
            options: Options,
        ) Error!Result {
            if (options.max_steps == 0) return error.InvalidSimulationBound;
            const limit = @min(options.max_steps, max_simulation_steps);
            var result = Result{ .initial_snapshot = initial_snapshot, .final_snapshot = initial_snapshot };

            for (events, 0..) |event, index| {
                if (result.step_count >= limit) {
                    result.stop_reason = .step_limit;
                    result.truncated = true;
                    break;
                }
                if (result.final_snapshot.status != .active) {
                    result.stop_reason = .terminal;
                    break;
                }
                const macro = try Macro.run(definition, result.final_snapshot, event);
                var step = Step{
                    .index = index,
                    .event = event,
                    .before = result.final_snapshot,
                    .after = macro.next,
                    .command_count = macro.commands().len,
                    .macrostep_fingerprint = macro.fingerprint,
                };
                for (macro.microsteps()) |microstep| {
                    if (step.transition_count >= step.transition_storage.len) break;
                    step.transition_storage[step.transition_count] = microstep.transition_id;
                    step.transition_count += 1;
                }
                result.step_storage[result.step_count] = step;
                result.step_count += 1;
                result.final_snapshot = macro.next;

                if (hitsTransitionBreakpoint(&step, options.transition_breakpoints) or
                    hitsStateBreakpoint(result.final_snapshot.state, options.state_breakpoints))
                {
                    result.stop_reason = .breakpoint;
                    break;
                }
                if (result.final_snapshot.status != .active) {
                    result.stop_reason = .terminal;
                    break;
                }
            }
            if (events.len > result.step_count and result.stop_reason == .exhausted) {
                result.stop_reason = .step_limit;
                result.truncated = true;
            }
            return result;
        }

        pub fn evaluateInvariants(result: *const Result, invariants: []const Invariant) InvariantReport {
            var report = InvariantReport{};
            for (invariants) |invariant| {
                if (report.result_count >= report.result_storage.len) {
                    report.truncated = true;
                    break;
                }
                report.result_storage[report.result_count] = evaluateInvariant(result, invariant);
                report.result_count += 1;
            }
            return report;
        }

        fn evaluateInvariant(result: *const Result, invariant: Invariant) InvariantResult {
            if (result.truncated) return .{ .id = invariant.id, .status = .incomplete };
            return switch (invariant.kind) {
                .terminal => .{
                    .id = invariant.id,
                    .status = if (result.final_snapshot.status == .done) .passed else .failed,
                    .witness_step = result.step_count,
                },
                .eventually_active => eventually: {
                    const expected = invariant.state orelse break :eventually .{ .id = invariant.id, .status = .failed };
                    for (result.steps(), 1..) |step, index| {
                        if (step.after.state == expected) break :eventually .{ .id = invariant.id, .status = .passed, .witness_step = index };
                    }
                    break :eventually .{ .id = invariant.id, .status = .failed };
                },
                .never_active_after_first_step => never: {
                    const forbidden = invariant.state orelse break :never .{ .id = invariant.id, .status = .failed };
                    for (result.steps(), 1..) |step, index| {
                        if (step.after.state == forbidden) break :never .{ .id = invariant.id, .status = .failed, .witness_step = index };
                    }
                    break :never .{ .id = invariant.id, .status = .passed };
                },
                .always_active => always: {
                    const expected = invariant.state orelse break :always .{ .id = invariant.id, .status = .failed };
                    for (result.steps(), 1..) |step, index| {
                        if (step.after.state != expected) break :always .{ .id = invariant.id, .status = .failed, .witness_step = index };
                    }
                    break :always .{ .id = invariant.id, .status = .passed };
                },
                .precedes => precedes: {
                    const before = invariant.before orelse break :precedes .{ .id = invariant.id, .status = .failed };
                    const after = invariant.state orelse break :precedes .{ .id = invariant.id, .status = .failed };
                    var seen_before = result.initial_snapshot.state == before;
                    for (result.steps(), 1..) |step, index| {
                        if (step.after.state == after) {
                            break :precedes .{
                                .id = invariant.id,
                                .status = if (seen_before) .passed else .failed,
                                .witness_step = index,
                            };
                        }
                        if (step.after.state == before) seen_before = true;
                    }
                    break :precedes .{ .id = invariant.id, .status = .failed };
                },
            };
        }

        fn hitsTransitionBreakpoint(step: *const Step, breakpoints: []const []const u8) bool {
            for (step.transitionIds()) |transition_id| {
                for (breakpoints) |breakpoint| if (std.mem.eql(u8, transition_id, breakpoint)) return true;
            }
            return false;
        }

        fn hitsStateBreakpoint(state: State, breakpoints: []const State) bool {
            for (breakpoints) |breakpoint| if (state == breakpoint) return true;
            return false;
        }
    };
}

pub fn ConfigurationSimulation(comptime DefinitionType: type) type {
    const Runtime = configuration_mod.ConfigurationMachine(DefinitionType);
    const Macro = configuration_macrostep_mod.ConfigurationMacrostep(DefinitionType);
    const State = DefinitionType.StateType;
    const Event = DefinitionType.EventType;

    return struct {
        pub const Error = Macro.Error || error{InvalidSimulationBound};
        pub const StopReason = enum { exhausted, breakpoint, terminal, step_limit };
        pub const Options = struct {
            max_steps: usize = max_simulation_steps,
            state_breakpoints: []const State = &.{},
            transition_breakpoints: []const []const u8 = &.{},
        };
        pub const Step = struct {
            index: usize,
            event: Event,
            before: Runtime.Snapshot,
            after: Runtime.Snapshot,
            transition_storage: [max_simulation_transition_ids][]const u8 = undefined,
            transition_count: usize = 0,
            command_count: usize = 0,
            macrostep_fingerprint: u64 = 0,
            pub fn transitionIds(self: *const Step) []const []const u8 {
                return self.transition_storage[0..self.transition_count];
            }
        };
        pub const Result = struct {
            allocator: std.mem.Allocator,
            initial_snapshot: Runtime.Snapshot,
            final_snapshot: Runtime.Snapshot,
            step_storage: []Step,
            step_count: usize = 0,
            stop_reason: StopReason = .exhausted,
            truncated: bool = false,
            pub fn deinit(self: *Result) void {
                self.allocator.free(self.step_storage);
                self.* = undefined;
            }
            pub fn steps(self: *const Result) []const Step {
                return self.step_storage[0..self.step_count];
            }
            pub fn snapshotAt(self: *const Result, position: usize) ?Runtime.Snapshot {
                if (position == 0) return self.initial_snapshot;
                if (position > self.step_count) return null;
                return self.step_storage[position - 1].after;
            }
        };
        pub const InvariantKind = enum { always_active, eventually_active, never_active_after_first_step, precedes, terminal };
        pub const Invariant = struct { id: []const u8, kind: InvariantKind, state: ?State = null, before: ?State = null };
        pub const InvariantStatus = enum { passed, failed, incomplete };
        pub const InvariantResult = struct { id: []const u8, status: InvariantStatus, witness_step: ?usize = null };
        pub const InvariantReport = struct {
            result_storage: [max_simulation_invariants]InvariantResult = undefined,
            result_count: usize = 0,
            truncated: bool = false,
            pub fn results(self: *const InvariantReport) []const InvariantResult {
                return self.result_storage[0..self.result_count];
            }
            pub fn complete(self: *const InvariantReport) bool {
                if (self.truncated) return false;
                for (self.results()) |result| if (result.status != .passed) return false;
                return true;
            }
        };

        pub fn run(allocator: std.mem.Allocator, definition: *const DefinitionType, initial_snapshot: Runtime.Snapshot, events: []const Event, options: Options) (Error || std.mem.Allocator.Error)!Result {
            if (options.max_steps == 0) return error.InvalidSimulationBound;
            const limit = @min(options.max_steps, max_simulation_steps);
            const steps = try allocator.alloc(Step, limit);
            errdefer allocator.free(steps);
            var result = Result{ .allocator = allocator, .initial_snapshot = initial_snapshot, .final_snapshot = initial_snapshot, .step_storage = steps };
            for (events, 0..) |event, index| {
                if (result.step_count >= limit) {
                    result.stop_reason = .step_limit;
                    result.truncated = true;
                    break;
                }
                if (result.final_snapshot.status != .active) {
                    result.stop_reason = .terminal;
                    break;
                }
                const macro = try Macro.run(definition, result.final_snapshot, event);
                var step = Step{ .index = index, .event = event, .before = result.final_snapshot, .after = macro.next, .command_count = macro.commands().len, .macrostep_fingerprint = macro.fingerprint };
                for (macro.microsteps()) |microstep| for (microstep.transitionIds()) |transition_id| {
                    if (step.transition_count >= step.transition_storage.len) break;
                    step.transition_storage[step.transition_count] = transition_id;
                    step.transition_count += 1;
                };
                result.step_storage[result.step_count] = step;
                result.step_count += 1;
                result.final_snapshot = macro.next;
                if (hitsTransitionBreakpoint(&step, options.transition_breakpoints) or hitsStateBreakpoint(&result.final_snapshot, options.state_breakpoints)) {
                    result.stop_reason = .breakpoint;
                    break;
                }
                if (result.final_snapshot.status != .active) {
                    result.stop_reason = .terminal;
                    break;
                }
            }
            if (events.len > result.step_count and result.stop_reason == .exhausted) {
                result.stop_reason = .step_limit;
                result.truncated = true;
            }
            return result;
        }

        pub fn evaluateInvariants(result: *const Result, invariants: []const Invariant) InvariantReport {
            var report = InvariantReport{};
            for (invariants) |invariant| {
                if (report.result_count >= report.result_storage.len) {
                    report.truncated = true;
                    break;
                }
                report.result_storage[report.result_count] = evaluateInvariant(result, invariant);
                report.result_count += 1;
            }
            return report;
        }

        fn evaluateInvariant(result: *const Result, invariant: Invariant) InvariantResult {
            if (result.truncated) return .{ .id = invariant.id, .status = .incomplete };
            return switch (invariant.kind) {
                .terminal => .{ .id = invariant.id, .status = if (result.final_snapshot.status == .done) .passed else .failed, .witness_step = result.step_count },
                .eventually_active => eventually: {
                    const expected = invariant.state orelse break :eventually .{ .id = invariant.id, .status = .failed };
                    if (result.initial_snapshot.isActive(expected)) break :eventually .{ .id = invariant.id, .status = .passed, .witness_step = 0 };
                    for (result.steps(), 1..) |step, index| if (step.after.isActive(expected)) break :eventually .{ .id = invariant.id, .status = .passed, .witness_step = index };
                    break :eventually .{ .id = invariant.id, .status = .failed };
                },
                .never_active_after_first_step => never: {
                    const forbidden = invariant.state orelse break :never .{ .id = invariant.id, .status = .failed };
                    for (result.steps(), 1..) |step, index| if (step.after.isActive(forbidden)) break :never .{ .id = invariant.id, .status = .failed, .witness_step = index };
                    break :never .{ .id = invariant.id, .status = .passed };
                },
                .always_active => always: {
                    const expected = invariant.state orelse break :always .{ .id = invariant.id, .status = .failed };
                    for (result.steps(), 1..) |step, index| if (!step.after.isActive(expected)) break :always .{ .id = invariant.id, .status = .failed, .witness_step = index };
                    break :always .{ .id = invariant.id, .status = .passed };
                },
                .precedes => precedes: {
                    const before = invariant.before orelse break :precedes .{ .id = invariant.id, .status = .failed };
                    const after = invariant.state orelse break :precedes .{ .id = invariant.id, .status = .failed };
                    var seen_before = result.initial_snapshot.isActive(before);
                    for (result.steps(), 1..) |step, index| {
                        if (step.after.isActive(after)) break :precedes .{ .id = invariant.id, .status = if (seen_before) .passed else .failed, .witness_step = index };
                        if (step.after.isActive(before)) seen_before = true;
                    }
                    break :precedes .{ .id = invariant.id, .status = .failed };
                },
            };
        }
        fn hitsTransitionBreakpoint(step: *const Step, breakpoints: []const []const u8) bool {
            for (step.transitionIds()) |transition_id| for (breakpoints) |breakpoint| if (std.mem.eql(u8, transition_id, breakpoint)) return true;
            return false;
        }
        fn hitsStateBreakpoint(snapshot: *const Runtime.Snapshot, breakpoints: []const State) bool {
            for (breakpoints) |breakpoint| if (snapshot.isActive(breakpoint)) return true;
            return false;
        }
    };
}
