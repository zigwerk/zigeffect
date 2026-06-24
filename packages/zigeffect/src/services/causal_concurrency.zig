const std = @import("std");
const causal = @import("causal.zig");

pub const CausalConcurrencyContext = struct {
    run_id: ?u64 = null,
    scope_id: ?u64 = null,
};

pub const CausalConcurrencyRecord = struct {
    schedule_id: ?u64 = null,
    fiber_id: ?u64 = null,
    parent_id: ?u64 = null,
    cause_event_id: ?u64 = null,
    label: []const u8 = "",
};

pub const CausalConcurrencyRecorder = struct {
    store: *causal.CausalStore,
    context: CausalConcurrencyContext,

    pub fn init(store: *causal.CausalStore, context: CausalConcurrencyContext) CausalConcurrencyRecorder {
        return .{ .store = store, .context = context };
    }

    pub fn recordRaceStarted(self: *CausalConcurrencyRecorder, record: CausalConcurrencyRecord) std.mem.Allocator.Error!u64 {
        return self.appendEvent(.race_started, "started", record);
    }

    pub fn recordRaceWinner(self: *CausalConcurrencyRecorder, record: CausalConcurrencyRecord) std.mem.Allocator.Error!u64 {
        return self.appendEvent(.race_winner_selected, "winner", record);
    }

    pub fn recordRaceLoserInterrupted(self: *CausalConcurrencyRecorder, record: CausalConcurrencyRecord) std.mem.Allocator.Error!u64 {
        return self.appendEvent(.race_loser_interrupted, "interrupted", record);
    }

    pub fn recordBothStarted(self: *CausalConcurrencyRecorder, record: CausalConcurrencyRecord) std.mem.Allocator.Error!u64 {
        return self.appendEvent(.both_started, "started", record);
    }

    pub fn recordBothCompleted(self: *CausalConcurrencyRecorder, record: CausalConcurrencyRecord) std.mem.Allocator.Error!u64 {
        return self.appendEvent(.both_completed, "completed", record);
    }

    pub fn recordStmTransactionStarted(self: *CausalConcurrencyRecorder, record: CausalConcurrencyRecord) std.mem.Allocator.Error!u64 {
        return self.appendEvent(.stm_transaction_started, "started", record);
    }

    pub fn recordStmConflictDetected(self: *CausalConcurrencyRecorder, record: CausalConcurrencyRecord) std.mem.Allocator.Error!u64 {
        return self.appendEvent(.stm_conflict_detected, "conflict", record);
    }

    pub fn recordStmRetryScheduled(self: *CausalConcurrencyRecorder, record: CausalConcurrencyRecord) std.mem.Allocator.Error!u64 {
        return self.appendEvent(.stm_retry_scheduled, "retry", record);
    }

    pub fn recordStmTransactionCommitted(self: *CausalConcurrencyRecorder, record: CausalConcurrencyRecord) std.mem.Allocator.Error!u64 {
        return self.appendEvent(.stm_transaction_committed, "committed", record);
    }

    fn appendEvent(
        self: *CausalConcurrencyRecorder,
        kind: causal.CausalEventKind,
        status: []const u8,
        entry: CausalConcurrencyRecord,
    ) std.mem.Allocator.Error!u64 {
        return self.store.record(.{
            .kind = kind,
            .run_id = self.context.run_id,
            .scope_id = self.context.scope_id,
            .fiber_id = entry.fiber_id,
            .schedule_id = entry.schedule_id,
            .parent_id = entry.parent_id,
            .cause_event_id = entry.cause_event_id,
            .status = status,
            .label = entry.label,
        });
    }
};
