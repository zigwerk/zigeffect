const std = @import("std");
const nendb = @import("nendb.zig");
const owned = @import("memory.zig");

pub const NodeKind = enum(u8) {
    repository,
    directory,
    file,
    symbol,
    external_module,
    component,
    requirement,
    acceptance_check,
    command,
    test_scenario,
    causal_event,
    concept,
    workspace,
    package,
    application,
    library,
    build_target,
    api_surface,
    module_reference,
    type,
    service,
    operation,
    message,
    field,
};

pub const Relation = enum(u16) {
    contains,
    declares,
    imports,
    calls,
    depends_on,
    satisfies,
    verified_by,
    executes,
    covers,
    source_root,
    causal_parent,
    observed_at,
    references,
    owned_by,
    member_of,
    part_of_target,
    defines,
    dispatches_to,
    deferred_imports,
    resolves_to,
    imports_from,
    re_exports,
    aliases,
    instantiates,
    has_field,
    uses_request,
    uses_response,
    references_type,
    generated_from,
    generated_client_for,
    generated_server_for,
    invokes_operation,
    handles_operation,
    passes_callback,
};

pub const Provenance = enum(u8) {
    extracted,
    inferred,
    ambiguous,
};

pub const Options = struct {
    max_nodes: usize = 100_000,
    max_edges: usize = 500_000,
    max_hyperedges: usize = 100_000,
    max_hyperedge_participants: usize = 1_000_000,
    max_hyperedge_evidence: usize = 1_000_000,
    max_supernodes: usize = 100_000,
    max_supernode_members: usize = 1_000_000,
    max_supernode_evidence: usize = 1_000_000,
    max_supernode_proof_steps: usize = 1_000_000,
};

pub const Node = struct {
    id: u64,
    kind: NodeKind,
    label: []const u8,
    path: []const u8,
    line: u32,
    search_text: []const u8,
};

pub const Edge = struct {
    from: u64,
    to: u64,
    relation: Relation,
    provenance: Provenance = .extracted,
    source_path: []const u8 = "",
    line: u32 = 0,
};

pub const SourceSpan = struct {
    start_byte: usize,
    end_byte: usize,
    start_line: u32,
    start_column: u32,
    end_line: u32,
    end_column: u32,

    pub fn valid(self: SourceSpan) bool {
        return self.start_byte < self.end_byte and self.start_line > 0 and self.start_column > 0 and
            self.end_line >= self.start_line and self.end_column > 0 and
            (self.end_line != self.start_line or self.end_column >= self.start_column);
    }
};

pub const EvidenceRole = enum(u8) {
    frontend_invocation,
    client_binding,
    canonical_contract,
    request_schema,
    response_schema,
    implementation_container,
    backend_handler,
    ui_consumer,
    data_loader,
    focused_test,
};

pub const SourceEvidence = struct {
    role: EvidenceRole,
    source_path: []const u8,
    span: SourceSpan,
};

pub const HyperedgeKind = enum(u8) {
    request_path,
};

pub const ParticipantRole = enum(u8) {
    ui_consumer,
    frontend_callsite,
    client_binding,
    canonical_operation,
    request_message,
    response_message,
    implementation_container,
    backend_handler,
    data_loader,
    focused_test,
};

pub const Participant = struct {
    role: ParticipantRole,
    node_id: u64,
};

pub const HyperedgeInput = struct {
    id: ?u64 = null,
    kind: HyperedgeKind,
    canonical_name: []const u8,
    recipe: []const u8,
    interaction_fingerprint: [32]u8,
    participants: []const Participant,
    evidence: []const SourceEvidence,
};

pub const Hyperedge = struct {
    id: u64,
    kind: HyperedgeKind,
    canonical_name: []const u8,
    recipe: []const u8,
    interaction_fingerprint: [32]u8,
    participants: []Participant,
    evidence: []SourceEvidence,

    pub fn participant(self: *const Hyperedge, role: ParticipantRole) ?*const Participant {
        for (self.participants, 0..) |item, index| if (item.role == role) return &self.participants[index];
        return null;
    }
};

pub const SupernodeKind = enum(u8) {
    feature,
};

pub const SupernodeCompleteness = enum(u8) {
    contract_path,
    end_to_end_feature,
};

