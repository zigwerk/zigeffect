const std = @import("std");
const freshness = @import("freshness.zig");
const graph_index = @import("graph_index.zig");
const model = @import("model.zig");
const nendb = @import("zgdb").Store;
const semantic_recipes = @import("semantic_recipes.zig");

pub const schema = "zgraphy.nendb.snapshot.v1";
pub const schema_version: u32 = 1;
pub const semantic_schema = "zgraphy.nendb.snapshot.v2";
pub const semantic_schema_version: u32 = 2;
pub const current_schema = "zgraphy.nendb.snapshot.v3";
pub const current_schema_version: u32 = 3;
pub const default_path = ".zgraphy/nendb.jsonl";
pub const max_snapshot_bytes: usize = 512 * 1024 * 1024;

const Header = struct {
    record: []const u8 = "header",
    schema: []const u8 = current_schema,
    schema_version: u32 = current_schema_version,
    engine: []const u8 = "nendb_embedded_soa",
    upstream_commit: []const u8 = nendb.upstream_commit,
    embedder: []const u8 = nendb.embedder,
    dimensions: usize = nendb.embedding_dimensions,
};

const NodeRecord = struct {
    record: []const u8 = "node",
    id: u64,
    kind: model.NodeKind,
    label: []const u8,
    path: []const u8,
    line: u32,
    search_text: []const u8,
    embedding: []const f32,
};

const EdgeRecord = struct {
    record: []const u8 = "edge",
    from: u64,
    to: u64,
    relation: model.Relation,
    provenance: model.Provenance,
    source_path: []const u8,
    line: u32,
};

const HyperedgeRecord = struct {
    record: []const u8 = "hyperedge",
    id: u64,
    hyperedge_kind: model.HyperedgeKind,
    canonical_name: []const u8,
    recipe: []const u8,
    interaction_fingerprint: [32]u8,
    participants: []const model.Participant,
    evidence: []const model.SourceEvidence,
};

