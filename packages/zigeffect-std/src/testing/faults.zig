const std = @import("std");
const Contract = @import("contract.zig");

pub const MatrixError = error{
    InvalidBounds,
    UnsupportedFault,
};

pub const FaultCase = struct {
    id: []const u8,
    kind: Contract.FaultKind,
    index: usize,
    seed: u64,
    schedule_choices: []const u32 = &.{},
    replay_token: []const u8,
};

pub const Limits = struct {
    allocation_failures: usize = 4,
    schedules: usize = 4,
    cases: usize = 64,
};

pub const FaultMatrix = struct {
    allocator: std.mem.Allocator,
    cases: []FaultCase,
    truncated: usize = 0,

    pub fn standard(allocator: std.mem.Allocator, seed: u64) !FaultMatrix {
        return planAlloc(allocator, seed, .standard, .{});
    }

    pub fn exhaustive(allocator: std.mem.Allocator, seed: u64, limits: Limits) !FaultMatrix {
        return planAlloc(allocator, seed, .exhaustive, limits);
    }

    pub fn deinit(self: *FaultMatrix) void {
        for (self.cases) |item| {
            self.allocator.free(item.id);
            self.allocator.free(item.schedule_choices);
            self.allocator.free(item.replay_token);
        }
        self.allocator.free(self.cases);
    }
};

pub const CaseStatus = enum { passed, failed, unsupported, skipped };

pub const CaseResult = struct {
    id: []const u8,
    kind: Contract.FaultKind,
    index: usize,
    status: CaseStatus,
    error_name: []const u8 = "",
    replay_token: []const u8,
};

pub const RunOptions = struct {
    stop_on_failure: bool = false,
};

pub const MatrixReceipt = struct {
    allocator: std.mem.Allocator,
    seed: u64,
    planned: usize,
    executed: usize,
    passed: usize,
    failed: usize,
    unsupported: usize,
    skipped: usize,
    truncated: usize,
    results: []CaseResult,

    pub fn deinit(self: *MatrixReceipt) void {
        for (self.results) |result| {
            self.allocator.free(result.id);
            self.allocator.free(result.error_name);
            self.allocator.free(result.replay_token);
        }
        self.allocator.free(self.results);
    }

    pub fn complete(self: MatrixReceipt) bool {
        return self.truncated == 0 and self.executed == self.planned and self.skipped == 0;
    }

    pub fn status(self: MatrixReceipt) Contract.TestStatus {
        if (self.failed != 0) return .failed;
        if (!self.complete()) return .incomplete;
        if (self.passed == 0 and self.unsupported != 0) return .unsupported;
        return .passed;
    }

    pub fn evidenceSummary(self: MatrixReceipt) Contract.EvidenceSummary {
        return .{ .attempted = true, .status = self.status(), .planned = self.planned, .executed = self.executed, .passed = self.passed, .failed = self.failed, .unsupported = self.unsupported, .truncated = self.truncated != 0, .replay_token = if (self.results.len == 0) "" else self.results[0].replay_token };
    }

    pub fn jsonAlloc(self: MatrixReceipt, allocator: std.mem.Allocator) ![]u8 {
        return @import("../secrets/root.zig").safeJsonAlloc(allocator, .{ .schema = "zigeffect.test-fault-matrix.v1", .seed = self.seed, .status = self.status(), .planned = self.planned, .executed = self.executed, .passed = self.passed, .failed = self.failed, .unsupported = self.unsupported, .skipped = self.skipped, .truncated = self.truncated, .results = self.results }, .{});
    }

    pub fn replayCommandAlloc(self: MatrixReceipt, allocator: std.mem.Allocator, scenario_id: []const u8, result_index: usize) ![]u8 {
        if (result_index >= self.results.len) return error.InvalidBounds;
        return std.fmt.allocPrint(allocator, "zigeffect test replay {s} --seed {d} --fault {s}", .{ scenario_id, self.seed, self.results[result_index].replay_token });
    }
};

