const std = @import("std");
const fx = @import("zigeffect");
const Contract = @import("contract.zig");

pub const Options = fx.ScheduleExplorerOptions;

pub const Evidence = struct {
    allocator: std.mem.Allocator,
    status: Contract.TestStatus,
    explored_states: usize,
    explored_schedules: usize,
    deduplicated_states: usize,
    truncated: bool,
    failure_kind: []const u8,
    error_name: []const u8,
    schedule: []usize,
    source_ref_id: ?u64,
    replay_token: []const u8,

    pub fn deinit(self: *Evidence) void {
        self.allocator.free(self.failure_kind);
        self.allocator.free(self.error_name);
        self.allocator.free(self.schedule);
        self.allocator.free(self.replay_token);
    }

    pub fn jsonAlloc(self: Evidence, allocator: std.mem.Allocator) ![]u8 {
        return std.json.Stringify.valueAlloc(allocator, .{
            .schema = "zigeffect.test-schedule-evidence.v1",
            .schema_version = 1,
            .status = self.status,
            .explored_states = self.explored_states,
            .explored_schedules = self.explored_schedules,
            .deduplicated_states = self.deduplicated_states,
            .truncated = self.truncated,
            .failure_kind = self.failure_kind,
            .error_name = self.error_name,
            .schedule = self.schedule,
            .source_ref_id = self.source_ref_id,
            .replay_token = self.replay_token,
        }, .{});
    }

    pub fn evidenceSummary(self: Evidence) Contract.EvidenceSummary {
        const failed: usize = if (self.status == .failed) 1 else 0;
        const executed = self.explored_schedules + failed;
        const planned = executed + @as(usize, @intFromBool(self.truncated));
        return .{
            .attempted = true,
            .status = self.status,
            .planned = planned,
            .executed = executed,
            .passed = self.explored_schedules,
            .failed = failed,
            .truncated = self.truncated,
            .replay_token = self.replay_token,
        };
    }
};

pub fn explore(allocator: std.mem.Allocator, initial: anytype, options: Options) !Evidence {
    var report = try fx.exploreSchedules(allocator, initial, options);
    defer report.deinit();
    const status: Contract.TestStatus = switch (report.verdict()) {
        .passed => .passed,
        .failed => .failed,
        .incomplete => .incomplete,
    };
    const failure_kind = if (report.failure) |failure| try allocator.dupe(u8, @tagName(failure.kind)) else try allocator.dupe(u8, "");
    errdefer allocator.free(failure_kind);
    const error_name = if (report.failure) |failure| try allocator.dupe(u8, failure.error_name) else try allocator.dupe(u8, "");
    errdefer allocator.free(error_name);
    const schedule = if (report.failure) |failure| try allocator.dupe(usize, failure.schedule) else try allocator.alloc(usize, 0);
    errdefer allocator.free(schedule);
    const replay_token = try replayTokenAlloc(allocator, schedule);
    errdefer allocator.free(replay_token);
    return .{
        .allocator = allocator,
        .status = status,
        .explored_states = report.explored_states,
        .explored_schedules = report.explored_schedules,
        .deduplicated_states = report.deduplicated_states,
        .truncated = report.truncated,
        .failure_kind = failure_kind,
        .error_name = error_name,
        .schedule = schedule,
        .source_ref_id = if (report.failure) |failure| failure.source_ref_id else null,
        .replay_token = replay_token,
    };
}

pub fn replay(initial: anytype, schedule: []const usize) !@TypeOf(initial) {
    return fx.replaySchedule(initial, schedule);
}

fn replayTokenAlloc(allocator: std.mem.Allocator, schedule: []const usize) ![]u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, "schedule:");
    for (schedule, 0..) |action, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.print(allocator, "{d}", .{action});
    }
    return output.toOwnedSlice(allocator);
}

const SafeModel = struct {
    value: u8 = 0,
    done: [2]bool = .{ false, false },

    pub fn actionCount(_: @This()) usize {
        return 2;
    }

    pub fn runnable(self: @This(), action: usize) bool {
        return action < 2 and !self.done[action];
    }

    pub fn step(self: *@This(), action: usize) !void {
        if (!self.runnable(action)) return error.NotRunnable;
        self.value += 1;
        self.done[action] = true;
    }

    pub fn isComplete(self: @This()) bool {
        return self.done[0] and self.done[1];
    }

    pub fn invariant(self: @This()) bool {
        return self.value <= 2;
    }

    pub fn stateHash(self: @This()) u64 {
        return @as(u64, self.value) | (@as(u64, @intFromBool(self.done[0])) << 8) | (@as(u64, @intFromBool(self.done[1])) << 9);
    }

    pub fn sourceRef(_: @This(), action: usize) ?u64 {
        return 100 + action;
    }
};

test "schedule evidence passes complete bounded exploration" {
    var evidence = try explore(std.testing.allocator, SafeModel{}, .{});
    defer evidence.deinit();
    try std.testing.expectEqual(Contract.TestStatus.passed, evidence.status);
    try std.testing.expect(evidence.explored_schedules > 0);
    try std.testing.expectEqual(@as(usize, 0), evidence.schedule.len);
}

test "schedule evidence preserves the smallest failing replay" {
    const BadModel = struct {
        value: u8 = 0,
        pub fn actionCount(_: @This()) usize {
            return 1;
        }
        pub fn runnable(self: @This(), action: usize) bool {
            return action == 0 and self.value == 0;
        }
        pub fn step(self: *@This(), _: usize) !void {
            self.value = 2;
        }
        pub fn isComplete(self: @This()) bool {
            return self.value == 2;
        }
        pub fn invariant(self: @This()) bool {
            return self.value < 2;
        }
        pub fn stateHash(self: @This()) u64 {
            return self.value;
        }
        pub fn sourceRef(_: @This(), action: usize) ?u64 {
            return 200 + action;
        }
    };
    var evidence = try explore(std.testing.allocator, BadModel{}, .{});
    defer evidence.deinit();
    try std.testing.expectEqual(Contract.TestStatus.failed, evidence.status);
    try std.testing.expectEqualSlices(usize, &.{0}, evidence.schedule);
    try std.testing.expectEqual(@as(?u64, 200), evidence.source_ref_id);
    try std.testing.expect(std.mem.indexOf(u8, evidence.replay_token, "0") != null);
}

test "schedule bounds remain incomplete rather than passed" {
    var evidence = try explore(std.testing.allocator, SafeModel{}, .{ .max_states = 1, .max_schedules = 1, .max_steps_per_schedule = 1 });
    defer evidence.deinit();
    try std.testing.expectEqual(Contract.TestStatus.incomplete, evidence.status);
    try std.testing.expect(evidence.truncated);
}
