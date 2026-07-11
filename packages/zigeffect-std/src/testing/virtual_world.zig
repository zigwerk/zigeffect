const std = @import("std");
const Contract = @import("contract.zig");

pub const FaultKind = enum {
    clock_skew,
    delay,
    drop,
    duplicate,
    reorder,
    partition,
    heal_partition,
    queue_redelivery,
    stale_read,
    conflicting_write,
    partial_write,
    crash,
    recover,
};

pub const ActionKind = enum { advance_time, send, queue_delivery, store_read, store_write, checkpoint };

pub const Fault = struct {
    step: usize,
    kind: FaultKind,
    target: []const u8 = "",
    amount: i64 = 0,
};

pub const Action = struct {
    kind: ActionKind,
    actor: []const u8,
    target: []const u8 = "",
    value: []const u8 = "",
    amount_ms: u64 = 0,
};

pub const Options = struct { seed: u64 = 1, max_steps: usize = 4096 };

pub const Step = struct {
    index: usize,
    action: ActionKind,
    fault: ?FaultKind,
    delivered: usize,
    virtual_time_ms: u64,
};

pub const Report = struct {
    allocator: std.mem.Allocator,
    seed: u64,
    planned: usize,
    executed: usize,
    applied_faults: usize,
    deliveries: usize,
    dropped: usize,
    redeliveries: usize,
    stale_reads: usize,
    conflicting_writes: usize,
    partial_writes: usize,
    crashed_actions: usize,
    virtual_time_ms: u64,
    state_digest: []const u8,
    replay_token: []const u8,
    steps: []Step,
    truncated: bool,

    pub fn deinit(self: *Report) void {
        self.allocator.free(self.state_digest);
        self.allocator.free(self.replay_token);
        self.allocator.free(self.steps);
    }

    pub fn status(self: Report) Contract.TestStatus {
        return if (self.truncated or self.executed != self.planned) .incomplete else .passed;
    }

    pub fn evidenceSummary(self: Report) Contract.EvidenceSummary {
        return .{
            .attempted = true,
            .status = self.status(),
            .planned = self.planned,
            .executed = self.executed,
            .passed = self.executed,
            .truncated = self.truncated,
            .replay_token = self.replay_token,
        };
    }

    pub fn jsonAlloc(self: Report, allocator: std.mem.Allocator) ![]u8 {
        return std.json.Stringify.valueAlloc(allocator, .{
            .schema = "zigeffect.test-virtual-world.v1",
            .seed = self.seed,
            .status = @tagName(self.status()),
            .planned = self.planned,
            .executed = self.executed,
            .applied_faults = self.applied_faults,
            .deliveries = self.deliveries,
            .dropped = self.dropped,
            .redeliveries = self.redeliveries,
            .stale_reads = self.stale_reads,
            .conflicting_writes = self.conflicting_writes,
            .partial_writes = self.partial_writes,
            .crashed_actions = self.crashed_actions,
            .virtual_time_ms = self.virtual_time_ms,
            .state_digest = self.state_digest,
            .replay_token = self.replay_token,
            .truncated = self.truncated,
            .steps = self.steps,
        }, .{});
    }
};

