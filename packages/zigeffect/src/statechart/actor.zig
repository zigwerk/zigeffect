const std = @import("std");
const macrostep_mod = @import("macrostep.zig");
const machine_mod = @import("machine.zig");
const configuration_mod = @import("configuration.zig");
const configuration_macrostep_mod = @import("configuration_macrostep.zig");

pub const Allocator = std.mem.Allocator;

pub const ActorStatus = enum {
    running,
    completed,
    stopped,
    failed,
};

pub const MailboxOverflowPolicy = enum {
    reject,
    drop_newest,
    drop_oldest,
};

pub const InspectionKind = enum {
    actor_started,
    actor_completed,
    actor_stopped,
    actor_failed,
    event_enqueued,
    event_dropped,
    macrostep_committed,
    command_completed,
    command_failed,
    subscriber_added,
    subscriber_removed,
    actor_resumed,
    actor_restored,
};

pub const ActorError = error{
    InvalidCapacity,
    InvalidDefinition,
    MailboxFull,
    ActorStopped,
    ActorCompleted,
    ActorFailed,
    MissingCommandExecutor,
    CommandExecutionFailed,
    SubscriberCapacityExceeded,
    UnknownSubscription,
    ActorNotFailed,
    WrongExecutor,
    MissingInitializationEvent,
};

pub fn Actor(comptime DefinitionType: type) type {
    return ActorFor(DefinitionType, machine_mod.Machine(DefinitionType), macrostep_mod.Macrostep(DefinitionType), false);
}

pub fn ConfigurationActor(comptime DefinitionType: type) type {
    return ActorFor(
        DefinitionType,
        configuration_mod.ConfigurationMachine(DefinitionType),
        configuration_macrostep_mod.ConfigurationMacrostep(DefinitionType),
        true,
    );
}

