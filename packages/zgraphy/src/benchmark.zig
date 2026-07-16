const std = @import("std");
const parity = @import("parity.zig");
const assets = @import("zgraphy_benchmark_assets");

pub const corpus_schema = "zgraphy.benchmark-corpus.v1";
pub const canonical_ir_schema = "zgraphy.canonical-benchmark-ir.v1";
pub const schema_version: u32 = 1;
pub const max_fixture_bytes: usize = 1024 * 1024;

pub const embedded_corpus = assets.corpus;
const embedded_zig_ambiguity = assets.zig_ambiguity;
const embedded_fullstack_orders = assets.fullstack_orders;
const embedded_mutation_pruning = assets.mutation_pruning;

pub const Baseline = struct {
    product: []const u8,
    version: []const u8,
    commit: []const u8,
};

pub const MutationOperation = enum {
    create,
    modify,
    rename,
    delete,
};

pub const Mutation = struct {
    id: []const u8,
    operation: MutationOperation,
    path: []const u8,
    to_path: ?[]const u8,
    replacement_path: ?[]const u8,
    replacement_sha256: ?[]const u8,
    expected_removed_entities: []const []const u8,
    expected_preserved_entities: []const []const u8,
    expected_invalidated_facts: []const []const u8,
    expected_no_orphans: bool,
};

pub const Fixture = struct {
    id: []const u8,
    title: []const u8,
    root: []const u8,
    scan_root: []const u8,
    gold: []const u8,
    languages: []const []const u8,
    capabilities: []const []const u8,
    held_out: bool,
    mutations: []const Mutation,
};

pub const Corpus = struct {
    schema: []const u8,
    schema_version: u32,
    canonical_ir_schema: []const u8,
    baseline: Baseline,
    fixtures: []const Fixture,
};

pub const EntityKind = enum {
    repository,
    file,
    module_alias,
    local_binding,
    function,
    type,
    service,
    rpc_method,
    message,
    client,
    component,
    @"test",
};

pub const RelationKind = enum {
    contains,
    declares,
    imports,
    calls,
    references,
    generated_from,
    invokes_contract,
    implements_contract,
    covers,
    selects_candidate,
};

pub const Provenance = enum {
    extracted,
    resolved,
    derived,
    ambiguous,
};

pub const RetrievalIntent = enum {
    orientation,
    explanation,
    change_impact,
    ambiguity,
    freshness,
};

pub const HyperedgeKind = enum {
    request_path,
    ambiguity_set,
};

pub const SupernodeKind = enum {
    feature,
    application,
    subsystem,
};

pub const SourceSpan = struct {
    path: []const u8,
    content_sha256: []const u8,
    start_line: u32,
    start_column: u32,
    end_line: u32,
    end_column: u32,
};

pub const Evidence = struct {
    id: []const u8,
    source: SourceSpan,
};

pub const Entity = struct {
    id: []const u8,
    kind: EntityKind,
    name: []const u8,
    evidence: []const []const u8,
};

pub const Relation = struct {
    id: []const u8,
    kind: RelationKind,
    from: []const u8,
    to: []const u8,
    provenance: Provenance,
    confidence: f64,
    evidence: []const []const u8,
};

pub const Fact = struct {
    id: []const u8,
    subject: []const u8,
    predicate: []const u8,
    value: []const u8,
    provenance: Provenance,
    confidence: f64,
    evidence: []const []const u8,
    alternatives: []const []const u8,
};

pub const Participant = struct {
    entity: []const u8,
    role: []const u8,
};

pub const Hyperedge = struct {
    id: []const u8,
    kind: HyperedgeKind,
    participants: []const Participant,
    evidence: []const []const u8,
};

pub const Supernode = struct {
    id: []const u8,
    kind: SupernodeKind,
    name: []const u8,
    members: []const []const u8,
    proof_relations: []const []const u8,
    synopsis: []const u8,
};

pub const RetrievalTask = struct {
    id: []const u8,
    intent: RetrievalIntent,
    query: []const u8,
    required_entities: []const []const u8,
    required_relations: []const []const u8,
    required_facts: []const []const u8,
    max_results: u32,
};

