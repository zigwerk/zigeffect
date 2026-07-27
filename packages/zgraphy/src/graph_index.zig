//! A derived binary image of a published graph, so opening one does not mean
//! parsing ten megabytes of JSON.
//!
//! The snapshot is the truth and this is not. It stores only the *facts* a node
//! or edge asserts — identity, kind, the three strings, the line — and never the
//! structures derived from them. Postings, vectors, adjacency and the secondary
//! indexes are all rebuilt by `addNode` and `addEdge` on the way in, exactly as
//! they are when the graph is built from source. So an index cannot disagree
//! with the snapshot about anything derived; the only thing it can be wrong
//! about is the facts, and the caller checks that against the generation's
//! recorded fingerprint before trusting it.
//!
//! That is what makes it safe to be incomplete. A snapshot carrying record kinds
//! this format does not know about simply produces a graph whose fingerprint
//! does not match, and the caller falls back to replaying the JSONL. The index
//! is a cache that can be deleted at any moment, and being deleted is never
//! worse than being slow.
//!
//! Same contract as `zigeffect-std/src/causal_graph/index.zig`, for the same
//! reason: a derived artifact that can be rebuilt from its source must never be
//! able to make an answer wrong, only late.

const std = @import("std");
const model = @import("model.zig");

pub const schema = "zgraphy.graph-index.v1";
pub const magic: u64 = 0x7a67_7261_7068_6931; // "zgraphi1"
pub const version: u32 = 1;

pub const Header = extern struct {
    magic: u64 = magic,
    version: u32 = version,
    node_count: u32,
    edge_count: u32,
    string_bytes: u32,
    /// SHA-256 of the snapshot this was derived from. A mismatch means the
    /// index describes a graph nobody asked for.
    source_digest: [32]u8,

    comptime {
        std.debug.assert(@sizeOf(Header) == 56);
    }
};

pub const NodeRecord = extern struct {
    id: u64,
    kind: u16,
    reserved: u16 = 0,
    line: u32,
    label_offset: u32,
    label_length: u32,
    path_offset: u32,
    path_length: u32,
    text_offset: u32,
    text_length: u32,

    comptime {
        std.debug.assert(@sizeOf(NodeRecord) == 40);
    }
};

pub const EdgeRecord = extern struct {
    from: u64,
    to: u64,
    relation: u16,
    provenance: u16,
    line: u32,
    path_offset: u32,
    path_length: u32,

    comptime {
        std.debug.assert(@sizeOf(EdgeRecord) == 32);
    }
};

pub const Error = error{
    IndexUnusable,
};

/// Intern strings once so a path repeated across every symbol in a file costs
/// its bytes once rather than once per node. On a real corpus most of the blob
/// is `search_text`, which is genuinely distinct per node, so this is a modest
/// win on strings and a large one on paths.
const Interner = struct {
    bytes: std.ArrayList(u8) = .empty,
    offsets: std.StringHashMapUnmanaged(u32) = .empty,
    allocator: std.mem.Allocator,

    fn deinit(self: *Interner) void {
        self.bytes.deinit(self.allocator);
        self.offsets.deinit(self.allocator);
    }

    fn intern(self: *Interner, value: []const u8) !u32 {
        if (value.len == 0) return 0;
        if (self.offsets.get(value)) |offset| return offset;
        const offset: u32 = @intCast(self.bytes.items.len);
        try self.bytes.appendSlice(self.allocator, value);
        // Key by the interned copy: the caller's slice may not outlive us.
        try self.offsets.put(self.allocator, self.bytes.items[offset..][0..value.len], offset);
        return offset;
    }
};

