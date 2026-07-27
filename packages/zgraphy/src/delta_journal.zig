const std = @import("std");
const freshness = @import("freshness.zig");
const memory = @import("memory.zig");
const model = @import("model.zig");
const nendb = @import("zgdb").Store;
const semantic_recipes = @import("semantic_recipes.zig");

pub const schema = "zgraphy.canonical-delta.v1";
pub const schema_version: u32 = 1;
pub const canonical_order_recipe = "canonical-record-order-v1";
pub const default_name = "canonical-delta.jsonl";
pub const max_journal_bytes: usize = 512 * 1024 * 1024;
pub const max_operations: usize = 2_000_000;

pub const Mode = enum {
    checkpoint,
    delta,
};

pub const RecordKind = enum {
    node,
    edge,
    hyperedge,
    supernode,
};

pub const TombstoneCause = enum {
    replaced,
    renamed,
    moved,
    deleted,
    excluded,
    dependency_invalidated,
    reconciled_absent,
};

pub const SourceChange = struct {
    path: []const u8,
    cause: TombstoneCause,
};

pub const CauseCounts = struct {
    replaced: usize = 0,
    renamed: usize = 0,
    moved: usize = 0,
    deleted: usize = 0,
    excluded: usize = 0,
    dependency_invalidated: usize = 0,
    reconciled_absent: usize = 0,
};

pub const Summary = struct {
    operations: usize = 0,
    tombstones: usize = 0,
    upserts: usize = 0,
    node_tombstones: usize = 0,
    edge_tombstones: usize = 0,
    hyperedge_tombstones: usize = 0,
    supernode_tombstones: usize = 0,
    node_upserts: usize = 0,
    edge_upserts: usize = 0,
    hyperedge_upserts: usize = 0,
    supernode_upserts: usize = 0,
    target_nodes: usize = 0,
    target_edges: usize = 0,
    target_vectors: usize = 0,
    target_hyperedges: usize = 0,
    target_supernodes: usize = 0,
    causes: CauseCounts = .{},
};

pub const WriteInput = struct {
    repository_id: []const u8,
    parent_generation: []const u8,
    target_generation: []const u8,
    previous: ?*const model.RepositoryGraph,
    target: *const model.RepositoryGraph,
    source_changes: []const SourceChange = &.{},
};

pub const WriteResult = struct {
    summary: Summary,
    journal_fingerprint: [71]u8,
};

pub const IdentityInput = struct {
    repository_id: []const u8,
    parent_generation: []const u8,
    target_generation: []const u8,
    graph_fingerprint: []const u8,
    index_fingerprint: []const u8,
    target_nodes: usize,
    target_edges: usize,
    target_vectors: usize,
    target_hyperedges: usize,
    target_supernodes: usize,
};

pub const Inspection = struct {
    allocator: std.mem.Allocator,
    mode: Mode,
    repository_id: []const u8,
    parent_generation: []const u8,
    target_generation: []const u8,
    parent_graph_fingerprint: []const u8,
    parent_index_fingerprint: []const u8,
    target_graph_fingerprint: []const u8,
    target_index_fingerprint: []const u8,
    journal_fingerprint: []const u8,
    summary: Summary,

    pub fn deinit(self: *Inspection) void {
        self.allocator.free(self.repository_id);
        if (self.parent_generation.len > 0) self.allocator.free(self.parent_generation);
        self.allocator.free(self.target_generation);
        if (self.parent_graph_fingerprint.len > 0) self.allocator.free(self.parent_graph_fingerprint);
        if (self.parent_index_fingerprint.len > 0) self.allocator.free(self.parent_index_fingerprint);
        self.allocator.free(self.target_graph_fingerprint);
        self.allocator.free(self.target_index_fingerprint);
        self.allocator.free(self.journal_fingerprint);
        self.repository_id = &.{};
        self.parent_generation = &.{};
        self.target_generation = &.{};
        self.parent_graph_fingerprint = &.{};
        self.parent_index_fingerprint = &.{};
        self.target_graph_fingerprint = &.{};
        self.target_index_fingerprint = &.{};
        self.journal_fingerprint = &.{};
        self.summary = .{};
    }
};

const Header = struct {
    record: []const u8 = "header",
    schema: []const u8 = schema,
    schema_version: u32 = schema_version,
    mode: Mode,
    repository_id: []const u8,
    parent_generation: []const u8,
    target_generation: []const u8,
    parent_graph_fingerprint: []const u8,
    parent_index_fingerprint: []const u8,
    target_graph_fingerprint: []const u8,
    target_index_fingerprint: []const u8,
    canonical_order: []const u8 = canonical_order_recipe,
    complete: bool = false,
};

const Footer = struct {
    record: []const u8 = "footer",
    complete: bool = true,
    summary: Summary,
    journal_fingerprint: []const u8,
};

const NodeTombstone = struct {
    record: []const u8 = "node_tombstone",
    sequence: usize,
    kind: RecordKind = .node,
    cause: TombstoneCause,
    id: u64,
    source_path: []const u8,
};

const EdgeTombstone = struct {
    record: []const u8 = "edge_tombstone",
    sequence: usize,
    kind: RecordKind = .edge,
    cause: TombstoneCause,
    from: u64,
    to: u64,
    relation: model.Relation,
    provenance: model.Provenance,
    source_path: []const u8,
    line: u32,
};

const HyperedgeTombstone = struct {
    record: []const u8 = "hyperedge_tombstone",
    sequence: usize,
    kind: RecordKind = .hyperedge,
    cause: TombstoneCause,
    id: u64,
    source_path: []const u8,
};

const SupernodeTombstone = struct {
    record: []const u8 = "supernode_tombstone",
    sequence: usize,
    kind: RecordKind = .supernode,
    cause: TombstoneCause,
    id: u64,
    source_path: []const u8,
};

const NodeUpsert = struct {
    record: []const u8 = "node_upsert",
    sequence: usize,
    id: u64,
    node_kind: model.NodeKind,
    label: []const u8,
    path: []const u8,
    line: u32,
    search_text: []const u8,
    embedding: []const f32,
};

const EdgeUpsert = struct {
    record: []const u8 = "edge_upsert",
    sequence: usize,
    from: u64,
    to: u64,
    relation: model.Relation,
    provenance: model.Provenance,
    source_path: []const u8,
    line: u32,
};

const HyperedgeUpsert = struct {
    record: []const u8 = "hyperedge_upsert",
    sequence: usize,
    id: u64,
    hyperedge_kind: model.HyperedgeKind,
    canonical_name: []const u8,
    recipe: []const u8,
    interaction_fingerprint: [32]u8,
    participants: []const model.Participant,
    evidence: []const model.SourceEvidence,
};

const SupernodeUpsert = struct {
    record: []const u8 = "supernode_upsert",
    sequence: usize,
    id: u64,
    supernode_kind: model.SupernodeKind,
    canonical_name: []const u8,
    name: []const u8,
    recipe: []const u8,
    synopsis: []const u8,
    input_hyperedge_id: u64,
    completeness: model.SupernodeCompleteness,
    members: []const model.SupernodeMember,
    evidence: []const model.SourceEvidence,
    proof_steps: []const model.ProofStep,
};

