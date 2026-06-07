const std = @import("std");
const causal_run = @import("causal_run");

const proposal_suffix = "-scenario-proposal.json";
const registry_patch_suffix = "-registry-patch";
const proposal_schema = "zigeffect.causal.scenario-proposal.v1";
const registry_patch_schema = "zigeffect.causal.registry-patch.v1";

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

const RegistryPatchInput = struct {
    source_proposal_path: []const u8,
    proposal_json: []const u8,
};

const RegistryPatchReports = struct {
    json: []const u8,
    text: []const u8,
    zig: []const u8,

    fn deinit(self: RegistryPatchReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
        allocator.free(self.zig);
    }
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

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-scenario-registry-patch error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
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

fn formatRegistryPatchReports(allocator: std.mem.Allocator, input: RegistryPatchInput) !RegistryPatchReports {
    var parsed = try std.json.parseFromSlice(ScenarioProposal, allocator, input.proposal_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const validation = try validateScenarioProposal(parsed.value);
    const json = try formatRegistryPatchJson(allocator, input.source_proposal_path, parsed.value, validation);
    errdefer allocator.free(json);
    const text = try formatRegistryPatchText(allocator, input.source_proposal_path, parsed.value, validation);
    errdefer allocator.free(text);
    const zig = try formatRegistryPatchZig(allocator, input.source_proposal_path, parsed.value, validation);
    errdefer allocator.free(zig);

    return .{ .json = json, .text = text, .zig = zig };
}

fn formatRegistryPatchJson(
    allocator: std.mem.Allocator,
    source_proposal_path: []const u8,
    proposal: ScenarioProposal,
    validation: ValidationResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, registry_patch_schema);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"source_proposal\": ");
    try appendJsonString(allocator, &output, source_proposal_path);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"recommendation\": ");
    try appendJsonString(allocator, &output, proposal.recommendation);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"patch_status\": ");
    try appendJsonString(allocator, &output, patchStatusText(validation));
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"target\": ");
    try appendJsonString(allocator, &output, proposal.target);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"scenario_slug\": ");
    if (proposal.proposed_scenario) |scenario| {
        try appendJsonString(allocator, &output, scenario.slug);
    } else {
        try output.appendSlice(allocator, "null");
    }
    try output.appendSlice(allocator, ",\n");
    try output.print(allocator, "  \"scenario_conflict\": {},\n", .{validation.scenario_conflict});
    try output.appendSlice(allocator, "  \"known_invariant_ids\": ");
    try appendInvariantIdsJson(allocator, &output, proposal.proposed_invariants, true);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"new_invariant_ids\": ");
    try appendInvariantIdsJson(allocator, &output, proposal.proposed_invariants, false);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"review_checklist\": ");
    try appendStringArray(allocator, &output, reviewChecklist(validation));
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"guardrails\": ");
    try appendStringArray(allocator, &output, guardrails(validation));
    try output.append(allocator, '\n');
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

fn formatRegistryPatchText(
    allocator: std.mem.Allocator,
    source_proposal_path: []const u8,
    proposal: ScenarioProposal,
    validation: ValidationResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal scenario registry patch\n");
    try output.print(allocator, "schema: {s}\n", .{registry_patch_schema});
    try output.print(allocator, "source proposal: {s}\n", .{source_proposal_path});
    try output.print(allocator, "recommendation: {s}\n", .{proposal.recommendation});
    try output.print(allocator, "patch_status: {s}\n", .{patchStatusText(validation)});
    try output.print(allocator, "target: {s}\n", .{proposal.target});

    if (validation.recommendation == .none) {
        try output.appendSlice(allocator, "\nno registry patch recommended\n");
    } else if (proposal.proposed_scenario) |scenario| {
        if (validation.recommendation == .refine_scenario) {
            try output.print(allocator, "\nreview existing scenario: {s}\n", .{scenario.slug});
        } else {
            try output.print(allocator, "\nproposed scenario: {s}\n", .{scenario.slug});
        }
        try output.print(allocator, "- owner: {s}\n", .{scenario.owner});
        try output.print(allocator, "- expectation: {s}\n", .{scenario.expectation});
        try output.print(allocator, "- finding_policy: {s}\n", .{scenario.finding_policy});
        try output.print(allocator, "- conflict: {}\n", .{validation.scenario_conflict});
    }

    try output.appendSlice(allocator, "\nreview checklist:\n");
    for (reviewChecklist(validation)) |item| try output.print(allocator, "- {s}\n", .{item});
    try output.appendSlice(allocator, "\nguardrails:\n");
    for (guardrails(validation)) |item| try output.print(allocator, "- {s}\n", .{item});

    return output.toOwnedSlice(allocator);
}

