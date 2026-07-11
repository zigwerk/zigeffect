const std = @import("std");
const actor_mod = @import("actor.zig");
const control_mod = @import("control.zig");

pub const ActorSystemError = error{
    InvalidCapacity,
    SystemCapacityExceeded,
    DuplicateActorName,
    DuplicateInstanceId,
    ParentNotFound,
    ActorNotFound,
    EnvelopeQueueFull,
    StaleFence,
    NotLeaseOwner,
    SupervisionFailed,
    UnsupportedControlOperation,
};

pub const SupervisionPolicy = enum { stop, restart, @"resume", escalate };
pub const actor_tree_checkpoint_schema = "zigeffect.statechart.actor-tree.v1";
pub const actor_tree_checkpoint_schema_version: u32 = 1;

pub fn ActorSystem(comptime DefinitionType: type) type {
    return ActorSystemFor(DefinitionType, actor_mod.Actor(DefinitionType), false);
}

pub fn ConfigurationActorSystem(comptime DefinitionType: type) type {
    return ActorSystemFor(DefinitionType, actor_mod.ConfigurationActor(DefinitionType), true);
}

fn ActorSystemFor(comptime DefinitionType: type, comptime ActorType: type, comptime is_configuration: bool) type {
    _ = is_configuration;
    const Event = DefinitionType.EventType;
    const Context = DefinitionType.ContextType;

    return struct {
        const Self = @This();

        pub const SendDisposition = enum { delivered, dead_letter };

        pub const Envelope = struct {
            sender_instance_id: u64 = 0,
            correlation_id: u64 = 0,
            trace_id: u64 = 0,
            boundary_id: u64 = 0,
            expected_fence_epoch: u64 = 0,
        };

        pub const DeadLetter = struct {
            sequence: u64,
            recipient: []const u8,
            envelope: Envelope,
        };

        pub const PendingEnvelope = struct {
            event: Event,
            metadata: Envelope,
        };

        pub const ActorCheckpoint = struct {
            instance_id: u64,
            name: []u8,
            parent_instance_id: ?u64,
            snapshot: ActorType.Snapshot,
            status: actor_mod.ActorStatus,
            pending: []PendingEnvelope,
            lease_owner: ?[]u8,
            lease_epoch: u64,
            initial_context: Context,
            supervision: SupervisionPolicy,
            mailbox_capacity: usize,
            inspection_capacity: usize,
            subscriber_capacity: usize,
        };

        pub const TreeCheckpoint = struct {
            allocator: std.mem.Allocator,
            schema: []const u8 = actor_tree_checkpoint_schema,
            schema_version: u32 = actor_tree_checkpoint_schema_version,
            actors: []ActorCheckpoint,

            pub fn deinit(self: *TreeCheckpoint) void {
                for (self.actors) |actor| {
                    self.allocator.free(actor.name);
                    self.allocator.free(actor.pending);
                    if (actor.lease_owner) |owner| self.allocator.free(owner);
                }
                self.allocator.free(self.actors);
                self.* = undefined;
            }
        };

        /// Rebinds process-local command services while restoring durable actor
        /// state. Function pointers and service handles are deliberately absent
        /// from the checkpoint.
        pub const ExecutorResolver = struct {
            context: *anyopaque,
            resolve_fn: *const fn (context: *anyopaque, name: []const u8, instance_id: u64) ?ActorType.CommandExecutor,

            pub fn resolve(self: ExecutorResolver, name: []const u8, instance_id: u64) ?ActorType.CommandExecutor {
                return self.resolve_fn(self.context, name, instance_id);
            }
        };

        pub const SpawnOptions = struct {
            instance_id: u64,
            name: []const u8,
            parent_instance_id: ?u64 = null,
            mailbox_capacity: usize = 64,
            inspection_capacity: usize = 128,
            subscriber_capacity: usize = 8,
            executor: ?ActorType.CommandExecutor = null,
            initialization_event: ?Event = null,
            supervision: SupervisionPolicy = .stop,
        };

        pub const Options = struct {
            capacity: usize = 64,
            dead_letter_capacity: usize = 128,
        };

        pub const ProcessResult = struct {
            snapshot: ActorType.Snapshot,
            actor_result: ActorType.ProcessResult,
            envelope: Envelope,
        };

        const QueuedEnvelope = struct {
            event: Event,
            metadata: Envelope,
        };

        const Slot = struct {
            actor: ?ActorType = null,
            name: ?[]u8 = null,
            parent_instance_id: ?u64 = null,
            envelope_queue: ?[]QueuedEnvelope = null,
            envelope_head: usize = 0,
            envelope_len: usize = 0,
            lease_owner: ?[]u8 = null,
            lease_epoch: u64 = 0,
            initial_context: Context = undefined,
            initialization_event: ?Event = null,
            supervision: SupervisionPolicy = .stop,
            executor: ?ActorType.CommandExecutor = null,
            inspection_capacity: usize = 128,
            subscriber_capacity: usize = 8,
        };

        const DeadLetterSlot = struct {
            record: ?DeadLetter = null,
            owned_recipient: ?[]u8 = null,
        };

        allocator: std.mem.Allocator,
        definition: *const DefinitionType,
        slots: []Slot,
        dead_letters: []DeadLetterSlot,
        dead_letter_head: usize = 0,
        dead_letter_len: usize = 0,
        dead_letter_sequence: u64 = 0,

        pub fn init(
            allocator: std.mem.Allocator,
            definition: *const DefinitionType,
            options: Options,
        ) (std.mem.Allocator.Error || ActorSystemError)!Self {
            if (options.capacity == 0 or options.dead_letter_capacity == 0) return error.InvalidCapacity;
            const slots = try allocator.alloc(Slot, options.capacity);
            errdefer allocator.free(slots);
            @memset(slots, .{});
            const dead_letters = try allocator.alloc(DeadLetterSlot, options.dead_letter_capacity);
            errdefer allocator.free(dead_letters);
            @memset(dead_letters, .{});
            return .{
                .allocator = allocator,
                .definition = definition,
                .slots = slots,
                .dead_letters = dead_letters,
            };
        }

        pub fn checkpoint(self: *const Self, allocator: std.mem.Allocator) std.mem.Allocator.Error!TreeCheckpoint {
            var actor_count: usize = 0;
            for (self.slots) |slot| if (slot.actor != null) {
                actor_count += 1;
            };
            const actors = try allocator.alloc(ActorCheckpoint, actor_count);
            errdefer allocator.free(actors);
            var initialized: usize = 0;
            errdefer for (actors[0..initialized]) |actor| {
                allocator.free(actor.name);
                allocator.free(actor.pending);
                if (actor.lease_owner) |owner| allocator.free(owner);
            };

            for (self.slots) |slot| {
                const actor = slot.actor orelse continue;
                const name = try allocator.dupe(u8, slot.name.?);
                errdefer allocator.free(name);
                const owner = if (slot.lease_owner) |value| try allocator.dupe(u8, value) else null;
                errdefer if (owner) |value| allocator.free(value);
                const pending = try allocator.alloc(PendingEnvelope, slot.envelope_len);
                errdefer allocator.free(pending);
                const queue = slot.envelope_queue.?;
                for (0..slot.envelope_len) |index| {
                    const queued = queue[(slot.envelope_head + index) % queue.len];
                    pending[index] = .{ .event = queued.event, .metadata = queued.metadata };
                }
                actors[initialized] = .{
                    .instance_id = actor.snapshot().instance_id,
                    .name = name,
                    .parent_instance_id = slot.parent_instance_id,
                    .snapshot = actor.snapshot(),
                    .status = actor.status(),
                    .pending = pending,
                    .lease_owner = owner,
                    .lease_epoch = slot.lease_epoch,
                    .initial_context = slot.initial_context,
                    .supervision = slot.supervision,
                    .mailbox_capacity = queue.len,
                    .inspection_capacity = slot.inspection_capacity,
                    .subscriber_capacity = slot.subscriber_capacity,
                };
                initialized += 1;
            }
            return .{ .allocator = allocator, .actors = actors };
        }

        pub fn restore(
            allocator: std.mem.Allocator,
            definition: *const DefinitionType,
            checkpoint_value: *const TreeCheckpoint,
            options: Options,
            resolver: ?ExecutorResolver,
        ) (ActorType.Error || ActorSystemError)!Self {
            if (!std.mem.eql(u8, checkpoint_value.schema, actor_tree_checkpoint_schema) or
                checkpoint_value.schema_version != actor_tree_checkpoint_schema_version)
            {
                return error.InvalidDefinition;
            }
            if (checkpoint_value.actors.len > options.capacity) return error.SystemCapacityExceeded;
            for (checkpoint_value.actors, 0..) |candidate, index| {
                for (checkpoint_value.actors[index + 1 ..]) |other| {
                    if (candidate.instance_id == other.instance_id) return error.DuplicateInstanceId;
                    if (std.mem.eql(u8, candidate.name, other.name)) return error.DuplicateActorName;
                }
                if (candidate.parent_instance_id) |parent| {
                    var found = false;
                    for (checkpoint_value.actors) |possible| if (possible.instance_id == parent) {
                        found = true;
                        break;
                    };
                    if (!found) return error.ParentNotFound;
                }
                if (candidate.pending.len > candidate.mailbox_capacity) return error.EnvelopeQueueFull;
            }

            var system = try Self.init(allocator, definition, options);
            errdefer system.deinit();
            for (checkpoint_value.actors) |saved| {
                const slot = system.freeSlot() orelse return error.SystemCapacityExceeded;
                const name = try allocator.dupe(u8, saved.name);
                errdefer allocator.free(name);
                const owner = if (saved.lease_owner) |value| try allocator.dupe(u8, value) else null;
                errdefer if (owner) |value| allocator.free(value);
                const queue = try allocator.alloc(QueuedEnvelope, saved.mailbox_capacity);
                errdefer allocator.free(queue);
                const executor = if (resolver) |value| value.resolve(saved.name, saved.instance_id) else null;
                var actor = try ActorType.initFromSnapshot(allocator, definition, saved.snapshot, saved.status, .{
                    .instance_id = saved.instance_id,
                    .mailbox_capacity = saved.mailbox_capacity,
                    .inspection_capacity = saved.inspection_capacity,
                    .subscriber_capacity = saved.subscriber_capacity,
                    .overflow_policy = .reject,
                    .executor = executor,
                });
                errdefer actor.deinit();
                for (saved.pending, 0..) |pending, pending_index| {
                    try actor.restorePending(&.{pending.event});
                    queue[pending_index] = .{ .event = pending.event, .metadata = pending.metadata };
                }
                slot.* = .{
                    .actor = actor,
                    .name = name,
                    .parent_instance_id = saved.parent_instance_id,
                    .envelope_queue = queue,
                    .envelope_len = saved.pending.len,
                    .lease_owner = owner,
                    .lease_epoch = saved.lease_epoch,
                    .initial_context = saved.initial_context,
                    .supervision = saved.supervision,
                    .executor = executor,
                    .inspection_capacity = saved.inspection_capacity,
                    .subscriber_capacity = saved.subscriber_capacity,
                };
            }
            return system;
        }

        pub fn deinit(self: *Self) void {
            for (self.slots) |*slot| self.deinitSlot(slot);
            for (self.dead_letters) |*slot| {
                if (slot.owned_recipient) |recipient| self.allocator.free(recipient);
            }
            self.allocator.free(self.dead_letters);
            self.allocator.free(self.slots);
            self.* = undefined;
        }

        pub fn spawn(
            self: *Self,
            context: Context,
            options: SpawnOptions,
        ) (ActorType.Error || ActorSystemError)!void {
            if (options.name.len == 0 or options.mailbox_capacity == 0) return error.InvalidCapacity;
            if (self.findByName(options.name) != null) return error.DuplicateActorName;
            if (self.findById(options.instance_id) != null) return error.DuplicateInstanceId;
            if (options.parent_instance_id) |parent| {
                if (self.findById(parent) == null) return error.ParentNotFound;
            }
            const slot = self.freeSlot() orelse return error.SystemCapacityExceeded;
            const owned_name = try self.allocator.dupe(u8, options.name);
            errdefer self.allocator.free(owned_name);
            const envelopes = try self.allocator.alloc(QueuedEnvelope, options.mailbox_capacity);
            errdefer self.allocator.free(envelopes);
            const actor_options = ActorType.Options{
                .instance_id = options.instance_id,
                .mailbox_capacity = options.mailbox_capacity,
                .inspection_capacity = options.inspection_capacity,
                .subscriber_capacity = options.subscriber_capacity,
                .overflow_policy = .reject,
                .executor = options.executor,
            };
            const actor = if (options.initialization_event) |init_event|
                try ActorType.initWithEvent(self.allocator, self.definition, context, init_event, actor_options)
            else
                try ActorType.init(self.allocator, self.definition, context, actor_options);
            slot.* = .{
                .actor = actor,
                .name = owned_name,
                .parent_instance_id = options.parent_instance_id,
                .envelope_queue = envelopes,
                .initial_context = context,
                .initialization_event = options.initialization_event,
                .supervision = options.supervision,
                .executor = options.executor,
                .inspection_capacity = options.inspection_capacity,
                .subscriber_capacity = options.subscriber_capacity,
            };
        }

        pub fn send(self: *Self, recipient: []const u8, event: Event, envelope: Envelope) !SendDisposition {
            const slot = self.findByName(recipient) orelse {
                try self.recordDeadLetter(recipient, envelope);
                return .dead_letter;
            };
            if (envelope.expected_fence_epoch != 0 and envelope.expected_fence_epoch != slot.lease_epoch) return error.StaleFence;
            const queue = slot.envelope_queue orelse return error.ActorNotFound;
            if (slot.envelope_len >= queue.len) return error.EnvelopeQueueFull;
            _ = try slot.actor.?.send(event);
            const index = (slot.envelope_head + slot.envelope_len) % queue.len;
            queue[index] = .{ .event = event, .metadata = envelope };
            slot.envelope_len += 1;
            return .delivered;
        }

        pub fn process(self: *Self, name: []const u8) !ProcessResult {
            const slot = self.findByName(name) orelse return error.ActorNotFound;
            return self.processSupervised(slot);
        }

        pub fn processOwned(self: *Self, name: []const u8, owner: []const u8, epoch: u64) !ProcessResult {
            const slot = self.findByName(name) orelse return error.ActorNotFound;
            if (epoch != slot.lease_epoch) return error.StaleFence;
            const actual_owner = slot.lease_owner orelse return error.NotLeaseOwner;
            if (!std.mem.eql(u8, actual_owner, owner)) return error.NotLeaseOwner;
            return self.processSupervised(slot);
        }

        pub fn claim(self: *Self, instance_id: u64, owner: []const u8, epoch: u64) !void {
            const slot = self.findById(instance_id) orelse return error.ActorNotFound;
            if (epoch < slot.lease_epoch) return error.StaleFence;
            if (epoch == slot.lease_epoch and slot.lease_owner != null and !std.mem.eql(u8, slot.lease_owner.?, owner)) {
                return error.StaleFence;
            }
            const owned_owner = try self.allocator.dupe(u8, owner);
            if (slot.lease_owner) |previous| self.allocator.free(previous);
            slot.lease_owner = owned_owner;
            slot.lease_epoch = epoch;
        }

        pub fn stop(self: *Self, instance_id: u64) ActorSystemError!void {
            const slot = self.findById(instance_id) orelse return error.ActorNotFound;
            slot.actor.?.stop();
            for (self.slots) |*candidate| {
                if (candidate.actor == null or candidate.parent_instance_id == null) continue;
                if (candidate.parent_instance_id.? == instance_id) try self.stop(candidate.actor.?.snapshot().instance_id);
            }
        }

        pub fn status(self: *Self, instance_id: u64) ?actor_mod.ActorStatus {
            const slot = self.findById(instance_id) orelse return null;
            return slot.actor.?.status();
        }

        /// Adapts this actor system to the policy-neutral statechart control
        /// plane. The caller must still attach an explicit allow/review policy.
        pub fn controlAdapter(self: *Self) control_mod.ControlPlane(Event).Adapter {
            return .{ .context = self, .inspect_fn = inspectControl, .apply_fn = applyControl };
        }

        fn inspectControl(context: *anyopaque, instance_id: u64) anyerror!control_mod.ControlPlane(Event).InstanceState {
            const self: *Self = @ptrCast(@alignCast(context));
            const slot = self.findById(instance_id) orelse return error.ActorNotFound;
            const status_value: control_mod.InstanceStatus = switch (slot.actor.?.status()) {
                .running => .running,
                .completed => .completed,
                .stopped => .stopped,
                .failed => .failed,
            };
            return .{
                .definition_fingerprint = self.definition.fingerprint(),
                .fence_epoch = slot.lease_epoch,
                .status = status_value,
            };
        }

        fn applyControl(context: *anyopaque, request: control_mod.ControlPlane(Event).Request) anyerror!void {
            const self: *Self = @ptrCast(@alignCast(context));
            const slot = self.findById(request.instance_id) orelse return error.ActorNotFound;
            switch (request.operation) {
                .inspect => {},
                .signal => {
                    const event = request.event orelse return error.UnsupportedControlOperation;
                    const queue = slot.envelope_queue orelse return error.ActorNotFound;
                    if (slot.envelope_len >= queue.len) return error.EnvelopeQueueFull;
                    _ = try slot.actor.?.send(event);
                    const index = (slot.envelope_head + slot.envelope_len) % queue.len;
                    queue[index] = .{ .event = event, .metadata = .{
                        .correlation_id = request.correlation_id,
                        .trace_id = request.trace_id,
                        .boundary_id = request.boundary_id,
                        .expected_fence_epoch = request.expected_fence_epoch,
                    } };
                    slot.envelope_len += 1;
                },
                .cancel, .drain => try self.stop(request.instance_id),
                .@"resume", .retry => try slot.actor.?.resumeAfterFailure(),
                .start, .@"suspend", .checkpoint, .restart, .migrate => return error.UnsupportedControlOperation,
            }
        }

        fn processSupervised(self: *Self, slot: *Slot) !ProcessResult {
            return processSlot(slot) catch |err| {
                if (err == error.CommandExecutionFailed) {
                    if (slot.envelope_len != 0) {
                        const queue = slot.envelope_queue orelse return error.ActorNotFound;
                        slot.envelope_head = (slot.envelope_head + 1) % queue.len;
                        slot.envelope_len -= 1;
                    }
                    self.applySupervision(slot) catch return error.SupervisionFailed;
                }
                return err;
            };
        }

        fn applySupervision(self: *Self, slot: *Slot) !void {
            switch (slot.supervision) {
                .stop => slot.actor.?.stop(),
                .@"resume" => try slot.actor.?.resumeAfterFailure(),
                .restart => {
                    const instance_id = slot.actor.?.snapshot().instance_id;
                    slot.actor.?.deinit();
                    const options = ActorType.Options{
                        .instance_id = instance_id,
                        .mailbox_capacity = (slot.envelope_queue orelse return error.ActorNotFound).len,
                        .inspection_capacity = slot.inspection_capacity,
                        .subscriber_capacity = slot.subscriber_capacity,
                        .overflow_policy = .reject,
                        .executor = slot.executor,
                    };
                    slot.actor = if (slot.initialization_event) |init_event|
                        try ActorType.initWithEvent(self.allocator, self.definition, slot.initial_context, init_event, options)
                    else
                        try ActorType.init(self.allocator, self.definition, slot.initial_context, options);
                },
                .escalate => {
                    slot.actor.?.stop();
                    if (slot.parent_instance_id) |parent| try self.stop(parent);
                },
            }
        }

        pub fn copyDeadLetters(self: *const Self, storage: []DeadLetter) []const DeadLetter {
            const count = @min(storage.len, self.dead_letter_len);
            const skip = self.dead_letter_len - count;
            for (0..count) |index| {
                const ring_index = (self.dead_letter_head + skip + index) % self.dead_letters.len;
                storage[index] = self.dead_letters[ring_index].record.?;
            }
            return storage[0..count];
        }

        fn processSlot(slot: *Slot) !ProcessResult {
            if (slot.envelope_len == 0) {
                const actor_result = try slot.actor.?.processNext();
                return .{ .snapshot = slot.actor.?.snapshot(), .actor_result = actor_result, .envelope = .{} };
            }
            const queue = slot.envelope_queue orelse return error.ActorNotFound;
            const envelope = queue[slot.envelope_head].metadata;
            const actor_result = try slot.actor.?.processNext();
            slot.envelope_head = (slot.envelope_head + 1) % queue.len;
            slot.envelope_len -= 1;
            return .{ .snapshot = slot.actor.?.snapshot(), .actor_result = actor_result, .envelope = envelope };
        }

        fn recordDeadLetter(self: *Self, recipient: []const u8, envelope: Envelope) !void {
            self.dead_letter_sequence +%= 1;
            if (self.dead_letter_sequence == 0) self.dead_letter_sequence = 1;
            const index = if (self.dead_letter_len < self.dead_letters.len)
                (self.dead_letter_head + self.dead_letter_len) % self.dead_letters.len
            else
                self.dead_letter_head;
            const slot = &self.dead_letters[index];
            const owned = try self.allocator.dupe(u8, recipient);
            if (slot.owned_recipient) |previous| self.allocator.free(previous);
            slot.owned_recipient = owned;
            slot.record = .{
                .sequence = self.dead_letter_sequence,
                .recipient = owned,
                .envelope = envelope,
            };
            if (self.dead_letter_len < self.dead_letters.len) {
                self.dead_letter_len += 1;
            } else {
                self.dead_letter_head = (self.dead_letter_head + 1) % self.dead_letters.len;
            }
        }

        fn findByName(self: *Self, name: []const u8) ?*Slot {
            for (self.slots) |*slot| {
                const candidate = slot.name orelse continue;
                if (std.mem.eql(u8, candidate, name)) return slot;
            }
            return null;
        }

        fn findById(self: *Self, instance_id: u64) ?*Slot {
            for (self.slots) |*slot| {
                const actor = slot.actor orelse continue;
                if (actor.snapshot().instance_id == instance_id) return slot;
            }
            return null;
        }

        fn freeSlot(self: *Self) ?*Slot {
            for (self.slots) |*slot| if (slot.actor == null) return slot;
            return null;
        }

        fn deinitSlot(self: *Self, slot: *Slot) void {
            if (slot.actor) |*actor| actor.deinit();
            if (slot.name) |name| self.allocator.free(name);
            if (slot.envelope_queue) |queue| self.allocator.free(queue);
            if (slot.lease_owner) |owner| self.allocator.free(owner);
            slot.* = .{};
        }
    };
}
