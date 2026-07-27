const std = @import("std");
const delta_journal = @import("delta_journal.zig");
const discovery = @import("discovery.zig");
const freshness = @import("freshness.zig");
const memory = @import("memory.zig");
const model = @import("model.zig");
const nendb = @import("nendb.zig");
const semantic_recipes = @import("semantic_recipes.zig");

pub const schema = "zgraphy.origin-ledger.v1";
pub const schema_version: u32 = 1;
pub const default_name = "origin-ledger.json";
pub const max_artifact_bytes: usize = 256 * 1024 * 1024;
pub const max_provider_id_bytes: usize = 256;
pub const max_owners: usize = 16_384;
pub const max_records: usize = 2_000_000;
pub const max_dependencies: usize = 1_000_000;

pub const Tier = enum(u8) {
    source_syntax,
    source_documentation,
    manifest,
    build_contract,
    version_control,
    zigeffect_metadata,
    compiler_index,
    runtime_causal,
    resolver_recipe,
    model_suggestion,
    human_confirmation,
    historical_lineage,
};

pub const ProviderFreshness = enum(u8) {
    current,
    stale,
    incompatible,
};

pub const Authority = enum(u8) {
    repository_read,
    provider_read,
    runtime_read,
    user_pin,
};

pub const Dependency = struct {
    path: []const u8,
    content_digest: [32]u8,
};

pub const RecordKind = enum(u8) {
    node,
    edge,
    hyperedge,
    supernode,
};

pub const RecordRef = struct {
    kind: RecordKind,
    id: u64 = 0,
    from: u64 = 0,
    to: u64 = 0,
    relation: model.Relation = .contains,
};

pub const OwnerInput = struct {
    tier: Tier,
    provider_id: []const u8,
    provider_fingerprint: []const u8,
    freshness: ProviderFreshness = .current,
    authority: Authority = .provider_read,
    dependencies: []const Dependency = &.{},
};

pub const Owner = struct {
    id: []const u8,
    tier: Tier,
    provider_id: []const u8,
    provider_fingerprint: []const u8,
    freshness: ProviderFreshness,
    authority: Authority,
    dependencies: []const Dependency,
};

pub const Ownership = struct {
    record: RecordRef,
    owner_id: []const u8,
};

pub const Overlay = struct {
    owner: OwnerInput,
    graph: *const model.RepositoryGraph,
    owned_records: []const RecordRef,
};

pub const SweepReasons = struct {
    owner_replaced: usize = 0,
    dependency_changed: usize = 0,
    dependency_deleted: usize = 0,
    dependency_excluded: usize = 0,
    provider_stale: usize = 0,
    provider_incompatible: usize = 0,
    dangling_reference: usize = 0,
    invalid_proof: usize = 0,
    unowned_prior_record: usize = 0,
    reconciled_absent: usize = 0,

    pub fn total(self: SweepReasons) usize {
        return self.owner_replaced + self.dependency_changed + self.dependency_deleted +
            self.dependency_excluded + self.provider_stale + self.provider_incompatible +
            self.dangling_reference + self.invalid_proof + self.unowned_prior_record + self.reconciled_absent;
    }
};

pub const TierCounts = struct {
    source_syntax: usize = 0,
    source_documentation: usize = 0,
    manifest: usize = 0,
    build_contract: usize = 0,
    version_control: usize = 0,
    zigeffect_metadata: usize = 0,
    compiler_index: usize = 0,
    runtime_causal: usize = 0,
    resolver_recipe: usize = 0,
    model_suggestion: usize = 0,
    human_confirmation: usize = 0,
    historical_lineage: usize = 0,

    pub fn total(self: TierCounts) usize {
        return self.source_syntax + self.source_documentation + self.manifest + self.build_contract +
            self.version_control + self.zigeffect_metadata + self.compiler_index + self.runtime_causal +
            self.resolver_recipe + self.model_suggestion + self.human_confirmation + self.historical_lineage;
    }
};

pub const Summary = struct {
    owners: usize = 0,
    records: usize = 0,
    owned_records: usize = 0,
    nodes: usize = 0,
    edges: usize = 0,
    hyperedges: usize = 0,
    supernodes: usize = 0,
    carried_records: usize = 0,
    replaced_records: usize = 0,
    swept_records: usize = 0,
    active_by_tier: TierCounts = .{},
    swept_by_tier: TierCounts = .{},
    sweep_reasons: SweepReasons = .{},
};

pub const CoverageWork = struct {
    records: usize = 0,
    owner_lookups: usize = 0,
    record_lookups: usize = 0,
    duplicate_checks: usize = 0,
};

pub const Artifact = struct {
    schema: []const u8 = schema,
    schema_version: u32 = schema_version,
    repository_id: []const u8,
    target_generation: []const u8,
    input_fingerprint: []const u8,
    fingerprint: []const u8,
    owners: []const Owner,
    ownership: []const Ownership,
    summary: Summary,
    complete: bool = true,
};

pub const Owned = struct {
    allocator: std.mem.Allocator,
    value: Artifact,

    pub fn deinit(self: *Owned) void {
        deinitArtifact(self.allocator, self.value);
        self.value.owners = &.{};
        self.value.ownership = &.{};
    }
};

pub const Reconciliation = struct {
    allocator: std.mem.Allocator,
    graph: model.RepositoryGraph,
    value: Artifact,

    pub fn deinit(self: *Reconciliation) void {
        self.graph.deinit();
        deinitArtifact(self.allocator, self.value);
        self.value.owners = &.{};
        self.value.ownership = &.{};
    }

    pub fn bindTargetGeneration(self: *Reconciliation, target_generation: []const u8) !void {
        if (!validGenerationId(target_generation)) return error.InvalidOriginGeneration;
        self.allocator.free(self.value.target_generation);
        self.value.target_generation = try memory.copy(u8, self.allocator, target_generation);
        self.allocator.free(self.value.fingerprint);
        self.value.fingerprint = try artifactFingerprintAlloc(self.allocator, self.value);
    }
};

