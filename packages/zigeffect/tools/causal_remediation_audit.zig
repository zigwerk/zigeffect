const std = @import("std");
const causal_run = @import("causal_run");

const supported_local_schema = "zigeffect.causal.dev-loop-verdict.v1";
const audit_schema = "zigeffect.causal.remediation-audit.v1";

const Verdict = struct {
    schema: []const u8,
    schema_version: u32,
    status: []const u8,
    next_action: []const u8,
    json_artifacts: usize,
    baseline_pairs: usize,
    actions: usize,
    new_actions: usize,
    persisting_actions: usize,
    observed_actions: usize,
    artifacts: []const VerdictArtifact,
};

const VerdictArtifact = struct {
    json_path: []const u8,
    baseline_path: ?[]const u8,
    advice_report_path: []const u8,
    compare_report_path: ?[]const u8,
    actions: usize,
    new_actions: usize,
    persisting_actions: usize,
    observed_actions: usize,
};

const SourcePaths = struct {
    verdict: []const u8,
    diagnosis: []const u8,
    remediation_plan: []const u8,
    advice: []const u8,
    query: []const u8,
    compare: ?[]const u8,
};

const ParsedPlan = struct {
    target: []const u8,
    posture: []const u8,
    event_ids: []const u64,
    verification_commands: []const []const u8,
    claim_guardrails: []const []const u8,
};

const AuditInput = struct {
    mode: []const u8,
    target: []const u8,
    proposer: []const u8,
    source: SourcePaths,
    plan: ParsedPlan,
};

fn localAuditJsonPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-audit.json";
}

fn localAuditTextPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-audit.txt";
}

fn localAuditJsonPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-remediation-audit.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn localAuditTextPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-remediation-audit.txt",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn parseRemediationPlan(allocator: std.mem.Allocator, plan_text: []const u8) !ParsedPlan {
    var target: ?[]const u8 = null;
    errdefer if (target) |value| allocator.free(value);
    var posture: ?[]const u8 = null;
    errdefer if (posture) |value| allocator.free(value);
    var event_ids = std.ArrayList(u64).empty;
    errdefer event_ids.deinit(allocator);
    var verification_commands = std.ArrayList([]const u8).empty;
    errdefer deinitOwnedStringList(allocator, &verification_commands);
    var claim_guardrails = std.ArrayList([]const u8).empty;
    errdefer deinitOwnedStringList(allocator, &claim_guardrails);

    var section: enum { none, verification, guardrails } = .none;
    var lines = std.mem.splitScalar(u8, plan_text, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "target: ")) {
            const owned = try allocator.dupe(u8, line["target: ".len..]);
            if (target) |value| allocator.free(value);
            target = owned;
            continue;
        }
        if (std.mem.startsWith(u8, line, "posture: ")) {
            const owned = try allocator.dupe(u8, line["posture: ".len..]);
            if (posture) |value| allocator.free(value);
            posture = owned;
            continue;
        }
        if (std.mem.eql(u8, line, "## Required Verification")) {
            section = .verification;
            continue;
        }
        if (std.mem.eql(u8, line, "## Claim Guardrails")) {
            section = .guardrails;
            continue;
        }
        if (std.mem.startsWith(u8, line, "## ")) {
            section = .none;
            continue;
        }
        if (std.mem.startsWith(u8, line, "- event ")) {
            const rest = line["- event ".len..];
            const end = std.mem.indexOfScalar(u8, rest, ' ') orelse return error.InvalidRemediationPlan;
            try event_ids.append(allocator, try std.fmt.parseInt(u64, rest[0..end], 10));
            continue;
        }

        switch (section) {
            .verification => {
                if (std.mem.startsWith(u8, line, "- `") and std.mem.endsWith(u8, line, "`")) {
                    try appendOwnedString(allocator, &verification_commands, line["- `".len .. line.len - 1]);
                }
            },
            .guardrails => {
                if (std.mem.startsWith(u8, line, "- ")) {
                    try appendOwnedString(allocator, &claim_guardrails, line["- ".len..]);
                }
            },
            .none => {},
        }
    }

    return .{
        .target = target orelse return error.InvalidRemediationPlan,
        .posture = posture orelse return error.InvalidRemediationPlan,
        .event_ids = try event_ids.toOwnedSlice(allocator),
        .verification_commands = try verification_commands.toOwnedSlice(allocator),
        .claim_guardrails = try claim_guardrails.toOwnedSlice(allocator),
    };
}

fn deinitParsedPlan(allocator: std.mem.Allocator, plan: ParsedPlan) void {
    allocator.free(plan.target);
    allocator.free(plan.posture);
    allocator.free(plan.event_ids);
    deinitOwnedStrings(allocator, plan.verification_commands);
    deinitOwnedStrings(allocator, plan.claim_guardrails);
}

