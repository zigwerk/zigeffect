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
//! Deliberately not ranking yet. `Plan.Result` is `{ids, scanned, truncated}`
//! with nowhere to put a score, so this answers *which* nodes match and leaves
//! *how well* to the rank clause the IR does not have. Returning an arbitrary
//! order and calling it relevance would be worse than returning a set.

const std = @import("std");
const model = @import("model.zig");
const nendb = @import("zgdb").Store;
const zgroach = @import("zgroach");

/// What this connector can answer, and nothing more.
///
/// `vector_search` is false even though the store holds an embedding per node,
/// for the same reason the CockroachDB connector says false: similarity is an
/// ordering and `Plan.Result` carries no order.
pub const capabilities = zgroach.Backend.Capabilities{
    .predicates = true,
    .text_search = true,
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
        // Refused by capability before execution; reaching here means that check
        // was bypassed, and a wrong answer is worse than a loud stop.
        .similar => unreachable,
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
