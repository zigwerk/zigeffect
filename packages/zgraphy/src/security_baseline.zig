const std = @import("std");

pub const schema = "zgraphy.security-baseline.v1";
pub const schema_version: u32 = 1;
pub const embedded_bytes = @embedFile("security-baseline.v1.json");

pub const Maturity = enum { baseline };
pub const Severity = enum { low, medium, high, critical };
pub const ControlMaturity = enum { implemented, contract_only, planned, deferred, not_applicable };
pub const Disposition = enum { mitigated, partial, contract_only, planned, deferred, not_applicable };
pub const EvidenceState = enum { exercised, contract_exercised, planned, deferred, not_applicable };

pub const Boundary = enum {
    repository_content,
    filesystem,
    configuration_authority,
    parser_converter,
    persistence_migration,
    provider_external,
    agent_output,
    runtime_causal,
    export_integration,
};

pub const Asset = enum {
    user_files,
    secrets_credentials,
    canonical_truth,
    provenance,
    active_generations,
    availability,
    agent_context,
    external_systems,
    owned_state,
};

pub const FixtureKind = enum {
    source_tree,
    resource_limit,
    contract_mutation,
    structured_input,
    snapshot,
    provider_fake,
    exporter,
    absence_guard,
    freshness,
    causal_input,
};

pub const Reference = struct {
    id: []const u8,
    path: []const u8,
    sha256: []const u8,
    line_start: u32,
    line_end: u32,
};

pub const GraphifyBaseline = struct {
    version: []const u8,
    commit: []const u8,
    references: []Reference,
};

pub const Control = struct {
    id: []const u8,
    maturity: ControlMaturity,
};

pub const Threat = struct {
    id: []const u8,
    title: []const u8,
    severity: Severity,
    boundaries: []Boundary,
    assets: []Asset,
    control_ids: []const []const u8,
    graphify_reference_ids: []const []const u8,
    fixture_ids: []const []const u8,
    disposition: Disposition,
    milestone: []const u8,
    residual_risk: []const u8,
};

pub const Fixture = struct {
    id: []const u8,
    threat_ids: []const []const u8,
    kind: FixtureKind,
    evidence_state: EvidenceState,
    path: []const u8,
    scenario: []const u8,
    expected_behavior: []const u8,
    milestone: []const u8,
};

pub const Contract = struct {
    schema: []const u8,
    schema_version: u32,
    maturity: Maturity,
    graphify: GraphifyBaseline,
    boundaries: []Boundary,
    assets: []Asset,
    controls: []Control,
    threats: []Threat,
    fixtures: []Fixture,
};

pub const Summary = struct {
    total: usize = 0,
    exercised: usize = 0,
    contract_exercised: usize = 0,
    planned: usize = 0,
    deferred: usize = 0,
    not_applicable: usize = 0,
    unowned_high_or_critical: usize = 0,
};

pub const required_threat_ids = [_][]const u8{
    "ZG-THR-001", "ZG-THR-002", "ZG-THR-003", "ZG-THR-004", "ZG-THR-005",
    "ZG-THR-006", "ZG-THR-007", "ZG-THR-008", "ZG-THR-009", "ZG-THR-010",
    "ZG-THR-011", "ZG-THR-012", "ZG-THR-013", "ZG-THR-014", "ZG-THR-015",
    "ZG-THR-016", "ZG-THR-017", "ZG-THR-018", "ZG-THR-019", "ZG-THR-020",
};

const required_control_ids = [_][]const u8{
    "relative_path_validation",     "no_follow_symlinks",       "owned_root_writes",   "pre_read_size_caps",
    "aggregate_resource_bounds",    "object_count_bounds",      "bounded_parser",      "binary_encoding_handling",
    "strict_json_schema",           "transactional_generation", "snapshot_integrity",  "sensitive_redaction",
    "untrusted_content_delimiting", "output_escaping",          "ssrf_validation",     "structured_argv",
    "explicit_capabilities",        "read_only_external",       "unit_reconciliation", "freshness_barrier",
    "rollback_retention",           "causal_allowlist",         "bounded_diagnostics", "owned_export_paths",
};

const required_reference_ids = [_][]const u8{
    "graphify-security-policy",
    "graphify-security-module",
    "graphify-llm-boundary",
    "graphify-detector",
    "graphify-security-tests",
};

pub fn parseEmbedded(allocator: std.mem.Allocator) !std.json.Parsed(Contract) {
    return std.json.parseFromSlice(Contract, allocator, embedded_bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = false,
    });
}

