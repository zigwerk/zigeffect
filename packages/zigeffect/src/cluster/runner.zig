const std = @import("std");

pub const Allocator = std.mem.Allocator;
pub const RunnerId = u64;
pub const MachineId = u64;
pub const RunnerHeartbeatSequence = u64;

pub const RunnerAddress = struct {
    machine_id: MachineId,
    runner_id: RunnerId,

    pub fn eql(self: RunnerAddress, other: RunnerAddress) bool {
        return self.machine_id == other.machine_id and self.runner_id == other.runner_id;
    }
};

pub const RunnerHealthState = enum { starting, healthy, degraded, unhealthy, stopped };
pub const RunnerHealthReason = enum { startup_registered, heartbeat_recorded, heartbeat_late, heartbeat_expired, runner_stopped };

pub const RunnerRegistration = struct {
    address: RunnerAddress,
    name: []const u8,
    started_at_ms: u64,
};

pub const RunnerHeartbeat = struct {
    address: RunnerAddress,
    sequence: RunnerHeartbeatSequence,
    observed_at_ms: u64,
};

pub const RunnerHealthEvent = struct {
    address: RunnerAddress,
    previous_state: ?RunnerHealthState,
    next_state: RunnerHealthState,
    reason: RunnerHealthReason,
    at_ms: u64,
};

pub const RunnerHealthSnapshot = struct {
    address: RunnerAddress,
    name: []const u8,
    state: RunnerHealthState,
    started_at_ms: u64,
    last_heartbeat_at_ms: ?u64 = null,
    last_heartbeat_sequence: ?RunnerHeartbeatSequence = null,
    heartbeat_age_ms: ?u64 = null,
    health_event_count: usize = 0,
};

pub const RunnerHealthReport = struct {
    allocator: Allocator,
    generated_at_ms: u64,
    snapshots: []RunnerHealthSnapshot,

    pub fn deinit(self: *RunnerHealthReport) void {
        self.allocator.free(self.snapshots);
    }
};

pub const RunnerHealthInspectorOptions = struct {
    degraded_after_ms: u64 = 5_000,
    unhealthy_after_ms: u64 = 15_000,
};

pub const RunnerRegistryError = error{
    DuplicateRunner,
    RunnerNotFound,
    InvalidHeartbeatSequence,
    InvalidHealthThresholds,
};

pub const LocalRunnerRegistry = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) LocalRunnerRegistry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *LocalRunnerRegistry) void {
        _ = self;
    }
};

pub const LocalRunnerHealthInspector = struct {
    options: RunnerHealthInspectorOptions,

    pub fn init(options: RunnerHealthInspectorOptions) RunnerRegistryError!LocalRunnerHealthInspector {
        if (options.degraded_after_ms > options.unhealthy_after_ms) return error.InvalidHealthThresholds;
        return .{ .options = options };
    }
};

pub fn machineId(machine_key: []const u8) MachineId {
    var hasher = std.hash.Fnv1a_64.init();
    hasher.update("zigeffect.cluster.machine.v1:");
    hasher.update(machine_key);
    return hasher.final();
}

pub fn runnerId(machine_id: MachineId, runner_key: []const u8) RunnerId {
    var hasher = std.hash.Fnv1a_64.init();
    var machine_buf: [8]u8 = undefined;
    std.mem.writeInt(u64, &machine_buf, machine_id, .little);
    hasher.update("zigeffect.cluster.runner.v1:");
    hasher.update(&machine_buf);
    hasher.update(":");
    hasher.update(runner_key);
    return hasher.final();
}

pub fn runnerAddress(machine_key: []const u8, runner_key: []const u8) RunnerAddress {
    const machine_id = machineId(machine_key);
    return .{
        .machine_id = machine_id,
        .runner_id = runnerId(machine_id, runner_key),
    };
}
