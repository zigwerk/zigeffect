const std = @import("std");
const causal_run = @import("causal_run");

const proposal_suffix = "-scenario-proposal.json";
const registry_patch_suffix = "-registry-patch";
const proposal_schema = "zigeffect.causal.scenario-proposal.v1";

const Options = struct {
    proposal_path: []const u8,
};

const Recommendation = enum {
    add_scenario,
    refine_scenario,
    none,
};

const ScenarioProposal = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    recommendation: []const u8,
    reason: []const u8,
    proposed_scenario: ?ProposedScenario = null,
    proposed_invariants: []const ProposedInvariant = &.{},
    review_checklist: []const []const u8 = &.{},
    guardrails: []const []const u8 = &.{},
};

const ProposedScenario = struct {
    slug: []const u8,
    label: []const u8,
    owner: []const u8,
    expectation: []const u8,
    finding_policy: []const u8,
    purpose: []const u8,
    minimal_command: []const u8,
};

const ProposedInvariant = struct {
    id: []const u8,
    subsystem: []const u8,
    rule: []const u8,
    detection_query: []const u8,
};

const ValidationResult = struct {
    recommendation: Recommendation,
    scenario_conflict: bool,
    has_patch_snippet: bool,
};

const RegistryPatchPaths = struct {
    json: []const u8,
    text: []const u8,
    zig: []const u8,

    fn deinit(self: RegistryPatchPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
        allocator.free(self.zig);
    }
};

fn parseOptions(args: []const []const u8) !Options {
    if (args.len < 3) return error.MissingProposalPath;
    if (args.len > 3) return error.TooManyArguments;
    if (!std.mem.eql(u8, args[1], "--from-proposal")) return error.UnknownFlag;
    if (!std.mem.endsWith(u8, args[2], proposal_suffix)) return error.InvalidProposalPath;

    return .{ .proposal_path = args[2] };
}

fn registryPatchPathsFromProposal(allocator: std.mem.Allocator, proposal_path: []const u8) !RegistryPatchPaths {
    if (!std.mem.endsWith(u8, proposal_path, proposal_suffix)) return error.InvalidProposalPath;
    const prefix = proposal_path[0 .. proposal_path.len - proposal_suffix.len];

    const json = try std.fmt.allocPrint(allocator, "{s}{s}.json", .{ prefix, registry_patch_suffix });
    errdefer allocator.free(json);
    const text = try std.fmt.allocPrint(allocator, "{s}{s}.txt", .{ prefix, registry_patch_suffix });
    errdefer allocator.free(text);
    const zig = try std.fmt.allocPrint(allocator, "{s}{s}.zig", .{ prefix, registry_patch_suffix });

    return .{ .json = json, .text = text, .zig = zig };
}

fn identifierFromSlug(allocator: std.mem.Allocator, slug: []const u8) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    if (slug.len > 0 and slug[0] >= '0' and slug[0] <= '9') {
        try output.appendSlice(allocator, "scenario_");
    }

    var previous_underscore = false;
    for (slug) |byte| {
        const normalized = switch (byte) {
            'A'...'Z' => byte + 32,
            'a'...'z', '0'...'9' => byte,
            else => '_',
        };
        if (normalized == '_') {
            if (!previous_underscore and output.items.len > 0) try output.append(allocator, '_');
            previous_underscore = true;
        } else {
            try output.append(allocator, normalized);
            previous_underscore = false;
        }
    }

    while (output.items.len > 0 and output.items[output.items.len - 1] == '_') {
        output.items.len -= 1;
    }

    if (output.items.len == 0) try output.appendSlice(allocator, "scenario");
    return output.toOwnedSlice(allocator);
}

fn usage() []const u8 {
    return "usage: zig build causal-scenario-registry-patch -- --from-proposal <scenario-proposal.json>\n";
}

fn validateScenarioProposal(proposal: ScenarioProposal) !ValidationResult {
    if (!std.mem.eql(u8, proposal.schema, proposal_schema)) return error.UnsupportedProposalSchema;
    if (proposal.schema_version != 1) return error.UnsupportedProposalSchema;

    const recommendation = try parseRecommendation(proposal.recommendation);
    if (recommendation == .none) {
        return .{
            .recommendation = .none,
            .scenario_conflict = false,
            .has_patch_snippet = false,
        };
    }

    const scenario = proposal.proposed_scenario orelse return error.MissingProposedScenario;
    try validateOwner(scenario.owner);
    try validateExpectation(scenario.expectation);
    try validateFindingPolicy(scenario.finding_policy);
    try validateProposedInvariants(proposal.proposed_invariants);

    return .{
        .recommendation = recommendation,
        .scenario_conflict = scenarioExists(scenario.slug),
        .has_patch_snippet = true,
    };
}