pub fn validate(contract: *const Contract) !void {
    if (!std.mem.eql(u8, contract.schema, schema) or contract.schema_version != schema_version or contract.maturity != .baseline) {
        return error.IncompatibleSecurityBaseline;
    }
    try validateGraphify(&contract.graphify);
    try exactEnumDeclaration(Boundary, contract.boundaries, error.IncompleteSecurityBoundaries);
    try exactEnumDeclaration(Asset, contract.assets, error.IncompleteSecurityAssets);
    try validateControls(contract.controls);
    try validateThreats(contract);
    try validateFixtures(contract);
    try validatePromotions(contract);
}

pub fn catalogDigest() [32]u8 {
    var digest: [32]u8 = @splat(0);
    std.crypto.hash.sha2.Sha256.hash(embedded_bytes, &digest, .{});
    return digest;
}

pub fn findThreat(contract: *const Contract, id: []const u8) ?*const Threat {
    for (contract.threats, 0..) |threat, index| if (std.mem.eql(u8, threat.id, id)) return &contract.threats[index];
    return null;
}

pub fn summarize(contract: *const Contract) Summary {
    var summary = Summary{ .total = contract.threats.len };
    for (contract.fixtures) |fixture| switch (fixture.evidence_state) {
        .exercised => summary.exercised += 1,
        .contract_exercised => summary.contract_exercised += 1,
        .planned => summary.planned += 1,
        .deferred => summary.deferred += 1,
        .not_applicable => summary.not_applicable += 1,
    };
    for (contract.threats) |threat| {
        if ((threat.severity == .high or threat.severity == .critical) and
            (threat.milestone.len == 0 or threat.control_ids.len == 0 or threat.fixture_ids.len == 0))
        {
            summary.unowned_high_or_critical += 1;
        }
    }
    return summary;
}

pub fn validateEvidencePaths(
    allocator: std.mem.Allocator,
    io: std.Io,
    package_root: std.Io.Dir,
    contract: *const Contract,
) !void {
    for (contract.graphify.references) |reference| {
        const bytes = try package_root.readFileAlloc(io, reference.path, allocator, .limited(8 * 1024 * 1024));
        defer allocator.free(bytes);
        var digest: [32]u8 = @splat(0);
        std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
        const hex = std.fmt.bytesToHex(digest, .lower);
        if (!std.mem.eql(u8, &hex, reference.sha256)) return error.StaleGraphifySecurityReference;
    }
    for (contract.fixtures) |fixture| switch (fixture.evidence_state) {
        .exercised, .contract_exercised, .not_applicable => package_root.access(io, fixture.path, .{}) catch return error.MissingSecurityEvidence,
        .planned, .deferred => {},
    };
}

fn validateGraphify(graphify: *const GraphifyBaseline) !void {
    if (!std.mem.eql(u8, graphify.version, "0.9.17") or
        !std.mem.eql(u8, graphify.commit, "cb96bdaa0c367bec8d5c5aee5d7c9ebb727e9780") or
        graphify.references.len != required_reference_ids.len)
    {
        return error.IncompatibleGraphifySecurityBaseline;
    }
    for (graphify.references, 0..) |reference, index| {
        for (graphify.references[0..index]) |previous| if (std.mem.eql(u8, previous.id, reference.id)) return error.DuplicateSecurityReference;
        if (!std.mem.eql(u8, reference.id, required_reference_ids[index]) or
            !std.mem.startsWith(u8, reference.path, "test/fixtures/references/graphify/") or
            !validSha256(reference.sha256) or reference.line_start == 0 or reference.line_end < reference.line_start)
        {
            return error.InvalidSecurityReference;
        }
    }
}

fn validateControls(controls: []const Control) !void {
    if (controls.len != required_control_ids.len) return error.IncompleteSecurityControls;
    for (controls, 0..) |control, index| {
        for (controls[0..index]) |previous| if (std.mem.eql(u8, previous.id, control.id)) return error.DuplicateSecurityControl;
        if (!std.mem.eql(u8, control.id, required_control_ids[index])) return error.InvalidSecurityControl;
    }
}

fn validateThreats(contract: *const Contract) !void {
    if (contract.threats.len != required_threat_ids.len) return error.IncompleteThreatCatalog;
    for (contract.threats, 0..) |threat, index| {
        for (contract.threats[0..index]) |previous| if (std.mem.eql(u8, previous.id, threat.id)) return error.DuplicateThreat;
        if (!std.mem.eql(u8, threat.id, required_threat_ids[index]) or threat.title.len == 0 or
            threat.boundaries.len == 0 or threat.assets.len == 0 or threat.control_ids.len == 0 or
            threat.graphify_reference_ids.len == 0 or threat.fixture_ids.len == 0 or
            threat.milestone.len == 0 or threat.residual_risk.len == 0)
        {
            return error.InvalidThreat;
        }
        try uniqueEnums(Boundary, threat.boundaries);
        try uniqueEnums(Asset, threat.assets);
        for (threat.control_ids) |id| if (findControl(contract, id) == null) return error.UnknownControlReference;
        for (threat.graphify_reference_ids) |id| if (findReference(contract, id) == null) return error.UnknownSecurityReference;
        for (threat.fixture_ids) |id| if (findFixture(contract, id) == null) return error.UnknownFixtureReference;
    }
}

