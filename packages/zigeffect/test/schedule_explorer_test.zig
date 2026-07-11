const std = @import("std");
const fx = @import("zigeffect");

const LostUpdateModel = struct {
    shared: u8 = 0,
    pc: [2]u8 = .{ 0, 0 },
    observed: [2]u8 = .{ 0, 0 },

    pub fn actionCount(_: LostUpdateModel) usize {
        return 2;
    }

    pub fn runnable(self: LostUpdateModel, action: usize) bool {
        return action < 2 and self.pc[action] < 2;
    }

    pub fn step(self: *LostUpdateModel, action: usize) !void {
        if (!self.runnable(action)) return error.NotRunnable;
        if (self.pc[action] == 0) {
            self.observed[action] = self.shared;
            self.pc[action] = 1;
        } else {
            self.shared = self.observed[action] + 1;
            self.pc[action] = 2;
        }
    }

    pub fn isComplete(self: LostUpdateModel) bool {
        return self.pc[0] == 2 and self.pc[1] == 2;
    }

    pub fn invariant(self: LostUpdateModel) bool {
        return !self.isComplete() or self.shared == 2;
    }

    pub fn stateHash(self: LostUpdateModel) u64 {
        return @as(u64, self.shared) |
            (@as(u64, self.pc[0]) << 8) |
            (@as(u64, self.pc[1]) << 16) |
            (@as(u64, self.observed[0]) << 24) |
            (@as(u64, self.observed[1]) << 32);
    }

    pub fn sourceRef(_: LostUpdateModel, action: usize) ?u64 {
        return 100 + action;
    }
};

const SafeIncrementModel = struct {
    shared: u8 = 0,
    done: [2]bool = .{ false, false },

    pub fn actionCount(_: SafeIncrementModel) usize {
        return 2;
    }

    pub fn runnable(self: SafeIncrementModel, action: usize) bool {
        return action < 2 and !self.done[action];
    }

    pub fn step(self: *SafeIncrementModel, action: usize) !void {
        if (!self.runnable(action)) return error.NotRunnable;
        self.shared += 1;
        self.done[action] = true;
    }

    pub fn isComplete(self: SafeIncrementModel) bool {
        return self.done[0] and self.done[1];
    }

    pub fn invariant(self: SafeIncrementModel) bool {
        return !self.isComplete() or self.shared == 2;
    }

    pub fn stateHash(self: SafeIncrementModel) u64 {
        return @as(u64, self.shared) |
            (@as(u64, @intFromBool(self.done[0])) << 8) |
            (@as(u64, @intFromBool(self.done[1])) << 9);
    }

    pub fn sourceRef(_: SafeIncrementModel, action: usize) ?u64 {
        return 200 + action;
    }
};

test "ScheduleExplorer finds and replays the smallest lost-update schedule" {
    var report = try fx.exploreSchedules(std.testing.allocator, LostUpdateModel{}, .{
        .max_states = 128,
        .max_schedules = 128,
        .max_steps_per_schedule = 8,
    });
    defer report.deinit();

    try std.testing.expectEqual(fx.ScheduleExplorationVerdict.failed, report.verdict());
    try std.testing.expect(report.failure != null);
    try std.testing.expectEqual(fx.ScheduleFailureKind.invariant_failed, report.failure.?.kind);
    try std.testing.expectEqual(@as(usize, 4), report.failure.?.schedule.len);
    try std.testing.expect(report.failure.?.source_ref_id != null);
    try std.testing.expect(!report.truncated);

    const replayed = try fx.replaySchedule(LostUpdateModel{}, report.failure.?.schedule);
    try std.testing.expect(replayed.isComplete());
    try std.testing.expectEqual(@as(u8, 1), replayed.shared);

    const json = try report.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, fx.schedule_exploration_schema) != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "invariant_failed") != null);
}

test "ScheduleExplorer proves bounded safe model schedules" {
    var report = try fx.exploreSchedules(std.testing.allocator, SafeIncrementModel{}, .{});
    defer report.deinit();
    try std.testing.expectEqual(fx.ScheduleExplorationVerdict.passed, report.verdict());
    try std.testing.expect(report.explored_schedules >= 1);
    try std.testing.expect(report.failure == null);
    try std.testing.expect(!report.truncated);
}

test "ScheduleExplorer reports deadlock and truthful truncation" {
    const Deadlock = struct {
        pub fn actionCount(_: @This()) usize {
            return 1;
        }
        pub fn runnable(_: @This(), _: usize) bool {
            return false;
        }
        pub fn step(_: *@This(), _: usize) !void {}
        pub fn isComplete(_: @This()) bool {
            return false;
        }
        pub fn invariant(_: @This()) bool {
            return true;
        }
        pub fn stateHash(_: @This()) u64 {
            return 1;
        }
        pub fn sourceRef(_: @This(), _: usize) ?u64 {
            return null;
        }
    };
    var deadlock = try fx.exploreSchedules(std.testing.allocator, Deadlock{}, .{});
    defer deadlock.deinit();
    try std.testing.expectEqual(fx.ScheduleFailureKind.deadlock, deadlock.failure.?.kind);

    var truncated = try fx.exploreSchedules(std.testing.allocator, LostUpdateModel{}, .{
        .max_states = 1,
        .max_schedules = 1,
        .max_steps_per_schedule = 1,
    });
    defer truncated.deinit();
    try std.testing.expect(truncated.truncated);
    try std.testing.expectEqual(fx.ScheduleExplorationVerdict.incomplete, truncated.verdict());
}

test "ScheduleExplorer source-links timeout cancellation and spawn failures" {
    const Fault = enum { timeout, canceled, spawn_failed };
    const FaultModel = struct {
        fault: Fault,
        done: bool = false,

        pub fn actionCount(_: @This()) usize { return 1; }
        pub fn runnable(self: @This(), action: usize) bool { return action == 0 and !self.done; }
        pub fn step(self: *@This(), _: usize) !void {
            return switch (self.fault) {
                .timeout => error.Timeout,
                .canceled => error.Canceled,
                .spawn_failed => error.SpawnFailed,
            };
        }
        pub fn isComplete(self: @This()) bool { return self.done; }
        pub fn invariant(_: @This()) bool { return true; }
        pub fn stateHash(self: @This()) u64 { return @intFromEnum(self.fault); }
        pub fn sourceRef(_: @This(), _: usize) ?u64 { return 9001; }
    };
    const cases = [_]struct { fault: Fault, name: []const u8 }{
        .{ .fault = .timeout, .name = "Timeout" },
        .{ .fault = .canceled, .name = "Canceled" },
        .{ .fault = .spawn_failed, .name = "SpawnFailed" },
    };
    for (cases) |case| {
        var report = try fx.exploreSchedules(std.testing.allocator, FaultModel{ .fault = case.fault }, .{});
        defer report.deinit();
        try std.testing.expectEqual(fx.ScheduleFailureKind.step_error, report.failure.?.kind);
        try std.testing.expectEqualStrings(case.name, report.failure.?.error_name);
        try std.testing.expectEqual(@as(?u64, 9001), report.failure.?.source_ref_id);
    }
}

test "ScheduleExplorer releases partial exploration state on every allocation failure" {
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var report = try fx.exploreSchedules(allocator, SafeIncrementModel{}, .{});
            defer report.deinit();
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}