fn parseRecommendation(value: []const u8) !Recommendation {
    if (std.mem.eql(u8, value, "add-scenario")) return .add_scenario;
    if (std.mem.eql(u8, value, "refine-scenario")) return .refine_scenario;
    if (std.mem.eql(u8, value, "none")) return .none;
    return error.UnknownRecommendation;
}

fn validateOwner(value: []const u8) !void {
    if (std.mem.eql(u8, value, "command_harness")) return;
    if (std.mem.eql(u8, value, "service_resolution")) return;
    if (std.mem.eql(u8, value, "scope_lifecycle")) return;
    if (std.mem.eql(u8, value, "fiber_runtime")) return;
    if (std.mem.eql(u8, value, "schedule_retry")) return;
    if (std.mem.eql(u8, value, "package")) return;
    return error.UnknownOwner;
}

fn validateExpectation(value: []const u8) !void {
    if (std.mem.eql(u8, value, "expected_pass")) return;
    if (std.mem.eql(u8, value, "expected_failure")) return;
    return error.UnknownExpectation;
}

fn validateFindingPolicy(value: []const u8) !void {
    if (std.mem.eql(u8, value, "none_when_command_passes")) return;
    if (std.mem.eql(u8, value, "failure_artifact_on_command_failure")) return;
    if (std.mem.eql(u8, value, "expected_failure_command_emits_assertion")) return;
    return error.UnknownFindingPolicy;
}

fn validateProposedInvariants(invariants: []const ProposedInvariant) !void {
    for (invariants) |invariant| {
        if (invariant.id.len == 0) return error.EmptyInvariantId;
    }
}

fn scenarioExists(slug: []const u8) bool {
    _ = causal_run.scenarioByName(slug) catch return false;
    return true;
}

const sample_add_scenario_proposal_json =
    \\{
    \\  "schema": "zigeffect.causal.scenario-proposal.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "dogfood",
    \\  "recommendation": "add-scenario",
    \\  "reason": "persisting evidence should become reviewed regression coverage",
    \\  "source": {
    \\    "verdict": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
    \\    "diagnosis": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
    \\    "remediation_plan": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md",
    \\    "audit_chain": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-audit-chain.json"
    \\  },
    \\  "evidence": {
    \\    "verdict_status": "attention",
    \\    "actions": 4,
    \\    "new_actions": 0,
    \\    "persisting_actions": 4,
    \\    "observed_actions": 0,
    \\    "audit_chain_assessment": "unchanged",
    \\    "event_ids": [3, 4, 5, 6],
    \\    "persisting_event_ids": [3, 4, 5, 6],
    \\    "appeared_event_ids": [],
    \\    "missing_event_ids": [],
    \\    "dominant_subsystem": "service_resolution",
    \\    "dominant_kind": "service_required",
    \\    "dominant_fix_category": "code-or-layer-provider",
    \\    "dominant_diagnosis": "required service lacks matching provider"
    \\  },
    \\  "proposed_scenario": {
    \\    "slug": "learned-dogfood-service-resolution",
    \\    "label": "Learned dogfood service_resolution",
    \\    "owner": "service_resolution",
    \\    "expectation": "expected_pass",
    \\    "finding_policy": "failure_artifact_on_command_failure",
    \\    "purpose": "required service lacks matching provider",
    \\    "minimal_command": "choose the smallest command that reproduces the cited event ids"
    \\  },
    \\  "proposed_invariants": [
    \\    {
    \\      "id": "service-requirement-has-provider",
    \\      "subsystem": "service_resolution",
    \\      "rule": "service requirements must cite the missing provider boundary",
    \\      "detection_query": "kind=service_required status=missing"
    \\    }
    \\  ],
    \\  "review_checklist": ["Verify cited event ids reproduce on the smallest command."],
    \\  "guardrails": ["This proposal is read-only."]
    \\}
;

const sample_refine_scenario_proposal_json =
    \\{
    \\  "schema": "zigeffect.causal.scenario-proposal.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "causal-scoped-fiber",
    \\  "recommendation": "refine-scenario",
    \\  "reason": "new or regressed evidence should become reviewed regression coverage",
    \\  "source": {},
    \\  "evidence": {
    \\    "dominant_subsystem": "fiber_runtime",
    \\    "event_ids": [9],
    \\    "persisting_event_ids": [],
    \\    "appeared_event_ids": [9],
    \\    "missing_event_ids": []
    \\  },
    \\  "proposed_scenario": {
    \\    "slug": "causal-scoped-fiber",
    \\    "label": "Refine causal-scoped-fiber",
    \\    "owner": "fiber_runtime",
    \\    "expectation": "expected_pass",
    \\    "finding_policy": "failure_artifact_on_command_failure",
    \\    "purpose": "scoped fibers must finish before scope close",
    \\    "minimal_command": "review existing scenario"
    \\  },
    \\  "proposed_invariants": [
    \\    {
    \\      "id": "scoped-fiber-must-finish-before-scope-close",
    \\      "subsystem": "fiber_runtime",
    \\      "rule": "scoped fibers must finish before scope close",
    \\      "detection_query": "kind=fiber_forked status=pending"
    \\    }
    \\  ],
    \\  "review_checklist": [],
    \\  "guardrails": []
    \\}
