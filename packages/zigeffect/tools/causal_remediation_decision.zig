const std = @import("std");
const causal_run = @import("causal_run");
const fx = @import("zigeffect");

const audit_schema = "zigeffect.causal.remediation-audit.v1";
const decision_schema = "zigeffect.causal.remediation-decision.v1";

const AuditSource = struct {
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
    source: AuditSource,
    event_ids: []const u64,
    verification_commands: []const []const u8,
    claim_guardrails: []const []const u8,
};

const DecisionKind = enum {
    approved,
    rejected,
};

const DecisionOptions = struct {
    mode: []const u8,
    kind: DecisionKind,
    scenario_slug: ?[]const u8 = null,
    decided_by: []const u8 = "local-reviewer",
    policy: []const u8 = "none",
    reason: []const u8,
};

const DecisionInput = struct {
    audit_path: []const u8,
    audit: AuditRecord,
    options: DecisionOptions,
};

const DecisionEvalArtifactPaths = struct {
    diff_path: []const u8,
    link_path: []const u8,
    manifest_path: []const u8,
    decision_json_path: []const u8,
};

const DecisionEvalArtifactSinks = struct {
    diff: fx.AgentEvalDiffArtifactSink,
    link: fx.AgentEvalDiffArtifactSink,
    manifest: fx.AgentEvalDiffArtifactSink,
};

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

fn localDecisionTextPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-decision.txt";
}

fn localDecisionJsonPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-remediation-decision.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn localDecisionTextPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-remediation-decision.txt",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn localDecisionEvalDiffPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-eval-diff.json";
}

fn localDecisionEvalLinkPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-eval-link.json";
}

fn localDecisionEvalManifestPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-eval-manifest.json";
}

