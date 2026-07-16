const std = @import("std");
const assets = @import("zgraphy_benchmark_assets");
const benchmark = @import("benchmark.zig");
const memory = @import("memory.zig");
const model = @import("model.zig");

pub const schema = "zgraphy.freshness-receipt.v1";
pub const schema_version: u32 = 1;
pub const promotion_status = "baseline_only";
pub const transition_file_schema = "zgraphy.freshness-transitions.v1";
pub const max_transition_file_bytes: usize = 1024 * 1024;
pub const embedded_baseline = assets.freshness_receipt;

pub const CapabilityStatus = enum {
    supported,
    unsupported,
};

pub const Capabilities = struct {
    full_rebuild: CapabilityStatus,
    snapshot_pruning: CapabilityStatus,
    incremental_update: CapabilityStatus,
    pre_query_refresh: CapabilityStatus,
    watch_mode: CapabilityStatus,
    automatic_pruning: CapabilityStatus,
    repair: CapabilityStatus,
    garbage_collection: CapabilityStatus,

    pub fn currentM0() Capabilities {
        return .{
            .full_rebuild = .supported,
            .snapshot_pruning = .supported,
            .incremental_update = .unsupported,
            .pre_query_refresh = .unsupported,
            .watch_mode = .unsupported,
            .automatic_pruning = .unsupported,
            .repair = .unsupported,
            .garbage_collection = .unsupported,
        };
    }
};

pub const UpdateMode = enum {
    full_rebuild,
    incremental,
    unsupported,
};

pub const Health = struct {
    nodes: usize,
    edges: usize,
    vectors: usize,
    dangling_edges: usize,
    missing_vectors: usize,
    unowned_vectors: usize,
    true_orphans: usize,

    pub fn clean(self: Health) bool {
        return self.dangling_edges == 0 and self.missing_vectors == 0 and self.unowned_vectors == 0 and self.true_orphans == 0;
    }
};

pub const Transition = struct {
    mutation_id: []const u8,
    operation: benchmark.MutationOperation,
    update_mode: UpdateMode = .full_rebuild,
    before_digest: []const u8,
    after_digest: []const u8,
    observed_graph_fingerprint: []const u8,
    clean_graph_fingerprint: []const u8,
    canonical_equivalent: bool = true,
    preserved_expected: usize = 0,
    preserved_observed: usize = 0,
    removed_expected: usize = 0,
    removed_observed: usize = 0,
    invalidated_expected: usize = 0,
    invalidated_observed: usize = 0,
    stale_nodes: usize = 0,
    stale_edges: usize = 0,
    dangling_edges: usize = 0,
    true_orphans: usize = 0,
    unowned_vectors: usize = 0,
    snapshot_complete: bool = true,
    persisted_bytes: u64,
};

pub const TransitionFile = struct {
    schema: []const u8,
    schema_version: u32,
    transitions: []const Transition,
};

const limitations = [_][]const u8{
    "M0 proves full-rebuild equivalence and snapshot pruning only",
    "incremental update automatic pre-query refresh watch repair and garbage collection are unsupported",
    "path-based rename identity and semantic fact invalidation remain measured baseline deficits",
};

pub const Receipt = struct {
    schema: []const u8 = schema,
    schema_version: u32 = schema_version,
    promotion_status: []const u8 = promotion_status,
    fixture_id: []const u8 = "mutation-pruning",
    corpus_digest: []const u8,
    capabilities: Capabilities,
    transitions: []Transition,
    freshness_gate_passed: bool,
    claims: []const []const u8 = &.{},
    limitations: []const []const u8 = &limitations,

    pub fn deinit(self: *Receipt, allocator: std.mem.Allocator) void {
        allocator.free(self.transitions);
        self.transitions = &.{};
    }
};

const required_mutations = [_]struct { id: []const u8, operation: benchmark.MutationOperation }{
    .{ .id = "modify-catalog", .operation = .modify },
    .{ .id = "rename-catalog-to-inventory", .operation = .rename },
    .{ .id = "delete-inventory", .operation = .delete },
};