pub const CanonicalIr = struct {
    schema: []const u8,
    schema_version: u32,
    fixture_id: []const u8,
    generation: u64,
    evidence: []const Evidence,
    entities: []const Entity,
    relations: []const Relation,
    facts: []const Fact,
    hyperedges: []const Hyperedge,
    supernodes: []const Supernode,
    retrieval_tasks: []const RetrievalTask,
};

pub const CorpusSummary = struct {
    fixtures: usize = 0,
    languages: usize = 0,
    mutations: usize = 0,
    evidence: usize = 0,
    entities: usize = 0,
    relations: usize = 0,
    facts: usize = 0,
    hyperedges: usize = 0,
    supernodes: usize = 0,
    retrieval_tasks: usize = 0,

    pub fn include(self: *CorpusSummary, fixture: *const Fixture, gold: *const CanonicalIr) void {
        self.fixtures += 1;
        self.languages += fixture.languages.len;
        self.mutations += fixture.mutations.len;
        self.evidence += gold.evidence.len;
        self.entities += gold.entities.len;
        self.relations += gold.relations.len;
        self.facts += gold.facts.len;
        self.hyperedges += gold.hyperedges.len;
        self.supernodes += gold.supernodes.len;
        self.retrieval_tasks += gold.retrieval_tasks.len;
    }
};

pub fn parseEmbeddedCorpus(allocator: std.mem.Allocator) !std.json.Parsed(Corpus) {
    return std.json.parseFromSlice(Corpus, allocator, embedded_corpus, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = false,
    });
}

pub fn parseEmbeddedGold(allocator: std.mem.Allocator, path: []const u8) !std.json.Parsed(CanonicalIr) {
    const bytes = goldBytes(path) orelse return error.UnknownGoldFixture;
    return std.json.parseFromSlice(CanonicalIr, allocator, bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = false,
    });
}

pub fn validateCorpus(corpus: *const Corpus) !void {
    if (!std.mem.eql(u8, corpus.schema, corpus_schema) or corpus.schema_version != schema_version or
        !std.mem.eql(u8, corpus.canonical_ir_schema, canonical_ir_schema))
    {
        return error.IncompatibleBenchmarkCorpus;
    }
    if (!std.mem.eql(u8, corpus.baseline.product, "Graphify") or
        !std.mem.eql(u8, corpus.baseline.version, parity.pinned_graphify_version) or
        !std.mem.eql(u8, corpus.baseline.commit, parity.pinned_graphify_commit))
    {
        return error.InvalidBenchmarkBaseline;
    }
    if (corpus.fixtures.len == 0) return error.EmptyBenchmarkCorpus;
    for (corpus.fixtures, 0..) |fixture, index| {
        if (!validId(fixture.id) or fixture.title.len == 0 or !validRelativePath(fixture.root) or
            !validRelativePath(fixture.scan_root) or !pathWithin(fixture.root, fixture.scan_root) or
            !validRelativePath(fixture.gold) or goldBytes(fixture.gold) == null or
            fixture.languages.len == 0 or fixture.capabilities.len == 0)
        {
            return error.InvalidBenchmarkFixture;
        }
        for (corpus.fixtures[0..index]) |previous| {
            if (std.mem.eql(u8, previous.id, fixture.id) or std.mem.eql(u8, previous.gold, fixture.gold)) {
                return error.DuplicateBenchmarkFixture;
            }
        }
        try validateUniqueStrings(fixture.languages);
        try validateUniqueStrings(fixture.capabilities);
        for (fixture.mutations, 0..) |mutation, mutation_index| {
            try validateMutation(&mutation);
            for (fixture.mutations[0..mutation_index]) |previous| {
                if (std.mem.eql(u8, previous.id, mutation.id)) return error.DuplicateBenchmarkMutation;
            }
        }
    }
}

pub fn canonicalCorpusDigest() [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    const inputs = [_]struct { name: []const u8, bytes: []const u8 }{
        .{ .name = "corpus.v1.json", .bytes = embedded_corpus },
        .{ .name = "zig-ambiguity.canonical.v1.json", .bytes = embedded_zig_ambiguity },
        .{ .name = "fullstack-orders.canonical.v1.json", .bytes = embedded_fullstack_orders },
        .{ .name = "mutation-pruning.canonical.v1.json", .bytes = embedded_mutation_pruning },
    };
    for (inputs) |input| {
        hasher.update(input.name);
        hasher.update(&.{0});
        hasher.update(input.bytes);
        hasher.update(&.{0});
    }
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    return digest;
}