pub const ReconcileInput = struct {
    repository_id: []const u8,
    native_graph: *const model.RepositoryGraph,
    current_sources: []const discovery.Record,
    previous_graph: ?*const model.RepositoryGraph = null,
    previous: ?Artifact = null,
    overlays: []const Overlay = &.{},
    options: model.Options = .{},
};

const Builder = struct {
    allocator: std.mem.Allocator,
    graph: model.RepositoryGraph,
    owners: std.ArrayList(Owner) = .empty,
    ownership: std.ArrayList(Ownership) = .empty,
    record_keys: std.AutoHashMapUnmanaged([32]u8, void) = .empty,
    summary: Summary = .{},

    fn deinit(self: *Builder) void {
        self.record_keys.deinit(self.allocator);
        self.graph.deinit();
        for (self.ownership.items) |entry| self.allocator.free(entry.owner_id);
        self.ownership.deinit(self.allocator);
        for (self.owners.items) |owner| deinitOwner(self.allocator, owner);
        self.owners.deinit(self.allocator);
    }
};

const DependencyState = enum {
    valid,
    changed,
    deleted,
    excluded,
};

pub fn reconcile(allocator: std.mem.Allocator, input: ReconcileInput) !Reconciliation {
    if (input.repository_id.len == 0 or input.overlays.len > max_owners) return error.InvalidOriginInput;
    try input.native_graph.validateSemanticRecords();
    try semantic_recipes.validateGraph(input.native_graph);
    try input.native_graph.validateSecondaryIndexes();

    var builder = Builder{
        .allocator = allocator,
        .graph = try delta_journal.canonicalClone(allocator, input.native_graph, input.options),
    };
    defer builder.deinit();

    const native_digest = try freshness.fingerprint(allocator, input.native_graph);
    var native_fingerprint: [71]u8 = @splat(0);
    native_fingerprint[0..7].* = "sha256:".*;
    native_fingerprint[7..].* = std.fmt.bytesToHex(native_digest, .lower);
    try assignNativeRecords(&builder, input.native_graph, &native_fingerprint);

    if (input.previous != null and input.previous_graph == null) return error.OriginPreviousGraphMissing;
    if (input.previous) |previous| {
        try validate(input.previous_graph.?, previous);
        try carryPrevious(&builder, input.current_sources, input.previous_graph.?, previous, input.overlays);
    }
    try applyOverlays(&builder, input.current_sources, input.overlays);

    var canonical = try delta_journal.canonicalClone(allocator, &builder.graph, input.options);
    errdefer canonical.deinit();
    builder.graph.deinit();
    builder.graph = try model.RepositoryGraph.init(allocator, input.options);

    std.mem.sort(Owner, builder.owners.items, {}, ownerLessThan);
    std.mem.sort(Ownership, builder.ownership.items, {}, ownershipLessThan);
    _ = try validateCoverage(&canonical, builder.owners.items, builder.ownership.items);
    builder.summary.owners = builder.owners.items.len;
    builder.summary.records = builder.ownership.items.len;
    builder.summary.owned_records = builder.ownership.items.len;
    builder.summary.nodes = canonical.nodeCount();
    builder.summary.edges = canonical.edgeCount();
    builder.summary.hyperedges = canonical.hyperedgeCount();
    builder.summary.supernodes = canonical.supernodeCount();
    if (builder.summary.active_by_tier.total() != builder.summary.records or
        builder.summary.swept_by_tier.total() != builder.summary.swept_records or
        builder.summary.sweep_reasons.total() != builder.summary.swept_records + builder.summary.replaced_records)
    {
        return error.InvalidOriginSummary;
    }

    const owners = try builder.owners.toOwnedSlice(allocator);
    errdefer {
        for (owners) |owner| deinitOwner(allocator, owner);
        allocator.free(owners);
    }
    const ownership = try builder.ownership.toOwnedSlice(allocator);
    errdefer {
        for (ownership) |entry| allocator.free(entry.owner_id);
        allocator.free(ownership);
    }
    const repository_id = try memory.copy(u8, allocator, input.repository_id);
    errdefer allocator.free(repository_id);
    const target_generation = try memory.copy(u8, allocator, "");
    errdefer allocator.free(target_generation);
    var artifact = Artifact{
        .repository_id = repository_id,
        .target_generation = target_generation,
        .input_fingerprint = "",
        .fingerprint = "",
        .owners = owners,
        .ownership = ownership,
        .summary = builder.summary,
    };
    artifact.input_fingerprint = try inputFingerprintAlloc(allocator, artifact);
    errdefer allocator.free(artifact.input_fingerprint);
    artifact.fingerprint = try memory.copy(u8, allocator, artifact.input_fingerprint);
    return .{ .allocator = allocator, .graph = canonical, .value = artifact };
}

pub const ValidateOptions = struct {
    /// Skip the graph checks this function would otherwise repeat.
    ///
    /// `validate` re-runs `validateSemanticRecords`, `semantic_recipes.validateGraph`
    /// and `validateSecondaryIndexes` on the caller's graph. That is right when
    /// the caller has not already done it, and pure repetition when it has — and
    /// on the read path it has, ten lines earlier, on the same graph object.
    /// Measured at 34 ms of a 55 ms validate on an 8,102-node graph.
    ///
    /// Off by default, so every existing caller keeps the checks. Passing true is
    /// a claim the caller must actually be able to make.
    graph_already_validated: bool = false,
};

pub fn validate(graph: *const model.RepositoryGraph, artifact: Artifact) !void {
    return validateWithOptions(graph, artifact, .{});
}