fn formatRegistryPatchZig(
    allocator: std.mem.Allocator,
    source_proposal_path: []const u8,
    proposal: ScenarioProposal,
    validation: ValidationResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.print(allocator, "// Generated from: {s}\n", .{source_proposal_path});
    try output.print(allocator, "// Recommendation: {s}\n", .{proposal.recommendation});

    if (validation.recommendation == .none) {
        try output.appendSlice(allocator, "// No registry patch recommended for this proposal.\n");
        return output.toOwnedSlice(allocator);
    }

    const scenario = proposal.proposed_scenario orelse return error.MissingProposedScenario;
    const identifier = try identifierFromSlug(allocator, scenario.slug);
    defer allocator.free(identifier);

    if (validation.recommendation == .refine_scenario) {
        try output.print(allocator, "// Review existing scenario entry: {s}\n", .{scenario.slug});
        try output.appendSlice(allocator, "// Suggested invariant ids:\n");
        for (proposal.proposed_invariants) |invariant| {
            try output.print(allocator, "// - {s}\n", .{invariant.id});
        }
        try output.appendSlice(allocator, "// REVIEW: update only the smallest registry fields needed.\n");
        return output.toOwnedSlice(allocator);
    }

    try output.print(allocator, "\nconst {s}_invariants: []const []const u8 = &.{{\n", .{identifier});
    for (proposal.proposed_invariants) |invariant| {
        try output.print(allocator, "    \"{s}\",\n", .{invariant.id});
    }
    try output.appendSlice(allocator, "};\n\n");

    try output.print(allocator, "const {s}_argv: []const []const u8 = &.{{\n", .{identifier});
    try output.appendSlice(allocator, "    // REVIEW: replace this placeholder with the smallest reproducing command.\n");
    try output.appendSlice(allocator, "    \"zig\",\n");
    try output.appendSlice(allocator, "    \"build\",\n");
    try output.appendSlice(allocator, "    \"examples\",\n");
    try output.appendSlice(allocator, "};\n\n");

    try output.appendSlice(allocator, "// Add to scenario_registry after review:\n");
    try output.appendSlice(allocator, ".{\n");
    try output.print(allocator, "    .slug = \"{s}\",\n", .{scenario.slug});
    try output.print(allocator, "    .label = \"{s}\",\n", .{scenario.label});
    try output.print(allocator, "    .expectation = .{s},\n", .{scenario.expectation});
    try output.print(allocator, "    .owner = .{s},\n", .{scenario.owner});
    try output.print(allocator, "    .purpose = \"{s}\",\n", .{scenario.purpose});
    try output.print(allocator, "    .finding_policy = .{s},\n", .{scenario.finding_policy});
    try output.print(allocator, "    .invariant_ids = {s}_invariants,\n", .{identifier});
    try output.print(allocator, "    .argv = {s}_argv,\n", .{identifier});
    try output.appendSlice(allocator, "},\n");

    return output.toOwnedSlice(allocator);
}

fn patchStatusText(validation: ValidationResult) []const u8 {
    return if (validation.recommendation == .none) "no-op" else "review-required";
}

fn reviewChecklist(validation: ValidationResult) []const []const u8 {
    if (validation.recommendation == .none) {
        return &.{"Confirm no scenario or invariant change is needed for clear evidence."};
    }
    return &.{
        "Verify the proposed scenario slug does not conflict with existing scenarios.",
        "Replace placeholder argv with the smallest reproducing command.",
        "Confirm invariant ids match the catalog or add reviewed invariant entries.",
        "Run the scenario after applying the registry patch.",
    };
}

