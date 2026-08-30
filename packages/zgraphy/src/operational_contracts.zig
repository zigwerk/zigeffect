const std = @import("std");

pub const schema = "zgraphy.operational-contracts.v1";
pub const schema_version: u32 = 1;
pub const embedded_bytes = @embedFile("operational-contracts.v1.json");

pub const Maturity = enum { contract_candidate };

pub const ProviderKind = enum {
    source_syntax,
    manifest,
    generated_contract,
    compiler_index,
    live_database,
    runtime_causal,
    document_converter,
    local_model,
    remote_model,
};

pub const Authority = enum {
    repository_read,
    process_execute,
    filesystem_external,
    network_egress,
    database_read,
    model_local,
    model_remote,
};

pub const TrustClass = enum { observation, derived, hypothesis };

pub const ProviderKindDefinition = struct {
    kind: ProviderKind,
    authority: Authority,
    trust: TrustClass,
    expiration_required: bool,
    reconciliation_required: bool,
};

pub const AuthorityDefinition = struct {
    id: Authority,
    rank: u8,
    externally_granted: bool,
    repository_config_allowed: bool,
    read_only: bool,
};

pub const LifecycleState = enum {
    disabled,
    available,
    checking,
    running,
    partial,
    complete,
    stale,
    failed,
    expired,
};

pub const LifecycleTransition = struct {
    from: LifecycleState,
    to: LifecycleState,
};

pub const TerminalUnitState = enum {
    returned,
    omitted,
    zero_node,
    hyperedge_only,
    failed,
    content_filtered,
};

pub const BoundDefinition = struct {
    name: []const u8,
    default_value: u64,
    maximum_value: u64,
};

pub const HealthStatus = enum {
    healthy,
    degraded,
    stale,
    partial,
    incompatible,
    corrupt,
};

pub const ProviderFailurePolicy = struct {
    retain_last_complete_generation: bool,
    required_provider_health: HealthStatus,
    optional_provider_health: HealthStatus,
    canonical_overwrite: bool,
    conflicts_become_contradictions: bool,
};

pub const ProviderContract = struct {
    schema: []const u8,
    kinds: []ProviderKindDefinition,
    authorities: []AuthorityDefinition,
    repository_config_max_authority: Authority,
    capability_decision_required: []Authority,
    envelope_required_fields: []const []const u8,
    prohibited_fields: []const []const u8,
    lifecycle_states: []LifecycleState,
    lifecycle_transitions: []LifecycleTransition,
    terminal_unit_states: []TerminalUnitState,
    bounds: []BoundDefinition,
    failure_policy: ProviderFailurePolicy,
};

pub const ConformanceDimension = enum {
    identity,
    source_span,
    containment,
    reference_direction,
    ambiguity,
    mutation,
    incremental_equivalence,
    resource_bounds,
    determinism,
    redaction,
    authority,
    unit_reconciliation,
    interruption_safety,
};

pub const ConformanceProfileName = enum {
    discovery,
    structural,
    resolved,
    external,
    semantic_model,
};

pub const ConformanceProfile = struct {
    name: ConformanceProfileName,
    required_dimensions: []ConformanceDimension,
    unsupported_must_be_declared: bool,
    no_canonical_mutation: bool,
};

pub const ConformanceContract = struct {
    schema: []const u8,
    output_schema: []const u8,
    dimensions: []ConformanceDimension,
    profiles: []ConformanceProfile,
    receipt_required_fields: []const []const u8,
    partial_is_not_pass: bool,
    unknown_is_unsupported: bool,
};

pub const ConfigLayer = enum {
    compiled_defaults,
    user,
    repository,
    environment,
    cli,
};

pub const ConfigMode = enum {
    structural,
    semantic_local,
    semantic_remote,
    ci,
    agent,
    benchmark,
};

pub const FreshnessMode = enum { on_query };
pub const ConfigMigrationStrategy = enum { expand_safe_defaults };

pub const ConfigAuthorityPolicy = struct {
    repository_max: Authority,
    higher_layer_may_tighten: bool,
    widening_requires_capability_decision: bool,
    ambient_credentials_select_provider: bool,
};