const Probe = struct {
    record: []const u8,
};

const Phase = enum(u8) {
    supernode_tombstone,
    hyperedge_tombstone,
    edge_tombstone,
    node_tombstone,
    node_upsert,
    edge_upsert,
    hyperedge_upsert,
    supernode_upsert,
};

const EdgeKey = struct {
    from: u64,
    to: u64,
    relation: model.Relation,
};

pub fn canonicalClone(
    allocator: std.mem.Allocator,
    source: *const model.RepositoryGraph,
    options: model.Options,
) !model.RepositoryGraph {
    var result = try model.RepositoryGraph.init(allocator, options);
    errdefer result.deinit();

    const node_order = try orderedNodeIndices(allocator, source);
    defer allocator.free(node_order);
    for (node_order) |index| {
        const node = source.nodes.items[index];
        const id = try result.addNode(.{
            .id = node.id,
            .kind = node.kind,
            .label = node.label,
            .path = node.path,
            .line = node.line,
            .search_text = node.search_text,
        });
        try setEmbedding(&result, id, source.vectorAt(index));
    }

    const edge_order = try orderedEdgeIndices(allocator, source);
    defer allocator.free(edge_order);
    for (edge_order) |index| try result.addEdge(source.edges.items[index]);

    const hyperedge_order = try orderedHyperedgeIndices(allocator, source);
    defer allocator.free(hyperedge_order);
    for (hyperedge_order) |index| {
        const item = source.hyperedges.items[index];
        _ = try result.addHyperedge(.{
            .id = item.id,
            .kind = item.kind,
            .canonical_name = item.canonical_name,
            .recipe = item.recipe,
            .interaction_fingerprint = item.interaction_fingerprint,
            .participants = item.participants,
            .evidence = item.evidence,
        });
    }

    const supernode_order = try orderedSupernodeIndices(allocator, source);
    defer allocator.free(supernode_order);
    for (supernode_order) |index| {
        const item = source.supernodes.items[index];
        _ = try result.addSupernode(.{
            .id = item.id,
            .kind = item.kind,
            .canonical_name = item.canonical_name,
            .name = item.name,
            .recipe = item.recipe,
            .synopsis = item.synopsis,
            .input_hyperedge_id = item.input_hyperedge_id,
            .completeness = item.completeness,
            .members = item.members,
            .evidence = item.evidence,
            .proof_steps = item.proof_steps,
        });
    }
    try result.validateSemanticRecords();
    try semantic_recipes.validateGraph(&result);
    try result.validateSecondaryIndexes();
    return result;
}