const SupernodeRecord = struct {
    record: []const u8 = "supernode",
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

const Footer = struct {
    record: []const u8 = "footer",
    complete: bool = true,
    nodes: usize,
    edges: usize,
    vectors: usize,
    hyperedges: usize,
    supernodes: usize,
    secondary_index_schema: []const u8,
    secondary_index_fingerprint: []const u8,
    indexed_documents: usize,
    adjacency_keys: usize,
    adjacency_postings: usize,
    lexical_terms: usize,
    lexical_postings: usize,
};

const ParsedLine = struct {
    record: []const u8,
    schema: ?[]const u8 = null,
    schema_version: ?u32 = null,
    engine: ?[]const u8 = null,
    upstream_commit: ?[]const u8 = null,
    embedder: ?[]const u8 = null,
    dimensions: ?usize = null,
    id: ?u64 = null,
    kind: ?model.NodeKind = null,
    label: ?[]const u8 = null,
    path: ?[]const u8 = null,
    line: ?u32 = null,
    search_text: ?[]const u8 = null,
    embedding: ?[]const f32 = null,
    from: ?u64 = null,
    to: ?u64 = null,
    relation: ?model.Relation = null,
    provenance: ?model.Provenance = null,
    source_path: ?[]const u8 = null,
    hyperedge_kind: ?model.HyperedgeKind = null,
    supernode_kind: ?model.SupernodeKind = null,
    canonical_name: ?[]const u8 = null,
    name: ?[]const u8 = null,
    recipe: ?[]const u8 = null,
    synopsis: ?[]const u8 = null,
    interaction_fingerprint: ?[32]u8 = null,
    participants: ?[]const model.Participant = null,
    evidence: ?[]const model.SourceEvidence = null,
    input_hyperedge_id: ?u64 = null,
    completeness: ?model.SupernodeCompleteness = null,
    members: ?[]const model.SupernodeMember = null,
    proof_steps: ?[]const model.ProofStep = null,
    complete: ?bool = null,
    nodes: ?usize = null,
    edges: ?usize = null,
    vectors: ?usize = null,
    hyperedges: ?usize = null,
    supernodes: ?usize = null,
    secondary_index_schema: ?[]const u8 = null,
    secondary_index_fingerprint: ?[]const u8 = null,
    indexed_documents: ?usize = null,
    adjacency_keys: ?usize = null,
    adjacency_postings: ?usize = null,
    lexical_terms: ?usize = null,
    lexical_postings: ?usize = null,
};

pub fn save(io: std.Io, dir: std.Io.Dir, path: []const u8, graph: *const model.RepositoryGraph) !void {
    try validatePath(path);
    try graph.validateSemanticRecords();
    try semantic_recipes.validateGraph(graph);
    try graph.validateSecondaryIndexes();
    const index_fingerprint = try graph.secondaryIndexFingerprintValidated(graph.allocator);
    const index_fingerprint_hex = std.fmt.bytesToHex(index_fingerprint, .lower);
    const index_stats = graph.secondaryIndexStats();
    if (std.mem.lastIndexOfScalar(u8, path, '/')) |slash| try dir.createDirPath(io, path[0..slash]);
    var output = std.Io.Writer.Allocating.init(graph.allocator);
    defer output.deinit();
    try appendLine(graph.allocator, &output.writer, Header{});
    for (graph.nodes.items, 0..) |node, index| {
        try appendLine(graph.allocator, &output.writer, NodeRecord{
            .id = node.id,
            .kind = node.kind,
            .label = node.label,
            .path = node.path,
            .line = node.line,
            .search_text = node.search_text,
            .embedding = graph.vectorAt(index),
        });
    }
    for (graph.edges.items) |edge| {
        try appendLine(graph.allocator, &output.writer, EdgeRecord{
            .from = edge.from,
            .to = edge.to,
            .relation = edge.relation,
            .provenance = edge.provenance,
            .source_path = edge.source_path,
            .line = edge.line,
        });
    }
    for (graph.hyperedges.items) |hyperedge| {
        try appendLine(graph.allocator, &output.writer, HyperedgeRecord{
            .id = hyperedge.id,
            .hyperedge_kind = hyperedge.kind,
            .canonical_name = hyperedge.canonical_name,
            .recipe = hyperedge.recipe,
            .interaction_fingerprint = hyperedge.interaction_fingerprint,
            .participants = hyperedge.participants,
            .evidence = hyperedge.evidence,
        });
    }
    for (graph.supernodes.items) |supernode| {
        try appendLine(graph.allocator, &output.writer, SupernodeRecord{
            .id = supernode.id,
            .supernode_kind = supernode.kind,
            .canonical_name = supernode.canonical_name,
            .name = supernode.name,
            .recipe = supernode.recipe,
            .synopsis = supernode.synopsis,
            .input_hyperedge_id = supernode.input_hyperedge_id,
            .completeness = supernode.completeness,
            .members = supernode.members,
            .evidence = supernode.evidence,
            .proof_steps = supernode.proof_steps,
        });
    }
    try appendLine(graph.allocator, &output.writer, Footer{
        .nodes = graph.nodeCount(),
        .edges = graph.edgeCount(),
        .vectors = graph.vectorCount(),
        .hyperedges = graph.hyperedgeCount(),
        .supernodes = graph.supernodeCount(),
        .secondary_index_schema = nendb.secondary_index_schema,
        .secondary_index_fingerprint = &index_fingerprint_hex,
        .indexed_documents = index_stats.indexed_documents,
        .adjacency_keys = index_stats.adjacency_keys,
        .adjacency_postings = index_stats.adjacency_postings,
        .lexical_terms = index_stats.lexical_terms,
        .lexical_postings = index_stats.lexical_postings,
    });
    const bytes = try output.toOwnedSlice();
    defer graph.allocator.free(bytes);
    if (bytes.len > max_snapshot_bytes) return error.SnapshotTooLarge;
    try writeAtomic(graph.allocator, io, dir, path, bytes);
    writeDerivedIndex(io, dir, path, graph, bytes);
}

pub fn indexPathAlloc(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}.idx", .{path});
}

