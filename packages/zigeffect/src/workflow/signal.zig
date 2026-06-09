const std = @import("std");
const journal_mod = @import("journal.zig");
const store_mod = @import("store.zig");

pub const Allocator = std.mem.Allocator;
pub const ExecutionId = journal_mod.ExecutionId;
pub const JournalSequence = journal_mod.JournalSequence;
pub const JournalStore = store_mod.JournalStore;
pub const WorkflowId = journal_mod.WorkflowId;

pub const SignalMetadata = struct {
    name: []const u8,
    payload_type_name: []const u8,
    timeout_ms: ?u64,
};

pub fn SignalWaitResult(comptime Payload: type) type {
    return union(enum) {
        received: Payload,
        timed_out,
        suspended: @import("../runtime/control.zig").Suspension,
    };
}

fn SignalDefinition(
    comptime Name: []const u8,
    comptime Payload: type,
    comptime TimeoutMs: ?u64,
) type {
    return struct {
        pub const name = Name;
        pub const PayloadType = Payload;

        pub fn metadata() SignalMetadata {
            return .{
                .name = Name,
                .payload_type_name = @typeName(Payload),
                .timeout_ms = TimeoutMs,
            };
        }

        pub fn withTimeoutMs(comptime timeout_ms: u64) type {
            return SignalDefinition(Name, Payload, timeout_ms);
        }
    };
}

pub fn Signal(comptime Name: []const u8, comptime Payload: type) type {
    return SignalDefinition(Name, Payload, null);
}

pub const DurableSignal = struct {
    allocator: Allocator,
    journal_store: JournalStore,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,

    pub fn init(
        allocator: Allocator,
        journal_store: JournalStore,
        workflow_id: WorkflowId,
        execution_id: ExecutionId,
    ) DurableSignal {
        return .{
            .allocator = allocator,
            .journal_store = journal_store,
            .workflow_id = workflow_id,
            .execution_id = execution_id,
        };
    }

    pub fn send(
        self: *DurableSignal,
        comptime SignalType: type,
        payload_codec: anytype,
        payload: SignalType.PayloadType,
        external_idempotency_key: []const u8,
    ) !bool {
        var events = try self.journal_store.readAll(self.allocator);
        defer events.deinit();

        const encoded = try payload_codec.encodeValue(self.allocator, payload);
        defer self.allocator.free(encoded);

        var next_sequence_value = try nextSequence(events.events);
        const appended = try appendSignalEvent(
            self,
            .signal_received,
            SignalType.name,
            "received",
            encoded,
            external_idempotency_key,
            &next_sequence_value,
        );
        if (!appended) return false;

        if (workflowIsSuspended(events.events, self.workflow_id, self.execution_id)) {
            _ = try appendSignalEvent(
                self,
                .workflow_resumed,
                SignalType.name,
                "running",
                "signal",
                "",
                &next_sequence_value,
            );
        }
        return true;
    }
};

pub fn signalId(name: []const u8) u64 {
    return std.hash.Fnv1a_64.hash(name);
}

fn nextSequence(events: []const journal_mod.WorkflowEvent) store_mod.JournalStoreError!JournalSequence {
    if (events.len == 0) return 1;
    const latest = events[events.len - 1].sequence;
    if (latest == std.math.maxInt(JournalSequence)) return error.SequenceOverflow;
    return latest + 1;
}

fn advanceSequence(sequence: *JournalSequence) store_mod.JournalStoreError!void {
    if (sequence.* == std.math.maxInt(JournalSequence)) return error.SequenceOverflow;
    sequence.* += 1;
}

fn appendSignalEvent(
    self: *DurableSignal,
    kind: journal_mod.WorkflowEventKind,
    name: []const u8,
    status: []const u8,
    redacted_detail: []const u8,
    external_idempotency_key: []const u8,
    next_sequence_value: *JournalSequence,
) !bool {
    const idempotency_key = try signalEventIdempotencyKey(
        self.allocator,
        kind,
        name,
        external_idempotency_key,
        next_sequence_value.*,
    );
    defer self.allocator.free(idempotency_key);

    _ = self.journal_store.append(.{
        .expected_next_sequence = next_sequence_value.*,
        .event = .{
            .sequence = next_sequence_value.*,
            .kind = kind,
            .workflow_id = self.workflow_id,
            .execution_id = self.execution_id,
            .name = name,
            .status = status,
            .redacted_detail = redacted_detail,
            .idempotency_key = idempotency_key,
        },
    }) catch |err| switch (err) {
        error.DuplicateEvent => return false,
        else => return err,
    };
    try advanceSequence(next_sequence_value);
    return true;
}

fn signalEventIdempotencyKey(
    allocator: Allocator,
    kind: journal_mod.WorkflowEventKind,
    name: []const u8,
    external_idempotency_key: []const u8,
    sequence: JournalSequence,
) Allocator.Error![]const u8 {
    if (kind == .signal_received) {
        return std.fmt.allocPrint(
            allocator,
            "signal:{s}:received:{s}",
            .{ name, external_idempotency_key },
        );
    }
    return std.fmt.allocPrint(
        allocator,
        "signal:{s}:{s}:{d}",
        .{ name, journal_mod.workflowEventKindName(kind), sequence },
    );
}

fn workflowIsSuspended(
    events: []const journal_mod.WorkflowEvent,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
) bool {
    var suspended = false;
    for (events) |event| {
        if (event.workflow_id != workflow_id or event.execution_id != execution_id) continue;
        switch (event.kind) {
            .workflow_started, .workflow_resumed => suspended = false,
            .workflow_suspended => suspended = true,
            .workflow_completed,
            .workflow_failed,
            .workflow_interrupted,
            .workflow_cancelled,
            => suspended = false,
            else => {},
        }
    }
    return suspended;
}