fn validateFixtures(contract: *const Contract) !void {
    if (contract.fixtures.len != contract.threats.len) return error.IncompleteAdversarialFixtures;
    for (contract.fixtures, 0..) |fixture, index| {
        for (contract.fixtures[0..index]) |previous| if (std.mem.eql(u8, previous.id, fixture.id)) return error.DuplicateFixture;
        if (!validName(fixture.id) or fixture.threat_ids.len == 0 or fixture.path.len == 0 or
            fixture.scenario.len == 0 or fixture.expected_behavior.len == 0 or fixture.milestone.len == 0)
        {
            return error.InvalidAdversarialFixture;
        }
        for (fixture.threat_ids) |id| {
            const threat = findThreat(contract, id) orelse return error.UnknownThreatReference;
            if (!containsString(threat.fixture_ids, fixture.id)) return error.InconsistentFixtureReference;
        }
    }
}

fn validatePromotions(contract: *const Contract) !void {
    for (contract.threats) |threat| {
        var saw_exercised = false;
        var saw_contract = false;
        var saw_planned = false;
        var saw_deferred = false;
        var saw_not_applicable = false;
        for (threat.fixture_ids) |id| {
            const fixture = findFixture(contract, id).?;
            switch (fixture.evidence_state) {
                .exercised => saw_exercised = true,
                .contract_exercised => saw_contract = true,
                .planned => saw_planned = true,
                .deferred => saw_deferred = true,
                .not_applicable => saw_not_applicable = true,
            }
        }
        switch (threat.disposition) {
            .mitigated => {
                if (!saw_exercised or saw_contract or saw_planned or saw_deferred or saw_not_applicable) return error.FalseSecurityPromotion;
                for (threat.control_ids) |id| if (findControl(contract, id).?.maturity != .implemented) return error.FalseSecurityPromotion;
            },
            .partial => if (!saw_exercised and !saw_contract) return error.FalseSecurityPromotion,
            .contract_only => if (!saw_contract or saw_exercised) return error.FalseSecurityPromotion,
            .planned => if (!saw_planned) return error.FalseSecurityPromotion,
            .deferred => if (!saw_deferred) return error.FalseSecurityPromotion,
            .not_applicable => if (!saw_not_applicable) return error.FalseSecurityPromotion,
        }
    }
    if (summarize(contract).unowned_high_or_critical != 0) return error.UnownedHighRiskThreat;
}

fn findControl(contract: *const Contract, id: []const u8) ?*const Control {
    for (contract.controls, 0..) |control, index| if (std.mem.eql(u8, control.id, id)) return &contract.controls[index];
    return null;
}

fn findReference(contract: *const Contract, id: []const u8) ?*const Reference {
    for (contract.graphify.references, 0..) |reference, index| if (std.mem.eql(u8, reference.id, id)) return &contract.graphify.references[index];
    return null;
}

fn findFixture(contract: *const Contract, id: []const u8) ?*const Fixture {
    for (contract.fixtures, 0..) |fixture, index| if (std.mem.eql(u8, fixture.id, id)) return &contract.fixtures[index];
    return null;
}

fn exactEnumDeclaration(comptime T: type, values: []const T, failure: anyerror) !void {
    const fields = std.meta.fields(T);
    if (values.len != fields.len) return failure;
    inline for (fields, 0..) |field, index| {
        const expected: T = @enumFromInt(field.value);
        if (values[index] != expected) return failure;
    }
}

fn uniqueEnums(comptime T: type, values: []const T) !void {
    for (values, 0..) |value, index| for (values[0..index]) |previous| if (previous == value) return error.DuplicateThreatDimension;
}

fn containsString(values: []const []const u8, wanted: []const u8) bool {
    for (values) |value| if (std.mem.eql(u8, value, wanted)) return true;
    return false;
}

fn validSha256(value: []const u8) bool {
    if (value.len != 64) return false;
    for (value) |byte| if (!std.ascii.isDigit(byte) and (byte < 'a' or byte > 'f')) return false;
    return true;
}

fn validName(value: []const u8) bool {
    if (value.len == 0 or value.len > 96 or !std.ascii.isLower(value[0])) return false;
    for (value) |byte| if (!std.ascii.isLower(byte) and !std.ascii.isDigit(byte) and byte != '_' and byte != '-') return false;
    return true;
}