fn guardrails(validation: ValidationResult) []const []const u8 {
    if (validation.recommendation == .none) {
        return &.{"Do not apply registry changes for no-op proposals."};
    }
    return &.{
        "This registry patch is generated from evidence but requires explicit review.",
        "Do not apply registry patches without verifying the minimal reproducing command.",
        "Generated argv is a placeholder until a reviewer replaces it.",
    };
}

fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| switch (byte) {
        '"' => try output.appendSlice(allocator, "\\\""),
        '\\' => try output.appendSlice(allocator, "\\\\"),
        '\n' => try output.appendSlice(allocator, "\\n"),
        '\r' => try output.appendSlice(allocator, "\\r"),
        '\t' => try output.appendSlice(allocator, "\\t"),
        0...7,
        11,
        12,
        14...31,
        => {
            const hex = "0123456789abcdef";
            try output.appendSlice(allocator, "\\u00");
            try output.append(allocator, hex[@intCast(byte >> 4)]);
            try output.append(allocator, hex[@intCast(byte & 0x0f)]);
        },
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}

fn appendStringArray(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const []const u8) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, value);
    }
    try output.append(allocator, ']');
}

fn appendInvariantIdsJson(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    invariants: []const ProposedInvariant,
    known: bool,
) !void {
    try output.append(allocator, '[');
    var emitted: usize = 0;
    for (invariants) |invariant| {
        const is_known = invariantExists(invariant.id);
        if (is_known != known) continue;
        if (emitted > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, invariant.id);
        emitted += 1;
    }
    try output.append(allocator, ']');
}

fn invariantExists(id: []const u8) bool {
    _ = causal_run.invariantById(id) catch return false;
    return true;
}

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingRegistryPatchInput,
        else => return err,
    };
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn runFromProposal(init: std.process.Init, options: Options) !void {
    const allocator = init.gpa;
    const proposal_json = try readRequiredArtifact(init.io, allocator, options.proposal_path);
    defer allocator.free(proposal_json);

    const reports = try formatRegistryPatchReports(allocator, .{
        .source_proposal_path = options.proposal_path,
        .proposal_json = proposal_json,
    });
    defer reports.deinit(allocator);

    const paths = try registryPatchPathsFromProposal(allocator, options.proposal_path);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json, reports.json);
    try writeArtifact(init.io, paths.text, reports.text);
    try writeArtifact(init.io, paths.zig, reports.zig);
    std.debug.print("{s}", .{reports.text});
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(args) catch |err| failUsage(err);
    runFromProposal(init, options) catch |err| switch (err) {
        error.MissingRegistryPatchInput,
        error.InvalidProposalPath,
        error.InvalidArtifactPath,
        error.UnsupportedProposalSchema,
        error.UnknownRecommendation,
        error.MissingProposedScenario,
        error.UnknownOwner,
        error.UnknownExpectation,
        error.UnknownFindingPolicy,
        error.EmptyInvariantId,
        => failUsage(err),
        else => return err,
    };
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

test "registry patch formats add-scenario JSON text and Zig snippet" {
    const reports = try formatRegistryPatchReports(std.testing.allocator, .{
        .source_proposal_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json",
        .proposal_json = sample_add_scenario_proposal_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.registry-patch.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"patch_status\": \"review-required\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"scenario_conflict\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "patch_status: review-required") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.zig, "const learned_dogfood_service_resolution_invariants") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.zig, ".slug = \"learned-dogfood-service-resolution\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.zig, ".owner = .service_resolution") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.zig, "REVIEW: replace this placeholder") != null);
}

test "registry patch formats none proposal as no-op" {
    const reports = try formatRegistryPatchReports(std.testing.allocator, .{
        .source_proposal_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json",
        .proposal_json = sample_none_proposal_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"patch_status\": \"no-op\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "no registry patch recommended") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.zig, "No registry patch recommended") != null);
}

test "registry patch formats refine proposal as review guidance" {
    const reports = try formatRegistryPatchReports(std.testing.allocator, .{
        .source_proposal_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json",
        .proposal_json = sample_refine_scenario_proposal_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"recommendation\": \"refine-scenario\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "review existing scenario: causal-scoped-fiber") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.zig, "Review existing scenario entry") != null);
}
