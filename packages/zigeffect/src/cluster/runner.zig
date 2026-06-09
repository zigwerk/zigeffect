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

const RunnerRecord = struct {
    registration: RunnerRegistration,
    state: RunnerHealthState = .starting,
    last_heartbeat_index: ?usize = null,
};

pub const LocalRunnerRegistry = struct {
    allocator: Allocator,
    records: std.ArrayList(RunnerRecord) = .empty,
    heartbeats: std.ArrayList(RunnerHeartbeat) = .empty,
    events: std.ArrayList(RunnerHealthEvent) = .empty,

    pub fn init(allocator: Allocator) LocalRunnerRegistry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *LocalRunnerRegistry) void {
        for (self.records.items) |record| {
            self.allocator.free(record.registration.name);
        }
        self.records.deinit(self.allocator);
        self.heartbeats.deinit(self.allocator);
        self.events.deinit(self.allocator);
    }

    pub fn registerRunner(self: *LocalRunnerRegistry, registration: RunnerRegistration) (Allocator.Error || RunnerRegistryError)!RunnerHealthSnapshot {
        if (self.findRecordIndex(registration.address) != null) return error.DuplicateRunner;

        try self.records.ensureUnusedCapacity(self.allocator, 1);
        try self.events.ensureUnusedCapacity(self.allocator, 1);
        const owned_name = try self.allocator.dupe(u8, registration.name);
        var owned_registration = registration;
        owned_registration.name = owned_name;

        self.records.appendAssumeCapacity(.{ .registration = owned_registration });
        self.events.appendAssumeCapacity(.{
            .address = registration.address,
            .previous_state = null,
            .next_state = .starting,
            .reason = .startup_registered,
            .at_ms = registration.started_at_ms,
        });
        return try self.snapshot(registration.address, registration.started_at_ms);
    }

    pub fn runnerCount(self: *const LocalRunnerRegistry) usize {
        return self.records.items.len;
    }

    pub fn state(self: *const LocalRunnerRegistry, address: RunnerAddress) RunnerRegistryError!RunnerHealthState {
        const index = self.findRecordIndex(address) orelse return error.RunnerNotFound;
        return self.records.items[index].state;
    }

    pub fn recordHeartbeat(self: *LocalRunnerRegistry, heartbeat: RunnerHeartbeat) (Allocator.Error || RunnerRegistryError)!RunnerHealthSnapshot {
        const record_index = self.findRecordIndex(heartbeat.address) orelse return error.RunnerNotFound;
        const current_record = self.records.items[record_index];
        if (current_record.last_heartbeat_index) |heartbeat_index| {
            const previous_heartbeat = self.heartbeats.items[heartbeat_index];
            if (heartbeat.sequence <= previous_heartbeat.sequence) return error.InvalidHeartbeatSequence;
        }

        const previous_state = current_record.state;
        try self.heartbeats.ensureUnusedCapacity(self.allocator, 1);
        if (previous_state != .healthy) try self.events.ensureUnusedCapacity(self.allocator, 1);

        const heartbeat_index = self.heartbeats.items.len;
        self.heartbeats.appendAssumeCapacity(heartbeat);
        self.records.items[record_index].last_heartbeat_index = heartbeat_index;
        self.records.items[record_index].state = .healthy;
        if (previous_state != .healthy) {
            self.events.appendAssumeCapacity(.{
                .address = heartbeat.address,
                .previous_state = previous_state,
                .next_state = .healthy,
                .reason = .heartbeat_recorded,
                .at_ms = heartbeat.observed_at_ms,
            });
        }
        return try self.snapshot(heartbeat.address, heartbeat.observed_at_ms);
    }

    pub fn heartbeatCount(self: *const LocalRunnerRegistry, address: RunnerAddress) RunnerRegistryError!usize {
        if (self.findRecordIndex(address) == null) return error.RunnerNotFound;
        var count: usize = 0;
        for (self.heartbeats.items) |heartbeat| {
            if (heartbeat.address.eql(address)) count += 1;
        }
        return count;
    }

    pub fn lastHeartbeat(self: *const LocalRunnerRegistry, address: RunnerAddress) RunnerRegistryError!?RunnerHeartbeat {
        const index = self.findRecordIndex(address) orelse return error.RunnerNotFound;
        return if (self.records.items[index].last_heartbeat_index) |heartbeat_index| self.heartbeats.items[heartbeat_index] else null;
    }

    pub fn snapshot(self: *const LocalRunnerRegistry, address: RunnerAddress, now_ms: u64) RunnerRegistryError!RunnerHealthSnapshot {
        const index = self.findRecordIndex(address) orelse return error.RunnerNotFound;
        const record = self.records.items[index];
        const last_heartbeat = if (record.last_heartbeat_index) |heartbeat_index| self.heartbeats.items[heartbeat_index] else null;
        const heartbeat_age_ms = if (last_heartbeat) |heartbeat| elapsedMs(now_ms, heartbeat.observed_at_ms) else null;
        return .{
            .address = record.registration.address,
            .name = record.registration.name,
            .state = record.state,
            .started_at_ms = record.registration.started_at_ms,
            .last_heartbeat_at_ms = if (last_heartbeat) |heartbeat| heartbeat.observed_at_ms else null,
            .last_heartbeat_sequence = if (last_heartbeat) |heartbeat| heartbeat.sequence else null,
            .heartbeat_age_ms = heartbeat_age_ms,
            .health_event_count = try self.healthEventCount(address),
        };
    }

    pub fn healthEventCount(self: *const LocalRunnerRegistry, address: RunnerAddress) RunnerRegistryError!usize {
        if (self.findRecordIndex(address) == null) return error.RunnerNotFound;
        var count: usize = 0;
        for (self.events.items) |event| {
            if (event.address.eql(address)) count += 1;
        }
        return count;
    }

    pub fn lastHealthEvent(self: *const LocalRunnerRegistry, address: RunnerAddress) RunnerRegistryError!?RunnerHealthEvent {
        if (self.findRecordIndex(address) == null) return error.RunnerNotFound;
        var index = self.events.items.len;
        while (index > 0) {
            index -= 1;
            const event = self.events.items[index];
            if (event.address.eql(address)) return event;
        }
        return null;
    }

    fn findRecordIndex(self: *const LocalRunnerRegistry, address: RunnerAddress) ?usize {
        for (self.records.items, 0..) |record, index| {
            if (record.registration.address.eql(address)) return index;
        }
        return null;
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

fn elapsedMs(now_ms: u64, then_ms: u64) u64 {
    return if (now_ms >= then_ms) now_ms - then_ms else 0;
}
