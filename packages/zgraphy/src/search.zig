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
    /// Nodes actually scored. The postings plus one hop, not the corpus — so
    /// this reads far below `nodeCount()` on any selective query, and a reader
    /// can tell a narrow answer from an exhaustive one.
    scanned: usize = 0,
    /// Nodes in the graph when the query ran, so `scanned` has a denominator.
    corpus: usize = 0,

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
    @memset(keyword, 0);
    @memset(vector, 0);
    @memset(base, 0);
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

    // The postings ARE the candidate generator. A node with no matching term and
    // no matching neighbour cannot outrank one that has either, so scoring the
    // whole corpus in order to discover that is work spent to learn nothing.
    //
    // This is also what demotes the vector from a generator over the corpus to a
    // rescorer over the candidates, and that demotion is what keeps an
    // approximate-nearest-neighbour index unnecessary rather than merely
    // deferred: the cosine now runs over hundreds of nodes, not all of them.
    const seen = try owned.slice(bool, allocator, count);
    defer allocator.free(seen);
    @memset(seen, false);
    var candidates: std.ArrayList(u32) = .empty;
    defer candidates.deinit(allocator);

    for (query_terms.items, idfs) |term, idf| {
        const postings = graph.lexicalPostings(term);
        var cursor: usize = 0;
        while (cursor < postings.len) {
            // Postings for one term are sorted by node index, so every posting
            // for a given node is contiguous. The best field wins without a
            // dense per-term scratch array to scatter into and re-zero.
            const node_index = postings[cursor].node_index;
            var best: f32 = 0;
            while (cursor < postings.len and postings[cursor].node_index == node_index) : (cursor += 1) {
                const field_weight: f32 = switch (postings[cursor].field) {
                    .label => 1.0,
                    .path => 0.8,
                    .search_text => 0.65,
                };
                const frequency_boost = @min(@as(f32, 1.2), 1.0 + 0.05 * @as(f32, @floatFromInt(postings[cursor].frequency - 1)));
                best = @max(best, field_weight * frequency_boost);
            }
            keyword[node_index] += best * idf / idf_total;
            if (!seen[node_index]) {
                seen[node_index] = true;
                try candidates.append(allocator, @intCast(node_index));
            }
        }
    }

    // One hop out. The graph signal lets a node score through a matching
    // neighbour, so a neighbour of a seed is a candidate even when it matched no
    // term itself. Anything further than one hop cannot affect the score,
    // because the propagation below reads `base` and never chains.
    const seed_count = candidates.items.len;
    for (0..seed_count) |position| {
        const seed_index = candidates.items[position];
        const node_id = graph.nodeAt(seed_index).id;
        for (graph.outgoingEdges(node_id)) |edge_index| {
            const edge = graph.edgeAt(edge_index) orelse continue;
            const neighbor = graph.topology.findNodeIndex(edge.to) orelse continue;
            if (seen[neighbor]) continue;
            seen[neighbor] = true;
            try candidates.append(allocator, @intCast(neighbor));
        }
        for (graph.incomingEdges(node_id)) |edge_index| {
            const edge = graph.edgeAt(edge_index) orelse continue;
            const neighbor = graph.topology.findNodeIndex(edge.from) orelse continue;
            if (seen[neighbor]) continue;
            seen[neighbor] = true;
            try candidates.append(allocator, @intCast(neighbor));
        }
    }

    var max_keyword: f32 = 0;
    var max_vector: f32 = 0;
    for (candidates.items) |index| {
        vector[index] = @max(@as(f32, 0), nendb.cosine(&query_vector, graph.vectorAt(index)));
        max_keyword = @max(max_keyword, keyword[index]);
        max_vector = @max(max_vector, vector[index]);
    }
    for (candidates.items) |index| {
        if (max_keyword > 0) keyword[index] /= max_keyword;
        if (max_vector > 0) vector[index] /= max_vector;
        base[index] = 0.6 * keyword[index] + 0.4 * vector[index];
    }
    for (candidates.items) |index| {
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
    for (candidates.items) |index| {
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
    return .{
        .allocator = allocator,
        .items = try owned.copy(Result, allocator, ranked.items[0..result_count]),
        .scanned = candidates.items.len,
        .corpus = count,
    };
}