pub fn validateWithOptions(graph: *const model.RepositoryGraph, artifact: Artifact, options: ValidateOptions) !void {
    if (!artifact.complete or !std.mem.eql(u8, artifact.schema, schema) or artifact.schema_version != schema_version or
        artifact.repository_id.len == 0 or !validGenerationId(artifact.target_generation) or
        !validSha256Identity(artifact.input_fingerprint) or !validSha256Identity(artifact.fingerprint) or
        artifact.owners.len > max_owners or artifact.ownership.len > max_records)
    {
        return error.InvalidOriginArtifact;
    }
    if (!options.graph_already_validated) {
        try graph.validateSemanticRecords();
        try semantic_recipes.validateGraph(graph);
        try graph.validateSecondaryIndexes();
    }
    for (artifact.owners, 0..) |owner, index| {
        try validateOwner(graph.allocator, owner);
        if (index > 0 and !ownerLessThan({}, artifact.owners[index - 1], owner)) return error.NonCanonicalOriginOwners;
    }
    for (artifact.ownership, 0..) |entry, index| {
        try validateRecordRef(entry.record);
        if (index > 0 and !ownershipLessThan({}, artifact.ownership[index - 1], entry)) return error.NonCanonicalOriginRecords;
    }
    _ = try validateCoverage(graph, artifact.owners, artifact.ownership);
    const expected_summary = summarize(graph, artifact.owners, artifact.ownership, artifact.summary);
    if (!std.meta.eql(expected_summary, artifact.summary)) return error.InvalidOriginSummary;
    const input_fingerprint = try inputFingerprintAlloc(graph.allocator, artifact);
    defer graph.allocator.free(input_fingerprint);
    if (!std.mem.eql(u8, input_fingerprint, artifact.input_fingerprint)) return error.OriginInputFingerprintMismatch;
    const fingerprint = try artifactFingerprintAlloc(graph.allocator, artifact);
    defer graph.allocator.free(fingerprint);
    if (!std.mem.eql(u8, fingerprint, artifact.fingerprint)) return error.OriginFingerprintMismatch;
}

pub fn encodeAlloc(allocator: std.mem.Allocator, artifact: Artifact) ![]u8 {
    if (artifact.owners.len > max_owners or artifact.ownership.len > max_records) return error.OriginArtifactTooLarge;
    const bytes = try std.json.Stringify.valueAlloc(allocator, artifact, .{ .whitespace = .indent_2 });
    errdefer allocator.free(bytes);
    if (bytes.len > max_artifact_bytes) return error.OriginArtifactTooLarge;
    return bytes;
}

pub fn read(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, path: []const u8) !Owned {
    try validateArtifactPath(path);
    const bytes = try root.readFileAlloc(io, path, allocator, .limited(max_artifact_bytes));
    defer allocator.free(bytes);
    var parsed = std.json.parseFromSlice(Artifact, allocator, bytes, .{ .allocate = .alloc_always }) catch return error.CorruptOriginArtifact;
    defer parsed.deinit();
    return .{ .allocator = allocator, .value = try cloneArtifact(allocator, parsed.value) };
}

fn assignNativeRecords(builder: *Builder, graph: *const model.RepositoryGraph, fingerprint: []const u8) !void {
    for (graph.nodes.items) |node| {
        const tier = nativeNodeTier(node.kind);
        const owner_id = try ensureNativeOwner(builder, tier, fingerprint);
        try appendOwnership(builder, .{ .kind = .node, .id = node.id }, owner_id, tier, false);
    }
    for (graph.edges.items) |edge| {
        const tier = nativeEdgeTier(edge.relation);
        const owner_id = try ensureNativeOwner(builder, tier, fingerprint);
        try appendOwnership(builder, .{ .kind = .edge, .from = edge.from, .to = edge.to, .relation = edge.relation }, owner_id, tier, false);
    }
    for (graph.hyperedges.items) |hyperedge| {
        const owner_id = try ensureNativeOwner(builder, .resolver_recipe, fingerprint);
        try appendOwnership(builder, .{ .kind = .hyperedge, .id = hyperedge.id }, owner_id, .resolver_recipe, false);
    }
    for (graph.supernodes.items) |supernode| {
        const owner_id = try ensureNativeOwner(builder, .resolver_recipe, fingerprint);
        try appendOwnership(builder, .{ .kind = .supernode, .id = supernode.id }, owner_id, .resolver_recipe, false);
    }
}

fn carryPrevious(
    builder: *Builder,
    current_sources: []const discovery.Record,
    previous_graph: *const model.RepositoryGraph,
    previous: Artifact,
    overlays: []const Overlay,
) !void {
    inline for (.{ RecordKind.node, RecordKind.edge, RecordKind.hyperedge, RecordKind.supernode }) |phase| {
        for (previous.ownership) |entry| {
            if (entry.record.kind != phase) continue;
            const owner = findOwner(previous.owners, entry.owner_id) orelse return error.UnknownOriginOwner;
            if (isNativeOwner(owner.provider_id)) continue;
            if (overlayRefreshesOwner(overlays, owner.*)) {
                builder.summary.replaced_records += 1;
                builder.summary.sweep_reasons.owner_replaced += 1;
                continue;
            }
            const state = ownerDependencyState(owner.*, current_sources);
            if (state != .valid or owner.freshness != .current) {
                recordOwnerSweep(&builder.summary, owner.*, state);
                continue;
            }
            const copied = try copyRecord(builder, previous_graph, entry.record);
            if (!copied) {
                builder.summary.swept_records += 1;
                builder.summary.sweep_reasons.dangling_reference += 1;
                incrementTier(&builder.summary.swept_by_tier, owner.tier);
                continue;
            }
            const owner_id = try ensureOwner(builder, ownerInput(owner.*));
            try appendOwnership(builder, entry.record, owner_id, owner.tier, true);
        }
    }
}

