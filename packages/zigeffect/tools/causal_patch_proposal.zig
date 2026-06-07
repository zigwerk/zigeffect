const std = @import("std");
const causal_run = @import("causal_run");

const audit_schema = "zigeffect.causal.remediation-audit.v1";
const decision_schema = "zigeffect.causal.remediation-decision.v1";
const proposal_schema = "zigeffect.causal.patch-proposal.v1";

const ProposalStatus = enum {
    draft,
    approved,
};

const ProposalOptions = struct {
    mode: []const u8,
    status: ProposalStatus,
    scenario_slug: ?[]const u8 = null,
    summary: []const u8,
    file: []const u8,
    change: []const u8,
};

const ArtifactSource = struct {
    verdict: []const u8,
    diagnosis: []const u8,
    remediation_plan: []const u8,
    advice: []const u8,
    query: []const u8,
    compare: ?[]const u8,
};

const AuditRecord = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    proposer: []const u8,
    approval_status: []const u8,
    applied: bool,
    posture: []const u8,
    source: ArtifactSource,
    event_ids: []const u64,
    verification_commands: []const []const u8,
    claim_guardrails: []const []const u8,
};

const ProposalSource = struct {
    audit: []const u8,
    decision: ?[]const u8,
    artifacts: ArtifactSource,
};

const ProposalInput = struct {
    options: ProposalOptions,
    target: []const u8,
    source: ProposalSource,
    event_ids: []const u64,
    verification_commands: []const []const u8,
    claim_guardrails: []const []const u8,
};

fn localProposalJsonPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-patch-proposal.json";
}

fn localProposalTextPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-patch-proposal.txt";
}

fn localProposalJsonPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-patch-proposal.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn localProposalTextPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-patch-proposal.txt",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn parseProposalStatus(value: []const u8) ?ProposalStatus {
    if (std.mem.eql(u8, value, "draft")) return .draft;
    if (std.mem.eql(u8, value, "approved")) return .approved;
    return null;
}

fn proposalStatusText(status: ProposalStatus) []const u8 {
    return switch (status) {
        .draft => "draft",
        .approved => "approved",
    };
}

fn parseProposalOptions(args: []const []const u8) !ProposalOptions {
    if (args.len < 2) return error.MissingMode;
    if (!std.mem.eql(u8, args[1], "local")) return error.UnknownMode;
    if (args.len < 3) return error.MissingProposalStatus;

    const status = parseProposalStatus(args[2]) orelse return error.UnknownProposalStatus;
    var scenario_slug: ?[]const u8 = null;
    var summary: ?[]const u8 = null;
    var file: ?[]const u8 = null;
    var change: ?[]const u8 = null;

    var index: usize = 3;
    while (index < args.len) {
        const arg = args[index];
        if (std.mem.startsWith(u8, arg, "--")) {
            if (index + 1 >= args.len) return error.MissingFlagValue;
            const value = args[index + 1];
            if (std.mem.eql(u8, arg, "--summary")) {
                summary = value;
            } else if (std.mem.eql(u8, arg, "--file")) {
                file = value;
            } else if (std.mem.eql(u8, arg, "--change")) {
                change = value;
            } else {
                return error.UnknownFlag;
            }
            index += 2;
        } else {
            if (scenario_slug != null) return error.DuplicateScenarioArgument;
            scenario_slug = arg;
            index += 1;
        }
    }

    return .{
        .mode = "local",
        .status = status,
        .scenario_slug = scenario_slug,
        .summary = summary orelse return error.MissingSummary,
        .file = file orelse return error.MissingFile,
        .change = change orelse return error.MissingChange,
    };
}

fn usage() []const u8 {
    return "usage: zig build causal-patch-proposal -- local draft|approved [scenario] --summary <summary> --file <path> --change <description>\n";
}

fn validateAuditRecord(audit: AuditRecord) !void {
    if (!std.mem.eql(u8, audit.schema, audit_schema)) return error.UnsupportedAuditSchema;
    if (audit.schema_version != 1) return error.UnsupportedAuditSchema;
    if (!std.mem.eql(u8, audit.mode, "local")) return error.UnsupportedAuditSchema;
    if (!std.mem.eql(u8, audit.approval_status, "pending")) return error.AuditNotPending;
    if (audit.applied) return error.AuditAlreadyApplied;
}

fn proposalInputFromAudit(options: ProposalOptions, audit_path: []const u8, audit: AuditRecord) ProposalInput {
    return .{
        .options = options,
        .target = audit.target,
        .source = .{
            .audit = audit_path,
            .decision = null,
            .artifacts = audit.source,
        },
        .event_ids = audit.event_ids,
        .verification_commands = audit.verification_commands,
        .claim_guardrails = audit.claim_guardrails,
    };
}

fn approvalStatusText(status: ProposalStatus) []const u8 {
    return switch (status) {
        .draft => "pending",
        .approved => "approved",
    };
}

