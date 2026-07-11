const std = @import("std");
const macrostep_mod = @import("../statechart/macrostep.zig");
const machine_mod = @import("../statechart/machine.zig");
const configuration_mod = @import("../statechart/configuration.zig");
const configuration_macrostep_mod = @import("../statechart/configuration_macrostep.zig");
const workflow_context_mod = @import("context.zig");

pub const Allocator = std.mem.Allocator;
pub const statechart_record_schema = "zigeffect.workflow.statechart-record.v1";
pub const statechart_record_schema_version: u32 = 1;
pub const max_journal_transition_ids: usize = 1024;

pub const StatechartJournalError = error{
    SequenceConflict,
    DuplicateEvent,
    DuplicateCommandOutcome,
    MissingTransition,
    InvalidCommandIndex,
    ConflictingCommandOutcome,
    DefinitionMismatch,
    TransitionLimitExceeded,
    CommandCascadeLimitExceeded,
    FutureRecordSchemaVersion,
    MissingRecordMigration,
    InvalidMigratedRecord,
    CompactionUnsupported,
};

pub fn DurableStatechart(comptime DefinitionType: type) type {
    return DurableStatechartFor(
        DefinitionType,
        machine_mod.Machine(DefinitionType),
        macrostep_mod.Macrostep(DefinitionType),
        false,
    );
}

pub fn DurableConfigurationStatechart(comptime DefinitionType: type) type {
    return DurableStatechartFor(
        DefinitionType,
        configuration_mod.ConfigurationMachine(DefinitionType),
        configuration_macrostep_mod.ConfigurationMacrostep(DefinitionType),
        true,
    );
}