fn localDecisionEvalDiffPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-remediation-eval-diff.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn localDecisionEvalLinkPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-remediation-eval-link.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn localDecisionEvalManifestPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-remediation-eval-manifest.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn parseDecisionOptions(args: []const []const u8) !DecisionOptions {
    if (args.len < 2) return error.MissingMode;
    if (!std.mem.eql(u8, args[1], "local")) return error.UnknownMode;
    if (args.len < 3) return error.MissingDecision;

    const kind: DecisionKind = if (std.mem.eql(u8, args[2], "approve"))
        .approved
    else if (std.mem.eql(u8, args[2], "reject"))
        .rejected
    else
        return error.UnknownDecision;

    var scenario_slug: ?[]const u8 = null;
    var decided_by: []const u8 = "local-reviewer";
    var policy: []const u8 = "none";
    var reason: ?[]const u8 = if (kind == .approved) "reviewed local remediation audit" else null;

    var index: usize = 3;
    while (index < args.len) {
        const arg = args[index];
        if (std.mem.startsWith(u8, arg, "--")) {
            if (index + 1 >= args.len) return error.MissingFlagValue;
            const value = args[index + 1];
            if (std.mem.eql(u8, arg, "--by")) {
                decided_by = value;
            } else if (std.mem.eql(u8, arg, "--policy")) {
                policy = value;
            } else if (std.mem.eql(u8, arg, "--reason")) {
                reason = value;
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

    if (kind == .rejected and reason == null) return error.MissingRejectionReason;

    return .{
        .mode = "local",
        .kind = kind,
        .scenario_slug = scenario_slug,
        .decided_by = decided_by,
        .policy = policy,
        .reason = reason.?,
    };
}

fn validateAuditRecord(audit: AuditRecord) !void {
    if (!std.mem.eql(u8, audit.schema, audit_schema)) return error.UnsupportedAuditSchema;
    if (audit.schema_version != 1) return error.UnsupportedAuditSchema;
    if (!std.mem.eql(u8, audit.mode, "local")) return error.UnsupportedAuditSchema;
    if (!std.mem.eql(u8, audit.approval_status, "pending")) return error.AuditAlreadyDecided;
    if (audit.applied) return error.AuditAlreadyApplied;
}

fn decisionText(kind: DecisionKind) []const u8 {
    return switch (kind) {
        .approved => "approved",
        .rejected => "rejected",
    };
}

fn firstDecisionGuardrail(kind: DecisionKind) []const u8 {
    return switch (kind) {
        .approved => "Approval does not apply source changes.",
        .rejected => "Rejected proposals must not be used as permission for source edits.",
    };
}

fn secondDecisionGuardrail(kind: DecisionKind) []const u8 {
    return switch (kind) {
        .approved => "Run required verification after any future patch before claiming a fix.",
        .rejected => "Create a new audit if evidence changes.",
    };
}

fn formatDecisionJson(allocator: std.mem.Allocator, input: DecisionInput) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, decision_schema);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"mode\": ");
    try appendJsonString(allocator, &output, input.options.mode);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"target\": ");
    try appendJsonString(allocator, &output, input.audit.target);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"decision\": ");
    try appendJsonString(allocator, &output, decisionText(input.options.kind));
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"approval_status\": ");
    try appendJsonString(allocator, &output, decisionText(input.options.kind));
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"decided_by\": ");
    try appendJsonString(allocator, &output, input.options.decided_by);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"policy\": ");
    try appendJsonString(allocator, &output, input.options.policy);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"reason\": ");
    try appendJsonString(allocator, &output, input.options.reason);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"applied\": false,\n");
    try output.appendSlice(allocator, "  \"source\": {\n");
    try appendSourceJson(allocator, &output, input);
    try output.appendSlice(allocator, "  },\n");
    try output.appendSlice(allocator, "  \"event_ids\": ");
    try appendU64Array(allocator, &output, input.audit.event_ids);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"verification_commands\": ");
    try appendStringArray(allocator, &output, input.audit.verification_commands);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"claim_guardrails\": ");
    try appendStringArray(allocator, &output, input.audit.claim_guardrails);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"decision_guardrails\": [");
    try appendJsonString(allocator, &output, firstDecisionGuardrail(input.options.kind));
    try output.appendSlice(allocator, ", ");
    try appendJsonString(allocator, &output, secondDecisionGuardrail(input.options.kind));
    try output.appendSlice(allocator, "]\n");
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

fn appendSourceJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: DecisionInput) !void {
    try output.appendSlice(allocator, "    \"audit\": ");
    try appendJsonString(allocator, output, input.audit_path);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"verdict\": ");
    try appendJsonString(allocator, output, input.audit.source.verdict);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"diagnosis\": ");
    try appendJsonString(allocator, output, input.audit.source.diagnosis);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"remediation_plan\": ");
    try appendJsonString(allocator, output, input.audit.source.remediation_plan);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"advice\": ");
    try appendJsonString(allocator, output, input.audit.source.advice);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"query\": ");
    try appendJsonString(allocator, output, input.audit.source.query);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"compare\": ");
    if (input.audit.source.compare) |compare| {
        try appendJsonString(allocator, output, compare);
    } else {
        try output.appendSlice(allocator, "null");
    }
    try output.append(allocator, '\n');
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