;

const sample_none_proposal_json =
    \\{
    \\  "schema": "zigeffect.causal.scenario-proposal.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "causal-scoped-fiber",
    \\  "recommendation": "none",
    \\  "reason": "clear evidence does not justify scenario work",
    \\  "source": {},
    \\  "evidence": {
    \\    "dominant_subsystem": "command_harness",
    \\    "event_ids": [],
    \\    "persisting_event_ids": [],
    \\    "appeared_event_ids": [],
    \\    "missing_event_ids": []
    \\  },
    \\  "proposed_scenario": null,
    \\  "proposed_invariants": [],
    \\  "review_checklist": [],
    \\  "guardrails": []
    \\}
;

test "registry patch parses from-proposal option and rejects invalid shapes" {
    const options = try parseOptions(&.{
        "zigeffect-causal-scenario-registry-patch",
        "--from-proposal",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json",
    });
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json",
        options.proposal_path,
    );

    try std.testing.expectError(error.MissingProposalPath, parseOptions(&.{
        "zigeffect-causal-scenario-registry-patch",
    }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{
        "zigeffect-causal-scenario-registry-patch",
        "--proposal",
        "x.json",
    }));
    try std.testing.expectError(error.InvalidProposalPath, parseOptions(&.{
        "zigeffect-causal-scenario-registry-patch",
        "--from-proposal",
        "proposal.json",
    }));
}

test "registry patch output paths are derived from proposal path" {
    const paths = try registryPatchPathsFromProposal(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json",
    );
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json",
        paths.json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.txt",
        paths.text,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.zig",
        paths.zig,
    );
}

test "registry patch identifiers are stable Zig identifiers" {
    const identifier = try identifierFromSlug(std.testing.allocator, "learned-dogfood-service-resolution");
    defer std.testing.allocator.free(identifier);
    try std.testing.expectEqualStrings("learned_dogfood_service_resolution", identifier);

    const digit = try identifierFromSlug(std.testing.allocator, "123-example");
    defer std.testing.allocator.free(digit);
    try std.testing.expectEqualStrings("scenario_123_example", digit);
}

test "registry patch validates add scenario proposal and registry conflict" {
    var parsed = try std.json.parseFromSlice(ScenarioProposal, std.testing.allocator, sample_add_scenario_proposal_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const validation = try validateScenarioProposal(parsed.value);
    try std.testing.expectEqual(Recommendation.add_scenario, validation.recommendation);
    try std.testing.expect(!validation.scenario_conflict);
    try std.testing.expect(validation.has_patch_snippet);
    try std.testing.expectEqualStrings("learned-dogfood-service-resolution", parsed.value.proposed_scenario.?.slug);
}

test "registry patch validates no-op proposal" {
    var parsed = try std.json.parseFromSlice(ScenarioProposal, std.testing.allocator, sample_none_proposal_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const validation = try validateScenarioProposal(parsed.value);
    try std.testing.expectEqual(Recommendation.none, validation.recommendation);
    try std.testing.expect(!validation.has_patch_snippet);
}

test "registry patch rejects unsupported schema and unknown enum values" {
    const bad_schema_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        sample_add_scenario_proposal_json,
        "zigeffect.causal.scenario-proposal.v1",
        "other.schema",
    );
    defer std.testing.allocator.free(bad_schema_json);
    var bad_schema = try std.json.parseFromSlice(ScenarioProposal, std.testing.allocator, bad_schema_json, .{ .ignore_unknown_fields = true });
    defer bad_schema.deinit();
    try std.testing.expectError(error.UnsupportedProposalSchema, validateScenarioProposal(bad_schema.value));

    const bad_owner_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        sample_add_scenario_proposal_json,
        "\"owner\": \"service_resolution\"",
        "\"owner\": \"not_a_subsystem\"",
    );
    defer std.testing.allocator.free(bad_owner_json);
    var bad_owner = try std.json.parseFromSlice(ScenarioProposal, std.testing.allocator, bad_owner_json, .{ .ignore_unknown_fields = true });
    defer bad_owner.deinit();
    try std.testing.expectError(error.UnknownOwner, validateScenarioProposal(bad_owner.value));
}
