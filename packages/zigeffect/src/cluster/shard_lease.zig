const std = @import("std");
const causal_mod = @import("../services/causal.zig");
const fencing = @import("fencing.zig");
const runner = @import("runner.zig");
const runner_storage = @import("runner_storage.zig");

pub const Allocator = std.mem.Allocator;
pub const RunnerAddress = runner.RunnerAddress;
pub const ShardId = runner_storage.ShardId;
pub const RunnerStorage = runner_storage.RunnerStorage;
pub const RunnerLeaseTtlMs = runner_storage.RunnerLeaseTtlMs;
pub const ShardLease = runner_storage.ShardLease;
pub const ShardLeaseFence = fencing.ShardLeaseFence;
pub const RunnerLeaseBatch = runner_storage.RunnerLeaseBatch;

pub const ShardLeaseManagerError = error{
    InvalidLeaseOptions,
    ShardAlreadyOwned,
    ShardNotOwned,
    RunnerStillAlive,
};

pub const ShardLeaseManagerOptions = struct {
    ttl_ms: RunnerLeaseTtlMs,
    refresh_interval_ms: u64,
    renewal_jitter_ms: u64 = 0,
    renewal_deadline_ms: u64 = 0,
    clock_skew_tolerance_ms: u64 = 0,
};

pub const ShardLeaseRefreshReport = struct {
    refreshed: usize = 0,
    reacquired: usize = 0,
    expired: usize = 0,
    conflicts: usize = 0,
};

pub const ShardLeaseRecoveryReport = struct {
    dead_runner: RunnerAddress,
    recovered_by: RunnerAddress,
    released: usize,
    at_ms: u64,
};

pub const ShardHandoffReport = struct {
    shard_id: ShardId,
    from: RunnerAddress,
    to: RunnerAddress,
    released_at_ms: u64,
};

pub const ShardLeaseAuditStatus = enum {
    valid,
    refresh_due,
    renewal_deadline_missed,
    expired,
    missing,
    stale_owner,
    stale_epoch,
};

pub const ShardLeaseAuditEntry = struct {
    shard_id: ShardId,
    local_owner: RunnerAddress,
    local_epoch: runner_storage.ShardLeaseEpoch,
    current_owner: ?RunnerAddress = null,
    current_epoch: ?runner_storage.ShardLeaseEpoch = null,
    expires_at_ms: u64 = 0,
    status: ShardLeaseAuditStatus,
};

pub const ShardLeaseAuditReport = struct {
    allocator: ?Allocator = null,
    entries: []ShardLeaseAuditEntry = &.{},
    scanned: usize = 0,
    valid: usize = 0,
    refresh_due: usize = 0,
    renewal_deadline_missed: usize = 0,
    expired: usize = 0,
    missing: usize = 0,
    stale_owner: usize = 0,
    stale_epoch: usize = 0,

    pub fn deinit(self: *ShardLeaseAuditReport) void {
        const report_allocator = self.allocator orelse return;
        report_allocator.free(self.entries);
        self.* = .{};
    }
};

pub const ShardLeaseForceReleaseReport = struct {
    shard_id: ShardId,
    released_owner: RunnerAddress,
    released_epoch: runner_storage.ShardLeaseEpoch,
    released_at_ms: u64,
};