/// Write the derived index beside a snapshot, only after that snapshot is
/// durable. Best effort: the snapshot is the truth, and failing to write a cache
/// must never fail a publish.
fn writeDerivedIndex(
    io: std.Io,
    dir: std.Io.Dir,
    path: []const u8,
    graph: *const model.RepositoryGraph,
    snapshot_bytes: []const u8,
) void {
    const allocator = graph.allocator;
    const index_path = indexPathAlloc(allocator, path) catch return;
    defer allocator.free(index_path);
    const fingerprint = freshness.fingerprint(allocator, graph) catch return;
    const encoded = graph_index.encodeAlloc(allocator, graph, fingerprint, snapshotCrc(snapshot_bytes)) catch {
        dir.deleteFile(io, index_path) catch {};
        return;
    };
    defer allocator.free(encoded);
    dir.writeFile(io, .{ .sub_path = index_path, .data = encoded }) catch {
        dir.deleteFile(io, index_path) catch {};
    };
}

/// Load a snapshot, skipping the *parse* when a derived index can be trusted.
///
/// The snapshot is still read and still checksummed, so a damaged one is still
/// detected and still reaches recovery with its real provenance. Three
/// independent conditions, each covering what the others cannot: the CRC says
/// the snapshot is byte-identical to the one the index was built from; the
/// digest says the index belongs to the generation being asked for; and the
/// rebuilt graph's own fingerprint says the format actually reproduced it, which
/// matters because the encoder is lossy for record kinds it does not model.
pub fn loadPreferringIndex(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    path: []const u8,
    expected_fingerprint: [32]u8,
    options: model.Options,
) !model.RepositoryGraph {
    try validatePath(path);
    const bytes = try dir.readFileAlloc(io, path, allocator, .limited(max_snapshot_bytes));
    defer allocator.free(bytes);
    if (indexPathAlloc(allocator, path)) |index_path| {
        defer allocator.free(index_path);
        if (dir.readFileAlloc(io, index_path, allocator, .limited(max_snapshot_bytes))) |encoded| {
            defer allocator.free(encoded);
            if (graph_index.decode(allocator, encoded, expected_fingerprint, snapshotCrc(bytes), options)) |rebuilt| {
                var candidate = rebuilt;
                if (freshness.fingerprint(allocator, &candidate)) |actual| {
                    if (std.mem.eql(u8, &actual, &expected_fingerprint)) return candidate;
                } else |_| {}
                candidate.deinit();
            } else |_| {}
        } else |_| {}
    } else |_| {}
    return loadFromBytes(allocator, bytes, options);
}

pub fn load(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    path: []const u8,
    options: model.Options,
) !model.RepositoryGraph {
    try validatePath(path);
    const bytes = try dir.readFileAlloc(io, path, allocator, .limited(max_snapshot_bytes));
    defer allocator.free(bytes);
    return loadFromBytes(allocator, bytes, options);
}

pub fn snapshotCrc(bytes: []const u8) u32 {
    return std.hash.crc.Crc32Iscsi.hash(bytes);
}