pub fn write(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    path: []const u8,
    input: WriteInput,
) !WriteResult {
    try validateRelativePath(path);
    if (input.repository_id.len == 0 or !validGenerationId(input.target_generation)) return error.InvalidDeltaIdentity;
    const mode: Mode = if (input.previous == null) .checkpoint else .delta;
    if ((mode == .checkpoint and input.parent_generation.len != 0) or
        (mode == .delta and !validGenerationId(input.parent_generation))) return error.InvalidDeltaParent;
    try input.target.validateSemanticRecords();
    try semantic_recipes.validateGraph(input.target);
    try input.target.validateSecondaryIndexes();

    const target_graph_digest = try freshness.fingerprint(allocator, input.target);
    const target_graph_identity = sha256Identity(target_graph_digest);
    const target_index_digest = try input.target.secondaryIndexFingerprintValidated(allocator);
    const target_index_identity = sha256Identity(target_index_digest);
    var parent_graph_identity: [71]u8 = @splat(0);
    var parent_index_identity: [71]u8 = @splat(0);
    if (input.previous) |previous| {
        try previous.validateSemanticRecords();
        try semantic_recipes.validateGraph(previous);
        try previous.validateSecondaryIndexes();
        parent_graph_identity = sha256Identity(try freshness.fingerprint(allocator, previous));
        parent_index_identity = sha256Identity(try previous.secondaryIndexFingerprintValidated(allocator));
    }

    var output = std.Io.Writer.Allocating.init(allocator);
    defer output.deinit();
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    try appendHashedLine(allocator, &output.writer, &hasher, Header{
        .mode = mode,
        .repository_id = input.repository_id,
        .parent_generation = input.parent_generation,
        .target_generation = input.target_generation,
        .parent_graph_fingerprint = if (mode == .delta) &parent_graph_identity else "",
        .parent_index_fingerprint = if (mode == .delta) &parent_index_identity else "",
        .target_graph_fingerprint = &target_graph_identity,
        .target_index_fingerprint = &target_index_identity,
    });

    var summary = Summary{
        .target_nodes = input.target.nodeCount(),
        .target_edges = input.target.edgeCount(),
        .target_vectors = input.target.vectorCount(),
        .target_hyperedges = input.target.hyperedgeCount(),
        .target_supernodes = input.target.supernodeCount(),
    };
    var sequence: usize = 0;
    if (input.previous) |previous| {
        const super_order = try orderedSupernodeIndices(allocator, previous);
        defer allocator.free(super_order);
        for (super_order) |index| {
            const item = previous.supernodes.items[index];
            const target = findSupernode(input.target, item.id);
            if (target != null and equalSupernode(item, target.?)) continue;
            const source_path = changedEvidencePath(item.evidence, input.source_changes);
            const cause = causeForPath(input.source_changes, source_path);
            try appendHashedLine(allocator, &output.writer, &hasher, SupernodeTombstone{
                .sequence = sequence,
                .cause = cause,
                .id = item.id,
                .source_path = source_path,
            });
            sequence += 1;
            summary.supernode_tombstones += 1;
            incrementCause(&summary.causes, cause);
        }

        const hyper_order = try orderedHyperedgeIndices(allocator, previous);
        defer allocator.free(hyper_order);
        for (hyper_order) |index| {
            const item = previous.hyperedges.items[index];
            const target = input.target.findHyperedge(item.id);
            if (target != null and equalHyperedge(item, target.?.*)) continue;
            const source_path = changedEvidencePath(item.evidence, input.source_changes);
            const cause = causeForPath(input.source_changes, source_path);
            try appendHashedLine(allocator, &output.writer, &hasher, HyperedgeTombstone{
                .sequence = sequence,
                .cause = cause,
                .id = item.id,
                .source_path = source_path,
            });
            sequence += 1;
            summary.hyperedge_tombstones += 1;
            incrementCause(&summary.causes, cause);
        }

        const edge_order = try orderedEdgeIndices(allocator, previous);
        defer allocator.free(edge_order);
        for (edge_order) |index| {
            const item = previous.edges.items[index];
            const target = findEdge(input.target, item.from, item.to, item.relation);
            if (target != null and equalEdge(item, target.?.*)) continue;
            const cause = causeForPath(input.source_changes, item.source_path);
            try appendHashedLine(allocator, &output.writer, &hasher, EdgeTombstone{
                .sequence = sequence,
                .cause = cause,
                .from = item.from,
                .to = item.to,
                .relation = item.relation,
                .provenance = item.provenance,
                .source_path = item.source_path,
                .line = item.line,
            });
            sequence += 1;
            summary.edge_tombstones += 1;
            incrementCause(&summary.causes, cause);
        }

        const node_order = try orderedNodeIndices(allocator, previous);
        defer allocator.free(node_order);
        for (node_order) |index| {
            const item = previous.nodes.items[index];
            const target = input.target.findNode(item.id);
            if (target != null and equalNode(previous, index, item, input.target, target.?)) continue;
            const cause = causeForPath(input.source_changes, item.path);
            try appendHashedLine(allocator, &output.writer, &hasher, NodeTombstone{
                .sequence = sequence,
                .cause = cause,
                .id = item.id,
                .source_path = item.path,
            });
            sequence += 1;
            summary.node_tombstones += 1;
            incrementCause(&summary.causes, cause);
        }
    }

    const target_node_order = try orderedNodeIndices(allocator, input.target);
    defer allocator.free(target_node_order);
    for (target_node_order) |index| {
        const item = input.target.nodes.items[index];
        if (input.previous) |previous| if (previous.findNode(item.id)) |prior| {
            if (equalNode(input.target, index, item, previous, prior)) continue;
        };
        try appendHashedLine(allocator, &output.writer, &hasher, NodeUpsert{
            .sequence = sequence,
            .id = item.id,
            .node_kind = item.kind,
            .label = item.label,
            .path = item.path,
            .line = item.line,
            .search_text = item.search_text,
            .embedding = input.target.vectorAt(index),
        });
        sequence += 1;
        summary.node_upserts += 1;
    }

    const target_edge_order = try orderedEdgeIndices(allocator, input.target);
    defer allocator.free(target_edge_order);
    for (target_edge_order) |index| {
        const item = input.target.edges.items[index];
        if (input.previous) |previous| if (findEdge(previous, item.from, item.to, item.relation)) |prior| {
            if (equalEdge(item, prior.*)) continue;
        };
        try appendHashedLine(allocator, &output.writer, &hasher, EdgeUpsert{
            .sequence = sequence,
            .from = item.from,
            .to = item.to,
            .relation = item.relation,
            .provenance = item.provenance,
            .source_path = item.source_path,
            .line = item.line,
        });
        sequence += 1;
        summary.edge_upserts += 1;
    }

    const target_hyper_order = try orderedHyperedgeIndices(allocator, input.target);
    defer allocator.free(target_hyper_order);
    for (target_hyper_order) |index| {
        const item = input.target.hyperedges.items[index];
        if (input.previous) |previous| if (previous.findHyperedge(item.id)) |prior| {
            if (equalHyperedge(item, prior.*)) continue;
        };
        try appendHashedLine(allocator, &output.writer, &hasher, HyperedgeUpsert{
            .sequence = sequence,
            .id = item.id,
            .hyperedge_kind = item.kind,
            .canonical_name = item.canonical_name,
            .recipe = item.recipe,
            .interaction_fingerprint = item.interaction_fingerprint,
            .participants = item.participants,
            .evidence = item.evidence,
        });
        sequence += 1;
        summary.hyperedge_upserts += 1;
    }

    const target_super_order = try orderedSupernodeIndices(allocator, input.target);
    defer allocator.free(target_super_order);
    for (target_super_order) |index| {
        const item = input.target.supernodes.items[index];
        if (input.previous) |previous| if (findSupernode(previous, item.id)) |prior| {
            if (equalSupernode(item, prior)) continue;
        };
        try appendHashedLine(allocator, &output.writer, &hasher, SupernodeUpsert{
            .sequence = sequence,
            .id = item.id,
            .supernode_kind = item.kind,
            .canonical_name = item.canonical_name,
            .name = item.name,
            .recipe = item.recipe,
            .synopsis = item.synopsis,
            .input_hyperedge_id = item.input_hyperedge_id,
            .completeness = item.completeness,
            .members = item.members,
            .evidence = item.evidence,
            .proof_steps = item.proof_steps,
        });
        sequence += 1;
        summary.supernode_upserts += 1;
    }

    summary.tombstones = summary.node_tombstones + summary.edge_tombstones + summary.hyperedge_tombstones + summary.supernode_tombstones;
    summary.upserts = summary.node_upserts + summary.edge_upserts + summary.hyperedge_upserts + summary.supernode_upserts;
    summary.operations = summary.tombstones + summary.upserts;
    if (summary.operations != sequence or summary.operations > max_operations) return error.DeltaOperationLimitExceeded;
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    const identity = sha256Identity(digest);
    try appendLine(allocator, &output.writer, Footer{ .summary = summary, .journal_fingerprint = &identity });
    const bytes = try output.toOwnedSlice();
    defer allocator.free(bytes);
    if (bytes.len > max_journal_bytes) return error.DeltaJournalTooLarge;
    try writeAtomic(allocator, io, dir, path, bytes);
    return .{ .summary = summary, .journal_fingerprint = identity };
}

pub fn writeIdentity(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    path: []const u8,
    input: IdentityInput,
) !WriteResult {
    try validateRelativePath(path);
    if (input.repository_id.len == 0 or !validGenerationId(input.parent_generation) or
        !validGenerationId(input.target_generation) or !validSha256Identity(input.graph_fingerprint) or
        !validSha256Identity(input.index_fingerprint) or input.target_vectors != input.target_nodes)
    {
        return error.InvalidIdentityDelta;
    }
    const summary = Summary{
        .target_nodes = input.target_nodes,
        .target_edges = input.target_edges,
        .target_vectors = input.target_vectors,
        .target_hyperedges = input.target_hyperedges,
        .target_supernodes = input.target_supernodes,
    };
    var output = std.Io.Writer.Allocating.init(allocator);
    defer output.deinit();
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    try appendHashedLine(allocator, &output.writer, &hasher, Header{
        .mode = .delta,
        .repository_id = input.repository_id,
        .parent_generation = input.parent_generation,
        .target_generation = input.target_generation,
        .parent_graph_fingerprint = input.graph_fingerprint,
        .parent_index_fingerprint = input.index_fingerprint,
        .target_graph_fingerprint = input.graph_fingerprint,
        .target_index_fingerprint = input.index_fingerprint,
    });
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    const identity = sha256Identity(digest);
    try appendLine(allocator, &output.writer, Footer{ .summary = summary, .journal_fingerprint = &identity });
    const bytes = try output.toOwnedSlice();
    defer allocator.free(bytes);
    if (bytes.len > max_journal_bytes) return error.DeltaJournalTooLarge;
    try writeAtomic(allocator, io, dir, path, bytes);
    return .{ .summary = summary, .journal_fingerprint = identity };
}

pub fn inspect(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    path: []const u8,
) !Inspection {
    try validateRelativePath(path);
    const bytes = try dir.readFileAlloc(io, path, allocator, .limited(max_journal_bytes));
    defer allocator.free(bytes);
    return inspectBytes(allocator, bytes);
}