pub const ConfigMigration = struct {
    source_schema: []const u8,
    target_schema: []const u8,
    strategy: ConfigMigrationStrategy,
    in_place: bool,
    retain_source_for_rollback: bool,
};

pub const ConfigContract = struct {
    schema: []const u8,
    current_runtime_schema: []const u8,
    active: bool,
    precedence: []ConfigLayer,
    modes: []ConfigMode,
    field_groups: []const []const u8,
    fingerprint_groups: []const []const u8,
    default_freshness: FreshnessMode,
    authority: ConfigAuthorityPolicy,
    migration: ConfigMigration,
};

pub const HealthDimension = enum {
    generation,
    freshness,
    discovery,
    semantics,
    providers,
    storage,
    indexes,
    self_manager,
    resources,
};

pub const HealthContract = struct {
    schema: []const u8,
    statuses: []HealthStatus,
    dimensions: []HealthDimension,
    accounting_fields: []const []const u8,
    independent_dimensions: bool,
    query_declares_dependencies: bool,
    repair_fields: []const []const u8,
    unknown_dimension_is_unsafe: bool,
};

pub const DiagnosticSeverity = enum { info, warning, @"error", fatal };

pub const DiagnosticStage = enum {
    discovery,
    extraction,
    resolution,
    derivation,
    indexing,
    pruning,
    validation,
    publication,
    query,
    provider,
    migration,
    storage,
};

pub const DiagnosticStream = enum { stderr };

pub const DiagnosticContract = struct {
    schema: []const u8,
    severities: []DiagnosticSeverity,
    stages: []DiagnosticStage,
    required_fields: []const []const u8,
    prohibited_fields: []const []const u8,
    max_code_bytes: u16,
    max_detail_bytes: u16,
    max_repair_bytes: u16,
    stdout_result_only: bool,
    stream: DiagnosticStream,
};

pub const MigrationStrategy = enum { rebuild_generation };

pub const MigrationState = enum {
    planned,
    candidate_created,
    copying,
    validating,
    validated,
    publishing,
    published,
    rolling_back,
    rolled_back,
    failed,
};

pub const MigrationContract = struct {
    schema: []const u8,
    source_schema: []const u8,
    target_schema: []const u8,
    strategy: MigrationStrategy,
    states: []MigrationState,
    receipt_required_fields: []const []const u8,
    publish_requires: []const []const u8,
    publish_requires_validation: bool,
    atomic_publish: bool,
    in_place: bool,
    retain_previous_good: bool,
    failed_candidate_replaces_active: bool,
    cleanup_owned_only: bool,
};

pub const Contract = struct {
    schema: []const u8,
    schema_version: u32,
    maturity: Maturity,
    provider: ProviderContract,
    conformance: ConformanceContract,
    config: ConfigContract,
    health: HealthContract,
    diagnostic: DiagnosticContract,
    migration: MigrationContract,
};

pub const required_provider_kinds = [_]ProviderKind{
    .source_syntax,
    .manifest,
    .generated_contract,
    .compiler_index,
    .live_database,
    .runtime_causal,
    .document_converter,
    .local_model,
    .remote_model,
};

pub const required_conformance_dimensions = [_]ConformanceDimension{
    .identity,
    .source_span,
    .containment,
    .reference_direction,
    .ambiguity,
    .mutation,
    .incremental_equivalence,
    .resource_bounds,
    .determinism,
    .redaction,
    .authority,
    .unit_reconciliation,
    .interruption_safety,
};

pub const required_health_dimensions = [_]HealthDimension{
    .generation,
    .freshness,
    .discovery,
    .semantics,
    .providers,
    .storage,
    .indexes,
    .self_manager,
    .resources,
};

const required_authorities = [_]Authority{
    .repository_read,
    .process_execute,
    .filesystem_external,
    .network_egress,
    .database_read,
    .model_local,
    .model_remote,
};

const externally_granted_authorities = [_]Authority{
    .process_execute,
    .filesystem_external,
    .network_egress,
    .database_read,
    .model_local,
    .model_remote,
};

const required_envelope_fields = [_][]const u8{
    "provider_kind", "implementation", "version", "authority", "capabilities", "source_generation", "observed_at_ms", "expires_at_ms", "content_fingerprint", "config_fingerprint", "scope", "redaction", "bounds", "requested_units", "terminal_units",
};

