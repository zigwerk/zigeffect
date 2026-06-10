const std = @import("std");
const causal_run = @import("causal_run");

pub const matrix_schema = "zigeffect.causal.test-matrix.v1";

pub const CoverageStatus = enum {
    covered,
    partial,
    missing,
};

const DomainExpectation = struct {
    domain: causal_run.CausalCoverageDomain,
    status: CoverageStatus,
    note: []const u8,
};

const MatrixRow = struct {
    domain: causal_run.CausalCoverageDomain,
    status: CoverageStatus,
    scenarios: []const []const u8,
    invariants: []const []const u8,
    note: []const u8,
};

const Matrix = struct {
    rows: []MatrixRow,
    scenario_count: usize,
    invariant_count: usize,

    fn deinit(self: Matrix, allocator: std.mem.Allocator) void {
        for (self.rows) |row| {
            allocator.free(row.scenarios);
            allocator.free(row.invariants);
        }
        allocator.free(self.rows);
    }
};

const domain_expectations: []const DomainExpectation = &.{
    .{
        .domain = .service,
        .status = .covered,
        .note = "service requirements have compile-fail and runtime graph evidence",
    },
    .{
        .domain = .layer,
        .status = .covered,
        .note = "layer graph startup and readiness scenarios record causal graph evidence",
    },
    .{
        .domain = .scope,
        .status = .covered,
        .note = "scope close and cleanup scenarios assert causal lifecycle events",
    },
    .{
        .domain = .fiber,
        .status = .covered,
        .note = "scoped fiber scenarios assert fork, interruption, and join causality",
    },
    .{
        .domain = .schedule,
        .status = .covered,
        .note = "schedule decisions are asserted in retry scenarios and tests",
    },
    .{
        .domain = .config,
        .status = .partial,
        .note = "config failures are covered through service/layer examples but need a named config invariant",
    },
    .{
        .domain = .resource,
        .status = .covered,
        .note = "resource acquisition and finalization events are asserted directly",
    },
    .{
        .domain = .retry,
        .status = .covered,
        .note = "retry exhaustion is recorded as causal schedule evidence",
    },
    .{
        .domain = .cause,
        .status = .partial,
        .note = "cause evidence is present in cleanup/runtime tests but needs a dedicated cause invariant",
    },
    .{
        .domain = .observability,
        .status = .covered,
        .note = "causal readiness records log, metric, and span observability events",
    },
    .{
        .domain = .workflow,
        .status = .covered,
        .note = "workflow crash recovery records durable suspend, resume, retry, and failure evidence",
    },
};

fn scenarioCovers(scenario: causal_run.Scenario, domain: causal_run.CausalCoverageDomain) bool {
    for (scenario.coverage_domains) |candidate| {
        if (candidate == domain) return true;
    }
    return false;
}

fn invariantMatchesDomain(invariant: causal_run.Invariant, domain: causal_run.CausalCoverageDomain) bool {
    return switch (domain) {
        .service => invariant.subsystem == .service_resolution,
        .layer => invariant.subsystem == .service_resolution or invariant.subsystem == .scope_lifecycle,
        .scope => invariant.subsystem == .scope_lifecycle,
        .fiber => invariant.subsystem == .fiber_runtime,
        .schedule, .retry => invariant.subsystem == .schedule_retry,
        .config => invariant.subsystem == .service_resolution,
        .resource => invariant.subsystem == .scope_lifecycle,
        .cause => invariant.finding_kind != null,
        .observability => invariant.subsystem == .observability,
        .workflow => invariant.subsystem == .workflow_runtime,
    };
}

fn collectScenarioNames(
    allocator: std.mem.Allocator,
    domain: causal_run.CausalCoverageDomain,
) ![]const []const u8 {
    var names = std.ArrayList([]const u8).empty;
    errdefer names.deinit(allocator);

    for (causal_run.scenarioRegistry()) |scenario| {
        if (scenarioCovers(scenario, domain)) {
            try names.append(allocator, scenario.slug);
        }
    }

    return names.toOwnedSlice(allocator);
}

fn collectInvariantNames(
    allocator: std.mem.Allocator,
    domain: causal_run.CausalCoverageDomain,
) ![]const []const u8 {
    var names = std.ArrayList([]const u8).empty;
    errdefer names.deinit(allocator);

    for (causal_run.invariantCatalog()) |invariant| {
        if (invariantMatchesDomain(invariant, domain)) {
            try names.append(allocator, invariant.id);
        }
    }

    return names.toOwnedSlice(allocator);
}

fn validateUniqueNames(names: []const []const u8) !void {
    for (names, 0..) |name, index| {
        for (names[index + 1 ..]) |candidate| {
            if (std.mem.eql(u8, name, candidate)) return error.DuplicateName;
        }
    }
}

fn validateRegistry() !void {
    var scenario_names: [64][]const u8 = undefined;
    var scenario_count: usize = 0;
    for (causal_run.scenarioRegistry()) |scenario| {
        if (scenario.coverage_domains.len == 0) return error.MissingCoverageDomain;
        if (scenario_count >= scenario_names.len) return error.TooManyNames;
        scenario_names[scenario_count] = scenario.slug;
        scenario_count += 1;

        for (scenario.invariant_ids) |id| {
            _ = try causal_run.invariantById(id);
        }
    }
    try validateUniqueNames(scenario_names[0..scenario_count]);

    var invariant_names: [64][]const u8 = undefined;
    var invariant_count: usize = 0;
    for (causal_run.invariantCatalog()) |invariant| {
        if (invariant_count >= invariant_names.len) return error.TooManyNames;
        invariant_names[invariant_count] = invariant.id;
        invariant_count += 1;
    }
    try validateUniqueNames(invariant_names[0..invariant_count]);
}

