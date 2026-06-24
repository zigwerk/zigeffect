const std = @import("std");
const causal_run = @import("causal_run");
const fx = @import("zigeffect");

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

const DecisionSource = struct {
    audit: []const u8,
    verdict: []const u8,
    diagnosis: []const u8,
    remediation_plan: []const u8,
    advice: []const u8,
    query: []const u8,
    compare: ?[]const u8,
};

const DecisionRecord = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    decision: []const u8,
    approval_status: []const u8,
    decided_by: []const u8,
    policy: []const u8,
    reason: []const u8,
    applied: bool,
    source: DecisionSource,
    event_ids: []const u64,
    verification_commands: []const []const u8,
    claim_guardrails: []const []const u8,
    decision_guardrails: []const []const u8,
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

const PatchProposalEvalArtifactPaths = struct {
    diff_path: []const u8,
    link_path: []const u8,
    manifest_path: []const u8,
    proposal_json_path: []const u8,
};

const PatchProposalEvalArtifactSinks = struct {
    diff: fx.AgentEvalDiffArtifactSink,
    link: fx.AgentEvalDiffArtifactSink,
    manifest: fx.AgentEvalDiffArtifactSink,
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

fn localProposalEvalDiffPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-patch-proposal-eval-diff.json";
}

fn localProposalEvalLinkPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-patch-proposal-eval-link.json";
}

fn localProposalEvalManifestPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-patch-proposal-eval-manifest.json";
}

fn localProposalEvalDiffPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-patch-proposal-eval-diff.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn localProposalEvalLinkPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-patch-proposal-eval-link.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn localProposalEvalManifestPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-patch-proposal-eval-manifest.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn localAuditJsonPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-audit.json";
}

fn localAuditJsonPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-remediation-audit.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn localDecisionJsonPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-decision.json";
}

fn localDecisionJsonPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-remediation-decision.json",
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

fn validateDecisionRecord(decision: DecisionRecord) !void {
    if (!std.mem.eql(u8, decision.schema, decision_schema)) return error.UnsupportedDecisionSchema;
    if (decision.schema_version != 1) return error.UnsupportedDecisionSchema;
    if (!std.mem.eql(u8, decision.mode, "local")) return error.UnsupportedDecisionSchema;
    if (!std.mem.eql(u8, decision.decision, "approved")) return error.DecisionNotApproved;
    if (!std.mem.eql(u8, decision.approval_status, "approved")) return error.DecisionNotApproved;
    if (decision.applied) return error.DecisionAlreadyApplied;
}

fn proposalInputFromDecision(options: ProposalOptions, decision_path: []const u8, decision: DecisionRecord) ProposalInput {
    return .{
        .options = options,
        .target = decision.target,
        .source = .{
            .audit = decision.source.audit,
            .decision = decision_path,
            .artifacts = .{
                .verdict = decision.source.verdict,
                .diagnosis = decision.source.diagnosis,
                .remediation_plan = decision.source.remediation_plan,
                .advice = decision.source.advice,
                .query = decision.source.query,
                .compare = decision.source.compare,
            },
        },
        .event_ids = decision.event_ids,
        .verification_commands = decision.verification_commands,
        .claim_guardrails = decision.claim_guardrails,
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

fn formatProposalText(allocator: std.mem.Allocator, input: ProposalInput) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal patch proposal\n");
    try output.print(allocator, "schema: {s}\n", .{proposal_schema});
    try output.print(allocator, "mode: {s}\n", .{input.options.mode});
    try output.print(allocator, "target: {s}\n", .{input.target});
    try output.print(allocator, "proposal_status: {s}\n", .{proposalStatusText(input.options.status)});
    try output.print(allocator, "approval_status: {s}\n", .{approvalStatusText(input.options.status)});
    try output.print(allocator, "approved: {}\n", .{approvedBool(input.options.status)});
    try output.appendSlice(allocator, "applied: false\n");
    try output.print(allocator, "summary: {s}\n\n", .{input.options.summary});

    try output.appendSlice(allocator, "source:\n");
    try output.print(allocator, "- audit: {s}\n", .{input.source.audit});
    if (input.source.decision) |decision| {
        try output.print(allocator, "- decision: {s}\n", .{decision});
    } else {
        try output.appendSlice(allocator, "- decision: none\n");
    }
    try output.print(allocator, "- verdict: {s}\n", .{input.source.artifacts.verdict});
    try output.print(allocator, "- diagnosis: {s}\n", .{input.source.artifacts.diagnosis});
    try output.print(allocator, "- remediation plan: {s}\n", .{input.source.artifacts.remediation_plan});
    try output.print(allocator, "- advice: {s}\n", .{input.source.artifacts.advice});
    try output.print(allocator, "- query: {s}\n", .{input.source.artifacts.query});
    if (input.source.artifacts.compare) |compare| {
        try output.print(allocator, "- compare: {s}\n\n", .{compare});
    } else {
        try output.appendSlice(allocator, "- compare: none\n\n");
    }

    try output.appendSlice(allocator, "proposed changes:\n");
    try output.print(allocator, "- {s}: {s}\n\n", .{ input.options.file, input.options.change });

    try output.appendSlice(allocator, "evidence:\n");
    if (input.event_ids.len == 0) {
        try output.appendSlice(allocator, "- none\n\n");
    } else {
        for (input.event_ids) |event_id| try output.print(allocator, "- event {d}\n", .{event_id});
        try output.append(allocator, '\n');
    }

    try output.appendSlice(allocator, "verification:\n");
    for (input.verification_commands) |command| try output.print(allocator, "- `{s}`\n", .{command});
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "claim guardrails:\n");
    for (input.claim_guardrails) |guardrail| try output.print(allocator, "- {s}\n", .{guardrail});
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "proposal guardrails:\n");
    try output.print(allocator, "- {s}\n", .{firstProposalGuardrail()});
    try output.print(allocator, "- {s}\n", .{secondProposalGuardrail(input.options.status)});
    try output.print(allocator, "- {s}\n", .{thirdProposalGuardrail()});

    return output.toOwnedSlice(allocator);
}

