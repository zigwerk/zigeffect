//! zgroach's first consumer: a connector over the repository graph.
//!
//! The query layer has been complete and unused. Its two backends see the causal
//! forest — `backends/embedded.zig` holds a `CausalGraph.Snapshot` — and the
//! repository graph, the one an agent actually asks about, had no connector at
//! all. So a plan could be built, validated and refused, and never executed
//! against code.
//!
//! This is where `text_search` becomes true and means it. The store keeps
//! lexical postings per term, so a `.lexical` predicate is a posting-list walk
//! rather than a scan, and the connector declares the capability because it
//! performs it — not because the underlying store theoretically could.
//!
//! It ranks when asked to. `Plan.Result` gained a `scores` array, so a
//! `.lexical` predicate now returns ids ordered by relevance — inverse document
//! frequency weighted by which field the term hit, which is what distinguishes
//! two nodes that both contain every term.
//!
//! It ranks by similarity too. `Match.similar` carries the probe the IR was
//! missing, so a hybrid plan — narrow by term, order by distance — is one query
//! against one store rather than two passes merged by the caller.

const std = @import("std");
const model = @import("model.zig");
const nendb = @import("zgdb").Store;
const zgroach = @import("zgroach");

/// What this connector can answer, and nothing more.
///
/// `vector_search` is true and backed by computation: `Match.similar` carries
/// the probe, the store holds an embedding per node, and the connector compares
/// them. It is not true because the store *could* — the CockroachDB connector
/// says false for exactly that reason, since its emitter cannot write a distance
/// operator.
pub const capabilities = zgroach.Backend.Capabilities{
    .predicates = true,
    .text_search = true,
    .vector_search = true,
    .traversal = true,
    .reverse_traversal = true,
};

