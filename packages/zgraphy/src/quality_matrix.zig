const std = @import("std");
const builtin = @import("builtin");
const assets = @import("zgraphy_benchmark_assets");
const differential = @import("differential.zig");
const memory = @import("memory.zig");
const parity = @import("parity.zig");

pub const schema = "zgraphy.quality-matrix.v1";
pub const schema_version: u32 = 1;
pub const promotion_status = "baseline_only";
pub const embedded_baseline = assets.quality_matrix;

pub const Engine = enum {
    graphify,
    zgraphy,
    lexical,
};

pub const Identity = struct {
    corpus_digest: []const u8,
    zgraphy_source_revision: []const u8,
    graphify_python: []const u8,
    graphify_environment_digest: []const u8,
};

pub const Baseline = struct {
    product: []const u8 = "Graphify",
    version: []const u8 = parity.pinned_graphify_version,
    commit: []const u8 = parity.pinned_graphify_commit,
};

pub const GraphifyEnvironment = struct {
    python: []const u8,
    digest: []const u8,
};

pub const Toolchain = struct {
    zig: []const u8 = builtin.zig_version_string,
    architecture: []const u8 = @tagName(builtin.target.cpu.arch),
    operating_system: []const u8 = @tagName(builtin.target.os.tag),
    abi: []const u8 = @tagName(builtin.target.abi),
    optimize: []const u8 = @tagName(builtin.mode),
};

pub const Run = struct {
    fixture_id: []const u8,
    engine: Engine,
    entities: differential.Score,
    relations: differential.Score,
    facts: differential.Score,
    hyperedges: differential.Score,
    supernodes: differential.Score,

    pub fn fromReceipt(receipt: *const differential.Receipt) !Run {
        return .{
            .fixture_id = receipt.fixture_id,
            .engine = try engineFromAdapter(receipt.adapter.engine),
            .entities = receipt.entities,
            .relations = receipt.relations,
            .facts = receipt.facts,
            .hyperedges = receipt.hyperedges,
            .supernodes = receipt.supernodes,
        };
    }
};

pub const EngineQuality = struct {
    engine: Engine,
    entities: differential.Score,
    relations: differential.Score,
    facts: differential.Score,
    hyperedges: differential.Score,
    supernodes: differential.Score,
};

pub const FixtureComparison = struct {
    fixture_id: []const u8,
    engines: [3]EngineQuality,
};

pub const Aggregate = EngineQuality;

const limitations = [_][]const u8{
    "quality-only receipt; latency memory storage and freshness are excluded",
    "candidate engineering baseline; no superiority claim",
};

const required_fixtures = [_][]const u8{
    "zig-ambiguity",
    "fullstack-orders",
    "mutation-pruning",
};

pub const Receipt = struct {
    schema: []const u8 = schema,
    schema_version: u32 = schema_version,
    promotion_status: []const u8 = promotion_status,
    corpus_digest: []const u8,
    zgraphy_source_revision: []const u8,
    baseline: Baseline = .{},
    graphify_environment: GraphifyEnvironment,
    toolchain: Toolchain = .{},
    fixtures: []FixtureComparison,
    aggregates: [3]Aggregate,
    claims: []const []const u8 = &.{},
    limitations: []const []const u8 = &limitations,

    pub fn deinit(self: *Receipt, allocator: std.mem.Allocator) void {
        allocator.free(self.fixtures);
        self.fixtures = &.{};
    }
};