pub const SupernodeMember = struct {
    role: ParticipantRole,
    node_id: u64,
    reason: []const u8,
};

pub const ProofStep = struct {
    from: u64,
    to: u64,
    relation: Relation,
};

pub const SupernodeInput = struct {
    id: ?u64 = null,
    kind: SupernodeKind,
    canonical_name: []const u8,
    name: []const u8,
    recipe: []const u8,
    synopsis: []const u8,
    input_hyperedge_id: u64,
    completeness: SupernodeCompleteness,
    members: []const SupernodeMember,
    evidence: []const SourceEvidence,
    proof_steps: []const ProofStep,
};

pub const Supernode = struct {
    id: u64,
    kind: SupernodeKind,
    canonical_name: []const u8,
    name: []const u8,
    recipe: []const u8,
    synopsis: []const u8,
    input_hyperedge_id: u64,
    completeness: SupernodeCompleteness,
    members: []SupernodeMember,
    evidence: []SourceEvidence,
    proof_steps: []ProofStep,

    pub fn member(self: *const Supernode, role: ParticipantRole) ?*const SupernodeMember {
        for (self.members, 0..) |item, index| if (item.role == role) return &self.members[index];
        return null;
    }

    pub fn hasProofStep(self: *const Supernode, from: u64, to: u64, relation: Relation) bool {
        for (self.proof_steps) |step| if (step.from == from and step.to == to and step.relation == relation) return true;
        return false;
    }
};

pub const NodeInput = struct {
    id: ?u64 = null,
    kind: NodeKind,
    label: []const u8,
    path: []const u8 = "",
    line: u32 = 0,
    search_text: []const u8 = "",
};

pub const Path = struct {
    allocator: std.mem.Allocator,
    node_ids: []u64,
    complete: bool,
    exhausted: bool,

    pub fn deinit(self: *Path) void {
        self.allocator.free(self.node_ids);
    }
};

