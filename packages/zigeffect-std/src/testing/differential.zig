const std = @import("std");
const Contract = @import("contract.zig");

pub const OutcomeStatus = enum { passed, failed, unsupported };

/// A differential executor returns borrowed data. ZigEffect copies any data it
/// retains before the callback returns, keeping ownership explicit.
pub const Outcome = struct {
    status: OutcomeStatus = .passed,
    output: []const u8 = "",
    detail: []const u8 = "",
};

pub const Executor = struct {
    name: []const u8,
    state: *anyopaque,
    run_fn: *const fn (*anyopaque, []const u8, std.mem.Allocator) anyerror!Outcome,

    pub fn run(self: Executor, input: []const u8, allocator: std.mem.Allocator) !Outcome {
        return self.run_fn(self.state, input, allocator);
    }
};

pub const Case = struct { id: []const u8, input: []const u8 };

pub const Options = struct {
    ignored_fields: []const []const u8 = &.{},
    max_executions: usize = 1024,
    replay_prefix: []const u8 = "zigeffect test replay",
};

pub const Mismatch = struct {
    case_id: []const u8,
    baseline_executor: []const u8,
    compared_executor: []const u8,
    baseline_output: []const u8,
    compared_output: []const u8,
};

pub const Report = struct {
    allocator: std.mem.Allocator,
    planned: usize,
    executed: usize,
    unsupported: usize,
    executor_failures: usize,
    mismatches: []Mismatch,
    truncated: bool,
    replay_token: []const u8,

    pub fn deinit(self: *Report) void {
        for (self.mismatches) |item| {
            self.allocator.free(item.case_id);
            self.allocator.free(item.baseline_executor);
            self.allocator.free(item.compared_executor);
            self.allocator.free(item.baseline_output);
            self.allocator.free(item.compared_output);
        }
        self.allocator.free(self.mismatches);
        self.allocator.free(self.replay_token);
    }

    pub fn status(self: Report) Contract.TestStatus {
        if (self.executor_failures != 0 or self.mismatches.len != 0) return .failed;
        if (self.truncated or self.executed != self.planned) return .incomplete;
        if (self.executed != 0 and self.unsupported == self.executed) return .unsupported;
        return .passed;
    }

    pub fn evidenceSummary(self: Report) Contract.EvidenceSummary {
        const failed = self.executor_failures + self.mismatches.len;
        return .{
            .attempted = true,
            .status = self.status(),
            .planned = self.planned,
            .executed = self.executed,
            .passed = self.executed -| self.unsupported -| self.executor_failures -| self.mismatches.len,
            .failed = failed,
            .unsupported = self.unsupported,
            .truncated = self.truncated,
            .replay_token = self.replay_token,
        };
    }

    pub fn jsonAlloc(self: Report, allocator: std.mem.Allocator) ![]u8 {
        return std.json.Stringify.valueAlloc(allocator, .{
            .schema = "zigeffect.test-differential.v1",
            .status = @tagName(self.status()),
            .planned = self.planned,
            .executed = self.executed,
            .unsupported = self.unsupported,
            .executor_failures = self.executor_failures,
            .mismatch_count = self.mismatches.len,
            .truncated = self.truncated,
            .replay_token = self.replay_token,
            .mismatches = self.mismatches,
        }, .{});
    }
};

pub fn runAlloc(allocator: std.mem.Allocator, cases: []const Case, executors: []const Executor, options: Options) !Report {
    if (executors.len < 2 or options.max_executions == 0) return error.InvalidBounds;
    var mismatches = std.ArrayList(Mismatch).empty;
    errdefer deinitMismatchList(allocator, &mismatches);
    var executed: usize = 0;
    var unsupported: usize = 0;
    var executor_failures: usize = 0;
    var stop = false;
    for (cases) |case| {
        if (stop) break;
        var baseline: ?Outcome = null;
        for (executors, 0..) |executor, executor_index| {
            if (executed == options.max_executions) {
                stop = true;
                break;
            }
            executed += 1;
            const outcome = executor.run(case.input, allocator) catch {
                executor_failures += 1;
                continue;
            };
            switch (outcome.status) {
                .unsupported => unsupported += 1,
                .failed => executor_failures += 1,
                .passed => if (executor_index == 0) {
                    baseline = outcome;
                } else if (baseline) |expected| {
                    if (!(try equivalentJson(allocator, expected.output, outcome.output, options.ignored_fields))) {
                        const owned = try cloneMismatch(allocator, .{
                            .case_id = case.id,
                            .baseline_executor = executors[0].name,
                            .compared_executor = executor.name,
                            .baseline_output = expected.output,
                            .compared_output = outcome.output,
                        });
                        errdefer deinitMismatch(allocator, owned);
                        try mismatches.append(allocator, owned);
                    }
                },
            }
        }
    }
    const replay = if (mismatches.items.len == 0)
        try allocator.dupe(u8, "")
    else
        try std.fmt.allocPrint(allocator, "{s} --case {s}", .{ options.replay_prefix, mismatches.items[0].case_id });
    return .{
        .allocator = allocator,
        .planned = cases.len * executors.len,
        .executed = executed,
        .unsupported = unsupported,
        .executor_failures = executor_failures,
        .mismatches = try mismatches.toOwnedSlice(allocator),
        .truncated = executed != cases.len * executors.len,
        .replay_token = replay,
    };
}