const prohibited_fields = [_][]const u8{
    "credential", "token", "secret", "connection_string", "authorization_header", "raw_environment", "absolute_path", "raw_source_body", "raw_stdout", "raw_stderr",
};

const required_bound_names = [_][]const u8{
    "max_input_bytes", "max_output_bytes", "timeout_ms", "memory_bytes", "concurrency", "retries", "max_tokens", "max_spend_microunits",
};

const required_config_groups = [_][]const u8{
    "repository", "paths", "providers", "bounds", "freshness", "retention", "analysis", "retrieval", "models", "storage", "diagnostics", "maturity", "linked_repositories", "output",
};

const required_fingerprint_groups = [_][]const u8{
    "repository", "paths", "providers", "bounds", "freshness", "analysis", "retrieval", "models", "storage", "maturity", "linked_repositories", "mode",
};

const required_health_fields = [_][]const u8{
    "discovered_units", "included_units", "indexed_units", "ignored_units", "excluded_units", "unsupported_units", "unreadable_units", "oversized_units", "sensitive_units", "unclassified_units", "converted_units", "uncovered_units", "facts", "relationships", "parse_errors", "unresolved_references", "ambiguity_sets", "dangling_candidates", "contradictions", "invalidated_claims", "stale_provider_observations", "dropped_evidence", "invalidated", "retained", "pruned", "orphan_swept", "repaired", "rebuilt", "compacted", "garbage_collected", "truncations", "retries", "timeouts", "allocation_failures", "process_exits",
};

const required_publish_invariants = [_][]const u8{
    "endpoints", "evidence", "participants", "memberships", "proof_paths", "indexes", "vectors", "health",
};

pub fn parseEmbedded(allocator: std.mem.Allocator) !std.json.Parsed(Contract) {
    return std.json.parseFromSlice(Contract, allocator, embedded_bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = false,
    });
}

pub fn validate(contract: *const Contract) !void {
    if (!std.mem.eql(u8, contract.schema, schema) or contract.schema_version != schema_version or contract.maturity != .contract_candidate) {
        return error.IncompatibleOperationalContract;
    }
    try validateProvider(&contract.provider);
    try validateConformance(&contract.conformance);
    try validateConfig(&contract.config);
    try validateHealth(&contract.health);
    try validateDiagnostic(&contract.diagnostic);
    try validateMigration(&contract.migration);
}

pub fn contractDigest() [32]u8 {
    var digest: [32]u8 = @splat(0);
    std.crypto.hash.sha2.Sha256.hash(embedded_bytes, &digest, .{});
    return digest;
}

pub fn findAuthority(provider: *const ProviderContract, authority: Authority) ?*const AuthorityDefinition {
    for (provider.authorities, 0..) |definition, index| {
        if (definition.id == authority) return &provider.authorities[index];
    }
    return null;
}

pub fn findConformanceProfile(conformance: *const ConformanceContract, name: ConformanceProfileName) ?*const ConformanceProfile {
    for (conformance.profiles, 0..) |profile, index| {
        if (profile.name == name) return &conformance.profiles[index];
    }
    return null;
}

pub fn allowsTransition(provider: *const ProviderContract, from: LifecycleState, to: LifecycleState) bool {
    for (provider.lifecycle_transitions) |transition| {
        if (transition.from == from and transition.to == to) return true;
    }
    return false;
}