pub const RepositoryGraph = struct {
    allocator: std.mem.Allocator,
    options: Options,
    topology: nendb.GraphData,
    nodes: std.ArrayList(Node) = .empty,
    edges: std.ArrayList(Edge) = .empty,
    hyperedges: std.ArrayList(Hyperedge) = .empty,
    supernodes: std.ArrayList(Supernode) = .empty,
    hyperedge_participant_count: usize = 0,
    hyperedge_evidence_count: usize = 0,
    supernode_member_count: usize = 0,
    supernode_evidence_count: usize = 0,
    supernode_proof_step_count: usize = 0,

    pub fn init(allocator: std.mem.Allocator, options: Options) !RepositoryGraph {
        if (options.max_hyperedges == 0 or options.max_hyperedge_participants == 0 or options.max_hyperedge_evidence == 0 or
            options.max_supernodes == 0 or options.max_supernode_members == 0 or options.max_supernode_evidence == 0 or options.max_supernode_proof_steps == 0)
        {
            return error.InvalidSemanticCapacity;
        }
        return .{
            .allocator = allocator,
            .options = options,
            .topology = try nendb.GraphData.init(allocator, .{
                .max_nodes = options.max_nodes,
                .max_edges = options.max_edges,
            }),
        };
    }

    pub fn deinit(self: *RepositoryGraph) void {
        for (self.supernodes.items) |supernode| deinitSupernode(self.allocator, supernode);
        self.supernodes.deinit(self.allocator);
        for (self.hyperedges.items) |hyperedge| deinitHyperedge(self.allocator, hyperedge);
        self.hyperedges.deinit(self.allocator);
        for (self.edges.items) |edge| if (edge.source_path.len > 0) self.allocator.free(edge.source_path);
        self.edges.deinit(self.allocator);
        for (self.nodes.items) |node| {
            self.allocator.free(node.label);
            if (node.path.len > 0) self.allocator.free(node.path);
            if (node.search_text.len > 0) self.allocator.free(node.search_text);
        }
        self.nodes.deinit(self.allocator);
        self.topology.deinit();
    }

    pub fn addNode(self: *RepositoryGraph, input: NodeInput) !u64 {
        const id = input.id orelse stableId(input.kind, input.path, input.label);
        if (self.topology.findNodeIndex(id)) |index| {
            const existing = self.nodes.items[index];
            if (existing.kind != input.kind or !std.mem.eql(u8, existing.label, input.label) or !std.mem.eql(u8, existing.path, input.path)) {
                return error.NodeIdCollision;
            }
            return id;
        }
        const label = try owned.copy(u8, self.allocator, input.label);
        errdefer self.allocator.free(label);
        const path = if (input.path.len == 0) "" else try owned.copy(u8, self.allocator, input.path);
        errdefer if (path.len > 0) self.allocator.free(path);
        const search_text = if (input.search_text.len == 0) "" else try owned.copy(u8, self.allocator, input.search_text);
        errdefer if (search_text.len > 0) self.allocator.free(search_text);

        const embedding = nendb.embedPair(input.label, input.search_text);
        const index = try self.topology.addNode(id, @intFromEnum(input.kind), &embedding);
        errdefer self.rollbackNode(index);
        try self.nodes.append(self.allocator, .{
            .id = id,
            .kind = input.kind,
            .label = label,
            .path = path,
            .line = input.line,
            .search_text = search_text,
        });
        return id;
    }

    pub fn addSearchableNode(
        self: *RepositoryGraph,
        kind: NodeKind,
        label: []const u8,
        path: []const u8,
        line: u32,
        search_text: []const u8,
    ) !u64 {
        return self.addNode(.{
            .kind = kind,
            .label = label,
            .path = path,
            .line = line,
            .search_text = search_text,
        });
    }

    pub fn addEdge(self: *RepositoryGraph, input: Edge) !void {
        if (self.hasEdge(input.from, input.to, input.relation)) return;
        const source_path = if (input.source_path.len == 0) "" else try owned.copy(u8, self.allocator, input.source_path);
        errdefer if (source_path.len > 0) self.allocator.free(source_path);
        _ = try self.topology.addEdge(input.from, input.to, @intFromEnum(input.relation));
        errdefer self.topology.edge_count -= 1;
        try self.edges.append(self.allocator, .{
            .from = input.from,
            .to = input.to,
            .relation = input.relation,
            .provenance = input.provenance,
            .source_path = source_path,
            .line = input.line,
        });
    }

    pub fn nodeCount(self: *const RepositoryGraph) usize {
        return self.nodes.items.len;
    }

    pub fn edgeCount(self: *const RepositoryGraph) usize {
        return self.edges.items.len;
    }

    pub fn vectorCount(self: *const RepositoryGraph) usize {
        return self.topology.vector_count;
    }

    pub fn hyperedgeCount(self: *const RepositoryGraph) usize {
        return self.hyperedges.items.len;
    }

    pub fn supernodeCount(self: *const RepositoryGraph) usize {
        return self.supernodes.items.len;
    }

    pub fn nodeAt(self: *const RepositoryGraph, index: usize) *const Node {
        return &self.nodes.items[index];
    }

    pub fn vectorAt(self: *const RepositoryGraph, index: usize) []const f32 {
        return self.topology.vectorAt(@intCast(index));
    }

    pub fn findNode(self: *const RepositoryGraph, id: u64) ?*const Node {
        const index = self.topology.findNodeIndex(id) orelse return null;
        return &self.nodes.items[index];
    }

    pub fn findNodeByLabel(self: *const RepositoryGraph, label: []const u8) ?*const Node {
        for (self.nodes.items) |*node| if (std.ascii.eqlIgnoreCase(node.label, label)) return node;
        return null;
    }

    pub fn hasEdge(self: *const RepositoryGraph, from: u64, to: u64, relation: Relation) bool {
        for (self.edges.items) |edge| {
            if (edge.from == from and edge.to == to and edge.relation == relation) return true;
        }
        return false;
    }

    pub fn hasOutgoingRelation(self: *const RepositoryGraph, from: u64, relation: Relation) bool {
        for (self.edges.items) |edge| if (edge.from == from and edge.relation == relation) return true;
        return false;
    }

    pub fn addHyperedge(self: *RepositoryGraph, input: HyperedgeInput) !u64 {
        try validateHyperedgeInput(self, input);
        if (self.hyperedges.items.len >= self.options.max_hyperedges) return error.HyperedgeCapacityExceeded;
        const participant_total = std.math.add(usize, self.hyperedge_participant_count, input.participants.len) catch return error.HyperedgeParticipantCapacityExceeded;
        if (participant_total > self.options.max_hyperedge_participants) return error.HyperedgeParticipantCapacityExceeded;
        const evidence_total = std.math.add(usize, self.hyperedge_evidence_count, input.evidence.len) catch return error.HyperedgeEvidenceCapacityExceeded;
        if (evidence_total > self.options.max_hyperedge_evidence) return error.HyperedgeEvidenceCapacityExceeded;

        const canonical_name = try owned.copy(u8, self.allocator, input.canonical_name);
        errdefer self.allocator.free(canonical_name);
        const recipe = try owned.copy(u8, self.allocator, input.recipe);
        errdefer self.allocator.free(recipe);
        const participants = try owned.copy(Participant, self.allocator, input.participants);
        errdefer self.allocator.free(participants);
        std.mem.sort(Participant, participants, {}, lessThanParticipant);
        const evidence = try cloneEvidence(self.allocator, input.evidence);
        errdefer deinitEvidence(self.allocator, evidence);
        std.mem.sort(SourceEvidence, evidence, {}, lessThanEvidence);
        const computed_id = stableHyperedgeId(input.kind, canonical_name, recipe, input.interaction_fingerprint, participants);
        const id = input.id orelse computed_id;
        if (id == 0 or id != computed_id) return error.InvalidHyperedgeId;
        for (self.hyperedges.items) |existing| if (existing.id == id) return error.HyperedgeIdCollision;
        try self.hyperedges.append(self.allocator, .{
            .id = id,
            .kind = input.kind,
            .canonical_name = canonical_name,
            .recipe = recipe,
            .interaction_fingerprint = input.interaction_fingerprint,
            .participants = participants,
            .evidence = evidence,
        });
        self.hyperedge_participant_count = participant_total;
        self.hyperedge_evidence_count = evidence_total;
        return id;
    }

    pub fn addSupernode(self: *RepositoryGraph, input: SupernodeInput) !u64 {
        try validateSupernodeInput(self, input);
        if (self.supernodes.items.len >= self.options.max_supernodes) return error.SupernodeCapacityExceeded;
        const member_total = std.math.add(usize, self.supernode_member_count, input.members.len) catch return error.SupernodeMemberCapacityExceeded;
        if (member_total > self.options.max_supernode_members) return error.SupernodeMemberCapacityExceeded;
        const evidence_total = std.math.add(usize, self.supernode_evidence_count, input.evidence.len) catch return error.SupernodeEvidenceCapacityExceeded;
        if (evidence_total > self.options.max_supernode_evidence) return error.SupernodeEvidenceCapacityExceeded;
        const proof_total = std.math.add(usize, self.supernode_proof_step_count, input.proof_steps.len) catch return error.SupernodeProofCapacityExceeded;
        if (proof_total > self.options.max_supernode_proof_steps) return error.SupernodeProofCapacityExceeded;

        const canonical_name = try owned.copy(u8, self.allocator, input.canonical_name);
        errdefer self.allocator.free(canonical_name);
        const name = try owned.copy(u8, self.allocator, input.name);
        errdefer self.allocator.free(name);
        const recipe = try owned.copy(u8, self.allocator, input.recipe);
        errdefer self.allocator.free(recipe);
        const synopsis = try owned.copy(u8, self.allocator, input.synopsis);
        errdefer self.allocator.free(synopsis);
        const members = try cloneMembers(self.allocator, input.members);
        errdefer deinitMembers(self.allocator, members);
        std.mem.sort(SupernodeMember, members, {}, lessThanMember);
        const evidence = try cloneEvidence(self.allocator, input.evidence);
        errdefer deinitEvidence(self.allocator, evidence);
        std.mem.sort(SourceEvidence, evidence, {}, lessThanEvidence);
        const proof_steps = try owned.copy(ProofStep, self.allocator, input.proof_steps);
        errdefer self.allocator.free(proof_steps);
        std.mem.sort(ProofStep, proof_steps, {}, lessThanProofStep);
        const computed_id = stableSupernodeId(input.kind, canonical_name, recipe, input.input_hyperedge_id, members, proof_steps);
        const id = input.id orelse computed_id;
        if (id == 0 or id != computed_id) return error.InvalidSupernodeId;
        for (self.supernodes.items) |existing| if (existing.id == id) return error.SupernodeIdCollision;
        try self.supernodes.append(self.allocator, .{
            .id = id,
            .kind = input.kind,
            .canonical_name = canonical_name,
            .name = name,
            .recipe = recipe,
            .synopsis = synopsis,
            .input_hyperedge_id = input.input_hyperedge_id,
            .completeness = input.completeness,
            .members = members,
            .evidence = evidence,
            .proof_steps = proof_steps,
        });
        self.supernode_member_count = member_total;
        self.supernode_evidence_count = evidence_total;
        self.supernode_proof_step_count = proof_total;
        return id;
    }

    pub fn findHyperedge(self: *const RepositoryGraph, id: u64) ?*const Hyperedge {
        for (self.hyperedges.items, 0..) |item, index| if (item.id == id) return &self.hyperedges.items[index];
        return null;
    }

    pub fn findHyperedgeByCanonicalName(self: *const RepositoryGraph, kind: HyperedgeKind, canonical_name: []const u8) ?*const Hyperedge {
        for (self.hyperedges.items, 0..) |item, index| {
            if (item.kind == kind and std.mem.eql(u8, item.canonical_name, canonical_name)) return &self.hyperedges.items[index];
        }
        return null;
    }

    pub fn findHyperedgeByParticipant(self: *const RepositoryGraph, node_id: u64) ?*const Hyperedge {
        for (self.hyperedges.items, 0..) |item, index| {
            for (item.participants) |participant| if (participant.node_id == node_id) return &self.hyperedges.items[index];
        }
        return null;
    }

    pub fn findSupernodeByInputHyperedge(self: *const RepositoryGraph, hyperedge_id: u64) ?*const Supernode {
        for (self.supernodes.items, 0..) |item, index| if (item.input_hyperedge_id == hyperedge_id) return &self.supernodes.items[index];
        return null;
    }

    pub fn findSupernodeByMember(self: *const RepositoryGraph, node_id: u64) ?*const Supernode {
        for (self.supernodes.items, 0..) |item, index| {
            for (item.members) |member_item| if (member_item.node_id == node_id) return &self.supernodes.items[index];
        }
        return null;
    }

    pub fn validateSemanticRecords(self: *const RepositoryGraph) !void {
        for (self.hyperedges.items) |hyperedge| try validateHyperedgeInput(self, .{
            .id = hyperedge.id,
            .kind = hyperedge.kind,
            .canonical_name = hyperedge.canonical_name,
            .recipe = hyperedge.recipe,
            .interaction_fingerprint = hyperedge.interaction_fingerprint,
            .participants = hyperedge.participants,
            .evidence = hyperedge.evidence,
        });
        for (self.supernodes.items) |supernode| try validateSupernodeInput(self, .{
            .id = supernode.id,
            .kind = supernode.kind,
            .canonical_name = supernode.canonical_name,
            .name = supernode.name,
            .recipe = supernode.recipe,
            .synopsis = supernode.synopsis,
            .input_hyperedge_id = supernode.input_hyperedge_id,
            .completeness = supernode.completeness,
            .members = supernode.members,
            .evidence = supernode.evidence,
            .proof_steps = supernode.proof_steps,
        });
    }

    pub fn shortestPathAlloc(
        self: *const RepositoryGraph,
        allocator: std.mem.Allocator,
        from: u64,
        to: u64,
        max_hops: usize,
    ) !Path {
        if (self.findNode(from) == null or self.findNode(to) == null) return error.NodeNotFound;
        if (max_hops == 0) return error.InvalidHopLimit;
        if (from == to) return .{
            .allocator = allocator,
            .node_ids = try owned.copy(u64, allocator, &.{from}),
            .complete = true,
            .exhausted = false,
        };

        const Parent = struct { parent: u64, depth: usize };
        var parents = std.AutoHashMap(u64, Parent).init(allocator);
        defer parents.deinit();
        var queue: std.ArrayList(u64) = .empty;
        defer queue.deinit(allocator);
        try queue.append(allocator, from);
        try parents.put(from, .{ .parent = from, .depth = 0 });
        var cursor: usize = 0;
        var found = false;
        var exhausted = false;
        while (cursor < queue.items.len and !found) : (cursor += 1) {
            const current = queue.items[cursor];
            const depth = parents.get(current).?.depth;
            if (depth >= max_hops) {
                exhausted = true;
                continue;
            }
            for (self.edges.items) |edge| {
                const neighbor = if (edge.from == current) edge.to else if (edge.to == current) edge.from else continue;
                if (parents.contains(neighbor)) continue;
                try parents.put(neighbor, .{ .parent = current, .depth = depth + 1 });
                try queue.append(allocator, neighbor);
                if (neighbor == to) {
                    found = true;
                    break;
                }
            }
        }
        if (!found) return .{
            .allocator = allocator,
            .node_ids = try owned.slice(u64, allocator, 0),
            .complete = false,
            .exhausted = exhausted,
        };
        const depth = parents.get(to).?.depth;
        const ids = try owned.slice(u64, allocator, depth + 1);
        var current = to;
        var index = depth + 1;
        while (index > 0) {
            index -= 1;
            ids[index] = current;
            current = parents.get(current).?.parent;
        }
        return .{ .allocator = allocator, .node_ids = ids, .complete = true, .exhausted = false };
    }

    fn rollbackNode(self: *RepositoryGraph, index: u32) void {
        const id = self.topology.node_ids[index];
        _ = self.topology.id_index.remove(id);
        self.topology.node_active[index] = false;
        self.topology.node_count -= 1;
        self.topology.vector_count -= 1;
    }
};