fn approvedBool(status: ProposalStatus) bool {
    return status == .approved;
}

fn firstProposalGuardrail() []const u8 {
    return "This proposal does not apply source changes.";
}

fn secondProposalGuardrail(status: ProposalStatus) []const u8 {
    return switch (status) {
        .draft => "Draft proposals are not approval for source edits.",
        .approved => "Approval permits reviewable patch work but does not prove the fix.",
    };
}

fn thirdProposalGuardrail() []const u8 {
    return "Run required verification after any future patch before claiming a fix.";
}

fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| switch (byte) {
        '"' => try output.appendSlice(allocator, "\\\""),
        '\\' => try output.appendSlice(allocator, "\\\\"),
        '\n' => try output.appendSlice(allocator, "\\n"),
        '\r' => try output.appendSlice(allocator, "\\r"),
        '\t' => try output.appendSlice(allocator, "\\t"),
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}

fn appendU64Array(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const u64) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.print(allocator, "{d}", .{value});
    }
    try output.append(allocator, ']');
}

fn appendStringArray(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const []const u8) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, value);
    }
    try output.append(allocator, ']');
}

fn appendSourceJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: ProposalInput) !void {
    try output.appendSlice(allocator, "    \"audit\": ");
    try appendJsonString(allocator, output, input.source.audit);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"decision\": ");
    if (input.source.decision) |decision| {
        try appendJsonString(allocator, output, decision);
    } else {
        try output.appendSlice(allocator, "null");
    }
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"verdict\": ");
    try appendJsonString(allocator, output, input.source.artifacts.verdict);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"diagnosis\": ");
    try appendJsonString(allocator, output, input.source.artifacts.diagnosis);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"remediation_plan\": ");
    try appendJsonString(allocator, output, input.source.artifacts.remediation_plan);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"advice\": ");
    try appendJsonString(allocator, output, input.source.artifacts.advice);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"query\": ");
    try appendJsonString(allocator, output, input.source.artifacts.query);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"compare\": ");
    if (input.source.artifacts.compare) |compare| {
        try appendJsonString(allocator, output, compare);
    } else {
        try output.appendSlice(allocator, "null");
    }
    try output.append(allocator, '\n');
}

fn formatProposalJson(allocator: std.mem.Allocator, input: ProposalInput) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, proposal_schema);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"mode\": ");
    try appendJsonString(allocator, &output, input.options.mode);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"target\": ");
    try appendJsonString(allocator, &output, input.target);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"proposal_status\": ");
    try appendJsonString(allocator, &output, proposalStatusText(input.options.status));
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"approval_status\": ");
    try appendJsonString(allocator, &output, approvalStatusText(input.options.status));
    try output.appendSlice(allocator, ",\n");
    try output.print(allocator, "  \"approved\": {},\n", .{approvedBool(input.options.status)});
    try output.appendSlice(allocator, "  \"applied\": false,\n");
    try output.appendSlice(allocator, "  \"summary\": ");
    try appendJsonString(allocator, &output, input.options.summary);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"source\": {\n");
    try appendSourceJson(allocator, &output, input);
    try output.appendSlice(allocator, "  },\n");
    try output.appendSlice(allocator, "  \"proposed_changes\": [\n");
    try output.appendSlice(allocator, "    {\n");
    try output.appendSlice(allocator, "      \"file\": ");
    try appendJsonString(allocator, &output, input.options.file);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "      \"change\": ");
    try appendJsonString(allocator, &output, input.options.change);
    try output.appendSlice(allocator, "\n");
    try output.appendSlice(allocator, "    }\n");
    try output.appendSlice(allocator, "  ],\n");
    try output.appendSlice(allocator, "  \"event_ids\": ");
    try appendU64Array(allocator, &output, input.event_ids);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"verification_commands\": ");
    try appendStringArray(allocator, &output, input.verification_commands);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"claim_guardrails\": ");
    try appendStringArray(allocator, &output, input.claim_guardrails);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"proposal_guardrails\": [");
    try appendJsonString(allocator, &output, firstProposalGuardrail());
    try output.appendSlice(allocator, ", ");
    try appendJsonString(allocator, &output, secondProposalGuardrail(input.options.status));
    try output.appendSlice(allocator, ", ");
    try appendJsonString(allocator, &output, thirdProposalGuardrail());
    try output.appendSlice(allocator, "]\n");
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