fn deinitOwnedStrings(allocator: std.mem.Allocator, values: []const []const u8) void {
    for (values) |value| allocator.free(value);
    allocator.free(values);
}

fn deinitOwnedStringList(allocator: std.mem.Allocator, list: *std.ArrayList([]const u8)) void {
    for (list.items) |value| allocator.free(value);
    list.deinit(allocator);
}

fn appendOwnedString(allocator: std.mem.Allocator, list: *std.ArrayList([]const u8), value: []const u8) !void {
    const owned = try allocator.dupe(u8, value);
    errdefer allocator.free(owned);
    try list.append(allocator, owned);
}

fn formatAuditJson(allocator: std.mem.Allocator, input: AuditInput) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, audit_schema);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"mode\": ");
    try appendJsonString(allocator, &output, input.mode);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"target\": ");
    try appendJsonString(allocator, &output, input.target);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"proposer\": ");
    try appendJsonString(allocator, &output, input.proposer);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"approval_status\": \"pending\",\n");
    try output.appendSlice(allocator, "  \"applied\": false,\n");
    try output.appendSlice(allocator, "  \"posture\": ");
    try appendJsonString(allocator, &output, input.plan.posture);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"source\": {\n");
    try appendSourceJson(allocator, &output, input.source);
    try output.appendSlice(allocator, "  },\n");
    try output.appendSlice(allocator, "  \"event_ids\": ");
    try appendU64Array(allocator, &output, input.plan.event_ids);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"verification_commands\": ");
    try appendStringArray(allocator, &output, input.plan.verification_commands);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"claim_guardrails\": ");
    try appendStringArray(allocator, &output, input.plan.claim_guardrails);
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn appendSourceJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), source: SourcePaths) !void {
    try output.appendSlice(allocator, "    \"verdict\": ");
    try appendJsonString(allocator, output, source.verdict);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"diagnosis\": ");
    try appendJsonString(allocator, output, source.diagnosis);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"remediation_plan\": ");
    try appendJsonString(allocator, output, source.remediation_plan);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"advice\": ");
    try appendJsonString(allocator, output, source.advice);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"query\": ");
    try appendJsonString(allocator, output, source.query);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"compare\": ");
    if (source.compare) |compare| {
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

fn formatAuditText(allocator: std.mem.Allocator, input: AuditInput) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal remediation audit\n");
    try output.print(allocator, "schema: {s}\n", .{audit_schema});
    try output.print(allocator, "mode: {s}\n", .{input.mode});
    try output.print(allocator, "target: {s}\n", .{input.target});
    try output.print(allocator, "proposer: {s}\n", .{input.proposer});
    try output.appendSlice(allocator, "approval_status: pending\n");
    try output.appendSlice(allocator, "applied: false\n");
    try output.print(allocator, "posture: {s}\n\n", .{input.plan.posture});

    try output.appendSlice(allocator, "source:\n");
    try output.print(allocator, "- verdict: {s}\n", .{input.source.verdict});
    try output.print(allocator, "- diagnosis: {s}\n", .{input.source.diagnosis});
    try output.print(allocator, "- remediation plan: {s}\n", .{input.source.remediation_plan});
    try output.print(allocator, "- advice: {s}\n", .{input.source.advice});
    try output.print(allocator, "- query: {s}\n", .{input.source.query});
    if (input.source.compare) |compare| {
        try output.print(allocator, "- compare: {s}\n\n", .{compare});
    } else {
        try output.appendSlice(allocator, "- compare: none\n\n");
    }

    try output.appendSlice(allocator, "evidence:\n");
    if (input.plan.event_ids.len == 0) {
        try output.appendSlice(allocator, "- none\n\n");
    } else {
        for (input.plan.event_ids) |event_id| try output.print(allocator, "- event {d}\n", .{event_id});
        try output.append(allocator, '\n');
    }

    try output.appendSlice(allocator, "approval:\n");
    try output.appendSlice(allocator, "- status: pending\n");
    try output.appendSlice(allocator, "- approved_by: none\n");
    try output.appendSlice(allocator, "- policy: none\n");
    try output.appendSlice(allocator, "- applied: false\n\n");

    try output.appendSlice(allocator, "verification:\n");
    for (input.plan.verification_commands) |command| try output.print(allocator, "- `{s}`\n", .{command});
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "claim guardrails:\n");
    for (input.plan.claim_guardrails) |guardrail| try output.print(allocator, "- {s}\n", .{guardrail});
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "next:\n");
    try output.appendSlice(allocator, "- review remediation plan before source edits\n");
    try output.appendSlice(allocator, "- cite event ids when opening or summarizing a patch\n");
    try output.appendSlice(allocator, "- rerun the required verification commands before claiming a fix\n");

    return output.toOwnedSlice(allocator);
}