pub fn inspect(graph: *const model.RepositoryGraph) Health {
    var dangling_edges: usize = 0;
    for (graph.edges.items) |edge| {
        if (graph.findNode(edge.from) == null or graph.findNode(edge.to) == null) dangling_edges += 1;
    }
    const missing_vectors = if (graph.nodeCount() > graph.vectorCount()) graph.nodeCount() - graph.vectorCount() else 0;
    const unowned_vectors = if (graph.vectorCount() > graph.nodeCount()) graph.vectorCount() - graph.nodeCount() else 0;
    return .{
        .nodes = graph.nodeCount(),
        .edges = graph.edgeCount(),
        .vectors = graph.vectorCount(),
        .dangling_edges = dangling_edges,
        .missing_vectors = missing_vectors,
        .unowned_vectors = unowned_vectors,
        .true_orphans = dangling_edges + unowned_vectors,
    };
}

pub fn fingerprint(allocator: std.mem.Allocator, graph: *const model.RepositoryGraph) ![32]u8 {
    const node_order = try memory.slice(usize, allocator, graph.nodes.items.len);
    defer allocator.free(node_order);
    for (node_order, 0..) |*value, index| value.* = index;
    std.mem.sort(usize, node_order, graph, struct {
        fn lessThan(context: *const model.RepositoryGraph, left: usize, right: usize) bool {
            return context.nodes.items[left].id < context.nodes.items[right].id;
        }
    }.lessThan);

    const edge_order = try memory.slice(usize, allocator, graph.edges.items.len);
    defer allocator.free(edge_order);
    for (edge_order, 0..) |*value, index| value.* = index;
    std.mem.sort(usize, edge_order, graph, struct {
        fn lessThan(context: *const model.RepositoryGraph, left: usize, right: usize) bool {
            const a = context.edges.items[left];
            const b = context.edges.items[right];
            if (a.from != b.from) return a.from < b.from;
            if (a.to != b.to) return a.to < b.to;
            if (a.relation != b.relation) return @intFromEnum(a.relation) < @intFromEnum(b.relation);
            if (a.provenance != b.provenance) return @intFromEnum(a.provenance) < @intFromEnum(b.provenance);
            const path_order = std.mem.order(u8, a.source_path, b.source_path);
            if (path_order != .eq) return path_order == .lt;
            return a.line < b.line;
        }
    }.lessThan);

    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateU64(&hasher, graph.nodeCount());
    for (node_order) |index| {
        const node = graph.nodes.items[index];
        updateU64(&hasher, node.id);
        updateU64(&hasher, @intFromEnum(node.kind));
        updateBytes(&hasher, node.label);
        updateBytes(&hasher, node.path);
        updateU64(&hasher, node.line);
        updateBytes(&hasher, node.search_text);
        for (graph.vectorAt(index)) |value| updateU32(&hasher, @bitCast(value));
    }
    updateU64(&hasher, graph.edgeCount());
    for (edge_order) |index| {
        const edge = graph.edges.items[index];
        updateU64(&hasher, edge.from);
        updateU64(&hasher, edge.to);
        updateU64(&hasher, @intFromEnum(edge.relation));
        updateU64(&hasher, @intFromEnum(edge.provenance));
        updateBytes(&hasher, edge.source_path);
        updateU64(&hasher, edge.line);
    }
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    return digest;
}

pub fn build(
    allocator: std.mem.Allocator,
    corpus_digest: []const u8,
    input_transitions: []const Transition,
    capabilities: Capabilities,
) !Receipt {
    const transitions = try memory.copy(Transition, allocator, input_transitions);
    errdefer allocator.free(transitions);
    var receipt = Receipt{
        .corpus_digest = corpus_digest,
        .capabilities = capabilities,
        .transitions = transitions,
        .freshness_gate_passed = transitionsPass(input_transitions),
    };
    try validate(&receipt);
    return receipt;
}

pub fn parseTransitionFile(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(TransitionFile) {
    if (bytes.len == 0 or bytes.len > max_transition_file_bytes) return error.InvalidFreshnessTransitionFile;
    const parsed = std.json.parseFromSlice(TransitionFile, allocator, bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = false,
    }) catch return error.InvalidFreshnessTransitionFile;
    if (!std.mem.eql(u8, parsed.value.schema, transition_file_schema) or parsed.value.schema_version != schema_version) {
        var owned = parsed;
        owned.deinit();
        return error.InvalidFreshnessTransitionFile;
    }
    return parsed;
}

pub fn parseEmbeddedBaseline(allocator: std.mem.Allocator) !std.json.Parsed(Receipt) {
    return std.json.parseFromSlice(Receipt, allocator, embedded_baseline, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = false,
    });
}