pub fn build(allocator: std.mem.Allocator, identity: Identity, runs: []const Run) !Receipt {
    if (runs.len != required_fixtures.len * 3) return error.IncompleteQualityMatrix;

    const fixtures = try memory.slice(FixtureComparison, allocator, required_fixtures.len);
    errdefer allocator.free(fixtures);
    for (required_fixtures, 0..) |fixture_id, fixture_index| {
        var qualities: [3]?EngineQuality = .{ null, null, null };
        for (runs) |run| {
            if (!std.mem.eql(u8, run.fixture_id, fixture_id)) continue;
            const index = @intFromEnum(run.engine);
            if (qualities[index] != null) return error.DuplicateQualityRun;
            qualities[index] = qualityFromRun(run);
        }
        for (qualities) |quality| if (quality == null) return error.IncompleteQualityMatrix;
        fixtures[fixture_index] = .{
            .fixture_id = fixture_id,
            .engines = .{ qualities[0].?, qualities[1].?, qualities[2].? },
        };
        for (fixtures[fixture_index].engines, 0..) |quality, engine_index| {
            try validateQuality(&quality);
            if (engine_index > 0) try validateExpectedCounts(&fixtures[fixture_index].engines[0], &quality);
        }
    }
    for (runs) |run| {
        if (!isRequiredFixture(run.fixture_id)) return error.UnknownQualityFixture;
    }

    var receipt = Receipt{
        .corpus_digest = identity.corpus_digest,
        .zgraphy_source_revision = identity.zgraphy_source_revision,
        .graphify_environment = .{
            .python = identity.graphify_python,
            .digest = identity.graphify_environment_digest,
        },
        .fixtures = fixtures,
        .aggregates = aggregateFixtures(fixtures),
    };
    try validate(&receipt);
    return receipt;
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
        return error.IncompatibleQualityMatrix;
    }
    if (!validSha256Identity(receipt.corpus_digest) or
        !validSha256Identity(receipt.zgraphy_source_revision) or
        !validSha256Identity(receipt.graphify_environment.digest) or
        receipt.graphify_environment.python.len == 0 or receipt.graphify_environment.python.len > 64)
    {
        return error.InvalidQualityIdentity;
    }
    if (!std.mem.eql(u8, receipt.baseline.product, "Graphify") or
        !std.mem.eql(u8, receipt.baseline.version, parity.pinned_graphify_version) or
        !std.mem.eql(u8, receipt.baseline.commit, parity.pinned_graphify_commit))
    {
        return error.InvalidQualityBaseline;
    }
    if (receipt.toolchain.zig.len == 0 or receipt.toolchain.architecture.len == 0 or
        receipt.toolchain.operating_system.len == 0 or receipt.toolchain.abi.len == 0 or
        receipt.toolchain.optimize.len == 0)
    {
        return error.InvalidQualityToolchain;
    }
    if (receipt.fixtures.len != required_fixtures.len or receipt.claims.len != 0 or
        receipt.limitations.len != limitations.len)
    {
        return error.IncompleteQualityMatrix;
    }
    for (limitations, receipt.limitations) |expected, actual| {
        if (!std.mem.eql(u8, expected, actual)) return error.InvalidQualityLimitations;
    }
    for (receipt.fixtures, 0..) |fixture, fixture_index| {
        if (!std.mem.eql(u8, fixture.fixture_id, required_fixtures[fixture_index])) return error.InvalidQualityFixtureOrder;
        for (fixture.engines, 0..) |quality, engine_index| {
            if (@intFromEnum(quality.engine) != engine_index) return error.InvalidQualityEngineOrder;
            try validateQuality(&quality);
            if (engine_index > 0) try validateExpectedCounts(&fixture.engines[0], &quality);
        }
    }
    const expected_aggregates = aggregateFixtures(receipt.fixtures);
    for (receipt.aggregates, expected_aggregates, 0..) |actual, expected, index| {
        if (@intFromEnum(actual.engine) != index or !qualityEqual(actual, expected)) {
            return error.InconsistentQualityAggregate;
        }
    }
}

pub fn findAggregate(receipt: *const Receipt, engine: Engine) ?*const Aggregate {
    for (receipt.aggregates, 0..) |aggregate, index| {
        if (aggregate.engine == engine) return &receipt.aggregates[index];
    }
    return null;
}

fn qualityFromRun(run: Run) EngineQuality {
    return .{
        .engine = run.engine,
        .entities = run.entities,
        .relations = run.relations,
        .facts = run.facts,
        .hyperedges = run.hyperedges,
        .supernodes = run.supernodes,
    };
}