fn validateHyperedgeInput(graph: *const RepositoryGraph, input: HyperedgeInput) !void {
    if (input.canonical_name.len == 0 or input.canonical_name.len > 1024 or input.recipe.len == 0 or input.recipe.len > 128 or
        input.participants.len < 2 or input.evidence.len == 0 or allZero(&input.interaction_fingerprint))
    {
        return error.InvalidHyperedge;
    }
    var roles = std.EnumSet(ParticipantRole).initEmpty();
    for (input.participants, 0..) |participant, index| {
        if (participant.node_id == 0 or graph.findNode(participant.node_id) == null or roles.contains(participant.role)) return error.InvalidHyperedgeParticipant;
        roles.insert(participant.role);
        for (input.participants[0..index]) |previous| if (previous.node_id == participant.node_id) return error.InvalidHyperedgeParticipant;
    }
    if (input.kind == .request_path) {
        inline for (.{
            ParticipantRole.frontend_callsite,
            ParticipantRole.client_binding,
            ParticipantRole.canonical_operation,
            ParticipantRole.request_message,
            ParticipantRole.response_message,
            ParticipantRole.implementation_container,
            ParticipantRole.backend_handler,
        }) |required| if (!roles.contains(required)) return error.IncompleteRequestPath;
    }
    for (input.evidence, 0..) |item, index| {
        if (!validRelativePath(item.source_path) or !item.span.valid()) return error.InvalidSemanticEvidence;
        for (input.evidence[0..index]) |previous| {
            if (previous.role == item.role and std.mem.eql(u8, previous.source_path, item.source_path) and
                previous.span.start_byte == item.span.start_byte and previous.span.end_byte == item.span.end_byte) return error.DuplicateSemanticEvidence;
        }
    }
    const participants = try owned.copy(Participant, graph.allocator, input.participants);
    defer graph.allocator.free(participants);
    std.mem.sort(Participant, participants, {}, lessThanParticipant);
    const expected_id = stableHyperedgeId(input.kind, input.canonical_name, input.recipe, input.interaction_fingerprint, participants);
    if (input.id) |id| if (id != expected_id) return error.InvalidHyperedgeId;
}