pub const RepositoryBackend = struct {
    graph: *const model.RepositoryGraph,

    pub fn backend(self: *RepositoryBackend) zgroach.Backend.Backend {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = zgroach.Backend.Backend.VTable{
        .name = "repository",
        .capabilities = capabilities,
        .execute = execute,
    };

    fn execute(ptr: *anyopaque, allocator: std.mem.Allocator, plan: zgroach.Plan.Plan) anyerror!zgroach.Plan.Result {
        const self: *RepositoryBackend = @ptrCast(@alignCast(ptr));
        return self.run(allocator, plan);
    }

    /// How well `node` answers the ranking predicates, by summed inverse
    /// document frequency.
    ///
    /// A term present in most of the corpus separates nothing, so it should not
    /// lift a result above one that matched something rare. Same smoothing as
    /// the ranking in `search.zig` — `ln(1 + N/df)` rather than `ln(N/df)`, which
    /// is exactly zero for a term in every node and would score a whole answer
    /// at zero for a query made of common words.
    fn relevance(self: *RepositoryBackend, node: *const model.Node, predicates: []const zgroach.Plan.Predicate) f32 {
        const index = self.graph.topology.findNodeIndex(node.id) orelse return 0;
        const total: f32 = @floatFromInt(@max(self.graph.nodeCount(), 1));
        var score: f32 = 0;
        for (predicates) |predicate| {
            const phrase = switch (predicate.match) {
                .lexical => |value| value,
                else => continue,
            };
            var tokenizer = nendb.Tokenizer.init(phrase);
            while (tokenizer.next()) |token| {
                const postings = self.graph.lexicalPostings(nendb.tokenHash(token));
                if (postings.len == 0) continue;
                const idf = @log(1.0 + total / @as(f32, @floatFromInt(postings.len)));

                // Where the term hit, not merely that it did. Every node that
                // survives `matches` contains every term, so an IDF sum alone is
                // identical for all of them and orders nothing — a score has to
                // read something about *this* node to rank it.
                var best: f32 = 0;
                for (postings) |posting| {
                    if (posting.node_index != index) continue;
                    const field_weight: f32 = switch (posting.field) {
                        .label => 1.0,
                        .path => 0.8,
                        .search_text => 0.65,
                    };
                    const frequency = @min(@as(f32, 1.2), 1.0 + 0.05 * @as(f32, @floatFromInt(posting.frequency - 1)));
                    best = @max(best, field_weight * frequency);
                }
                score += idf * best;
            }
        }
        for (predicates) |predicate| {
            const probe = switch (predicate.match) {
                .similar => |value| value,
                else => continue,
            };
            // A probe of the wrong width is a caller error, not a reason to
            // guess: `cosine` returns 0 for mismatched lengths, so a 3-element
            // probe against 64-dimension embeddings would score every node
            // identically and look like a tie rather than a mistake.
            if (probe.len != nendb.embedding_dimensions) continue;
            score += @max(@as(f32, 0), nendb.cosine(probe, self.graph.vectorAt(index)));
        }
        return score;
    }

    fn run(self: *RepositoryBackend, allocator: std.mem.Allocator, plan: zgroach.Plan.Plan) !zgroach.Plan.Result {
        var ids: std.ArrayList(u64) = .empty;
        errdefer ids.deinit(allocator);
        var scanned: usize = 0;
        var truncated = false;

        switch (plan.from) {
            .event => |id| {
                scanned = 1;
                if (self.graph.findNode(id)) |node| try ids.append(allocator, node.id);
            },
            .matching => |predicates| {
                const ranking = ranksAny(predicates);
                var scores: std.ArrayList(f32) = .empty;
                defer scores.deinit(allocator);

                for (0..self.graph.nodeCount()) |index| {
                    if (scanned >= plan.scan_limit) {
                        truncated = true;
                        break;
                    }
                    scanned += 1;
                    const node = self.graph.nodeAt(index);
                    if (!matchesAll(self.graph, node, predicates)) continue;
                    if (ids.items.len >= plan.limit) {
                        truncated = true;
                        break;
                    }
                    try ids.append(allocator, node.id);
                    if (ranking) try scores.append(allocator, self.relevance(node, predicates));
                }

                if (ranking) {
                    sortByScore(ids.items, scores.items);
                    return .{
                        .ids = try ids.toOwnedSlice(allocator),
                        .scores = try scores.toOwnedSlice(allocator),
                        .scanned = scanned,
                        .truncated = truncated,
                    };
                }
            },
        }

        return .{
            .ids = try ids.toOwnedSlice(allocator),
            .scanned = scanned,
            .truncated = truncated,
        };
    }
};

/// Whether any predicate asks for a ranking rather than a comparison.
fn ranksAny(predicates: []const zgroach.Plan.Predicate) bool {
    for (predicates) |predicate| if (predicate.match.ranks()) return true;
    return false;
}

/// Order ids by descending score, carrying the scores with them.
///
/// An insertion sort because `limit` defaults to 256 and is capped well below
/// where anything cleverer pays for itself; the two arrays move together so a
/// score can never end up beside the wrong id.
fn sortByScore(ids: []u64, scores: []f32) void {
    var i: usize = 1;
    while (i < ids.len) : (i += 1) {
        const id = ids[i];
        const score = scores[i];
        var j = i;
        while (j > 0 and scores[j - 1] < score) : (j -= 1) {
            ids[j] = ids[j - 1];
            scores[j] = scores[j - 1];
        }
        ids[j] = id;
        scores[j] = score;
    }
}

fn matchesAll(graph: *const model.RepositoryGraph, node: *const model.Node, predicates: []const zgroach.Plan.Predicate) bool {
    for (predicates) |predicate| {
        const holds = matches(graph, node, predicate);
        if (holds == predicate.negated) return false;
    }
    return true;
}

fn matches(graph: *const model.RepositoryGraph, node: *const model.Node, predicate: zgroach.Plan.Predicate) bool {
    return switch (predicate.match) {
        .text => |wanted| blk: {
            const actual = column(node, predicate.field) orelse break :blk false;
            break :blk std.mem.eql(u8, actual, wanted);
        },
        .id => |wanted| node.id == wanted,
        // Every term must appear. A node matching one word of three is not what
        // was asked for, and without a score there is no way to say it matched
        // less — so the honest boolean is "all of them".
        .lexical => |phrase| blk: {
            var tokenizer = nendb.Tokenizer.init(phrase);
            var saw_term = false;
            while (tokenizer.next()) |token| {
                saw_term = true;
                if (!termHitsNode(graph, nendb.tokenHash(token), node.id)) break :blk false;
            }
            break :blk saw_term;
        },
        // Similarity ranks; it does not filter. Every node is a candidate because
        // there is no threshold in the plan to be below, and inventing one would
        // silently drop results the caller never excluded. Narrowing is what the
        // other predicates are for, and `scan_limit` is what bounds the cost.
        .similar => true,
    };
}

/// Whether `term` has a posting on `node_id`.
///
/// A posting-list walk rather than a scan of the node's text: the store already
/// keeps the inverted index, and using the field text instead would make a
/// declared index decorative.
fn termHitsNode(graph: *const model.RepositoryGraph, term: u64, node_id: u64) bool {
    const index = graph.topology.findNodeIndex(node_id) orelse return false;
    for (graph.lexicalPostings(term)) |posting| {
        if (posting.node_index == index) return true;
    }
    return false;
}

fn column(node: *const model.Node, field: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, field, "label")) return node.label;
    if (std.mem.eql(u8, field, "path")) return node.path;
    if (std.mem.eql(u8, field, "kind")) return @tagName(node.kind);
    return null;
}
