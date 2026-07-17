const std = @import("std");
const builtin = @import("builtin");
const memory = @import("memory.zig");
const parity = @import("parity.zig");

pub const supervisor_version = "zgraphy-m3-qualification-supervisor-v2";
pub const performance_schema = "zgraphy.performance-receipt.v1";
pub const performance_sample_file_schema = "zgraphy.performance-samples.v1";
pub const churn_schema = "zgraphy.m3-churn-receipt.v1";
pub const churn_observation_file_schema = "zgraphy.m3-churn-observations.v1";
pub const schema_version: u32 = 1;
pub const max_repetitions: u16 = 256;
pub const min_repetitions: u16 = 7;
pub const max_performance_sample_bytes: usize = 16 * 1024 * 1024;
pub const max_churn_observation_bytes: usize = 16 * 1024 * 1024;
pub const max_churn_transitions: usize = 256;
pub const min_churn_transitions: usize = 32;

pub const Engine = enum {
    graphify,
    zgraphy,
};

pub const PerformanceIdentity = struct {
    workload_id: []const u8,
    corpus_digest: []const u8,
    source_revision: []const u8,
    machine_digest: []const u8,
    operating_system: []const u8,
    target: []const u8,
    toolchain: []const u8,
    graphify_python: []const u8,
    optimize: []const u8,
    adapter_version: []const u8,
    provider_version: []const u8,
    configuration_digest: []const u8,
    correctness_digest: []const u8,
    quality_matrix_digest: []const u8,
    resource_matrix_digest: []const u8,
    graphify_environment_digest: []const u8,
};

pub const Sampling = struct {
    warmups: u16,
    repetitions: u16,
    supervisor: []const u8 = supervisor_version,
};

pub const Targets = struct {
    minimum_speedup_basis_points: u64 = 50_000,
    maximum_rss_ratio_basis_points: u64 = 5_000,
};

pub const PerformanceSample = struct {
    engine: Engine,
    repetition: u16,
    elapsed_ns: u64,
    user_cpu_ns: u64,
    system_cpu_ns: u64,
    peak_rss_bytes: u64,
    persisted_bytes: u64,
    nodes: usize,
    relations: usize,
    correctness_digest: []const u8,
    correctness_passed: bool = true,
    graph_healthy: bool = true,
    changed_source_reconciled: bool = true,
    incremental_clean_equivalent: bool = true,
    active_generation_current: bool = true,
    retention_healthy: bool = true,
    reparsed_files: usize = 0,
    cache_hits: usize = 0,
    exit_code: u8 = 0,
};

pub const PerformanceSampleFile = struct {
    schema: []const u8,
    schema_version: u32,
    identity: PerformanceIdentity,
    sampling: Sampling,
    targets: Targets = .{},
    samples: []const PerformanceSample,
};

pub const Statistics = struct {
    minimum: u64,
    p50: u64,
    p95: u64,
    p99: u64,
    maximum: u64,
};

pub const PerformanceAggregate = struct {
    engine: Engine,
    sample_count: u16,
    elapsed_ns: Statistics,
    user_cpu_ns: Statistics,
    system_cpu_ns: Statistics,
    peak_rss_bytes: Statistics,
    persisted_bytes: Statistics,
    nodes: usize,
    relations: usize,
};

pub const PerformanceComparison = struct {
    speedup_basis_points: u64,
    rss_ratio_basis_points: u64,
    persisted_ratio_basis_points: u64,
    latency_target_passed: bool,
    rss_target_passed: bool,
};

pub const Baseline = struct {
    product: []const u8 = "Graphify",
    version: []const u8 = parity.pinned_graphify_version,
    commit: []const u8 = parity.pinned_graphify_commit,
};

pub const Toolchain = struct {
    zig: []const u8 = builtin.zig_version_string,
    architecture: []const u8 = @tagName(builtin.target.cpu.arch),
    operating_system: []const u8 = @tagName(builtin.target.os.tag),
    abi: []const u8 = @tagName(builtin.target.abi),
    optimize: []const u8 = @tagName(builtin.mode),
};

