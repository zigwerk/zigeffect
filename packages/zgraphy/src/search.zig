const std = @import("std");
const model = @import("model.zig");
const nendb = @import("nendb.zig");
const owned = @import("memory.zig");

pub const Options = struct {
    limit: usize = 10,
    keyword_weight: f32 = 0.45,
    vector_weight: f32 = 0.35,
    graph_weight: f32 = 0.20,
};

pub const Result = struct {
    node_id: u64,
    score: f32,
    keyword_score: f32,
    vector_score: f32,
    graph_score: f32,
};

pub const Results = struct {
    allocator: std.mem.Allocator,
    items: []Result,
    embedder: []const u8 = nendb.embedder,

    pub fn deinit(self: *Results) void {
        self.allocator.free(self.items);
    }
};

pub fn queryAlloc(
    allocator: std.mem.Allocator,
    graph: *const model.RepositoryGraph,
    query: []const u8,
    options: Options,
) !Results {
    if (std.mem.trim(u8, query, " \t\r\n").len == 0) return error.EmptyQuery;
    if (options.limit == 0 or options.limit > 1024) return error.InvalidLimit;
    const weight_sum = options.keyword_weight + options.vector_weight + options.graph_weight;
    if (weight_sum <= 0) return error.InvalidWeights;

    var query_terms: std.ArrayList(u64) = .empty;
    defer query_terms.deinit(allocator);
    var tokenizer = nendb.Tokenizer.init(query);
    while (tokenizer.next()) |token| {
        const term = nendb.tokenHash(token);
        if (std.mem.indexOfScalar(u64, query_terms.items, term) == null) try query_terms.append(allocator, term);
    }
    if (query_terms.items.len == 0) return error.EmptyQuery;
    const query_vector = nendb.embedText(query);

    const count = graph.nodeCount();
    const keyword = try owned.slice(f32, allocator, count);
    defer allocator.free(keyword);
    const vector = try owned.slice(f32, allocator, count);
    defer allocator.free(vector);
    const base = try owned.slice(f32, allocator, count);
    defer allocator.free(base);
    const graph_scores = try owned.slice(f32, allocator, count);
    defer allocator.free(graph_scores);
    const term_scores = try owned.slice(f32, allocator, count);
    defer allocator.free(term_scores);
    @memset(keyword, 0);
    @memset(graph_scores, 0);
    // Inverse document frequency. A term's document frequency is the number of
    // distinct nodes in its posting list, and the postings already answer that:
    // they are sorted ascending by node index, so counting distinct nodes is one
    // linear pass with no allocation and no second index.
    //
    // Without this every query term carries identical weight, so a token present
    // in every node counts for exactly as much as a rare identifier — which is
    // ranking by word count rather than by relevance.
    const idfs = try owned.slice(f32, allocator, query_terms.items.len);
    defer allocator.free(idfs);
    var idf_total: f32 = 0;
    for (query_terms.items, idfs) |term, *idf| {
        const postings = graph.lexicalPostings(term);
        var document_frequency: usize = 0;
        var last_index: usize = std.math.maxInt(usize);
        for (postings) |posting| {
            if (posting.node_index != last_index) {
                document_frequency += 1;
                last_index = posting.node_index;
            }
        }
        // Smoothed. The textbook ln(N/df) is exactly zero for a term present in
        // every node, which would make a query built only of common words score
        // zero everywhere and return nothing at all.
        idf.* = if (document_frequency == 0)
            0
        else
            @log(1.0 + @as(f32, @floatFromInt(count)) / @as(f32, @floatFromInt(document_frequency)));
        idf_total += idf.*;
    }
    if (idf_total <= 0) idf_total = 1;

    for (query_terms.items, idfs) |term, idf| {
        @memset(term_scores, 0);
        for (graph.lexicalPostings(term)) |posting| {
            const field_weight: f32 = switch (posting.field) {
                .label => 1.0,
                .path => 0.8,
                .search_text => 0.65,
            };
            const frequency_boost = @min(@as(f32, 1.2), 1.0 + 0.05 * @as(f32, @floatFromInt(posting.frequency - 1)));
            term_scores[posting.node_index] = @max(term_scores[posting.node_index], field_weight * frequency_boost);
        }
        for (0..count) |index| keyword[index] += term_scores[index] * idf / idf_total;
    }
    var max_keyword: f32 = 0;
    var max_vector: f32 = 0;
    for (0..count) |index| {
        vector[index] = @max(@as(f32, 0), nendb.cosine(&query_vector, graph.vectorAt(index)));
        max_keyword = @max(max_keyword, keyword[index]);
        max_vector = @max(max_vector, vector[index]);
    }
    for (0..count) |index| {
        if (max_keyword > 0) keyword[index] /= max_keyword;
        if (max_vector > 0) vector[index] /= max_vector;
        base[index] = 0.6 * keyword[index] + 0.4 * vector[index];
    }
    for (0..count) |index| {
        const node_id = graph.nodeAt(index).id;
        for (graph.outgoingEdges(node_id)) |edge_index| {
            const edge = graph.edgeAt(edge_index) orelse continue;
            const neighbor = graph.topology.findNodeIndex(edge.to) orelse continue;
            graph_scores[index] = @max(graph_scores[index], base[neighbor] * 0.5);
        }
        for (graph.incomingEdges(node_id)) |edge_index| {
            const edge = graph.edgeAt(edge_index) orelse continue;
            const neighbor = graph.topology.findNodeIndex(edge.from) orelse continue;
            graph_scores[index] = @max(graph_scores[index], base[neighbor] * 0.5);
        }
    }

    var ranked: std.ArrayList(Result) = .empty;
    defer ranked.deinit(allocator);
    for (0..count) |index| {
        const score = (options.keyword_weight * keyword[index] +
            options.vector_weight * vector[index] +
            options.graph_weight * graph_scores[index]) / weight_sum;
        if (score <= 0) continue;
        try ranked.append(allocator, .{
            .node_id = graph.nodeAt(index).id,
            .score = score,
            .keyword_score = keyword[index],
            .vector_score = vector[index],
            .graph_score = graph_scores[index],
        });
    }
    std.mem.sort(Result, ranked.items, {}, struct {
        fn lessThan(_: void, left: Result, right: Result) bool {
            if (left.score == right.score) return left.node_id < right.node_id;
            return left.score > right.score;
        }
    }.lessThan);
    const result_count = @min(options.limit, ranked.items.len);
    return .{ .allocator = allocator, .items = try owned.copy(Result, allocator, ranked.items[0..result_count]) };
}
