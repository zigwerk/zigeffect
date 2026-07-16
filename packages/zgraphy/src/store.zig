const std = @import("std");
const model = @import("model.zig");
const nendb = @import("nendb.zig");

pub const schema = "zgraphy.nendb.snapshot.v1";
pub const schema_version: u32 = 1;
pub const default_path = ".zgraphy/nendb.jsonl";
pub const max_snapshot_bytes: usize = 512 * 1024 * 1024;

const Header = struct {
    record: []const u8 = "header",
    schema: []const u8 = schema,
    schema_version: u32 = schema_version,
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

const Footer = struct {
    record: []const u8 = "footer",
    complete: bool = true,
    nodes: usize,
    edges: usize,
    vectors: usize,
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
    complete: ?bool = null,
    nodes: ?usize = null,
    edges: ?usize = null,
    vectors: ?usize = null,
};

pub fn save(io: std.Io, dir: std.Io.Dir, path: []const u8, graph: *const model.RepositoryGraph) !void {
    try validatePath(path);
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
    try appendLine(graph.allocator, &output.writer, Footer{
        .nodes = graph.nodeCount(),
        .edges = graph.edgeCount(),
        .vectors = graph.vectorCount(),
    });
    const bytes = try output.toOwnedSlice();
    defer graph.allocator.free(bytes);
    if (bytes.len > max_snapshot_bytes) return error.SnapshotTooLarge;
    const temporary = try std.fmt.allocPrint(graph.allocator, "{s}.tmp", .{path});
    defer graph.allocator.free(temporary);
    try dir.writeFile(io, .{ .sub_path = temporary, .data = bytes });
    dir.rename(temporary, dir, path, io) catch |failure| {
        dir.deleteFile(io, temporary) catch {};
        return failure;
    };
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
    var graph = try model.RepositoryGraph.init(allocator, options);
    errdefer graph.deinit();
    var saw_header = false;
    var saw_footer = false;
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
            if (!std.mem.eql(u8, record.schema.?, schema) or
                record.schema_version != schema_version or
                !std.mem.eql(u8, record.engine.?, "nendb_embedded_soa") or
                !std.mem.eql(u8, record.upstream_commit.?, nendb.upstream_commit) or
                record.dimensions != nendb.embedding_dimensions or
                !std.mem.eql(u8, record.embedder.?, nendb.embedder)) return error.IncompatibleSnapshot;
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
        } else if (std.mem.eql(u8, record.record, "footer")) {
            if (!saw_header or saw_footer or record.complete != true) return error.IncompleteSnapshot;
            if (record.nodes != graph.nodeCount() or record.edges != graph.edgeCount() or record.vectors != graph.vectorCount()) return error.CorruptSnapshot;
            saw_footer = true;
        } else return error.CorruptSnapshot;
    }
    if (!saw_header or !saw_footer) return error.IncompleteSnapshot;
    return graph;
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
