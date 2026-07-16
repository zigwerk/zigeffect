//! Bounded embedded NenDB-derived topology for zgraphy.
//!
//! The struct-of-arrays layout is adapted from Nen-Co/nen-db at commit
//! c990ef87d74e4dd7e77d3d8d1aafea2d57d12af7 under Apache-2.0. See
//! `vendor/nendb/UPSTREAM.md` and `vendor/nendb/LICENSE`.

const std = @import("std");
const owned = @import("memory.zig");

pub const upstream_repository = "https://github.com/Nen-Co/nen-db";
pub const upstream_commit = "c990ef87d74e4dd7e77d3d8d1aafea2d57d12af7";
pub const upstream_version = "0.2.2-beta";
pub const port_toolchain = "zig-0.16";
pub const embedding_dimensions: usize = 64;
pub const embedder = "feature_hash_v1";

pub const Options = struct {
    max_nodes: usize = 100_000,
    max_edges: usize = 500_000,

    pub fn validate(self: Options) !void {
        if (self.max_nodes == 0 or self.max_edges == 0) return error.InvalidCapacity;
        if (self.max_nodes > std.math.maxInt(u32) or self.max_edges > std.math.maxInt(u32)) {
            return error.InvalidCapacity;
        }
    }
};

pub const Stats = struct {
    node_count: usize,
    edge_count: usize,
    vector_count: usize,
    node_capacity: usize,
    edge_capacity: usize,
    dimensions: usize = embedding_dimensions,
    engine: []const u8 = "nendb_embedded_soa",
    upstream: []const u8 = upstream_commit,
    embedder_name: []const u8 = embedder,
};

pub const GraphData = struct {
    allocator: std.mem.Allocator,
    options: Options,
    node_ids: []u64,
    node_kinds: []u8,
    node_active: []bool,
    edge_from: []u64,
    edge_to: []u64,
    edge_labels: []u16,
    edge_active: []bool,
    vectors: []f32,
    node_count: usize = 0,
    edge_count: usize = 0,
    vector_count: usize = 0,
    id_index: std.AutoHashMap(u64, u32),

    pub fn init(allocator: std.mem.Allocator, options: Options) !GraphData {
        try options.validate();
        const node_ids = try owned.slice(u64, allocator, options.max_nodes);
        errdefer allocator.free(node_ids);
        const node_kinds = try owned.slice(u8, allocator, options.max_nodes);
        errdefer allocator.free(node_kinds);
        const node_active = try owned.slice(bool, allocator, options.max_nodes);
        errdefer allocator.free(node_active);
        const edge_from = try owned.slice(u64, allocator, options.max_edges);
        errdefer allocator.free(edge_from);
        const edge_to = try owned.slice(u64, allocator, options.max_edges);
        errdefer allocator.free(edge_to);
        const edge_labels = try owned.slice(u16, allocator, options.max_edges);
        errdefer allocator.free(edge_labels);
        const edge_active = try owned.slice(bool, allocator, options.max_edges);
        errdefer allocator.free(edge_active);
        const vector_values = std.math.mul(usize, options.max_nodes, embedding_dimensions) catch return error.InvalidCapacity;
        const vectors = try owned.slice(f32, allocator, vector_values);
        errdefer allocator.free(vectors);
        @memset(node_active, false);
        @memset(edge_active, false);
        @memset(vectors, 0);
        return .{
            .allocator = allocator,
            .options = options,
            .node_ids = node_ids,
            .node_kinds = node_kinds,
            .node_active = node_active,
            .edge_from = edge_from,
            .edge_to = edge_to,
            .edge_labels = edge_labels,
            .edge_active = edge_active,
            .vectors = vectors,
            .id_index = std.AutoHashMap(u64, u32).init(allocator),
        };
    }

    pub fn deinit(self: *GraphData) void {
        self.id_index.deinit();
        self.allocator.free(self.vectors);
        self.allocator.free(self.edge_active);
        self.allocator.free(self.edge_labels);
        self.allocator.free(self.edge_to);
        self.allocator.free(self.edge_from);
        self.allocator.free(self.node_active);
        self.allocator.free(self.node_kinds);
        self.allocator.free(self.node_ids);
    }

    pub fn addNode(self: *GraphData, id: u64, kind: u8, vector: *const [embedding_dimensions]f32) !u32 {
        if (id == 0) return error.InvalidNodeId;
        if (self.id_index.contains(id)) return error.DuplicateNode;
        if (self.node_count >= self.options.max_nodes) return error.NodeCapacityExceeded;
        const index: u32 = @intCast(self.node_count);
        self.node_ids[index] = id;
        self.node_kinds[index] = kind;
        self.node_active[index] = true;
        const start = @as(usize, index) * embedding_dimensions;
        @memcpy(self.vectors[start .. start + embedding_dimensions], vector);
        try self.id_index.put(id, index);
        self.node_count += 1;
        self.vector_count += 1;
        return index;
    }

    pub fn addEdge(self: *GraphData, from: u64, to: u64, label: u16) !u32 {
        if (self.findNodeIndex(from) == null or self.findNodeIndex(to) == null) return error.NodeNotFound;
        if (self.edge_count >= self.options.max_edges) return error.EdgeCapacityExceeded;
        const index: u32 = @intCast(self.edge_count);
        self.edge_from[index] = from;
        self.edge_to[index] = to;
        self.edge_labels[index] = label;
        self.edge_active[index] = true;
        self.edge_count += 1;
        return index;
    }

    pub fn findNodeIndex(self: *const GraphData, id: u64) ?u32 {
        const index = self.id_index.get(id) orelse return null;
        return if (self.node_active[index]) index else null;
    }

    pub fn vectorAt(self: *const GraphData, node_index: u32) []const f32 {
        const start = @as(usize, node_index) * embedding_dimensions;
        return self.vectors[start .. start + embedding_dimensions];
    }

    pub fn edgeEndpoints(self: *const GraphData, edge_index: usize) ?struct { from: u64, to: u64, label: u16 } {
        if (edge_index >= self.edge_count or !self.edge_active[edge_index]) return null;
        return .{
            .from = self.edge_from[edge_index],
            .to = self.edge_to[edge_index],
            .label = self.edge_labels[edge_index],
        };
    }

    pub fn stats(self: *const GraphData) Stats {
        return .{
            .node_count = self.node_count,
            .edge_count = self.edge_count,
            .vector_count = self.vector_count,
            .node_capacity = self.options.max_nodes,
            .edge_capacity = self.options.max_edges,
        };
    }
};

