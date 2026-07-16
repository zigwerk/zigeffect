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
    while (tokenizer.next()) |token| try query_terms.append(allocator, nendb.tokenHash(token));
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
    @memset(graph_scores, 0);
    var max_keyword: f32 = 0;
    var max_vector: f32 = 0;
    for (0..count) |index| {
        const node = graph.nodeAt(index);
        keyword[index] = keywordScore(query_terms.items, node.label, node.search_text);
        vector[index] = @max(@as(f32, 0), nendb.cosine(&query_vector, graph.vectorAt(index)));
        max_keyword = @max(max_keyword, keyword[index]);
        max_vector = @max(max_vector, vector[index]);
    }
    for (0..count) |index| {
        if (max_keyword > 0) keyword[index] /= max_keyword;
        if (max_vector > 0) vector[index] /= max_vector;
        base[index] = 0.6 * keyword[index] + 0.4 * vector[index];
    }
    for (graph.edges.items) |edge| {
        const from_index = graph.topology.findNodeIndex(edge.from) orelse continue;
        const to_index = graph.topology.findNodeIndex(edge.to) orelse continue;
        graph_scores[from_index] = @max(graph_scores[from_index], base[to_index] * 0.5);
        graph_scores[to_index] = @max(graph_scores[to_index], base[from_index] * 0.5);
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

fn keywordScore(query_terms: []const u64, label: []const u8, text: []const u8) f32 {
    var matched: usize = 0;
    for (query_terms) |query_term| {
        if (containsTerm(label, query_term) or containsTerm(text, query_term)) matched += 1;
    }
    return @as(f32, @floatFromInt(matched)) / @as(f32, @floatFromInt(query_terms.len));
}

fn containsTerm(text: []const u8, expected: u64) bool {
    var tokenizer = nendb.Tokenizer.init(text);
    while (tokenizer.next()) |token| if (nendb.tokenHash(token) == expected) return true;
    return false;
}