pub fn validate(receipt: *const Receipt) !void {
    if (!std.mem.eql(u8, receipt.schema, schema) or receipt.schema_version != schema_version or
        !std.mem.eql(u8, receipt.promotion_status, promotion_status))
    {
        return error.IncompatibleFreshnessReceipt;
    }
    if (!std.mem.eql(u8, receipt.fixture_id, "mutation-pruning") or !validSha256Identity(receipt.corpus_digest) or
        receipt.claims.len != 0 or receipt.limitations.len != limitations.len)
    {
        return error.InvalidFreshnessReceipt;
    }
    for (limitations, receipt.limitations) |expected, actual| {
        if (!std.mem.eql(u8, expected, actual)) return error.InvalidFreshnessLimitations;
    }
    const capabilities = receipt.capabilities;
    if (capabilities.full_rebuild != .supported or capabilities.snapshot_pruning != .supported or
        capabilities.incremental_update != .unsupported or capabilities.pre_query_refresh != .unsupported or
        capabilities.watch_mode != .unsupported or capabilities.automatic_pruning != .unsupported or
        capabilities.repair != .unsupported or capabilities.garbage_collection != .unsupported)
    {
        return error.InvalidFreshnessCapabilities;
    }
    if (receipt.transitions.len != required_mutations.len) return error.IncompleteFreshnessSequence;
    for (receipt.transitions, required_mutations, 0..) |transition, required, index| {
        if (!std.mem.eql(u8, transition.mutation_id, required.id) or transition.operation != required.operation or
            transition.update_mode != .full_rebuild or !validSha256Identity(transition.before_digest) or
            !validSha256Identity(transition.after_digest) or !validSha256Identity(transition.observed_graph_fingerprint) or
            !validSha256Identity(transition.clean_graph_fingerprint) or !transition.canonical_equivalent or
            !std.mem.eql(u8, transition.observed_graph_fingerprint, transition.clean_graph_fingerprint) or
            transition.preserved_observed > transition.preserved_expected or
            transition.removed_expected != transition.removed_observed or
            transition.invalidated_observed > transition.invalidated_expected or transition.stale_nodes != 0 or
            transition.stale_edges != 0 or transition.dangling_edges != 0 or transition.true_orphans != 0 or
            transition.unowned_vectors != 0 or !transition.snapshot_complete or transition.persisted_bytes == 0)
        {
            return error.InvalidFreshnessTransition;
        }
        if (index > 0 and !std.mem.eql(u8, receipt.transitions[index - 1].after_digest, transition.before_digest)) {
            return error.DisconnectedFreshnessSequence;
        }
    }
    if (receipt.freshness_gate_passed != transitionsPass(receipt.transitions)) return error.InconsistentFreshnessGate;
}

fn transitionsPass(transitions: []const Transition) bool {
    if (transitions.len != required_mutations.len) return false;
    for (transitions) |transition| {
        if (!transition.canonical_equivalent or transition.preserved_expected != transition.preserved_observed or
            transition.removed_expected != transition.removed_observed or
            transition.invalidated_expected != transition.invalidated_observed or transition.stale_nodes != 0 or
            transition.stale_edges != 0 or transition.dangling_edges != 0 or transition.true_orphans != 0 or
            transition.unowned_vectors != 0 or !transition.snapshot_complete)
        {
            return false;
        }
    }
    return true;
}

fn updateBytes(hasher: *std.crypto.hash.sha2.Sha256, value: []const u8) void {
    updateU64(hasher, value.len);
    hasher.update(value);
}

fn updateU64(hasher: *std.crypto.hash.sha2.Sha256, value: anytype) void {
    var bytes: [8]u8 = @splat(0);
    std.mem.writeInt(u64, &bytes, @intCast(value), .little);
    hasher.update(&bytes);
}

fn updateU32(hasher: *std.crypto.hash.sha2.Sha256, value: u32) void {
    var bytes: [4]u8 = @splat(0);
    std.mem.writeInt(u32, &bytes, value, .little);
    hasher.update(&bytes);
}

fn validSha256Identity(value: []const u8) bool {
    const prefix = "sha256:";
    if (!std.mem.startsWith(u8, value, prefix) or value.len != prefix.len + 64) return false;
    for (value[prefix.len..]) |byte| {
        if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    }
    return true;
}
