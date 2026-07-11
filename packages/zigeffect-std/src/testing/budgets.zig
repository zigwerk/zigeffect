const std = @import("std");
const Contract = @import("contract.zig");

pub const MetricKind = enum { deterministic_steps, allocations, peak_bytes, duration_ns };
pub const Metric = struct { id: []const u8, kind: MetricKind, value: u64 };

pub const Budget = struct {
    id: []const u8,
    metric_id: []const u8,
    absolute_max: ?u64 = null,
    baseline: ?u64 = null,
    /// 1000 means 1.0x, 1250 means 1.25x.
    relative_max_milli: ?u32 = null,
    deterministic_required: bool = true,
};

pub const Outcome = enum { passed, failed, unsupported };
pub const Evaluation = struct { budget: Budget, measured: ?u64, allowed: ?u64, outcome: Outcome, detail: []const u8 = "" };

pub const Report = struct {
    allocator: std.mem.Allocator,
    evaluations: []Evaluation,
    passed: usize,
    failed: usize,
    unsupported: usize,

    pub fn deinit(self: *Report) void {
        self.allocator.free(self.evaluations);
    }

    pub fn status(self: Report) Contract.TestStatus {
        if (self.failed != 0) return .failed;
        if (self.passed == 0 and self.unsupported != 0) return .unsupported;
        return .passed;
    }

    pub fn evidenceSummary(self: Report) Contract.EvidenceSummary {
        return .{
            .attempted = true,
            .status = self.status(),
            .planned = self.evaluations.len,
            .executed = self.evaluations.len,
            .passed = self.passed,
            .failed = self.failed,
            .unsupported = self.unsupported,
        };
    }

    pub fn jsonAlloc(self: Report, allocator: std.mem.Allocator) ![]u8 {
        return std.json.Stringify.valueAlloc(allocator, .{
            .schema = "zigeffect.test-performance.v1",
            .status = @tagName(self.status()),
            .passed = self.passed,
            .failed = self.failed,
            .unsupported = self.unsupported,
            .evaluations = self.evaluations,
        }, .{});
    }
};

pub fn evaluateAlloc(allocator: std.mem.Allocator, metrics: []const Metric, budgets: []const Budget) !Report {
    var evaluations = std.ArrayList(Evaluation).empty;
    errdefer evaluations.deinit(allocator);
    var passed: usize = 0;
    var failed: usize = 0;
    var unsupported: usize = 0;
    for (budgets, 0..) |budget, index| {
        if (budget.id.len == 0 or budget.metric_id.len == 0 or (budget.absolute_max == null and (budget.baseline == null or budget.relative_max_milli == null))) return error.InvalidBudget;
        for (budgets[0..index]) |previous| if (std.mem.eql(u8, previous.id, budget.id)) return error.DuplicateBudget;
        var metric: ?Metric = null;
        for (metrics) |candidate| if (std.mem.eql(u8, candidate.id, budget.metric_id)) {
            metric = candidate;
            break;
        };
        if (metric == null or (metric.?.kind == .duration_ns and budget.deterministic_required)) {
            unsupported += 1;
            try evaluations.append(allocator, .{ .budget = budget, .measured = if (metric) |m| m.value else null, .allowed = null, .outcome = .unsupported, .detail = if (metric == null) "metric missing" else "wall-clock metric rejected by deterministic budget" });
            continue;
        }
        var allowed = budget.absolute_max orelse std.math.maxInt(u64);
        if (budget.baseline) |baseline| if (budget.relative_max_milli) |ratio| {
            const scaled: u128 = @as(u128, baseline) * @as(u128, ratio);
            const relative: u64 = std.math.cast(u64, scaled / 1000) orelse return error.BudgetOverflow;
            allowed = @min(allowed, relative);
        };
        const outcome: Outcome = if (metric.?.value <= allowed) .passed else .failed;
        if (outcome == .passed) passed += 1 else failed += 1;
        try evaluations.append(allocator, .{ .budget = budget, .measured = metric.?.value, .allowed = allowed, .outcome = outcome });
    }
    return .{ .allocator = allocator, .evaluations = try evaluations.toOwnedSlice(allocator), .passed = passed, .failed = failed, .unsupported = unsupported };
}

pub const BaselinePlan = struct {
    allocator: std.mem.Allocator,
    expected_digest: []const u8,
    proposed: []const u8,
    pub fn deinit(self: *BaselinePlan) void {
        self.allocator.free(self.expected_digest);
        self.allocator.free(self.proposed);
    }
    pub fn verifyCurrent(self: BaselinePlan, current: []const u8) !void {
        const digest = try digestAlloc(self.allocator, current);
        defer self.allocator.free(digest);
        if (!std.mem.eql(u8, digest, self.expected_digest)) return error.StaleBaseline;
    }
};

pub fn planBaselineAlloc(allocator: std.mem.Allocator, current: []const u8, metrics: []const Metric) !BaselinePlan {
    return .{
        .allocator = allocator,
        .expected_digest = try digestAlloc(allocator, current),
        .proposed = try std.json.Stringify.valueAlloc(allocator, .{ .schema = "zigeffect.test-performance-baseline.v1", .metrics = metrics }, .{ .whitespace = .indent_2 }),
    };
}

fn digestAlloc(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(value, &digest, .{});
    return std.fmt.allocPrint(allocator, "sha256:{x}", .{digest});
}

test "performance budgets enforce absolute and relative deterministic metrics" {
    var report = try evaluateAlloc(std.testing.allocator, &.{
        .{ .id = "steps", .kind = .deterministic_steps, .value = 110 },
        .{ .id = "wall", .kind = .duration_ns, .value = 10 },
    }, &.{
        .{ .id = "steps-absolute", .metric_id = "steps", .absolute_max = 120 },
        .{ .id = "steps-relative", .metric_id = "steps", .baseline = 100, .relative_max_milli = 1050 },
        .{ .id = "wall-deterministic", .metric_id = "wall", .absolute_max = 20 },
    });
    defer report.deinit();
    try std.testing.expectEqual(@as(usize, 1), report.passed);
    try std.testing.expectEqual(@as(usize, 1), report.failed);
    try std.testing.expectEqual(@as(usize, 1), report.unsupported);
    try std.testing.expectEqual(Contract.TestStatus.failed, report.status());
}

test "performance baseline plan detects stale apply and serializes measurements" {
    var plan = try planBaselineAlloc(std.testing.allocator, "old", &.{.{ .id = "steps", .kind = .deterministic_steps, .value = 9 }});
    defer plan.deinit();
    try plan.verifyCurrent("old");
    try std.testing.expectError(error.StaleBaseline, plan.verifyCurrent("changed"));
    try std.testing.expect(std.mem.indexOf(u8, plan.proposed, "steps") != null);
}