pub fn planAlloc(allocator: std.mem.Allocator, seed: u64, profile: Contract.FaultProfile, limits: Limits) !FaultMatrix {
    if (seed == 0 or limits.cases == 0 or limits.allocation_failures == 0 or limits.schedules == 0) return error.InvalidBounds;
    var list = std.ArrayList(FaultCase).empty;
    errdefer deinitCaseList(allocator, &list);
    var truncated: usize = 0;

    try appendCase(allocator, &list, limits.cases, &truncated, seed, .none, 0, &.{});
    switch (profile) {
        .none => {},
        .allocation => try appendIndexed(allocator, &list, limits, &truncated, seed, .allocation_failure, limits.allocation_failures),
        .schedule => try appendSchedules(allocator, &list, limits, &truncated, seed),
        .recovery => {
            try appendKinds(allocator, &list, limits, &truncated, seed, &.{ .timeout, .cancellation, .interruption, .retry_exhaustion, .storage_failure, .transport_failure, .broker_failure, .cache_failure, .object_storage_failure, .telemetry_failure, .lease_loss, .database_restart, .network_partition, .migration_failure, .redelivery, .journal_crash, .corrupt_artifact });
        },
        .executor => try appendKinds(allocator, &list, limits, &truncated, seed, &.{ .spawn_failure, .executor }),
        .standard, .exhaustive => {
            const allocation_count = if (profile == .standard) @min(limits.allocation_failures, 2) else limits.allocation_failures;
            try appendIndexed(allocator, &list, limits, &truncated, seed, .allocation_failure, allocation_count);
            try appendSchedules(allocator, &list, limits, &truncated, seed);
            try appendKinds(allocator, &list, limits, &truncated, seed, &.{
                .timeout,         .cancellation, .interruption, .spawn_failure, .retry_exhaustion,
                .process_failure, .http_failure, .sql_failure, .storage_failure, .transport_failure,
                .broker_failure, .cache_failure, .object_storage_failure, .telemetry_failure, .lease_loss,
                .database_restart, .network_partition, .migration_failure, .redelivery, .journal_crash, .corrupt_artifact,
                .executor,
            });
        },
    }
    return .{ .allocator = allocator, .cases = try list.toOwnedSlice(allocator), .truncated = truncated };
}

pub fn runMatrix(
    allocator: std.mem.Allocator,
    matrix: FaultMatrix,
    state: anytype,
    comptime execute: fn (@TypeOf(state), FaultCase) anyerror!void,
    options: RunOptions,
) !MatrixReceipt {
    var results = std.ArrayList(CaseResult).empty;
    errdefer deinitResultList(allocator, &results);
    var passed: usize = 0;
    var failed: usize = 0;
    var unsupported: usize = 0;
    var skipped: usize = 0;
    var stop = false;
    for (matrix.cases) |item| {
        var status: CaseStatus = .passed;
        var error_name: []const u8 = "";
        if (stop) {
            status = .skipped;
            skipped += 1;
        } else {
            execute(state, item) catch |err| {
                error_name = @errorName(err);
                if (err == error.UnsupportedFault) {
                    status = .unsupported;
                    unsupported += 1;
                } else {
                    status = .failed;
                    failed += 1;
                    stop = options.stop_on_failure;
                }
            };
            if (status == .passed) passed += 1;
        }
        const owned = CaseResult{
            .id = try allocator.dupe(u8, item.id),
            .kind = item.kind,
            .index = item.index,
            .status = status,
            .error_name = try allocator.dupe(u8, error_name),
            .replay_token = try allocator.dupe(u8, item.replay_token),
        };
        errdefer {
            allocator.free(owned.id);
            allocator.free(owned.error_name);
            allocator.free(owned.replay_token);
        }
        try results.append(allocator, owned);
    }
    return .{
        .allocator = allocator,
        .seed = if (matrix.cases.len == 0) 0 else matrix.cases[0].seed,
        .planned = matrix.cases.len,
        .executed = matrix.cases.len - skipped,
        .passed = passed,
        .failed = failed,
        .unsupported = unsupported,
        .skipped = skipped,
        .truncated = matrix.truncated,
        .results = try results.toOwnedSlice(allocator),
    };
}

pub fn checkAllAllocationFailures(allocator: std.mem.Allocator, comptime test_fn: anytype, args: anytype) !void {
    return std.testing.checkAllAllocationFailures(allocator, test_fn, args);
}

pub const FakeProcess = struct {
    fault: ?FaultCase = null,
    pub fn run(self: FakeProcess) ![]const u8 {
        if (self.fault) |item| if (item.kind == .process_failure) return error.ProcessFailed;
        return "process output";
    }
};

pub const FakeHttp = struct {
    fault: ?FaultCase = null,
    pub fn request(self: FakeHttp) !u16 {
        if (self.fault) |item| if (item.kind == .http_failure) return error.HttpFailed;
        return 200;
    }
};

pub const FakeSql = struct {
    fault: ?FaultCase = null,
    pub fn execute(self: FakeSql) !usize {
        if (self.fault) |item| if (item.kind == .sql_failure) return error.SqlFailed;
        return 1;
    }
};

pub const CrashPoint = enum { before_write, after_write, before_commit, after_commit, during_recovery };
pub const CrashPlan = struct { point: CrashPoint, crash_index: usize = 0, corrupt_after_crash: bool = false };