fn validateProvider(provider: *const ProviderContract) !void {
    if (!std.mem.eql(u8, provider.schema, "zgraphy.provider-envelope.v1")) return error.IncompatibleProviderContract;
    if (provider.kinds.len != required_provider_kinds.len) return error.IncompleteProviderKinds;
    for (provider.kinds, 0..) |kind, index| {
        for (provider.kinds[0..index]) |previous| if (previous.kind == kind.kind) return error.DuplicateProviderKind;
        if (kind.kind != required_provider_kinds[index] or !kind.reconciliation_required) return error.InvalidProviderKind;
        if (findAuthority(provider, kind.authority) == null) return error.UnknownProviderAuthority;
        if ((kind.kind == .local_model or kind.kind == .remote_model) and kind.trust != .hypothesis) return error.UnsafeProviderTrust;
        if ((kind.kind == .live_database or kind.kind == .runtime_causal or kind.kind == .remote_model) != kind.expiration_required) return error.InvalidProviderExpiration;
    }
    if (provider.authorities.len != required_authorities.len) return error.IncompleteProviderAuthorities;
    var previous_rank: u8 = 0;
    for (provider.authorities, 0..) |authority, index| {
        for (provider.authorities[0..index]) |previous| if (previous.id == authority.id) return error.DuplicateProviderAuthority;
        if (authority.id != required_authorities[index]) return error.InvalidProviderAuthority;
        if (index > 0 and authority.rank <= previous_rank) return error.InvalidProviderAuthorityRank;
        previous_rank = authority.rank;
        if (authority.id == .repository_read) {
            if (authority.externally_granted or !authority.repository_config_allowed or !authority.read_only) return error.UnsafeRepositoryAuthority;
        } else if (!authority.externally_granted or authority.repository_config_allowed) return error.UnsafeExternalAuthority;
        if ((authority.id == .filesystem_external or authority.id == .database_read) and !authority.read_only) return error.UnsafeExternalAuthority;
    }
    if (provider.repository_config_max_authority != .repository_read) return error.UnsafeRepositoryAuthority;
    try exactEnums(Authority, provider.capability_decision_required, &externally_granted_authorities, error.IncompleteCapabilityPolicy);
    try exactStrings(provider.envelope_required_fields, &required_envelope_fields, error.IncompleteProviderEnvelope);
    try exactStrings(provider.prohibited_fields, &prohibited_fields, error.IncompleteRedactionPolicy);
    try exactEnumDeclaration(LifecycleState, provider.lifecycle_states, error.IncompleteProviderLifecycle);
    try validateTransitions(provider);
    try exactEnumDeclaration(TerminalUnitState, provider.terminal_unit_states, error.IncompleteUnitReconciliation);
    if (provider.bounds.len != required_bound_names.len) return error.IncompleteProviderBounds;
    for (provider.bounds, 0..) |bound, index| {
        if (!std.mem.eql(u8, bound.name, required_bound_names[index]) or bound.maximum_value == 0 or bound.default_value > bound.maximum_value) return error.InvalidProviderBound;
        for (provider.bounds[0..index]) |previous| if (std.mem.eql(u8, previous.name, bound.name)) return error.DuplicateProviderBound;
    }
    const policy = provider.failure_policy;
    if (!policy.retain_last_complete_generation or policy.required_provider_health != .partial or
        policy.optional_provider_health != .degraded or policy.canonical_overwrite or !policy.conflicts_become_contradictions)
    {
        return error.UnsafeProviderFailurePolicy;
    }
}

fn validateTransitions(provider: *const ProviderContract) !void {
    const required = [_]LifecycleTransition{
        .{ .from = .disabled, .to = .available },
        .{ .from = .available, .to = .checking },
        .{ .from = .checking, .to = .running },
        .{ .from = .checking, .to = .failed },
        .{ .from = .running, .to = .partial },
        .{ .from = .running, .to = .complete },
        .{ .from = .running, .to = .failed },
        .{ .from = .partial, .to = .running },
        .{ .from = .complete, .to = .stale },
        .{ .from = .complete, .to = .expired },
        .{ .from = .stale, .to = .running },
        .{ .from = .stale, .to = .expired },
        .{ .from = .failed, .to = .running },
        .{ .from = .expired, .to = .running },
        .{ .from = .available, .to = .disabled },
    };
    if (provider.lifecycle_transitions.len != required.len) return error.IncompleteProviderLifecycle;
    for (provider.lifecycle_transitions, required, 0..) |transition, wanted, index| {
        for (provider.lifecycle_transitions[0..index]) |previous| {
            if (previous.from == transition.from and previous.to == transition.to) return error.DuplicateProviderTransition;
        }
        if (transition.from != wanted.from or transition.to != wanted.to) return error.InvalidProviderTransition;
    }
}