fn aggregateFixtures(fixtures: []const FixtureComparison) [3]Aggregate {
    var result = [_]Aggregate{
        emptyAggregate(.graphify),
        emptyAggregate(.zgraphy),
        emptyAggregate(.lexical),
    };
    for (0..3) |engine_index| {
        var entities = Counts{};
        var relations = Counts{};
        var facts = Counts{};
        var hyperedges = Counts{};
        var supernodes = Counts{};
        for (fixtures) |fixture| {
            const quality = fixture.engines[engine_index];
            entities.include(quality.entities);
            relations.include(quality.relations);
            facts.include(quality.facts);
            hyperedges.include(quality.hyperedges);
            supernodes.include(quality.supernodes);
        }
        result[engine_index] = .{
            .engine = @enumFromInt(engine_index),
            .entities = entities.score(),
            .relations = relations.score(),
            .facts = facts.score(),
            .hyperedges = hyperedges.score(),
            .supernodes = supernodes.score(),
        };
    }
    return result;
}

fn emptyAggregate(engine: Engine) Aggregate {
    const empty = differential.scoreCounts(0, 0, 0);
    return .{
        .engine = engine,
        .entities = empty,
        .relations = empty,
        .facts = empty,
        .hyperedges = empty,
        .supernodes = empty,
    };
}

const Counts = struct {
    expected: usize = 0,
    matched: usize = 0,
    unexpected: usize = 0,

    fn include(self: *Counts, value: differential.Score) void {
        self.expected += value.expected;
        self.matched += value.matched;
        self.unexpected += value.unexpected;
    }

    fn score(self: Counts) differential.Score {
        return differential.scoreCounts(self.expected, self.matched, self.unexpected);
    }
};

fn validateQuality(quality: *const EngineQuality) !void {
    try validateScore(quality.entities);
    try validateScore(quality.relations);
    try validateScore(quality.facts);
    try validateScore(quality.hyperedges);
    try validateScore(quality.supernodes);
}

fn validateScore(value: differential.Score) !void {
    if (value.matched > value.expected) return error.InvalidQualityScore;
    if (!scoreEqual(value, differential.scoreCounts(value.expected, value.matched, value.unexpected))) {
        return error.InvalidQualityScore;
    }
}

fn validateExpectedCounts(reference: *const EngineQuality, candidate: *const EngineQuality) !void {
    if (reference.entities.expected != candidate.entities.expected or
        reference.relations.expected != candidate.relations.expected or
        reference.facts.expected != candidate.facts.expected or
        reference.hyperedges.expected != candidate.hyperedges.expected or
        reference.supernodes.expected != candidate.supernodes.expected)
    {
        return error.InconsistentQualityExpectations;
    }
}

fn qualityEqual(left: EngineQuality, right: EngineQuality) bool {
    return left.engine == right.engine and
        scoreEqual(left.entities, right.entities) and
        scoreEqual(left.relations, right.relations) and
        scoreEqual(left.facts, right.facts) and
        scoreEqual(left.hyperedges, right.hyperedges) and
        scoreEqual(left.supernodes, right.supernodes);
}

fn scoreEqual(left: differential.Score, right: differential.Score) bool {
    return left.expected == right.expected and left.matched == right.matched and
        left.missing == right.missing and left.unexpected == right.unexpected and
        left.recall == right.recall and left.conservative_precision == right.conservative_precision and
        left.f1 == right.f1;
}

fn engineFromAdapter(engine: []const u8) !Engine {
    if (std.mem.eql(u8, engine, "Graphify")) return .graphify;
    if (std.mem.eql(u8, engine, "zgraphy")) return .zgraphy;
    if (std.mem.eql(u8, engine, "lexical")) return .lexical;
    return error.UnknownQualityEngine;
}

fn isRequiredFixture(fixture_id: []const u8) bool {
    for (required_fixtures) |required| if (std.mem.eql(u8, fixture_id, required)) return true;
    return false;
}

fn validSha256Identity(value: []const u8) bool {
    const prefix = "sha256:";
    if (!std.mem.startsWith(u8, value, prefix) or value.len != prefix.len + 64) return false;
    for (value[prefix.len..]) |byte| {
        if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    }
    return true;
}