pub const LocalShardLeaseManager = struct {
    allocator: Allocator,
    storage: RunnerStorage,
    owner: RunnerAddress,
    options: ShardLeaseManagerOptions,
    owned_leases: std.ArrayList(ShardLease) = .empty,
    causal_store: ?*causal_mod.CausalStore = null,
    causal_run_id: ?u64 = null,

    pub fn init(allocator: Allocator, storage: RunnerStorage, owner: RunnerAddress, options: ShardLeaseManagerOptions) ShardLeaseManagerError!LocalShardLeaseManager {
        try validateOptions(options);
        return .{
            .allocator = allocator,
            .storage = storage,
            .owner = owner,
            .options = options,
        };
    }

    pub fn deinit(self: *LocalShardLeaseManager) void {
        self.owned_leases.deinit(self.allocator);
    }

    pub fn attachCausalStore(self: *LocalShardLeaseManager, store: *causal_mod.CausalStore, run_id: u64) void {
        self.causal_store = store;
        self.causal_run_id = run_id;
    }

    pub fn acquireShard(self: *LocalShardLeaseManager, shard_id: ShardId, now_ms: u64) !ShardLease {
        if (self.findOwnedIndex(shard_id) != null) return error.ShardAlreadyOwned;
        const lease = self.storage.acquire(.{
            .shard_id = shard_id,
            .owner = self.owner,
            .now_ms = now_ms,
            .ttl_ms = self.options.ttl_ms,
        }) catch |err| switch (err) {
            error.LeaseConflict => {
                try self.recordConflict(shard_id, now_ms);
                return err;
            },
            else => return err,
        };
        try self.owned_leases.append(self.allocator, lease);
        try self.recordLeaseCausal(.cluster_shard_lease_acquired, lease, "acquired");
        return lease;
    }

    pub fn refreshOwnedLeases(self: *LocalShardLeaseManager, now_ms: u64) !ShardLeaseRefreshReport {
        var report = ShardLeaseRefreshReport{};
        var index: usize = 0;
        while (index < self.owned_leases.items.len) {
            const current = self.owned_leases.items[index];
            if (!shardLeaseRefreshDue(current, self.options, now_ms)) {
                index += 1;
                continue;
            }

            const refreshed = self.storage.refresh(.{
                .shard_id = current.shard_id,
                .owner = self.owner,
                .now_ms = now_ms,
                .ttl_ms = self.options.ttl_ms,
            }) catch |err| switch (err) {
                error.LeaseExpired => {
                    report.expired += 1;
                    const reacquired = self.storage.acquire(.{
                        .shard_id = current.shard_id,
                        .owner = self.owner,
                        .now_ms = now_ms,
                        .ttl_ms = self.options.ttl_ms,
                    }) catch |acquire_err| switch (acquire_err) {
                        error.LeaseConflict => {
                            _ = self.owned_leases.orderedRemove(index);
                            report.conflicts += 1;
                            try self.recordConflict(current.shard_id, now_ms);
                            continue;
                        },
                        else => return acquire_err,
                    };
                    self.owned_leases.items[index] = reacquired;
                    report.reacquired += 1;
                    try self.recordLeaseCausal(.cluster_shard_lease_acquired, reacquired, "acquired");
                    index += 1;
                    continue;
                },
                else => return err,
            };

            self.owned_leases.items[index] = refreshed;
            report.refreshed += 1;
            try self.recordLeaseCausal(.cluster_shard_lease_refreshed, refreshed, "refreshed");
            index += 1;
        }
        return report;
    }

    pub fn releaseShard(self: *LocalShardLeaseManager, shard_id: ShardId, now_ms: u64) !void {
        const index = self.findOwnedIndex(shard_id) orelse return error.ShardNotOwned;
        const lease = self.owned_leases.items[index];
        try self.storage.release(.{
            .shard_id = shard_id,
            .owner = self.owner,
        });
        _ = self.owned_leases.orderedRemove(index);
        try self.recordLeaseCausal(.cluster_shard_lease_released, lease, "released");
        _ = now_ms;
    }

    pub fn handoffShard(self: *LocalShardLeaseManager, shard_id: ShardId, target: RunnerAddress, now_ms: u64) !ShardHandoffReport {
        const index = self.findOwnedIndex(shard_id) orelse return error.ShardNotOwned;
        const lease = self.owned_leases.items[index];
        try self.recordHandoffCausal(lease, target, now_ms);
        try self.releaseShard(shard_id, now_ms);
        return .{
            .shard_id = shard_id,
            .from = self.owner,
            .to = target,
            .released_at_ms = now_ms,
        };
    }

    pub fn recoverDeadRunner(
        self: *LocalShardLeaseManager,
        registry: *runner.LocalRunnerRegistry,
        inspector: *const runner.LocalRunnerHealthInspector,
        dead_runner: RunnerAddress,
        now_ms: u64,
    ) !ShardLeaseRecoveryReport {
        const snapshot = try inspector.inspectRunner(registry, dead_runner, now_ms);
        switch (snapshot.state) {
            .unhealthy, .stopped => {},
            .starting, .healthy, .degraded => return error.RunnerStillAlive,
        }

        try self.recordRecoveryCausal(.cluster_shard_recovery_started, dead_runner, now_ms, 0, "recovery_started");
        const released = try self.storage.releaseAll(dead_runner);
        try self.recordRecoveryCausal(.cluster_shard_recovery_completed, dead_runner, now_ms, released, "recovery_completed");
        return .{
            .dead_runner = dead_runner,
            .recovered_by = self.owner,
            .released = released,
            .at_ms = now_ms,
        };
    }

    pub fn ownsShard(self: *const LocalShardLeaseManager, shard_id: ShardId) bool {
        return self.findOwnedIndex(shard_id) != null;
    }

    pub fn ownedLeases(self: *const LocalShardLeaseManager, allocator: Allocator) Allocator.Error!RunnerLeaseBatch {
        const copied = try allocator.dupe(ShardLease, self.owned_leases.items);
        return .{
            .allocator = allocator,
            .leases = copied,
        };
    }

    pub fn auditOwnedLeases(self: *LocalShardLeaseManager, allocator: Allocator, now_ms: u64) !ShardLeaseAuditReport {
        var entries: std.ArrayList(ShardLeaseAuditEntry) = .empty;
        errdefer entries.deinit(allocator);

        var report = ShardLeaseAuditReport{
            .allocator = allocator,
            .scanned = self.owned_leases.items.len,
        };

        for (self.owned_leases.items) |local| {
            const current = try self.storage.lease(local.shard_id);
            const entry = auditEntry(local, current, self.options, now_ms);
            countAuditEntry(&report, entry.status);
            try entries.append(allocator, entry);
        }

        report.entries = try entries.toOwnedSlice(allocator);
        return report;
    }

    pub fn forceReleaseStaleShard(self: *LocalShardLeaseManager, shard_id: ShardId, now_ms: u64) !ShardLeaseForceReleaseReport {
        const current = (try self.storage.lease(shard_id)) orelse return error.LeaseNotFound;
        if (!shardLeaseExpiredForRecovery(current, self.options, now_ms)) return error.RunnerStillAlive;
        try self.storage.release(.{
            .shard_id = shard_id,
            .owner = current.owner,
        });
        return .{
            .shard_id = shard_id,
            .released_owner = current.owner,
            .released_epoch = current.epoch,
            .released_at_ms = now_ms,
        };
    }

    pub fn fenceForShard(self: *const LocalShardLeaseManager, shard_id: ShardId) !ShardLeaseFence {
        const index = self.findOwnedIndex(shard_id) orelse return error.ShardNotOwned;
        return fencing.fenceFromLease(self.owned_leases.items[index]);
    }

    fn findOwnedIndex(self: *const LocalShardLeaseManager, shard_id: ShardId) ?usize {
        for (self.owned_leases.items, 0..) |lease, index| {
            if (lease.shard_id == shard_id) return index;
        }
        return null;
    }

    fn recordConflict(self: *LocalShardLeaseManager, shard_id: ShardId, now_ms: u64) Allocator.Error!void {
        const store = self.causal_store orelse return;
        const label = try std.fmt.allocPrint(self.allocator, "shard-{d}", .{shard_id});
        defer self.allocator.free(label);
        const detail = try std.fmt.allocPrint(
            self.allocator,
            "shard_id={d} owner_machine_id={d} owner_runner_id={d} at_ms={d}",
            .{ shard_id, self.owner.machine_id, self.owner.runner_id, now_ms },
        );
        defer self.allocator.free(detail);
        _ = try store.record(.{
            .kind = .cluster_shard_lease_conflict,
            .run_id = self.causal_run_id,
            .label = label,
            .type_name = "cluster.shard_lease",
            .status = "conflict",
            .redacted_detail = detail,
        });
    }

    fn recordLeaseCausal(self: *LocalShardLeaseManager, kind: causal_mod.CausalEventKind, lease: ShardLease, status: []const u8) Allocator.Error!void {
        const store = self.causal_store orelse return;
        const label = try std.fmt.allocPrint(self.allocator, "shard-{d}", .{lease.shard_id});
        defer self.allocator.free(label);
        const detail = try std.fmt.allocPrint(
            self.allocator,
            "shard_id={d} owner_machine_id={d} owner_runner_id={d} version={d} expires_at_ms={d}",
            .{ lease.shard_id, lease.owner.machine_id, lease.owner.runner_id, lease.version, lease.expires_at_ms },
        );
        defer self.allocator.free(detail);
        _ = try store.record(.{
            .kind = kind,
            .run_id = self.causal_run_id,
            .label = label,
            .type_name = "cluster.shard_lease",
            .status = status,
            .redacted_detail = detail,
        });
    }

    fn recordHandoffCausal(self: *LocalShardLeaseManager, lease: ShardLease, target: RunnerAddress, now_ms: u64) Allocator.Error!void {
        const store = self.causal_store orelse return;
        const label = try std.fmt.allocPrint(self.allocator, "shard-{d}", .{lease.shard_id});
        defer self.allocator.free(label);
        const detail = try std.fmt.allocPrint(
            self.allocator,
            "shard_id={d} from_machine_id={d} from_runner_id={d} to_machine_id={d} to_runner_id={d} at_ms={d}",
            .{ lease.shard_id, self.owner.machine_id, self.owner.runner_id, target.machine_id, target.runner_id, now_ms },
        );
        defer self.allocator.free(detail);
        _ = try store.record(.{
            .kind = .cluster_shard_handoff_started,
            .run_id = self.causal_run_id,
            .label = label,
            .type_name = "cluster.shard_lease",
            .status = "handoff_started",
            .redacted_detail = detail,
        });
    }

    fn recordRecoveryCausal(self: *LocalShardLeaseManager, kind: causal_mod.CausalEventKind, dead_runner: RunnerAddress, now_ms: u64, released: usize, status: []const u8) Allocator.Error!void {
        const store = self.causal_store orelse return;
        const detail = try std.fmt.allocPrint(
            self.allocator,
            "dead_machine_id={d} dead_runner_id={d} recovered_by_machine_id={d} recovered_by_runner_id={d} released={d} at_ms={d}",
            .{ dead_runner.machine_id, dead_runner.runner_id, self.owner.machine_id, self.owner.runner_id, released, now_ms },
        );
        defer self.allocator.free(detail);
        _ = try store.record(.{
            .kind = kind,
            .run_id = self.causal_run_id,
            .label = "runner-recovery",
            .type_name = "cluster.shard_lease",
            .status = status,
            .redacted_detail = detail,
        });
    }
};