/// Serialize `graph` into a freshly allocated buffer the caller owns.
pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    graph: *const model.RepositoryGraph,
    source_digest: [32]u8,
) ![]u8 {
    var interner = Interner{ .allocator = allocator };
    defer interner.deinit();

    const nodes = try allocator.alloc(NodeRecord, graph.nodes.items.len);
    defer allocator.free(nodes);
    for (graph.nodes.items, nodes) |node, *record| {
        record.* = .{
            .id = node.id,
            .kind = @intFromEnum(node.kind),
            .line = node.line,
            .label_offset = try interner.intern(node.label),
            .label_length = @intCast(node.label.len),
            .path_offset = try interner.intern(node.path),
            .path_length = @intCast(node.path.len),
            .text_offset = try interner.intern(node.search_text),
            .text_length = @intCast(node.search_text.len),
        };
    }

    const edges = try allocator.alloc(EdgeRecord, graph.edges.items.len);
    defer allocator.free(edges);
    for (graph.edges.items, edges) |edge, *record| {
        record.* = .{
            .from = edge.from,
            .to = edge.to,
            .relation = @intFromEnum(edge.relation),
            .provenance = @intFromEnum(edge.provenance),
            .line = edge.line,
            .path_offset = try interner.intern(edge.source_path),
            .path_length = @intCast(edge.source_path.len),
        };
    }

    const header = Header{
        .node_count = @intCast(nodes.len),
        .edge_count = @intCast(edges.len),
        .string_bytes = @intCast(interner.bytes.items.len),
        .source_digest = source_digest,
    };

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, std.mem.asBytes(&header));
    try output.appendSlice(allocator, std.mem.sliceAsBytes(nodes));
    try output.appendSlice(allocator, std.mem.sliceAsBytes(edges));
    try output.appendSlice(allocator, interner.bytes.items);
    return output.toOwnedSlice(allocator);
}

fn stringAt(strings: []const u8, offset: u32, length: u32) Error![]const u8 {
    if (length == 0) return "";
    // Untrusted bytes off disk: check with addition that cannot wrap before
    // indexing. A truncated or hostile index must fail over, not read past the
    // buffer or panic in a safe build.
    const end = @as(u64, offset) + @as(u64, length);
    if (end > strings.len) return Error.IndexUnusable;
    return strings[offset..][0..length];
}

/// Rebuild a graph from `bytes`, or fail so the caller can replay the snapshot.
///
/// Every derived structure is reconstructed by `addNode` and `addEdge`, which is
/// why this can be trusted at all: the index supplies facts and the graph
/// supplies the machinery, exactly as during a build.
pub fn decode(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    expected_digest: [32]u8,
    options: model.Options,
) !model.RepositoryGraph {
    if (bytes.len < @sizeOf(Header)) return Error.IndexUnusable;
    var header: Header = undefined;
    @memcpy(std.mem.asBytes(&header), bytes[0..@sizeOf(Header)]);
    if (header.magic != magic or header.version != version) return Error.IndexUnusable;
    if (!std.mem.eql(u8, &header.source_digest, &expected_digest)) return Error.IndexUnusable;

    const nodes_bytes = @as(u64, header.node_count) * @sizeOf(NodeRecord);
    const edges_bytes = @as(u64, header.edge_count) * @sizeOf(EdgeRecord);
    const total = @as(u64, @sizeOf(Header)) + nodes_bytes + edges_bytes + @as(u64, header.string_bytes);
    if (total != bytes.len) return Error.IndexUnusable;

    const nodes_start = @sizeOf(Header);
    const edges_start = nodes_start + @as(usize, @intCast(nodes_bytes));
    const strings_start = edges_start + @as(usize, @intCast(edges_bytes));
    const node_records = std.mem.bytesAsSlice(NodeRecord, bytes[nodes_start..edges_start]);
    const edge_records = std.mem.bytesAsSlice(EdgeRecord, bytes[edges_start..strings_start]);
    const strings = bytes[strings_start..];

    var graph = try model.RepositoryGraph.init(allocator, options);
    errdefer graph.deinit();

    for (node_records) |record| {
        const kind = std.enums.fromInt(model.NodeKind, record.kind) orelse return Error.IndexUnusable;
        _ = try graph.addNode(.{
            .id = record.id,
            .kind = kind,
            .label = try stringAt(strings, record.label_offset, record.label_length),
            .path = try stringAt(strings, record.path_offset, record.path_length),
            .line = record.line,
            .search_text = try stringAt(strings, record.text_offset, record.text_length),
        });
    }
    for (edge_records) |record| {
        const relation = std.enums.fromInt(model.Relation, record.relation) orelse return Error.IndexUnusable;
        const provenance = std.enums.fromInt(model.Provenance, record.provenance) orelse return Error.IndexUnusable;
        try graph.addEdge(.{
            .from = record.from,
            .to = record.to,
            .relation = relation,
            .provenance = provenance,
            .source_path = try stringAt(strings, record.path_offset, record.path_length),
            .line = record.line,
        });
    }
    return graph;
}
