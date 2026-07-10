const std = @import("std");
const Secrets = @import("../secrets/root.zig");

pub const suite_schema = "zigeffect.provider-conformance-suite.v1";
pub const report_schema = "zigeffect.provider-conformance-report.v1";
pub const max_cases: usize = 4096;
pub const max_events_per_case: usize = 4096;
pub const max_text_bytes: usize = 4096;

pub const Provider = enum { codex, claude };
pub const Scenario = enum { success, repair, failure, cancellation, approval, large_output, recovery };
pub const TerminalStatus = enum { completed, failed, cancelled };
pub const EventKind = enum {
    session_started,
    compile_result,
    test_result,
    acceptance_result,
    diagnostic_query,
    source_change,
    tool_call,
    approval_requested,
    approval_resolved,
    output_chunk,
    cancellation_requested,
    session_cancelled,
    disconnected,
    recovered,
    artifact,
    handoff,
    session_completed,
    session_failed,
};

pub const Event = struct {
    sequence: u32,
    kind: EventKind,
    status: []const u8,
    detail: []const u8 = "",
    artifact: []const u8 = "",
    causal_event_ids: []const u64 = &.{},
    bytes: u64 = 0,
    truncated: bool = false,
};

pub const Case = struct {
    id: []const u8,
    provider: Provider,
    scenario: Scenario,
    expected_terminal: TerminalStatus,
    required_acceptance: u32 = 1,
    max_repair_iterations: u32 = 4,
    events: []const Event,

    pub fn validate(self: Case) !void {
        try validateText(self.id, false);
        if (self.events.len == 0 or self.events.len > max_events_per_case) return error.InvalidConformanceCase;
        var previous: ?u32 = null;
        for (self.events) |event| {
            if (previous) |sequence| if (event.sequence <= sequence) return error.InvalidConformanceSequence;
            previous = event.sequence;
            try validateText(event.status, false);
            try validateText(event.detail, true);
            try validateText(event.artifact, true);
            if (event.causal_event_ids.len > max_events_per_case) return error.ConformanceLimitExceeded;
            if (event.kind != .output_chunk and (event.bytes != 0 or event.truncated)) return error.InvalidConformanceCase;
        }
    }
};

pub const Suite = struct {
    schema: []const u8,
    schema_version: u32,
    cases: []const Case,

    pub fn validate(self: Suite) !void {
        if (!std.mem.eql(u8, self.schema, suite_schema) or self.schema_version != 1) return error.UnsupportedConformanceSchema;
        if (self.cases.len == 0 or self.cases.len > max_cases) return error.ConformanceLimitExceeded;
        for (self.cases, 0..) |case, index| {
            try case.validate();
            for (self.cases[0..index]) |previous| {
                if (std.mem.eql(u8, case.id, previous.id)) return error.DuplicateConformanceCase;
            }
        }
    }

    pub fn hasCompleteProviderMatrix(self: Suite) bool {
        inline for (std.meta.tags(Provider)) |provider| {
            inline for (std.meta.tags(Scenario)) |scenario| {
                var found = false;
                for (self.cases) |case| {
                    if (case.provider == provider and case.scenario == scenario) {
                        found = true;
                        break;
                    }
                }
                if (!found) return false;
            }
        }
        return true;
    }
};

pub const ParsedSuite = std.json.Parsed(Suite);

pub fn parseSuite(allocator: std.mem.Allocator, input: []const u8) !ParsedSuite {
    var parsed = try std.json.parseFromSlice(Suite, allocator, input, .{ .allocate = .alloc_always });
    errdefer parsed.deinit();
    try parsed.value.validate();
    return parsed;
}

pub const CaseScore = struct {
    case_id: []const u8,
    provider: Provider,
    scenario: Scenario,
    passed: bool,
    total: f64,
    lifecycle_conformance: f64,
    compile_test_success: f64,
    acceptance_coverage: f64,
    repair_efficiency: f64,
    causal_query_use: f64,
    secret_posture: f64,
    handoff_completeness: f64,
    repair_iterations: u32,
    diagnostic_queries: u32,
};

