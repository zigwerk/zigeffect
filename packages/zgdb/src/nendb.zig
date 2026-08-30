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
pub const secondary_index_schema = "zgraphy.nendb.secondary-index.v1";
const initial_node_capacity: usize = 256;
const initial_edge_capacity: usize = 1024;

pub const Options = struct {
    max_nodes: usize = 100_000,
    max_edges: usize = 500_000,
    max_lexical_postings: usize = 4_000_000,

    pub fn validate(self: Options) !void {
        if (self.max_nodes == 0 or self.max_edges == 0 or self.max_lexical_postings == 0) return error.InvalidCapacity;
        if (self.max_nodes > std.math.maxInt(u32) or self.max_edges > std.math.maxInt(u32) or self.max_lexical_postings > std.math.maxInt(u32)) {
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

pub const LexicalField = enum(u8) {
    label,
    path,
    search_text,
};

pub const LexicalDocument = struct {
    label: []const u8,
    path: []const u8,
    search_text: []const u8,
};

pub const LexicalPosting = struct {
    node_index: u32,
    field: LexicalField,
    frequency: u16,
};

pub const SecondaryIndexStats = struct {
    indexed_documents: usize,
    adjacency_keys: usize,
    adjacency_postings: usize,
    lexical_terms: usize,
    lexical_postings: usize,
};

pub const SecondaryIndexValidationWork = struct {
    node_records: usize = 0,
    edge_records: usize = 0,
    relation_postings: usize = 0,
    incident_postings: usize = 0,
    lexical_records: usize = 0,
    lexical_postings: usize = 0,
};

const RelationKey = u128;
const EdgePostings = std.ArrayList(u32);
const LexicalPostings = std.ArrayList(LexicalPosting);
pub const PendingLexical = struct {
    term: u64,
    posting: LexicalPosting,
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
    outgoing_relation: std.AutoHashMap(RelationKey, EdgePostings),
    incoming_relation: std.AutoHashMap(RelationKey, EdgePostings),
    outgoing_incident: std.AutoHashMap(u64, EdgePostings),
    incoming_incident: std.AutoHashMap(u64, EdgePostings),
    lexical_index: std.AutoHashMap(u64, LexicalPostings),
    lexical_records: std.ArrayList(PendingLexical) = .empty,
    node_lexical_start: []u32,
    node_lexical_count: []u32,

    pub fn init(allocator: std.mem.Allocator, options: Options) !GraphData {
        try options.validate();
        const node_capacity = @min(options.max_nodes, initial_node_capacity);
        const edge_capacity = @min(options.max_edges, initial_edge_capacity);
        const node_ids = try owned.slice(u64, allocator, node_capacity);
        errdefer allocator.free(node_ids);
        const node_kinds = try owned.slice(u8, allocator, node_capacity);
        errdefer allocator.free(node_kinds);
        const node_active = try owned.slice(bool, allocator, node_capacity);
        errdefer allocator.free(node_active);
        const edge_from = try owned.slice(u64, allocator, edge_capacity);
        errdefer allocator.free(edge_from);
        const edge_to = try owned.slice(u64, allocator, edge_capacity);
        errdefer allocator.free(edge_to);
        const edge_labels = try owned.slice(u16, allocator, edge_capacity);
        errdefer allocator.free(edge_labels);
        const edge_active = try owned.slice(bool, allocator, edge_capacity);
        errdefer allocator.free(edge_active);
        const vector_values = std.math.mul(usize, node_capacity, embedding_dimensions) catch return error.InvalidCapacity;
        const vectors = try owned.slice(f32, allocator, vector_values);
        errdefer allocator.free(vectors);
        const node_lexical_start = try owned.slice(u32, allocator, node_capacity);
        errdefer allocator.free(node_lexical_start);
        const node_lexical_count = try owned.slice(u32, allocator, node_capacity);
        errdefer allocator.free(node_lexical_count);
        @memset(node_active, false);
        @memset(edge_active, false);
        @memset(vectors, 0);
        @memset(node_lexical_start, 0);
        @memset(node_lexical_count, 0);
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
            .outgoing_relation = std.AutoHashMap(RelationKey, EdgePostings).init(allocator),
            .incoming_relation = std.AutoHashMap(RelationKey, EdgePostings).init(allocator),
            .outgoing_incident = std.AutoHashMap(u64, EdgePostings).init(allocator),
            .incoming_incident = std.AutoHashMap(u64, EdgePostings).init(allocator),
            .lexical_index = std.AutoHashMap(u64, LexicalPostings).init(allocator),
            .node_lexical_start = node_lexical_start,
            .node_lexical_count = node_lexical_count,
        };
    }

    pub fn deinit(self: *GraphData) void {
        deinitPostingMap(u64, LexicalPosting, self.allocator, &self.lexical_index);
        self.lexical_records.deinit(self.allocator);
        deinitPostingMap(u64, u32, self.allocator, &self.incoming_incident);
        deinitPostingMap(u64, u32, self.allocator, &self.outgoing_incident);
        deinitPostingMap(RelationKey, u32, self.allocator, &self.incoming_relation);
        deinitPostingMap(RelationKey, u32, self.allocator, &self.outgoing_relation);
        self.id_index.deinit();
        self.allocator.free(self.node_lexical_count);
        self.allocator.free(self.node_lexical_start);
        self.allocator.free(self.vectors);
        self.allocator.free(self.edge_active);
        self.allocator.free(self.edge_labels);
        self.allocator.free(self.edge_to);
        self.allocator.free(self.edge_from);
        self.allocator.free(self.node_active);
        self.allocator.free(self.node_kinds);
        self.allocator.free(self.node_ids);
    }

    pub fn addNode(
        self: *GraphData,
        id: u64,
        kind: u8,
        vector: *const [embedding_dimensions]f32,
        document: LexicalDocument,
    ) !u32 {
        if (id == 0) return error.InvalidNodeId;
        if (self.id_index.contains(id)) return error.DuplicateNode;
        if (self.node_count >= self.options.max_nodes) return error.NodeCapacityExceeded;
        const index: u32 = @intCast(self.node_count);

        var pending: std.ArrayList(PendingLexical) = .empty;
        defer pending.deinit(self.allocator);
        try appendDocumentTerms(self.allocator, &pending, index, .label, document.label);
        try appendDocumentTerms(self.allocator, &pending, index, .path, document.path);
        try appendDocumentTerms(self.allocator, &pending, index, .search_text, document.search_text);
        const posting_total = std.math.add(usize, self.lexical_records.items.len, pending.items.len) catch return error.LexicalPostingCapacityExceeded;
        if (posting_total > self.options.max_lexical_postings) return error.LexicalPostingCapacityExceeded;
        try self.lexical_records.ensureUnusedCapacity(self.allocator, pending.items.len);
        try self.ensureNodeCapacity(self.node_count + 1);

        try self.id_index.put(id, index);
        errdefer _ = self.id_index.remove(id);
        var applied: usize = 0;
        errdefer while (applied > 0) {
            applied -= 1;
            rollbackPosting(u64, LexicalPosting, self.allocator, &self.lexical_index, pending.items[applied].term);
        };
        for (pending.items) |item| {
            try appendPosting(u64, LexicalPosting, self.allocator, &self.lexical_index, item.term, item.posting);
            applied += 1;
        }

        self.node_ids[index] = id;
        self.node_kinds[index] = kind;
        self.node_active[index] = true;
        const start = @as(usize, index) * embedding_dimensions;
        @memcpy(self.vectors[start .. start + embedding_dimensions], vector);
        self.node_lexical_start[index] = @intCast(self.lexical_records.items.len);
        self.node_lexical_count[index] = @intCast(pending.items.len);
        for (pending.items) |item| self.lexical_records.appendAssumeCapacity(item);
        self.node_count += 1;
        self.vector_count += 1;
        return index;
    }

    pub fn addEdge(self: *GraphData, from: u64, to: u64, label: u16) !u32 {
        if (self.findNodeIndex(from) == null or self.findNodeIndex(to) == null) return error.NodeNotFound;
        if (self.edge_count >= self.options.max_edges) return error.EdgeCapacityExceeded;
        try self.ensureEdgeCapacity(self.edge_count + 1);
        const index: u32 = @intCast(self.edge_count);
        const outgoing_key = relationKey(from, label);
        const incoming_key = relationKey(to, label);
        try appendPosting(RelationKey, u32, self.allocator, &self.outgoing_relation, outgoing_key, index);
        errdefer rollbackPosting(RelationKey, u32, self.allocator, &self.outgoing_relation, outgoing_key);
        try appendPosting(RelationKey, u32, self.allocator, &self.incoming_relation, incoming_key, index);
        errdefer rollbackPosting(RelationKey, u32, self.allocator, &self.incoming_relation, incoming_key);
        try appendPosting(u64, u32, self.allocator, &self.outgoing_incident, from, index);
        errdefer rollbackPosting(u64, u32, self.allocator, &self.outgoing_incident, from);
        try appendPosting(u64, u32, self.allocator, &self.incoming_incident, to, index);
        errdefer rollbackPosting(u64, u32, self.allocator, &self.incoming_incident, to);
        self.edge_from[index] = from;
        self.edge_to[index] = to;
        self.edge_labels[index] = label;
        self.edge_active[index] = true;
        self.edge_count += 1;
        return index;
    }

    fn ensureNodeCapacity(self: *GraphData, required: usize) !void {
        if (required <= self.node_ids.len) return;
        const capacity = try nextCapacity(self.node_ids.len, required, self.options.max_nodes, error.NodeCapacityExceeded);
        const vector_values = std.math.mul(usize, capacity, embedding_dimensions) catch return error.NodeCapacityExceeded;
        const active_vector_values = std.math.mul(usize, self.node_count, embedding_dimensions) catch return error.NodeCapacityExceeded;

        const node_ids = try owned.slice(u64, self.allocator, capacity);
        errdefer self.allocator.free(node_ids);
        const node_kinds = try owned.slice(u8, self.allocator, capacity);
        errdefer self.allocator.free(node_kinds);
        const node_active = try owned.slice(bool, self.allocator, capacity);
        errdefer self.allocator.free(node_active);
        const vectors = try owned.slice(f32, self.allocator, vector_values);
        errdefer self.allocator.free(vectors);
        const node_lexical_start = try owned.slice(u32, self.allocator, capacity);
        errdefer self.allocator.free(node_lexical_start);
        const node_lexical_count = try owned.slice(u32, self.allocator, capacity);
        errdefer self.allocator.free(node_lexical_count);

        @memcpy(node_ids[0..self.node_count], self.node_ids[0..self.node_count]);
        @memcpy(node_kinds[0..self.node_count], self.node_kinds[0..self.node_count]);
        @memcpy(node_active[0..self.node_count], self.node_active[0..self.node_count]);
        @memset(node_active[self.node_count..], false);
        @memcpy(vectors[0..active_vector_values], self.vectors[0..active_vector_values]);
        @memcpy(node_lexical_start[0..self.node_count], self.node_lexical_start[0..self.node_count]);
        @memset(node_lexical_start[self.node_count..], 0);
        @memcpy(node_lexical_count[0..self.node_count], self.node_lexical_count[0..self.node_count]);
        @memset(node_lexical_count[self.node_count..], 0);

        self.allocator.free(self.node_lexical_count);
        self.allocator.free(self.node_lexical_start);
        self.allocator.free(self.vectors);
        self.allocator.free(self.node_active);
        self.allocator.free(self.node_kinds);
        self.allocator.free(self.node_ids);
        self.node_ids = node_ids;
        self.node_kinds = node_kinds;
        self.node_active = node_active;
        self.vectors = vectors;
        self.node_lexical_start = node_lexical_start;
        self.node_lexical_count = node_lexical_count;
    }

    fn ensureEdgeCapacity(self: *GraphData, required: usize) !void {
        if (required <= self.edge_from.len) return;
        const capacity = try nextCapacity(self.edge_from.len, required, self.options.max_edges, error.EdgeCapacityExceeded);

        const edge_from = try owned.slice(u64, self.allocator, capacity);
        errdefer self.allocator.free(edge_from);
        const edge_to = try owned.slice(u64, self.allocator, capacity);
        errdefer self.allocator.free(edge_to);
        const edge_labels = try owned.slice(u16, self.allocator, capacity);
        errdefer self.allocator.free(edge_labels);
        const edge_active = try owned.slice(bool, self.allocator, capacity);
        errdefer self.allocator.free(edge_active);

        @memcpy(edge_from[0..self.edge_count], self.edge_from[0..self.edge_count]);
        @memcpy(edge_to[0..self.edge_count], self.edge_to[0..self.edge_count]);
        @memcpy(edge_labels[0..self.edge_count], self.edge_labels[0..self.edge_count]);
        @memcpy(edge_active[0..self.edge_count], self.edge_active[0..self.edge_count]);
        @memset(edge_active[self.edge_count..], false);

        self.allocator.free(self.edge_active);
        self.allocator.free(self.edge_labels);
        self.allocator.free(self.edge_to);
        self.allocator.free(self.edge_from);
        self.edge_from = edge_from;
        self.edge_to = edge_to;
        self.edge_labels = edge_labels;
        self.edge_active = edge_active;
    }

    pub fn removeLastNode(self: *GraphData, index: u32) void {
        std.debug.assert(self.node_count > 0 and index == self.node_count - 1);
        const start: usize = self.node_lexical_start[index];
        const count: usize = self.node_lexical_count[index];
        var cursor = count;
        while (cursor > 0) {
            cursor -= 1;
            const item = self.lexical_records.items[start + cursor];
            rollbackPosting(u64, LexicalPosting, self.allocator, &self.lexical_index, item.term);
        }
        self.lexical_records.items.len = start;
        const id = self.node_ids[index];
        _ = self.id_index.remove(id);
        self.node_active[index] = false;
        self.node_count -= 1;
        self.vector_count -= 1;
    }

    pub fn removeLastEdge(self: *GraphData, index: u32) void {
        std.debug.assert(self.edge_count > 0 and index == self.edge_count - 1);
        const from = self.edge_from[index];
        const to = self.edge_to[index];
        const label = self.edge_labels[index];
        rollbackPosting(u64, u32, self.allocator, &self.incoming_incident, to);
        rollbackPosting(u64, u32, self.allocator, &self.outgoing_incident, from);
        rollbackPosting(RelationKey, u32, self.allocator, &self.incoming_relation, relationKey(to, label));
        rollbackPosting(RelationKey, u32, self.allocator, &self.outgoing_relation, relationKey(from, label));
        self.edge_active[index] = false;
        self.edge_count -= 1;
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

    pub fn outgoingRelationEdges(self: *const GraphData, node_id: u64, label: u16) []const u32 {
        const postings = self.outgoing_relation.getPtr(relationKey(node_id, label)) orelse return &.{};
        return postings.items;
    }

    pub fn incomingRelationEdges(self: *const GraphData, node_id: u64, label: u16) []const u32 {
        const postings = self.incoming_relation.getPtr(relationKey(node_id, label)) orelse return &.{};
        return postings.items;
    }

    pub fn outgoingEdges(self: *const GraphData, node_id: u64) []const u32 {
        const postings = self.outgoing_incident.getPtr(node_id) orelse return &.{};
        return postings.items;
    }

    pub fn incomingEdges(self: *const GraphData, node_id: u64) []const u32 {
        const postings = self.incoming_incident.getPtr(node_id) orelse return &.{};
        return postings.items;
    }

    pub fn lexicalPostings(self: *const GraphData, term: u64) []const LexicalPosting {
        const postings = self.lexical_index.getPtr(term) orelse return &.{};
        return postings.items;
    }

    pub fn nodeLexicalRecords(self: *const GraphData, node_index: u32) []const PendingLexical {
        if (node_index >= self.node_count) return &.{};
        const start: usize = self.node_lexical_start[node_index];
        const count: usize = self.node_lexical_count[node_index];
        return self.lexical_records.items[start..][0..count];
    }

    pub fn secondaryIndexStats(self: *const GraphData) SecondaryIndexStats {
        return .{
            .indexed_documents = self.node_count,
            .adjacency_keys = self.outgoing_relation.count() + self.incoming_relation.count(),
            .adjacency_postings = postingCount(RelationKey, u32, &self.outgoing_relation) + postingCount(RelationKey, u32, &self.incoming_relation),
            .lexical_terms = self.lexical_index.count(),
            .lexical_postings = self.lexical_records.items.len,
        };
    }

    pub fn validateSecondaryIndexes(self: *const GraphData) !void {
        _ = try self.validateSecondaryIndexesWithWork();
    }

    pub fn validateSecondaryIndexesWithWork(self: *const GraphData) !SecondaryIndexValidationWork {
        const stats_value = self.secondaryIndexStats();
        if (stats_value.indexed_documents != self.node_count or self.vector_count != self.node_count or self.id_index.count() != self.node_count or
            stats_value.adjacency_postings != self.edge_count * 2)
        {
            return error.SecondaryIndexCardinalityMismatch;
        }
        if (postingCount(u64, u32, &self.outgoing_incident) != self.edge_count or postingCount(u64, u32, &self.incoming_incident) != self.edge_count) {
            return error.SecondaryIndexCardinalityMismatch;
        }
        var work = SecondaryIndexValidationWork{};
        var lexical_cursor: usize = 0;
        for (0..self.node_count) |node_index| {
            const indexed_node = self.id_index.get(self.node_ids[node_index]) orelse return error.SecondaryIndexCanonicalMismatch;
            if (!self.node_active[node_index] or self.node_ids[node_index] == 0 or indexed_node != node_index) {
                return error.SecondaryIndexCanonicalMismatch;
            }
            const start: usize = self.node_lexical_start[node_index];
            const count: usize = self.node_lexical_count[node_index];
            const end = std.math.add(usize, start, count) catch return error.SecondaryIndexCanonicalMismatch;
            if (start != lexical_cursor or end > self.lexical_records.items.len) return error.SecondaryIndexCanonicalMismatch;
            for (self.lexical_records.items[start..end]) |item| if (item.posting.node_index != node_index) return error.SecondaryIndexCanonicalMismatch;
            lexical_cursor = end;
            work.node_records += 1;
        }
        if (lexical_cursor != self.lexical_records.items.len) return error.SecondaryIndexCanonicalMismatch;

        const EdgeCounts = struct { outgoing_relation: u8 = 0, incoming_relation: u8 = 0, outgoing_incident: u8 = 0, incoming_incident: u8 = 0 };
        const edge_counts = try owned.slice(EdgeCounts, self.allocator, self.edge_count);
        defer self.allocator.free(edge_counts);
        for (edge_counts) |*counts| counts.* = .{};

        var outgoing_relation = self.outgoing_relation.iterator();
        while (outgoing_relation.next()) |entry| {
            if (entry.value_ptr.items.len == 0) return error.SecondaryIndexCanonicalMismatch;
            const from: u64 = @intCast(entry.key_ptr.* >> 16);
            const label: u16 = @truncate(entry.key_ptr.*);
            for (entry.value_ptr.items) |edge_index| {
                if (edge_index >= self.edge_count or self.edge_from[edge_index] != from or self.edge_labels[edge_index] != label or
                    edge_counts[edge_index].outgoing_relation != 0) return error.SecondaryIndexCanonicalMismatch;
                edge_counts[edge_index].outgoing_relation = 1;
                work.relation_postings += 1;
            }
        }
        var incoming_relation = self.incoming_relation.iterator();
        while (incoming_relation.next()) |entry| {
            if (entry.value_ptr.items.len == 0) return error.SecondaryIndexCanonicalMismatch;
            const to: u64 = @intCast(entry.key_ptr.* >> 16);
            const label: u16 = @truncate(entry.key_ptr.*);
            for (entry.value_ptr.items) |edge_index| {
                if (edge_index >= self.edge_count or self.edge_to[edge_index] != to or self.edge_labels[edge_index] != label or
                    edge_counts[edge_index].incoming_relation != 0) return error.SecondaryIndexCanonicalMismatch;
                edge_counts[edge_index].incoming_relation = 1;
                work.relation_postings += 1;
            }
        }
        var outgoing_incident = self.outgoing_incident.iterator();
        while (outgoing_incident.next()) |entry| {
            if (entry.value_ptr.items.len == 0) return error.SecondaryIndexCanonicalMismatch;
            for (entry.value_ptr.items) |edge_index| {
                if (edge_index >= self.edge_count or self.edge_from[edge_index] != entry.key_ptr.* or
                    edge_counts[edge_index].outgoing_incident != 0) return error.SecondaryIndexCanonicalMismatch;
                edge_counts[edge_index].outgoing_incident = 1;
                work.incident_postings += 1;
            }
        }
        var incoming_incident = self.incoming_incident.iterator();
        while (incoming_incident.next()) |entry| {
            if (entry.value_ptr.items.len == 0) return error.SecondaryIndexCanonicalMismatch;
            for (entry.value_ptr.items) |edge_index| {
                if (edge_index >= self.edge_count or self.edge_to[edge_index] != entry.key_ptr.* or
                    edge_counts[edge_index].incoming_incident != 0) return error.SecondaryIndexCanonicalMismatch;
                edge_counts[edge_index].incoming_incident = 1;
                work.incident_postings += 1;
            }
        }
        for (edge_counts, 0..) |counts, edge_index| {
            if (!self.edge_active[edge_index] or counts.outgoing_relation != 1 or counts.incoming_relation != 1 or
                counts.outgoing_incident != 1 or counts.incoming_incident != 1) return error.SecondaryIndexCanonicalMismatch;
            work.edge_records += 1;
        }

        if (stats_value.lexical_postings != postingCount(u64, LexicalPosting, &self.lexical_index)) return error.SecondaryIndexCardinalityMismatch;
        var lexical_expected = std.AutoHashMap(u128, u8).init(self.allocator);
        defer lexical_expected.deinit();
        try lexical_expected.ensureTotalCapacity(@intCast(self.lexical_records.items.len));
        for (self.lexical_records.items) |item| {
            if (item.posting.node_index >= self.node_count or !self.node_active[item.posting.node_index] or item.posting.frequency == 0) {
                return error.SecondaryIndexCanonicalMismatch;
            }
            const indexed = try lexical_expected.getOrPut(lexicalKey(item.term, item.posting));
            if (indexed.found_existing) return error.SecondaryIndexCanonicalMismatch;
            indexed.value_ptr.* = 0;
            work.lexical_records += 1;
        }
        var lexical_index = self.lexical_index.iterator();
        while (lexical_index.next()) |entry| {
            if (entry.value_ptr.items.len == 0) return error.SecondaryIndexCanonicalMismatch;
            for (entry.value_ptr.items) |posting| {
                const matched = lexical_expected.getPtr(lexicalKey(entry.key_ptr.*, posting)) orelse return error.SecondaryIndexCanonicalMismatch;
                if (matched.* != 0) return error.SecondaryIndexCanonicalMismatch;
                matched.* = 1;
                work.lexical_postings += 1;
            }
        }
        if (work.lexical_postings != self.lexical_records.items.len) return error.SecondaryIndexCanonicalMismatch;
        var expected_iterator = lexical_expected.valueIterator();
        while (expected_iterator.next()) |matched| if (matched.* != 1) return error.SecondaryIndexCanonicalMismatch;
        return work;
    }

    pub fn secondaryIndexFingerprint(self: *const GraphData, allocator: std.mem.Allocator) ![32]u8 {
        try self.validateSecondaryIndexes();
        return self.secondaryIndexFingerprintValidated(allocator);
    }

    pub fn secondaryIndexFingerprintValidated(self: *const GraphData, allocator: std.mem.Allocator) ![32]u8 {
        const FingerprintLexical = struct { term: u64, node_id: u64, field: LexicalField, frequency: u16 };
        var lexical = try owned.slice(FingerprintLexical, allocator, self.lexical_records.items.len);
        defer allocator.free(lexical);
        for (self.lexical_records.items, 0..) |item, index| lexical[index] = .{
            .term = item.term,
            .node_id = self.node_ids[item.posting.node_index],
            .field = item.posting.field,
            .frequency = item.posting.frequency,
        };
        std.mem.sort(FingerprintLexical, lexical, {}, struct {
            fn lessThan(_: void, left: FingerprintLexical, right: FingerprintLexical) bool {
                if (left.term != right.term) return left.term < right.term;
                if (left.node_id != right.node_id) return left.node_id < right.node_id;
                if (left.field != right.field) return @intFromEnum(left.field) < @intFromEnum(right.field);
                return left.frequency < right.frequency;
            }
        }.lessThan);

        const FingerprintEdge = struct { from: u64, to: u64, label: u16 };
        var edges = try owned.slice(FingerprintEdge, allocator, self.edge_count);
        defer allocator.free(edges);
        for (0..self.edge_count) |index| edges[index] = .{ .from = self.edge_from[index], .to = self.edge_to[index], .label = self.edge_labels[index] };
        std.mem.sort(FingerprintEdge, edges, {}, struct {
            fn lessThan(_: void, left: FingerprintEdge, right: FingerprintEdge) bool {
                if (left.from != right.from) return left.from < right.from;
                if (left.to != right.to) return left.to < right.to;
                return left.label < right.label;
            }
        }.lessThan);

        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        updateHashBytes(&hasher, secondary_index_schema);
        const stats_value = self.secondaryIndexStats();
        updateHashInt(&hasher, stats_value.indexed_documents);
        updateHashInt(&hasher, stats_value.adjacency_keys);
        updateHashInt(&hasher, stats_value.adjacency_postings);
        updateHashInt(&hasher, stats_value.lexical_terms);
        updateHashInt(&hasher, stats_value.lexical_postings);
        for (edges) |edge| {
            updateHashInt(&hasher, edge.from);
            updateHashInt(&hasher, edge.to);
            updateHashInt(&hasher, edge.label);
        }
        for (lexical) |item| {
            updateHashInt(&hasher, item.term);
            updateHashInt(&hasher, item.node_id);
            updateHashInt(&hasher, @intFromEnum(item.field));
            updateHashInt(&hasher, item.frequency);
        }
        var digest: [32]u8 = @splat(0);
        hasher.final(&digest);
        return digest;
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

fn nextCapacity(current: usize, required: usize, maximum: usize, comptime limit_error: anyerror) !usize {
    if (required > maximum or current >= maximum) return limit_error;
    const doubled = std.math.mul(usize, current, 2) catch maximum;
    const candidate = @max(required, doubled);
    return @min(candidate, maximum);
}

fn relationKey(node_id: u64, label: u16) RelationKey {
    return (@as(RelationKey, node_id) << 16) | label;
}

fn lexicalKey(term: u64, posting: LexicalPosting) u128 {
    return (@as(u128, term) << 50) |
        (@as(u128, posting.node_index) << 18) |
        (@as(u128, @intFromEnum(posting.field)) << 16) |
        posting.frequency;
}

fn appendDocumentTerms(
    allocator: std.mem.Allocator,
    pending: *std.ArrayList(PendingLexical),
    node_index: u32,
    field: LexicalField,
    text: []const u8,
) !void {
    var frequencies = std.AutoHashMap(u64, u16).init(allocator);
    defer frequencies.deinit();
    var tokenizer = Tokenizer.init(text);
    while (tokenizer.next()) |token| {
        const entry = try frequencies.getOrPut(tokenHash(token));
        if (!entry.found_existing) entry.value_ptr.* = 0;
        if (entry.value_ptr.* < std.math.maxInt(u16)) entry.value_ptr.* += 1;
    }
    var iterator = frequencies.iterator();
    while (iterator.next()) |entry| try pending.append(allocator, .{
        .term = entry.key_ptr.*,
        .posting = .{ .node_index = node_index, .field = field, .frequency = entry.value_ptr.* },
    });
}

fn appendPosting(
    comptime Key: type,
    comptime Value: type,
    allocator: std.mem.Allocator,
    map: *std.AutoHashMap(Key, std.ArrayList(Value)),
    key: Key,
    value: Value,
) !void {
    const entry = try map.getOrPut(key);
    if (!entry.found_existing) entry.value_ptr.* = .empty;
    errdefer if (!entry.found_existing) {
        entry.value_ptr.deinit(allocator);
        _ = map.remove(key);
    };
    try entry.value_ptr.append(allocator, value);
}

fn rollbackPosting(
    comptime Key: type,
    comptime Value: type,
    allocator: std.mem.Allocator,
    map: *std.AutoHashMap(Key, std.ArrayList(Value)),
    key: Key,
) void {
    const postings = map.getPtr(key) orelse return;
    _ = postings.pop();
    if (postings.items.len == 0) {
        postings.deinit(allocator);
        _ = map.remove(key);
    }
}

fn deinitPostingMap(
    comptime Key: type,
    comptime Value: type,
    allocator: std.mem.Allocator,
    map: *std.AutoHashMap(Key, std.ArrayList(Value)),
) void {
    var iterator = map.valueIterator();
    while (iterator.next()) |postings| postings.deinit(allocator);
    map.deinit();
}

fn postingCount(comptime Key: type, comptime Value: type, map: *const std.AutoHashMap(Key, std.ArrayList(Value))) usize {
    var mutable = @constCast(map);
    var iterator = mutable.valueIterator();
    var count: usize = 0;
    while (iterator.next()) |postings| count += postings.items.len;
    return count;
}

fn countScalar(values: []const u32, expected: u32) usize {
    var count: usize = 0;
    for (values) |value| if (value == expected) {
        count += 1;
    };
    return count;
}

fn updateHashBytes(hasher: *std.crypto.hash.sha2.Sha256, value: []const u8) void {
    updateHashInt(hasher, value.len);
    hasher.update(value);
}

fn updateHashInt(hasher: *std.crypto.hash.sha2.Sha256, value: anytype) void {
    var bytes: [8]u8 = @splat(0);
    std.mem.writeInt(u64, &bytes, @intCast(value), .little);
    hasher.update(&bytes);
}

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