const scoped_performance_claims = [_][]const u8{
    "on the identified corpus machine and paired ReleaseSafe sample set zgraphy's managed one-file update met the declared Graphify median latency and peak RSS targets",
};

const performance_limitations = [_][]const u8{
    "the result is scoped to the identified corpus machine workload versions and configuration",
    "persisted size is measured and reported but has no relative M3 superiority target",
    "held-out retrieval agent-task million-edge and production-soak claims remain unearned",
};

pub const PerformanceReceipt = struct {
    schema: []const u8 = performance_schema,
    schema_version: u32 = schema_version,
    evidence_state: []const u8 = "active_scoped_baseline",
    identity: PerformanceIdentity,
    baseline: Baseline = .{},
    toolchain: Toolchain = .{},
    sampling: Sampling,
    targets: Targets,
    samples: []PerformanceSample,
    aggregates: []PerformanceAggregate,
    comparison: PerformanceComparison,
    comparison_eligible: bool,
    performance_gate_passed: bool,
    claims: []const []const u8,
    limitations: []const []const u8 = &performance_limitations,

    pub fn deinit(self: *PerformanceReceipt, allocator: std.mem.Allocator) void {
        allocator.free(self.samples);
        allocator.free(self.aggregates);
        self.samples = &.{};
        self.aggregates = &.{};
    }
};

pub fn parsePerformanceSampleFile(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(PerformanceSampleFile) {
    if (bytes.len == 0 or bytes.len > max_performance_sample_bytes) return error.InvalidPerformanceSampleFile;
    var parsed = std.json.parseFromSlice(PerformanceSampleFile, allocator, bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = false,
    }) catch return error.InvalidPerformanceSampleFile;
    errdefer parsed.deinit();
    if (!std.mem.eql(u8, parsed.value.schema, performance_sample_file_schema) or parsed.value.schema_version != schema_version) {
        return error.InvalidPerformanceSampleFile;
    }
    return parsed;
}

pub fn buildPerformance(
    allocator: std.mem.Allocator,
    identity: PerformanceIdentity,
    sampling: Sampling,
    targets: Targets,
    input_samples: []const PerformanceSample,
) !PerformanceReceipt {
    try validatePerformanceIdentity(identity);
    try validateSampling(sampling);
    try validateTargets(targets);
    if (input_samples.len != @as(usize, sampling.repetitions) * 2) return error.IncompletePerformanceSamples;
    for (input_samples, 0..) |sample, index| {
        try validatePerformanceSample(sample, identity, sampling);
        for (input_samples[0..index]) |previous| {
            if (previous.engine == sample.engine and previous.repetition == sample.repetition) return error.DuplicatePerformanceSample;
        }
    }

    const samples = try memory.copy(PerformanceSample, allocator, input_samples);
    errdefer allocator.free(samples);
    const aggregates = try memory.slice(PerformanceAggregate, allocator, 2);
    errdefer allocator.free(aggregates);
    aggregates[0] = try aggregatePerformance(samples, .graphify, sampling.repetitions);
    aggregates[1] = try aggregatePerformance(samples, .zgraphy, sampling.repetitions);
    const comparison = try comparePerformance(aggregates[0], aggregates[1], targets);
    const gate_passed = comparison.latency_target_passed and comparison.rss_target_passed;
    var receipt = PerformanceReceipt{
        .identity = identity,
        .sampling = sampling,
        .targets = targets,
        .samples = samples,
        .aggregates = aggregates,
        .comparison = comparison,
        .comparison_eligible = true,
        .performance_gate_passed = gate_passed,
        .claims = if (gate_passed) &scoped_performance_claims else &.{},
    };
    try validatePerformance(&receipt);
    return receipt;
}