fn ActorFor(
    comptime DefinitionType: type,
    comptime Runtime: type,
    comptime Macro: type,
    comptime initial_returns_error: bool,
) type {
    const Event = DefinitionType.EventType;
    const Context = DefinitionType.ContextType;
    const Command = DefinitionType.CommandType;
    const ActorStatusT = ActorStatus;
    const MailboxOverflowPolicyT = MailboxOverflowPolicy;
    const InspectionKindT = InspectionKind;

    return struct {
        const Self = @This();

        pub const Snapshot = Runtime.Snapshot;
        pub const Status = ActorStatusT;
        pub const MailboxOverflowPolicy = MailboxOverflowPolicyT;
        pub const InspectionKind = InspectionKindT;
        pub const Error = ActorError || Allocator.Error || Macro.Error;

        pub const SendResult = enum {
            enqueued,
            dropped_newest,
            replaced_oldest,
        };

        pub const ProcessStatus = enum {
            idle,
            processed,
        };

        pub const ProcessResult = struct {
            status: ProcessStatus,
            transition_id: []const u8 = "",
            microstep_count: usize = 0,
            command_count: usize = 0,
        };

        pub const CommandExecutor = struct {
            context: *anyopaque,
            execute_fn: *const fn (context: *anyopaque, command: Command) anyerror!void,

            pub fn execute(self: CommandExecutor, command: Command) anyerror!void {
                return self.execute_fn(self.context, command);
            }
        };

        pub const Subscriber = struct {
            context: *anyopaque,
            notify_fn: *const fn (context: *anyopaque, snapshot: Snapshot) void,

            pub fn notify(self: Subscriber, snapshot_value: Snapshot) void {
                self.notify_fn(self.context, snapshot_value);
            }
        };

        const SubscriptionSlot = struct {
            id: u64 = 0,
            subscriber: ?Subscriber = null,
        };

        pub const InspectionRecord = struct {
            sequence: u64,
            kind: InspectionKindT,
            instance_id: u64,
            revision: u64,
            label: []const u8 = "",
            status: []const u8 = "",
        };

        pub const Options = struct {
            instance_id: u64,
            mailbox_capacity: usize = 64,
            inspection_capacity: usize = 128,
            subscriber_capacity: usize = 8,
            overflow_policy: MailboxOverflowPolicyT = .reject,
            executor: ?CommandExecutor = null,
            owner_thread_id: ?std.Thread.Id = null,
        };

        allocator: Allocator,
        definition: *const DefinitionType,
        current: Snapshot,
        actor_status: ActorStatusT = .running,
        overflow_policy: MailboxOverflowPolicyT,
        executor: ?CommandExecutor,
        mailbox: []Event,
        mailbox_head: usize = 0,
        mailbox_len: usize = 0,
        inspection: []InspectionRecord,
        inspection_head: usize = 0,
        inspection_len: usize = 0,
        inspection_sequence: u64 = 0,
        subscriptions: []SubscriptionSlot,
        next_subscription_id: u64 = 1,
        owner_thread_id: std.Thread.Id,

        pub fn init(
            allocator: Allocator,
            definition: *const DefinitionType,
            context: Context,
            options: Options,
        ) Error!Self {
            if (options.mailbox_capacity == 0 or options.inspection_capacity == 0) return error.InvalidCapacity;
            const validation = definition.validate();
            if (!validation.isValid()) return error.InvalidDefinition;
            if (comptime !initial_returns_error) {
                if (Runtime.requiresInitializationEvent(definition)) return error.MissingInitializationEvent;
            }

            const mailbox = try allocator.alloc(Event, options.mailbox_capacity);
            errdefer allocator.free(mailbox);
            const inspection = try allocator.alloc(InspectionRecord, options.inspection_capacity);
            errdefer allocator.free(inspection);
            const subscriptions = try allocator.alloc(SubscriptionSlot, options.subscriber_capacity);
            errdefer allocator.free(subscriptions);
            @memset(subscriptions, .{});
            const initial_snapshot = if (initial_returns_error)
                try Runtime.initial(definition, context, options.instance_id)
            else
                Runtime.initial(definition, context, options.instance_id);

            var self = Self{
                .allocator = allocator,
                .definition = definition,
                .current = initial_snapshot,
                .actor_status = if (initial_snapshot.status == .done) .completed else .running,
                .overflow_policy = options.overflow_policy,
                .executor = options.executor,
                .mailbox = mailbox,
                .inspection = inspection,
                .subscriptions = subscriptions,
                .owner_thread_id = options.owner_thread_id orelse std.Thread.getCurrentId(),
            };
            self.record(.actor_started, definition.id, "running");
            if (self.actor_status == .completed) self.record(.actor_completed, definition.id, "completed");
            return self;
        }

        /// Initializes an actor through its typed initialization macrostep so
        /// entry actions, invocations, completion events, and eventless
        /// transitions are never skipped at startup.
        pub fn initWithEvent(
            allocator: Allocator,
            definition: *const DefinitionType,
            context: Context,
            init_event: Event,
            options: Options,
        ) Error!Self {
            if (options.mailbox_capacity == 0 or options.inspection_capacity == 0) return error.InvalidCapacity;
            const validation = definition.validate();
            if (!validation.isValid()) return error.InvalidDefinition;

            const initialized = try Macro.initialize(definition, context, options.instance_id, init_event);
            if (initialized.commands().len != 0 and options.executor == null) return error.MissingCommandExecutor;

            const mailbox = try allocator.alloc(Event, options.mailbox_capacity);
            errdefer allocator.free(mailbox);
            const inspection = try allocator.alloc(InspectionRecord, options.inspection_capacity);
            errdefer allocator.free(inspection);
            const subscriptions = try allocator.alloc(SubscriptionSlot, options.subscriber_capacity);
            errdefer allocator.free(subscriptions);
            @memset(subscriptions, .{});

            var self = Self{
                .allocator = allocator,
                .definition = definition,
                .current = initialized.next,
                .actor_status = if (initialized.next.status == .done) .completed else .running,
                .overflow_policy = options.overflow_policy,
                .executor = options.executor,
                .mailbox = mailbox,
                .inspection = inspection,
                .subscriptions = subscriptions,
                .owner_thread_id = options.owner_thread_id orelse std.Thread.getCurrentId(),
            };
            self.record(.actor_started, definition.id, "running");
            if (options.executor) |executor| {
                for (initialized.commands()) |command| {
                    executor.execute(command) catch {
                        self.actor_status = .failed;
                        self.current.status = .failed;
                        self.record(.command_failed, valueTagName(Command, command), "failed");
                        self.record(.actor_failed, definition.id, "failed");
                        return error.CommandExecutionFailed;
                    };
                    self.record(.command_completed, valueTagName(Command, command), "completed");
                }
            }
            if (self.actor_status == .completed) self.record(.actor_completed, definition.id, "completed");
            return self;
        }

        /// Rehydrates an actor from an authoritative durable snapshot. External
        /// command executors are supplied again through `options`; no process
        /// pointer is ever treated as durable state.
        pub fn initFromSnapshot(
            allocator: Allocator,
            definition: *const DefinitionType,
            snapshot_value: Snapshot,
            restored_status: ActorStatusT,
            options: Options,
        ) Error!Self {
            if (options.mailbox_capacity == 0 or options.inspection_capacity == 0) return error.InvalidCapacity;
            const validation = definition.validate();
            if (!validation.isValid()) return error.InvalidDefinition;
            if (snapshot_value.definition_fingerprint != definition.fingerprint() or
                snapshot_value.instance_id != options.instance_id)
            {
                return error.DefinitionMismatch;
            }

            const mailbox = try allocator.alloc(Event, options.mailbox_capacity);
            errdefer allocator.free(mailbox);
            const inspection = try allocator.alloc(InspectionRecord, options.inspection_capacity);
            errdefer allocator.free(inspection);
            const subscriptions = try allocator.alloc(SubscriptionSlot, options.subscriber_capacity);
            errdefer allocator.free(subscriptions);
            @memset(subscriptions, .{});

            var self = Self{
                .allocator = allocator,
                .definition = definition,
                .current = snapshot_value,
                .actor_status = restored_status,
                .overflow_policy = options.overflow_policy,
                .executor = options.executor,
                .mailbox = mailbox,
                .inspection = inspection,
                .subscriptions = subscriptions,
                .owner_thread_id = options.owner_thread_id orelse std.Thread.getCurrentId(),
            };
            self.record(.actor_restored, definition.id, @tagName(restored_status));
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.subscriptions);
            self.allocator.free(self.inspection);
            self.allocator.free(self.mailbox);
            self.* = undefined;
        }

        pub fn status(self: *const Self) ActorStatusT {
            return self.actor_status;
        }

        pub fn snapshot(self: *const Self) Snapshot {
            return self.current;
        }

        pub fn mailboxSize(self: *const Self) usize {
            return self.mailbox_len;
        }

        /// Restores already accepted mailbox events without re-running ingress
        /// policy or publishing duplicate enqueue evidence.
        pub fn restorePending(self: *Self, events: []const Event) ActorError!void {
            if (events.len > self.mailbox.len - self.mailbox_len) return error.MailboxFull;
            for (events) |event| self.enqueue(event);
        }

        pub fn send(self: *Self, event: Event) ActorError!SendResult {
            try self.ensureConfined();
            try self.ensureRunning();
            if (self.mailbox_len == self.mailbox.len) {
                switch (self.overflow_policy) {
                    .reject => return error.MailboxFull,
                    .drop_newest => {
                        self.record(.event_dropped, valueTagName(Event, event), "drop_newest");
                        return .dropped_newest;
                    },
                    .drop_oldest => {
                        self.mailbox_head = (self.mailbox_head + 1) % self.mailbox.len;
                        self.mailbox_len -= 1;
                        self.enqueue(event);
                        self.record(.event_dropped, valueTagName(Event, event), "drop_oldest");
                        return .replaced_oldest;
                    },
                }
            }

            self.enqueue(event);
            self.record(.event_enqueued, valueTagName(Event, event), "enqueued");
            return .enqueued;
        }

        pub fn processNext(self: *Self) Error!ProcessResult {
            try self.ensureConfined();
            try self.ensureRunning();
            if (self.mailbox_len == 0) return .{ .status = .idle };

            const event = self.mailbox[self.mailbox_head];
            const result = try Macro.run(self.definition, self.current, event);
            if (result.commands().len != 0 and self.executor == null) return error.MissingCommandExecutor;

            self.current = result.next;
            self.mailbox_head = (self.mailbox_head + 1) % self.mailbox.len;
            self.mailbox_len -= 1;
            const transition_id = firstTransitionId(&result);
            self.record(.macrostep_committed, transition_id, "committed");
            self.notifySubscribers();

            if (self.executor) |executor| {
                for (result.commands()) |command| {
                    executor.execute(command) catch {
                        self.actor_status = .failed;
                        self.current.status = .failed;
                        self.record(.command_failed, valueTagName(Command, command), "failed");
                        self.record(.actor_failed, self.definition.id, "failed");
                        return error.CommandExecutionFailed;
                    };
                    self.record(.command_completed, valueTagName(Command, command), "completed");
                }
            }

            if (self.current.status == .done) {
                self.actor_status = .completed;
                self.record(.actor_completed, self.definition.id, "completed");
            }

            return .{
                .status = .processed,
                .transition_id = transition_id,
                .microstep_count = result.microsteps().len,
                .command_count = result.commands().len,
            };
        }

        pub fn stop(self: *Self) void {
            if (self.actor_status == .stopped) return;
            self.actor_status = .stopped;
            self.current.status = .stopped;
            self.record(.actor_stopped, self.definition.id, "stopped");
        }

        pub fn resumeAfterFailure(self: *Self) ActorError!void {
            if (self.actor_status != .failed) return error.ActorNotFailed;
            self.actor_status = .running;
            self.current.status = .active;
            self.record(.actor_resumed, self.definition.id, "running");
        }

        pub fn subscribe(self: *Self, subscriber: Subscriber) ActorError!u64 {
            for (self.subscriptions) |*slot| {
                if (slot.subscriber != null) continue;
                const id = self.next_subscription_id;
                self.next_subscription_id +%= 1;
                if (self.next_subscription_id == 0) self.next_subscription_id = 1;
                slot.* = .{ .id = id, .subscriber = subscriber };
                self.record(.subscriber_added, "snapshot", "active");
                return id;
            }
            return error.SubscriberCapacityExceeded;
        }

        pub fn unsubscribe(self: *Self, subscription_id: u64) void {
            for (self.subscriptions) |*slot| {
                if (slot.id != subscription_id or slot.subscriber == null) continue;
                slot.* = .{};
                self.record(.subscriber_removed, "snapshot", "removed");
                return;
            }
        }

        pub fn copyInspection(self: *const Self, storage: []InspectionRecord) []const InspectionRecord {
            const count = @min(storage.len, self.inspection_len);
            const skip = self.inspection_len - count;
            for (0..count) |index| {
                const ring_index = (self.inspection_head + skip + index) % self.inspection.len;
                storage[index] = self.inspection[ring_index];
            }
            return storage[0..count];
        }

        fn ensureRunning(self: *const Self) ActorError!void {
            return switch (self.actor_status) {
                .running => {},
                .completed => error.ActorCompleted,
                .stopped => error.ActorStopped,
                .failed => error.ActorFailed,
            };
        }

        fn ensureConfined(self: *const Self) ActorError!void {
            if (std.Thread.getCurrentId() != self.owner_thread_id) return error.WrongExecutor;
        }

        fn firstTransitionId(result: *const Macro.Result) []const u8 {
            if (result.microsteps().len == 0) return "";
            const step_record = &result.microsteps()[0];
            if (@hasDecl(@TypeOf(step_record.*), "transitionIds")) {
                const ids = step_record.transitionIds();
                return if (ids.len == 0) "" else ids[0];
            }
            return step_record.transition_id;
        }

        fn enqueue(self: *Self, event: Event) void {
            const index = (self.mailbox_head + self.mailbox_len) % self.mailbox.len;
            self.mailbox[index] = event;
            self.mailbox_len += 1;
        }

        fn notifySubscribers(self: *Self) void {
            for (self.subscriptions) |slot| {
                const subscriber = slot.subscriber orelse continue;
                subscriber.notify(self.current);
            }
        }

        fn record(self: *Self, kind: InspectionKindT, label: []const u8, status_text: []const u8) void {
            self.inspection_sequence +%= 1;
            if (self.inspection_sequence == 0) self.inspection_sequence = 1;
            const index = if (self.inspection_len < self.inspection.len)
                (self.inspection_head + self.inspection_len) % self.inspection.len
            else
                self.inspection_head;
            self.inspection[index] = .{
                .sequence = self.inspection_sequence,
                .kind = kind,
                .instance_id = self.current.instance_id,
                .revision = self.current.revision,
                .label = label,
                .status = status_text,
            };
            if (self.inspection_len < self.inspection.len) {
                self.inspection_len += 1;
            } else {
                self.inspection_head = (self.inspection_head + 1) % self.inspection.len;
            }
        }
    };
}

fn valueTagName(comptime T: type, value: T) []const u8 {
    return switch (@typeInfo(T)) {
        .@"enum" => @tagName(value),
        .@"union" => @tagName(std.meta.activeTag(value)),
        else => @typeName(T),
    };
}
