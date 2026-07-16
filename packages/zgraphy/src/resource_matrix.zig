const std = @import("std");
const builtin = @import("builtin");
const assets = @import("zgraphy_benchmark_assets");
const memory = @import("memory.zig");
const model = @import("model.zig");
const parity = @import("parity.zig");

pub const schema = "zgraphy.resource-matrix.v1";
pub const schema_version: u32 = 1;
pub const promotion_status = "baseline_only";
pub const supervisor_version = "zgraphy-local-supervisor-v1";
pub const max_repetitions: u16 = 256;
pub const max_sample_file_bytes: usize = 16 * 1024 * 1024;
pub const sample_file_schema = "zgraphy.resource-samples.v1";
pub const embedded_baseline = assets.resource_matrix;

pub const Engine = enum {
    graphify,
    zgraphy,
};

pub const Workload = enum {
    cold_build,
    warm_unchanged_build,
    one_file_modify,
    rename,
    delete,
    bounded_query,
};

pub const observation_schema = "zgraphy.workload-observation.v1";

pub const WorkloadObservation = struct {
    schema: []const u8 = observation_schema,
    schema_version: u32 = schema_version,
    engine: Engine = .zgraphy,
    fixture_id: []const u8,
    workload: Workload,
    workload_elapsed_ns: u64,
    persisted_bytes: u64,
    nodes: usize,
    relations: usize,
    vectors: usize,
    dangling_edges: usize,
    true_orphans: usize,
    unowned_vectors: usize,
    graph_fingerprint: []const u8,
    entities_expected: usize,
    entities_matched: usize,
    relations_expected: usize,
    relations_matched: usize,
    identities: []const IdentityProbe,
    snapshot_complete: bool,
    peak_rss_source: []const u8 = "external_process_supervisor_required",
};

pub const IdentityProbe = struct {
    id: u64,
    kind: model.NodeKind,
    label: []const u8,
    path: []const u8,
};

pub const Identity = struct {
    corpus_digest: []const u8,
    zgraphy_source_revision: []const u8,
    graphify_python: []const u8,
    graphify_environment_digest: []const u8,
    machine_digest: []const u8,
    configuration_digest: []const u8,
};

pub const Sampling = struct {
    warmups: u16,
    repetitions: u16,
    supervisor: []const u8 = supervisor_version,
};

pub const Sample = struct {
    fixture_id: []const u8,
    engine: Engine,
    workload: Workload,
    repetition: u16,
    elapsed_ns: u64,
    user_cpu_ns: u64 = 0,
    system_cpu_ns: u64 = 0,
    peak_rss_bytes: u64,
    persisted_bytes: u64,
    nodes: usize,
    relations: usize,
    facts: usize = 0,
    exit_code: u8 = 0,
    projection_valid: bool = true,
};

pub const SampleFile = struct {
    schema: []const u8,
    schema_version: u32,
    samples: []const Sample,
};

pub const Statistics = struct {
    minimum: u64,
    p50: u64,
    p95: u64,
    p99: u64,
    maximum: u64,
};