fn formatDecisionText(allocator: std.mem.Allocator, input: DecisionInput) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal remediation decision\n");
    try output.print(allocator, "schema: {s}\n", .{decision_schema});
    try output.print(allocator, "mode: {s}\n", .{input.options.mode});
    try output.print(allocator, "target: {s}\n", .{input.audit.target});
    try output.print(allocator, "decision: {s}\n", .{decisionText(input.options.kind)});
    try output.print(allocator, "approval_status: {s}\n", .{decisionText(input.options.kind)});
    try output.print(allocator, "decided_by: {s}\n", .{input.options.decided_by});
    try output.print(allocator, "policy: {s}\n", .{input.options.policy});
    try output.print(allocator, "reason: {s}\n", .{input.options.reason});
    try output.appendSlice(allocator, "applied: false\n\n");

    try output.appendSlice(allocator, "source:\n");
    try output.print(allocator, "- audit: {s}\n", .{input.audit_path});
    try output.print(allocator, "- verdict: {s}\n", .{input.audit.source.verdict});
    try output.print(allocator, "- diagnosis: {s}\n", .{input.audit.source.diagnosis});
    try output.print(allocator, "- remediation plan: {s}\n", .{input.audit.source.remediation_plan});
    try output.print(allocator, "- advice: {s}\n", .{input.audit.source.advice});
    try output.print(allocator, "- query: {s}\n", .{input.audit.source.query});
    if (input.audit.source.compare) |compare| {
        try output.print(allocator, "- compare: {s}\n\n", .{compare});
    } else {
        try output.appendSlice(allocator, "- compare: none\n\n");
    }

    try output.appendSlice(allocator, "evidence:\n");
    if (input.audit.event_ids.len == 0) {
        try output.appendSlice(allocator, "- none\n\n");
    } else {
        for (input.audit.event_ids) |event_id| try output.print(allocator, "- event {d}\n", .{event_id});
        try output.append(allocator, '\n');
    }

    try output.appendSlice(allocator, "verification:\n");
    for (input.audit.verification_commands) |command| try output.print(allocator, "- `{s}`\n", .{command});
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "claim guardrails:\n");
    for (input.audit.claim_guardrails) |guardrail| try output.print(allocator, "- {s}\n", .{guardrail});
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "decision guardrails:\n");
    try output.print(allocator, "- {s}\n", .{firstDecisionGuardrail(input.options.kind)});
    try output.print(allocator, "- {s}\n", .{secondDecisionGuardrail(input.options.kind)});

    return output.toOwnedSlice(allocator);
}

fn usage() []const u8 {
    return "usage: zig build causal-remediation-decision -- local approve|reject [scenario] [--by <actor>] [--policy <policy>] [--reason <reason>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-remediation-decision error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn readArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingRemediationDecisionInput,
        else => return err,
    };
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

const DecisionEvalArtifactFileSink = struct {
    io: std.Io,
    path: []const u8,

    fn sink(self: *DecisionEvalArtifactFileSink) fx.AgentEvalDiffArtifactSink {
        return .{ .state = self, .write = write };
    }

    fn write(raw: ?*anyopaque, json: []const u8) anyerror!void {
        const self: *DecisionEvalArtifactFileSink = @ptrCast(@alignCast(raw.?));
        try writeArtifact(self.io, self.path, json);
    }
};

fn writeDecisionEvalArtifacts(
    allocator: std.mem.Allocator,
    input: DecisionInput,
    paths: DecisionEvalArtifactPaths,
    sinks: DecisionEvalArtifactSinks,
) anyerror!fx.AgentEvalResult {
    std.debug.assert(input.options.kind == .approved);

    const baseline = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .run_started, .run_id = 1, .status = "started" },
        .{ .id = 2, .kind = .fiber_suspended, .run_id = 1, .fiber_id = 9, .status = "suspended", .label = "remediation decision eval suspended fiber" },
    };
    const policy = (fx.AgentInterventionPolicy{})
        .withApplyEnabled(true)
        .withKindPolicy(.interrupt_fiber, .auto_approve);
    const invariants = fx.CausalInvariantBuilder.init().requireSuspendedFibersResolve();
    const eval_name = try std.fmt.allocPrint(allocator, "remediation decision eval: {s}", .{paths.decision_json_path});
    defer allocator.free(eval_name);

    return try fx.runAgentEvalAndWriteLinkedDiffManifest(allocator, .{
        .name = eval_name,
        .baseline = &baseline,
        .policy = policy,
        .request = .{
            .kind = .interrupt_fiber,
            .run_id = 1,
            .fiber_id = 9,
            .reason = "remediation decision built-in eval interrupt",
        },
        .invariants = invariants,
        .expect_improvement = true,
    }, input.audit.source.verdict, paths.decision_json_path, .{
        .diff_artifact_path = paths.diff_path,
        .link_artifact_path = paths.link_path,
    }, sinks.diff, sinks.link, sinks.manifest);
}