/// Parse a snapshot already read into memory, so the index path can checksum the
/// same bytes it would otherwise have parsed rather than reading the file twice.
pub fn loadFromBytes(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    options: model.Options,
) !model.RepositoryGraph {
    var graph = try model.RepositoryGraph.init(allocator, options);
    errdefer graph.deinit();
    var saw_header = false;
    var saw_footer = false;
    var semantic_records = false;
    var indexed_snapshot = false;
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var parsed = std.json.parseFromSlice(ParsedLine, allocator, line, .{ .ignore_unknown_fields = true }) catch return error.CorruptSnapshot;
        defer parsed.deinit();
        const record = parsed.value;
        if (std.mem.eql(u8, record.record, "header")) {
            if (saw_header or graph.nodeCount() != 0) return error.CorruptSnapshot;
            if (record.schema == null or record.schema_version == null or record.engine == null or record.upstream_commit == null or record.dimensions == null or record.embedder == null) {
                return error.IncompleteSnapshot;
            }
            const legacy_header = std.mem.eql(u8, record.schema.?, schema) and record.schema_version == schema_version;
            const semantic_header = std.mem.eql(u8, record.schema.?, semantic_schema) and record.schema_version == semantic_schema_version;
            const current_header = std.mem.eql(u8, record.schema.?, current_schema) and record.schema_version == current_schema_version;
            if ((!legacy_header and !semantic_header and !current_header) or !std.mem.eql(u8, record.engine.?, "nendb_embedded_soa") or
                !std.mem.eql(u8, record.upstream_commit.?, nendb.upstream_commit) or
                record.dimensions != nendb.embedding_dimensions or
                !std.mem.eql(u8, record.embedder.?, nendb.embedder)) return error.IncompatibleSnapshot;
            semantic_records = semantic_header or current_header;
            indexed_snapshot = current_header;
            saw_header = true;
        } else if (std.mem.eql(u8, record.record, "node")) {
            if (!saw_header or saw_footer) return error.CorruptSnapshot;
            const id = record.id orelse return error.CorruptSnapshot;
            const node_id = try graph.addNode(.{
                .id = id,
                .kind = record.kind orelse return error.CorruptSnapshot,
                .label = record.label orelse return error.CorruptSnapshot,
                .path = record.path orelse "",
                .line = record.line orelse 0,
                .search_text = record.search_text orelse "",
            });
            const embedding = record.embedding orelse return error.CorruptSnapshot;
            if (embedding.len != nendb.embedding_dimensions) return error.IncompatibleSnapshot;
            const node_index = graph.topology.findNodeIndex(node_id).?;
            const start = @as(usize, node_index) * nendb.embedding_dimensions;
            @memcpy(graph.topology.vectors[start .. start + nendb.embedding_dimensions], embedding);
        } else if (std.mem.eql(u8, record.record, "edge")) {
            if (!saw_header or saw_footer) return error.CorruptSnapshot;
            try graph.addEdge(.{
                .from = record.from orelse return error.CorruptSnapshot,
                .to = record.to orelse return error.CorruptSnapshot,
                .relation = record.relation orelse return error.CorruptSnapshot,
                .provenance = record.provenance orelse return error.CorruptSnapshot,
                .source_path = record.source_path orelse "",
                .line = record.line orelse 0,
            });
        } else if (std.mem.eql(u8, record.record, "hyperedge")) {
            if (!saw_header or saw_footer or !semantic_records) return error.CorruptSnapshot;
            _ = try graph.addHyperedge(.{
                .id = record.id orelse return error.CorruptSnapshot,
                .kind = record.hyperedge_kind orelse return error.CorruptSnapshot,
                .canonical_name = record.canonical_name orelse return error.CorruptSnapshot,
                .recipe = record.recipe orelse return error.CorruptSnapshot,
                .interaction_fingerprint = record.interaction_fingerprint orelse return error.CorruptSnapshot,
                .participants = record.participants orelse return error.CorruptSnapshot,
                .evidence = record.evidence orelse return error.CorruptSnapshot,
            });
        } else if (std.mem.eql(u8, record.record, "supernode")) {
            if (!saw_header or saw_footer or !semantic_records) return error.CorruptSnapshot;
            _ = try graph.addSupernode(.{
                .id = record.id orelse return error.CorruptSnapshot,
                .kind = record.supernode_kind orelse return error.CorruptSnapshot,
                .canonical_name = record.canonical_name orelse return error.CorruptSnapshot,
                .name = record.name orelse return error.CorruptSnapshot,
                .recipe = record.recipe orelse return error.CorruptSnapshot,
                .synopsis = record.synopsis orelse return error.CorruptSnapshot,
                .input_hyperedge_id = record.input_hyperedge_id orelse return error.CorruptSnapshot,
                .completeness = record.completeness orelse return error.CorruptSnapshot,
                .members = record.members orelse return error.CorruptSnapshot,
                .evidence = record.evidence orelse return error.CorruptSnapshot,
                .proof_steps = record.proof_steps orelse return error.CorruptSnapshot,
            });
        } else if (std.mem.eql(u8, record.record, "footer")) {
            if (!saw_header or saw_footer or record.complete != true) return error.IncompleteSnapshot;
            if (record.nodes != graph.nodeCount() or record.edges != graph.edgeCount() or record.vectors != graph.vectorCount()) return error.CorruptSnapshot;
            if (semantic_records) {
                if (record.hyperedges != graph.hyperedgeCount() or record.supernodes != graph.supernodeCount()) return error.CorruptSnapshot;
            } else if (graph.hyperedgeCount() != 0 or graph.supernodeCount() != 0) return error.CorruptSnapshot;
            if (indexed_snapshot) {
                if (record.secondary_index_schema == null or record.secondary_index_fingerprint == null or
                    record.indexed_documents == null or record.adjacency_keys == null or record.adjacency_postings == null or
                    record.lexical_terms == null or record.lexical_postings == null)
                {
                    return error.IncompleteSnapshot;
                }
                if (!std.mem.eql(u8, record.secondary_index_schema.?, nendb.secondary_index_schema)) return error.IncompatibleSnapshot;
                try graph.validateSecondaryIndexes();
                const stats_value = graph.secondaryIndexStats();
                if (record.indexed_documents != stats_value.indexed_documents or record.adjacency_keys != stats_value.adjacency_keys or
                    record.adjacency_postings != stats_value.adjacency_postings or record.lexical_terms != stats_value.lexical_terms or
                    record.lexical_postings != stats_value.lexical_postings)
                {
                    return error.SecondaryIndexMetadataMismatch;
                }
                const fingerprint = try graph.secondaryIndexFingerprintValidated(allocator);
                const fingerprint_hex = std.fmt.bytesToHex(fingerprint, .lower);
                if (!std.mem.eql(u8, record.secondary_index_fingerprint.?, &fingerprint_hex)) return error.SecondaryIndexFingerprintMismatch;
            }
            saw_footer = true;
        } else return error.CorruptSnapshot;
    }
    if (!saw_header or !saw_footer) return error.IncompleteSnapshot;
    try graph.validateSemanticRecords();
    try semantic_recipes.validateGraph(&graph);
    try graph.validateSecondaryIndexes();
    return graph;
}

