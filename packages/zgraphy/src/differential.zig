const std = @import("std");
const assets = @import("zgraphy_benchmark_assets");
const benchmark = @import("benchmark.zig");
const lexical = @import("lexical.zig");
const model = @import("model.zig");
const owned = @import("memory.zig");
const parity = @import("parity.zig");

pub const schema = "zgraphy.differential-receipt.v1";
pub const schema_version: u32 = 1;
pub const adapter_version = "graphify-json-v1";
pub const zgraphy_adapter_version = "zgraphy-native-v2";
pub const zgraphy_version = "0.1.0";
pub const lexical_adapter_version = "lexical-token-v1";
pub const max_graph_bytes: usize = 64 * 1024 * 1024;
pub const embedded_graphify_fixture = assets.graphify_zig_ambiguity;

pub const GraphifyNode = struct {
    id: []const u8,
    label: []const u8,
    file_type: []const u8 = "",
    source_file: []const u8 = "",
    source_location: []const u8 = "",
};

pub const GraphifyEdge = struct {
    source: []const u8,
    target: []const u8,
    relation: []const u8,
    confidence: []const u8 = "EXTRACTED",
    source_file: []const u8 = "",
    source_location: []const u8 = "",
    context: ?[]const u8 = null,
    weight: f64 = 1,
};

pub const GraphifyGraph = struct {
    nodes: []const GraphifyNode,
    edges: []const GraphifyEdge = &.{},
    links: []const GraphifyEdge = &.{},
    hyperedges: []const std.json.Value = &.{},
    input_tokens: u64 = 0,
    output_tokens: u64 = 0,

    pub fn relations(self: *const GraphifyGraph) []const GraphifyEdge {
        return if (self.edges.len > 0) self.edges else self.links;
    }
};

pub const Adapter = struct {
    engine: []const u8 = "Graphify",
    version: []const u8 = parity.pinned_graphify_version,
    commit: []const u8 = parity.pinned_graphify_commit,
    adapter_version: []const u8 = adapter_version,
    input_schema: []const u8 = "graphify.graph-json.v1",
    output_schema: []const u8 = benchmark.canonical_ir_schema,
};

pub const InputCounts = struct {
    nodes: usize,
    relations: usize,
    hyperedges: usize,
    input_tokens: u64,
    output_tokens: u64,
};

pub const Score = struct {
    expected: usize,
    matched: usize,
    missing: usize,
    unexpected: usize,
    recall: f64,
    conservative_precision: f64,
    f1: f64,
};

pub const ProjectionSummary = struct {
    mapped_input_nodes: usize,
    projected_unique_entities: usize,
    mapped_input_relations: usize,
    entity_evidence_line_matches: usize,
    relation_evidence_line_matches: usize,
    provenance_matches: usize,
    provenance_mismatches: usize,
};

pub const Receipt = struct {
    schema: []const u8 = schema,
    schema_version: u32 = schema_version,
    fixture_id: []const u8,
    adapter: Adapter = .{},
    input: InputCounts,
    projection: ProjectionSummary,
    entities: Score,
    relations: Score,
    facts: Score,
    hyperedges: Score,
    supernodes: Score,
    missing_entity_ids: []const []const u8,
    missing_relation_ids: []const []const u8,
    missing_fact_ids: []const []const u8,
    missing_hyperedge_ids: []const []const u8,
    missing_supernode_ids: []const []const u8,
    synthesized_entity_ids: []const []const u8,
    synthesized_relation_ids: []const []const u8,
    unmappable_node_labels: []const []const u8,
    unmappable_relation_kinds: []const []const u8,

    pub fn deinit(self: *Receipt, allocator: std.mem.Allocator) void {
        allocator.free(self.missing_entity_ids);
        allocator.free(self.missing_relation_ids);
        allocator.free(self.missing_fact_ids);
        allocator.free(self.missing_hyperedge_ids);
        allocator.free(self.missing_supernode_ids);
        allocator.free(self.synthesized_entity_ids);
        allocator.free(self.synthesized_relation_ids);
        allocator.free(self.unmappable_node_labels);
        allocator.free(self.unmappable_relation_kinds);
        self.* = undefinedReceipt();
    }
};

pub fn parseEmbeddedGraphifyFixture(allocator: std.mem.Allocator) !std.json.Parsed(GraphifyGraph) {
    return parseGraphify(allocator, embedded_graphify_fixture);
}