fn validateSupernodeInput(graph: *const RepositoryGraph, input: SupernodeInput) !void {
    if (input.canonical_name.len == 0 or input.canonical_name.len > 1024 or input.name.len == 0 or input.name.len > 1024 or
        input.recipe.len == 0 or input.recipe.len > 128 or input.synopsis.len == 0 or input.synopsis.len > 4096 or
        input.members.len < 2 or input.evidence.len == 0 or input.proof_steps.len == 0 or graph.findHyperedge(input.input_hyperedge_id) == null)
    {
        return error.InvalidSupernode;
    }
    var roles = std.EnumSet(ParticipantRole).initEmpty();
    for (input.members, 0..) |member, index| {
        if (member.node_id == 0 or graph.findNode(member.node_id) == null or roles.contains(member.role) or member.reason.len == 0 or member.reason.len > 1024) {
            return error.InvalidSupernodeMember;
        }
        roles.insert(member.role);
        for (input.members[0..index]) |previous| if (previous.node_id == member.node_id) return error.InvalidSupernodeMember;
    }
    inline for (.{ ParticipantRole.frontend_callsite, ParticipantRole.canonical_operation, ParticipantRole.backend_handler }) |required| {
        if (!roles.contains(required)) return error.IncompleteFeatureSupernode;
    }
    if (input.completeness == .end_to_end_feature) inline for (.{
        ParticipantRole.ui_consumer,
        ParticipantRole.data_loader,
        ParticipantRole.focused_test,
    }) |required| if (!roles.contains(required)) return error.IncompleteFeatureSupernode;
    for (input.evidence) |item| if (!validRelativePath(item.source_path) or !item.span.valid()) return error.InvalidSemanticEvidence;
    for (input.proof_steps, 0..) |step, index| {
        if (!graph.hasEdge(step.from, step.to, step.relation)) return error.InvalidSupernodeProof;
        for (input.proof_steps[0..index]) |previous| {
            if (previous.from == step.from and previous.to == step.to and previous.relation == step.relation) return error.DuplicateSupernodeProof;
        }
    }
    const members = try cloneMembers(graph.allocator, input.members);
    defer deinitMembers(graph.allocator, members);
    std.mem.sort(SupernodeMember, members, {}, lessThanMember);
    const proofs = try owned.copy(ProofStep, graph.allocator, input.proof_steps);
    defer graph.allocator.free(proofs);
    std.mem.sort(ProofStep, proofs, {}, lessThanProofStep);
    const expected_id = stableSupernodeId(input.kind, input.canonical_name, input.recipe, input.input_hyperedge_id, members, proofs);
    if (input.id) |id| if (id != expected_id) return error.InvalidSupernodeId;
}