fn appendIndexed(allocator: std.mem.Allocator, list: *std.ArrayList(FaultCase), limits: Limits, truncated: *usize, seed: u64, kind: Contract.FaultKind, count: usize) !void {
    for (0..count) |index| try appendCase(allocator, list, limits.cases, truncated, seed, kind, index, &.{});
}

fn appendSchedules(allocator: std.mem.Allocator, list: *std.ArrayList(FaultCase), limits: Limits, truncated: *usize, seed: u64) !void {
    for (0..limits.schedules) |index| {
        const choices = [_]u32{ @intCast(index % 3), @intCast((seed +% index) % 3) };
        try appendCase(allocator, list, limits.cases, truncated, seed, .schedule_choice, index, &choices);
    }
}

fn appendKinds(allocator: std.mem.Allocator, list: *std.ArrayList(FaultCase), limits: Limits, truncated: *usize, seed: u64, kinds: []const Contract.FaultKind) !void {
    for (kinds) |kind| try appendCase(allocator, list, limits.cases, truncated, seed, kind, 0, &.{});
}

fn appendCase(allocator: std.mem.Allocator, list: *std.ArrayList(FaultCase), max: usize, truncated: *usize, seed: u64, kind: Contract.FaultKind, index: usize, choices: []const u32) !void {
    if (list.items.len >= max) {
        truncated.* += 1;
        return;
    }
    const id = try std.fmt.allocPrint(allocator, "{s}-{d:0>4}", .{ @tagName(kind), index });
    errdefer allocator.free(id);
    const owned_choices = try allocator.dupe(u32, choices);
    errdefer allocator.free(owned_choices);
    const replay = try std.fmt.allocPrint(allocator, "{s}:{d}", .{ @tagName(kind), index });
    errdefer allocator.free(replay);
    try list.append(allocator, .{ .id = id, .kind = kind, .index = index, .seed = seed, .schedule_choices = owned_choices, .replay_token = replay });
}

fn deinitCaseList(allocator: std.mem.Allocator, list: *std.ArrayList(FaultCase)) void {
    for (list.items) |item| {
        allocator.free(item.id);
        allocator.free(item.schedule_choices);
        allocator.free(item.replay_token);
    }
    list.deinit(allocator);
}

fn deinitResultList(allocator: std.mem.Allocator, list: *std.ArrayList(CaseResult)) void {
    for (list.items) |item| {
        allocator.free(item.id);
        allocator.free(item.error_name);
        allocator.free(item.replay_token);
    }
    list.deinit(allocator);
}

test "fault planning is stable bounded and replayable" {
    var first = try FaultMatrix.standard(std.testing.allocator, 42);
    defer first.deinit();
    var second = try FaultMatrix.standard(std.testing.allocator, 42);
    defer second.deinit();
    try std.testing.expect(first.cases.len > 10);
    try std.testing.expectEqual(first.cases.len, second.cases.len);
    for (first.cases, second.cases) |left, right| {
        try std.testing.expectEqualStrings(left.id, right.id);
        try std.testing.expectEqualSlices(u32, left.schedule_choices, right.schedule_choices);
    }
    var bounded = try FaultMatrix.exhaustive(std.testing.allocator, 1, .{ .cases = 3 });
    defer bounded.deinit();
    try std.testing.expectEqual(@as(usize, 3), bounded.cases.len);
    try std.testing.expect(bounded.truncated > 0);
    try std.testing.expectError(error.InvalidBounds, planAlloc(std.testing.allocator, 0, .standard, .{}));
}

test "matrix runner records failures unsupported cases and first-failure stopping" {
    const State = struct { calls: usize = 0 };
    const Runner = struct {
        fn run(state: *State, item: FaultCase) !void {
            state.calls += 1;
            if (item.kind == .allocation_failure) return error.InjectedFailure;
            if (item.kind == .executor) return error.UnsupportedFault;
        }
    };
    var matrix = try FaultMatrix.standard(std.testing.allocator, 7);
    defer matrix.deinit();
    var state = State{};
    var receipt = try runMatrix(std.testing.allocator, matrix, &state, Runner.run, .{ .stop_on_failure = true });
    defer receipt.deinit();
    try std.testing.expectEqual(@as(usize, 1), receipt.failed);
    try std.testing.expect(receipt.skipped > 0);
    try std.testing.expectEqual(state.calls, receipt.executed);
    const replay = try receipt.replayCommandAlloc(std.testing.allocator, "scenario", 1);
    defer std.testing.allocator.free(replay);
    try std.testing.expect(std.mem.indexOf(u8, replay, "--seed 7") != null);
}

test "fault planner and receipts release partial allocations" {
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var matrix = try FaultMatrix.standard(allocator, 9);
            defer matrix.deinit();
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}