fn buildMatrix(allocator: std.mem.Allocator) !Matrix {
    try validateRegistry();

    var rows = std.ArrayList(MatrixRow).empty;
    errdefer {
        for (rows.items) |row| {
            allocator.free(row.scenarios);
            allocator.free(row.invariants);
        }
        rows.deinit(allocator);
    }

    for (domain_expectations) |expectation| {
        const scenarios = try collectScenarioNames(allocator, expectation.domain);
        errdefer allocator.free(scenarios);
        const invariants = try collectInvariantNames(allocator, expectation.domain);
        errdefer allocator.free(invariants);

        try rows.append(allocator, .{
            .domain = expectation.domain,
            .status = expectation.status,
            .scenarios = scenarios,
            .invariants = invariants,
            .note = expectation.note,
        });
    }

    return .{
        .rows = try rows.toOwnedSlice(allocator),
        .scenario_count = causal_run.scenarioRegistry().len,
        .invariant_count = causal_run.invariantCatalog().len,
    };
}

fn rowByDomain(matrix: Matrix, domain: causal_run.CausalCoverageDomain) ?MatrixRow {
    for (matrix.rows) |row| {
        if (row.domain == domain) return row;
    }
    return null;
}

fn contains(values: []const []const u8, expected: []const u8) bool {
    for (values) |value| {
        if (std.mem.eql(u8, value, expected)) return true;
    }
    return false;
}

pub fn formatMatrix(allocator: std.mem.Allocator, matrix: Matrix) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal test matrix\n");
    try output.print(allocator, "schema: {s}\n", .{matrix_schema});
    try output.print(allocator, "coverage domains: {d}\n", .{matrix.rows.len});
    try output.print(allocator, "scenarios: {d}\n", .{matrix.scenario_count});
    try output.print(allocator, "invariants: {d}\n", .{matrix.invariant_count});

    for (matrix.rows) |row| {
        try output.print(allocator, "\n- domain {s}\n", .{@tagName(row.domain)});
        try output.print(allocator, "  status: {s}\n", .{@tagName(row.status)});
        try output.appendSlice(allocator, "  scenarios:");
        for (row.scenarios) |scenario| {
            try output.print(allocator, " {s}", .{scenario});
        }
        try output.append(allocator, '\n');
        try output.appendSlice(allocator, "  invariants:");
        for (row.invariants) |invariant| {
            try output.print(allocator, " {s}", .{invariant});
        }
        try output.append(allocator, '\n');
        try output.print(allocator, "  notes: {s}\n", .{row.note});
    }

    return output.toOwnedSlice(allocator);
}

pub fn main(init: std.process.Init) !void {
    const matrix = try buildMatrix(init.gpa);
    defer matrix.deinit(init.gpa);

    const text = try formatMatrix(init.gpa, matrix);
    defer init.gpa.free(text);

    std.debug.print("{s}", .{text});
}

test "matrix builds requested coverage domains from the scenario registry" {
    const matrix = try buildMatrix(std.testing.allocator);
    defer matrix.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 11), matrix.rows.len);
    try std.testing.expect(rowByDomain(matrix, .service) != null);
    try std.testing.expect(rowByDomain(matrix, .layer) != null);
    try std.testing.expect(rowByDomain(matrix, .scope) != null);
    try std.testing.expect(rowByDomain(matrix, .fiber) != null);
    try std.testing.expect(rowByDomain(matrix, .schedule) != null);
    try std.testing.expect(rowByDomain(matrix, .config) != null);
    try std.testing.expect(rowByDomain(matrix, .resource) != null);
    try std.testing.expect(rowByDomain(matrix, .retry) != null);
    try std.testing.expect(rowByDomain(matrix, .cause) != null);
    try std.testing.expect(rowByDomain(matrix, .observability) != null);
    try std.testing.expect(rowByDomain(matrix, .workflow) != null);

    const observability = rowByDomain(matrix, .observability).?;
    try std.testing.expectEqual(CoverageStatus.covered, observability.status);
    try std.testing.expect(contains(observability.scenarios, "causal-readiness"));

    const workflow = rowByDomain(matrix, .workflow).?;
    try std.testing.expectEqual(CoverageStatus.covered, workflow.status);
    try std.testing.expect(contains(workflow.scenarios, "workflow-crash-recovery"));
    try std.testing.expect(contains(workflow.invariants, "workflow-crash-recovery-preserves-durable-evidence"));
}

test "matrix formatter prints schema statuses scenarios and invariants" {
    const matrix = try buildMatrix(std.testing.allocator);
    defer matrix.deinit(std.testing.allocator);

    const text = try formatMatrix(std.testing.allocator, matrix);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect causal test matrix") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "schema: zigeffect.causal.test-matrix.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "- domain observability") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "status: covered") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "scenarios:") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "causal-readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "invariants:") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "observability-events-are-sampleable") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "- domain workflow") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "workflow-crash-recovery") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "workflow-crash-recovery-preserves-durable-evidence") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "- domain config") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "status: partial") != null);
}

test "matrix validation catches duplicate scenario and invariant ids" {
    try validateUniqueNames(&.{ "a", "b", "c" });
    try std.testing.expectError(error.DuplicateName, validateUniqueNames(&.{ "a", "b", "a" }));
}
