const std = @import("std");

pub const schema = "zgraphy.semantic-contract.v2";
pub const schema_version: u32 = 2;
pub const embedded_bytes = @embedFile("semantic-schema.v2.json");

pub const Maturity = enum {
    contract_candidate,
};

pub const RecordEvidence = enum {
    optional,
    self_contained,
    required,
    required_or_synthetic,
};

pub const Origin = enum {
    source_syntax,
    source_documentation,
    manifest,
    build_contract,
    version_control,
    zigeffect_metadata,
    runtime_causal,
    resolver_recipe,
    model_suggestion,
    human_confirmation,
};

pub const EpistemicStatus = enum {
    observed,
    resolved,
    derived,
    hypothesis,
    ambiguous,
    contradicted,
    rejected,
};

pub const KindClass = enum {
    entity,
    container,
    package,
    target,
    deployment,
    file,
    scope,
    symbol,
    type,
    callable,
    contract,
    ui,
    data,
    config,
    document,
    requirement,
    @"test",
    runtime,
    generation,
    semantic,
};

pub const Direction = enum {
    directed,
};

pub const EvidencePolicy = enum {
    required,
    required_or_synthetic,
};

pub const SpanPolicy = enum {
    when_source,
    optional,
};

pub const ConfidencePolicy = enum {
    forbidden,
    calibrated_optional,
};

pub const AmbiguityPolicy = enum {
    allowed,
    candidates_required_when_ambiguous,
};

pub const InvalidationDependency = enum {
    source_content,
    source_placement,
    manifest,
    build_contract,
    config,
    version_control,
    zigeffect_generation,
    runtime_generation,
    generation,
    ontology,
    provider,
    resolver,
    recipe,
};

pub const CompatibilitySource = enum {
    mvp_v1,
    benchmark_v1,
};

pub const CompatibilityProjection = enum {
    binary,
    hyperedge_candidate,
};

pub const MigrationStrategy = enum {
    rebuild_generation,
};

pub const RecordDefinition = struct {
    name: []const u8,
    evidence: RecordEvidence,
    generation_scoped: bool,
    immutable: bool,
    parallel: bool,
};

pub const NamespacePolicy = struct {
    canonical: []const u8,
    format: []const u8,
    allow_canonical_override: bool,
};

pub const AffectedPolicy = struct {
    forward: bool,
    reverse: bool,
    default_cost: u8,
};

pub const FamilyPolicy = struct {
    id: []const u8,
    direction: Direction,
    reverse_traversal: bool,
    parallel_instances: bool,
    permitted_origins: []Origin,
    permitted_statuses: []EpistemicStatus,
    evidence: EvidencePolicy,
    span: SpanPolicy,
    confidence: ConfidencePolicy,
    ambiguity: AmbiguityPolicy,
    affected: AffectedPolicy,
    hyperedge_projection: ?[]const u8,
    invalidation: []InvalidationDependency,
};

pub const ExternalMapping = struct {
    namespace: []const u8,
    name: []const u8,
    reverse_endpoints: bool,
};

pub const RelationDefinition = struct {
    name: []const u8,
    family: []const u8,
    source_kind: KindClass,
    target_kind: KindClass,
    source_role: []const u8,
    target_role: []const u8,
    external_mappings: []ExternalMapping,
};

pub const CompatibilityMapping = struct {
    source_schema: CompatibilitySource,
    source_relation: []const u8,
    target_relation: []const u8,
    reverse_endpoints: bool,
    projection: CompatibilityProjection,
};

pub const GraphifyProvenance = struct {
    source: []const u8,
    origin: Origin,
    status: EpistemicStatus,
};

pub const MigrationPolicy = struct {
    source_schema: []const u8,
    target_schema: []const u8,
    strategy: MigrationStrategy,
    in_place: bool,
    retain_source_for_rollback: bool,
    invalidate_on: []const []const u8,
    publish_after: []const []const u8,
};