fn validateConformance(conformance: *const ConformanceContract) !void {
    if (!std.mem.eql(u8, conformance.schema, "zgraphy.extractor-conformance.v1") or
        !std.mem.eql(u8, conformance.output_schema, "zgraphy.semantic-contract.v2")) return error.IncompatibleConformanceContract;
    try exactEnums(ConformanceDimension, conformance.dimensions, &required_conformance_dimensions, error.IncompleteConformanceDimensions);
    const required_profiles = [_]ConformanceProfileName{ .discovery, .structural, .resolved, .external, .semantic_model };
    const required_counts = [_]usize{ 6, 9, 12, 13, 13 };
    if (conformance.profiles.len != required_profiles.len) return error.IncompleteConformanceProfiles;
    for (conformance.profiles, 0..) |profile, index| {
        for (conformance.profiles[0..index]) |previous| if (previous.name == profile.name) return error.DuplicateConformanceProfile;
        if (profile.name != required_profiles[index] or profile.required_dimensions.len != required_counts[index] or
            !profile.unsupported_must_be_declared or !profile.no_canonical_mutation) return error.InvalidConformanceProfile;
        try validateDimensionSubset(profile.required_dimensions);
    }
    const external = findConformanceProfile(conformance, .external) orelse return error.IncompleteConformanceProfiles;
    const semantic = findConformanceProfile(conformance, .semantic_model) orelse return error.IncompleteConformanceProfiles;
    try exactEnums(ConformanceDimension, external.required_dimensions, &required_conformance_dimensions, error.IncompleteConformanceProfile);
    try exactEnums(ConformanceDimension, semantic.required_dimensions, &required_conformance_dimensions, error.IncompleteConformanceProfile);
    if (conformance.receipt_required_fields.len < 14) return error.IncompleteConformanceReceipt;
    try validateUniqueNames(conformance.receipt_required_fields);
    if (!conformance.partial_is_not_pass or !conformance.unknown_is_unsupported) return error.UnsafeConformancePolicy;
}

fn validateDimensionSubset(dimensions: []const ConformanceDimension) !void {
    for (dimensions, 0..) |dimension, index| {
        if (!containsEnum(ConformanceDimension, &required_conformance_dimensions, dimension)) return error.UnknownConformanceDimension;
        for (dimensions[0..index]) |previous| if (previous == dimension) return error.DuplicateConformanceDimension;
    }
}

fn validateConfig(config: *const ConfigContract) !void {
    if (!std.mem.eql(u8, config.schema, "zgraphy.config.v2") or
        !std.mem.eql(u8, config.current_runtime_schema, "zgraphy.config.v2") or config.active) return error.InvalidConfigContract;
    try exactEnumDeclaration(ConfigLayer, config.precedence, error.IncompleteConfigPrecedence);
    try exactEnumDeclaration(ConfigMode, config.modes, error.IncompleteConfigModes);
    try exactStrings(config.field_groups, &required_config_groups, error.IncompleteConfigGroups);
    try exactStrings(config.fingerprint_groups, &required_fingerprint_groups, error.IncompleteConfigFingerprint);
    if (config.default_freshness != .on_query or config.authority.repository_max != .repository_read or
        !config.authority.higher_layer_may_tighten or !config.authority.widening_requires_capability_decision or
        config.authority.ambient_credentials_select_provider) return error.UnsafeConfigAuthority;
    const migration = config.migration;
    if (!std.mem.eql(u8, migration.source_schema, "zgraphy.config.v1") or
        !std.mem.eql(u8, migration.target_schema, "zgraphy.config.v2") or migration.strategy != .expand_safe_defaults or
        migration.in_place or !migration.retain_source_for_rollback) return error.UnsafeConfigMigration;
}

fn validateHealth(health: *const HealthContract) !void {
    if (!std.mem.eql(u8, health.schema, "zgraphy.graph-health.v1")) return error.IncompatibleHealthContract;
    try exactEnumDeclaration(HealthStatus, health.statuses, error.IncompleteHealthStatuses);
    try exactEnums(HealthDimension, health.dimensions, &required_health_dimensions, error.IncompleteHealthDimensions);
    try exactStrings(health.accounting_fields, &required_health_fields, error.IncompleteHealthAccounting);
    const required_repairs = [_][]const u8{ "diagnostic_code", "repair_hint", "repair_command", "source_ref", "generation" };
    try exactStrings(health.repair_fields, &required_repairs, error.IncompleteHealthRepairPolicy);
    if (!health.independent_dimensions or !health.query_declares_dependencies or !health.unknown_dimension_is_unsafe) return error.UnsafeHealthPolicy;
}