fn applyOverlays(builder: *Builder, current_sources: []const discovery.Record, overlays: []const Overlay) !void {
    for (overlays) |overlay| {
        try validateOwnerInput(overlay.owner);
        if (overlay.owner.freshness != .current or ownerInputDependencyState(overlay.owner, current_sources) != .valid) {
            return error.ProviderDependencyMismatch;
        }
        try overlay.graph.validateSemanticRecords();
        try semantic_recipes.validateGraph(overlay.graph);
        try overlay.graph.validateSecondaryIndexes();
        try validateOverlayCoverage(&builder.graph, overlay);
        const owner_id = try ensureOwner(builder, overlay.owner);
        inline for (.{ RecordKind.node, RecordKind.edge, RecordKind.hyperedge, RecordKind.supernode }) |phase| {
            for (overlay.owned_records) |record| {
                if (record.kind != phase) continue;
                if (!recordExists(overlay.graph, record)) return error.OwnedOverlayRecordMissing;
                const copied = try copyRecord(builder, overlay.graph, record);
                if (!copied) return error.InvalidOverlayReference;
                try appendOwnership(builder, record, owner_id, overlay.owner.tier, false);
            }
        }
    }
}

fn validateOverlayCoverage(candidate: *const model.RepositoryGraph, overlay: Overlay) !void {
    if (overlay.owned_records.len == 0 and recordCount(overlay.graph) != 0) return error.UnownedOverlayRecord;
    for (overlay.owned_records, 0..) |record, index| {
        try validateRecordRef(record);
        if (index > 0) for (overlay.owned_records[0..index]) |prior| if (recordEqual(prior, record)) return error.DuplicateOverlayOwnership;
    }
    for (overlay.graph.nodes.items) |node| {
        const ref = RecordRef{ .kind = .node, .id = node.id };
        if (!containsRecord(overlay.owned_records, ref) and !recordExists(candidate, ref)) return error.UnownedOverlayRecord;
    }
    for (overlay.graph.edges.items) |edge| {
        const ref = RecordRef{ .kind = .edge, .from = edge.from, .to = edge.to, .relation = edge.relation };
        if (!containsRecord(overlay.owned_records, ref) and !recordExists(candidate, ref)) return error.UnownedOverlayRecord;
    }
    for (overlay.graph.hyperedges.items) |hyperedge| {
        const ref = RecordRef{ .kind = .hyperedge, .id = hyperedge.id };
        if (!containsRecord(overlay.owned_records, ref) and !recordExists(candidate, ref)) return error.UnownedOverlayRecord;
    }
    for (overlay.graph.supernodes.items) |supernode| {
        const ref = RecordRef{ .kind = .supernode, .id = supernode.id };
        if (!containsRecord(overlay.owned_records, ref) and !recordExists(candidate, ref)) return error.UnownedOverlayRecord;
    }
}

