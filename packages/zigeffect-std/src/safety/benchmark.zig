const std = @import("std");

pub const fixture_schema = "zigeffect.agent-benchmark-fixture.v1";
pub const score_schema = "zigeffect.agent-benchmark-score.v1";

pub const Language = enum { zigeffect_zig, rust_tokio, c };
pub const Provider = enum { codex, claude, local };

pub const Task = struct {
    id: []const u8,
    description: []const u8,
    acceptance_budget_ms: u64,
    token_budget: u64,
    target_throughput_ops_s: f64,
    target_latency_p95_us: f64,
    target_peak_memory_bytes: u64,
    target_binary_bytes: u64,
};

pub const Run = struct {
    id: []const u8,
    provider: Provider,
    language: Language,
    first_compile_ms: u64,
    acceptance_ms: u64,
    input_tokens: u64,
    output_tokens: u64,
    repair_iterations: u32,
    diagnostic_queries: u32,
    unsafe_sites_introduced: u32,
    unsafe_sites_reviewed: u32,
    seeded_defects: u32,
    escaped_defects: u32,
    injected_failures: u32,
    survived_failures: u32,
    deterministic_reproductions: u32,
    evidence_required: u32,
    evidence_present: u32,
    throughput_ops_s: f64,
    latency_p95_us: f64,
    peak_memory_bytes: u64,
    binary_bytes: u64,
};

pub const Fixture = struct {
    schema: []const u8,
    schema_version: u32,
    task: Task,
    runs: []const Run,

    pub fn validate(self: Fixture) !void {
        if (!std.mem.eql(u8, self.schema, fixture_schema) or self.schema_version != 1) return error.UnsupportedBenchmarkSchema;
        if (self.task.id.len == 0 or self.task.description.len == 0 or self.runs.len == 0) return error.InvalidBenchmarkFixture;
        if (self.task.acceptance_budget_ms == 0 or self.task.token_budget == 0 or self.task.target_throughput_ops_s <= 0 or
            self.task.target_latency_p95_us <= 0 or self.task.target_peak_memory_bytes == 0 or self.task.target_binary_bytes == 0)
        {
            return error.InvalidBenchmarkFixture;
        }
        for (self.runs, 0..) |run, index| {
            if (run.id.len == 0 or run.seeded_defects < run.escaped_defects or run.injected_failures < run.survived_failures or
                run.injected_failures < run.deterministic_reproductions or run.evidence_required < run.evidence_present or
                run.unsafe_sites_introduced < run.unsafe_sites_reviewed or run.throughput_ops_s < 0 or run.latency_p95_us < 0)
            {
                _ = index;
                return error.InvalidBenchmarkFixture;
            }
        }
    }
};

pub const ParsedFixture = std.json.Parsed(Fixture);

pub fn parseFixture(allocator: std.mem.Allocator, input: []const u8) !ParsedFixture {
    var parsed = try std.json.parseFromSlice(Fixture, allocator, input, .{ .allocate = .alloc_always });
    errdefer parsed.deinit();
    try parsed.value.validate();
    return parsed;
}

pub const Score = struct {
    run_id: []const u8,
    provider: Provider,
    language: Language,
    total: f64,
    defect_containment: f64,
    failure_robustness: f64,
    evidence_completeness: f64,
    delivery_efficiency: f64,
    unsafe_governance: f64,
    performance: f64,
};

pub const ScoreReport = struct {
    schema: []const u8 = score_schema,
    schema_version: u32 = 1,
    task_id: []const u8,
    scores: []const Score,
    interpretation: []const u8 = "Scores compare only the bounded fixture and do not establish general language safety or performance superiority.",

    pub fn jsonAlloc(self: ScoreReport, allocator: std.mem.Allocator) ![]u8 {
        return std.json.Stringify.valueAlloc(allocator, self, .{ .whitespace = .minified });
    }
};

pub fn scoreFixtureAlloc(allocator: std.mem.Allocator, fixture: Fixture) ![]Score {
    try fixture.validate();
    const scores = try allocator.alloc(Score, fixture.runs.len);
    for (fixture.runs, 0..) |run, index| scores[index] = scoreRun(fixture.task, run);
    std.mem.sort(Score, scores, {}, higherScore);
    return scores;
}

