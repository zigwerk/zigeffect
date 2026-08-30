const std = @import("std");
const extraction_cache = @import("extraction_cache.zig");
const model = @import("model.zig");

pub const registry_schema = "zgraphy.semantic-recipe-registry.v1";
pub const registry_schema_version: u32 = 1;

pub const RecipeId = enum(u8) {
    rpc_request_path_v2,
    end_to_end_feature_v2,
};

pub const OutputClass = enum(u8) {
    hyperedge,
    supernode,
};

pub const ProofPolicy = enum(u8) {
    none,
    all_steps_are_live_edges,
};

pub const SynopsisPolicy = enum(u8) {
    absent,
    deterministic_template,
};

pub const Definition = struct {
    id: RecipeId,
    name: []const u8,
    version: u32,
    output_class: OutputClass,
    hyperedge_kind: ?model.HyperedgeKind = null,
    supernode_kind: ?model.SupernodeKind = null,
    upstream: ?RecipeId = null,
    required_roles: []const model.ParticipantRole,
    optional_roles: []const model.ParticipantRole,
    required_evidence: []const model.EvidenceRole,
    optional_evidence: []const model.EvidenceRole,
    allowed_completeness: []const model.SupernodeCompleteness,
    complete_roles: []const model.ParticipantRole,
    proof_policy: ProofPolicy,
    synopsis_policy: SynopsisPolicy,
};

const request_required_roles = [_]model.ParticipantRole{
    .frontend_callsite,
    .client_binding,
    .canonical_operation,
    .request_message,
    .response_message,
    .implementation_container,
    .backend_handler,
};

const request_optional_roles = [_]model.ParticipantRole{
    .ui_consumer,
    .data_loader,
    .focused_test,
};

const request_required_evidence = [_]model.EvidenceRole{
    .frontend_invocation,
    .client_binding,
    .canonical_contract,
    .request_schema,
    .response_schema,
    .implementation_container,
    .backend_handler,
};

const request_optional_evidence = [_]model.EvidenceRole{
    .ui_consumer,
    .data_loader,
    .focused_test,
};

const feature_completeness = [_]model.SupernodeCompleteness{
    .contract_path,
    .end_to_end_feature,
};

const complete_feature_roles = [_]model.ParticipantRole{
    .ui_consumer,
    .data_loader,
    .focused_test,
};

pub const definitions = [_]Definition{
    .{
        .id = .rpc_request_path_v2,
        .name = "rpc-request-path-v2",
        .version = 2,
        .output_class = .hyperedge,
        .hyperedge_kind = .request_path,
        .required_roles = &request_required_roles,
        .optional_roles = &request_optional_roles,
        .required_evidence = &request_required_evidence,
        .optional_evidence = &request_optional_evidence,
        .allowed_completeness = &.{},
        .complete_roles = &.{},
        .proof_policy = .none,
        .synopsis_policy = .absent,
    },
    .{
        .id = .end_to_end_feature_v2,
        .name = "end-to-end-feature-v2",
        .version = 2,
        .output_class = .supernode,
        .supernode_kind = .feature,
        .upstream = .rpc_request_path_v2,
        .required_roles = &request_required_roles,
        .optional_roles = &request_optional_roles,
        .required_evidence = &request_required_evidence,
        .optional_evidence = &request_optional_evidence,
        .allowed_completeness = &feature_completeness,
        .complete_roles = &complete_feature_roles,
        .proof_policy = .all_steps_are_live_edges,
        .synopsis_policy = .deterministic_template,
    },
};

pub fn findById(id: RecipeId) *const Definition {
    return switch (id) {
        .rpc_request_path_v2 => &definitions[0],
        .end_to_end_feature_v2 => &definitions[1],
    };
}

pub fn findByName(name: []const u8) ?*const Definition {
    for (&definitions) |*definition| {
        if (std.mem.eql(u8, definition.name, name)) return definition;
    }
    return null;
}