pub const Aggregate = struct {
    fixture_id: []const u8,
    engine: Engine,
    workload: Workload,
    sample_count: u16,
    elapsed_ns: Statistics,
    user_cpu_ns: Statistics,
    system_cpu_ns: Statistics,
    peak_rss_bytes: Statistics,
    persisted_bytes: Statistics,
    nodes: usize,
    relations: usize,
    facts: usize,
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

const limitations = [_][]const u8{
    "candidate engineering baseline; no performance superiority claim",
    "peak RSS is process-supervisor evidence and is not inferred from allocator counts",
};

pub const Receipt = struct {
    schema: []const u8 = schema,
    schema_version: u32 = schema_version,
    promotion_status: []const u8 = promotion_status,
    identity: Identity,
    baseline: Baseline = .{},
    toolchain: Toolchain = .{},
    sampling: Sampling,
    samples: []Sample,
    aggregates: []Aggregate,
    comparison_eligible: bool = true,
    claims: []const []const u8 = &.{},
    limitations: []const []const u8 = &limitations,

    pub fn deinit(self: *Receipt, allocator: std.mem.Allocator) void {
        allocator.free(self.aggregates);
        allocator.free(self.samples);
        self.aggregates = &.{};
        self.samples = &.{};
    }
};

const Group = struct {
    fixture_id: []const u8,
    engine: Engine,
    workload: Workload,
};

pub fn build(
    allocator: std.mem.Allocator,
    identity: Identity,
    sampling: Sampling,
    input_samples: []const Sample,
) !Receipt {
    try validateIdentity(identity);
    try validateSampling(sampling);
    if (input_samples.len == 0) return error.IncompleteResourceSamples;

    var groups: std.ArrayList(Group) = .empty;
    defer groups.deinit(allocator);
    for (input_samples, 0..) |sample, index| {
        try validateSample(sample, sampling);
        for (input_samples[0..index]) |previous| {
            if (sameSampleKey(previous, sample)) return error.DuplicateResourceSample;
        }
        if (!containsGroup(groups.items, sample)) {
            try groups.append(allocator, .{
                .fixture_id = sample.fixture_id,
                .engine = sample.engine,
                .workload = sample.workload,
            });
        }
    }
    for (groups.items) |group| {
        if (!containsPairedGroup(groups.items, group)) return error.IncompleteResourceSamples;
    }

    const samples = try memory.copy(Sample, allocator, input_samples);
    errdefer allocator.free(samples);
    const aggregates = try memory.slice(Aggregate, allocator, groups.items.len);
    errdefer allocator.free(aggregates);
    for (groups.items, 0..) |group, index| {
        aggregates[index] = try aggregateGroup(samples, group, sampling.repetitions);
    }

    var receipt = Receipt{
        .identity = identity,
        .sampling = sampling,
        .samples = samples,
        .aggregates = aggregates,
    };
    try validate(&receipt);
    return receipt;
}

pub fn parseSampleFile(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(SampleFile) {
    if (bytes.len == 0 or bytes.len > max_sample_file_bytes) return error.InvalidResourceSampleFile;
    const parsed = std.json.parseFromSlice(SampleFile, allocator, bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = false,
    }) catch return error.InvalidResourceSampleFile;
    if (!std.mem.eql(u8, parsed.value.schema, sample_file_schema) or parsed.value.schema_version != schema_version) {
        var owned = parsed;
        owned.deinit();
        return error.InvalidResourceSampleFile;
    }
    return parsed;
}

pub fn parseEmbeddedBaseline(allocator: std.mem.Allocator) !std.json.Parsed(Receipt) {
    return std.json.parseFromSlice(Receipt, allocator, embedded_baseline, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = false,
    });
}

pub fn validate(receipt: *const Receipt) !void {
    if (!std.mem.eql(u8, receipt.schema, schema) or receipt.schema_version != schema_version or
        !std.mem.eql(u8, receipt.promotion_status, promotion_status))
    {
        return error.IncompatibleResourceMatrix;
    }
    try validateIdentity(receipt.identity);
    try validateSampling(receipt.sampling);
    if (!std.mem.eql(u8, receipt.baseline.product, "Graphify") or
        !std.mem.eql(u8, receipt.baseline.version, parity.pinned_graphify_version) or
        !std.mem.eql(u8, receipt.baseline.commit, parity.pinned_graphify_commit))
    {
        return error.InvalidResourceBaseline;
    }
    if (receipt.toolchain.zig.len == 0 or receipt.toolchain.architecture.len == 0 or
        receipt.toolchain.operating_system.len == 0 or receipt.toolchain.abi.len == 0 or
        receipt.toolchain.optimize.len == 0)
    {
        return error.InvalidResourceToolchain;
    }
    if (!receipt.comparison_eligible or receipt.claims.len != 0 or receipt.limitations.len != limitations.len or
        receipt.samples.len == 0 or receipt.aggregates.len == 0)
    {
        return error.IncompleteResourceMatrix;
    }
    for (limitations, receipt.limitations) |expected, actual| {
        if (!std.mem.eql(u8, expected, actual)) return error.InvalidResourceLimitations;
    }
    for (receipt.samples, 0..) |sample, index| {
        try validateSample(sample, receipt.sampling);
        for (receipt.samples[0..index]) |previous| {
            if (sameSampleKey(previous, sample)) return error.DuplicateResourceSample;
        }
    }
    var expected_aggregate_count: usize = 0;
    for (receipt.samples, 0..) |sample, index| {
        var first_group = true;
        for (receipt.samples[0..index]) |previous| {
            if (previous.engine == sample.engine and previous.workload == sample.workload and
                std.mem.eql(u8, previous.fixture_id, sample.fixture_id))
            {
                first_group = false;
                break;
            }
        }
        if (first_group) expected_aggregate_count += 1;
    }
    if (receipt.aggregates.len != expected_aggregate_count) return error.IncompleteResourceMatrix;
    for (receipt.aggregates, 0..) |aggregate, index| {
        const expected = try aggregateGroup(receipt.samples, .{
            .fixture_id = aggregate.fixture_id,
            .engine = aggregate.engine,
            .workload = aggregate.workload,
        }, receipt.sampling.repetitions);
        if (!aggregateEqual(aggregate, expected)) return error.InconsistentResourceAggregate;
        for (receipt.aggregates[0..index]) |previous| {
            if (sameAggregateKey(previous, aggregate)) return error.DuplicateResourceAggregate;
        }
        const paired = findAggregate(receipt, otherEngine(aggregate.engine), aggregate.fixture_id, aggregate.workload);
        if (paired == null) return error.IncompleteResourceSamples;
    }
}