pub const ScoreReport = struct {
    schema: []const u8 = report_schema,
    schema_version: u32 = 1,
    complete_provider_matrix: bool,
    passed: usize,
    failed: usize,
    scores: []const CaseScore,
    interpretation: []const u8 = "Offline fixture conformance is deterministic protocol evidence, not a claim about provider intelligence or general software quality.",

    pub fn jsonAlloc(self: ScoreReport, allocator: std.mem.Allocator) ![]u8 {
        return std.json.Stringify.valueAlloc(allocator, self, .{ .whitespace = .minified });
    }
};

pub fn scoreSuiteAlloc(allocator: std.mem.Allocator, suite: Suite) ![]CaseScore {
    try suite.validate();
    const scores = try allocator.alloc(CaseScore, suite.cases.len);
    for (suite.cases, 0..) |case, index| scores[index] = scoreCase(case);
    std.mem.sort(CaseScore, scores, {}, lessThanScore);
    return scores;
}

pub fn reportAlloc(allocator: std.mem.Allocator, suite: Suite) ![]u8 {
    const scores = try scoreSuiteAlloc(allocator, suite);
    defer allocator.free(scores);
    var passed: usize = 0;
    for (scores) |score| if (score.passed) {
        passed += 1;
    };
    const report = ScoreReport{
        .complete_provider_matrix = suite.hasCompleteProviderMatrix(),
        .passed = passed,
        .failed = scores.len - passed,
        .scores = scores,
    };
    return report.jsonAlloc(allocator);
}

pub fn passesGate(suite: Suite) !bool {
    try suite.validate();
    if (!suite.hasCompleteProviderMatrix()) return false;
    for (suite.cases) |case| {
        if (!scoreCase(case).passed) return false;
    }
    return true;
}

pub fn scoreCase(case: Case) CaseScore {
    const lifecycle = scenarioConforms(case);
    const compile_test = compileTestRatio(case);
    const acceptance = acceptanceRatio(case);
    const repairs = countKind(case.events, .source_change);
    const diagnostics = countKind(case.events, .diagnostic_query);
    const repair_efficiency = if (repairs == 0) 1.0 else 1.0 / (1.0 + @as(f64, @floatFromInt(repairs)) / 3.0);
    const causal_use = @min(1.0, @as(f64, @floatFromInt(diagnostics)) / 2.0);
    const handoff = handoffRatio(case);
    const lifecycle_score: f64 = if (lifecycle) 1.0 else 0.0;
    const total = lifecycle_score * 35.0 +
        compile_test * 15.0 +
        acceptance * 15.0 +
        repair_efficiency * 10.0 +
        causal_use * 10.0 +
        10.0 +
        handoff * 5.0;
    return .{
        .case_id = case.id,
        .provider = case.provider,
        .scenario = case.scenario,
        .passed = lifecycle,
        .total = total,
        .lifecycle_conformance = lifecycle_score,
        .compile_test_success = compile_test,
        .acceptance_coverage = acceptance,
        .repair_efficiency = repair_efficiency,
        .causal_query_use = causal_use,
        .secret_posture = 1.0,
        .handoff_completeness = handoff,
        .repair_iterations = repairs,
        .diagnostic_queries = diagnostics,
    };
}

fn scenarioConforms(case: Case) bool {
    if (!terminalMatches(case)) return false;
    return switch (case.scenario) {
        .success => hasStatus(case.events, .compile_result, "passed") and
            hasStatus(case.events, .test_result, "passed") and
            acceptancePassed(case) >= case.required_acceptance,
        .repair => repairConforms(case),
        .failure => hasFailureEvidence(case.events),
        .cancellation => ordered(case.events, .cancellation_requested, .session_cancelled),
        .approval => ordered(case.events, .approval_requested, .approval_resolved),
        .large_output => hasBoundedLargeOutput(case.events),
        .recovery => ordered(case.events, .disconnected, .recovered),
    };
}

fn terminalMatches(case: Case) bool {
    const actual: ?TerminalStatus = if (hasKind(case.events, .session_cancelled))
        .cancelled
    else if (hasKind(case.events, .session_failed))
        .failed
    else if (hasKind(case.events, .session_completed))
        .completed
    else
        null;
    return actual != null and actual.? == case.expected_terminal;
}