pub const Contract = struct {
    schema: []const u8,
    schema_version: u32,
    maturity: Maturity,
    records: []RecordDefinition,
    node_kinds: []const []const u8,
    origins: []Origin,
    epistemic_statuses: []EpistemicStatus,
    extension_namespace: NamespacePolicy,
    families: []FamilyPolicy,
    relations: []RelationDefinition,
    compatibility: []CompatibilityMapping,
    graphify_provenance: []GraphifyProvenance,
    migration: MigrationPolicy,
};

pub const ResolvedDefinition = struct {
    name: []const u8,
    family: []const u8,
    source_kind: KindClass,
    target_kind: KindClass,
    source_role: []const u8,
    target_role: []const u8,
    direction: Direction,
    reverse_traversal: bool,
    parallel_instances: bool,
    permitted_origins: []const Origin,
    permitted_statuses: []const EpistemicStatus,
    evidence: EvidencePolicy,
    span: SpanPolicy,
    confidence: ConfidencePolicy,
    ambiguity: AmbiguityPolicy,
    affected: AffectedPolicy,
    hyperedge_projection: ?[]const u8,
    invalidation: []const InvalidationDependency,
    external_mappings: []const ExternalMapping,
};

pub const required_record_names = [_][]const u8{
    "entity",
    "evidence",
    "fact",
    "edge",
    "hyperedge",
    "claim",
    "supernode",
    "generation",
};

pub const required_family_names = [_][]const u8{
    "placement_ownership",
    "dependency_visibility",
    "type_composition",
    "execution_dispatch",
    "api_ui_contract",
    "data_configuration",
    "documentation_rationale",
    "requirement_test_causal",
    "graph_change",
};

pub const required_relation_names = [_][]const u8{
    "contains",       "declares",           "defines",               "member_of",            "source_root_of",          "generated_from",          "owned_by",         "part_of_package",      "part_of_target",   "deployed_as",
    "imports",        "deferred_imports",   "resolves_to",           "imports_from",         "dynamic_imports",         "re_exports",              "aliases",          "depends_on",           "includes",         "sources",
    "extends_config", "references_package", "inherits",              "implements",           "mixes_in",                "embeds",                  "specialises",      "conforms_to",          "has_field",        "has_parameter",
    "returns",        "references_type",    "uses_generic_argument", "calls_direct",         "calls_virtual",           "calls_callback",          "calls_reflective", "registers_handler",    "returns_callable", "aliases_callable",
    "instantiates",   "dispatches_to",      "observed_call",         "invokes_operation",    "handles_operation",       "uses_request",            "uses_response",    "uses_field",           "binds_route",      "renders",
    "uses_component", "binds_property",     "binds_command",         "generated_client_for", "generated_server_for",    "compatible_with",         "reads_from",       "writes_to",            "queries",          "references",
    "foreign_key_to", "produces_event",     "consumes_event",        "uses_config",          "uses_secret_requirement", "binds_service",           "listened_by",      "uses_static_property", "documents",        "explains",
    "rationale_for",  "cites",              "mentions",              "references_document",  "semantically_similar_to", "conceptually_related_to", "supports_claim",   "contradicts_claim",    "satisfies",        "verified_by",
    "covers",         "executes",           "asserts",               "failed_at",            "causal_parent",           "observed_at",             "replays",          "repairs_surface",      "renamed_from",     "moved_from",
    "replaces",       "split_from",         "merged_from",           "changed_by",           "affected_by",             "candidate_impact",        "same_identity_as", "conflicts_with",
};

const required_mvp_mappings = [_][]const u8{
    "contains", "declares", "imports", "calls", "depends_on", "satisfies", "verified_by", "executes", "covers", "source_root", "causal_parent", "observed_at", "references", "owned_by", "member_of", "part_of_target", "defines", "dispatches_to", "deferred_imports", "resolves_to", "imports_from", "re_exports", "aliases", "instantiates", "has_field", "uses_request", "uses_response", "references_type", "generated_from", "generated_client_for", "generated_server_for", "invokes_operation", "handles_operation", "passes_callback",
};