fn readArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingPatchProposalInput,
        else => return err,
    };
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

const PatchProposalEvalArtifactFileSink = struct {
    io: std.Io,
    path: []const u8,

    fn sink(self: *PatchProposalEvalArtifactFileSink) fx.AgentEvalDiffArtifactSink {
        return .{ .state = self, .write = write };
    }

    fn write(raw: ?*anyopaque, json: []const u8) anyerror!void {
        const self: *PatchProposalEvalArtifactFileSink = @ptrCast(@alignCast(raw.?));
        try writeArtifact(self.io, self.path, json);
    }
};

fn writePatchProposalEvalArtifacts(
    allocator: std.mem.Allocator,
    input: ProposalInput,
    paths: PatchProposalEvalArtifactPaths,
    sinks: PatchProposalEvalArtifactSinks,
) anyerror!fx.AgentEvalResult {
    std.debug.assert(input.options.status == .approved);

    const baseline = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .run_started, .run_id = 1, .status = "started" },
        .{ .id = 2, .kind = .fiber_suspended, .run_id = 1, .fiber_id = 9, .status = "suspended", .label = "patch proposal eval suspended fiber" },
    };
    const policy = (fx.AgentInterventionPolicy{})
        .withApplyEnabled(true)
        .withKindPolicy(.interrupt_fiber, .auto_approve);
    const invariants = fx.CausalInvariantBuilder.init().requireSuspendedFibersResolve();
    const eval_name = try std.fmt.allocPrint(allocator, "patch proposal eval: {s}", .{paths.proposal_json_path});
    defer allocator.free(eval_name);

    return try fx.runAgentEvalAndWriteLinkedDiffManifest(allocator, .{
        .name = eval_name,
        .baseline = &baseline,
        .policy = policy,
        .request = .{
            .kind = .interrupt_fiber,
            .run_id = 1,
            .fiber_id = 9,
            .reason = "patch proposal built-in eval interrupt",
        },
        .invariants = invariants,
        .expect_improvement = true,
    }, input.source.artifacts.verdict, paths.proposal_json_path, .{
        .diff_artifact_path = paths.diff_path,
        .link_artifact_path = paths.link_path,
    }, sinks.diff, sinks.link, sinks.manifest);
}

fn writeProposal(init: std.process.Init, proposal_json_path: []const u8, proposal_text_path: []const u8, input: ProposalInput) !void {
    const allocator = init.gpa;
    const json_report = try formatProposalJson(allocator, input);
    defer allocator.free(json_report);
    const text_report = try formatProposalText(allocator, input);
    defer allocator.free(text_report);

    try writeArtifact(init.io, proposal_json_path, json_report);
    try writeArtifact(init.io, proposal_text_path, text_report);
    std.debug.print("{s}", .{text_report});
}