pub fn validatePerformance(receipt: *const PerformanceReceipt) !void {
    if (!std.mem.eql(u8, receipt.schema, performance_schema) or receipt.schema_version != schema_version or
        !std.mem.eql(u8, receipt.evidence_state, "active_scoped_baseline"))
    {
        return error.IncompatiblePerformanceReceipt;
    }
    try validatePerformanceIdentity(receipt.identity);
    try validateSampling(receipt.sampling);
    try validateTargets(receipt.targets);
    if (!std.mem.eql(u8, receipt.baseline.product, "Graphify") or
        !std.mem.eql(u8, receipt.baseline.version, parity.pinned_graphify_version) or
        !std.mem.eql(u8, receipt.baseline.commit, parity.pinned_graphify_commit))
    {
        return error.InvalidPerformanceBaseline;
    }
    if (receipt.toolchain.zig.len == 0 or receipt.toolchain.architecture.len == 0 or
        receipt.toolchain.operating_system.len == 0 or receipt.toolchain.abi.len == 0 or
        !std.mem.eql(u8, receipt.toolchain.optimize, @tagName(builtin.mode)) or
        (!builtin.is_test and builtin.mode != .ReleaseSafe))
    {
        return error.InvalidPerformanceToolchain;
    }
    if (!receipt.comparison_eligible or receipt.samples.len != @as(usize, receipt.sampling.repetitions) * 2 or
        receipt.aggregates.len != 2 or receipt.limitations.len != performance_limitations.len)
    {
        return error.IncompletePerformanceReceipt;
    }
    for (performance_limitations, receipt.limitations) |expected, actual| {
        if (!std.mem.eql(u8, expected, actual)) return error.InvalidPerformanceLimitations;
    }
    for (receipt.samples, 0..) |sample, index| {
        try validatePerformanceSample(sample, receipt.identity, receipt.sampling);
        for (receipt.samples[0..index]) |previous| {
            if (previous.engine == sample.engine and previous.repetition == sample.repetition) return error.DuplicatePerformanceSample;
        }
    }
    const graphify = try aggregatePerformance(receipt.samples, .graphify, receipt.sampling.repetitions);
    const zgraphy = try aggregatePerformance(receipt.samples, .zgraphy, receipt.sampling.repetitions);
    if (!aggregateEqual(receipt.aggregates[0], graphify) or !aggregateEqual(receipt.aggregates[1], zgraphy)) {
        return error.InconsistentPerformanceAggregate;
    }
    const comparison = try comparePerformance(graphify, zgraphy, receipt.targets);
    if (!comparisonEqual(receipt.comparison, comparison)) return error.InconsistentPerformanceComparison;
    const expected_gate = comparison.latency_target_passed and comparison.rss_target_passed;
    if (receipt.performance_gate_passed != expected_gate) return error.InconsistentPerformanceGate;
    if (expected_gate) {
        if (receipt.claims.len != scoped_performance_claims.len) return error.InvalidPerformanceClaims;
        for (scoped_performance_claims, receipt.claims) |expected, actual| {
            if (!std.mem.eql(u8, expected, actual)) return error.InvalidPerformanceClaims;
        }
    } else if (receipt.claims.len != 0) return error.InvalidPerformanceClaims;
}

fn validatePerformanceIdentity(identity: PerformanceIdentity) !void {
    if (!validName(identity.workload_id, 160) or !validSha256(identity.corpus_digest) or
        !validSha256(identity.source_revision) or !validSha256(identity.machine_digest) or
        !validName(identity.operating_system, 64) or !validName(identity.target, 128) or
        !validText(identity.toolchain, 256) or !validName(identity.graphify_python, 64) or
        !std.mem.eql(u8, identity.optimize, "ReleaseSafe") or
        !std.mem.eql(u8, identity.adapter_version, supervisor_version) or
        !std.mem.startsWith(u8, identity.provider_version, "Graphify-0.9.17-") or
        !validSha256(identity.configuration_digest) or !validSha256(identity.correctness_digest) or
        !validSha256(identity.quality_matrix_digest) or !validSha256(identity.resource_matrix_digest) or
        !validSha256(identity.graphify_environment_digest))
    {
        return error.InvalidPerformanceIdentity;
    }
}