const required_benchmark_mappings = [_][]const u8{
    "contains", "declares", "imports", "calls", "references", "generated_from", "invokes_contract", "implements_contract", "covers", "selects_candidate",
};

pub fn parseEmbedded(allocator: std.mem.Allocator) !std.json.Parsed(Contract) {
    return std.json.parseFromSlice(Contract, allocator, embedded_bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = false,
    });
}

pub fn validate(contract: *const Contract) !void {
    if (!std.mem.eql(u8, contract.schema, schema) or contract.schema_version != schema_version or contract.maturity != .contract_candidate) {
        return error.IncompatibleSemanticContract;
    }
    try validateRecords(contract.records);
    try validateNodeKinds(contract.node_kinds);
    try validateEnumSet(Origin, contract.origins);
    try validateEnumSet(EpistemicStatus, contract.epistemic_statuses);
    if (!std.mem.eql(u8, contract.extension_namespace.canonical, "zgraphy") or
        !std.mem.eql(u8, contract.extension_namespace.format, "reverse_dns") or
        contract.extension_namespace.allow_canonical_override)
    {
        return error.InvalidExtensionNamespacePolicy;
    }
    try validateFamilies(contract.families);
    try validateRelations(contract);
    try validateCompatibility(contract);
    try validateGraphifyProvenance(contract.graphify_provenance);
    try validateMigration(&contract.migration);
}

pub fn findRelation(contract: *const Contract, name: []const u8) ?*const RelationDefinition {
    for (contract.relations, 0..) |relation, index| {
        if (std.mem.eql(u8, relation.name, name)) return &contract.relations[index];
    }
    return null;
}

pub fn findCompatibility(contract: *const Contract, source: CompatibilitySource, relation: []const u8) ?*const CompatibilityMapping {
    for (contract.compatibility, 0..) |mapping, index| {
        if (mapping.source_schema == source and std.mem.eql(u8, mapping.source_relation, relation)) return &contract.compatibility[index];
    }
    return null;
}

pub fn resolveRelation(contract: *const Contract, name: []const u8) !ResolvedDefinition {
    const relation = findRelation(contract, name) orelse return error.UnknownSemanticRelation;
    const family = findFamily(contract, relation.family) orelse return error.UnknownRelationFamily;
    return .{
        .name = relation.name,
        .family = relation.family,
        .source_kind = relation.source_kind,
        .target_kind = relation.target_kind,
        .source_role = relation.source_role,
        .target_role = relation.target_role,
        .direction = family.direction,
        .reverse_traversal = family.reverse_traversal,
        .parallel_instances = family.parallel_instances,
        .permitted_origins = family.permitted_origins,
        .permitted_statuses = family.permitted_statuses,
        .evidence = family.evidence,
        .span = family.span,
        .confidence = family.confidence,
        .ambiguity = family.ambiguity,
        .affected = family.affected,
        .hyperedge_projection = family.hyperedge_projection,
        .invalidation = family.invalidation,
        .external_mappings = relation.external_mappings,
    };
}

pub fn contractDigest() [32]u8 {
    var digest: [32]u8 = @splat(0);
    std.crypto.hash.sha2.Sha256.hash(embedded_bytes, &digest, .{});
    return digest;
}

fn validateRecords(records: []const RecordDefinition) !void {
    if (records.len != required_record_names.len) return error.IncompleteSemanticRecords;
    for (records, 0..) |record, index| {
        if (!std.mem.eql(u8, record.name, required_record_names[index])) return error.IncompleteSemanticRecords;
        if (index > 0 and !record.immutable) return error.MutableSemanticRecord;
    }
    if (records[2].evidence != .required or records[3].evidence != .required_or_synthetic or records[4].evidence != .required or records[5].evidence != .required or records[6].evidence != .required) {
        return error.InvalidSemanticEvidencePolicy;
    }
}