fn cloneEvidence(allocator: std.mem.Allocator, input: []const SourceEvidence) ![]SourceEvidence {
    const result = try owned.slice(SourceEvidence, allocator, input.len);
    errdefer allocator.free(result);
    var initialized: usize = 0;
    errdefer for (result[0..initialized]) |item| allocator.free(item.source_path);
    for (input, 0..) |item, index| {
        result[index] = .{
            .role = item.role,
            .source_path = try owned.copy(u8, allocator, item.source_path),
            .span = item.span,
        };
        initialized += 1;
    }
    return result;
}

fn deinitEvidence(allocator: std.mem.Allocator, evidence: []SourceEvidence) void {
    for (evidence) |item| allocator.free(item.source_path);
    allocator.free(evidence);
}

fn cloneMembers(allocator: std.mem.Allocator, input: []const SupernodeMember) ![]SupernodeMember {
    const result = try owned.slice(SupernodeMember, allocator, input.len);
    errdefer allocator.free(result);
    var initialized: usize = 0;
    errdefer for (result[0..initialized]) |item| allocator.free(item.reason);
    for (input, 0..) |item, index| {
        result[index] = .{ .role = item.role, .node_id = item.node_id, .reason = try owned.copy(u8, allocator, item.reason) };
        initialized += 1;
    }
    return result;
}