fn runLocal(init: std.process.Init, options: DecisionOptions) !void {
    const allocator = init.gpa;
    const audit_path = if (options.scenario_slug) |slug| try localAuditJsonPathForScenario(allocator, slug) else localAuditJsonPath();
    defer if (options.scenario_slug != null) allocator.free(audit_path);
    const decision_json_path = if (options.scenario_slug) |slug| try localDecisionJsonPathForScenario(allocator, slug) else localDecisionJsonPath();
    defer if (options.scenario_slug != null) allocator.free(decision_json_path);
    const decision_text_path = if (options.scenario_slug) |slug| try localDecisionTextPathForScenario(allocator, slug) else localDecisionTextPath();
    defer if (options.scenario_slug != null) allocator.free(decision_text_path);
    const eval_diff_path = if (options.scenario_slug) |slug| try localDecisionEvalDiffPathForScenario(allocator, slug) else localDecisionEvalDiffPath();
    defer if (options.scenario_slug != null) allocator.free(eval_diff_path);
    const eval_link_path = if (options.scenario_slug) |slug| try localDecisionEvalLinkPathForScenario(allocator, slug) else localDecisionEvalLinkPath();
    defer if (options.scenario_slug != null) allocator.free(eval_link_path);
    const eval_manifest_path = if (options.scenario_slug) |slug| try localDecisionEvalManifestPathForScenario(allocator, slug) else localDecisionEvalManifestPath();
    defer if (options.scenario_slug != null) allocator.free(eval_manifest_path);

    const audit_json = try readArtifact(init.io, allocator, audit_path);
    defer allocator.free(audit_json);
    var parsed_audit = try std.json.parseFromSlice(AuditRecord, allocator, audit_json, .{ .ignore_unknown_fields = true });
    defer parsed_audit.deinit();
    try validateAuditRecord(parsed_audit.value);

    const input = DecisionInput{
        .audit_path = audit_path,
        .audit = parsed_audit.value,
        .options = options,
    };

    const json_report = try formatDecisionJson(allocator, input);
    defer allocator.free(json_report);
    const text_report = try formatDecisionText(allocator, input);
    defer allocator.free(text_report);

    try writeArtifact(init.io, decision_json_path, json_report);
    try writeArtifact(init.io, decision_text_path, text_report);
    if (options.kind == .approved) {
        var diff_sink = DecisionEvalArtifactFileSink{ .io = init.io, .path = eval_diff_path };
        var link_sink = DecisionEvalArtifactFileSink{ .io = init.io, .path = eval_link_path };
        var manifest_sink = DecisionEvalArtifactFileSink{ .io = init.io, .path = eval_manifest_path };
        _ = try writeDecisionEvalArtifacts(allocator, input, .{
            .diff_path = eval_diff_path,
            .link_path = eval_link_path,
            .manifest_path = eval_manifest_path,
            .decision_json_path = decision_json_path,
        }, .{
            .diff = diff_sink.sink(),
            .link = link_sink.sink(),
            .manifest = manifest_sink.sink(),
        });
    }
    std.debug.print("{s}", .{text_report});
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseDecisionOptions(args) catch |err| switch (err) {
        error.MissingMode,
        error.UnknownMode,
        error.MissingDecision,
        error.UnknownDecision,
        error.DuplicateScenarioArgument,
        error.UnknownFlag,
        error.MissingFlagValue,
        error.MissingRejectionReason,
        => failUsage(err),
    };

    if (options.scenario_slug) |slug| {
        _ = causal_run.scenarioByName(slug) catch |err| failUsage(err);
    }

    runLocal(init, options) catch |err| switch (err) {
        error.MissingRemediationDecisionInput,
        error.UnsupportedAuditSchema,
        error.AuditAlreadyDecided,
        error.AuditAlreadyApplied,
        error.InvalidArtifactPath,
        => failUsage(err),
        else => return err,
    };
}