pub fn findAggregate(receipt: *const Receipt, engine: Engine, fixture_id: []const u8, workload: Workload) ?*const Aggregate {
    for (receipt.aggregates, 0..) |aggregate, index| {
        if (aggregate.engine == engine and aggregate.workload == workload and std.mem.eql(u8, aggregate.fixture_id, fixture_id)) {
            return &receipt.aggregates[index];
        }
    }
    return null;
}

pub fn validateObservation(observation: *const WorkloadObservation) !void {
    if (!std.mem.eql(u8, observation.schema, observation_schema) or observation.schema_version != schema_version or
        observation.engine != .zgraphy or observation.fixture_id.len == 0 or observation.fixture_id.len > 160 or
        observation.workload_elapsed_ns == 0 or observation.persisted_bytes == 0 or observation.nodes == 0 or
        observation.vectors != observation.nodes or observation.dangling_edges != 0 or observation.true_orphans != 0 or
        observation.unowned_vectors != 0 or !validSha256Identity(observation.graph_fingerprint) or
        observation.entities_matched > observation.entities_expected or observation.relations_matched > observation.relations_expected or
        observation.identities.len != observation.nodes or observation.identities.len > 1024 or !validIdentityProbes(observation.identities) or
        !observation.snapshot_complete or
        !std.mem.eql(u8, observation.peak_rss_source, "external_process_supervisor_required"))
    {
        return error.InvalidWorkloadObservation;
    }
}

fn validIdentityProbes(probes: []const IdentityProbe) bool {
    for (probes, 0..) |probe, index| {
        if (probe.id == 0 or probe.label.len == 0 or probe.label.len > 256 or probe.path.len > 4096) return false;
        for (probes[0..index]) |previous| if (previous.id == probe.id) return false;
    }
    return true;
}