fn DurableStatechartFor(
    comptime DefinitionType: type,
    comptime Runtime: type,
    comptime Macro: type,
    comptime is_configuration: bool,
) type {
    const Context = DefinitionType.ContextType;
    const Event = DefinitionType.EventType;
    const EventTag = DefinitionType.EventTag;
    const Command = DefinitionType.CommandType;

    return struct {
        const Self = @This();

        pub const RecordKind = enum {
            initialization_committed,
            transition_committed,
            checkpoint_committed,
            command_completed,
            command_failed,
        };

        pub const CommandOutcome = enum {
            completed,
            failed,
        };

        pub const JournalRecord = struct {
            schema: []const u8 = statechart_record_schema,
            schema_version: u32 = statechart_record_schema_version,
            sequence: u64,
            kind: RecordKind,
            instance_id: u64,
            event_id: u64,
            definition_fingerprint: u64,
            event_tag: ?EventTag = null,
            snapshot: ?Runtime.Snapshot = null,
            macrostep_fingerprint: u64 = 0,
            transition_storage: [max_journal_transition_ids][]const u8 = undefined,
            transition_count: usize = 0,
            command_storage: [macrostep_mod.max_macrostep_commands]Command = undefined,
            command_count: usize = 0,
            command_index: ?usize = null,
            outcome_event: ?Event = null,
            fence_epoch: u64 = 0,

            pub fn transitions(self: *const JournalRecord) []const []const u8 {
                return self.transition_storage[0..self.transition_count];
            }

            pub fn commands(self: *const JournalRecord) []const Command {
                return self.command_storage[0..self.command_count];
            }
        };

        pub const JournalBatch = struct {
            allocator: Allocator,
            records: []JournalRecord,

            pub fn deinit(self: *JournalBatch) void {
                self.allocator.free(self.records);
                self.* = undefined;
            }
        };

        pub const JournalStore = struct {
            context: *anyopaque,
            vtable: *const VTable,

            pub const VTable = struct {
                append: *const fn (context: *anyopaque, record: JournalRecord) anyerror!void,
                read_all: *const fn (context: *anyopaque, allocator: Allocator) anyerror!JournalBatch,
                compact_instance: ?*const fn (context: *anyopaque, instance_id: u64, checkpoint_sequence: u64) anyerror!void = null,
            };

            pub fn append(self: JournalStore, record: JournalRecord) anyerror!void {
                return self.vtable.append(self.context, record);
            }

            pub fn readAll(self: JournalStore, allocator: Allocator) anyerror!JournalBatch {
                return self.vtable.read_all(self.context, allocator);
            }

            pub fn compactInstance(self: JournalStore, instance_id: u64, checkpoint_sequence: u64) anyerror!void {
                const compact = self.vtable.compact_instance orelse return error.CompactionUnsupported;
                return compact(self.context, instance_id, checkpoint_sequence);
            }
        };

        pub const JournalFence = struct {
            context: *anyopaque,
            validate_fn: *const fn (context: *anyopaque) anyerror!u64,

            pub fn validate(self: JournalFence) anyerror!u64 {
                return self.validate_fn(self.context);
            }
        };

        /// Wraps any typed journal with a cluster lease fence. Validation occurs
        /// immediately before append and the accepted epoch is recorded with
        /// the commit, preventing a stale shard owner from mutating history.
        pub const FencedJournal = struct {
            base: JournalStore,
            fence: JournalFence,

            pub fn init(base: JournalStore, fence: JournalFence) FencedJournal {
                return .{ .base = base, .fence = fence };
            }

            pub fn store(self: *FencedJournal) JournalStore {
                return .{ .context = self, .vtable = &vtable };
            }

            fn appendOpaque(context: *anyopaque, input: JournalRecord) anyerror!void {
                const self: *FencedJournal = @ptrCast(@alignCast(context));
                var record = input;
                record.fence_epoch = try self.fence.validate();
                try self.base.append(record);
            }

            fn readAllOpaque(context: *anyopaque, allocator: Allocator) anyerror!JournalBatch {
                const self: *FencedJournal = @ptrCast(@alignCast(context));
                return self.base.readAll(allocator);
            }

            fn compactInstanceOpaque(context: *anyopaque, instance_id: u64, checkpoint_sequence: u64) anyerror!void {
                const self: *FencedJournal = @ptrCast(@alignCast(context));
                _ = try self.fence.validate();
                try self.base.compactInstance(instance_id, checkpoint_sequence);
            }

            const vtable = JournalStore.VTable{
                .append = appendOpaque,
                .read_all = readAllOpaque,
                .compact_instance = compactInstanceOpaque,
            };
        };

        pub const InMemoryJournal = struct {
            allocator: Allocator,
            records: std.ArrayList(JournalRecord) = .empty,

            pub fn init(allocator: Allocator) InMemoryJournal {
                return .{ .allocator = allocator };
            }

            pub fn deinit(self: *InMemoryJournal) void {
                self.records.deinit(self.allocator);
                self.* = undefined;
            }

            pub fn count(self: *const InMemoryJournal) usize {
                return self.records.items.len;
            }

            pub fn store(self: *InMemoryJournal) JournalStore {
                return .{ .context = self, .vtable = &in_memory_vtable };
            }

            fn appendOpaque(context: *anyopaque, record: JournalRecord) anyerror!void {
                const self: *InMemoryJournal = @ptrCast(@alignCast(context));
                const expected_sequence: u64 = if (self.records.items.len == 0)
                    1
                else
                    self.records.items[self.records.items.len - 1].sequence + 1;
                if (record.sequence != expected_sequence) return error.SequenceConflict;

                for (self.records.items) |existing| {
                    if (isEventCommit(record.kind) and isEventCommit(existing.kind) and
                        record.instance_id == existing.instance_id and record.event_id == existing.event_id)
                    {
                        return error.DuplicateEvent;
                    }
                    if (isCommandReceipt(record.kind) and existing.kind == record.kind and
                        record.instance_id == existing.instance_id and record.event_id == existing.event_id and
                        record.command_index == existing.command_index)
                    {
                        return error.DuplicateCommandOutcome;
                    }
                }
                try self.records.append(self.allocator, record);
            }

            fn readAllOpaque(context: *anyopaque, allocator: Allocator) anyerror!JournalBatch {
                const self: *InMemoryJournal = @ptrCast(@alignCast(context));
                const records = try allocator.alloc(JournalRecord, self.records.items.len);
                @memcpy(records, self.records.items);
                return .{ .allocator = allocator, .records = records };
            }

            fn compactInstanceOpaque(context: *anyopaque, instance_id: u64, checkpoint_sequence: u64) anyerror!void {
                const self: *InMemoryJournal = @ptrCast(@alignCast(context));
                for (self.records.items) |*record| {
                    if (record.instance_id != instance_id or record.sequence >= checkpoint_sequence) continue;
                    if (!isEventCommit(record.kind)) continue;
                    record.snapshot = null;
                    record.transition_count = 0;
                    record.command_count = 0;
                }
            }

            const in_memory_vtable = JournalStore.VTable{
                .append = appendOpaque,
                .read_all = readAllOpaque,
                .compact_instance = compactInstanceOpaque,
            };
        };

        pub const HandleStatus = enum {
            committed,
            duplicate,
        };

        pub const HandleResult = struct {
            status: HandleStatus,
            sequence: u64,
            instance_id: u64,
            event_id: u64,
            snapshot: Runtime.Snapshot,
            command_storage: [macrostep_mod.max_macrostep_commands]Command = undefined,
            command_count: usize = 0,

            pub fn commands(self: *const HandleResult) []const Command {
                return self.command_storage[0..self.command_count];
            }

            fn fromRecord(status: HandleStatus, record: JournalRecord) StatechartJournalError!HandleResult {
                const snapshot = record.snapshot orelse return error.MissingTransition;
                var result = HandleResult{
                    .status = status,
                    .sequence = record.sequence,
                    .instance_id = record.instance_id,
                    .event_id = record.event_id,
                    .snapshot = snapshot,
                    .command_count = record.command_count,
                };
                @memcpy(result.command_storage[0..record.command_count], record.commands());
                return result;
            }
        };

        pub const ReceiptStatus = enum {
            committed,
            duplicate,
        };

        pub const ReceiptResult = struct {
            status: ReceiptStatus,
            sequence: u64,
            command_id: u64,
        };

        pub const CommandExecution = union(enum) {
            completed: ?Event,
            failed: ?Event,
            suspended,
        };

        /// Capability adapter from a typed statechart command to the durable
        /// workflow context. Implementations can call activity, sleep,
        /// waitForSignal, queue, or child-workflow APIs and receive a stable
        /// command id for their idempotency key.
        pub const CommandAdapter = struct {
            context: *anyopaque,
            execute_fn: *const fn (
                context: *anyopaque,
                workflow: *workflow_context_mod.WorkflowContext,
                command_id: u64,
                command: Command,
            ) anyerror!CommandExecution,

            pub fn execute(
                self: CommandAdapter,
                workflow: *workflow_context_mod.WorkflowContext,
                command_id: u64,
                command: Command,
            ) anyerror!CommandExecution {
                return self.execute_fn(self.context, workflow, command_id, command);
            }
        };

        pub const DispatchResult = struct {
            snapshot: Runtime.Snapshot,
            commands_completed: usize = 0,
            commands_failed: usize = 0,
            commands_suspended: usize = 0,
            outcome_events: usize = 0,
            receipts_recovered: usize = 0,
        };

        allocator: Allocator,
        definition: *const DefinitionType,
        journal: JournalStore,
        migrate_record: ?*const fn (record: *JournalRecord) anyerror!void = null,

        pub fn init(allocator: Allocator, definition: *const DefinitionType, journal: JournalStore) Self {
            return .{ .allocator = allocator, .definition = definition, .journal = journal };
        }

        pub fn initWithMigration(
            allocator: Allocator,
            definition: *const DefinitionType,
            journal: JournalStore,
            migrate_record: *const fn (record: *JournalRecord) anyerror!void,
        ) Self {
            return .{
                .allocator = allocator,
                .definition = definition,
                .journal = journal,
                .migrate_record = migrate_record,
            };
        }

        pub fn handle(
            self: *Self,
            initial_context: Context,
            instance_id: u64,
            event_id: u64,
            event: Event,
        ) anyerror!HandleResult {
            var batch = try self.journal.readAll(self.allocator);
            defer batch.deinit();
            try self.normalizeRecords(batch.records);

            if (findEventRecord(batch.records, instance_id, event_id)) |existing| {
                if (existing.definition_fingerprint != self.definition.fingerprint()) return error.DefinitionMismatch;
                return self.resultFromPossiblyCompactedRecord(batch.records, .duplicate, existing);
            }

            const restored = try self.restoreFrom(batch.records, instance_id);
            if (restored == null) {
                if (comptime !is_configuration) {
                    if (Runtime.requiresInitializationEvent(self.definition)) return error.MissingInitializationEvent;
                }
            }
            const current = restored orelse if (comptime is_configuration)
                try Runtime.initial(self.definition, initial_context, instance_id)
            else
                Runtime.initial(self.definition, initial_context, instance_id);
            const result = try Macro.run(self.definition, current, event);

            var record = JournalRecord{
                .sequence = nextSequence(batch.records),
                .kind = .transition_committed,
                .instance_id = instance_id,
                .event_id = event_id,
                .definition_fingerprint = self.definition.fingerprint(),
                .event_tag = DefinitionType.eventTag(event),
                .snapshot = result.next,
                .macrostep_fingerprint = result.fingerprint,
                .command_count = result.commands().len,
            };
            try appendMacrostepTransitions(&record, &result);
            @memcpy(record.command_storage[0..record.command_count], result.commands());

            try self.journal.append(record);
            return HandleResult.fromRecord(.committed, record);
        }

        /// Idempotently journals the complete initialization macrostep,
        /// including entry/invocation commands and stabilized snapshot.
        pub fn initialize(
            self: *Self,
            initial_context: Context,
            instance_id: u64,
            initialization_id: u64,
            init_event: Event,
        ) anyerror!HandleResult {
            var batch = try self.journal.readAll(self.allocator);
            defer batch.deinit();
            try self.normalizeRecords(batch.records);

            if (findEventRecord(batch.records, instance_id, initialization_id)) |existing| {
                if (existing.definition_fingerprint != self.definition.fingerprint()) return error.DefinitionMismatch;
                return self.resultFromPossiblyCompactedRecord(batch.records, .duplicate, existing);
            }
            if (try self.restoreFrom(batch.records, instance_id) != null) return error.DuplicateEvent;

            const result = try Macro.initialize(self.definition, initial_context, instance_id, init_event);
            var record = JournalRecord{
                .sequence = nextSequence(batch.records),
                .kind = .initialization_committed,
                .instance_id = instance_id,
                .event_id = initialization_id,
                .definition_fingerprint = self.definition.fingerprint(),
                .event_tag = DefinitionType.eventTag(init_event),
                .snapshot = result.next,
                .macrostep_fingerprint = result.fingerprint,
                .command_count = result.commands().len,
            };
            try appendMacrostepTransitions(&record, &result);
            @memcpy(record.command_storage[0..record.command_count], result.commands());
            try self.journal.append(record);
            return HandleResult.fromRecord(.committed, record);
        }

        pub fn restore(self: *Self, instance_id: u64) anyerror!?Runtime.Snapshot {
            var batch = try self.journal.readAll(self.allocator);
            defer batch.deinit();
            try self.normalizeRecords(batch.records);
            return self.restoreFrom(batch.records, instance_id);
        }

        pub fn checkpointAndCompact(self: *Self, instance_id: u64, checkpoint_id: u64) anyerror!u64 {
            var batch = try self.journal.readAll(self.allocator);
            defer batch.deinit();
            try self.normalizeRecords(batch.records);
            const snapshot = try self.restoreFrom(batch.records, instance_id) orelse return error.MissingTransition;
            const sequence = nextSequence(batch.records);
            try self.journal.append(.{
                .sequence = sequence,
                .kind = .checkpoint_committed,
                .instance_id = instance_id,
                .event_id = checkpoint_id,
                .definition_fingerprint = self.definition.fingerprint(),
                .snapshot = snapshot,
            });
            try self.journal.compactInstance(instance_id, sequence);
            return sequence;
        }

        pub fn markCommand(
            self: *Self,
            instance_id: u64,
            event_id: u64,
            command_index: usize,
            outcome: CommandOutcome,
        ) anyerror!ReceiptResult {
            return self.recordCommandOutcome(instance_id, event_id, command_index, outcome, null);
        }

        pub fn recordCommandOutcome(
            self: *Self,
            instance_id: u64,
            event_id: u64,
            command_index: usize,
            outcome: CommandOutcome,
            outcome_event: ?Event,
        ) anyerror!ReceiptResult {
            var batch = try self.journal.readAll(self.allocator);
            defer batch.deinit();
            try self.normalizeRecords(batch.records);

            const transition = findEventRecord(batch.records, instance_id, event_id) orelse return error.MissingTransition;
            if (transition.definition_fingerprint != self.definition.fingerprint()) return error.DefinitionMismatch;
            if (command_index >= transition.command_count) return error.InvalidCommandIndex;
            const desired_kind: RecordKind = switch (outcome) {
                .completed => .command_completed,
                .failed => .command_failed,
            };

            for (batch.records) |existing| {
                if (existing.instance_id != instance_id or existing.event_id != event_id or existing.command_index != command_index) continue;
                if (existing.kind == desired_kind) {
                    return .{
                        .status = .duplicate,
                        .sequence = existing.sequence,
                        .command_id = commandId(instance_id, event_id, command_index),
                    };
                }
                if (existing.kind == .command_completed or existing.kind == .command_failed) {
                    return error.ConflictingCommandOutcome;
                }
            }

            const record = JournalRecord{
                .sequence = nextSequence(batch.records),
                .kind = desired_kind,
                .instance_id = instance_id,
                .event_id = event_id,
                .definition_fingerprint = self.definition.fingerprint(),
                .command_index = command_index,
                .outcome_event = outcome_event,
            };
            try self.journal.append(record);
            return .{
                .status = .committed,
                .sequence = record.sequence,
                .command_id = commandId(instance_id, event_id, command_index),
            };
        }

        /// Executes committed commands through durable workflow capabilities,
        /// journals their receipts, and feeds typed completion/failure events
        /// back into the machine. A bounded cascade prevents command/event
        /// feedback loops from escaping runtime limits.
        pub fn dispatchCommands(
            self: *Self,
            initial_context: Context,
            committed: *const HandleResult,
            workflow: *workflow_context_mod.WorkflowContext,
            adapter: CommandAdapter,
            max_cascades: usize,
        ) anyerror!DispatchResult {
            if (max_cascades == 0) return error.CommandCascadeLimitExceeded;
            var result = DispatchResult{ .snapshot = committed.snapshot };
            var remaining = max_cascades;
            try self.dispatchCommitted(initial_context, committed, workflow, adapter, &remaining, &result);
            return result;
        }

        fn dispatchCommitted(
            self: *Self,
            initial_context: Context,
            committed: *const HandleResult,
            workflow: *workflow_context_mod.WorkflowContext,
            adapter: CommandAdapter,
            remaining: *usize,
            result: *DispatchResult,
        ) anyerror!void {
            for (committed.commands(), 0..) |command, command_index| {
                if (try self.commandReceipt(committed.instance_id, committed.event_id, command_index)) |receipt| {
                    if (receipt.outcome_event) |event| {
                        if (remaining.* == 0) return error.CommandCascadeLimitExceeded;
                        remaining.* -= 1;
                        const command_id = commandId(committed.instance_id, committed.event_id, command_index);
                        const outcome: CommandOutcome = if (receipt.kind == .command_completed) .completed else .failed;
                        const handled = try self.handle(
                            initial_context,
                            committed.instance_id,
                            outcomeEventId(command_id, outcome),
                            event,
                        );
                        result.snapshot = handled.snapshot;
                        result.outcome_events += 1;
                        result.receipts_recovered += 1;
                        try self.dispatchCommitted(initial_context, &handled, workflow, adapter, remaining, result);
                    }
                    continue;
                }
                if (remaining.* == 0) return error.CommandCascadeLimitExceeded;
                remaining.* -= 1;

                const command_id = commandId(committed.instance_id, committed.event_id, command_index);
                const execution = try adapter.execute(workflow, command_id, command);
                const outcome_event: ?Event = switch (execution) {
                    .suspended => {
                        result.commands_suspended += 1;
                        continue;
                    },
                    .completed => |event| completed: {
                        _ = try self.recordCommandOutcome(committed.instance_id, committed.event_id, command_index, .completed, event);
                        result.commands_completed += 1;
                        break :completed event;
                    },
                    .failed => |event| failed: {
                        _ = try self.recordCommandOutcome(committed.instance_id, committed.event_id, command_index, .failed, event);
                        result.commands_failed += 1;
                        break :failed event;
                    },
                };

                if (outcome_event) |event| {
                    const outcome_id = outcomeEventId(command_id, switch (execution) {
                        .completed => .completed,
                        .failed => .failed,
                        .suspended => unreachable,
                    });
                    const handled = try self.handle(initial_context, committed.instance_id, outcome_id, event);
                    result.snapshot = handled.snapshot;
                    result.outcome_events += 1;
                    try self.dispatchCommitted(initial_context, &handled, workflow, adapter, remaining, result);
                }
            }
        }

        fn commandReceipt(self: *Self, instance_id: u64, event_id: u64, command_index: usize) anyerror!?JournalRecord {
            var batch = try self.journal.readAll(self.allocator);
            defer batch.deinit();
            try self.normalizeRecords(batch.records);
            for (batch.records) |record| {
                if (record.instance_id != instance_id or record.event_id != event_id or record.command_index != command_index) continue;
                if (record.kind == .command_completed or record.kind == .command_failed) return record;
            }
            return null;
        }

        fn normalizeRecords(self: *Self, records: []JournalRecord) anyerror!void {
            for (records) |*record| {
                if (record.schema_version == statechart_record_schema_version) continue;
                if (record.schema_version > statechart_record_schema_version) return error.FutureRecordSchemaVersion;
                const migrate = self.migrate_record orelse return error.MissingRecordMigration;
                try migrate(record);
                if (record.schema_version != statechart_record_schema_version or
                    !std.mem.eql(u8, record.schema, statechart_record_schema))
                {
                    return error.InvalidMigratedRecord;
                }
            }
        }

        pub fn commandId(instance_id: u64, event_id: u64, command_index: usize) u64 {
            var hasher = std.hash.Fnv1a_64.init();
            hashInt(&hasher, instance_id);
            hashInt(&hasher, event_id);
            hashInt(&hasher, command_index);
            const id = hasher.final();
            return if (id == 0) 1 else id;
        }

        pub fn outcomeEventId(command_id: u64, outcome: CommandOutcome) u64 {
            var hasher = std.hash.Fnv1a_64.init();
            hashInt(&hasher, command_id);
            hashInt(&hasher, @intFromEnum(outcome));
            const id = hasher.final();
            return if (id == 0) 1 else id;
        }

        fn restoreFrom(self: *Self, records: []const JournalRecord, instance_id: u64) StatechartJournalError!?Runtime.Snapshot {
            var latest: ?Runtime.Snapshot = null;
            var latest_sequence: u64 = 0;
            for (records) |record| {
                if (record.instance_id != instance_id or !isSnapshotCommit(record.kind)) continue;
                if (record.definition_fingerprint != self.definition.fingerprint()) return error.DefinitionMismatch;
                if (record.sequence < latest_sequence) return error.SequenceConflict;
                const committed_snapshot = record.snapshot orelse continue;
                latest = committed_snapshot;
                latest_sequence = record.sequence;
            }
            return latest;
        }

        fn resultFromPossiblyCompactedRecord(
            self: *Self,
            records: []const JournalRecord,
            status: HandleStatus,
            record: JournalRecord,
        ) StatechartJournalError!HandleResult {
            if (record.snapshot != null) return HandleResult.fromRecord(status, record);
            const latest = try self.restoreFrom(records, record.instance_id) orelse return error.MissingTransition;
            var compacted = record;
            compacted.snapshot = latest;
            compacted.command_count = 0;
            compacted.transition_count = 0;
            return HandleResult.fromRecord(status, compacted);
        }

        fn findEventRecord(records: []const JournalRecord, instance_id: u64, event_id: u64) ?JournalRecord {
            for (records) |record| {
                if (isEventCommit(record.kind) and record.instance_id == instance_id and record.event_id == event_id) {
                    return record;
                }
            }
            return null;
        }

        fn isEventCommit(kind: RecordKind) bool {
            return kind == .initialization_committed or kind == .transition_committed;
        }

        fn isSnapshotCommit(kind: RecordKind) bool {
            return isEventCommit(kind) or kind == .checkpoint_committed;
        }

        fn isCommandReceipt(kind: RecordKind) bool {
            return kind == .command_completed or kind == .command_failed;
        }

        fn appendMacrostepTransitions(record: *JournalRecord, result: *const Macro.Result) StatechartJournalError!void {
            for (result.microsteps()) |microstep| {
                if (comptime is_configuration) {
                    for (microstep.transitionIds()) |transition_id| {
                        if (record.transition_count >= record.transition_storage.len) return error.TransitionLimitExceeded;
                        record.transition_storage[record.transition_count] = transition_id;
                        record.transition_count += 1;
                    }
                } else {
                    if (record.transition_count >= record.transition_storage.len) return error.TransitionLimitExceeded;
                    record.transition_storage[record.transition_count] = microstep.transition_id;
                    record.transition_count += 1;
                }
            }
        }

        fn nextSequence(records: []const JournalRecord) u64 {
            if (records.len == 0) return 1;
            return records[records.len - 1].sequence + 1;
        }
    };
}

fn hashInt(hasher: *std.hash.Fnv1a_64, value: anytype) void {
    var widened: u64 = @intCast(value);
    hasher.update(std.mem.asBytes(&widened));
}