fn writeAtomic(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8, bytes: []const u8) !void {
    for (0..1024) |slot| if (try writeAtomicSlot(allocator, io, dir, path, bytes, slot)) return;
    return error.AtomicTemporaryPathExhausted;
}

fn writeAtomicSlot(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8, bytes: []const u8, slot: usize) !bool {
    const temporary = try std.fmt.allocPrint(allocator, "{s}.tmp.{d}", .{ path, slot });
    defer allocator.free(temporary);
    const file = dir.createFile(io, temporary, .{ .exclusive = true }) catch |failure| switch (failure) {
        error.PathAlreadyExists => return false,
        else => return failure,
    };
    var open = true;
    defer if (open) file.close(io);
    defer dir.deleteFile(io, temporary) catch {};
    try file.writeStreamingAll(io, bytes);
    // Before the rename, not after. writeStreamingAll returns once the bytes
    // reach the page cache, and rename is atomic with respect to *the directory
    // entry* only — so without this a power loss can leave the entry pointing at
    // a file whose contents never reached disk. The snapshot would then be
    // present, named correctly, and truncated or empty, which is the one failure
    // mode an atomic write exists to prevent.
    try file.sync(io);
    file.close(io);
    open = false;
    dir.rename(temporary, dir, path, io) catch |failure| switch (failure) {
        error.FileNotFound => return false,
        else => return failure,
    };
    return true;
}

fn appendLine(allocator: std.mem.Allocator, writer: *std.Io.Writer, value: anytype) !void {
    const encoded = try std.json.Stringify.valueAlloc(allocator, value, .{});
    defer allocator.free(encoded);
    try writer.writeAll(encoded);
    try writer.writeByte('\n');
}

fn validatePath(path: []const u8) !void {
    if (path.len == 0 or path[0] == '/' or std.mem.indexOf(u8, path, "..") != null or std.mem.indexOfScalar(u8, path, '\\') != null) {
        return error.InvalidSnapshotPath;
    }
}