pub fn embedText(text: []const u8) [embedding_dimensions]f32 {
    var vector = [_]f32{0} ** embedding_dimensions;
    var tokenizer = Tokenizer.init(text);
    var count: usize = 0;
    while (tokenizer.next()) |token| {
        const hash = tokenHash(token);
        const index: usize = @intCast(hash % embedding_dimensions);
        vector[index] += if ((hash & (1 << 63)) == 0) 1.0 else -1.0;
        count += 1;
    }
    if (count == 0) return vector;
    var norm_squared: f32 = 0;
    for (vector) |value| norm_squared += value * value;
    if (norm_squared == 0) return vector;
    const norm = @sqrt(norm_squared);
    for (&vector) |*value| value.* /= norm;
    return vector;
}

pub fn embedPair(first: []const u8, second: []const u8) [embedding_dimensions]f32 {
    if (second.len == 0 or std.mem.eql(u8, first, second)) return embedText(first);
    var vector = embedText(first);
    const other = embedText(second);
    var norm_squared: f32 = 0;
    for (&vector, other) |*value, right| {
        value.* += right;
        norm_squared += value.* * value.*;
    }
    if (norm_squared == 0) return vector;
    const norm = @sqrt(norm_squared);
    for (&vector) |*value| value.* /= norm;
    return vector;
}

pub fn cosine(a: []const f32, b: []const f32) f32 {
    if (a.len != b.len or a.len == 0) return 0;
    var dot: f32 = 0;
    var norm_a: f32 = 0;
    var norm_b: f32 = 0;
    for (a, b) |left, right| {
        dot += left * right;
        norm_a += left * left;
        norm_b += right * right;
    }
    if (norm_a == 0 or norm_b == 0) return 0;
    return dot / (@sqrt(norm_a) * @sqrt(norm_b));
}

pub fn tokenHash(token: []const u8) u64 {
    var hash: u64 = 0xcbf29ce484222325;
    for (token) |character| {
        hash ^= std.ascii.toLower(character);
        hash *%= 0x100000001b3;
    }
    return hash;
}

pub const Tokenizer = struct {
    text: []const u8,
    cursor: usize = 0,

    pub fn init(text: []const u8) Tokenizer {
        return .{ .text = text };
    }

    pub fn next(self: *Tokenizer) ?[]const u8 {
        while (self.cursor < self.text.len and !std.ascii.isAlphanumeric(self.text[self.cursor])) self.cursor += 1;
        if (self.cursor >= self.text.len) return null;
        const start = self.cursor;
        self.cursor += 1;
        while (self.cursor < self.text.len and std.ascii.isAlphanumeric(self.text[self.cursor])) {
            const current = self.text[self.cursor];
            const previous = self.text[self.cursor - 1];
            if (std.ascii.isUpper(current) and std.ascii.isLower(previous)) break;
            self.cursor += 1;
        }
        return self.text[start..self.cursor];
    }
};
