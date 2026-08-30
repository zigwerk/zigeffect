const std = @import("std");

pub const schema = "zgraphy.graphify-parity.v1";
pub const schema_version: u32 = 1;
pub const pinned_graphify_version = "0.9.17";
pub const pinned_graphify_commit = "cb96bdaa0c367bec8d5c5aee5d7c9ebb727e9780";
pub const embedded_bytes = @embedFile("graphify-parity.v1.json");

pub const required_capability_ids = [_][]const u8{
    "discovery-corpus-health",
    "corpus-ingress-conversion",
    "deterministic-code-extraction",
    "symbol-member-dispatch-resolution",
    "specialized-repository-adapters",
    "semantic-documents-model-providers",
    "graph-assembly-identity-dedup",
    "incremental-self-management",
    "analysis-communities-meaning",
    "query-navigation-retrieval",
    "agent-protocols-installation",
    "agent-work-memory",
    "change-history-federation",
    "interchange-export",
    "security-failure-packaging",
    "benchmarking-claims",
    "human-visualization",
};

pub const Disposition = enum {
    core_parity,
    improved_equivalent,
    optional_parity,
    deferred_visual,
};

pub const EvidenceStatus = enum {
    mvp_partial,
    planned,
    deferred,
};

pub const Baseline = struct {
    product: []const u8,
    version: []const u8,
    commit: []const u8,
    reference_path: []const u8,
};

pub const Capability = struct {
    id: []const u8,
    title: []const u8,
    disposition: Disposition,
    milestone: []const u8,
    requirement: []const u8,
    status: EvidenceStatus,
    reference_modules: []const []const u8,
    reference_tests: []const []const u8,
    improvement: []const u8,
};

pub const Ledger = struct {
    schema: []const u8,
    schema_version: u32,
    baseline: Baseline,
    capabilities: []const Capability,
};

pub const Summary = struct {
    total: usize = 0,
    core_parity: usize = 0,
    improved_equivalent: usize = 0,
    optional_parity: usize = 0,
    deferred_visual: usize = 0,
    mvp_partial: usize = 0,
    planned: usize = 0,
    deferred: usize = 0,
};

pub fn parseEmbedded(allocator: std.mem.Allocator) !std.json.Parsed(Ledger) {
    return std.json.parseFromSlice(Ledger, allocator, embedded_bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = false,
    });
}

pub fn validate(ledger: *const Ledger) !void {
    if (!std.mem.eql(u8, ledger.schema, schema) or ledger.schema_version != schema_version) {
        return error.IncompatibleParityLedger;
    }
    if (!std.mem.eql(u8, ledger.baseline.product, "Graphify") or
        !std.mem.eql(u8, ledger.baseline.version, pinned_graphify_version) or
        !std.mem.eql(u8, ledger.baseline.commit, pinned_graphify_commit) or
        ledger.baseline.reference_path.len == 0)
    {
        return error.InvalidParityBaseline;
    }
    if (!isLowerHexCommit(ledger.baseline.commit)) return error.InvalidParityBaseline;
    if (ledger.capabilities.len != required_capability_ids.len) return error.IncompleteParityLedger;

    for (ledger.capabilities, 0..) |capability, index| {
        try validateCapability(&capability);
        for (ledger.capabilities[0..index]) |previous| {
            if (std.mem.eql(u8, previous.id, capability.id)) return error.DuplicateParityCapability;
        }
    }
    for (required_capability_ids) |id| {
        if (findCapability(ledger, id) == null) return error.IncompleteParityLedger;
    }
}

pub fn summarize(ledger: *const Ledger) Summary {
    var result = Summary{ .total = ledger.capabilities.len };
    for (ledger.capabilities) |capability| {
        switch (capability.disposition) {
            .core_parity => result.core_parity += 1,
            .improved_equivalent => result.improved_equivalent += 1,
            .optional_parity => result.optional_parity += 1,
            .deferred_visual => result.deferred_visual += 1,
        }
        switch (capability.status) {
            .mvp_partial => result.mvp_partial += 1,
            .planned => result.planned += 1,
            .deferred => result.deferred += 1,
        }
    }
    return result;
}

pub fn findCapability(ledger: *const Ledger, id: []const u8) ?*const Capability {
    for (ledger.capabilities, 0..) |capability, index| {
        if (std.mem.eql(u8, capability.id, id)) return &ledger.capabilities[index];
    }
    return null;
}

fn validateCapability(capability: *const Capability) !void {
    if (!validKebabId(capability.id) or capability.title.len == 0 or capability.improvement.len == 0) {
        return error.InvalidParityCapability;
    }
    if (!validMilestone(capability.milestone)) return error.InvalidParityMilestone;
    if (!validRequirement(capability.requirement)) return error.InvalidParityRequirement;
    if (capability.reference_modules.len == 0 or capability.reference_tests.len == 0) {
        return error.InvalidParityReferences;
    }
    for (capability.reference_modules) |module| {
        if (module.len == 0 or std.mem.indexOf(u8, module, "..") != null) return error.InvalidParityReferences;
    }
    for (capability.reference_tests) |test_name| {
        if (test_name.len == 0) return error.InvalidParityReferences;
    }
}

fn validKebabId(value: []const u8) bool {
    if (value.len == 0 or value[0] == '-' or value[value.len - 1] == '-') return false;
    var previous_dash = false;
    for (value) |byte| {
        const valid = std.ascii.isLower(byte) or std.ascii.isDigit(byte) or byte == '-';
        if (!valid or (byte == '-' and previous_dash)) return false;
        previous_dash = byte == '-';
    }
    return true;
}

fn validMilestone(value: []const u8) bool {
    if (value.len < 2 or value[0] != 'M') return false;
    const number = std.fmt.parseInt(u8, value[1..], 10) catch return false;
    return number <= 12;
}

fn validRequirement(value: []const u8) bool {
    if (value.len != "ZG-REQ-000".len or !std.mem.startsWith(u8, value, "ZG-REQ-")) return false;
    for (value["ZG-REQ-".len..]) |byte| if (!std.ascii.isDigit(byte)) return false;
    return true;
}

fn isLowerHexCommit(value: []const u8) bool {
    if (value.len != 40) return false;
    for (value) |byte| {
        if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    }
    return true;
}