fn validateSampling(sampling: Sampling) !void {
    if (sampling.warmups == 0 or sampling.repetitions < min_repetitions or sampling.repetitions > max_repetitions or
        !std.mem.eql(u8, sampling.supervisor, supervisor_version))
    {
        return error.InvalidPerformanceSampling;
    }
}

fn validateTargets(targets: Targets) !void {
    if (targets.minimum_speedup_basis_points < 10_000 or targets.minimum_speedup_basis_points > 1_000_000 or
        targets.maximum_rss_ratio_basis_points == 0 or targets.maximum_rss_ratio_basis_points > 10_000)
    {
        return error.InvalidPerformanceTargets;
    }
}

fn validatePerformanceSample(sample: PerformanceSample, identity: PerformanceIdentity, sampling: Sampling) !void {
    if (sample.repetition == 0 or sample.repetition > sampling.repetitions or sample.elapsed_ns == 0 or
        sample.peak_rss_bytes == 0 or sample.persisted_bytes == 0 or sample.nodes == 0 or sample.relations == 0 or
        sample.exit_code != 0 or !sample.correctness_passed or !sample.graph_healthy or
        !sample.changed_source_reconciled or !sample.incremental_clean_equivalent or
        !sample.active_generation_current or !sample.retention_healthy or
        !std.mem.eql(u8, sample.correctness_digest, identity.correctness_digest))
    {
        return error.IncorrectPerformanceSample;
    }
    if (sample.engine == .zgraphy and (sample.reparsed_files != 1 or sample.cache_hits == 0)) {
        return error.IncorrectPerformanceSample;
    }
}

fn aggregatePerformance(samples: []const PerformanceSample, engine: Engine, repetitions: u16) !PerformanceAggregate {
    var elapsed: [max_repetitions]u64 = @splat(0);
    var user_cpu: [max_repetitions]u64 = @splat(0);
    var system_cpu: [max_repetitions]u64 = @splat(0);
    var peak_rss: [max_repetitions]u64 = @splat(0);
    var persisted: [max_repetitions]u64 = @splat(0);
    var count: usize = 0;
    var nodes: usize = 0;
    var relations: usize = 0;
    for (samples) |sample| {
        if (sample.engine != engine) continue;
        if (count >= repetitions) return error.DuplicatePerformanceSample;
        if (count == 0) {
            nodes = sample.nodes;
            relations = sample.relations;
        } else if (nodes != sample.nodes or relations != sample.relations) return error.InconsistentPerformanceProjection;
        elapsed[count] = sample.elapsed_ns;
        user_cpu[count] = sample.user_cpu_ns;
        system_cpu[count] = sample.system_cpu_ns;
        peak_rss[count] = sample.peak_rss_bytes;
        persisted[count] = sample.persisted_bytes;
        count += 1;
    }
    if (count != repetitions) return error.IncompletePerformanceSamples;
    return .{
        .engine = engine,
        .sample_count = repetitions,
        .elapsed_ns = statistics(elapsed[0..count]),
        .user_cpu_ns = statistics(user_cpu[0..count]),
        .system_cpu_ns = statistics(system_cpu[0..count]),
        .peak_rss_bytes = statistics(peak_rss[0..count]),
        .persisted_bytes = statistics(persisted[0..count]),
        .nodes = nodes,
        .relations = relations,
    };
}

fn comparePerformance(graphify: PerformanceAggregate, zgraphy: PerformanceAggregate, targets: Targets) !PerformanceComparison {
    if (graphify.engine != .graphify or zgraphy.engine != .zgraphy) return error.InconsistentPerformanceAggregate;
    const speedup = try ratioBasisPoints(graphify.elapsed_ns.p50, zgraphy.elapsed_ns.p50);
    const rss = try ratioBasisPoints(zgraphy.peak_rss_bytes.p50, graphify.peak_rss_bytes.p50);
    const persisted = try ratioBasisPoints(zgraphy.persisted_bytes.p50, graphify.persisted_bytes.p50);
    return .{
        .speedup_basis_points = speedup,
        .rss_ratio_basis_points = rss,
        .persisted_ratio_basis_points = persisted,
        .latency_target_passed = speedup >= targets.minimum_speedup_basis_points,
        .rss_target_passed = rss <= targets.maximum_rss_ratio_basis_points,
    };
}

