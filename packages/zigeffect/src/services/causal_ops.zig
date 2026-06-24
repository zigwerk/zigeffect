const std = @import("std");
const causal = @import("causal.zig");

pub const CausalDeploymentMetadata = struct {
    service: []const u8 = "",
    environment: []const u8 = "",
    region: []const u8 = "",
    cluster_id: []const u8 = "",

    pub fn valid(self: CausalDeploymentMetadata) bool {
        return self.service.len > 0 and self.environment.len > 0 and self.region.len > 0 and self.cluster_id.len > 0;
    }
};

pub const CausalOpsAccessPolicy = struct {
    actor_id: []const u8 = "",
    allowed_scope_id: ?u64 = null,
};

pub const CausalOpsReadRequest = struct {
    actor_id: []const u8,
    scope_id: ?u64 = null,
};

pub const CausalOpsRetentionPolicy = struct {
    max_events: usize = 0,
    alert_threshold: usize = 0,
};

pub const CausalOpsRetentionInput = struct {
    current_events: usize,
    dropped_events: usize = 0,
};

pub const CausalOpsRetentionAction = enum {
    keep,
    trim,
};

pub const CausalOpsRetentionDecision = struct {
    action: CausalOpsRetentionAction,
    alert_emitted: bool = false,
};

pub const CausalOpsPolicy = struct {
    deployment: CausalDeploymentMetadata = .{},
    access: CausalOpsAccessPolicy = .{},
    retention: CausalOpsRetentionPolicy = .{},

    pub fn canRead(self: CausalOpsPolicy, request: CausalOpsReadRequest) bool {
        if (!self.deployment.valid()) return false;
        if (self.access.actor_id.len > 0 and !std.mem.eql(u8, self.access.actor_id, request.actor_id)) return false;
        if (self.access.allowed_scope_id) |scope_id| {
            if (request.scope_id != scope_id) return false;
        }
        return true;
    }

    pub fn checkRetentionAndAlert(
        self: CausalOpsPolicy,
        store: *causal.CausalStore,
        input: CausalOpsRetentionInput,
    ) std.mem.Allocator.Error!CausalOpsRetentionDecision {
        const action: CausalOpsRetentionAction = if (self.retention.max_events > 0 and input.current_events > self.retention.max_events)
            .trim
        else
            .keep;
        const should_alert = self.retention.alert_threshold > 0 and input.dropped_events >= self.retention.alert_threshold;
        if (should_alert) {
            _ = try store.record(.{
                .kind = .alert_emitted,
                .status = "emitted",
                .label = "causal retention threshold breached",
                .type_name = "retention.threshold",
                .redacted_detail = self.deployment.cluster_id,
            });
        }
        return .{ .action = action, .alert_emitted = should_alert };
    }
};