pub fn validateRegistry() !void {
    if (definitions.len != std.meta.fields(RecipeId).len) return error.IncompleteSemanticRecipeRegistry;
    for (definitions, 0..) |definition, index| {
        if (@intFromEnum(definition.id) != index or definition.name.len == 0 or definition.name.len > 128 or definition.version == 0) {
            return error.InvalidSemanticRecipeDefinition;
        }
        const version_marker = std.mem.lastIndexOf(u8, definition.name, "-v") orelse return error.InvalidSemanticRecipeDefinition;
        const parsed_version = std.fmt.parseInt(u32, definition.name[version_marker + 2 ..], 10) catch return error.InvalidSemanticRecipeDefinition;
        if (parsed_version != definition.version) return error.InvalidSemanticRecipeDefinition;
        for (definitions[0..index]) |previous| {
            if (previous.id == definition.id or std.mem.eql(u8, previous.name, definition.name)) return error.DuplicateSemanticRecipe;
        }
        if (definition.upstream) |upstream| {
            var dependency_precedes = false;
            for (definitions[0..index]) |previous| {
                if (previous.id == upstream) {
                    dependency_precedes = true;
                    break;
                }
            }
            if (!dependency_precedes) return error.InvalidSemanticRecipeDependency;
        }
        try validateDefinitionShape(definition);
        try validateRoleSet(definition.required_roles, definition.optional_roles);
        try validateEvidenceSet(definition.required_evidence, definition.optional_evidence);
        try validateUniqueCompleteness(definition.allowed_completeness);
        try validateUniqueRoles(definition.complete_roles);
        for (definition.complete_roles) |role| if (!containsRole(definition.optional_roles, role)) return error.InvalidSemanticRecipeDefinition;
    }
}

pub fn fingerprint() [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateString(&hasher, registry_schema);
    updateInt(&hasher, registry_schema_version);
    for (definitions) |definition| {
        updateString(&hasher, @tagName(definition.id));
        updateString(&hasher, definition.name);
        updateInt(&hasher, definition.version);
        updateString(&hasher, @tagName(definition.output_class));
        updateString(&hasher, if (definition.hyperedge_kind) |kind| @tagName(kind) else "");
        updateString(&hasher, if (definition.supernode_kind) |kind| @tagName(kind) else "");
        updateString(&hasher, if (definition.upstream) |upstream| findById(upstream).name else "");
        updateRoles(&hasher, definition.required_roles);
        updateRoles(&hasher, definition.optional_roles);
        updateEvidenceRoles(&hasher, definition.required_evidence);
        updateEvidenceRoles(&hasher, definition.optional_evidence);
        updateCompleteness(&hasher, definition.allowed_completeness);
        updateRoles(&hasher, definition.complete_roles);
        updateString(&hasher, @tagName(definition.proof_policy));
        updateString(&hasher, @tagName(definition.synopsis_policy));
    }
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    return digest;
}

pub fn validateGraph(graph: *const model.RepositoryGraph) !void {
    try validateRegistry();
    for (graph.hyperedges.items) |hyperedge| {
        const definition = findByName(hyperedge.recipe) orelse return error.UnsupportedSemanticRecipe;
        if (definition.output_class != .hyperedge or definition.hyperedge_kind == null or definition.hyperedge_kind.? != hyperedge.kind) {
            return error.SemanticRecipeOutputMismatch;
        }
        try validateParticipants(definition, hyperedge.participants);
        try validateEvidence(definition, hyperedge.evidence);
    }
    for (graph.supernodes.items) |supernode| {
        const definition = findByName(supernode.recipe) orelse return error.UnsupportedSemanticRecipe;
        if (definition.output_class != .supernode or definition.supernode_kind == null or definition.supernode_kind.? != supernode.kind) {
            return error.SemanticRecipeOutputMismatch;
        }
        const upstream_id = definition.upstream orelse return error.InvalidSemanticRecipeDependency;
        const input = graph.findHyperedge(supernode.input_hyperedge_id) orelse return error.InvalidSemanticRecipeDependency;
        if (!std.mem.eql(u8, input.recipe, findById(upstream_id).name)) return error.InvalidSemanticRecipeDependency;
        try validateMembers(definition, supernode.members, supernode.completeness);
        try validateEvidence(definition, supernode.evidence);
        if (definition.synopsis_policy == .deterministic_template and supernode.synopsis.len == 0) return error.InvalidSemanticRecipeSynopsis;
        if (definition.proof_policy == .all_steps_are_live_edges and !proofStepsLive(graph, supernode.proof_steps)) {
            return error.InvalidSemanticRecipeProof;
        }
    }
}

pub const RequestPathInput = struct {
    canonical_name: []const u8,
    interaction_fingerprint: [32]u8,
    participants: []const model.Participant,
    evidence: []const model.SourceEvidence,
    feature_name: []const u8,
    feature_synopsis: []const u8,
    completeness: model.SupernodeCompleteness,
    members: []const model.SupernodeMember,
    proof_steps: []const model.ProofStep,
};

pub const MaterializationResult = struct {
    hyperedge_id: u64,
    supernode_id: u64,
    hyperedge_reused: bool,
    supernode_reused: bool,
};