fn ratioBasisPoints(numerator: u64, denominator: u64) !u64 {
    if (denominator == 0) return error.InvalidPerformanceRatio;
    const scaled = std.math.mul(u64, numerator, 10_000) catch return error.PerformanceRatioOverflow;
    return scaled / denominator;
}

fn statistics(values: []u64) Statistics {
    std.mem.sort(u64, values, {}, comptime std.sort.asc(u64));
    return .{
        .minimum = values[0],
        .p50 = values[(values.len - 1) / 2],
        .p95 = values[nearestRank(values.len, 95)],
        .p99 = values[nearestRank(values.len, 99)],
        .maximum = values[values.len - 1],
    };
}

fn nearestRank(count: usize, percentile: usize) usize {
    return ((count * percentile + 99) / 100) - 1;
}

fn aggregateEqual(left: PerformanceAggregate, right: PerformanceAggregate) bool {
    return left.engine == right.engine and left.sample_count == right.sample_count and
        statisticsEqual(left.elapsed_ns, right.elapsed_ns) and statisticsEqual(left.user_cpu_ns, right.user_cpu_ns) and
        statisticsEqual(left.system_cpu_ns, right.system_cpu_ns) and statisticsEqual(left.peak_rss_bytes, right.peak_rss_bytes) and
        statisticsEqual(left.persisted_bytes, right.persisted_bytes) and left.nodes == right.nodes and left.relations == right.relations;
}

fn statisticsEqual(left: Statistics, right: Statistics) bool {
    return left.minimum == right.minimum and left.p50 == right.p50 and left.p95 == right.p95 and
        left.p99 == right.p99 and left.maximum == right.maximum;
}

fn comparisonEqual(left: PerformanceComparison, right: PerformanceComparison) bool {
    return left.speedup_basis_points == right.speedup_basis_points and
        left.rss_ratio_basis_points == right.rss_ratio_basis_points and
        left.persisted_ratio_basis_points == right.persisted_ratio_basis_points and
        left.latency_target_passed == right.latency_target_passed and left.rss_target_passed == right.rss_target_passed;
}

pub const ChurnOperation = enum {
    modify,
    create,
    rename,
    move,
    delete,
    exclude,
    include,
    branch,
    detach,
    unchanged,
    reader_defer,
    repair,
};

pub const RetentionStatus = enum {
    no_action,
    disabled,
    planned,
    applied,
    deferred_readers,
    failed,
};

pub const ChurnHealth = struct {
    dangling_edges: usize = 0,
    dangling_hyperedge_participants: usize = 0,
    dangling_supernode_members: usize = 0,
    missing_input_hyperedges: usize = 0,
    invalid_supernode_proofs: usize = 0,
    unowned_vectors: usize = 0,
    true_orphans: usize = 0,
    unowned_index_records: usize = 0,

    pub fn clean(self: ChurnHealth) bool {
        return self.dangling_edges == 0 and self.dangling_hyperedge_participants == 0 and
            self.dangling_supernode_members == 0 and self.missing_input_hyperedges == 0 and
            self.invalid_supernode_proofs == 0 and self.unowned_vectors == 0 and
            self.true_orphans == 0 and self.unowned_index_records == 0;
    }
};

pub const ChurnTransition = struct {
    ordinal: u16,
    operation: ChurnOperation,
    generation: []const u8,
    parent_generation: []const u8,
    graph_fingerprint: []const u8,
    clean_graph_fingerprint: []const u8,
    index_fingerprint: []const u8,
    clean_index_fingerprint: []const u8,
    checked_files: usize,
    reparsed_files: usize,
    cache_hits: usize,
    cache_misses: usize = 0,
    direct_invalidations: usize,
    invalidation_closure: usize,
    pruned_records: usize = 0,
    health: ChurnHealth = .{},
    generation_count: usize,
    generation_bytes: u64,
    cache_entries: usize,
    cache_bytes: u64,
    extraction_manifest_bytes: u64,
    delta_journal_bytes: u64,
    retention_status: RetentionStatus,
    generations_deleted: usize = 0,
    cache_entries_deleted: usize = 0,
    reader_deferred: bool = false,
    repair_published: bool = false,
    active_present: bool = true,
    parent_present: bool = true,
    origin_valid: bool = true,
    snapshot_complete: bool = true,
    current_read: bool = true,
};