pub fn shardLeaseNextRefreshAt(lease: ShardLease, options: ShardLeaseManagerOptions) u64 {
    return lease.refreshed_at_ms +| options.refresh_interval_ms +| shardLeaseRenewalJitterMs(lease, options);
}

pub fn shardLeaseRefreshDue(lease: ShardLease, options: ShardLeaseManagerOptions, now_ms: u64) bool {
    return now_ms >= shardLeaseNextRefreshAt(lease, options);
}

pub fn shardLeaseRenewalJitterMs(lease: ShardLease, options: ShardLeaseManagerOptions) u64 {
    if (options.renewal_jitter_ms == 0) return 0;
    const width = options.renewal_jitter_ms +| 1;
    return (lease.shard_id ^ lease.epoch) % width;
}

pub fn shardLeaseRenewalDeadlineAt(lease: ShardLease, options: ShardLeaseManagerOptions) u64 {
    return lease.refreshed_at_ms +| effectiveRenewalDeadlineMs(options);
}

pub fn shardLeaseExpiredForRecovery(lease: ShardLease, options: ShardLeaseManagerOptions, now_ms: u64) bool {
    return lease.expires_at_ms +| options.clock_skew_tolerance_ms <= now_ms;
}

fn validateOptions(options: ShardLeaseManagerOptions) ShardLeaseManagerError!void {
    if (options.ttl_ms == 0) return error.InvalidLeaseOptions;
    if (options.refresh_interval_ms == 0) return error.InvalidLeaseOptions;
    if (options.refresh_interval_ms >= options.ttl_ms) return error.InvalidLeaseOptions;
    const deadline = effectiveRenewalDeadlineMs(options);
    if (deadline > options.ttl_ms) return error.InvalidLeaseOptions;
    if (deadline <= options.refresh_interval_ms) return error.InvalidLeaseOptions;
    if (options.refresh_interval_ms +| options.renewal_jitter_ms >= deadline) return error.InvalidLeaseOptions;
}

