const std = @import("std");
const configuration_mod = @import("configuration.zig");
const machine_mod = @import("machine.zig");

pub const max_configuration_microsteps: usize = 256;
pub const max_configuration_commands: usize = machine_mod.max_decision_commands;
pub const max_configuration_internal_events: usize = machine_mod.max_decision_internal_events;

pub const ConfigurationMacrostepError = configuration_mod.ConfigurationError || error{
    MicrostepLimitExceeded,
    MacrostepCommandLimitExceeded,
    MacrostepInternalEventLimitExceeded,
};

pub fn ConfigurationMacrostep(comptime DefinitionType: type) type {
    const Runtime = configuration_mod.ConfigurationMachine(DefinitionType);
    const Event = DefinitionType.EventType;
    const Command = DefinitionType.CommandType;

    return struct {
        pub const Error = ConfigurationMacrostepError;

        pub const MicrostepRecord = struct {
            transition_storage: [configuration_mod.max_selected_transitions][]const u8 = undefined,
            transition_count: usize = 0,
            decision_fingerprint: u64,

            pub fn transitionIds(self: *const MicrostepRecord) []const []const u8 {
                return self.transition_storage[0..self.transition_count];
            }
        };

        pub const Result = struct {
            previous: Runtime.Snapshot,
            next: Runtime.Snapshot,
            microstep_storage: [max_configuration_microsteps]MicrostepRecord = undefined,
            microstep_count: usize = 0,
            command_storage: [max_configuration_commands]Command = undefined,
            command_count: usize = 0,
            fingerprint: u64 = 0,

            pub fn microsteps(self: *const Result) []const MicrostepRecord {
                return self.microstep_storage[0..self.microstep_count];
            }

            pub fn commands(self: *const Result) []const Command {
                return self.command_storage[0..self.command_count];
            }

            fn appendDecision(self: *Result, definition: *const DefinitionType, decision: *const Runtime.Decision) Error!void {
                self.next = decision.next;
                if (decision.outcome != .transitioned) return;
                const microstep_limit = @min(definition.bounds.max_microsteps, max_configuration_microsteps);
                if (self.microstep_count >= microstep_limit) return error.MicrostepLimitExceeded;
                var record = MicrostepRecord{
                    .decision_fingerprint = decision.fingerprint,
                    .transition_count = decision.transitionIds().len,
                };
                @memcpy(record.transition_storage[0..record.transition_count], decision.transitionIds());
                self.microstep_storage[self.microstep_count] = record;
                self.microstep_count += 1;

                const command_limit = @min(definition.bounds.max_commands, max_configuration_commands);
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
        ) Error!Result {
            var result = Result{ .previous = snapshot, .next = snapshot };
            var queue: [max_configuration_internal_events]Event = undefined;
            var queue_head: usize = 0;
            var queue_len: usize = 0;
            const event_limit = @min(definition.bounds.max_internal_events, max_configuration_internal_events);
            var last_event = external_event;

            const external = try Runtime.step(definition, result.next, external_event);
            try result.appendDecision(definition, &external);
            try enqueueEvents(&queue, &queue_len, event_limit, external.internalEvents());

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

        /// Builds and stabilizes the initial configuration as one transactional
        /// macrostep. Entry-action commands are preserved before any commands
        /// emitted by eventless or completion-event microsteps.
        pub fn initialize(
            definition: *const DefinitionType,
            context: DefinitionType.ContextType,
            instance_id: u64,
            init_event: Event,
        ) Error!Result {
            const initialization = try Runtime.initialize(definition, context, instance_id, init_event);
            var result = Result{
                .previous = initialization.snapshot,
                .next = initialization.snapshot,
                .command_count = initialization.commands().len,
            };
            @memcpy(result.command_storage[0..result.command_count], initialization.commands());

            var queue: [max_configuration_internal_events]Event = undefined;
            var queue_head: usize = 0;
            var queue_len: usize = 0;
            const event_limit = @min(definition.bounds.max_internal_events, max_configuration_internal_events);
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
            queue: *[max_configuration_internal_events]Event,
            queue_len: *usize,
            event_limit: usize,
            events: []const Event,
        ) Error!void {
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
                for (microstep.transitionIds()) |id| hashText(&hasher, id);
                hashInt(&hasher, microstep.decision_fingerprint);
            }
            for (result.next.activeAtomicStates()) |state| hashInt(&hasher, @intFromEnum(state));
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