pub const ChurnIdentity = struct {
    corpus_digest: []const u8,
    source_revision: []const u8,
    configuration_digest: []const u8,
    schedule_digest: []const u8,
};

pub const ChurnBudgets = struct {
    max_generations: usize = 8,
    max_generation_bytes: u64 = 64 * 1024 * 1024,
    max_cache_entries: usize = 256,
    max_cache_bytes: u64 = 32 * 1024 * 1024,
    max_extraction_manifest_bytes: u64 = 4 * 1024 * 1024,
    max_delta_journal_bytes: u64 = 16 * 1024 * 1024,
    max_reparsed_one_file: usize = 1,
};

pub const ChurnSummary = struct {
    transitions: usize,
    operation_kinds: usize,
    peak_generations: usize,
    peak_generation_bytes: u64,
    peak_cache_entries: usize,
    peak_cache_bytes: u64,
    peak_extraction_manifest_bytes: u64,
    peak_delta_journal_bytes: u64,
    gc_generations_deleted: usize,
    gc_cache_entries_deleted: usize,
    reader_deferrals: usize,
    repairs: usize,
};

const churn_claims = [_][]const u8{
    "the identified deterministic M3 churn schedule remained clean equivalent recoverable and within its declared generation cache manifest and journal budgets",
};

const churn_limitations = [_][]const u8{
    "the deterministic qualification schedule is bounded and is not a production-duration soak",
    "multi-repository model-provider and million-edge scale qualification remain later milestones",
};

pub const ChurnReceipt = struct {
    schema: []const u8 = churn_schema,
    schema_version: u32 = schema_version,
    identity: ChurnIdentity,
    budgets: ChurnBudgets,
    transitions: []ChurnTransition,
    summary: ChurnSummary,
    churn_gate_passed: bool,
    claims: []const []const u8 = &churn_claims,
    limitations: []const []const u8 = &churn_limitations,

    pub fn deinit(self: *ChurnReceipt, allocator: std.mem.Allocator) void {
        allocator.free(self.transitions);
        self.transitions = &.{};
    }
};

pub const ChurnObservationFile = struct {
    schema: []const u8,
    schema_version: u32,
    identity: ChurnIdentity,
    budgets: ChurnBudgets,
    transitions: []const ChurnTransition,
};

pub fn parseChurnObservationFile(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(ChurnObservationFile) {
    if (bytes.len == 0 or bytes.len > max_churn_observation_bytes) return error.InvalidChurnObservationFile;
    var parsed = std.json.parseFromSlice(ChurnObservationFile, allocator, bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = false,
    }) catch return error.InvalidChurnObservationFile;
    errdefer parsed.deinit();
    if (!std.mem.eql(u8, parsed.value.schema, churn_observation_file_schema) or parsed.value.schema_version != schema_version) {
        return error.InvalidChurnObservationFile;
    }
    return parsed;
}

pub fn buildChurn(
    allocator: std.mem.Allocator,
    identity: ChurnIdentity,
    budgets: ChurnBudgets,
    input_transitions: []const ChurnTransition,
) !ChurnReceipt {
    try validateChurnIdentity(identity);
    try validateChurnBudgets(budgets);
    const transitions = try memory.copy(ChurnTransition, allocator, input_transitions);
    errdefer allocator.free(transitions);
    const summary = try summarizeChurn(transitions, budgets);
    var receipt = ChurnReceipt{
        .identity = identity,
        .budgets = budgets,
        .transitions = transitions,
        .summary = summary,
        .churn_gate_passed = true,
    };
    try validateChurn(&receipt);
    return receipt;
}