/// Executes an abstract distributed-system plan without sleeping or touching
/// the network, process table, filesystem, or a real database.
pub fn runAlloc(allocator: std.mem.Allocator, actions: []const Action, faults: []const Fault, options: Options) !Report {
    if (options.seed == 0 or options.max_steps == 0) return error.InvalidBounds;
    for (faults, 0..) |fault, index| {
        if (fault.step >= actions.len) return error.InvalidFaultStep;
        for (faults[0..index]) |previous| if (previous.step == fault.step) return error.DuplicateFault;
    }
    var steps = std.ArrayList(Step).empty;
    errdefer steps.deinit(allocator);
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    var now: u64 = 0;
    var applied: usize = 0;
    var deliveries: usize = 0;
    var dropped: usize = 0;
    var redeliveries: usize = 0;
    var stale_reads: usize = 0;
    var conflicting_writes: usize = 0;
    var partial_writes: usize = 0;
    var crashed_actions: usize = 0;
    var crashed = std.StringHashMap(void).init(allocator);
    defer crashed.deinit();
    var partitions = std.StringHashMap(void).init(allocator);
    defer partitions.deinit();
    const limit = @min(actions.len, options.max_steps);
    for (actions[0..limit], 0..) |action, index| {
        var selected: ?Fault = null;
        for (faults) |fault| if (fault.step == index) {
            selected = fault;
            break;
        };
        var delivered: usize = 0;
        if (selected) |fault| {
            applied += 1;
            switch (fault.kind) {
                .clock_skew, .delay => now +|= @intCast(@max(fault.amount, 0)),
                .drop => dropped += 1,
                .duplicate => delivered = 2,
                .reorder => delivered = 1,
                .partition => try partitions.put(fault.target, {}),
                .heal_partition => _ = partitions.remove(fault.target),
                .queue_redelivery => {
                    delivered = 2;
                    redeliveries += 1;
                },
                .stale_read => stale_reads += 1,
                .conflicting_write => conflicting_writes += 1,
                .partial_write => partial_writes += 1,
                .crash => try crashed.put(fault.target, {}),
                .recover => _ = crashed.remove(fault.target),
            }
        }
        if (action.kind == .advance_time) now +|= action.amount_ms;
        const actor_crashed = crashed.contains(action.actor);
        const link_partitioned = partitions.contains(action.target);
        if (actor_crashed) crashed_actions += 1;
        if (action.kind == .send or action.kind == .queue_delivery) {
            if (selected == null) delivered = 1;
            if (actor_crashed or link_partitioned or (selected != null and selected.?.kind == .drop)) delivered = 0;
            deliveries += delivered;
        }
        hasher.update(@tagName(action.kind));
        hasher.update(action.actor);
        hasher.update(action.target);
        hasher.update(action.value);
        hasher.update(std.mem.asBytes(&now));
        if (selected) |fault| hasher.update(@tagName(fault.kind));
        try steps.append(allocator, .{ .index = index, .action = action.kind, .fault = if (selected) |f| f.kind else null, .delivered = delivered, .virtual_time_ms = now });
    }
    var digest: [32]u8 = undefined;
    hasher.final(&digest);
    const state_digest = try std.fmt.allocPrint(allocator, "sha256:{x}", .{digest});
    errdefer allocator.free(state_digest);
    const replay = try std.fmt.allocPrint(allocator, "zigeffect test replay --world-seed {d}", .{options.seed});
    return .{
        .allocator = allocator,
        .seed = options.seed,
        .planned = actions.len,
        .executed = limit,
        .applied_faults = applied,
        .deliveries = deliveries,
        .dropped = dropped,
        .redeliveries = redeliveries,
        .stale_reads = stale_reads,
        .conflicting_writes = conflicting_writes,
        .partial_writes = partial_writes,
        .crashed_actions = crashed_actions,
        .virtual_time_ms = now,
        .state_digest = state_digest,
        .replay_token = replay,
        .steps = try steps.toOwnedSlice(allocator),
        .truncated = limit != actions.len,
    };
}

test "virtual world applies deterministic distributed faults and replays exactly" {
    const actions = [_]Action{
        .{ .kind = .send, .actor = "api", .target = "worker", .value = "job" },
        .{ .kind = .queue_delivery, .actor = "queue", .target = "worker", .value = "job" },
        .{ .kind = .store_read, .actor = "worker", .target = "orders" },
        .{ .kind = .advance_time, .actor = "clock", .amount_ms = 10 },
    };
    const faults = [_]Fault{
        .{ .step = 0, .kind = .drop },
        .{ .step = 1, .kind = .queue_redelivery },
        .{ .step = 2, .kind = .stale_read },
        .{ .step = 3, .kind = .clock_skew, .amount = 5 },
    };
    var first = try runAlloc(std.testing.allocator, &actions, &faults, .{ .seed = 7 });
    defer first.deinit();
    var second = try runAlloc(std.testing.allocator, &actions, &faults, .{ .seed = 7 });
    defer second.deinit();
    try std.testing.expectEqualStrings(first.state_digest, second.state_digest);
    try std.testing.expectEqual(@as(usize, 1), first.dropped);
    try std.testing.expectEqual(@as(usize, 1), first.redeliveries);
    try std.testing.expectEqual(@as(usize, 1), first.stale_reads);
    try std.testing.expectEqual(@as(u64, 15), first.virtual_time_ms);
}

test "virtual world exposes bounded exploration as incomplete" {
    var report = try runAlloc(std.testing.allocator, &.{
        .{ .kind = .checkpoint, .actor = "a" }, .{ .kind = .checkpoint, .actor = "b" },
    }, &.{}, .{ .max_steps = 1 });
    defer report.deinit();
    try std.testing.expectEqual(Contract.TestStatus.incomplete, report.status());
}