fn copyRecord(builder: *Builder, source: *const model.RepositoryGraph, record: RecordRef) !bool {
    switch (record.kind) {
        .node => {
            const source_node = source.findNode(record.id) orelse return error.OriginRecordMissing;
            if (builder.graph.findNode(record.id)) |existing| {
                if (!equalNode(source, source_node.*, &builder.graph, existing.*)) return error.OriginRecordCollision;
                return error.ConflictingRecordOwnership;
            }
            const source_index = source.topology.findNodeIndex(record.id) orelse return error.OriginRecordMissing;
            const id = try builder.graph.addNode(.{
                .id = source_node.id,
                .kind = source_node.kind,
                .label = source_node.label,
                .path = source_node.path,
                .line = source_node.line,
                .search_text = source_node.search_text,
            });
            setEmbedding(&builder.graph, id, source.vectorAt(@intCast(source_index)));
            return true;
        },
        .edge => {
            const edge = findEdge(source, record) orelse return error.OriginRecordMissing;
            if (builder.graph.findNode(edge.from) == null or builder.graph.findNode(edge.to) == null) return false;
            if (findEdge(&builder.graph, record)) |existing| {
                if (!equalEdge(existing.*, edge.*)) return error.OriginRecordCollision;
                return error.ConflictingRecordOwnership;
            }
            try builder.graph.addEdge(edge.*);
            return true;
        },
        .hyperedge => {
            const hyperedge = source.findHyperedge(record.id) orelse return error.OriginRecordMissing;
            for (hyperedge.participants) |participant| if (builder.graph.findNode(participant.node_id) == null) return false;
            if (builder.graph.findHyperedge(record.id) != null) return error.ConflictingRecordOwnership;
            _ = try builder.graph.addHyperedge(.{
                .id = hyperedge.id,
                .kind = hyperedge.kind,
                .canonical_name = hyperedge.canonical_name,
                .recipe = hyperedge.recipe,
                .interaction_fingerprint = hyperedge.interaction_fingerprint,
                .participants = hyperedge.participants,
                .evidence = hyperedge.evidence,
            });
            return true;
        },
        .supernode => {
            const supernode = findSupernode(source, record.id) orelse return error.OriginRecordMissing;
            if (builder.graph.findHyperedge(supernode.input_hyperedge_id) == null) return false;
            for (supernode.members) |member| if (builder.graph.findNode(member.node_id) == null) return false;
            for (supernode.proof_steps) |step| if (!builder.graph.hasEdge(step.from, step.to, step.relation)) return false;
            if (findSupernode(&builder.graph, record.id) != null) return error.ConflictingRecordOwnership;
            _ = try builder.graph.addSupernode(.{
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
            return true;
        },
    }
}

fn ensureNativeOwner(builder: *Builder, tier: Tier, fingerprint: []const u8) ![]const u8 {
    return ensureOwner(builder, .{
        .tier = tier,
        .provider_id = nativeProviderId(tier),
        .provider_fingerprint = fingerprint,
        .freshness = .current,
        .authority = .repository_read,
    });
}

fn ensureOwner(builder: *Builder, input: OwnerInput) ![]const u8 {
    try validateOwnerInput(input);
    const id = try ownerIdAlloc(builder.allocator, input.tier, input.provider_id);
    defer builder.allocator.free(id);
    for (builder.owners.items) |owner| if (std.mem.eql(u8, owner.id, id)) {
        if (owner.tier != input.tier or !std.mem.eql(u8, owner.provider_id, input.provider_id) or
            !std.mem.eql(u8, owner.provider_fingerprint, input.provider_fingerprint) or owner.freshness != input.freshness or
            owner.authority != input.authority or !dependenciesEqual(owner.dependencies, input.dependencies))
        {
            return error.ConflictingOriginOwner;
        }
        return owner.id;
    };
    if (builder.owners.items.len >= max_owners) return error.OriginOwnerLimitExceeded;
    const owned = try cloneOwnerInput(builder.allocator, id, input);
    errdefer deinitOwner(builder.allocator, owned);
    try builder.owners.append(builder.allocator, owned);
    return builder.owners.items[builder.owners.items.len - 1].id;
}

fn appendOwnership(builder: *Builder, record: RecordRef, owner_id: []const u8, tier: Tier, carried: bool) !void {
    try validateRecordRef(record);
    if (builder.ownership.items.len >= max_records) return error.OriginRecordLimitExceeded;
    const key = recordKey(record);
    const indexed = try builder.record_keys.getOrPut(builder.allocator, key);
    if (indexed.found_existing) return error.ConflictingRecordOwnership;
    indexed.value_ptr.* = {};
    errdefer _ = builder.record_keys.remove(key);
    const copied_owner = try memory.copy(u8, builder.allocator, owner_id);
    errdefer builder.allocator.free(copied_owner);
    try builder.ownership.append(builder.allocator, .{
        .record = record,
        .owner_id = copied_owner,
    });
    incrementTier(&builder.summary.active_by_tier, tier);
    if (carried) builder.summary.carried_records += 1;
}

pub fn validateCoverage(graph: *const model.RepositoryGraph, owners: []const Owner, ownership: []const Ownership) !CoverageWork {
    if (ownership.len != recordCount(graph)) return error.UnownedActiveRecord;
    var owner_ids = std.StringHashMap(void).init(graph.allocator);
    defer owner_ids.deinit();
    for (owners) |owner| {
        const indexed = try owner_ids.getOrPut(owner.id);
        if (indexed.found_existing) return error.ConflictingOriginOwner;
        indexed.value_ptr.* = {};
    }
    var records = std.AutoHashMap([32]u8, void).init(graph.allocator);
    defer records.deinit();
    try records.ensureTotalCapacity(@intCast(ownership.len));
    var work = CoverageWork{};
    for (ownership) |entry| {
        work.owner_lookups += 1;
        if (!owner_ids.contains(entry.owner_id)) return error.UnknownOriginOwner;
        work.record_lookups += 1;
        if (!recordExists(graph, entry.record)) return error.InvalidOriginCoverage;
        work.duplicate_checks += 1;
        const indexed = try records.getOrPut(recordKey(entry.record));
        if (indexed.found_existing) return error.ConflictingRecordOwnership;
        indexed.value_ptr.* = {};
        work.records += 1;
    }
    if (records.count() != recordCount(graph)) return error.UnownedActiveRecord;
    return work;
}

fn summarize(graph: *const model.RepositoryGraph, owners: []const Owner, ownership: []const Ownership, retained: Summary) Summary {
    var result = retained;
    result.owners = owners.len;
    result.records = ownership.len;
    result.owned_records = ownership.len;
    result.nodes = graph.nodeCount();
    result.edges = graph.edgeCount();
    result.hyperedges = graph.hyperedgeCount();
    result.supernodes = graph.supernodeCount();
    result.active_by_tier = .{};
    for (ownership) |entry| {
        const owner = findOwner(owners, entry.owner_id) orelse continue;
        incrementTier(&result.active_by_tier, owner.tier);
    }
    return result;
}

fn recordOwnerSweep(summary: *Summary, owner: Owner, state: DependencyState) void {
    summary.swept_records += 1;
    incrementTier(&summary.swept_by_tier, owner.tier);
    if (owner.freshness == .stale) {
        summary.sweep_reasons.provider_stale += 1;
    } else if (owner.freshness == .incompatible) {
        summary.sweep_reasons.provider_incompatible += 1;
    } else switch (state) {
        .changed => summary.sweep_reasons.dependency_changed += 1,
        .deleted => summary.sweep_reasons.dependency_deleted += 1,
        .excluded => summary.sweep_reasons.dependency_excluded += 1,
        .valid => summary.sweep_reasons.reconciled_absent += 1,
    }
}

fn ownerDependencyState(owner: Owner, current: []const discovery.Record) DependencyState {
    return dependenciesState(owner.dependencies, current);
}

fn ownerInputDependencyState(owner: OwnerInput, current: []const discovery.Record) DependencyState {
    return dependenciesState(owner.dependencies, current);
}

fn dependenciesState(dependencies: []const Dependency, current: []const discovery.Record) DependencyState {
    for (dependencies) |dependency| {
        const record = findDiscoveryRecord(current, dependency.path) orelse return .deleted;
        if (!graphBearingDisposition(record.disposition)) return .excluded;
        const digest = record.content_digest orelse return .changed;
        if (!std.mem.eql(u8, &digest, &dependency.content_digest)) return .changed;
    }
    return .valid;
}

fn findDiscoveryRecord(records: []const discovery.Record, path: []const u8) ?*const discovery.Record {
    for (records) |*record| if (std.mem.eql(u8, record.relative_path, path)) return record;
    return null;
}

fn graphBearingDisposition(disposition: discovery.Disposition) bool {
    return disposition == .deeply_indexed or disposition == .placed_unsupported or disposition == .placed_asset;
}

fn overlayRefreshesOwner(overlays: []const Overlay, owner: Owner) bool {
    for (overlays) |overlay| {
        if (overlay.owner.tier == owner.tier and std.mem.eql(u8, overlay.owner.provider_id, owner.provider_id)) return true;
    }
    return false;
}

fn ownerInput(owner: Owner) OwnerInput {
    return .{
        .tier = owner.tier,
        .provider_id = owner.provider_id,
        .provider_fingerprint = owner.provider_fingerprint,
        .freshness = owner.freshness,
        .authority = owner.authority,
        .dependencies = owner.dependencies,
    };
}

fn nativeNodeTier(kind: model.NodeKind) Tier {
    return switch (kind) {
        .concept => .source_documentation,
        .workspace, .package, .application, .library, .component => .manifest,
        .build_target, .api_surface => .build_contract,
        .requirement, .acceptance_check, .command, .test_scenario => .zigeffect_metadata,
        .causal_event => .runtime_causal,
        .external_module, .module_reference => .resolver_recipe,
        else => .source_syntax,
    };
}

fn nativeEdgeTier(relation: model.Relation) Tier {
    return switch (relation) {
        .satisfies, .verified_by, .executes, .covers, .source_root, .causal_parent, .observed_at => .zigeffect_metadata,
        .resolves_to,
        .imports_from,
        .re_exports,
        .aliases,
        .dispatches_to,
        .generated_from,
        .generated_client_for,
        .generated_server_for,
        .invokes_operation,
        .handles_operation,
        .passes_callback,
        => .resolver_recipe,
        .part_of_target => .build_contract,
        else => .source_syntax,
    };
}

fn nativeProviderId(tier: Tier) []const u8 {
    return switch (tier) {
        .source_syntax => "zgraphy/native/source-syntax",
        .source_documentation => "zgraphy/native/source-documentation",
        .manifest => "zgraphy/native/manifest",
        .build_contract => "zgraphy/native/build-contract",
        .version_control => "zgraphy/native/version-control",
        .zigeffect_metadata => "zgraphy/native/zigeffect-metadata",
        .compiler_index => "zgraphy/native/compiler-index",
        .runtime_causal => "zgraphy/native/runtime-causal",
        .resolver_recipe => "zgraphy/native/resolver-recipe",
        .model_suggestion => "zgraphy/native/model-suggestion",
        .human_confirmation => "zgraphy/native/human-confirmation",
        .historical_lineage => "zgraphy/native/historical-lineage",
    };
}

fn isNativeOwner(provider_id: []const u8) bool {
    return std.mem.startsWith(u8, provider_id, "zgraphy/native/");
}

fn validateOwnerInput(input: OwnerInput) !void {
    if (!validProviderId(input.provider_id) or !validSha256Identity(input.provider_fingerprint) or input.dependencies.len > max_dependencies) {
        return error.InvalidOriginOwner;
    }
    if ((input.tier == .human_confirmation and input.authority != .user_pin and input.authority != .provider_read) or
        (input.tier == .runtime_causal and input.authority == .user_pin)) return error.InvalidOriginAuthority;
    for (input.dependencies, 0..) |dependency, index| {
        if (!validRelativePath(dependency.path)) return error.InvalidOriginDependency;
        for (input.dependencies[0..index]) |prior| if (std.mem.eql(u8, prior.path, dependency.path)) return error.DuplicateOriginDependency;
    }
}

fn validateOwner(allocator: std.mem.Allocator, owner: Owner) !void {
    try validateOwnerInput(ownerInput(owner));
    const expected = try ownerIdAlloc(allocator, owner.tier, owner.provider_id);
    defer allocator.free(expected);
    if (!std.mem.eql(u8, expected, owner.id)) return error.InvalidOriginOwnerId;
}

fn validateRecordRef(record: RecordRef) !void {
    switch (record.kind) {
        .node, .hyperedge, .supernode => if (record.id == 0 or record.from != 0 or record.to != 0) return error.InvalidOriginRecordRef,
        .edge => if (record.id != 0 or record.from == 0 or record.to == 0) return error.InvalidOriginRecordRef,
    }
}

fn validProviderId(value: []const u8) bool {
    if (value.len == 0 or value.len > max_provider_id_bytes or std.mem.indexOf(u8, value, "..") != null or
        std.mem.indexOf(u8, value, "://") != null or std.mem.indexOfScalar(u8, value, '\\') != null)
    {
        return false;
    }
    for (value) |byte| if (byte < 0x21 or byte == 0x7f) return false;
    return true;
}

fn validRelativePath(value: []const u8) bool {
    if (value.len == 0 or value[0] == '/' or std.mem.indexOfScalar(u8, value, '\\') != null or std.mem.indexOfScalar(u8, value, 0) != null) return false;
    var parts = std.mem.splitScalar(u8, value, '/');
    while (parts.next()) |part| if (part.len == 0 or std.mem.eql(u8, part, ".") or std.mem.eql(u8, part, "..")) return false;
    return true;
}

fn validateArtifactPath(path: []const u8) !void {
    if (!validRelativePath(path)) return error.InvalidOriginArtifactPath;
}

fn validSha256Identity(value: []const u8) bool {
    if (value.len != 71 or !std.mem.startsWith(u8, value, "sha256:")) return false;
    for (value[7..]) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}

fn validGenerationId(value: []const u8) bool {
    if (value.len != 66 or !std.mem.startsWith(u8, value, "g-")) return false;
    for (value[2..]) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}

fn ownerIdAlloc(allocator: std.mem.Allocator, tier: Tier, provider_id: []const u8) ![]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(schema);
    const tier_byte = [1]u8{@intFromEnum(tier)};
    hasher.update(&tier_byte);
    hasher.update(provider_id);
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    const hex = std.fmt.bytesToHex(digest, .lower);
    return std.fmt.allocPrint(allocator, "sha256:{s}", .{hex});
}

fn inputFingerprintAlloc(allocator: std.mem.Allocator, artifact: Artifact) ![]u8 {
    const payload = .{
        .schema = artifact.schema,
        .schema_version = artifact.schema_version,
        .repository_id = artifact.repository_id,
        .owners = artifact.owners,
        .ownership = artifact.ownership,
        .summary = artifact.summary,
        .complete = artifact.complete,
    };
    const bytes = try std.json.Stringify.valueAlloc(allocator, payload, .{});
    defer allocator.free(bytes);
    return sha256IdentityAlloc(allocator, bytes);
}

fn artifactFingerprintAlloc(allocator: std.mem.Allocator, artifact: Artifact) ![]u8 {
    const payload = .{
        .schema = artifact.schema,
        .schema_version = artifact.schema_version,
        .repository_id = artifact.repository_id,
        .target_generation = artifact.target_generation,
        .input_fingerprint = artifact.input_fingerprint,
        .owners = artifact.owners,
        .ownership = artifact.ownership,
        .summary = artifact.summary,
        .complete = artifact.complete,
    };
    const bytes = try std.json.Stringify.valueAlloc(allocator, payload, .{});
    defer allocator.free(bytes);
    return sha256IdentityAlloc(allocator, bytes);
}

fn sha256IdentityAlloc(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var digest: [32]u8 = @splat(0);
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    return std.fmt.allocPrint(allocator, "sha256:{s}", .{hex});
}

fn cloneOwnerInput(allocator: std.mem.Allocator, id: []const u8, input: OwnerInput) !Owner {
    const owned_id = try memory.copy(u8, allocator, id);
    errdefer allocator.free(owned_id);
    const provider_id = try memory.copy(u8, allocator, input.provider_id);
    errdefer allocator.free(provider_id);
    const provider_fingerprint = try memory.copy(u8, allocator, input.provider_fingerprint);
    errdefer allocator.free(provider_fingerprint);
    const dependencies = try cloneDependencies(allocator, input.dependencies);
    errdefer deinitDependencies(allocator, dependencies);
    return .{
        .id = owned_id,
        .tier = input.tier,
        .provider_id = provider_id,
        .provider_fingerprint = provider_fingerprint,
        .freshness = input.freshness,
        .authority = input.authority,
        .dependencies = dependencies,
    };
}

fn cloneDependencies(allocator: std.mem.Allocator, input: []const Dependency) ![]Dependency {
    const result = try memory.slice(Dependency, allocator, input.len);
    errdefer allocator.free(result);
    var initialized: usize = 0;
    errdefer for (result[0..initialized]) |dependency| allocator.free(dependency.path);
    for (input, 0..) |dependency, index| {
        result[index] = .{
            .path = try memory.copy(u8, allocator, dependency.path),
            .content_digest = dependency.content_digest,
        };
        initialized += 1;
    }
    std.mem.sort(Dependency, result, {}, struct {
        fn lessThan(_: void, left: Dependency, right: Dependency) bool {
            return std.mem.lessThan(u8, left.path, right.path);
        }
    }.lessThan);
    return result;
}

fn cloneArtifact(allocator: std.mem.Allocator, input: Artifact) !Artifact {
    const repository_id = try memory.copy(u8, allocator, input.repository_id);
    errdefer allocator.free(repository_id);
    const target_generation = try memory.copy(u8, allocator, input.target_generation);
    errdefer allocator.free(target_generation);
    const input_fingerprint = try memory.copy(u8, allocator, input.input_fingerprint);
    errdefer allocator.free(input_fingerprint);
    const fingerprint = try memory.copy(u8, allocator, input.fingerprint);
    errdefer allocator.free(fingerprint);
    const owners = try memory.slice(Owner, allocator, input.owners.len);
    errdefer allocator.free(owners);
    var owner_count: usize = 0;
    errdefer for (owners[0..owner_count]) |owner| deinitOwner(allocator, owner);
    for (input.owners, 0..) |owner, index| {
        owners[index] = try cloneOwnerInput(allocator, owner.id, ownerInput(owner));
        owner_count += 1;
    }
    const ownership = try memory.slice(Ownership, allocator, input.ownership.len);
    errdefer allocator.free(ownership);
    var ownership_count: usize = 0;
    errdefer for (ownership[0..ownership_count]) |entry| allocator.free(entry.owner_id);
    for (input.ownership, 0..) |entry, index| {
        ownership[index] = .{ .record = entry.record, .owner_id = try memory.copy(u8, allocator, entry.owner_id) };
        ownership_count += 1;
    }
    return .{
        .repository_id = repository_id,
        .target_generation = target_generation,
        .input_fingerprint = input_fingerprint,
        .fingerprint = fingerprint,
        .owners = owners,
        .ownership = ownership,
        .summary = input.summary,
        .complete = input.complete,
    };
}

fn deinitArtifact(allocator: std.mem.Allocator, artifact: Artifact) void {
    allocator.free(artifact.repository_id);
    allocator.free(artifact.target_generation);
    allocator.free(artifact.input_fingerprint);
    allocator.free(artifact.fingerprint);
    for (artifact.ownership) |entry| allocator.free(entry.owner_id);
    allocator.free(artifact.ownership);
    for (artifact.owners) |owner| deinitOwner(allocator, owner);
    allocator.free(artifact.owners);
}

fn deinitOwner(allocator: std.mem.Allocator, owner: Owner) void {
    allocator.free(owner.id);
    allocator.free(owner.provider_id);
    allocator.free(owner.provider_fingerprint);
    deinitDependencies(allocator, owner.dependencies);
}

fn deinitDependencies(allocator: std.mem.Allocator, dependencies: []const Dependency) void {
    for (dependencies) |dependency| allocator.free(dependency.path);
    allocator.free(dependencies);
}

fn dependenciesEqual(left: []const Dependency, right: []const Dependency) bool {
    if (left.len != right.len) return false;
    for (left, right) |a, b| if (!std.mem.eql(u8, a.path, b.path) or !std.mem.eql(u8, &a.content_digest, &b.content_digest)) return false;
    return true;
}

fn findOwner(owners: []const Owner, id: []const u8) ?*const Owner {
    for (owners) |*owner| if (std.mem.eql(u8, owner.id, id)) return owner;
    return null;
}

fn ownershipIndex(entries: []const Ownership, record: RecordRef) ?usize {
    for (entries, 0..) |entry, index| if (recordEqual(entry.record, record)) return index;
    return null;
}

fn containsRecord(records: []const RecordRef, expected: RecordRef) bool {
    for (records) |record| if (recordEqual(record, expected)) return true;
    return false;
}

fn recordKey(record: RecordRef) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(schema);
    const kind = [1]u8{@intFromEnum(record.kind)};
    hasher.update(&kind);
    var bytes: [8]u8 = @splat(0);
    std.mem.writeInt(u64, &bytes, record.id, .little);
    hasher.update(&bytes);
    std.mem.writeInt(u64, &bytes, record.from, .little);
    hasher.update(&bytes);
    std.mem.writeInt(u64, &bytes, record.to, .little);
    hasher.update(&bytes);
    var relation: [2]u8 = @splat(0);
    std.mem.writeInt(u16, &relation, @intFromEnum(record.relation), .little);
    hasher.update(&relation);
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    return digest;
}