pub fn validateGold(gold: *const CanonicalIr, expected_fixture: []const u8) !void {
    if (!std.mem.eql(u8, gold.schema, canonical_ir_schema) or gold.schema_version != schema_version) {
        return error.IncompatibleCanonicalIr;
    }
    if (!std.mem.eql(u8, gold.fixture_id, expected_fixture) or gold.generation != 0) {
        return error.InvalidCanonicalGeneration;
    }
    if (gold.evidence.len == 0 or gold.entities.len == 0 or gold.relations.len == 0 or gold.retrieval_tasks.len == 0) {
        return error.EmptyCanonicalIr;
    }

    for (gold.evidence, 0..) |item, index| {
        if (!validId(item.id) or !validSpan(&item.source)) return error.InvalidCanonicalEvidence;
        for (gold.evidence[0..index]) |previous| {
            if (std.mem.eql(u8, previous.id, item.id)) return error.DuplicateCanonicalEvidence;
        }
    }
    for (gold.entities, 0..) |entity, index| {
        if (!validId(entity.id) or entity.name.len == 0 or entity.evidence.len == 0) return error.InvalidCanonicalEntity;
        try validateEvidenceReferences(gold, entity.evidence);
        for (gold.entities[0..index]) |previous| {
            if (std.mem.eql(u8, previous.id, entity.id)) return error.DuplicateCanonicalEntity;
        }
    }
    for (gold.relations, 0..) |relation, index| {
        if (!validId(relation.id) or !hasEntity(gold, relation.from) or !hasEntity(gold, relation.to) or
            relation.confidence < 0 or relation.confidence > 1 or relation.evidence.len == 0)
        {
            return error.InvalidCanonicalRelation;
        }
        try validateEvidenceReferences(gold, relation.evidence);
        for (gold.relations[0..index]) |previous| {
            if (std.mem.eql(u8, previous.id, relation.id)) return error.DuplicateCanonicalRelation;
        }
    }
    for (gold.facts, 0..) |fact, index| {
        if (!validId(fact.id) or !hasEntity(gold, fact.subject) or fact.predicate.len == 0 or fact.value.len == 0 or
            fact.confidence < 0 or fact.confidence > 1 or fact.evidence.len == 0)
        {
            return error.InvalidCanonicalFact;
        }
        try validateEvidenceReferences(gold, fact.evidence);
        for (fact.alternatives) |alternative| if (!hasEntity(gold, alternative)) return error.InvalidCanonicalFact;
        for (gold.facts[0..index]) |previous| {
            if (std.mem.eql(u8, previous.id, fact.id)) return error.DuplicateCanonicalFact;
        }
    }
    for (gold.hyperedges, 0..) |hyperedge, index| {
        if (!validId(hyperedge.id) or hyperedge.participants.len < 2 or hyperedge.evidence.len == 0) return error.InvalidCanonicalHyperedge;
        try validateEvidenceReferences(gold, hyperedge.evidence);
        for (hyperedge.participants, 0..) |participant, participant_index| {
            if (!hasEntity(gold, participant.entity) or participant.role.len == 0) return error.InvalidCanonicalHyperedge;
            for (hyperedge.participants[0..participant_index]) |previous| {
                if (std.mem.eql(u8, previous.entity, participant.entity) or std.mem.eql(u8, previous.role, participant.role)) {
                    return error.InvalidCanonicalHyperedge;
                }
            }
        }
        for (gold.hyperedges[0..index]) |previous| {
            if (std.mem.eql(u8, previous.id, hyperedge.id)) return error.DuplicateCanonicalHyperedge;
        }
    }
    for (gold.supernodes, 0..) |supernode, index| {
        if (!validId(supernode.id) or supernode.name.len == 0 or supernode.synopsis.len == 0 or
            supernode.members.len < 2 or supernode.proof_relations.len == 0)
        {
            return error.InvalidCanonicalSupernode;
        }
        for (supernode.members) |member| if (!hasEntity(gold, member)) return error.InvalidCanonicalSupernode;
        for (supernode.proof_relations) |relation| if (!hasRelation(gold, relation)) return error.InvalidCanonicalSupernode;
        for (gold.supernodes[0..index]) |previous| {
            if (std.mem.eql(u8, previous.id, supernode.id)) return error.DuplicateCanonicalSupernode;
        }
    }
    for (gold.retrieval_tasks, 0..) |task, index| {
        if (!validId(task.id) or task.query.len == 0 or task.max_results == 0 or task.max_results > 64 or
            task.required_entities.len == 0)
        {
            return error.InvalidCanonicalRetrievalTask;
        }
        for (task.required_entities) |entity| if (!hasEntity(gold, entity)) return error.InvalidCanonicalRetrievalTask;
        for (task.required_relations) |relation| if (!hasRelation(gold, relation)) return error.InvalidCanonicalRetrievalTask;
        for (task.required_facts) |fact| if (!hasFact(gold, fact)) return error.InvalidCanonicalRetrievalTask;
        for (gold.retrieval_tasks[0..index]) |previous| {
            if (std.mem.eql(u8, previous.id, task.id)) return error.DuplicateCanonicalRetrievalTask;
        }
    }
}