const remediation_plan_text =
    \\# zigeffect causal remediation plan
    \\
    \\mode: local
    \\target: dogfood
    \\posture: patch-candidate
    \\plan: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md
    \\verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
    \\diagnosis: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt
    \\
    \\## Evidence
    \\
    \\- event 3 `scope_closed` status=persisting
    \\  - subsystem: scope_lifecycle
    \\- event 4 `resource_acquired` status=persisting
    \\  - subsystem: scope_lifecycle
    \\
    \\## Required Verification
    \\
    \\- `zig build causal-dev-loop -- baseline`
    \\- `zig build causal-dev-loop -- after`
    \\- `zig build causal-diagnosis -- local`
    \\- `zig build test --summary none`
    \\
    \\## Claim Guardrails
    \\
    \\- Do not claim this patch fixed persisting evidence unless the after verdict is clear or the compare report shows fewer findings.
    \\- Cite event ids from the remediation evidence section in the patch summary.
    \\
;

const clear_plan_text =
    \\# zigeffect causal remediation plan
    \\
    \\mode: local
    \\target: causal-scoped-fiber
    \\posture: do-not-patch
    \\plan: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md
    \\verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json
    \\diagnosis: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt
    \\
    \\## Evidence
    \\
    \\- no causal advice actions selected
    \\
    \\## Required Verification
    \\
    \\- `zig build causal-dev-loop -- baseline causal-scoped-fiber`
    \\- `zig build causal-dev-loop -- after causal-scoped-fiber`
    \\- `zig build causal-diagnosis -- local causal-scoped-fiber`
    \\- `zig build test --summary none`
    \\
    \\## Claim Guardrails
    \\
    \\- Do not patch unrelated subsystems when the causal verdict is clear.
    \\
;

test "audit output paths are stable for default and scenario targets" {
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
        localAuditJsonPath(),
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.txt",
        localAuditTextPath(),
    );

    const scenario_json = try localAuditJsonPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario_json);
    const scenario_text = try localAuditTextPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario_text);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.json",
        scenario_json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.txt",
        scenario_text,
    );
}

test "plan parser extracts posture events verification and guardrails" {
    const plan = try parseRemediationPlan(std.testing.allocator, remediation_plan_text);
    defer deinitParsedPlan(std.testing.allocator, plan);

    try std.testing.expectEqualStrings("dogfood", plan.target);
    try std.testing.expectEqualStrings("patch-candidate", plan.posture);
    try std.testing.expectEqualSlices(u64, &.{ 3, 4 }, plan.event_ids);
    try std.testing.expectEqual(@as(usize, 4), plan.verification_commands.len);
    try std.testing.expectEqualStrings("zig build causal-dev-loop -- baseline", plan.verification_commands[0]);
    try std.testing.expectEqual(@as(usize, 2), plan.claim_guardrails.len);
    try std.testing.expect(std.mem.indexOf(u8, plan.claim_guardrails[0], "Do not claim") != null);
}

test "plan parser allows do-not-patch plan with no event ids" {
    const plan = try parseRemediationPlan(std.testing.allocator, clear_plan_text);
    defer deinitParsedPlan(std.testing.allocator, plan);

    try std.testing.expectEqualStrings("causal-scoped-fiber", plan.target);
    try std.testing.expectEqualStrings("do-not-patch", plan.posture);
    try std.testing.expectEqual(@as(usize, 0), plan.event_ids.len);
    try std.testing.expectEqualStrings("zig build causal-dev-loop -- baseline causal-scoped-fiber", plan.verification_commands[0]);
}

test "audit JSON records pending approval and source bundle" {
    const plan = try parseRemediationPlan(std.testing.allocator, remediation_plan_text);
    defer deinitParsedPlan(std.testing.allocator, plan);

    const json = try formatAuditJson(std.testing.allocator, .{
        .mode = "local",
        .target = "dogfood",
        .proposer = "local-agent",
        .source = .{
            .verdict = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
            .diagnosis = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
            .remediation_plan = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md",
            .advice = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
            .query = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt",
            .compare = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
        },
        .plan = plan,
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\": \"zigeffect.causal.remediation-audit.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"approval_status\": \"pending\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"event_ids\": [3, 4]") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"verification_commands\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"claim_guardrails\"") != null);
}

test "audit text mirrors approval state and evidence ids" {
    const plan = try parseRemediationPlan(std.testing.allocator, remediation_plan_text);
    defer deinitParsedPlan(std.testing.allocator, plan);

    const text = try formatAuditText(std.testing.allocator, .{
        .mode = "local",
        .target = "dogfood",
        .proposer = "local-agent",
        .source = .{
            .verdict = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
            .diagnosis = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
            .remediation_plan = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md",
            .advice = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
            .query = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt",
            .compare = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
        },
        .plan = plan,
    });
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect causal remediation audit") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "approval_status: pending") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "applied: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "- event 3") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "- review remediation plan before source edits") != null);
}