const pending_audit_json =
    \\{
    \\  "schema": "zigeffect.causal.remediation-audit.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "dogfood",
    \\  "proposer": "local-agent",
    \\  "approval_status": "pending",
    \\  "applied": false,
    \\  "posture": "patch-candidate",
    \\  "source": {
    \\    "verdict": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
    \\    "diagnosis": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
    \\    "remediation_plan": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md",
    \\    "advice": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
    \\    "query": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt",
    \\    "compare": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt"
    \\  },
    \\  "event_ids": [3, 4, 5, 6],
    \\  "verification_commands": ["zig build causal-dev-loop -- baseline", "zig build causal-dev-loop -- after", "zig build causal-diagnosis -- local", "zig build test --summary none"],
    \\  "claim_guardrails": ["Do not claim this patch fixed persisting evidence unless the after verdict is clear or the compare report shows fewer findings."]
    \\}
;

test "patch proposal output paths are stable for default and scenario targets" {
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.json",
        localProposalJsonPath(),
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.txt",
        localProposalTextPath(),
    );

    const scenario_json = try localProposalJsonPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario_json);
    const scenario_text = try localProposalTextPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario_text);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-patch-proposal.json",
        scenario_json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-patch-proposal.txt",
        scenario_text,
    );
}

test "parse options accepts draft metadata" {
    const args = [_][]const u8{
        "zigeffect-causal-patch-proposal",
        "local",
        "draft",
        "--summary",
        "tighten scope close ordering",
        "--file",
        "packages/zigeffect/src/core/scope.zig",
        "--change",
        "ensure child finalizers run before parent close is reported",
    };

    const options = try parseProposalOptions(args[0..]);
    try std.testing.expectEqual(ProposalStatus.draft, options.status);
    try std.testing.expect(options.scenario_slug == null);
    try std.testing.expectEqualStrings("tighten scope close ordering", options.summary);
    try std.testing.expectEqualStrings("packages/zigeffect/src/core/scope.zig", options.file);
    try std.testing.expectEqualStrings("ensure child finalizers run before parent close is reported", options.change);
}

test "parse options accepts approved scenario metadata" {
    const args = [_][]const u8{
        "zigeffect-causal-patch-proposal",
        "local",
        "approved",
        "causal-scoped-fiber",
        "--summary",
        "record scoped fiber interruption",
        "--file",
        "packages/zigeffect/src/runtime/fiber.zig",
        "--change",
        "emit interrupted event before release evidence",
    };

    const options = try parseProposalOptions(args[0..]);
    try std.testing.expectEqual(ProposalStatus.approved, options.status);
    try std.testing.expectEqualStrings("causal-scoped-fiber", options.scenario_slug.?);
}

test "parse options requires summary file and change" {
    const missing_summary = [_][]const u8{
        "zigeffect-causal-patch-proposal",
        "local",
        "draft",
        "--file",
        "packages/zigeffect/src/core/scope.zig",
        "--change",
        "change",
    };
    try std.testing.expectError(error.MissingSummary, parseProposalOptions(missing_summary[0..]));

    const missing_file = [_][]const u8{
        "zigeffect-causal-patch-proposal",
        "local",
        "draft",
        "--summary",
        "summary",
        "--change",
        "change",
    };
    try std.testing.expectError(error.MissingFile, parseProposalOptions(missing_file[0..]));

    const missing_change = [_][]const u8{
        "zigeffect-causal-patch-proposal",
        "local",
        "draft",
        "--summary",
        "summary",
        "--file",
        "packages/zigeffect/src/core/scope.zig",
    };
    try std.testing.expectError(error.MissingChange, parseProposalOptions(missing_change[0..]));
}

test "usage names local proposal shape" {
    try std.testing.expectEqualStrings(
        "usage: zig build causal-patch-proposal -- local draft|approved [scenario] --summary <summary> --file <path> --change <description>\n",
        usage(),
    );
}

test "audit validation accepts pending unapplied audit only" {
    var parsed = try std.json.parseFromSlice(AuditRecord, std.testing.allocator, pending_audit_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try validateAuditRecord(parsed.value);

    var non_pending = parsed.value;
    non_pending.approval_status = "approved";
    try std.testing.expectError(error.AuditNotPending, validateAuditRecord(non_pending));

    var applied = parsed.value;
    applied.applied = true;
    try std.testing.expectError(error.AuditAlreadyApplied, validateAuditRecord(applied));
}

test "draft proposal JSON records pending approval without applying source changes" {
    var parsed = try std.json.parseFromSlice(AuditRecord, std.testing.allocator, pending_audit_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const input = proposalInputFromAudit(
        .{
            .mode = "local",
            .status = .draft,
            .summary = "tighten scope close ordering",
            .file = "packages/zigeffect/src/core/scope.zig",
            .change = "ensure child finalizers run before parent close is reported",
        },
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
        parsed.value,
    );

    const json = try formatProposalJson(std.testing.allocator, input);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\": \"zigeffect.causal.patch-proposal.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"proposal_status\": \"draft\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"approval_status\": \"pending\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"approved\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"decision\": null") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"file\": \"packages/zigeffect/src/core/scope.zig\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"event_ids\": [3, 4, 5, 6]") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"Draft proposals are not approval for source edits.\"") != null);
}