fn deinitMembers(allocator: std.mem.Allocator, members: []SupernodeMember) void {
    for (members) |item| allocator.free(item.reason);
    allocator.free(members);
}

fn deinitHyperedge(allocator: std.mem.Allocator, item: Hyperedge) void {
    allocator.free(item.canonical_name);
    allocator.free(item.recipe);
    allocator.free(item.participants);
    deinitEvidence(allocator, item.evidence);
}

fn deinitSupernode(allocator: std.mem.Allocator, item: Supernode) void {
    allocator.free(item.canonical_name);
    allocator.free(item.name);
    allocator.free(item.recipe);
    allocator.free(item.synopsis);
    deinitMembers(allocator, item.members);
    deinitEvidence(allocator, item.evidence);
    allocator.free(item.proof_steps);
}

fn stableHyperedgeId(kind: HyperedgeKind, canonical_name: []const u8, recipe: []const u8, fingerprint: [32]u8, participants: []const Participant) u64 {
    var hash = std.hash.Wyhash.hash(0x6879706572656467, @tagName(kind));
    hash = std.hash.Wyhash.hash(hash, canonical_name);
    hash = std.hash.Wyhash.hash(hash, recipe);
    hash = std.hash.Wyhash.hash(hash, &fingerprint);
    for (participants) |participant| {
        hash = std.hash.Wyhash.hash(hash, @tagName(participant.role));
        var bytes: [8]u8 = @splat(0);
        std.mem.writeInt(u64, &bytes, participant.node_id, .little);
        hash = std.hash.Wyhash.hash(hash, &bytes);
    }
    return if (hash == 0) 1 else hash;
}