const approved_audit_json =
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

test "decision output paths are stable for default and scenario targets" {
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json",
        localDecisionJsonPath(),
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.txt",
        localDecisionTextPath(),
    );

    const scenario_json = try localDecisionJsonPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario_json);
    const scenario_text = try localDecisionTextPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario_text);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-decision.json",
        scenario_json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-decision.txt",
        scenario_text,
    );
}

test "parse options accepts approve defaults and optional metadata" {
    const args = [_][]const u8{
        "zigeffect-causal-remediation-decision",
        "local",
        "approve",
        "--by",
        "local-reviewer",
        "--policy",
        "manual-review",
    };

    const options = try parseDecisionOptions(args[0..]);
    try std.testing.expectEqual(DecisionKind.approved, options.kind);
    try std.testing.expect(options.scenario_slug == null);
    try std.testing.expectEqualStrings("local-reviewer", options.decided_by);
    try std.testing.expectEqualStrings("manual-review", options.policy);
    try std.testing.expectEqualStrings("reviewed local remediation audit", options.reason);
}

test "parse options accepts reject scenario and requires reason" {
    const args = [_][]const u8{
        "zigeffect-causal-remediation-decision",
        "local",
        "reject",
        "causal-scoped-fiber",
        "--reason",
        "clear verdict",
    };

    const options = try parseDecisionOptions(args[0..]);
    try std.testing.expectEqual(DecisionKind.rejected, options.kind);
    try std.testing.expectEqualStrings("causal-scoped-fiber", options.scenario_slug.?);
    try std.testing.expectEqualStrings("clear verdict", options.reason);

    const missing_reason = [_][]const u8{
        "zigeffect-causal-remediation-decision",
        "local",
        "reject",
    };
    try std.testing.expectError(error.MissingRejectionReason, parseDecisionOptions(missing_reason[0..]));
}