fn validateNodeKinds(kinds: []const []const u8) !void {
    if (kinds.len < 32) return error.IncompleteSemanticNodeKinds;
    for (kinds, 0..) |kind, index| {
        if (!validName(kind)) return error.InvalidSemanticNodeKind;
        for (kinds[0..index]) |previous| if (std.mem.eql(u8, previous, kind)) return error.DuplicateSemanticNodeKind;
    }
}

fn validateEnumSet(comptime T: type, values: []const T) !void {
    const fields = std.meta.fields(T);
    if (values.len != fields.len) return error.IncompleteSemanticProvenance;
    inline for (fields) |field| {
        const wanted: T = @enumFromInt(field.value);
        var found = false;
        for (values) |value| if (value == wanted) {
            found = true;
            break;
        };
        if (!found) return error.IncompleteSemanticProvenance;
    }
}

fn validateFamilies(families: []const FamilyPolicy) !void {
    if (families.len != required_family_names.len) return error.IncompleteRelationFamilies;
    for (families, 0..) |family, index| {
        if (!std.mem.eql(u8, family.id, required_family_names[index]) or family.permitted_origins.len == 0 or
            family.permitted_statuses.len == 0 or family.affected.default_cost == 0 or family.affected.default_cost > 64 or
            family.invalidation.len == 0)
        {
            return error.InvalidRelationFamily;
        }
        try validateUniqueEnums(Origin, family.permitted_origins);
        try validateUniqueEnums(EpistemicStatus, family.permitted_statuses);
        try validateUniqueEnums(InvalidationDependency, family.invalidation);
        if (family.ambiguity == .candidates_required_when_ambiguous and !containsEnum(EpistemicStatus, family.permitted_statuses, .ambiguous)) {
            return error.InvalidRelationFamily;
        }
        if (family.hyperedge_projection) |projection| if (!validName(projection)) return error.InvalidRelationFamily;
    }
}

fn validateRelations(contract: *const Contract) !void {
    if (contract.relations.len != required_relation_names.len) return error.IncompleteSemanticRelations;
    for (contract.relations, 0..) |relation, index| {
        for (contract.relations[0..index]) |previous| if (std.mem.eql(u8, previous.name, relation.name)) return error.DuplicateSemanticRelation;
        if (!std.mem.eql(u8, relation.name, required_relation_names[index])) return error.IncompleteSemanticRelations;
        if (!validName(relation.name) or !validName(relation.source_role) or !validName(relation.target_role)) return error.InvalidSemanticRelation;
        if (findFamily(contract, relation.family) == null) return error.UnknownRelationFamily;
        for (relation.external_mappings, 0..) |mapping, mapping_index| {
            if (!validNamespace(mapping.namespace) or mapping.name.len == 0 or mapping.name.len > 128) return error.InvalidExternalRelationMapping;
            for (relation.external_mappings[0..mapping_index]) |previous| {
                if (std.mem.eql(u8, previous.namespace, mapping.namespace) and std.mem.eql(u8, previous.name, mapping.name)) return error.DuplicateExternalRelationMapping;
            }
            for (contract.relations[0..index]) |previous_relation| {
                for (previous_relation.external_mappings) |previous| {
                    if (std.mem.eql(u8, previous.namespace, mapping.namespace) and std.mem.eql(u8, previous.name, mapping.name)) return error.DuplicateExternalRelationMapping;
                }
            }
        }
        _ = try resolveRelation(contract, relation.name);
    }
}