pub fn replay(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    path: []const u8,
    previous: ?*const model.RepositoryGraph,
    options: model.Options,
) !model.RepositoryGraph {
    var info = try inspect(allocator, io, dir, path);
    defer info.deinit();
    if ((info.mode == .checkpoint and previous != null) or (info.mode == .delta and previous == null)) return error.DeltaParentModeMismatch;
    if (previous) |parent| {
        const parent_graph_identity = sha256Identity(try freshness.fingerprint(allocator, parent));
        const parent_index_identity = sha256Identity(try parent.secondaryIndexFingerprint(allocator));
        if (!std.mem.eql(u8, &parent_graph_identity, info.parent_graph_fingerprint)) return error.ParentGraphFingerprintMismatch;
        if (!std.mem.eql(u8, &parent_index_identity, info.parent_index_fingerprint)) return error.ParentIndexFingerprintMismatch;
    }

    const bytes = try dir.readFileAlloc(io, path, allocator, .limited(max_journal_bytes));
    defer allocator.free(bytes);
    var removed_nodes = std.AutoHashMap(u64, void).init(allocator);
    defer removed_nodes.deinit();
    var removed_edges = std.AutoHashMap(EdgeKey, void).init(allocator);
    defer removed_edges.deinit();
    var removed_hyperedges = std.AutoHashMap(u64, void).init(allocator);
    defer removed_hyperedges.deinit();
    var removed_supernodes = std.AutoHashMap(u64, void).init(allocator);
    defer removed_supernodes.deinit();
    try collectTombstones(allocator, bytes, &removed_nodes, &removed_edges, &removed_hyperedges, &removed_supernodes);

    var merged = try model.RepositoryGraph.init(allocator, options);
    defer merged.deinit();
    if (previous) |parent| try copySurvivingNodes(&merged, parent, &removed_nodes);
    try applyNodeUpserts(allocator, bytes, &merged);
    if (previous) |parent| try copySurvivingEdges(&merged, parent, &removed_edges);
    try applyEdgeUpserts(allocator, bytes, &merged);
    if (previous) |parent| try copySurvivingHyperedges(&merged, parent, &removed_hyperedges);
    try applyHyperedgeUpserts(allocator, bytes, &merged);
    if (previous) |parent| try copySurvivingSupernodes(&merged, parent, &removed_supernodes);
    try applySupernodeUpserts(allocator, bytes, &merged);
    try merged.validateSemanticRecords();
    try semantic_recipes.validateGraph(&merged);
    try merged.validateSecondaryIndexes();

    var canonical = try canonicalClone(allocator, &merged, options);
    errdefer canonical.deinit();
    if (canonical.nodeCount() != info.summary.target_nodes or canonical.edgeCount() != info.summary.target_edges or
        canonical.vectorCount() != info.summary.target_vectors or canonical.hyperedgeCount() != info.summary.target_hyperedges or
        canonical.supernodeCount() != info.summary.target_supernodes) return error.DeltaTargetCountMismatch;
    const target_graph_identity = sha256Identity(try freshness.fingerprint(allocator, &canonical));
    const target_index_identity = sha256Identity(try canonical.secondaryIndexFingerprintValidated(allocator));
    if (!std.mem.eql(u8, &target_graph_identity, info.target_graph_fingerprint)) return error.DeltaTargetGraphFingerprintMismatch;
    if (!std.mem.eql(u8, &target_index_identity, info.target_index_fingerprint)) return error.DeltaTargetIndexFingerprintMismatch;
    return canonical;
}