pub fn parseGraphify(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(GraphifyGraph) {
    if (bytes.len == 0 or bytes.len > max_graph_bytes) return error.InvalidGraphifyGraph;
    return std.json.parseFromSlice(GraphifyGraph, allocator, bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch return error.InvalidGraphifyGraph;
}

pub fn projectGraphify(
    allocator: std.mem.Allocator,
    graph: *const GraphifyGraph,
    gold: *const benchmark.CanonicalIr,
) !Receipt {
    if (graph.nodes.len == 0) return error.EmptyGraphifyGraph;
    try benchmark.validateGold(gold, gold.fixture_id);

    const entity_seen = try owned.slice(bool, allocator, gold.entities.len);
    defer allocator.free(entity_seen);
    @memset(entity_seen, false);
    const relation_seen = try owned.slice(bool, allocator, gold.relations.len);
    defer allocator.free(relation_seen);
    @memset(relation_seen, false);
    const node_mappings = try owned.slice(?usize, allocator, graph.nodes.len);
    defer allocator.free(node_mappings);
    @memset(node_mappings, null);

    var synthesized_entities: std.ArrayList([]const u8) = .empty;
    defer synthesized_entities.deinit(allocator);
    var synthesized_relations: std.ArrayList([]const u8) = .empty;
    defer synthesized_relations.deinit(allocator);
    var unmappable_nodes: std.ArrayList([]const u8) = .empty;
    defer unmappable_nodes.deinit(allocator);
    var unmappable_relations: std.ArrayList([]const u8) = .empty;
    defer unmappable_relations.deinit(allocator);

    for (gold.entities, 0..) |entity, index| {
        if (entity.kind == .repository) {
            entity_seen[index] = true;
            try synthesized_entities.append(allocator, entity.id);
        }
    }

    var mapped_input_nodes: usize = 0;
    var entity_evidence_line_matches: usize = 0;
    for (graph.nodes, 0..) |node, index| {
        const mapped = findGoldEntity(gold, &node);
        node_mappings[index] = mapped;
        if (mapped) |entity_index| {
            mapped_input_nodes += 1;
            entity_seen[entity_index] = true;
            if (evidenceLineMatches(gold, gold.entities[entity_index].evidence, node.source_file, parseLine(node.source_location))) {
                entity_evidence_line_matches += 1;
            }
        } else {
            try unmappable_nodes.append(allocator, node.label);
        }
    }

    for (gold.relations, 0..) |relation, index| {
        if (relation.kind != .contains) continue;
        const from = findEntityIndex(gold, relation.from) orelse continue;
        const to = findEntityIndex(gold, relation.to) orelse continue;
        if (gold.entities[from].kind != .repository or gold.entities[to].kind != .file) continue;
        if (!entity_seen[from] or !entity_seen[to]) continue;
        relation_seen[index] = true;
        try synthesized_relations.append(allocator, relation.id);
    }

    var mapped_input_relations: usize = 0;
    var relation_evidence_line_matches: usize = 0;
    var provenance_matches: usize = 0;
    var provenance_mismatches: usize = 0;
    for (graph.relations()) |edge| {
        const from = mapEndpoint(graph, node_mappings, gold, edge.source) orelse {
            try unmappable_relations.append(allocator, edge.relation);
            continue;
        };
        const to = mapEndpoint(graph, node_mappings, gold, edge.target) orelse {
            try unmappable_relations.append(allocator, edge.relation);
            continue;
        };
        const kind = canonicalRelation(edge.relation) orelse {
            try unmappable_relations.append(allocator, edge.relation);
            continue;
        };
        const expected_index = findExpectedRelation(gold, relation_seen, kind, gold.entities[from].id, gold.entities[to].id) orelse {
            try unmappable_relations.append(allocator, edge.relation);
            continue;
        };
        relation_seen[expected_index] = true;
        mapped_input_relations += 1;
        const expected = &gold.relations[expected_index];
        if (evidenceLineMatches(gold, expected.evidence, edge.source_file, parseLine(edge.source_location))) {
            relation_evidence_line_matches += 1;
        }
        if (canonicalProvenance(edge.confidence)) |provenance| {
            if (provenance == expected.provenance) provenance_matches += 1 else provenance_mismatches += 1;
        } else {
            provenance_mismatches += 1;
        }
    }

    var missing_entities: std.ArrayList([]const u8) = .empty;
    defer missing_entities.deinit(allocator);
    var missing_relations: std.ArrayList([]const u8) = .empty;
    defer missing_relations.deinit(allocator);
    var missing_facts: std.ArrayList([]const u8) = .empty;
    defer missing_facts.deinit(allocator);
    var missing_hyperedges: std.ArrayList([]const u8) = .empty;
    defer missing_hyperedges.deinit(allocator);
    var missing_supernodes: std.ArrayList([]const u8) = .empty;
    defer missing_supernodes.deinit(allocator);

    for (gold.entities, entity_seen) |entity, seen| if (!seen) try missing_entities.append(allocator, entity.id);
    for (gold.relations, relation_seen) |relation, seen| if (!seen) try missing_relations.append(allocator, relation.id);
    for (gold.facts) |fact| try missing_facts.append(allocator, fact.id);
    for (gold.hyperedges) |hyperedge| try missing_hyperedges.append(allocator, hyperedge.id);
    for (gold.supernodes) |supernode| try missing_supernodes.append(allocator, supernode.id);

    const projected_unique_entities = countTrue(entity_seen) - synthesized_entities.items.len;
    const matched_entities = countTrue(entity_seen);
    const matched_relations = countTrue(relation_seen);
    const unexpected_nodes = graph.nodes.len - mapped_input_nodes;
    const unexpected_relations = graph.relations().len - mapped_input_relations;

    const missing_entity_ids = try missing_entities.toOwnedSlice(allocator);
    errdefer allocator.free(missing_entity_ids);
    const missing_relation_ids = try missing_relations.toOwnedSlice(allocator);
    errdefer allocator.free(missing_relation_ids);
    const missing_fact_ids = try missing_facts.toOwnedSlice(allocator);
    errdefer allocator.free(missing_fact_ids);
    const missing_hyperedge_ids = try missing_hyperedges.toOwnedSlice(allocator);
    errdefer allocator.free(missing_hyperedge_ids);
    const missing_supernode_ids = try missing_supernodes.toOwnedSlice(allocator);
    errdefer allocator.free(missing_supernode_ids);
    const synthesized_entity_ids = try synthesized_entities.toOwnedSlice(allocator);
    errdefer allocator.free(synthesized_entity_ids);
    const synthesized_relation_ids = try synthesized_relations.toOwnedSlice(allocator);
    errdefer allocator.free(synthesized_relation_ids);
    const unmappable_node_labels = try unmappable_nodes.toOwnedSlice(allocator);
    errdefer allocator.free(unmappable_node_labels);
    const unmappable_relation_kinds = try unmappable_relations.toOwnedSlice(allocator);
    errdefer allocator.free(unmappable_relation_kinds);

    return .{
        .fixture_id = gold.fixture_id,
        .input = .{
            .nodes = graph.nodes.len,
            .relations = graph.relations().len,
            .hyperedges = graph.hyperedges.len,
            .input_tokens = graph.input_tokens,
            .output_tokens = graph.output_tokens,
        },
        .projection = .{
            .mapped_input_nodes = mapped_input_nodes,
            .projected_unique_entities = projected_unique_entities,
            .mapped_input_relations = mapped_input_relations,
            .entity_evidence_line_matches = entity_evidence_line_matches,
            .relation_evidence_line_matches = relation_evidence_line_matches,
            .provenance_matches = provenance_matches,
            .provenance_mismatches = provenance_mismatches,
        },
        .entities = score(gold.entities.len, matched_entities, unexpected_nodes),
        .relations = score(gold.relations.len, matched_relations, unexpected_relations),
        .facts = score(gold.facts.len, 0, 0),
        .hyperedges = score(gold.hyperedges.len, 0, graph.hyperedges.len),
        .supernodes = score(gold.supernodes.len, 0, 0),
        .missing_entity_ids = missing_entity_ids,
        .missing_relation_ids = missing_relation_ids,
        .missing_fact_ids = missing_fact_ids,
        .missing_hyperedge_ids = missing_hyperedge_ids,
        .missing_supernode_ids = missing_supernode_ids,
        .synthesized_entity_ids = synthesized_entity_ids,
        .synthesized_relation_ids = synthesized_relation_ids,
        .unmappable_node_labels = unmappable_node_labels,
        .unmappable_relation_kinds = unmappable_relation_kinds,
    };
}

pub fn projectZgraphy(
    allocator: std.mem.Allocator,
    graph: *const model.RepositoryGraph,
    gold: *const benchmark.CanonicalIr,
) !Receipt {
    if (graph.nodes.items.len == 0) return error.EmptyZgraphyGraph;
    try benchmark.validateGold(gold, gold.fixture_id);

    const entity_seen = try owned.slice(bool, allocator, gold.entities.len);
    defer allocator.free(entity_seen);
    @memset(entity_seen, false);
    const relation_seen = try owned.slice(bool, allocator, gold.relations.len);
    defer allocator.free(relation_seen);
    @memset(relation_seen, false);
    const fact_seen = try owned.slice(bool, allocator, gold.facts.len);
    defer allocator.free(fact_seen);
    @memset(fact_seen, false);
    const node_mappings = try owned.slice(?usize, allocator, graph.nodes.items.len);
    defer allocator.free(node_mappings);
    @memset(node_mappings, null);

    var synthesized_entities: std.ArrayList([]const u8) = .empty;
    defer synthesized_entities.deinit(allocator);
    var synthesized_relations: std.ArrayList([]const u8) = .empty;
    defer synthesized_relations.deinit(allocator);
    var unmappable_nodes: std.ArrayList([]const u8) = .empty;
    defer unmappable_nodes.deinit(allocator);
    var unmappable_relations: std.ArrayList([]const u8) = .empty;
    defer unmappable_relations.deinit(allocator);

    var mapped_input_nodes: usize = 0;
    var entity_evidence_line_matches: usize = 0;
    for (graph.nodes.items, 0..) |node, index| {
        const mapped = findGoldEntityZgraphy(gold, &node);
        node_mappings[index] = mapped;
        if (mapped) |entity_index| {
            mapped_input_nodes += 1;
            entity_seen[entity_index] = true;
            if (evidenceLineMatches(gold, gold.entities[entity_index].evidence, node.path, node.line)) {
                entity_evidence_line_matches += 1;
            }
        } else {
            try unmappable_nodes.append(allocator, node.label);
        }
    }

    for (gold.relations, 0..) |relation, index| {
        if (relation.kind != .contains) continue;
        const from = findEntityIndex(gold, relation.from) orelse continue;
        const to = findEntityIndex(gold, relation.to) orelse continue;
        if (gold.entities[from].kind != .repository or gold.entities[to].kind != .file) continue;
        if (!entity_seen[from] or !entity_seen[to]) continue;
        relation_seen[index] = true;
        try synthesized_relations.append(allocator, relation.id);
    }

    var mapped_input_relations: usize = 0;
    var relation_evidence_line_matches: usize = 0;
    var provenance_matches: usize = 0;
    var provenance_mismatches: usize = 0;
    for (graph.edges.items) |edge| {
        const from = mapZgraphyEndpoint(graph, node_mappings, edge.from) orelse {
            try unmappable_relations.append(allocator, @tagName(edge.relation));
            continue;
        };
        const to = mapZgraphyEndpoint(graph, node_mappings, edge.to) orelse {
            try unmappable_relations.append(allocator, @tagName(edge.relation));
            continue;
        };
        const kind = canonicalZgraphyRelation(edge.relation) orelse {
            try unmappable_relations.append(allocator, @tagName(edge.relation));
            continue;
        };
        const expected_index = findExpectedRelation(gold, relation_seen, kind, gold.entities[from].id, gold.entities[to].id) orelse {
            try unmappable_relations.append(allocator, @tagName(edge.relation));
            continue;
        };
        relation_seen[expected_index] = true;
        mapped_input_relations += 1;
        const expected = &gold.relations[expected_index];
        if (evidenceLineMatches(gold, expected.evidence, edge.source_path, edge.line)) {
            relation_evidence_line_matches += 1;
        }
        const provenance = canonicalZgraphyProvenance(edge.provenance);
        if (provenance == expected.provenance) provenance_matches += 1 else provenance_mismatches += 1;
    }

    for (gold.facts, 0..) |fact, index| {
        if (supportsZgraphyFact(graph, node_mappings, gold, &fact)) fact_seen[index] = true;
    }

    var missing_entities: std.ArrayList([]const u8) = .empty;
    defer missing_entities.deinit(allocator);
    var missing_relations: std.ArrayList([]const u8) = .empty;
    defer missing_relations.deinit(allocator);
    var missing_facts: std.ArrayList([]const u8) = .empty;
    defer missing_facts.deinit(allocator);
    var missing_hyperedges: std.ArrayList([]const u8) = .empty;
    defer missing_hyperedges.deinit(allocator);
    var missing_supernodes: std.ArrayList([]const u8) = .empty;
    defer missing_supernodes.deinit(allocator);

    for (gold.entities, entity_seen) |entity, seen| if (!seen) try missing_entities.append(allocator, entity.id);
    for (gold.relations, relation_seen) |relation, seen| if (!seen) try missing_relations.append(allocator, relation.id);
    for (gold.facts, fact_seen) |fact, seen| if (!seen) try missing_facts.append(allocator, fact.id);
    for (gold.hyperedges) |hyperedge| try missing_hyperedges.append(allocator, hyperedge.id);
    for (gold.supernodes) |supernode| try missing_supernodes.append(allocator, supernode.id);

    const projected_unique_entities = countTrue(entity_seen);
    const matched_entities = projected_unique_entities;
    const matched_relations = countTrue(relation_seen);
    const matched_facts = countTrue(fact_seen);
    const unexpected_nodes = graph.nodes.items.len - mapped_input_nodes;
    const unexpected_relations = graph.edges.items.len - mapped_input_relations;

    const missing_entity_ids = try missing_entities.toOwnedSlice(allocator);
    errdefer allocator.free(missing_entity_ids);
    const missing_relation_ids = try missing_relations.toOwnedSlice(allocator);
    errdefer allocator.free(missing_relation_ids);
    const missing_fact_ids = try missing_facts.toOwnedSlice(allocator);
    errdefer allocator.free(missing_fact_ids);
    const missing_hyperedge_ids = try missing_hyperedges.toOwnedSlice(allocator);
    errdefer allocator.free(missing_hyperedge_ids);
    const missing_supernode_ids = try missing_supernodes.toOwnedSlice(allocator);
    errdefer allocator.free(missing_supernode_ids);
    const synthesized_entity_ids = try synthesized_entities.toOwnedSlice(allocator);
    errdefer allocator.free(synthesized_entity_ids);
    const synthesized_relation_ids = try synthesized_relations.toOwnedSlice(allocator);
    errdefer allocator.free(synthesized_relation_ids);
    const unmappable_node_labels = try unmappable_nodes.toOwnedSlice(allocator);
    errdefer allocator.free(unmappable_node_labels);
    const unmappable_relation_kinds = try unmappable_relations.toOwnedSlice(allocator);
    errdefer allocator.free(unmappable_relation_kinds);

    return .{
        .fixture_id = gold.fixture_id,
        .adapter = .{
            .engine = "zgraphy",
            .version = zgraphy_version,
            .commit = "working-tree",
            .adapter_version = zgraphy_adapter_version,
            .input_schema = "zgraphy.repository-graph.v1",
            .output_schema = benchmark.canonical_ir_schema,
        },
        .input = .{
            .nodes = graph.nodes.items.len,
            .relations = graph.edges.items.len,
            .hyperedges = 0,
            .input_tokens = 0,
            .output_tokens = 0,
        },
        .projection = .{
            .mapped_input_nodes = mapped_input_nodes,
            .projected_unique_entities = projected_unique_entities,
            .mapped_input_relations = mapped_input_relations,
            .entity_evidence_line_matches = entity_evidence_line_matches,
            .relation_evidence_line_matches = relation_evidence_line_matches,
            .provenance_matches = provenance_matches,
            .provenance_mismatches = provenance_mismatches,
        },
        .entities = score(gold.entities.len, matched_entities, unexpected_nodes),
        .relations = score(gold.relations.len, matched_relations, unexpected_relations),
        .facts = score(gold.facts.len, matched_facts, 0),
        .hyperedges = score(gold.hyperedges.len, 0, 0),
        .supernodes = score(gold.supernodes.len, 0, 0),
        .missing_entity_ids = missing_entity_ids,
        .missing_relation_ids = missing_relation_ids,
        .missing_fact_ids = missing_fact_ids,
        .missing_hyperedge_ids = missing_hyperedge_ids,
        .missing_supernode_ids = missing_supernode_ids,
        .synthesized_entity_ids = synthesized_entity_ids,
        .synthesized_relation_ids = synthesized_relation_ids,
        .unmappable_node_labels = unmappable_node_labels,
        .unmappable_relation_kinds = unmappable_relation_kinds,
    };
}

pub fn projectLexical(
    allocator: std.mem.Allocator,
    graph: *const lexical.Graph,
    gold: *const benchmark.CanonicalIr,
) !Receipt {
    if (graph.nodes.items.len == 0) return error.EmptyLexicalGraph;
    try benchmark.validateGold(gold, gold.fixture_id);

    const entity_seen = try owned.slice(bool, allocator, gold.entities.len);
    defer allocator.free(entity_seen);
    @memset(entity_seen, false);
    const relation_seen = try owned.slice(bool, allocator, gold.relations.len);
    defer allocator.free(relation_seen);
    @memset(relation_seen, false);

    var unmappable_nodes: std.ArrayList([]const u8) = .empty;
    defer unmappable_nodes.deinit(allocator);
    var mapped_input_nodes: usize = 0;
    var entity_evidence_line_matches: usize = 0;
    for (graph.nodes.items) |node| {
        const mapped = findGoldEntityLexical(gold, &node);
        if (mapped) |entity_index| {
            mapped_input_nodes += 1;
            entity_seen[entity_index] = true;
            if (evidenceLineMatches(gold, gold.entities[entity_index].evidence, node.path, node.line)) {
                entity_evidence_line_matches += 1;
            }
        } else {
            try unmappable_nodes.append(allocator, node.label);
        }
    }

    var synthesized_relations: std.ArrayList([]const u8) = .empty;
    defer synthesized_relations.deinit(allocator);
    for (gold.relations, 0..) |relation, index| {
        if (relation.kind != .contains) continue;
        const from = findEntityIndex(gold, relation.from) orelse continue;
        const to = findEntityIndex(gold, relation.to) orelse continue;
        if (gold.entities[from].kind != .repository or gold.entities[to].kind != .file) continue;
        if (!entity_seen[from] or !entity_seen[to]) continue;
        relation_seen[index] = true;
        try synthesized_relations.append(allocator, relation.id);
    }

    var missing_entities: std.ArrayList([]const u8) = .empty;
    defer missing_entities.deinit(allocator);
    var missing_relations: std.ArrayList([]const u8) = .empty;
    defer missing_relations.deinit(allocator);
    var missing_facts: std.ArrayList([]const u8) = .empty;
    defer missing_facts.deinit(allocator);
    var missing_hyperedges: std.ArrayList([]const u8) = .empty;
    defer missing_hyperedges.deinit(allocator);
    var missing_supernodes: std.ArrayList([]const u8) = .empty;
    defer missing_supernodes.deinit(allocator);
    for (gold.entities, entity_seen) |entity, seen| if (!seen) try missing_entities.append(allocator, entity.id);
    for (gold.relations, relation_seen) |relation, seen| if (!seen) try missing_relations.append(allocator, relation.id);
    for (gold.facts) |fact| try missing_facts.append(allocator, fact.id);
    for (gold.hyperedges) |hyperedge| try missing_hyperedges.append(allocator, hyperedge.id);
    for (gold.supernodes) |supernode| try missing_supernodes.append(allocator, supernode.id);

    const matched_entities = countTrue(entity_seen);
    const matched_relations = countTrue(relation_seen);
    const unexpected_nodes = graph.nodes.items.len - mapped_input_nodes;

    const missing_entity_ids = try missing_entities.toOwnedSlice(allocator);
    errdefer allocator.free(missing_entity_ids);
    const missing_relation_ids = try missing_relations.toOwnedSlice(allocator);
    errdefer allocator.free(missing_relation_ids);
    const missing_fact_ids = try missing_facts.toOwnedSlice(allocator);
    errdefer allocator.free(missing_fact_ids);
    const missing_hyperedge_ids = try missing_hyperedges.toOwnedSlice(allocator);
    errdefer allocator.free(missing_hyperedge_ids);
    const missing_supernode_ids = try missing_supernodes.toOwnedSlice(allocator);
    errdefer allocator.free(missing_supernode_ids);
    const synthesized_relation_ids = try synthesized_relations.toOwnedSlice(allocator);
    errdefer allocator.free(synthesized_relation_ids);
    const unmappable_node_labels = try unmappable_nodes.toOwnedSlice(allocator);
    errdefer allocator.free(unmappable_node_labels);
    const synthesized_entity_ids = try owned.slice([]const u8, allocator, 0);
    errdefer allocator.free(synthesized_entity_ids);
    const unmappable_relation_kinds = try owned.slice([]const u8, allocator, 0);
    errdefer allocator.free(unmappable_relation_kinds);

    return .{
        .fixture_id = gold.fixture_id,
        .adapter = .{
            .engine = "lexical",
            .version = "1",
            .commit = "builtin",
            .adapter_version = lexical_adapter_version,
            .input_schema = "zgraphy.lexical-graph.v1",
            .output_schema = benchmark.canonical_ir_schema,
        },
        .input = .{
            .nodes = graph.nodes.items.len,
            .relations = 0,
            .hyperedges = 0,
            .input_tokens = 0,
            .output_tokens = 0,
        },
        .projection = .{
            .mapped_input_nodes = mapped_input_nodes,
            .projected_unique_entities = matched_entities,
            .mapped_input_relations = 0,
            .entity_evidence_line_matches = entity_evidence_line_matches,
            .relation_evidence_line_matches = 0,
            .provenance_matches = 0,
            .provenance_mismatches = 0,
        },
        .entities = score(gold.entities.len, matched_entities, unexpected_nodes),
        .relations = score(gold.relations.len, matched_relations, 0),
        .facts = score(gold.facts.len, 0, 0),
        .hyperedges = score(gold.hyperedges.len, 0, 0),
        .supernodes = score(gold.supernodes.len, 0, 0),
        .missing_entity_ids = missing_entity_ids,
        .missing_relation_ids = missing_relation_ids,
        .missing_fact_ids = missing_fact_ids,
        .missing_hyperedge_ids = missing_hyperedge_ids,
        .missing_supernode_ids = missing_supernode_ids,
        .synthesized_entity_ids = synthesized_entity_ids,
        .synthesized_relation_ids = synthesized_relation_ids,
        .unmappable_node_labels = unmappable_node_labels,
        .unmappable_relation_kinds = unmappable_relation_kinds,
    };
}

pub fn validateReceipt(receipt: *const Receipt) !void {
    if (!std.mem.eql(u8, receipt.schema, schema) or receipt.schema_version != schema_version) return error.IncompatibleDifferentialReceipt;
    const graphify_adapter = std.mem.eql(u8, receipt.adapter.engine, "Graphify") and
        std.mem.eql(u8, receipt.adapter.version, parity.pinned_graphify_version) and
        std.mem.eql(u8, receipt.adapter.commit, parity.pinned_graphify_commit) and
        std.mem.eql(u8, receipt.adapter.adapter_version, adapter_version) and
        std.mem.eql(u8, receipt.adapter.input_schema, "graphify.graph-json.v1");
    const zgraphy_adapter = std.mem.eql(u8, receipt.adapter.engine, "zgraphy") and
        std.mem.eql(u8, receipt.adapter.version, zgraphy_version) and
        std.mem.eql(u8, receipt.adapter.commit, "working-tree") and
        std.mem.eql(u8, receipt.adapter.adapter_version, zgraphy_adapter_version) and
        std.mem.eql(u8, receipt.adapter.input_schema, "zgraphy.repository-graph.v1");
    const lexical_adapter = std.mem.eql(u8, receipt.adapter.engine, "lexical") and
        std.mem.eql(u8, receipt.adapter.version, "1") and
        std.mem.eql(u8, receipt.adapter.commit, "builtin") and
        std.mem.eql(u8, receipt.adapter.adapter_version, lexical_adapter_version) and
        std.mem.eql(u8, receipt.adapter.input_schema, "zgraphy.lexical-graph.v1");
    if ((!graphify_adapter and !zgraphy_adapter and !lexical_adapter) or
        !std.mem.eql(u8, receipt.adapter.output_schema, benchmark.canonical_ir_schema))
    {
        return error.InvalidDifferentialAdapter;
    }
    if (receipt.fixture_id.len == 0 or receipt.input.nodes == 0) return error.InvalidDifferentialReceipt;
    try validateScore(&receipt.entities);
    try validateScore(&receipt.relations);
    try validateScore(&receipt.facts);
    try validateScore(&receipt.hyperedges);
    try validateScore(&receipt.supernodes);
    if (receipt.entities.missing != receipt.missing_entity_ids.len or
        receipt.relations.missing != receipt.missing_relation_ids.len or
        receipt.facts.missing != receipt.missing_fact_ids.len or
        receipt.hyperedges.missing != receipt.missing_hyperedge_ids.len or
        receipt.supernodes.missing != receipt.missing_supernode_ids.len or
        receipt.entities.unexpected != receipt.unmappable_node_labels.len or
        receipt.relations.unexpected != receipt.unmappable_relation_kinds.len)
    {
        return error.InconsistentDifferentialReceipt;
    }
    if (receipt.input.nodes != receipt.projection.mapped_input_nodes + receipt.entities.unexpected or
        receipt.input.relations != receipt.projection.mapped_input_relations + receipt.relations.unexpected or
        receipt.entities.matched != receipt.projection.projected_unique_entities + receipt.synthesized_entity_ids.len or
        receipt.relations.matched != receipt.projection.mapped_input_relations + receipt.synthesized_relation_ids.len)
    {
        return error.InconsistentDifferentialReceipt;
    }
}

pub fn containsId(ids: []const []const u8, wanted: []const u8) bool {
    for (ids) |id| if (std.mem.eql(u8, id, wanted)) return true;
    return false;
}

fn findGoldEntity(gold: *const benchmark.CanonicalIr, node: *const GraphifyNode) ?usize {
    const source_name = std.fs.path.basename(node.source_file);
    if (isFileNode(node)) {
        for (gold.entities, 0..) |entity, index| {
            if (entity.kind == .file and std.mem.eql(u8, std.fs.path.basename(entity.name), source_name)) return index;
        }
        return null;
    }
    const label = symbolLeaf(node.label);
    for (gold.entities, 0..) |entity, index| {
        if (entity.kind == .repository or entity.kind == .file) continue;
        if (!std.mem.eql(u8, symbolLeaf(entity.name), label)) continue;
        if (entitySourceMatches(gold, &entity, source_name)) return index;
    }
    return null;
}

fn findGoldEntityZgraphy(gold: *const benchmark.CanonicalIr, node: *const model.Node) ?usize {
    if (node.kind == .repository) {
        for (gold.entities, 0..) |entity, index| if (entity.kind == .repository) return index;
        return null;
    }
    if (node.kind == .file) {
        for (gold.entities, 0..) |entity, index| {
            if (entity.kind == .file and sourcePathEquivalent(entity.name, node.path)) return index;
        }
        return null;
    }
    if (node.kind != .symbol and node.kind != .concept) return null;
    for (gold.entities, 0..) |entity, index| {
        if (entity.kind == .repository or entity.kind == .file) continue;
        if (!std.mem.eql(u8, symbolLeaf(entity.name), symbolLeaf(node.label))) continue;
        if (entitySourcePathMatches(gold, &entity, node.path)) return index;
    }
    return null;
}

fn findGoldEntityLexical(gold: *const benchmark.CanonicalIr, node: *const lexical.Node) ?usize {
    if (node.kind == .repository) {
        for (gold.entities, 0..) |entity, index| if (entity.kind == .repository) return index;
        return null;
    }
    if (node.kind == .file) {
        for (gold.entities, 0..) |entity, index| {
            if (entity.kind == .file and sourcePathEquivalent(entity.name, node.path)) return index;
        }
        return null;
    }
    for (gold.entities, 0..) |entity, index| {
        if (entity.kind == .repository or entity.kind == .file) continue;
        if (!std.mem.eql(u8, symbolLeaf(entity.name), node.label)) continue;
        if (entitySourcePathMatches(gold, &entity, node.path)) return index;
    }
    return null;
}

fn mapEndpoint(
    graph: *const GraphifyGraph,
    node_mappings: []const ?usize,
    gold: *const benchmark.CanonicalIr,
    endpoint: []const u8,
) ?usize {
    for (graph.nodes, 0..) |node, index| {
        if (std.mem.eql(u8, node.id, endpoint)) return node_mappings[index];
    }
    if (std.mem.indexOfAny(u8, endpoint, "_/\\.") != null) return null;
    for (gold.entities, 0..) |entity, index| {
        if (entity.kind != .file) continue;
        const basename = std.fs.path.basename(entity.name);
        const extension = std.fs.path.extension(basename);
        const stem = basename[0 .. basename.len - extension.len];
        if (std.mem.eql(u8, stem, endpoint)) return index;
    }
    return null;
}

fn mapZgraphyEndpoint(
    graph: *const model.RepositoryGraph,
    node_mappings: []const ?usize,
    endpoint: u64,
) ?usize {
    for (graph.nodes.items, 0..) |node, index| {
        if (node.id == endpoint) return node_mappings[index];
    }
    return null;
}

fn findExpectedRelation(
    gold: *const benchmark.CanonicalIr,
    seen: []const bool,
    kind: benchmark.RelationKind,
    from: []const u8,
    to: []const u8,
) ?usize {
    for (gold.relations, 0..) |relation, index| {
        if (!seen[index] and relation.kind == kind and std.mem.eql(u8, relation.from, from) and std.mem.eql(u8, relation.to, to)) return index;
    }
    return null;
}

fn canonicalRelation(relation: []const u8) ?benchmark.RelationKind {
    if (std.mem.eql(u8, relation, "contains") or std.mem.eql(u8, relation, "method")) return .declares;
    if (std.mem.eql(u8, relation, "imports") or std.mem.eql(u8, relation, "imports_from")) return .imports;
    if (std.mem.eql(u8, relation, "calls") or std.mem.eql(u8, relation, "indirect_call")) return .calls;
    if (std.mem.eql(u8, relation, "references")) return .references;
    return null;
}

fn canonicalZgraphyRelation(relation: model.Relation) ?benchmark.RelationKind {
    return switch (relation) {
        .contains => .contains,
        .declares => .declares,
        .imports => .imports,
        .calls => .calls,
        .covers => .covers,
        .references => .references,
        .dispatches_to => .selects_candidate,
        else => null,
    };
}

fn supportsZgraphyFact(
    graph: *const model.RepositoryGraph,
    node_mappings: []const ?usize,
    gold: *const benchmark.CanonicalIr,
    fact: *const benchmark.Fact,
) bool {
    if (!std.mem.eql(u8, fact.predicate, "call_resolution") or !std.mem.eql(u8, fact.value, "ambiguous") or
        fact.provenance != .ambiguous or fact.alternatives.len < 2) return false;
    const subject_mapping = findEntityIndex(gold, fact.subject) orelse return false;
    for (graph.nodes.items, 0..) |subject, subject_index| {
        if (node_mappings[subject_index] == null or node_mappings[subject_index].? != subject_mapping) continue;
        var mapped_candidates: usize = 0;
        var all_expected = true;
        for (fact.alternatives) |alternative| {
            const alternative_mapping = findEntityIndex(gold, alternative) orelse return false;
            var found = false;
            for (graph.edges.items) |edge| {
                if (edge.from != subject.id or edge.relation != .dispatches_to or edge.provenance != .ambiguous) continue;
                const mapped = mapZgraphyEndpoint(graph, node_mappings, edge.to) orelse continue;
                if (mapped == alternative_mapping) found = true;
            }
            if (!found) {
                all_expected = false;
                break;
            }
        }
        if (!all_expected) continue;
        for (graph.edges.items) |edge| {
            if (edge.from != subject.id or edge.relation != .dispatches_to or edge.provenance != .ambiguous) continue;
            if (mapZgraphyEndpoint(graph, node_mappings, edge.to) != null) mapped_candidates += 1;
        }
        if (mapped_candidates == fact.alternatives.len) return true;
    }
    return false;
}

fn canonicalProvenance(confidence: []const u8) ?benchmark.Provenance {
    if (std.mem.eql(u8, confidence, "EXTRACTED")) return .extracted;
    if (std.mem.eql(u8, confidence, "INFERRED")) return .resolved;
    if (std.mem.eql(u8, confidence, "AMBIGUOUS")) return .ambiguous;
    return null;
}

fn canonicalZgraphyProvenance(provenance: model.Provenance) benchmark.Provenance {
    return switch (provenance) {
        .extracted => .extracted,
        .inferred => .resolved,
        .ambiguous => .ambiguous,
    };
}

fn entitySourceMatches(gold: *const benchmark.CanonicalIr, entity: *const benchmark.Entity, source_name: []const u8) bool {
    for (entity.evidence) |evidence_id| {
        const evidence = findEvidence(gold, evidence_id) orelse continue;
        if (std.mem.eql(u8, std.fs.path.basename(evidence.source.path), source_name)) return true;
    }
    return false;
}

fn entitySourcePathMatches(gold: *const benchmark.CanonicalIr, entity: *const benchmark.Entity, source_path: []const u8) bool {
    for (entity.evidence) |evidence_id| {
        const evidence = findEvidence(gold, evidence_id) orelse continue;
        if (sourcePathEquivalent(evidence.source.path, source_path)) return true;
    }
    return false;
}

fn sourcePathEquivalent(expected: []const u8, actual: []const u8) bool {
    if (std.mem.eql(u8, expected, actual)) return true;
    if (expected.len == 0 or actual.len == 0) return false;
    if (expected.len > actual.len and std.mem.endsWith(u8, expected, actual)) {
        return expected[expected.len - actual.len - 1] == '/';
    }
    if (actual.len > expected.len and std.mem.endsWith(u8, actual, expected)) {
        return actual[actual.len - expected.len - 1] == '/';
    }
    return false;
}

fn evidenceLineMatches(
    gold: *const benchmark.CanonicalIr,
    evidence_ids: []const []const u8,
    source_file: []const u8,
    line: ?u32,
) bool {
    const actual_line = line orelse return false;
    const source_name = std.fs.path.basename(source_file);
    for (evidence_ids) |evidence_id| {
        const evidence = findEvidence(gold, evidence_id) orelse continue;
        if (!std.mem.eql(u8, std.fs.path.basename(evidence.source.path), source_name)) continue;
        if (actual_line >= evidence.source.start_line and actual_line <= evidence.source.end_line) return true;
    }
    return false;
}

fn findEvidence(gold: *const benchmark.CanonicalIr, id: []const u8) ?*const benchmark.Evidence {
    for (gold.evidence, 0..) |evidence, index| if (std.mem.eql(u8, evidence.id, id)) return &gold.evidence[index];
    return null;
}

fn findEntityIndex(gold: *const benchmark.CanonicalIr, id: []const u8) ?usize {
    for (gold.entities, 0..) |entity, index| if (std.mem.eql(u8, entity.id, id)) return index;
    return null;
}

fn isFileNode(node: *const GraphifyNode) bool {
    return node.source_file.len > 0 and std.mem.eql(u8, std.fs.path.basename(node.label), std.fs.path.basename(node.source_file)) and std.fs.path.extension(node.label).len > 0;
}

fn symbolLeaf(value: []const u8) []const u8 {
    var result = value;
    while (result.len > 0 and result[0] == '.') result = result[1..];
    if (std.mem.endsWith(u8, result, "()")) result = result[0 .. result.len - 2];
    if (std.mem.lastIndexOfScalar(u8, result, '.')) |dot| result = result[dot + 1 ..];
    if (std.mem.lastIndexOfScalar(u8, result, '/')) |slash| result = result[slash + 1 ..];
    return result;
}

fn parseLine(location: []const u8) ?u32 {
    if (location.len < 2 or location[0] != 'L') return null;
    var end: usize = 1;
    while (end < location.len and std.ascii.isDigit(location[end])) : (end += 1) {}
    if (end == 1) return null;
    return std.fmt.parseInt(u32, location[1..end], 10) catch null;
}

fn countTrue(values: []const bool) usize {
    var count: usize = 0;
    for (values) |value| {
        if (value) count += 1;
    }
    return count;
}

pub fn scoreCounts(expected: usize, matched: usize, unexpected: usize) Score {
    const missing = expected - matched;
    const recall = ratio(matched, expected);
    const precision = ratio(matched, matched + unexpected);
    const f1 = if (recall + precision == 0) 0 else 2 * recall * precision / (recall + precision);
    return .{
        .expected = expected,
        .matched = matched,
        .missing = missing,
        .unexpected = unexpected,
        .recall = recall,
        .conservative_precision = precision,
        .f1 = f1,
    };
}

const score = scoreCounts;

fn ratio(numerator: usize, denominator: usize) f64 {
    if (denominator == 0) return 1;
    return @as(f64, @floatFromInt(numerator)) / @as(f64, @floatFromInt(denominator));
}

fn validateScore(value: *const Score) !void {
    if (value.expected != value.matched + value.missing or
        !std.math.isFinite(value.recall) or !std.math.isFinite(value.conservative_precision) or !std.math.isFinite(value.f1) or
        value.recall < 0 or value.recall > 1 or value.conservative_precision < 0 or value.conservative_precision > 1 or value.f1 < 0 or value.f1 > 1)
    {
        return error.InvalidDifferentialScore;
    }
}

fn undefinedReceipt() Receipt {
    return .{
        .fixture_id = "",
        .input = .{ .nodes = 0, .relations = 0, .hyperedges = 0, .input_tokens = 0, .output_tokens = 0 },
        .projection = .{
            .mapped_input_nodes = 0,
            .projected_unique_entities = 0,
            .mapped_input_relations = 0,
            .entity_evidence_line_matches = 0,
            .relation_evidence_line_matches = 0,
            .provenance_matches = 0,
            .provenance_mismatches = 0,
        },
        .entities = score(0, 0, 0),
        .relations = score(0, 0, 0),
        .facts = score(0, 0, 0),
        .hyperedges = score(0, 0, 0),
        .supernodes = score(0, 0, 0),
        .missing_entity_ids = &.{},
        .missing_relation_ids = &.{},
        .missing_fact_ids = &.{},
        .missing_hyperedge_ids = &.{},
        .missing_supernode_ids = &.{},
        .synthesized_entity_ids = &.{},
        .synthesized_relation_ids = &.{},
        .unmappable_node_labels = &.{},
        .unmappable_relation_kinds = &.{},
    };
}