pub fn materializeRequestPath(
    graph: *model.RepositoryGraph,
    previous_graph: ?*const model.RepositoryGraph,
    invalidations: *const extraction_cache.InvalidationPreview,
    input: RequestPathInput,
) !MaterializationResult {
    try validateRegistry();
    const request_definition = findById(.rpc_request_path_v2);
    const feature_definition = findById(.end_to_end_feature_v2);
    try validateParticipants(request_definition, input.participants);
    try validateEvidence(request_definition, input.evidence);
    try validateInputMembers(feature_definition, input.members, input.completeness);
    try validateEvidence(feature_definition, input.evidence);
    if (!proofStepsLive(graph, input.proof_steps)) return error.InvalidSemanticRecipeProof;

    const previous_hyperedge = if (previous_graph) |previous|
        previous.findHyperedgeByCanonicalName(.request_path, input.canonical_name)
    else
        null;
    const reuse_hyperedge = if (previous_hyperedge) |previous|
        canReuseHyperedge(graph, previous, request_definition, input, invalidations)
    else
        false;
    const hyperedge_id = if (reuse_hyperedge) reuse: {
        const previous = previous_hyperedge.?;
        break :reuse try graph.addHyperedge(.{
            .id = previous.id,
            .kind = previous.kind,
            .canonical_name = previous.canonical_name,
            .recipe = previous.recipe,
            .interaction_fingerprint = previous.interaction_fingerprint,
            .participants = previous.participants,
            .evidence = previous.evidence,
        });
    } else try graph.addHyperedge(.{
        .kind = request_definition.hyperedge_kind.?,
        .canonical_name = input.canonical_name,
        .recipe = request_definition.name,
        .interaction_fingerprint = input.interaction_fingerprint,
        .participants = input.participants,
        .evidence = input.evidence,
    });

    const previous_supernode = if (reuse_hyperedge and previous_graph != null)
        previous_graph.?.findSupernodeByInputHyperedge(previous_hyperedge.?.id)
    else
        null;
    const reuse_supernode = if (previous_supernode) |previous|
        canReuseSupernode(graph, previous, feature_definition, hyperedge_id, input, invalidations)
    else
        false;
    const supernode_id = if (reuse_supernode) reuse: {
        const previous = previous_supernode.?;
        break :reuse try graph.addSupernode(.{
            .id = previous.id,
            .kind = previous.kind,
            .canonical_name = previous.canonical_name,
            .name = previous.name,
            .recipe = previous.recipe,
            .synopsis = previous.synopsis,
            .input_hyperedge_id = hyperedge_id,
            .completeness = previous.completeness,
            .members = previous.members,
            .evidence = previous.evidence,
            .proof_steps = previous.proof_steps,
        });
    } else try graph.addSupernode(.{
        .kind = feature_definition.supernode_kind.?,
        .canonical_name = input.canonical_name,
        .name = input.feature_name,
        .recipe = feature_definition.name,
        .synopsis = input.feature_synopsis,
        .input_hyperedge_id = hyperedge_id,
        .completeness = input.completeness,
        .members = input.members,
        .evidence = input.evidence,
        .proof_steps = input.proof_steps,
    });
    return .{
        .hyperedge_id = hyperedge_id,
        .supernode_id = supernode_id,
        .hyperedge_reused = reuse_hyperedge,
        .supernode_reused = reuse_supernode,
    };
}

fn validateDefinitionShape(definition: Definition) !void {
    switch (definition.output_class) {
        .hyperedge => {
            if (definition.hyperedge_kind == null or definition.supernode_kind != null or definition.upstream != null or
                definition.allowed_completeness.len != 0 or definition.complete_roles.len != 0 or
                definition.proof_policy != .none or definition.synopsis_policy != .absent)
            {
                return error.InvalidSemanticRecipeDefinition;
            }
        },
        .supernode => {
            if (definition.hyperedge_kind != null or definition.supernode_kind == null or definition.upstream == null or
                definition.allowed_completeness.len == 0 or definition.proof_policy != .all_steps_are_live_edges or
                definition.synopsis_policy != .deterministic_template)
            {
                return error.InvalidSemanticRecipeDefinition;
            }
        },
    }
    if (definition.required_roles.len == 0 or definition.required_evidence.len == 0) return error.InvalidSemanticRecipeDefinition;
}

fn validateRoleSet(required: []const model.ParticipantRole, optional: []const model.ParticipantRole) !void {
    try validateUniqueRoles(required);
    try validateUniqueRoles(optional);
    for (required) |role| if (containsRole(optional, role)) return error.InvalidSemanticRecipeDefinition;
}