pub fn validateSources(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    fixture: *const Fixture,
    gold: *const CanonicalIr,
) !void {
    for (gold.evidence) |item| {
        const path = try std.fs.path.join(allocator, &.{ fixture.root, item.source.path });
        defer allocator.free(path);
        const source = try root.readFileAlloc(io, path, allocator, .limited(max_fixture_bytes));
        defer allocator.free(source);
        try validateContentHash(source, item.source.content_sha256);
        try validateSpanBounds(source, &item.source);
    }
    for (fixture.mutations) |mutation| {
        const replacement = mutation.replacement_path orelse continue;
        const expected_hash = mutation.replacement_sha256 orelse return error.MissingMutationHash;
        const path = try std.fs.path.join(allocator, &.{ fixture.root, replacement });
        defer allocator.free(path);
        const source = try root.readFileAlloc(io, path, allocator, .limited(max_fixture_bytes));
        defer allocator.free(source);
        try validateContentHash(source, expected_hash);
    }
}

pub fn findFixture(corpus: *const Corpus, id: []const u8) ?*const Fixture {
    for (corpus.fixtures, 0..) |fixture, index| {
        if (std.mem.eql(u8, fixture.id, id)) return &corpus.fixtures[index];
    }
    return null;
}

pub fn hasCapability(fixture: *const Fixture, capability: []const u8) bool {
    for (fixture.capabilities) |candidate| if (std.mem.eql(u8, candidate, capability)) return true;
    return false;
}

pub fn hasMutationOperation(fixture: *const Fixture, operation: MutationOperation) bool {
    for (fixture.mutations) |mutation| if (mutation.operation == operation) return true;
    return false;
}

fn validateMutation(mutation: *const Mutation) !void {
    if (!validId(mutation.id) or !validRelativePath(mutation.path) or !mutation.expected_no_orphans) {
        return error.InvalidBenchmarkMutation;
    }
    switch (mutation.operation) {
        .create => if (mutation.to_path == null or mutation.replacement_path == null or mutation.replacement_sha256 == null) return error.InvalidBenchmarkMutation,
        .modify => if (mutation.to_path != null or mutation.replacement_path == null or mutation.replacement_sha256 == null) return error.InvalidBenchmarkMutation,
        .rename => if (mutation.to_path == null or mutation.replacement_path == null or mutation.replacement_sha256 == null) return error.InvalidBenchmarkMutation,
        .delete => if (mutation.to_path != null or mutation.replacement_path != null or mutation.replacement_sha256 != null) return error.InvalidBenchmarkMutation,
    }
    if (mutation.to_path) |path| if (!validRelativePath(path)) return error.InvalidBenchmarkMutation;
    if (mutation.replacement_path) |path| if (!validRelativePath(path)) return error.InvalidBenchmarkMutation;
    if (mutation.replacement_sha256) |hash| if (!validSha256(hash)) return error.InvalidBenchmarkMutation;
    try validateUniqueStrings(mutation.expected_removed_entities);
    try validateUniqueStrings(mutation.expected_preserved_entities);
    try validateUniqueStrings(mutation.expected_invalidated_facts);
}

