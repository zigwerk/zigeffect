const std = @import("std");
const journal = @import("journal.zig");
const replay = @import("replay.zig");

const Allocator = std.mem.Allocator;

pub const WorkflowEvent = journal.WorkflowEvent;
pub const JournalSequence = journal.JournalSequence;
pub const WorkflowReplayState = replay.WorkflowReplayState;

pub const JournalStoreError = error{
    SequenceConflict,
    DuplicateEvent,
    SequenceOverflow,
};

pub const JournalStoreAppendError = Allocator.Error || JournalStoreError;
pub const JournalStoreReadError = Allocator.Error;
pub const JournalStoreReplayError = Allocator.Error || JournalStoreError || replay.ReplayError;

pub const JournalAppend = struct {
    expected_next_sequence: ?JournalSequence = null,
    event: WorkflowEvent,
};

pub const JournalEventBatch = struct {
    allocator: Allocator,
    events: []WorkflowEvent,

    pub fn deinit(self: *JournalEventBatch) void {
        for (self.events) |event| {
            journal.deinitWorkflowEventStrings(self.allocator, event);
        }
        self.allocator.free(self.events);
    }
};

pub const JournalStore = struct {
    context: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        append: *const fn (*anyopaque, JournalAppend) JournalStoreAppendError!JournalSequence,
        read_all: *const fn (*anyopaque, Allocator) JournalStoreReadError!JournalEventBatch,
        read_from_sequence: *const fn (*anyopaque, Allocator, JournalSequence) JournalStoreReadError!JournalEventBatch,
        latest_state: *const fn (*anyopaque, Allocator) JournalStoreReplayError!WorkflowReplayState,
        reset: *const fn (*anyopaque) void,
    };

    pub fn append(self: JournalStore, request: JournalAppend) JournalStoreAppendError!JournalSequence {
        return self.vtable.append(self.context, request);
    }

    pub fn readAll(self: JournalStore, allocator: Allocator) JournalStoreReadError!JournalEventBatch {
        return self.vtable.read_all(self.context, allocator);
    }

    pub fn readFromSequence(self: JournalStore, allocator: Allocator, sequence: JournalSequence) JournalStoreReadError!JournalEventBatch {
        return self.vtable.read_from_sequence(self.context, allocator, sequence);
    }

    pub fn latestState(self: JournalStore, allocator: Allocator) JournalStoreReplayError!WorkflowReplayState {
        return self.vtable.latest_state(self.context, allocator);
    }

    pub fn reset(self: JournalStore) void {
        self.vtable.reset(self.context);
    }
};

pub const InMemoryJournalStore = struct {
    allocator: Allocator,
    events: std.ArrayList(WorkflowEvent) = .empty,

    pub fn init(allocator: Allocator) InMemoryJournalStore {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *InMemoryJournalStore) void {
        self.reset();
        self.events.deinit(self.allocator);
    }

    pub fn asJournalStore(self: *InMemoryJournalStore) JournalStore {
        return .{
            .context = self,
            .vtable = &in_memory_vtable,
        };
    }

    pub fn append(self: *InMemoryJournalStore, request: JournalAppend) JournalStoreAppendError!JournalSequence {
        const next_sequence = try self.nextSequence();
        if (request.expected_next_sequence) |expected| {
            if (expected != next_sequence) return error.SequenceConflict;
        }
        if (request.event.sequence != next_sequence) return error.SequenceConflict;
        if (self.hasIdempotencyKey(request.event.idempotency_key)) return error.DuplicateEvent;

        const owned = try journal.cloneWorkflowEvent(self.allocator, request.event);
        errdefer journal.deinitWorkflowEventStrings(self.allocator, owned);
        try self.events.append(self.allocator, owned);

        return owned.sequence;
    }

    pub fn readAll(self: *const InMemoryJournalStore, allocator: Allocator) JournalStoreReadError!JournalEventBatch {
        return self.readFromSequence(allocator, 1);
    }

    pub fn readFromSequence(self: *const InMemoryJournalStore, allocator: Allocator, sequence: JournalSequence) JournalStoreReadError!JournalEventBatch {
        var output = std.ArrayList(WorkflowEvent).empty;
        errdefer {
            for (output.items) |event| {
                journal.deinitWorkflowEventStrings(allocator, event);
            }
            output.deinit(allocator);
        }

        for (self.events.items) |event| {
            if (event.sequence >= sequence) {
                {
                    const cloned = try journal.cloneWorkflowEvent(allocator, event);
                    errdefer journal.deinitWorkflowEventStrings(allocator, cloned);
                    try output.append(allocator, cloned);
                }
            }
        }

        return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
    }

    pub fn latestState(self: *const InMemoryJournalStore, allocator: Allocator) JournalStoreReplayError!WorkflowReplayState {
        var events = try self.readAll(allocator);
        defer events.deinit();
        return WorkflowReplayState.fold(allocator, events.events);
    }

    pub fn reset(self: *InMemoryJournalStore) void {
        for (self.events.items) |event| {
            journal.deinitWorkflowEventStrings(self.allocator, event);
        }
        self.events.clearRetainingCapacity();
    }

    fn nextSequence(self: *const InMemoryJournalStore) JournalStoreError!JournalSequence {
        if (self.events.items.len == 0) return 1;
        const latest = self.events.items[self.events.items.len - 1].sequence;
        if (latest == std.math.maxInt(JournalSequence)) return error.SequenceOverflow;
        return latest + 1;
    }

    fn hasIdempotencyKey(self: *const InMemoryJournalStore, key: []const u8) bool {
        if (key.len == 0) return false;
        for (self.events.items) |event| {
            if (std.mem.eql(u8, event.idempotency_key, key)) return true;
        }
        return false;
    }

    fn appendAdapter(context: *anyopaque, request: JournalAppend) JournalStoreAppendError!JournalSequence {
        const self: *InMemoryJournalStore = @ptrCast(@alignCast(context));
        return self.append(request);
    }

    fn readAllAdapter(context: *anyopaque, allocator: Allocator) JournalStoreReadError!JournalEventBatch {
        const self: *InMemoryJournalStore = @ptrCast(@alignCast(context));
        return self.readAll(allocator);
    }

    fn readFromSequenceAdapter(context: *anyopaque, allocator: Allocator, sequence: JournalSequence) JournalStoreReadError!JournalEventBatch {
        const self: *InMemoryJournalStore = @ptrCast(@alignCast(context));
        return self.readFromSequence(allocator, sequence);
    }

    fn latestStateAdapter(context: *anyopaque, allocator: Allocator) JournalStoreReplayError!WorkflowReplayState {
        const self: *InMemoryJournalStore = @ptrCast(@alignCast(context));
        return self.latestState(allocator);
    }

    fn resetAdapter(context: *anyopaque) void {
        const self: *InMemoryJournalStore = @ptrCast(@alignCast(context));
        self.reset();
    }
};

const in_memory_vtable: JournalStore.VTable = .{
    .append = InMemoryJournalStore.appendAdapter,
    .read_all = InMemoryJournalStore.readAllAdapter,
    .read_from_sequence = InMemoryJournalStore.readFromSequenceAdapter,
    .latest_state = InMemoryJournalStore.latestStateAdapter,
    .reset = InMemoryJournalStore.resetAdapter,
};