fn validateUniqueRoles(roles: []const model.ParticipantRole) !void {
    for (roles, 0..) |role, index| {
        for (roles[0..index]) |previous| if (previous == role) return error.InvalidSemanticRecipeDefinition;
    }
}

fn validateEvidenceSet(required: []const model.EvidenceRole, optional: []const model.EvidenceRole) !void {
    try validateUniqueEvidence(required);
    try validateUniqueEvidence(optional);
    for (required) |role| if (containsEvidenceRole(optional, role)) return error.InvalidSemanticRecipeDefinition;
}

fn validateUniqueEvidence(roles: []const model.EvidenceRole) !void {
    for (roles, 0..) |role, index| {
        for (roles[0..index]) |previous| if (previous == role) return error.InvalidSemanticRecipeDefinition;
    }
}

fn validateUniqueCompleteness(values: []const model.SupernodeCompleteness) !void {
    for (values, 0..) |value, index| {
        for (values[0..index]) |previous| if (previous == value) return error.InvalidSemanticRecipeDefinition;
    }
}

fn validateParticipants(definition: *const Definition, participants: []const model.Participant) !void {
    for (definition.required_roles) |required| {
        if (!participantHasRole(participants, required)) return error.IncompleteSemanticRecipeRoles;
    }
    for (participants) |participant| {
        if (!containsRole(definition.required_roles, participant.role) and !containsRole(definition.optional_roles, participant.role)) {
            return error.UnsupportedSemanticRecipeRole;
        }
    }
}

fn validateMembers(
    definition: *const Definition,
    members: []const model.SupernodeMember,
    completeness: model.SupernodeCompleteness,
) !void {
    try validateInputMembers(definition, members, completeness);
    for (members) |member| if (member.reason.len == 0) return error.InvalidSemanticRecipeMember;
}

fn validateInputMembers(
    definition: *const Definition,
    members: []const model.SupernodeMember,
    completeness: model.SupernodeCompleteness,
) !void {
    if (!containsCompleteness(definition.allowed_completeness, completeness)) return error.UnsupportedSemanticRecipeCompleteness;
    for (definition.required_roles) |required| {
        if (!memberHasRole(members, required)) return error.IncompleteSemanticRecipeRoles;
    }
    for (members) |member| {
        if (!containsRole(definition.required_roles, member.role) and !containsRole(definition.optional_roles, member.role)) {
            return error.UnsupportedSemanticRecipeRole;
        }
    }
    if (completeness == .end_to_end_feature) {
        for (definition.complete_roles) |required| if (!memberHasRole(members, required)) return error.IncompleteSemanticRecipeRoles;
    }
}

fn validateEvidence(definition: *const Definition, evidence: []const model.SourceEvidence) !void {
    for (definition.required_evidence) |required| {
        if (!evidenceHasRole(evidence, required)) return error.IncompleteSemanticRecipeEvidence;
    }
    for (evidence) |item| {
        if (!containsEvidenceRole(definition.required_evidence, item.role) and !containsEvidenceRole(definition.optional_evidence, item.role)) {
            return error.UnsupportedSemanticRecipeEvidence;
        }
    }
}

fn canReuseHyperedge(
    graph: *const model.RepositoryGraph,
    previous: *const model.Hyperedge,
    definition: *const Definition,
    input: RequestPathInput,
    invalidations: *const extraction_cache.InvalidationPreview,
) bool {
    if (previous.kind != definition.hyperedge_kind.? or !std.mem.eql(u8, previous.canonical_name, input.canonical_name) or
        !std.mem.eql(u8, previous.recipe, definition.name) or
        !std.mem.eql(u8, &previous.interaction_fingerprint, &input.interaction_fingerprint) or
        !sameParticipants(previous.participants, input.participants) or !sameEvidence(previous.evidence, input.evidence) or
        evidenceInvalidated(previous.evidence, invalidations) or evidenceInvalidated(input.evidence, invalidations))
    {
        return false;
    }
    for (previous.participants) |participant| if (graph.findNode(participant.node_id) == null) return false;
    return proofStepsLive(graph, input.proof_steps);
}

fn canReuseSupernode(
    graph: *const model.RepositoryGraph,
    previous: *const model.Supernode,
    definition: *const Definition,
    hyperedge_id: u64,
    input: RequestPathInput,
    invalidations: *const extraction_cache.InvalidationPreview,
) bool {
    if (previous.kind != definition.supernode_kind.? or !std.mem.eql(u8, previous.canonical_name, input.canonical_name) or
        !std.mem.eql(u8, previous.recipe, definition.name) or previous.input_hyperedge_id != hyperedge_id or
        previous.completeness != input.completeness or !sameMembers(previous.members, input.members) or
        !sameEvidence(previous.evidence, input.evidence) or !sameProofs(previous.proof_steps, input.proof_steps) or
        evidenceInvalidated(previous.evidence, invalidations) or evidenceInvalidated(input.evidence, invalidations))
    {
        return false;
    }
    for (previous.members) |member| if (graph.findNode(member.node_id) == null) return false;
    return graph.findHyperedge(hyperedge_id) != null and proofStepsLive(graph, previous.proof_steps);
}