fn inspectBytes(allocator: std.mem.Allocator, bytes: []const u8) !Inspection {
    if (bytes.len == 0 or bytes.len > max_journal_bytes or bytes[bytes.len - 1] != '\n') return error.IncompleteDeltaJournal;
    var cursor: usize = 0;
    var line_number: usize = 0;
    var expected_sequence: usize = 0;
    var current_phase: ?Phase = null;
    var last_node_tombstone: ?u64 = null;
    var last_edge_tombstone: ?EdgeKey = null;
    var last_hyperedge_tombstone: ?u64 = null;
    var last_supernode_tombstone: ?u64 = null;
    var last_node_upsert: ?u64 = null;
    var last_edge_upsert: ?EdgeKey = null;
    var last_hyperedge_upsert: ?u64 = null;
    var last_supernode_upsert: ?u64 = null;
    var saw_header = false;
    var saw_footer = false;
    var first_line: []const u8 = "";
    var summary = Summary{};
    var footer_fingerprint: [71]u8 = @splat(0);
    var has_footer_fingerprint = false;
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});

    while (cursor < bytes.len) {
        const newline_relative = std.mem.indexOfScalar(u8, bytes[cursor..], '\n') orelse return error.IncompleteDeltaJournal;
        const end = cursor + newline_relative;
        const line = bytes[cursor..end];
        cursor = end + 1;
        if (line.len == 0) return error.CorruptDeltaJournal;
        line_number += 1;
        var probe = std.json.parseFromSlice(Probe, allocator, line, .{ .ignore_unknown_fields = true }) catch return error.CorruptDeltaJournal;
        defer probe.deinit();
        const record = probe.value.record;

        if (std.mem.eql(u8, record, "header")) {
            if (line_number != 1 or saw_header or saw_footer) return error.CorruptDeltaJournal;
            var parsed = std.json.parseFromSlice(Header, allocator, line, .{}) catch return error.CorruptDeltaJournal;
            defer parsed.deinit();
            try validateHeader(parsed.value);
            saw_header = true;
            first_line = line;
            hasher.update(line);
            hasher.update("\n");
            continue;
        }
        if (!saw_header or saw_footer) return error.CorruptDeltaJournal;
        if (std.mem.eql(u8, record, "footer")) {
            var parsed = std.json.parseFromSlice(Footer, allocator, line, .{}) catch return error.CorruptDeltaJournal;
            defer parsed.deinit();
            if (!parsed.value.complete or parsed.value.journal_fingerprint.len == 0) return error.IncompleteDeltaJournal;
            summary.tombstones = summary.node_tombstones + summary.edge_tombstones + summary.hyperedge_tombstones + summary.supernode_tombstones;
            summary.upserts = summary.node_upserts + summary.edge_upserts + summary.hyperedge_upserts + summary.supernode_upserts;
            summary.operations = summary.tombstones + summary.upserts;
            summary.target_nodes = parsed.value.summary.target_nodes;
            summary.target_edges = parsed.value.summary.target_edges;
            summary.target_vectors = parsed.value.summary.target_vectors;
            summary.target_hyperedges = parsed.value.summary.target_hyperedges;
            summary.target_supernodes = parsed.value.summary.target_supernodes;
            if (!std.meta.eql(summary, parsed.value.summary) or summary.operations != expected_sequence or summary.operations > max_operations) {
                return error.DeltaSummaryMismatch;
            }
            var digest: [32]u8 = @splat(0);
            hasher.final(&digest);
            const identity = sha256Identity(digest);
            if (!std.mem.eql(u8, &identity, parsed.value.journal_fingerprint)) return error.DeltaJournalFingerprintMismatch;
            if (parsed.value.journal_fingerprint.len != footer_fingerprint.len) return error.InvalidDeltaJournalFingerprint;
            @memcpy(&footer_fingerprint, parsed.value.journal_fingerprint);
            has_footer_fingerprint = true;
            saw_footer = true;
            if (cursor != bytes.len) return error.CorruptDeltaJournal;
            break;
        }

        hasher.update(line);
        hasher.update("\n");
        if (std.mem.eql(u8, record, "supernode_tombstone")) {
            var parsed = std.json.parseFromSlice(SupernodeTombstone, allocator, line, .{}) catch return error.CorruptDeltaJournal;
            defer parsed.deinit();
            try validateOperation(parsed.value.sequence, expected_sequence, .supernode_tombstone, &current_phase);
            if (parsed.value.kind != .supernode or parsed.value.id == 0 or !strictIdOrder(last_supernode_tombstone, parsed.value.id)) return error.InvalidDeltaOperationOrder;
            try validateSourcePath(parsed.value.source_path);
            last_supernode_tombstone = parsed.value.id;
            summary.supernode_tombstones += 1;
            incrementCause(&summary.causes, parsed.value.cause);
        } else if (std.mem.eql(u8, record, "hyperedge_tombstone")) {
            var parsed = std.json.parseFromSlice(HyperedgeTombstone, allocator, line, .{}) catch return error.CorruptDeltaJournal;
            defer parsed.deinit();
            try validateOperation(parsed.value.sequence, expected_sequence, .hyperedge_tombstone, &current_phase);
            if (parsed.value.kind != .hyperedge or parsed.value.id == 0 or !strictIdOrder(last_hyperedge_tombstone, parsed.value.id)) return error.InvalidDeltaOperationOrder;
            try validateSourcePath(parsed.value.source_path);
            last_hyperedge_tombstone = parsed.value.id;
            summary.hyperedge_tombstones += 1;
            incrementCause(&summary.causes, parsed.value.cause);
        } else if (std.mem.eql(u8, record, "edge_tombstone")) {
            var parsed = std.json.parseFromSlice(EdgeTombstone, allocator, line, .{}) catch return error.CorruptDeltaJournal;
            defer parsed.deinit();
            try validateOperation(parsed.value.sequence, expected_sequence, .edge_tombstone, &current_phase);
            const key = EdgeKey{ .from = parsed.value.from, .to = parsed.value.to, .relation = parsed.value.relation };
            if (parsed.value.kind != .edge or parsed.value.from == 0 or parsed.value.to == 0 or !strictEdgeOrder(last_edge_tombstone, key)) return error.InvalidDeltaOperationOrder;
            try validateSourcePath(parsed.value.source_path);
            last_edge_tombstone = key;
            summary.edge_tombstones += 1;
            incrementCause(&summary.causes, parsed.value.cause);
        } else if (std.mem.eql(u8, record, "node_tombstone")) {
            var parsed = std.json.parseFromSlice(NodeTombstone, allocator, line, .{}) catch return error.CorruptDeltaJournal;
            defer parsed.deinit();
            try validateOperation(parsed.value.sequence, expected_sequence, .node_tombstone, &current_phase);
            if (parsed.value.kind != .node or parsed.value.id == 0 or !strictIdOrder(last_node_tombstone, parsed.value.id)) return error.InvalidDeltaOperationOrder;
            try validateSourcePath(parsed.value.source_path);
            last_node_tombstone = parsed.value.id;
            summary.node_tombstones += 1;
            incrementCause(&summary.causes, parsed.value.cause);
        } else if (std.mem.eql(u8, record, "node_upsert")) {
            var parsed = std.json.parseFromSlice(NodeUpsert, allocator, line, .{}) catch return error.CorruptDeltaJournal;
            defer parsed.deinit();
            try validateOperation(parsed.value.sequence, expected_sequence, .node_upsert, &current_phase);
            if (parsed.value.id == 0 or parsed.value.label.len == 0 or parsed.value.embedding.len != nendb.embedding_dimensions or !strictIdOrder(last_node_upsert, parsed.value.id)) return error.InvalidDeltaOperation;
            try validateGraphPath(parsed.value.path);
            last_node_upsert = parsed.value.id;
            summary.node_upserts += 1;
        } else if (std.mem.eql(u8, record, "edge_upsert")) {
            var parsed = std.json.parseFromSlice(EdgeUpsert, allocator, line, .{}) catch return error.CorruptDeltaJournal;
            defer parsed.deinit();
            try validateOperation(parsed.value.sequence, expected_sequence, .edge_upsert, &current_phase);
            const key = EdgeKey{ .from = parsed.value.from, .to = parsed.value.to, .relation = parsed.value.relation };
            if (parsed.value.from == 0 or parsed.value.to == 0 or !strictEdgeOrder(last_edge_upsert, key)) return error.InvalidDeltaOperationOrder;
            try validateSourcePath(parsed.value.source_path);
            last_edge_upsert = key;
            summary.edge_upserts += 1;
        } else if (std.mem.eql(u8, record, "hyperedge_upsert")) {
            var parsed = std.json.parseFromSlice(HyperedgeUpsert, allocator, line, .{}) catch return error.CorruptDeltaJournal;
            defer parsed.deinit();
            try validateOperation(parsed.value.sequence, expected_sequence, .hyperedge_upsert, &current_phase);
            if (parsed.value.id == 0 or parsed.value.canonical_name.len == 0 or parsed.value.recipe.len == 0 or !strictIdOrder(last_hyperedge_upsert, parsed.value.id)) return error.InvalidDeltaOperation;
            last_hyperedge_upsert = parsed.value.id;
            summary.hyperedge_upserts += 1;
        } else if (std.mem.eql(u8, record, "supernode_upsert")) {
            var parsed = std.json.parseFromSlice(SupernodeUpsert, allocator, line, .{}) catch return error.CorruptDeltaJournal;
            defer parsed.deinit();
            try validateOperation(parsed.value.sequence, expected_sequence, .supernode_upsert, &current_phase);
            if (parsed.value.id == 0 or parsed.value.canonical_name.len == 0 or parsed.value.recipe.len == 0 or !strictIdOrder(last_supernode_upsert, parsed.value.id)) return error.InvalidDeltaOperation;
            last_supernode_upsert = parsed.value.id;
            summary.supernode_upserts += 1;
        } else return error.UnknownDeltaRecord;
        expected_sequence += 1;
    }
    if (!saw_header or !saw_footer or !has_footer_fingerprint) return error.IncompleteDeltaJournal;

    var header = std.json.parseFromSlice(Header, allocator, first_line, .{}) catch return error.CorruptDeltaJournal;
    defer header.deinit();
    return inspectionAlloc(allocator, header.value, &footer_fingerprint, summary);
}