test "audit validation rejects non pending or applied audits" {
    var parsed = try std.json.parseFromSlice(AuditRecord, std.testing.allocator, approved_audit_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try validateAuditRecord(parsed.value);

    var non_pending = parsed.value;
    non_pending.approval_status = "approved";
    try std.testing.expectError(error.AuditAlreadyDecided, validateAuditRecord(non_pending));

    var applied = parsed.value;
    applied.applied = true;
    try std.testing.expectError(error.AuditAlreadyApplied, validateAuditRecord(applied));
}

test "decision JSON records approval without applying source changes" {
    var parsed = try std.json.parseFromSlice(AuditRecord, std.testing.allocator, approved_audit_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const json = try formatDecisionJson(std.testing.allocator, .{
        .audit_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
        .audit = parsed.value,
        .options = .{
            .mode = "local",
            .kind = .approved,
            .decided_by = "local-reviewer",
            .policy = "manual-review",
            .reason = "reviewed local remediation audit",
        },
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\": \"zigeffect.causal.remediation-decision.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"decision\": \"approved\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"approval_status\": \"approved\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"audit\": \".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"event_ids\": [3, 4, 5, 6]") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"Approval does not apply source changes.\"") != null);
}

test "decision text records rejection reason and guardrails" {
    var parsed = try std.json.parseFromSlice(AuditRecord, std.testing.allocator, approved_audit_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const text = try formatDecisionText(std.testing.allocator, .{
        .audit_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
        .audit = parsed.value,
        .options = .{
            .mode = "local",
            .kind = .rejected,
            .decided_by = "local-reviewer",
            .policy = "none",
            .reason = "intentional fixture",
        },
    });
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect causal remediation decision") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "decision: rejected") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "reason: intentional fixture") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "Rejected proposals must not be used as permission for source edits.") != null);
}

const DecisionEvalArtifactCapture = struct {
    diff_writes: usize = 0,
    link_writes: usize = 0,
    manifest_writes: usize = 0,
    saw_diff_schema: bool = false,
    saw_link_schema: bool = false,
    saw_manifest_schema: bool = false,
    saw_manifest_decision_path: bool = false,

    fn diffSink(self: *DecisionEvalArtifactCapture) fx.AgentEvalDiffArtifactSink {
        return .{ .state = self, .write = writeDiff };
    }

    fn linkSink(self: *DecisionEvalArtifactCapture) fx.AgentEvalDiffArtifactSink {
        return .{ .state = self, .write = writeLink };
    }

    fn manifestSink(self: *DecisionEvalArtifactCapture) fx.AgentEvalDiffArtifactSink {
        return .{ .state = self, .write = writeManifest };
    }

    fn writeDiff(raw: ?*anyopaque, json: []const u8) anyerror!void {
        const self: *DecisionEvalArtifactCapture = @ptrCast(@alignCast(raw.?));
        self.diff_writes += 1;
        self.saw_diff_schema = std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.agent-eval-diff.v1\"") != null;
    }

    fn writeLink(raw: ?*anyopaque, json: []const u8) anyerror!void {
        const self: *DecisionEvalArtifactCapture = @ptrCast(@alignCast(raw.?));
        self.link_writes += 1;
        self.saw_link_schema = std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.agent-eval-diff-link.v1\"") != null;
    }

    fn writeManifest(raw: ?*anyopaque, json: []const u8) anyerror!void {
        const self: *DecisionEvalArtifactCapture = @ptrCast(@alignCast(raw.?));
        self.manifest_writes += 1;
        self.saw_manifest_schema = std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.agent-eval-linked-manifest.v1\"") != null;
        self.saw_manifest_decision_path = std.mem.indexOf(u8, json, "zigeffect-causal-dev-loop-remediation-decision.json") != null;
    }
};

test "approved remediation decision writes linked eval manifest artifacts" {
    var parsed = try std.json.parseFromSlice(AuditRecord, std.testing.allocator, approved_audit_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    var capture = DecisionEvalArtifactCapture{};
    const result = try writeDecisionEvalArtifacts(
        std.testing.allocator,
        .{
            .audit_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
            .audit = parsed.value,
            .options = .{
                .mode = "local",
                .kind = .approved,
                .decided_by = "local-reviewer",
                .policy = "manual-review",
                .reason = "reviewed local remediation audit",
            },
        },
        .{
            .diff_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-eval-diff.json",
            .link_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-eval-link.json",
            .manifest_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-eval-manifest.json",
            .decision_json_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json",
        },
        .{
            .diff = capture.diffSink(),
            .link = capture.linkSink(),
            .manifest = capture.manifestSink(),
        },
    );

    try std.testing.expect(result.passed);
    try std.testing.expectEqual(@as(usize, 1), capture.diff_writes);
    try std.testing.expectEqual(@as(usize, 1), capture.link_writes);
    try std.testing.expectEqual(@as(usize, 1), capture.manifest_writes);
    try std.testing.expect(capture.saw_diff_schema);
    try std.testing.expect(capture.saw_link_schema);
    try std.testing.expect(capture.saw_manifest_schema);
    try std.testing.expect(capture.saw_manifest_decision_path);
}

test "usage names local decision shape" {
    try std.testing.expectEqualStrings(
        "usage: zig build causal-remediation-decision -- local approve|reject [scenario] [--by <actor>] [--policy <policy>] [--reason <reason>]\n",
        usage(),
    );
}

test "audit paths are stable for default and scenario targets" {
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
        localAuditJsonPath(),
    );

    const scenario = try localAuditJsonPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.json",
        scenario,
    );
}