fn effectiveRenewalDeadlineMs(options: ShardLeaseManagerOptions) u64 {
    return if (options.renewal_deadline_ms == 0) options.ttl_ms else options.renewal_deadline_ms;
}

fn auditEntry(local: ShardLease, current: ?ShardLease, options: ShardLeaseManagerOptions, now_ms: u64) ShardLeaseAuditEntry {
    const lease = current orelse return .{
        .shard_id = local.shard_id,
        .local_owner = local.owner,
        .local_epoch = local.epoch,
        .expires_at_ms = local.expires_at_ms,
        .status = .missing,
    };

    var status = ShardLeaseAuditStatus.valid;
    if (!lease.owner.eql(local.owner)) {
        status = .stale_owner;
    } else if (lease.epoch != local.epoch) {
        status = .stale_epoch;
    } else if (shardLeaseExpiredForRecovery(lease, options, now_ms)) {
        status = .expired;
    } else if (now_ms >= shardLeaseRenewalDeadlineAt(lease, options)) {
        status = .renewal_deadline_missed;
    } else if (shardLeaseRefreshDue(lease, options, now_ms)) {
        status = .refresh_due;
    }

    return .{
        .shard_id = local.shard_id,
        .local_owner = local.owner,
        .local_epoch = local.epoch,
        .current_owner = lease.owner,
        .current_epoch = lease.epoch,
        .expires_at_ms = lease.expires_at_ms,
        .status = status,
    };
}

fn countAuditEntry(report: *ShardLeaseAuditReport, status: ShardLeaseAuditStatus) void {
    switch (status) {
        .valid => report.valid += 1,
        .refresh_due => report.refresh_due += 1,
        .renewal_deadline_missed => report.renewal_deadline_missed += 1,
        .expired => report.expired += 1,
        .missing => report.missing += 1,
        .stale_owner => report.stale_owner += 1,
        .stale_epoch => report.stale_epoch += 1,
    }
}