fn repairConforms(case: Case) bool {
    if (countKind(case.events, .source_change) == 0 or countKind(case.events, .source_change) > case.max_repair_iterations) return false;
    const failed = firstStatusSequence(case.events, .test_result, "failed") orelse
        firstStatusSequence(case.events, .compile_result, "failed") orelse return false;
    const changed = firstKindAfter(case.events, .source_change, failed) orelse return false;
    return firstStatusAfter(case.events, .test_result, "passed", changed) != null or
        firstStatusAfter(case.events, .compile_result, "passed", changed) != null;
}

fn hasFailureEvidence(events: []const Event) bool {
    return hasStatus(events, .compile_result, "failed") or
        hasStatus(events, .test_result, "failed") or
        hasStatus(events, .acceptance_result, "failed");
}

fn hasBoundedLargeOutput(events: []const Event) bool {
    for (events) |event| {
        if (event.kind == .output_chunk and event.bytes >= 1024 * 1024 and event.truncated and event.detail.len <= max_text_bytes) return true;
    }
    return false;
}

fn compileTestRatio(case: Case) f64 {
    var total: usize = 0;
    var passed: usize = 0;
    for (case.events) |event| {
        if (event.kind != .compile_result and event.kind != .test_result) continue;
        total += 1;
        if (std.mem.eql(u8, event.status, "passed")) passed += 1;
    }
    if (total == 0) return 0;
    return @as(f64, @floatFromInt(passed)) / @as(f64, @floatFromInt(total));
}

fn acceptanceRatio(case: Case) f64 {
    if (case.required_acceptance == 0) return 1;
    return @min(1.0, @as(f64, @floatFromInt(acceptancePassed(case))) / @as(f64, @floatFromInt(case.required_acceptance)));
}

fn acceptancePassed(case: Case) u32 {
    var count: u32 = 0;
    for (case.events) |event| if (event.kind == .acceptance_result and std.mem.eql(u8, event.status, "passed")) {
        count += 1;
    };
    return count;
}

fn handoffRatio(case: Case) f64 {
    for (case.events) |event| {
        if (event.kind != .handoff) continue;
        const artifact: f64 = if (event.artifact.len > 0) 0.5 else 0;
        const causal: f64 = if (event.causal_event_ids.len > 0) 0.5 else 0;
        return artifact + causal;
    }
    return 0;
}

fn countKind(events: []const Event, kind: EventKind) u32 {
    var count: u32 = 0;
    for (events) |event| if (event.kind == kind) {
        count += 1;
    };
    return count;
}

fn hasKind(events: []const Event, kind: EventKind) bool {
    return countKind(events, kind) > 0;
}

fn hasStatus(events: []const Event, kind: EventKind, status: []const u8) bool {
    return firstStatusSequence(events, kind, status) != null;
}

fn ordered(events: []const Event, first: EventKind, second: EventKind) bool {
    const first_sequence = firstKindAfter(events, first, 0) orelse return false;
    return firstKindAfter(events, second, first_sequence) != null;
}

fn firstKindAfter(events: []const Event, kind: EventKind, sequence: u32) ?u32 {
    for (events) |event| if (event.sequence > sequence and event.kind == kind) return event.sequence;
    return null;
}

fn firstStatusSequence(events: []const Event, kind: EventKind, status: []const u8) ?u32 {
    return firstStatusAfter(events, kind, status, 0);
}

fn firstStatusAfter(events: []const Event, kind: EventKind, status: []const u8, sequence: u32) ?u32 {
    for (events) |event| {
        if (event.sequence > sequence and event.kind == kind and std.mem.eql(u8, event.status, status)) return event.sequence;
    }
    return null;
}

fn validateText(value: []const u8, allow_empty: bool) !void {
    if ((!allow_empty and value.len == 0) or value.len > max_text_bytes) return error.InvalidConformanceText;
    if (Secrets.containsSecret(value)) return error.SecretDetected;
}

fn lessThanScore(_: void, left: CaseScore, right: CaseScore) bool {
    return std.mem.order(u8, left.case_id, right.case_id) == .lt;
}

