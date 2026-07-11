const std = @import("std");
const machine_mod = @import("machine.zig");

pub const max_macrostep_microsteps: usize = 256;
pub const max_macrostep_commands: usize = machine_mod.max_decision_commands;
pub const max_macrostep_internal_events: usize = machine_mod.max_decision_internal_events;

pub const MacrostepError = machine_mod.StepError || error{
    MicrostepLimitExceeded,
    MacrostepCommandLimitExceeded,
    MacrostepInternalEventLimitExceeded,
};

pub fn Macrostep(comptime DefinitionType: type) type {
    const Runtime = machine_mod.Machine(DefinitionType);
    const State = DefinitionType.StateType;
    const Event = DefinitionType.EventType;
    const Command = DefinitionType.CommandType;

    return struct {
        const Self = @This();

        pub const Error = MacrostepError;

        pub const MicrostepRecord = struct {
            transition_id: []const u8,
            source: State,
            target: State,
            decision_fingerprint: u64,
        };

        pub const Result = struct {
            previous: Runtime.Snapshot,
            next: Runtime.Snapshot,
            microstep_storage: [max_macrostep_microsteps]MicrostepRecord = undefined,
            microstep_count: usize = 0,
            command_storage: [max_macrostep_commands]Command = undefined,
            command_count: usize = 0,
            fingerprint: u64 = 0,

            pub fn microsteps(self: *const Result) []const MicrostepRecord {
                return self.microstep_storage[0..self.microstep_count];
            }

            pub fn commands(self: *const Result) []const Command {
                return self.command_storage[0..self.command_count];
            }

            fn appendDecision(
                self: *Result,
                definition: *const DefinitionType,
                decision: *const Runtime.Decision,
            ) MacrostepError!void {
                self.next = decision.next;
                if (decision.outcome != .transitioned) return;

                const microstep_limit = @min(definition.bounds.max_microsteps, max_macrostep_microsteps);
                if (self.microstep_count >= microstep_limit) return error.MicrostepLimitExceeded;
                self.microstep_storage[self.microstep_count] = .{
                    .transition_id = decision.selected_transition_id,
                    .source = decision.previous.state,
                    .target = decision.next.state,
                    .decision_fingerprint = decision.fingerprint,
                };
                self.microstep_count += 1;

                const command_limit = @min(definition.bounds.max_commands, max_macrostep_commands);
                for (decision.commands()) |command| {
                    if (self.command_count >= command_limit) return error.MacrostepCommandLimitExceeded;
                    self.command_storage[self.command_count] = command;
                    self.command_count += 1;
                }
            }
        };

        pub fn run(
            definition: *const DefinitionType,
            snapshot: Runtime.Snapshot,
            external_event: Event,
        ) MacrostepError!Result {
            var result = Result{ .previous = snapshot, .next = snapshot };
            var queue: [max_macrostep_internal_events]Event = undefined;
            var queue_head: usize = 0;
            var queue_len: usize = 0;
            const event_limit = @min(definition.bounds.max_internal_events, max_macrostep_internal_events);
            var last_event = external_event;

            const external_decision = try Runtime.step(definition, result.next, external_event);
            try result.appendDecision(definition, &external_decision);
            try enqueueEvents(&queue, &queue_len, event_limit, external_decision.internalEvents());

            while (result.next.status == .active) {
                const eventless_decision = try Runtime.stepEventless(definition, result.next, last_event);
                if (eventless_decision.outcome == .transitioned) {
                    try result.appendDecision(definition, &eventless_decision);
                    try enqueueEvents(&queue, &queue_len, event_limit, eventless_decision.internalEvents());
                    continue;
                }

                if (queue_head < queue_len) {
                    const internal_event = queue[queue_head];
                    queue_head += 1;
                    last_event = internal_event;
                    const internal_decision = try Runtime.step(definition, result.next, internal_event);
                    try result.appendDecision(definition, &internal_decision);
                    try enqueueEvents(&queue, &queue_len, event_limit, internal_decision.internalEvents());
                    continue;
                }

                break;
            }

            result.fingerprint = resultFingerprint(&result);
            return result;
        }

        /// Builds and stabilizes a flat machine's initial state as one
        /// transaction, preserving entry/invocation commands and internal
        /// events before eventless processing.
        pub fn initialize(
            definition: *const DefinitionType,
            context: DefinitionType.ContextType,
            instance_id: u64,
            init_event: Event,
        ) MacrostepError!Result {
            const initialization = try Runtime.initialize(definition, context, instance_id, init_event);
            var result = Result{
                .previous = initialization.snapshot,
                .next = initialization.snapshot,
                .command_count = initialization.commands().len,
            };
            @memcpy(result.command_storage[0..result.command_count], initialization.commands());

            var queue: [max_macrostep_internal_events]Event = undefined;
            var queue_head: usize = 0;
            var queue_len: usize = 0;
            const event_limit = @min(definition.bounds.max_internal_events, max_macrostep_internal_events);
            try enqueueEvents(&queue, &queue_len, event_limit, initialization.internalEvents());
            var last_event = init_event;

            while (result.next.status == .active) {
                const eventless = try Runtime.stepEventless(definition, result.next, last_event);
                if (eventless.outcome == .transitioned) {
                    try result.appendDecision(definition, &eventless);
                    try enqueueEvents(&queue, &queue_len, event_limit, eventless.internalEvents());
                    continue;
                }
                if (queue_head < queue_len) {
                    const internal_event = queue[queue_head];
                    queue_head += 1;
                    last_event = internal_event;
                    const internal = try Runtime.step(definition, result.next, internal_event);
                    try result.appendDecision(definition, &internal);
                    try enqueueEvents(&queue, &queue_len, event_limit, internal.internalEvents());
                    continue;
                }
                break;
            }
            result.fingerprint = resultFingerprint(&result);
            return result;
        }

        fn enqueueEvents(
            queue: *[max_macrostep_internal_events]Event,
            queue_len: *usize,
            event_limit: usize,
            events: []const Event,
        ) MacrostepError!void {
            for (events) |event| {
                if (queue_len.* >= event_limit) return error.MacrostepInternalEventLimitExceeded;
                queue[queue_len.*] = event;
                queue_len.* += 1;
            }
        }

        fn resultFingerprint(result: *const Result) u64 {
            var hasher = std.hash.Fnv1a_64.init();
            hashInt(&hasher, result.previous.definition_fingerprint);
            hashInt(&hasher, result.previous.instance_id);
            hashInt(&hasher, result.previous.revision);
            for (result.microsteps()) |microstep| {
                hashText(&hasher, microstep.transition_id);
                hashInt(&hasher, microstep.decision_fingerprint);
            }
            hashInt(&hasher, @intFromEnum(result.next.state));
            hashInt(&hasher, @intFromEnum(result.next.status));
            hashInt(&hasher, result.next.revision);
            const fingerprint = hasher.final();
            return if (fingerprint == 0) 1 else fingerprint;
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