pub fn validateChurn(receipt: *const ChurnReceipt) !void {
    if (!std.mem.eql(u8, receipt.schema, churn_schema) or receipt.schema_version != schema_version) {
        return error.IncompatibleChurnReceipt;
    }
    try validateChurnIdentity(receipt.identity);
    try validateChurnBudgets(receipt.budgets);
    if (!receipt.churn_gate_passed or receipt.claims.len != churn_claims.len or
        receipt.limitations.len != churn_limitations.len)
    {
        return error.IncompleteChurnReceipt;
    }
    for (churn_claims, receipt.claims) |expected, actual| {
        if (!std.mem.eql(u8, expected, actual)) return error.InvalidChurnClaims;
    }
    for (churn_limitations, receipt.limitations) |expected, actual| {
        if (!std.mem.eql(u8, expected, actual)) return error.InvalidChurnLimitations;
    }
    const summary = try summarizeChurn(receipt.transitions, receipt.budgets);
    if (!churnSummaryEqual(receipt.summary, summary)) return error.InconsistentChurnSummary;
}

fn validateChurnIdentity(identity: ChurnIdentity) !void {
    if (!validSha256(identity.corpus_digest) or !validSha256(identity.source_revision) or
        !validSha256(identity.configuration_digest) or !validSha256(identity.schedule_digest))
    {
        return error.InvalidChurnIdentity;
    }
}

fn validateChurnBudgets(budgets: ChurnBudgets) !void {
    if (budgets.max_generations < 2 or budgets.max_generations > 256 or budgets.max_generation_bytes == 0 or
        budgets.max_cache_entries == 0 or budgets.max_cache_bytes == 0 or budgets.max_extraction_manifest_bytes == 0 or
        budgets.max_delta_journal_bytes == 0 or budgets.max_reparsed_one_file == 0 or budgets.max_reparsed_one_file > 8)
    {
        return error.InvalidChurnBudgets;
    }
}