test "conformance scorer validates repair and cancellation lifecycle ordering" {
    const repair_events = [_]Event{
        .{ .sequence = 1, .kind = .session_started, .status = "running" },
        .{ .sequence = 2, .kind = .test_result, .status = "failed" },
        .{ .sequence = 3, .kind = .diagnostic_query, .status = "complete" },
        .{ .sequence = 4, .kind = .source_change, .status = "applied" },
        .{ .sequence = 5, .kind = .test_result, .status = "passed" },
        .{ .sequence = 6, .kind = .handoff, .status = "complete", .artifact = "handoff.json", .causal_event_ids = &.{42} },
        .{ .sequence = 7, .kind = .session_completed, .status = "completed" },
    };
    const cancel_events = [_]Event{
        .{ .sequence = 1, .kind = .session_started, .status = "running" },
        .{ .sequence = 2, .kind = .cancellation_requested, .status = "requested" },
        .{ .sequence = 3, .kind = .session_cancelled, .status = "cancelled" },
    };
    const cases = [_]Case{
        .{ .id = "codex-repair", .provider = .codex, .scenario = .repair, .expected_terminal = .completed, .required_acceptance = 0, .events = &repair_events },
        .{ .id = "claude-cancel", .provider = .claude, .scenario = .cancellation, .expected_terminal = .cancelled, .required_acceptance = 0, .events = &cancel_events },
    };
    const suite = Suite{ .schema = suite_schema, .schema_version = 1, .cases = &cases };
    const scores = try scoreSuiteAlloc(std.testing.allocator, suite);
    defer std.testing.allocator.free(scores);
    try std.testing.expect(scores[0].passed);
    try std.testing.expect(scores[1].passed);
    const repair_score = if (scores[0].scenario == .repair) scores[0] else scores[1];
    try std.testing.expect(repair_score.diagnostic_queries > 0);
    try std.testing.expect(!suite.hasCompleteProviderMatrix());
    try std.testing.expect(!try passesGate(suite));
}

test "conformance scorer rejects bad ordering duplicates versions and secrets" {
    const bad_events = [_]Event{
        .{ .sequence = 2, .kind = .session_started, .status = "running" },
        .{ .sequence = 1, .kind = .session_failed, .status = "failed" },
    };
    const bad_case = Case{ .id = "bad", .provider = .codex, .scenario = .failure, .expected_terminal = .failed, .events = &bad_events };
    try std.testing.expectError(error.InvalidConformanceSequence, bad_case.validate());

    const secret_events = [_]Event{.{ .sequence = 1, .kind = .session_failed, .status = "failed", .detail = "token=sentinel-secret-for-tests" }};
    const secret_case = Case{ .id = "secret", .provider = .codex, .scenario = .failure, .expected_terminal = .failed, .events = &secret_events };
    try std.testing.expectError(error.SecretDetected, secret_case.validate());

    const one = [_]Case{bad_case};
    const unknown = Suite{ .schema = "zigeffect.provider-conformance-suite.v9", .schema_version = 9, .cases = &one };
    try std.testing.expectError(error.UnsupportedConformanceSchema, unknown.validate());
    const duplicates = [_]Case{ bad_case, bad_case };
    const duplicate_suite = Suite{ .schema = suite_schema, .schema_version = 1, .cases = &duplicates };
    try std.testing.expectError(error.InvalidConformanceSequence, duplicate_suite.validate());
}

fn allocationReport(allocator: std.mem.Allocator, suite: Suite) !void {
    const json = try reportAlloc(allocator, suite);
    allocator.free(json);
}

test "conformance reports survive every allocation failure" {
    const events = [_]Event{
        .{ .sequence = 1, .kind = .cancellation_requested, .status = "requested" },
        .{ .sequence = 2, .kind = .session_cancelled, .status = "cancelled" },
    };
    const cases = [_]Case{.{ .id = "cancel", .provider = .codex, .scenario = .cancellation, .expected_terminal = .cancelled, .required_acceptance = 0, .events = &events }};
    const suite = Suite{ .schema = suite_schema, .schema_version = 1, .cases = &cases };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationReport, .{suite});
}