pub fn scoreRun(task: Task, run: Run) Score {
    const defect_ratio = ratio(run.seeded_defects - run.escaped_defects, run.seeded_defects);
    const survival_ratio = ratio(run.survived_failures, run.injected_failures);
    const replay_ratio = ratio(run.deterministic_reproductions, run.injected_failures);
    const evidence_ratio = ratio(run.evidence_present, run.evidence_required);
    const unsafe_ratio = if (run.unsafe_sites_introduced == 0) 1.0 else ratio(run.unsafe_sites_reviewed, run.unsafe_sites_introduced);
    const time_ratio = inverseRatio(@floatFromInt(run.acceptance_ms), @floatFromInt(task.acceptance_budget_ms));
    const token_ratio = inverseRatio(@floatFromInt(run.input_tokens + run.output_tokens), @floatFromInt(task.token_budget));
    const repair_ratio = 1.0 / (1.0 + @as(f64, @floatFromInt(run.repair_iterations)) / 4.0);
    const delivery = mean3(time_ratio, token_ratio, repair_ratio);
    const throughput = clamp01(run.throughput_ops_s / task.target_throughput_ops_s);
    const latency = inverseRatio(run.latency_p95_us, task.target_latency_p95_us);
    const memory = inverseRatio(@floatFromInt(run.peak_memory_bytes), @floatFromInt(task.target_peak_memory_bytes));
    const binary = inverseRatio(@floatFromInt(run.binary_bytes), @floatFromInt(task.target_binary_bytes));
    const performance = (throughput + latency + memory + binary) / 4.0;

    const defect_points = defect_ratio * 25.0;
    const robustness_points = mean2(survival_ratio, replay_ratio) * 20.0;
    const evidence_points = evidence_ratio * 15.0;
    const delivery_points = delivery * 20.0;
    const unsafe_points = unsafe_ratio * 5.0;
    const performance_points = performance * 15.0;
    return .{
        .run_id = run.id,
        .provider = run.provider,
        .language = run.language,
        .total = defect_points + robustness_points + evidence_points + delivery_points + unsafe_points + performance_points,
        .defect_containment = defect_points,
        .failure_robustness = robustness_points,
        .evidence_completeness = evidence_points,
        .delivery_efficiency = delivery_points,
        .unsafe_governance = unsafe_points,
        .performance = performance_points,
    };
}

fn ratio(numerator: anytype, denominator: @TypeOf(numerator)) f64 {
    if (denominator == 0) return 1.0;
    return clamp01(@as(f64, @floatFromInt(numerator)) / @as(f64, @floatFromInt(denominator)));
}

fn inverseRatio(actual: f64, budget: f64) f64 {
    if (actual <= 0) return 1.0;
    return clamp01(budget / actual);
}

fn clamp01(value: f64) f64 {
    return @max(0.0, @min(1.0, value));
}

fn mean2(a: f64, b: f64) f64 {
    return (a + b) / 2.0;
}

fn mean3(a: f64, b: f64, c: f64) f64 {
    return (a + b + c) / 3.0;
}

fn higherScore(_: void, left: Score, right: Score) bool {
    if (left.total != right.total) return left.total > right.total;
    return std.mem.order(u8, left.run_id, right.run_id) == .lt;
}

test "benchmark scoring rewards contained defects complete evidence and reproducibility" {
    const task = Task{ .id = "service-repair", .description = "repair a bounded service", .acceptance_budget_ms = 10_000, .token_budget = 20_000, .target_throughput_ops_s = 1000, .target_latency_p95_us = 1000, .target_peak_memory_bytes = 1_000_000, .target_binary_bytes = 2_000_000 };
    const strong = Run{ .id = "strong", .provider = .codex, .language = .zigeffect_zig, .first_compile_ms = 1000, .acceptance_ms = 8000, .input_tokens = 8000, .output_tokens = 4000, .repair_iterations = 1, .diagnostic_queries = 2, .unsafe_sites_introduced = 0, .unsafe_sites_reviewed = 0, .seeded_defects = 4, .escaped_defects = 0, .injected_failures = 4, .survived_failures = 4, .deterministic_reproductions = 4, .evidence_required = 6, .evidence_present = 6, .throughput_ops_s = 1100, .latency_p95_us = 900, .peak_memory_bytes = 900_000, .binary_bytes = 1_800_000 };
    var weak = strong;
    weak.id = "weak";
    weak.language = .c;
    weak.escaped_defects = 3;
    weak.survived_failures = 1;
    weak.deterministic_reproductions = 0;
    weak.evidence_present = 2;
    const runs = [_]Run{ weak, strong };
    const fixture = Fixture{ .schema = fixture_schema, .schema_version = 1, .task = task, .runs = &runs };
    const scores = try scoreFixtureAlloc(std.testing.allocator, fixture);
    defer std.testing.allocator.free(scores);
    try std.testing.expectEqualStrings("strong", scores[0].run_id);
    try std.testing.expect(scores[0].total > scores[1].total);
    const report = ScoreReport{ .task_id = task.id, .scores = scores };
    const json = try report.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "do not establish general language safety") != null);
}

test "benchmark parser owns strings and rejects impossible counts" {
    const json =
        \\{"schema":"zigeffect.agent-benchmark-fixture.v1","schema_version":1,"task":{"id":"task","description":"bounded","acceptance_budget_ms":1000,"token_budget":1000,"target_throughput_ops_s":1,"target_latency_p95_us":1,"target_peak_memory_bytes":1,"target_binary_bytes":1},"runs":[{"id":"run","provider":"claude","language":"rust_tokio","first_compile_ms":1,"acceptance_ms":1,"input_tokens":1,"output_tokens":1,"repair_iterations":0,"diagnostic_queries":0,"unsafe_sites_introduced":0,"unsafe_sites_reviewed":0,"seeded_defects":1,"escaped_defects":2,"injected_failures":0,"survived_failures":0,"deterministic_reproductions":0,"evidence_required":0,"evidence_present":0,"throughput_ops_s":1,"latency_p95_us":1,"peak_memory_bytes":1,"binary_bytes":1}]}
    ;
    try std.testing.expectError(error.InvalidBenchmarkFixture, parseFixture(std.testing.allocator, json));
}