fn sameParticipants(left: []const model.Participant, right: []const model.Participant) bool {
    if (left.len != right.len) return false;
    for (left) |expected| {
        var found = false;
        for (right) |actual| if (expected.role == actual.role and expected.node_id == actual.node_id) {
            found = true;
            break;
        };
        if (!found) return false;
    }
    return true;
}

fn sameEvidence(left: []const model.SourceEvidence, right: []const model.SourceEvidence) bool {
    if (left.len != right.len) return false;
    for (left) |expected| {
        var found = false;
        for (right) |actual| if (expected.role == actual.role and std.mem.eql(u8, expected.source_path, actual.source_path) and
            std.meta.eql(expected.span, actual.span))
        {
            found = true;
            break;
        };
        if (!found) return false;
    }
    return true;
}

fn sameMembers(left: []const model.SupernodeMember, right: []const model.SupernodeMember) bool {
    if (left.len != right.len) return false;
    for (left) |expected| {
        var found = false;
        for (right) |actual| if (expected.role == actual.role and expected.node_id == actual.node_id and std.mem.eql(u8, expected.reason, actual.reason)) {
            found = true;
            break;
        };
        if (!found) return false;
    }
    return true;
}

fn sameProofs(left: []const model.ProofStep, right: []const model.ProofStep) bool {
    if (left.len != right.len) return false;
    for (left) |expected| {
        var found = false;
        for (right) |actual| if (std.meta.eql(expected, actual)) {
            found = true;
            break;
        };
        if (!found) return false;
    }
    return true;
}

fn evidenceInvalidated(evidence: []const model.SourceEvidence, invalidations: *const extraction_cache.InvalidationPreview) bool {
    for (evidence) |item| if (invalidations.contains(item.source_path)) return true;
    return false;
}

fn proofStepsLive(graph: *const model.RepositoryGraph, proofs: []const model.ProofStep) bool {
    for (proofs) |proof| if (!graph.hasEdge(proof.from, proof.to, proof.relation)) return false;
    return true;
}

fn participantHasRole(values: []const model.Participant, role: model.ParticipantRole) bool {
    for (values) |value| if (value.role == role) return true;
    return false;
}

fn memberHasRole(values: []const model.SupernodeMember, role: model.ParticipantRole) bool {
    for (values) |value| if (value.role == role) return true;
    return false;
}

fn evidenceHasRole(values: []const model.SourceEvidence, role: model.EvidenceRole) bool {
    for (values) |value| if (value.role == role) return true;
    return false;
}

fn containsRole(values: []const model.ParticipantRole, role: model.ParticipantRole) bool {
    for (values) |value| if (value == role) return true;
    return false;
}

fn containsEvidenceRole(values: []const model.EvidenceRole, role: model.EvidenceRole) bool {
    for (values) |value| if (value == role) return true;
    return false;
}

fn containsCompleteness(values: []const model.SupernodeCompleteness, value: model.SupernodeCompleteness) bool {
    for (values) |candidate| if (candidate == value) return true;
    return false;
}

fn updateRoles(hasher: *std.crypto.hash.sha2.Sha256, values: []const model.ParticipantRole) void {
    updateInt(hasher, values.len);
    for (values) |value| updateString(hasher, @tagName(value));
}

fn updateEvidenceRoles(hasher: *std.crypto.hash.sha2.Sha256, values: []const model.EvidenceRole) void {
    updateInt(hasher, values.len);
    for (values) |value| updateString(hasher, @tagName(value));
}

fn updateCompleteness(hasher: *std.crypto.hash.sha2.Sha256, values: []const model.SupernodeCompleteness) void {
    updateInt(hasher, values.len);
    for (values) |value| updateString(hasher, @tagName(value));
}

fn updateString(hasher: *std.crypto.hash.sha2.Sha256, value: []const u8) void {
    updateInt(hasher, value.len);
    hasher.update(value);
}

fn updateInt(hasher: *std.crypto.hash.sha2.Sha256, value: anytype) void {
    var bytes: [8]u8 = @splat(0);
    std.mem.writeInt(u64, &bytes, @intCast(value), .little);
    hasher.update(&bytes);
}