fn aggregateGroup(samples: []const Sample, group: Group, repetitions: u16) !Aggregate {
    var elapsed: [max_repetitions]u64 = @splat(0);
    var user_cpu: [max_repetitions]u64 = @splat(0);
    var system_cpu: [max_repetitions]u64 = @splat(0);
    var peak_rss: [max_repetitions]u64 = @splat(0);
    var persisted: [max_repetitions]u64 = @splat(0);
    var count: usize = 0;
    var nodes: usize = 0;
    var relations: usize = 0;
    var facts: usize = 0;
    for (samples) |sample| {
        if (sample.engine != group.engine or sample.workload != group.workload or !std.mem.eql(u8, sample.fixture_id, group.fixture_id)) continue;
        if (count >= repetitions) return error.DuplicateResourceSample;
        if (count == 0) {
            nodes = sample.nodes;
            relations = sample.relations;
            facts = sample.facts;
        } else if (nodes != sample.nodes or relations != sample.relations or facts != sample.facts) {
            return error.InconsistentResourceProjection;
        }
        elapsed[count] = sample.elapsed_ns;
        user_cpu[count] = sample.user_cpu_ns;
        system_cpu[count] = sample.system_cpu_ns;
        peak_rss[count] = sample.peak_rss_bytes;
        persisted[count] = sample.persisted_bytes;
        count += 1;
    }
    if (count != repetitions) return error.IncompleteResourceSamples;
    return .{
        .fixture_id = group.fixture_id,
        .engine = group.engine,
        .workload = group.workload,
        .sample_count = repetitions,
        .elapsed_ns = statistics(elapsed[0..count]),
        .user_cpu_ns = statistics(user_cpu[0..count]),
        .system_cpu_ns = statistics(system_cpu[0..count]),
        .peak_rss_bytes = statistics(peak_rss[0..count]),
        .persisted_bytes = statistics(persisted[0..count]),
        .nodes = nodes,
        .relations = relations,
        .facts = facts,
    };
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

fn validateIdentity(identity: Identity) !void {
    if (!validSha256Identity(identity.corpus_digest) or
        !validSha256Identity(identity.zgraphy_source_revision) or
        !validSha256Identity(identity.graphify_environment_digest) or
        !validSha256Identity(identity.machine_digest) or
        !validSha256Identity(identity.configuration_digest) or
        identity.graphify_python.len == 0 or identity.graphify_python.len > 64)
    {
        return error.InvalidResourceIdentity;
    }
}

fn validateSampling(sampling: Sampling) !void {
    if (sampling.warmups == 0 or sampling.repetitions < 7 or sampling.repetitions > max_repetitions or
        !std.mem.eql(u8, sampling.supervisor, supervisor_version))
    {
        return error.InvalidResourceSampling;
    }
}

fn validateSample(sample: Sample, sampling: Sampling) !void {
    if (sample.fixture_id.len == 0 or sample.fixture_id.len > 160 or sample.repetition == 0 or
        sample.repetition > sampling.repetitions or sample.elapsed_ns == 0 or sample.peak_rss_bytes == 0 or
        sample.persisted_bytes == 0 or sample.nodes == 0 or sample.exit_code != 0 or !sample.projection_valid)
    {
        return error.InvalidResourceSample;
    }
}

fn validSha256Identity(value: []const u8) bool {
    const prefix = "sha256:";
    if (!std.mem.startsWith(u8, value, prefix) or value.len != prefix.len + 64) return false;
    for (value[prefix.len..]) |byte| {
        if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    }
    return true;
}

fn containsGroup(groups: []const Group, sample: Sample) bool {
    for (groups) |group| {
        if (group.engine == sample.engine and group.workload == sample.workload and std.mem.eql(u8, group.fixture_id, sample.fixture_id)) return true;
    }
    return false;
}

fn containsPairedGroup(groups: []const Group, group: Group) bool {
    for (groups) |candidate| {
        if (candidate.engine == otherEngine(group.engine) and candidate.workload == group.workload and
            std.mem.eql(u8, candidate.fixture_id, group.fixture_id)) return true;
    }
    return false;
}

fn otherEngine(engine: Engine) Engine {
    return if (engine == .graphify) .zgraphy else .graphify;
}

fn sameSampleKey(left: Sample, right: Sample) bool {
    return left.engine == right.engine and left.workload == right.workload and left.repetition == right.repetition and
        std.mem.eql(u8, left.fixture_id, right.fixture_id);
}

fn sameAggregateKey(left: Aggregate, right: Aggregate) bool {
    return left.engine == right.engine and left.workload == right.workload and std.mem.eql(u8, left.fixture_id, right.fixture_id);
}

fn aggregateEqual(left: Aggregate, right: Aggregate) bool {
    return sameAggregateKey(left, right) and left.sample_count == right.sample_count and
        statisticsEqual(left.elapsed_ns, right.elapsed_ns) and statisticsEqual(left.user_cpu_ns, right.user_cpu_ns) and
        statisticsEqual(left.system_cpu_ns, right.system_cpu_ns) and statisticsEqual(left.peak_rss_bytes, right.peak_rss_bytes) and
        statisticsEqual(left.persisted_bytes, right.persisted_bytes) and left.nodes == right.nodes and
        left.relations == right.relations and left.facts == right.facts;
}

fn statisticsEqual(left: Statistics, right: Statistics) bool {
    return left.minimum == right.minimum and left.p50 == right.p50 and left.p95 == right.p95 and
        left.p99 == right.p99 and left.maximum == right.maximum;
}