fn stableSupernodeId(kind: SupernodeKind, canonical_name: []const u8, recipe: []const u8, hyperedge_id: u64, members: []const SupernodeMember, proofs: []const ProofStep) u64 {
    var hash = std.hash.Wyhash.hash(0x73757065726e6f64, @tagName(kind));
    hash = std.hash.Wyhash.hash(hash, canonical_name);
    hash = std.hash.Wyhash.hash(hash, recipe);
    var id_bytes: [8]u8 = @splat(0);
    std.mem.writeInt(u64, &id_bytes, hyperedge_id, .little);
    hash = std.hash.Wyhash.hash(hash, &id_bytes);
    for (members) |member| {
        hash = std.hash.Wyhash.hash(hash, @tagName(member.role));
        std.mem.writeInt(u64, &id_bytes, member.node_id, .little);
        hash = std.hash.Wyhash.hash(hash, &id_bytes);
    }
    for (proofs) |proof| {
        std.mem.writeInt(u64, &id_bytes, proof.from, .little);
        hash = std.hash.Wyhash.hash(hash, &id_bytes);
        std.mem.writeInt(u64, &id_bytes, proof.to, .little);
        hash = std.hash.Wyhash.hash(hash, &id_bytes);
        hash = std.hash.Wyhash.hash(hash, @tagName(proof.relation));
    }
    return if (hash == 0) 1 else hash;
}

fn lessThanParticipant(_: void, left: Participant, right: Participant) bool {
    if (left.role != right.role) return @intFromEnum(left.role) < @intFromEnum(right.role);
    return left.node_id < right.node_id;
}

fn lessThanEvidence(_: void, left: SourceEvidence, right: SourceEvidence) bool {
    if (left.role != right.role) return @intFromEnum(left.role) < @intFromEnum(right.role);
    const path_order = std.mem.order(u8, left.source_path, right.source_path);
    if (path_order != .eq) return path_order == .lt;
    if (left.span.start_byte != right.span.start_byte) return left.span.start_byte < right.span.start_byte;
    return left.span.end_byte < right.span.end_byte;
}

fn lessThanMember(_: void, left: SupernodeMember, right: SupernodeMember) bool {
    if (left.role != right.role) return @intFromEnum(left.role) < @intFromEnum(right.role);
    return left.node_id < right.node_id;
}

fn lessThanProofStep(_: void, left: ProofStep, right: ProofStep) bool {
    if (left.from != right.from) return left.from < right.from;
    if (left.to != right.to) return left.to < right.to;
    return @intFromEnum(left.relation) < @intFromEnum(right.relation);
}

fn validRelativePath(path: []const u8) bool {
    if (path.len == 0 or path.len > std.fs.max_path_bytes or std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, '\\') != null) return false;
    var components = std.mem.splitScalar(u8, path, '/');
    while (components.next()) |component| if (component.len == 0 or std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..")) return false;
    return true;
}

fn allZero(bytes: []const u8) bool {
    for (bytes) |byte| if (byte != 0) return false;
    return true;
}

pub fn stableId(kind: NodeKind, scope: []const u8, name: []const u8) u64 {
    var hash = std.hash.Wyhash.hash(0x7a67726170687931, @tagName(kind));
    hash = std.hash.Wyhash.hash(hash, scope);
    hash = std.hash.Wyhash.hash(hash, name);
    return if (hash == 0) 1 else hash;
}