fn recordExists(graph: *const model.RepositoryGraph, record: RecordRef) bool {
    return switch (record.kind) {
        .node => graph.findNode(record.id) != null,
        .edge => graph.hasEdge(record.from, record.to, record.relation),
        .hyperedge => graph.findHyperedge(record.id) != null,
        .supernode => findSupernode(graph, record.id) != null,
    };
}

fn findEdge(graph: *const model.RepositoryGraph, record: RecordRef) ?*const model.Edge {
    for (graph.edges.items) |*edge| if (edge.from == record.from and edge.to == record.to and edge.relation == record.relation) return edge;
    return null;
}

fn findSupernode(graph: *const model.RepositoryGraph, id: u64) ?*const model.Supernode {
    for (graph.supernodes.items) |*supernode| if (supernode.id == id) return supernode;
    return null;
}

fn equalNode(left_graph: *const model.RepositoryGraph, left: model.Node, right_graph: *const model.RepositoryGraph, right: model.Node) bool {
    if (left.id != right.id or left.kind != right.kind or left.line != right.line or !std.mem.eql(u8, left.label, right.label) or
        !std.mem.eql(u8, left.path, right.path) or !std.mem.eql(u8, left.search_text, right.search_text)) return false;
    const left_index = left_graph.topology.findNodeIndex(left.id) orelse return false;
    const right_index = right_graph.topology.findNodeIndex(right.id) orelse return false;
    return std.mem.eql(f32, left_graph.vectorAt(left_index), right_graph.vectorAt(right_index));
}

