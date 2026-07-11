const std = @import("std");
const Contract = @import("contract.zig");

pub const report_schema = "zigeffect.test-coverage.v1";

pub const Gap = struct {
    target: Contract.CoverageTarget,
};

pub const Report = struct {
    allocator: std.mem.Allocator,
    targets: []Contract.CoverageTarget,
    hits: []Contract.CoverageHit,
    gaps: []Gap,
    summary: Contract.CoverageSummary,

    pub fn deinit(self: *Report) void {
        self.allocator.free(self.targets);
        self.allocator.free(self.hits);
        self.allocator.free(self.gaps);
    }

    pub fn hasGap(self: Report, id: []const u8) bool {
        for (self.gaps) |gap| if (std.mem.eql(u8, gap.target.id, id)) return true;
        return false;
    }

    pub fn jsonAlloc(self: Report, allocator: std.mem.Allocator) ![]u8 {
        return std.json.Stringify.valueAlloc(allocator, .{
            .schema = report_schema,
            .schema_version = 1,
            .summary = self.summary,
            .targets = self.targets,
            .hits = self.hits,
            .gaps = self.gaps,
        }, .{});
    }
};

pub fn analyzeAlloc(
    allocator: std.mem.Allocator,
    targets: []const Contract.CoverageTarget,
    hits: []const Contract.CoverageHit,
    truncated: bool,
) !Report {
    for (targets, 0..) |target, index| {
        try target.validate();
        for (targets[0..index]) |previous| if (std.mem.eql(u8, target.id, previous.id)) return error.DuplicateCoverageTarget;
    }
    for (hits, 0..) |hit, index| {
        try hit.validate();
        var target_found = false;
        for (targets) |target| if (std.mem.eql(u8, target.id, hit.target_id)) {
            target_found = true;
            break;
        };
        if (!target_found) return error.UnknownCoverageTarget;
        for (hits[0..index]) |previous| {
            if (std.mem.eql(u8, previous.target_id, hit.target_id) and std.mem.eql(u8, previous.evidence_id, hit.evidence_id)) return error.DuplicateCoverageHit;
        }
    }

    const owned_targets = try allocator.dupe(Contract.CoverageTarget, targets);
    errdefer allocator.free(owned_targets);
    const owned_hits = try allocator.dupe(Contract.CoverageHit, hits);
    errdefer allocator.free(owned_hits);
    var gaps = std.ArrayList(Gap).empty;
    errdefer gaps.deinit(allocator);
    var required_gaps: usize = 0;
    var advisory_gaps: usize = 0;
    for (targets) |target| {
        var covered = false;
        for (hits) |hit| if (std.mem.eql(u8, target.id, hit.target_id)) {
            covered = true;
            break;
        };
        if (covered) continue;
        try gaps.append(allocator, .{ .target = target });
        if (target.required) required_gaps += 1 else advisory_gaps += 1;
    }
    return .{
        .allocator = allocator,
        .targets = owned_targets,
        .hits = owned_hits,
        .gaps = try gaps.toOwnedSlice(allocator),
        .summary = .{
            .targets = targets.len,
            .hits = hits.len,
            .required_gaps = required_gaps,
            .advisory_gaps = advisory_gaps,
            .truncated = truncated,
        },
    };
}