fn runLocal(init: std.process.Init, options: ProposalOptions) !void {
    const allocator = init.gpa;

    if (options.scenario_slug) |slug| {
        _ = try causal_run.scenarioByName(slug);
    }

    const proposal_json_path = if (options.scenario_slug) |slug| try localProposalJsonPathForScenario(allocator, slug) else localProposalJsonPath();
    defer if (options.scenario_slug != null) allocator.free(proposal_json_path);
    const proposal_text_path = if (options.scenario_slug) |slug| try localProposalTextPathForScenario(allocator, slug) else localProposalTextPath();
    defer if (options.scenario_slug != null) allocator.free(proposal_text_path);
    const eval_diff_path = if (options.scenario_slug) |slug| try localProposalEvalDiffPathForScenario(allocator, slug) else localProposalEvalDiffPath();
    defer if (options.scenario_slug != null) allocator.free(eval_diff_path);
    const eval_link_path = if (options.scenario_slug) |slug| try localProposalEvalLinkPathForScenario(allocator, slug) else localProposalEvalLinkPath();
    defer if (options.scenario_slug != null) allocator.free(eval_link_path);
    const eval_manifest_path = if (options.scenario_slug) |slug| try localProposalEvalManifestPathForScenario(allocator, slug) else localProposalEvalManifestPath();
    defer if (options.scenario_slug != null) allocator.free(eval_manifest_path);

    switch (options.status) {
        .draft => {
            const audit_path = if (options.scenario_slug) |slug| try localAuditJsonPathForScenario(allocator, slug) else localAuditJsonPath();
            defer if (options.scenario_slug != null) allocator.free(audit_path);

            const audit_json = try readArtifact(init.io, allocator, audit_path);
            defer allocator.free(audit_json);
            var parsed_audit = try std.json.parseFromSlice(AuditRecord, allocator, audit_json, .{ .ignore_unknown_fields = true });
            defer parsed_audit.deinit();
            try validateAuditRecord(parsed_audit.value);

            try writeProposal(init, proposal_json_path, proposal_text_path, proposalInputFromAudit(options, audit_path, parsed_audit.value));
        },
        .approved => {
            const decision_path = if (options.scenario_slug) |slug| try localDecisionJsonPathForScenario(allocator, slug) else localDecisionJsonPath();
            defer if (options.scenario_slug != null) allocator.free(decision_path);

            const decision_json = try readArtifact(init.io, allocator, decision_path);
            defer allocator.free(decision_json);
            var parsed_decision = try std.json.parseFromSlice(DecisionRecord, allocator, decision_json, .{ .ignore_unknown_fields = true });
            defer parsed_decision.deinit();
            try validateDecisionRecord(parsed_decision.value);

            const input = proposalInputFromDecision(options, decision_path, parsed_decision.value);
            try writeProposal(init, proposal_json_path, proposal_text_path, input);
            var diff_sink = PatchProposalEvalArtifactFileSink{ .io = init.io, .path = eval_diff_path };
            var link_sink = PatchProposalEvalArtifactFileSink{ .io = init.io, .path = eval_link_path };
            var manifest_sink = PatchProposalEvalArtifactFileSink{ .io = init.io, .path = eval_manifest_path };
            _ = try writePatchProposalEvalArtifacts(allocator, input, .{
                .diff_path = eval_diff_path,
                .link_path = eval_link_path,
                .manifest_path = eval_manifest_path,
                .proposal_json_path = proposal_json_path,
            }, .{
                .diff = diff_sink.sink(),
                .link = link_sink.sink(),
                .manifest = manifest_sink.sink(),
            });
        },
    }
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-patch-proposal error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseProposalOptions(args) catch |err| switch (err) {
        error.MissingMode,
        error.UnknownMode,
        error.MissingProposalStatus,
        error.UnknownProposalStatus,
        error.DuplicateScenarioArgument,
        error.UnknownFlag,
        error.MissingFlagValue,
        error.MissingSummary,
        error.MissingFile,
        error.MissingChange,
        => failUsage(err),
    };

    runLocal(init, options) catch |err| switch (err) {
        error.UnknownScenario,
        error.MissingPatchProposalInput,
        error.UnsupportedAuditSchema,
        error.UnsupportedDecisionSchema,
        error.AuditNotPending,
        error.AuditAlreadyApplied,
        error.DecisionNotApproved,
        error.DecisionAlreadyApplied,
        error.InvalidArtifactPath,
        => failUsage(err),
        else => return err,
    };
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

const approved_decision_json =
    \\{
    \\  "schema": "zigeffect.causal.remediation-decision.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "dogfood",
    \\  "decision": "approved",
    \\  "approval_status": "approved",
    \\  "decided_by": "local-reviewer",
    \\  "policy": "manual-review",
    \\  "reason": "reviewed local remediation audit",
    \\  "applied": false,
    \\  "source": {
    \\    "audit": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
    \\    "verdict": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
    \\    "diagnosis": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
    \\    "remediation_plan": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md",
    \\    "advice": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
    \\    "query": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt",
    \\    "compare": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt"
    \\  },
    \\  "event_ids": [3, 4, 5, 6],
    \\  "verification_commands": ["zig build causal-dev-loop -- baseline", "zig build causal-dev-loop -- after", "zig build causal-diagnosis -- local", "zig build test --summary none"],
    \\  "claim_guardrails": ["Do not claim this patch fixed persisting evidence unless the after verdict is clear or the compare report shows fewer findings."],
    \\  "decision_guardrails": ["Approval does not apply source changes.", "Run required verification after any future patch before claiming a fix."]
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

test "decision validation accepts approved unapplied decision only" {
    var parsed = try std.json.parseFromSlice(DecisionRecord, std.testing.allocator, approved_decision_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try validateDecisionRecord(parsed.value);

    var rejected = parsed.value;
    rejected.decision = "rejected";
    rejected.approval_status = "rejected";
    try std.testing.expectError(error.DecisionNotApproved, validateDecisionRecord(rejected));

    var applied = parsed.value;
    applied.applied = true;
    try std.testing.expectError(error.DecisionAlreadyApplied, validateDecisionRecord(applied));
}

test "approved proposal JSON carries decision evidence without applying source changes" {
    var parsed = try std.json.parseFromSlice(DecisionRecord, std.testing.allocator, approved_decision_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const input = proposalInputFromDecision(
        .{
            .mode = "local",
            .status = .approved,
            .summary = "tighten scope close ordering",
            .file = "packages/zigeffect/src/core/scope.zig",
            .change = "ensure child finalizers run before parent close is reported",
        },
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json",
        parsed.value,
    );

    const json = try formatProposalJson(std.testing.allocator, input);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"proposal_status\": \"approved\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"approval_status\": \"approved\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"approved\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"decision\": \".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"audit\": \".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"Approval permits reviewable patch work but does not prove the fix.\"") != null);
}

const PatchProposalEvalArtifactCapture = struct {
    diff_writes: usize = 0,
    link_writes: usize = 0,
    manifest_writes: usize = 0,
    saw_diff_schema: bool = false,
    saw_link_schema: bool = false,
    saw_manifest_schema: bool = false,
    saw_manifest_proposal_path: bool = false,

    fn diffSink(self: *PatchProposalEvalArtifactCapture) fx.AgentEvalDiffArtifactSink {
        return .{ .state = self, .write = writeDiff };
    }

    fn linkSink(self: *PatchProposalEvalArtifactCapture) fx.AgentEvalDiffArtifactSink {
        return .{ .state = self, .write = writeLink };
    }

    fn manifestSink(self: *PatchProposalEvalArtifactCapture) fx.AgentEvalDiffArtifactSink {
        return .{ .state = self, .write = writeManifest };
    }

    fn writeDiff(raw: ?*anyopaque, json: []const u8) anyerror!void {
        const self: *PatchProposalEvalArtifactCapture = @ptrCast(@alignCast(raw.?));
        self.diff_writes += 1;
        self.saw_diff_schema = std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.agent-eval-diff.v1\"") != null;
    }

    fn writeLink(raw: ?*anyopaque, json: []const u8) anyerror!void {
        const self: *PatchProposalEvalArtifactCapture = @ptrCast(@alignCast(raw.?));
        self.link_writes += 1;
        self.saw_link_schema = std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.agent-eval-diff-link.v1\"") != null;
    }

    fn writeManifest(raw: ?*anyopaque, json: []const u8) anyerror!void {
        const self: *PatchProposalEvalArtifactCapture = @ptrCast(@alignCast(raw.?));
        self.manifest_writes += 1;
        self.saw_manifest_schema = std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.agent-eval-linked-manifest.v1\"") != null;
        self.saw_manifest_proposal_path = std.mem.indexOf(u8, json, "zigeffect-causal-dev-loop-patch-proposal.json") != null;
    }
};