fn inspectionAlloc(allocator: std.mem.Allocator, header: Header, footer_fingerprint: []const u8, summary: Summary) !Inspection {
    const repository_id = try memory.copy(u8, allocator, header.repository_id);
    errdefer allocator.free(repository_id);
    const parent_generation = if (header.parent_generation.len == 0) "" else try memory.copy(u8, allocator, header.parent_generation);
    errdefer if (parent_generation.len > 0) allocator.free(parent_generation);
    const target_generation = try memory.copy(u8, allocator, header.target_generation);
    errdefer allocator.free(target_generation);
    const parent_graph = if (header.parent_graph_fingerprint.len == 0) "" else try memory.copy(u8, allocator, header.parent_graph_fingerprint);
    errdefer if (parent_graph.len > 0) allocator.free(parent_graph);
    const parent_index = if (header.parent_index_fingerprint.len == 0) "" else try memory.copy(u8, allocator, header.parent_index_fingerprint);
    errdefer if (parent_index.len > 0) allocator.free(parent_index);
    const target_graph = try memory.copy(u8, allocator, header.target_graph_fingerprint);
    errdefer allocator.free(target_graph);
    const target_index = try memory.copy(u8, allocator, header.target_index_fingerprint);
    errdefer allocator.free(target_index);
    const journal_fingerprint = try memory.copy(u8, allocator, footer_fingerprint);
    errdefer allocator.free(journal_fingerprint);
    return .{
        .allocator = allocator,
        .mode = header.mode,
        .repository_id = repository_id,
        .parent_generation = parent_generation,
        .target_generation = target_generation,
        .parent_graph_fingerprint = parent_graph,
        .parent_index_fingerprint = parent_index,
        .target_graph_fingerprint = target_graph,
        .target_index_fingerprint = target_index,
        .journal_fingerprint = journal_fingerprint,
        .summary = summary,
    };
}

fn validateHeader(value: Header) !void {
    if (!std.mem.eql(u8, value.record, "header") or !std.mem.eql(u8, value.schema, schema) or value.schema_version != schema_version or
        !std.mem.eql(u8, value.canonical_order, canonical_order_recipe) or value.complete or value.repository_id.len == 0 or
        !validGenerationId(value.target_generation) or !validSha256Identity(value.target_graph_fingerprint) or
        !validSha256Identity(value.target_index_fingerprint)) return error.IncompatibleDeltaJournal;
    switch (value.mode) {
        .checkpoint => if (value.parent_generation.len != 0 or value.parent_graph_fingerprint.len != 0 or value.parent_index_fingerprint.len != 0) return error.InvalidDeltaParent,
        .delta => if (!validGenerationId(value.parent_generation) or !validSha256Identity(value.parent_graph_fingerprint) or !validSha256Identity(value.parent_index_fingerprint)) return error.InvalidDeltaParent,
    }
}

fn validateOperation(sequence: usize, expected: usize, phase: Phase, current: *?Phase) !void {
    if (sequence != expected) return error.InvalidDeltaSequence;
    if (current.*) |prior| if (@intFromEnum(phase) < @intFromEnum(prior)) return error.InvalidDeltaOperationOrder;
    current.* = phase;
}

fn collectTombstones(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    nodes: *std.AutoHashMap(u64, void),
    edges: *std.AutoHashMap(EdgeKey, void),
    hyperedges: *std.AutoHashMap(u64, void),
    supernodes: *std.AutoHashMap(u64, void),
) !void {
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var probe = std.json.parseFromSlice(Probe, allocator, line, .{ .ignore_unknown_fields = true }) catch return error.CorruptDeltaJournal;
        defer probe.deinit();
        if (std.mem.eql(u8, probe.value.record, "node_tombstone")) {
            var parsed = std.json.parseFromSlice(NodeTombstone, allocator, line, .{}) catch return error.CorruptDeltaJournal;
            defer parsed.deinit();
            try nodes.put(parsed.value.id, {});
        } else if (std.mem.eql(u8, probe.value.record, "edge_tombstone")) {
            var parsed = std.json.parseFromSlice(EdgeTombstone, allocator, line, .{}) catch return error.CorruptDeltaJournal;
            defer parsed.deinit();
            try edges.put(.{ .from = parsed.value.from, .to = parsed.value.to, .relation = parsed.value.relation }, {});
        } else if (std.mem.eql(u8, probe.value.record, "hyperedge_tombstone")) {
            var parsed = std.json.parseFromSlice(HyperedgeTombstone, allocator, line, .{}) catch return error.CorruptDeltaJournal;
            defer parsed.deinit();
            try hyperedges.put(parsed.value.id, {});
        } else if (std.mem.eql(u8, probe.value.record, "supernode_tombstone")) {
            var parsed = std.json.parseFromSlice(SupernodeTombstone, allocator, line, .{}) catch return error.CorruptDeltaJournal;
            defer parsed.deinit();
            try supernodes.put(parsed.value.id, {});
        }
    }
}

fn applyNodeUpserts(allocator: std.mem.Allocator, bytes: []const u8, graph: *model.RepositoryGraph) !void {
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var probe = std.json.parseFromSlice(Probe, allocator, line, .{ .ignore_unknown_fields = true }) catch return error.CorruptDeltaJournal;
        defer probe.deinit();
        if (!std.mem.eql(u8, probe.value.record, "node_upsert")) continue;
        var parsed = std.json.parseFromSlice(NodeUpsert, allocator, line, .{}) catch return error.CorruptDeltaJournal;
        defer parsed.deinit();
        const id = try graph.addNode(.{ .id = parsed.value.id, .kind = parsed.value.node_kind, .label = parsed.value.label, .path = parsed.value.path, .line = parsed.value.line, .search_text = parsed.value.search_text });
        try setEmbedding(graph, id, parsed.value.embedding);
    }
}

fn applyEdgeUpserts(allocator: std.mem.Allocator, bytes: []const u8, graph: *model.RepositoryGraph) !void {
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var probe = std.json.parseFromSlice(Probe, allocator, line, .{ .ignore_unknown_fields = true }) catch return error.CorruptDeltaJournal;
        defer probe.deinit();
        if (!std.mem.eql(u8, probe.value.record, "edge_upsert")) continue;
        var parsed = std.json.parseFromSlice(EdgeUpsert, allocator, line, .{}) catch return error.CorruptDeltaJournal;
        defer parsed.deinit();
        try graph.addEdge(.{ .from = parsed.value.from, .to = parsed.value.to, .relation = parsed.value.relation, .provenance = parsed.value.provenance, .source_path = parsed.value.source_path, .line = parsed.value.line });
    }
}

fn applyHyperedgeUpserts(allocator: std.mem.Allocator, bytes: []const u8, graph: *model.RepositoryGraph) !void {
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var probe = std.json.parseFromSlice(Probe, allocator, line, .{ .ignore_unknown_fields = true }) catch return error.CorruptDeltaJournal;
        defer probe.deinit();
        if (!std.mem.eql(u8, probe.value.record, "hyperedge_upsert")) continue;
        var parsed = std.json.parseFromSlice(HyperedgeUpsert, allocator, line, .{}) catch return error.CorruptDeltaJournal;
        defer parsed.deinit();
        _ = try graph.addHyperedge(.{ .id = parsed.value.id, .kind = parsed.value.hyperedge_kind, .canonical_name = parsed.value.canonical_name, .recipe = parsed.value.recipe, .interaction_fingerprint = parsed.value.interaction_fingerprint, .participants = parsed.value.participants, .evidence = parsed.value.evidence });
    }
}