fn goldBytes(path: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, path, "benchmarks/gold/zig-ambiguity.canonical.v1.json")) return embedded_zig_ambiguity;
    if (std.mem.eql(u8, path, "benchmarks/gold/fullstack-orders.canonical.v1.json")) return embedded_fullstack_orders;
    if (std.mem.eql(u8, path, "benchmarks/gold/mutation-pruning.canonical.v1.json")) return embedded_mutation_pruning;
    return null;
}

fn validateEvidenceReferences(gold: *const CanonicalIr, ids: []const []const u8) !void {
    try validateUniqueStrings(ids);
    for (ids) |id| if (!hasEvidence(gold, id)) return error.MissingCanonicalEvidence;
}

fn hasEvidence(gold: *const CanonicalIr, id: []const u8) bool {
    for (gold.evidence) |item| if (std.mem.eql(u8, item.id, id)) return true;
    return false;
}

fn hasEntity(gold: *const CanonicalIr, id: []const u8) bool {
    for (gold.entities) |item| if (std.mem.eql(u8, item.id, id)) return true;
    return false;
}

fn hasRelation(gold: *const CanonicalIr, id: []const u8) bool {
    for (gold.relations) |item| if (std.mem.eql(u8, item.id, id)) return true;
    return false;
}

fn hasFact(gold: *const CanonicalIr, id: []const u8) bool {
    for (gold.facts) |item| if (std.mem.eql(u8, item.id, id)) return true;
    return false;
}

fn validSpan(span: *const SourceSpan) bool {
    return validRelativePath(span.path) and validSha256(span.content_sha256) and
        span.start_line > 0 and span.start_column > 0 and span.end_line >= span.start_line and span.end_column > 0;
}

fn validateContentHash(source: []const u8, expected: []const u8) !void {
    var digest: [32]u8 = @splat(0);
    std.crypto.hash.sha2.Sha256.hash(source, &digest, .{});
    const actual = std.fmt.bytesToHex(digest, .lower);
    if (!std.mem.eql(u8, &actual, expected)) return error.StaleBenchmarkEvidence;
}

fn validateSpanBounds(source: []const u8, span: *const SourceSpan) !void {
    const start_length = lineLength(source, span.start_line) orelse return error.InvalidBenchmarkSourceSpan;
    const end_length = lineLength(source, span.end_line) orelse return error.InvalidBenchmarkSourceSpan;
    if (span.start_column > start_length + 1 or span.end_column > end_length + 1) return error.InvalidBenchmarkSourceSpan;
    if (span.start_line == span.end_line and span.end_column < span.start_column) return error.InvalidBenchmarkSourceSpan;
}

fn lineLength(source: []const u8, wanted: u32) ?usize {
    var lines = std.mem.splitScalar(u8, source, '\n');
    var line: u32 = 1;
    while (lines.next()) |bytes| : (line += 1) {
        if (line == wanted) return bytes.len;
    }
    return null;
}

fn validRelativePath(path: []const u8) bool {
    if (path.len == 0 or std.fs.path.isAbsolute(path)) return false;
    var segments = std.mem.splitAny(u8, path, "/\\");
    while (segments.next()) |segment| {
        if (segment.len == 0 or std.mem.eql(u8, segment, ".") or std.mem.eql(u8, segment, "..")) return false;
    }
    return true;
}

fn pathWithin(root: []const u8, path: []const u8) bool {
    if (std.mem.eql(u8, root, path)) return true;
    if (!std.mem.startsWith(u8, path, root) or path.len <= root.len) return false;
    return path[root.len] == '/' or path[root.len] == '\\';
}

fn validId(id: []const u8) bool {
    if (id.len == 0 or id.len > 160) return false;
    for (id) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == ':' or byte == '.' or byte == '/') continue;
        return false;
    }
    return true;
}

fn validSha256(hash: []const u8) bool {
    if (hash.len != 64) return false;
    for (hash) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}

fn validateUniqueStrings(values: []const []const u8) !void {
    for (values, 0..) |value, index| {
        if (value.len == 0) return error.EmptyBenchmarkValue;
        for (values[0..index]) |previous| {
            if (std.mem.eql(u8, previous, value)) return error.DuplicateBenchmarkValue;
        }
    }
}