pub fn analyzeReceiptAlloc(allocator: std.mem.Allocator, receipt: Contract.TestReceipt) !Report {
    if (receipt.coverage_targets.len != 0) {
        return analyzeAlloc(allocator, receipt.coverage_targets, receipt.coverage_hits, receipt.coverage.truncated);
    }

    var targets = std.ArrayList(Contract.CoverageTarget).empty;
    defer targets.deinit(allocator);
    var hits = std.ArrayList(Contract.CoverageHit).empty;
    defer hits.deinit(allocator);

    try targets.append(allocator, .{
        .id = "native-receipt",
        .label = "test process published native structured evidence",
        .dimension = .requirement,
        .required = true,
        .repair_hint = "publish through zstd.Testing.TestContext.publish",
    });
    try targets.append(allocator, .{
        .id = "acceptance-assertion",
        .label = "at least one acceptance assertion passed",
        .dimension = .acceptance,
        .required = true,
        .repair_hint = "record the user-visible acceptance condition",
    });
    try targets.append(allocator, .{
        .id = "causal-clean",
        .label = "runtime causal invariants are clean",
        .dimension = .causal,
        .required = true,
        .repair_hint = "repair findings, leaked resources, or pending fibers",
    });
    try targets.append(allocator, .{
        .id = "source-linked",
        .label = "assertions identify responsible source",
        .dimension = .assertion,
        .required = false,
        .repair_hint = "add a source reference to the acceptance assertion",
    });
    if (receipt.scenario.fault_profile != .none) try targets.append(allocator, .{
        .id = "fault-exploration",
        .label = "declared fault profile was exercised",
        .dimension = .fault,
        .required = false,
        .repair_hint = "run the scenario with its declared fault profile",
    });
    try targets.append(allocator, .{
        .id = "performance-contract",
        .label = "a performance budget guards the requirement",
        .dimension = .performance,
        .required = false,
        .repair_hint = "attach a deterministic performance budget",
    });
    try targets.append(allocator, .{
        .id = "side-effect-firewall",
        .label = "real side effects are capability checked",
        .dimension = .sandbox,
        .required = false,
        .repair_hint = "run boundaries through the TestContext firewall",
    });

    if (receipt.execution.native_receipt) try hits.append(allocator, .{ .target_id = "native-receipt", .evidence_id = "process-receipt" });
    var has_passed_assertion = false;
    var has_source = false;
    for (receipt.assertions) |assertion| {
        if (assertion.status == .passed) has_passed_assertion = true;
        if (assertion.source.path.len != 0) has_source = true;
    }
    if (has_passed_assertion) try hits.append(allocator, .{ .target_id = "acceptance-assertion", .evidence_id = "assertions" });
    if (receipt.causal.clean()) try hits.append(allocator, .{ .target_id = "causal-clean", .evidence_id = "causal-summary" });
    if (has_source) try hits.append(allocator, .{ .target_id = "source-linked", .evidence_id = "source-reference" });
    if (receipt.scenario.fault_profile != .none and receipt.fault_kind != .none) try hits.append(allocator, .{ .target_id = "fault-exploration", .evidence_id = "fault-case" });

    return analyzeAlloc(allocator, targets.items, hits.items, !receipt.completeness.complete());
}

fn scenario() Contract.Scenario {
    return .{
        .id = "coverage",
        .label = "semantic coverage",
        .requirement = "req-coverage",
        .acceptance_check = "check-coverage",
        .component = "std-testing",
        .command = "test",
    };
}

test "explicit semantic coverage distinguishes required and advisory gaps" {
    const targets = [_]Contract.CoverageTarget{
        .{ .id = "acceptance", .label = "acceptance assertion", .dimension = .acceptance, .required = true },
        .{ .id = "timeout", .label = "timeout recovery", .dimension = .fault, .required = false, .repair_hint = "run the timeout fault" },
    };
    const hits = [_]Contract.CoverageHit{.{ .target_id = "acceptance", .evidence_id = "assert-order" }};
    var report = try analyzeAlloc(std.testing.allocator, targets[0..], hits[0..], false);
    defer report.deinit();
    try std.testing.expectEqual(@as(usize, 0), report.summary.required_gaps);
    try std.testing.expectEqual(@as(usize, 1), report.summary.advisory_gaps);
    try std.testing.expectEqualStrings("timeout", report.gaps[0].target.id);
}

test "receipt analysis exposes missing native evidence and assertion gaps" {
    const receipt = Contract.TestReceipt{
        .project = "demo",
        .suite = "acceptance",
        .scenario = scenario(),
        .source_revision = "working-tree",
        .zig_version = @import("builtin").zig_version_string,
        .status = .incomplete,
        .seed = 1,
        .completeness = .{ .dropped_diagnostics = 1 },
    };
    var report = try analyzeReceiptAlloc(std.testing.allocator, receipt);
    defer report.deinit();
    try std.testing.expect(report.summary.required_gaps >= 2);
    try std.testing.expect(report.hasGap("native-receipt"));
    try std.testing.expect(report.hasGap("acceptance-assertion"));
}

test "coverage truncation is incomplete and JSON remains agent readable" {
    const targets = [_]Contract.CoverageTarget{.{ .id = "one", .label = "one", .dimension = .requirement, .required = true }};
    var report = try analyzeAlloc(std.testing.allocator, targets[0..], &.{}, true);
    defer report.deinit();
    try std.testing.expect(!report.summary.complete());
    const json = try report.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"required_gaps\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"truncated\":true") != null);
}