fn validateDiagnostic(diagnostic: *const DiagnosticContract) !void {
    if (!std.mem.eql(u8, diagnostic.schema, "zgraphy.diagnostic.v1")) return error.IncompatibleDiagnosticContract;
    try exactEnumDeclaration(DiagnosticSeverity, diagnostic.severities, error.IncompleteDiagnosticSeverities);
    try exactEnumDeclaration(DiagnosticStage, diagnostic.stages, error.IncompleteDiagnosticStages);
    if (diagnostic.required_fields.len < 11) return error.IncompleteDiagnosticFields;
    try validateUniqueNames(diagnostic.required_fields);
    try exactStrings(diagnostic.prohibited_fields, &prohibited_fields, error.IncompleteRedactionPolicy);
    if (diagnostic.max_code_bytes == 0 or diagnostic.max_code_bytes > 128 or
        diagnostic.max_detail_bytes == 0 or diagnostic.max_detail_bytes > 4096 or
        diagnostic.max_repair_bytes == 0 or diagnostic.max_repair_bytes > 2048 or
        !diagnostic.stdout_result_only or diagnostic.stream != .stderr) return error.UnsafeDiagnosticPolicy;
}

fn validateMigration(migration: *const MigrationContract) !void {
    if (!std.mem.eql(u8, migration.schema, "zgraphy.migration-receipt.v1") or
        !std.mem.eql(u8, migration.source_schema, "zgraphy.nendb.snapshot.v1") or
        !std.mem.eql(u8, migration.target_schema, "zgraphy.nendb.snapshot.v2") or migration.strategy != .rebuild_generation)
    {
        return error.IncompatibleMigrationContract;
    }
    try exactEnumDeclaration(MigrationState, migration.states, error.IncompleteMigrationStates);
    if (migration.receipt_required_fields.len < 16) return error.IncompleteMigrationReceipt;
    try validateUniqueNames(migration.receipt_required_fields);
    try exactStrings(migration.publish_requires, &required_publish_invariants, error.IncompleteMigrationValidation);
    if (!migration.publish_requires_validation or !migration.atomic_publish or migration.in_place or
        !migration.retain_previous_good or migration.failed_candidate_replaces_active or !migration.cleanup_owned_only)
    {
        return error.UnsafeMigrationPolicy;
    }
}

fn exactEnumDeclaration(comptime T: type, values: []const T, failure: anyerror) !void {
    const fields = std.meta.fields(T);
    if (values.len != fields.len) return failure;
    inline for (fields, 0..) |field, index| {
        const expected: T = @enumFromInt(field.value);
        if (values[index] != expected) return failure;
    }
}

fn exactEnums(comptime T: type, values: []const T, expected: []const T, failure: anyerror) !void {
    if (values.len != expected.len) return failure;
    for (values, expected) |actual, wanted| if (actual != wanted) return failure;
}

fn exactStrings(values: []const []const u8, expected: []const []const u8, failure: anyerror) !void {
    if (values.len != expected.len) return failure;
    for (values, expected) |actual, wanted| if (!std.mem.eql(u8, actual, wanted)) return failure;
    try validateUniqueNames(values);
}

fn validateUniqueNames(values: []const []const u8) !void {
    for (values, 0..) |value, index| {
        if (!validName(value)) return error.InvalidOperationalFieldName;
        for (values[0..index]) |previous| if (std.mem.eql(u8, previous, value)) return error.DuplicateOperationalFieldName;
    }
}

fn containsEnum(comptime T: type, values: []const T, wanted: T) bool {
    for (values) |value| if (value == wanted) return true;
    return false;
}

fn validName(value: []const u8) bool {
    if (value.len == 0 or value.len > 96 or !std.ascii.isLower(value[0])) return false;
    for (value) |byte| if (!std.ascii.isLower(byte) and !std.ascii.isDigit(byte) and byte != '_') return false;
    return true;
}