test "approved patch proposal writes linked eval manifest artifacts" {
    var parsed = try std.json.parseFromSlice(DecisionRecord, std.testing.allocator, approved_decision_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const input = proposalInputFromDecision(
        .{
            .mode = "local",
            .status = .approved,
            .summary = "record scoped fiber interruption",
            .file = "packages/zigeffect/src/runtime/fiber.zig",
            .change = "emit interrupted event before release evidence",
        },
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json",
        parsed.value,
    );

    var capture = PatchProposalEvalArtifactCapture{};
    const result = try writePatchProposalEvalArtifacts(std.testing.allocator, input, .{
        .diff_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal-eval-diff.json",
        .link_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal-eval-link.json",
        .manifest_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal-eval-manifest.json",
        .proposal_json_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.json",
    }, .{
        .diff = capture.diffSink(),
        .link = capture.linkSink(),
        .manifest = capture.manifestSink(),
    });

    try std.testing.expect(result.passed);
    try std.testing.expectEqual(@as(usize, 1), capture.diff_writes);
    try std.testing.expectEqual(@as(usize, 1), capture.link_writes);
    try std.testing.expectEqual(@as(usize, 1), capture.manifest_writes);
    try std.testing.expect(capture.saw_diff_schema);
    try std.testing.expect(capture.saw_link_schema);
    try std.testing.expect(capture.saw_manifest_schema);
    try std.testing.expect(capture.saw_manifest_proposal_path);
}