fn applySupernodeUpserts(allocator: std.mem.Allocator, bytes: []const u8, graph: *model.RepositoryGraph) !void {
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var probe = std.json.parseFromSlice(Probe, allocator, line, .{ .ignore_unknown_fields = true }) catch return error.CorruptDeltaJournal;
        defer probe.deinit();
        if (!std.mem.eql(u8, probe.value.record, "supernode_upsert")) continue;
        var parsed = std.json.parseFromSlice(SupernodeUpsert, allocator, line, .{}) catch return error.CorruptDeltaJournal;
        defer parsed.deinit();
        _ = try graph.addSupernode(.{ .id = parsed.value.id, .kind = parsed.value.supernode_kind, .canonical_name = parsed.value.canonical_name, .name = parsed.value.name, .recipe = parsed.value.recipe, .synopsis = parsed.value.synopsis, .input_hyperedge_id = parsed.value.input_hyperedge_id, .completeness = parsed.value.completeness, .members = parsed.value.members, .evidence = parsed.value.evidence, .proof_steps = parsed.value.proof_steps });
    }
}

fn copySurvivingNodes(target: *model.RepositoryGraph, source: *const model.RepositoryGraph, removed: *const std.AutoHashMap(u64, void)) !void {
    for (source.nodes.items, 0..) |node, index| {
        if (removed.contains(node.id)) continue;
        const id = try target.addNode(.{ .id = node.id, .kind = node.kind, .label = node.label, .path = node.path, .line = node.line, .search_text = node.search_text });
        try setEmbedding(target, id, source.vectorAt(index));
    }
}

fn copySurvivingEdges(target: *model.RepositoryGraph, source: *const model.RepositoryGraph, removed: *const std.AutoHashMap(EdgeKey, void)) !void {
    for (source.edges.items) |edge| if (!removed.contains(.{ .from = edge.from, .to = edge.to, .relation = edge.relation })) try target.addEdge(edge);
}

fn copySurvivingHyperedges(target: *model.RepositoryGraph, source: *const model.RepositoryGraph, removed: *const std.AutoHashMap(u64, void)) !void {
    for (source.hyperedges.items) |item| {
        if (removed.contains(item.id)) continue;
        _ = try target.addHyperedge(.{ .id = item.id, .kind = item.kind, .canonical_name = item.canonical_name, .recipe = item.recipe, .interaction_fingerprint = item.interaction_fingerprint, .participants = item.participants, .evidence = item.evidence });
    }
}

fn copySurvivingSupernodes(target: *model.RepositoryGraph, source: *const model.RepositoryGraph, removed: *const std.AutoHashMap(u64, void)) !void {
    for (source.supernodes.items) |item| {
        if (removed.contains(item.id)) continue;
        _ = try target.addSupernode(.{ .id = item.id, .kind = item.kind, .canonical_name = item.canonical_name, .name = item.name, .recipe = item.recipe, .synopsis = item.synopsis, .input_hyperedge_id = item.input_hyperedge_id, .completeness = item.completeness, .members = item.members, .evidence = item.evidence, .proof_steps = item.proof_steps });
    }
}

fn setEmbedding(graph: *model.RepositoryGraph, id: u64, embedding: []const f32) !void {
    if (embedding.len != nendb.embedding_dimensions) return error.InvalidDeltaEmbedding;
    const index = graph.topology.findNodeIndex(id) orelse return error.DeltaNodeNotFound;
    const start = @as(usize, index) * nendb.embedding_dimensions;
    @memcpy(graph.topology.vectors[start .. start + nendb.embedding_dimensions], embedding);
}

fn orderedNodeIndices(allocator: std.mem.Allocator, graph: *const model.RepositoryGraph) ![]usize {
    const order = try memory.slice(usize, allocator, graph.nodes.items.len);
    for (order, 0..) |*value, index| value.* = index;
    std.mem.sort(usize, order, graph, struct {
        fn lessThan(context: *const model.RepositoryGraph, left: usize, right: usize) bool {
            return context.nodes.items[left].id < context.nodes.items[right].id;
        }
    }.lessThan);
    return order;
}

fn orderedEdgeIndices(allocator: std.mem.Allocator, graph: *const model.RepositoryGraph) ![]usize {
    const order = try memory.slice(usize, allocator, graph.edges.items.len);
    for (order, 0..) |*value, index| value.* = index;
    std.mem.sort(usize, order, graph, struct {
        fn lessThan(context: *const model.RepositoryGraph, left: usize, right: usize) bool {
            return edgeLessThan(context.edges.items[left], context.edges.items[right]);
        }
    }.lessThan);
    return order;
}

fn orderedHyperedgeIndices(allocator: std.mem.Allocator, graph: *const model.RepositoryGraph) ![]usize {
    const order = try memory.slice(usize, allocator, graph.hyperedges.items.len);
    for (order, 0..) |*value, index| value.* = index;
    std.mem.sort(usize, order, graph, struct {
        fn lessThan(context: *const model.RepositoryGraph, left: usize, right: usize) bool {
            return context.hyperedges.items[left].id < context.hyperedges.items[right].id;
        }
    }.lessThan);
    return order;
}

fn orderedSupernodeIndices(allocator: std.mem.Allocator, graph: *const model.RepositoryGraph) ![]usize {
    const order = try memory.slice(usize, allocator, graph.supernodes.items.len);
    for (order, 0..) |*value, index| value.* = index;
    std.mem.sort(usize, order, graph, struct {
        fn lessThan(context: *const model.RepositoryGraph, left: usize, right: usize) bool {
            return context.supernodes.items[left].id < context.supernodes.items[right].id;
        }
    }.lessThan);
    return order;
}

fn edgeLessThan(left: model.Edge, right: model.Edge) bool {
    if (left.from != right.from) return left.from < right.from;
    if (left.to != right.to) return left.to < right.to;
    if (left.relation != right.relation) return @intFromEnum(left.relation) < @intFromEnum(right.relation);
    if (left.provenance != right.provenance) return @intFromEnum(left.provenance) < @intFromEnum(right.provenance);
    const path_order = std.mem.order(u8, left.source_path, right.source_path);
    if (path_order != .eq) return path_order == .lt;
    return left.line < right.line;
}

fn findEdge(graph: *const model.RepositoryGraph, from: u64, to: u64, relation: model.Relation) ?*const model.Edge {
    for (graph.outgoingRelationEdges(from, relation)) |index| {
        const edge = graph.edgeAt(index) orelse continue;
        if (edge.to == to) return edge;
    }
    return null;
}

fn findSupernode(graph: *const model.RepositoryGraph, id: u64) ?model.Supernode {
    for (graph.supernodes.items) |item| if (item.id == id) return item;
    return null;
}

fn equalNode(left_graph: *const model.RepositoryGraph, left_index: usize, left: model.Node, right_graph: *const model.RepositoryGraph, right: *const model.Node) bool {
    if (left.id != right.id or left.kind != right.kind or left.line != right.line or !std.mem.eql(u8, left.label, right.label) or
        !std.mem.eql(u8, left.path, right.path) or !std.mem.eql(u8, left.search_text, right.search_text)) return false;
    const right_index = right_graph.topology.findNodeIndex(right.id) orelse return false;
    return equalF32(left_graph.vectorAt(left_index), right_graph.vectorAt(right_index));
}