fn summarizeChurn(transitions: []const ChurnTransition, budgets: ChurnBudgets) !ChurnSummary {
    if (transitions.len < min_churn_transitions or transitions.len > max_churn_transitions) return error.IncompleteChurnSchedule;
    var seen_operations: [@typeInfo(ChurnOperation).@"enum".fields.len]bool = @splat(false);
    var summary = ChurnSummary{
        .transitions = transitions.len,
        .operation_kinds = 0,
        .peak_generations = 0,
        .peak_generation_bytes = 0,
        .peak_cache_entries = 0,
        .peak_cache_bytes = 0,
        .peak_extraction_manifest_bytes = 0,
        .peak_delta_journal_bytes = 0,
        .gc_generations_deleted = 0,
        .gc_cache_entries_deleted = 0,
        .reader_deferrals = 0,
        .repairs = 0,
    };
    for (transitions, 0..) |transition, index| {
        if (transition.ordinal != index + 1 or !validGeneration(transition.generation) or
            !validGeneration(transition.parent_generation) or !validSha256(transition.graph_fingerprint) or
            !validSha256(transition.clean_graph_fingerprint) or !validSha256(transition.index_fingerprint) or
            !validSha256(transition.clean_index_fingerprint) or
            !std.mem.eql(u8, transition.graph_fingerprint, transition.clean_graph_fingerprint) or
            !std.mem.eql(u8, transition.index_fingerprint, transition.clean_index_fingerprint) or
            transition.checked_files == 0 or transition.invalidation_closure < transition.direct_invalidations or
            !transition.health.clean() or !transition.active_present or !transition.parent_present or
            !transition.origin_valid or !transition.snapshot_complete or !transition.current_read)
        {
            return error.IncorrectChurnTransition;
        }
        if (transition.generation_count == 0 or transition.generation_count > budgets.max_generations or
            transition.generation_bytes == 0 or transition.generation_bytes > budgets.max_generation_bytes or
            transition.cache_entries > budgets.max_cache_entries or transition.cache_bytes > budgets.max_cache_bytes or
            transition.extraction_manifest_bytes == 0 or transition.extraction_manifest_bytes > budgets.max_extraction_manifest_bytes or
            transition.delta_journal_bytes == 0 or transition.delta_journal_bytes > budgets.max_delta_journal_bytes)
        {
            return error.ChurnBudgetExceeded;
        }
        const operation_index = @intFromEnum(transition.operation);
        seen_operations[operation_index] = true;
        switch (transition.operation) {
            .branch, .detach, .unchanged, .reader_defer => if (transition.reparsed_files != 0) return error.IncorrectChurnReparseCount,
            .modify, .create, .rename, .move, .delete, .exclude, .include => if (transition.reparsed_files > budgets.max_reparsed_one_file) return error.IncorrectChurnReparseCount,
            .repair => {},
        }
        if (transition.operation == .reader_defer) {
            if (!transition.reader_deferred or transition.retention_status != .deferred_readers or
                transition.generations_deleted != 0 or transition.cache_entries_deleted != 0)
            {
                return error.IncorrectReaderDeferral;
            }
            summary.reader_deferrals += 1;
        } else if (transition.reader_deferred) return error.IncorrectReaderDeferral;
        if (transition.operation == .repair) {
            if (!transition.repair_published) return error.IncorrectRepairTransition;
            summary.repairs += 1;
        } else if (transition.repair_published) return error.IncorrectRepairTransition;
        summary.peak_generations = @max(summary.peak_generations, transition.generation_count);
        summary.peak_generation_bytes = @max(summary.peak_generation_bytes, transition.generation_bytes);
        summary.peak_cache_entries = @max(summary.peak_cache_entries, transition.cache_entries);
        summary.peak_cache_bytes = @max(summary.peak_cache_bytes, transition.cache_bytes);
        summary.peak_extraction_manifest_bytes = @max(summary.peak_extraction_manifest_bytes, transition.extraction_manifest_bytes);
        summary.peak_delta_journal_bytes = @max(summary.peak_delta_journal_bytes, transition.delta_journal_bytes);
        summary.gc_generations_deleted += transition.generations_deleted;
        summary.gc_cache_entries_deleted += transition.cache_entries_deleted;
    }
    for (seen_operations) |seen| if (seen) {
        summary.operation_kinds += 1;
    };
    if (summary.operation_kinds != seen_operations.len or summary.gc_generations_deleted == 0 or
        summary.reader_deferrals == 0 or summary.repairs == 0)
    {
        return error.IncompleteChurnSchedule;
    }
    return summary;
}

fn churnSummaryEqual(left: ChurnSummary, right: ChurnSummary) bool {
    return left.transitions == right.transitions and left.operation_kinds == right.operation_kinds and
        left.peak_generations == right.peak_generations and left.peak_generation_bytes == right.peak_generation_bytes and
        left.peak_cache_entries == right.peak_cache_entries and left.peak_cache_bytes == right.peak_cache_bytes and
        left.peak_extraction_manifest_bytes == right.peak_extraction_manifest_bytes and
        left.peak_delta_journal_bytes == right.peak_delta_journal_bytes and
        left.gc_generations_deleted == right.gc_generations_deleted and
        left.gc_cache_entries_deleted == right.gc_cache_entries_deleted and
        left.reader_deferrals == right.reader_deferrals and left.repairs == right.repairs;
}

fn validGeneration(value: []const u8) bool {
    if (!std.mem.startsWith(u8, value, "g-") or value.len != 66) return false;
    return validLowerHex(value[2..]);
}

fn validSha256(value: []const u8) bool {
    if (!std.mem.startsWith(u8, value, "sha256:") or value.len != 71) return false;
    return validLowerHex(value[7..]);
}

fn validLowerHex(value: []const u8) bool {
    for (value) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}

fn validName(value: []const u8, maximum: usize) bool {
    if (value.len == 0 or value.len > maximum) return false;
    for (value) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '-' and byte != '_' and byte != '.') return false;
    return true;
}

fn validText(value: []const u8, maximum: usize) bool {
    if (value.len == 0 or value.len > maximum) return false;
    for (value) |byte| if (byte < 0x20 or byte == 0x7f) return false;
    return true;
}
