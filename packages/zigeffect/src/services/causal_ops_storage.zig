const std = @import("std");
const causal = @import("causal.zig");
const causal_nendb_storage_backend = @import("causal_nendb_storage_backend.zig");
const causal_ops = @import("causal_ops.zig");

pub const Allocator = std.mem.Allocator;
pub const CausalSnapshot = causal.CausalSnapshot;
pub const CausalStore = causal.CausalStore;
pub const CausalNendbStorageBackendState = causal_nendb_storage_backend.CausalNendbStorageBackendState;
pub const CausalOpsPolicy = causal_ops.CausalOpsPolicy;
pub const CausalOpsReadRequest = causal_ops.CausalOpsReadRequest;
pub const CausalOpsRetentionDecision = causal_ops.CausalOpsRetentionDecision;

pub const CausalOpsArtifactReadResult = struct {
    allowed: bool,
    reason: []const u8,
    snapshot: ?CausalSnapshot = null,

    pub fn deinit(self: *CausalOpsArtifactReadResult) void {
        if (self.snapshot) |*snapshot| {
            snapshot.deinit();
        }
        self.* = .{
            .allowed = false,
            .reason = "",
        };
    }
};

pub fn readCausalOpsArtifact(
    allocator: Allocator,
    storage: *const CausalNendbStorageBackendState,
    policy: CausalOpsPolicy,
    request: CausalOpsReadRequest,
) Allocator.Error!CausalOpsArtifactReadResult {
    if (!policy.canRead(request)) {
        return .{
            .allowed = false,
            .reason = "access denied",
        };
    }

    const snapshot = if (request.scope_id) |scope_id|
        try storage.eventsByScope(allocator, scope_id)
    else
        try storage.snapshot(allocator);

    return .{
        .allowed = true,
        .reason = "access granted",
        .snapshot = snapshot,
    };
}

pub fn checkCausalOpsStorageRetention(
    policy: CausalOpsPolicy,
    alert_store: *CausalStore,
    storage: *const CausalNendbStorageBackendState,
    dropped_events: usize,
) Allocator.Error!CausalOpsRetentionDecision {
    return policy.checkRetentionAndAlert(alert_store, .{
        .current_events = storage.eventCount(),
        .dropped_events = dropped_events,
    });
}