fn equalEdge(left: model.Edge, right: model.Edge) bool {
    return left.from == right.from and left.to == right.to and left.relation == right.relation and left.provenance == right.provenance and
        left.line == right.line and std.mem.eql(u8, left.source_path, right.source_path);
}

fn equalHyperedge(left: model.Hyperedge, right: model.Hyperedge) bool {
    if (left.id != right.id or left.kind != right.kind or !std.mem.eql(u8, left.canonical_name, right.canonical_name) or
        !std.mem.eql(u8, left.recipe, right.recipe) or !std.mem.eql(u8, &left.interaction_fingerprint, &right.interaction_fingerprint) or
        left.participants.len != right.participants.len or left.evidence.len != right.evidence.len) return false;
    for (left.participants, right.participants) |a, b| if (!std.meta.eql(a, b)) return false;
    for (left.evidence, right.evidence) |a, b| if (!equalEvidence(a, b)) return false;
    return true;
}

fn equalSupernode(left: model.Supernode, right: model.Supernode) bool {
    if (left.id != right.id or left.kind != right.kind or left.input_hyperedge_id != right.input_hyperedge_id or left.completeness != right.completeness or
        !std.mem.eql(u8, left.canonical_name, right.canonical_name) or !std.mem.eql(u8, left.name, right.name) or
        !std.mem.eql(u8, left.recipe, right.recipe) or !std.mem.eql(u8, left.synopsis, right.synopsis) or
        left.members.len != right.members.len or left.evidence.len != right.evidence.len or left.proof_steps.len != right.proof_steps.len) return false;
    for (left.members, right.members) |a, b| if (a.role != b.role or a.node_id != b.node_id or !std.mem.eql(u8, a.reason, b.reason)) return false;
    for (left.evidence, right.evidence) |a, b| if (!equalEvidence(a, b)) return false;
    for (left.proof_steps, right.proof_steps) |a, b| if (!std.meta.eql(a, b)) return false;
    return true;
}

fn equalEvidence(left: model.SourceEvidence, right: model.SourceEvidence) bool {
    return left.role == right.role and std.mem.eql(u8, left.source_path, right.source_path) and std.meta.eql(left.span, right.span);
}

fn equalF32(left: []const f32, right: []const f32) bool {
    if (left.len != right.len) return false;
    for (left, right) |a, b| if (@as(u32, @bitCast(a)) != @as(u32, @bitCast(b))) return false;
    return true;
}

fn causeForPath(changes: []const SourceChange, path: []const u8) TombstoneCause {
    if (path.len > 0) for (changes) |change| {
        if (std.mem.eql(u8, change.path, path)) return change.cause;
    };
    return .reconciled_absent;
}

fn firstEvidencePath(evidence: []const model.SourceEvidence) []const u8 {
    for (evidence) |item| if (item.source_path.len > 0) return item.source_path;
    return "";
}

fn changedEvidencePath(evidence: []const model.SourceEvidence, changes: []const SourceChange) []const u8 {
    for (evidence) |item| for (changes) |change| {
        if (std.mem.eql(u8, item.source_path, change.path)) return item.source_path;
    };
    return firstEvidencePath(evidence);
}

fn incrementCause(counts: *CauseCounts, cause: TombstoneCause) void {
    switch (cause) {
        .replaced => counts.replaced += 1,
        .renamed => counts.renamed += 1,
        .moved => counts.moved += 1,
        .deleted => counts.deleted += 1,
        .excluded => counts.excluded += 1,
        .dependency_invalidated => counts.dependency_invalidated += 1,
        .reconciled_absent => counts.reconciled_absent += 1,
    }
}

fn strictIdOrder(previous: ?u64, current: u64) bool {
    return previous == null or previous.? < current;
}

fn strictEdgeOrder(previous: ?EdgeKey, current: EdgeKey) bool {
    if (previous == null) return true;
    const prior = previous.?;
    if (prior.from != current.from) return prior.from < current.from;
    if (prior.to != current.to) return prior.to < current.to;
    return @intFromEnum(prior.relation) < @intFromEnum(current.relation);
}

fn appendHashedLine(allocator: std.mem.Allocator, writer: *std.Io.Writer, hasher: *std.crypto.hash.sha2.Sha256, value: anytype) !void {
    const encoded = try std.json.Stringify.valueAlloc(allocator, value, .{});
    defer allocator.free(encoded);
    try writer.writeAll(encoded);
    try writer.writeByte('\n');
    hasher.update(encoded);
    hasher.update("\n");
}

fn appendLine(allocator: std.mem.Allocator, writer: *std.Io.Writer, value: anytype) !void {
    const encoded = try std.json.Stringify.valueAlloc(allocator, value, .{});
    defer allocator.free(encoded);
    try writer.writeAll(encoded);
    try writer.writeByte('\n');
}

fn writeAtomic(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8, bytes: []const u8) !void {
    if (std.mem.lastIndexOfScalar(u8, path, '/')) |slash| try dir.createDirPath(io, path[0..slash]);
    for (0..1024) |slot| {
        const temporary = try std.fmt.allocPrint(allocator, "{s}.tmp.{d}", .{ path, slot });
        defer allocator.free(temporary);
        const file = dir.createFile(io, temporary, .{ .exclusive = true }) catch |failure| switch (failure) {
            error.PathAlreadyExists => continue,
            else => return failure,
        };
        var open = true;
        defer if (open) file.close(io);
        errdefer dir.deleteFile(io, temporary) catch {};
        try file.writeStreamingAll(io, bytes);
        file.close(io);
        open = false;
        dir.rename(temporary, dir, path, io) catch |failure| {
            dir.deleteFile(io, temporary) catch {};
            return failure;
        };
        return;
    }
    return error.AtomicTemporaryPathExhausted;
}

fn validateRelativePath(path: []const u8) !void {
    if (path.len == 0 or path[0] == '/' or std.mem.indexOfScalar(u8, path, '\\') != null) return error.InvalidDeltaPath;
    var components = std.mem.splitScalar(u8, path, '/');
    while (components.next()) |component| if (std.mem.eql(u8, component, "..")) return error.InvalidDeltaPath;
}

fn validateSourcePath(path: []const u8) !void {
    try validateGraphPath(path);
}

fn validateGraphPath(path: []const u8) !void {
    if (path.len == 0) return;
    if (path[0] == '/' or std.mem.indexOfScalar(u8, path, '\\') != null) return error.InvalidDeltaPath;
}

fn sha256Identity(digest: [32]u8) [71]u8 {
    var output: [71]u8 = @splat(0);
    output[0..7].* = "sha256:".*;
    output[7..].* = std.fmt.bytesToHex(digest, .lower);
    return output;
}

fn validSha256Identity(value: []const u8) bool {
    if (value.len != 71 or !std.mem.eql(u8, value[0..7], "sha256:")) return false;
    for (value[7..]) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}

fn validGenerationId(value: []const u8) bool {
    if (value.len != 66 or !std.mem.eql(u8, value[0..2], "g-")) return false;
    for (value[2..]) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}