fn equivalentJson(allocator: std.mem.Allocator, left: []const u8, right: []const u8, ignored: []const []const u8) !bool {
    var left_value = std.json.parseFromSlice(std.json.Value, allocator, left, .{}) catch return std.mem.eql(u8, left, right);
    defer left_value.deinit();
    var right_value = std.json.parseFromSlice(std.json.Value, allocator, right, .{}) catch return std.mem.eql(u8, left, right);
    defer right_value.deinit();
    return equivalentValue(left_value.value, right_value.value, ignored);
}

fn equivalentValue(left: std.json.Value, right: std.json.Value, ignored: []const []const u8) bool {
    if (@intFromEnum(left) != @intFromEnum(right)) return false;
    return switch (left) {
        .null => true,
        .bool => |value| value == right.bool,
        .integer => |value| value == right.integer,
        .float => |value| value == right.float,
        .number_string => |value| std.mem.eql(u8, value, right.number_string),
        .string => |value| std.mem.eql(u8, value, right.string),
        .array => |values| blk: {
            if (values.items.len != right.array.items.len) break :blk false;
            for (values.items, right.array.items) |a, b| if (!equivalentValue(a, b, ignored)) break :blk false;
            break :blk true;
        },
        .object => |object| blk: {
            var relevant: usize = 0;
            var iterator = object.iterator();
            while (iterator.next()) |entry| {
                if (isIgnored(entry.key_ptr.*, ignored)) continue;
                relevant += 1;
                const other = right.object.get(entry.key_ptr.*) orelse break :blk false;
                if (!equivalentValue(entry.value_ptr.*, other, ignored)) break :blk false;
            }
            var other_relevant: usize = 0;
            var other_iterator = right.object.iterator();
            while (other_iterator.next()) |entry| if (!isIgnored(entry.key_ptr.*, ignored)) {
                other_relevant += 1;
            };
            break :blk relevant == other_relevant;
        },
    };
}

fn isIgnored(name: []const u8, ignored: []const []const u8) bool {
    for (ignored) |candidate| if (std.mem.eql(u8, name, candidate)) return true;
    return false;
}

fn cloneMismatch(allocator: std.mem.Allocator, item: Mismatch) !Mismatch {
    const case_id = try allocator.dupe(u8, item.case_id);
    errdefer allocator.free(case_id);
    const baseline_executor = try allocator.dupe(u8, item.baseline_executor);
    errdefer allocator.free(baseline_executor);
    const compared_executor = try allocator.dupe(u8, item.compared_executor);
    errdefer allocator.free(compared_executor);
    const baseline_output = try allocator.dupe(u8, item.baseline_output);
    errdefer allocator.free(baseline_output);
    return .{
        .case_id = case_id,
        .baseline_executor = baseline_executor,
        .compared_executor = compared_executor,
        .baseline_output = baseline_output,
        .compared_output = try allocator.dupe(u8, item.compared_output),
    };
}

fn deinitMismatch(allocator: std.mem.Allocator, item: Mismatch) void {
    allocator.free(item.case_id);
    allocator.free(item.baseline_executor);
    allocator.free(item.compared_executor);
    allocator.free(item.baseline_output);
    allocator.free(item.compared_output);
}

fn deinitMismatchList(allocator: std.mem.Allocator, items: *std.ArrayList(Mismatch)) void {
    for (items.items) |item| deinitMismatch(allocator, item);
    items.deinit(allocator);
}

test "differential execution normalizes ignored fields and retains smallest mismatch" {
    const State = struct { output: []const u8, status: OutcomeStatus = .passed };
    const Adapter = struct {
        fn run(raw: *anyopaque, _: []const u8, _: std.mem.Allocator) !Outcome {
            const state: *State = @ptrCast(@alignCast(raw));
            return .{ .status = state.status, .output = state.output };
        }
    };
    var baseline = State{ .output = "{\"value\":1,\"request_id\":\"a\"}" };
    var equal = State{ .output = "{\"request_id\":\"b\",\"value\":1}" };
    var different = State{ .output = "{\"value\":2}" };
    var report = try runAlloc(std.testing.allocator, &.{.{ .id = "case-a", .input = "{}" }}, &.{
        .{ .name = "baseline", .state = &baseline, .run_fn = Adapter.run },
        .{ .name = "equal", .state = &equal, .run_fn = Adapter.run },
        .{ .name = "different", .state = &different, .run_fn = Adapter.run },
    }, .{ .ignored_fields = &.{"request_id"} });
    defer report.deinit();
    try std.testing.expectEqual(@as(usize, 1), report.mismatches.len);
    try std.testing.expectEqual(Contract.TestStatus.failed, report.status());
    try std.testing.expect(std.mem.indexOf(u8, report.replay_token, "case-a") != null);
}

test "differential execution reports unsupported and truncation truthfully" {
    const Adapter = struct {
        fn run(_: *anyopaque, _: []const u8, _: std.mem.Allocator) !Outcome {
            return .{ .status = .unsupported };
        }
    };
    var state: u8 = 0;
    var report = try runAlloc(std.testing.allocator, &.{ .{ .id = "a", .input = "" }, .{ .id = "b", .input = "" } }, &.{
        .{ .name = "a", .state = &state, .run_fn = Adapter.run }, .{ .name = "b", .state = &state, .run_fn = Adapter.run },
    }, .{ .max_executions = 2 });
    defer report.deinit();
    try std.testing.expectEqual(Contract.TestStatus.incomplete, report.status());
    try std.testing.expect(report.truncated);
}