fn equalEdge(left: model.Edge, right: model.Edge) bool {
    return left.from == right.from and left.to == right.to and left.relation == right.relation and left.provenance == right.provenance and
        left.line == right.line and std.mem.eql(u8, left.source_path, right.source_path);
}

fn setEmbedding(graph: *model.RepositoryGraph, id: u64, embedding: []const f32) void {
    const index = graph.topology.findNodeIndex(id) orelse return;
    const start = @as(usize, index) * nendb.embedding_dimensions;
    @memcpy(graph.topology.vectors[start .. start + nendb.embedding_dimensions], embedding);
}

fn recordCount(graph: *const model.RepositoryGraph) usize {
    return graph.nodeCount() + graph.edgeCount() + graph.hyperedgeCount() + graph.supernodeCount();
}

fn incrementTier(counts: *TierCounts, tier: Tier) void {
    switch (tier) {
        .source_syntax => counts.source_syntax += 1,
        .source_documentation => counts.source_documentation += 1,
        .manifest => counts.manifest += 1,
        .build_contract => counts.build_contract += 1,
        .version_control => counts.version_control += 1,
        .zigeffect_metadata => counts.zigeffect_metadata += 1,
        .compiler_index => counts.compiler_index += 1,
        .runtime_causal => counts.runtime_causal += 1,
        .resolver_recipe => counts.resolver_recipe += 1,
        .model_suggestion => counts.model_suggestion += 1,
        .human_confirmation => counts.human_confirmation += 1,
        .historical_lineage => counts.historical_lineage += 1,
    }
}

fn recordEqual(left: RecordRef, right: RecordRef) bool {
    return left.kind == right.kind and left.id == right.id and left.from == right.from and left.to == right.to and
        (left.kind != .edge or left.relation == right.relation);
}

fn recordOrder(left: RecordRef, right: RecordRef) std.math.Order {
    if (left.kind != right.kind) return std.math.order(@intFromEnum(left.kind), @intFromEnum(right.kind));
    if (left.id != right.id) return std.math.order(left.id, right.id);
    if (left.from != right.from) return std.math.order(left.from, right.from);
    if (left.to != right.to) return std.math.order(left.to, right.to);
    return std.math.order(@intFromEnum(left.relation), @intFromEnum(right.relation));
}

fn ownerLessThan(_: void, left: Owner, right: Owner) bool {
    return std.mem.lessThan(u8, left.id, right.id);
}

fn ownershipLessThan(_: void, left: Ownership, right: Ownership) bool {
    const order = recordOrder(left.record, right.record);
    if (order != .eq) return order == .lt;
    return std.mem.lessThan(u8, left.owner_id, right.owner_id);
}