fn validateCompatibility(contract: *const Contract) !void {
    if (contract.compatibility.len != required_mvp_mappings.len + required_benchmark_mappings.len) return error.IncompleteCompatibilityMappings;
    for (contract.compatibility, 0..) |mapping, index| {
        if (!validName(mapping.source_relation) or findRelation(contract, mapping.target_relation) == null) return error.InvalidCompatibilityMapping;
        for (contract.compatibility[0..index]) |previous| {
            if (previous.source_schema == mapping.source_schema and std.mem.eql(u8, previous.source_relation, mapping.source_relation)) {
                return error.DuplicateCompatibilityMapping;
            }
        }
    }
    for (required_mvp_mappings) |name| if (findCompatibility(contract, .mvp_v1, name) == null) return error.IncompleteCompatibilityMappings;
    for (required_benchmark_mappings) |name| if (findCompatibility(contract, .benchmark_v1, name) == null) return error.IncompleteCompatibilityMappings;
    const source_root = findCompatibility(contract, .mvp_v1, "source_root") orelse return error.IncompleteCompatibilityMappings;
    if (!source_root.reverse_endpoints or !std.mem.eql(u8, source_root.target_relation, "source_root_of")) return error.InvalidCompatibilityMapping;
    const candidate = findCompatibility(contract, .benchmark_v1, "selects_candidate") orelse return error.IncompleteCompatibilityMappings;
    if (candidate.projection != .hyperedge_candidate) return error.InvalidCompatibilityMapping;
}

fn validateGraphifyProvenance(mappings: []const GraphifyProvenance) !void {
    const expected = [_]struct { source: []const u8, origin: Origin, status: EpistemicStatus }{
        .{ .source = "EXTRACTED", .origin = .source_syntax, .status = .observed },
        .{ .source = "INFERRED", .origin = .resolver_recipe, .status = .derived },
        .{ .source = "AMBIGUOUS", .origin = .resolver_recipe, .status = .ambiguous },
    };
    if (mappings.len != expected.len) return error.IncompleteGraphifyProvenance;
    for (mappings, expected) |mapping, wanted| {
        if (!std.mem.eql(u8, mapping.source, wanted.source) or mapping.origin != wanted.origin or mapping.status != wanted.status) {
            return error.InvalidGraphifyProvenance;
        }
    }
}

fn validateMigration(migration: *const MigrationPolicy) !void {
    if (!std.mem.eql(u8, migration.source_schema, "zgraphy.nendb.snapshot.v1") or
        !std.mem.eql(u8, migration.target_schema, "zgraphy.nendb.snapshot.v2") or migration.strategy != .rebuild_generation or
        migration.in_place or !migration.retain_source_for_rollback or migration.invalidate_on.len < 7 or migration.publish_after.len < 8)
    {
        return error.InvalidSemanticMigration;
    }
    try validateUniqueStrings(migration.invalidate_on);
    try validateUniqueStrings(migration.publish_after);
}

fn findFamily(contract: *const Contract, id: []const u8) ?*const FamilyPolicy {
    for (contract.families, 0..) |family, index| if (std.mem.eql(u8, family.id, id)) return &contract.families[index];
    return null;
}

fn validateUniqueEnums(comptime T: type, values: []const T) !void {
    for (values, 0..) |value, index| {
        for (values[0..index]) |previous| if (previous == value) return error.DuplicateSemanticPolicyValue;
    }
}

fn containsEnum(comptime T: type, values: []const T, wanted: T) bool {
    for (values) |value| if (value == wanted) return true;
    return false;
}

fn validateUniqueStrings(values: []const []const u8) !void {
    for (values, 0..) |value, index| {
        if (!validName(value)) return error.InvalidSemanticPolicyValue;
        for (values[0..index]) |previous| if (std.mem.eql(u8, previous, value)) return error.DuplicateSemanticPolicyValue;
    }
}

fn validName(value: []const u8) bool {
    if (value.len == 0 or value.len > 96 or !std.ascii.isLower(value[0])) return false;
    for (value) |byte| if (!std.ascii.isLower(byte) and !std.ascii.isDigit(byte) and byte != '_') return false;
    return true;
}

fn validNamespace(value: []const u8) bool {
    if (value.len == 0 or value.len > 128) return false;
    for (value) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '_' and byte != '.' and byte != '-') return false;
    return true;
}
