const std = @import("std");
const causal_run = @import("causal_run");

const supported_local_schema = "zigeffect.causal.dev-loop-verdict.v1";

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

const EvidenceAction = struct {
    action: []const u8,
    status: []const u8,
    event_id: u64,
    kind: []const u8,
    label: ?[]const u8 = null,
    subsystem: []const u8,
    fix_category: []const u8,
    diagnosis: []const u8,
    patch_prompt: []const u8,
};

const RemediationPosture = enum {
    do_not_patch,
    investigate,
    patch_candidate,
    regression_candidate,
};

const RemediationInput = struct {
    target: []const u8,
    plan_path: []const u8,
    verdict_path: []const u8,
    diagnosis_path: []const u8,
    verdict: Verdict,
    evidence: []const EvidenceAction,
    compare_guardrail: []const u8,
};

const diagnosis_text =
    \\zigeffect causal diagnosis
    \\mode: local
    \\target: dogfood
    \\diagnosis: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt
    \\verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
    \\status: attention
    \\next_action: inspect-persisting-advice
    \\actions: 2
    \\new_actions: 0
    \\persisting_actions: 2
    \\observed_actions: 0
    \\
    \\summary:
    \\- diagnosis status: attention
    \\- dominant evidence: persisting
    \\- patch posture: existing causal findings remain; do not claim this patch fixed them
    \\- compare posture: no before/after event or finding delta
    \\- query report: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt (12 queries)
    \\
    \\evidence:
    \\- action close-resource status=persisting event=4 kind=resource_acquired label=dogfood database
    \\  subsystem: scope_lifecycle
    \\  fix category: resource-finalizer
    \\  diagnosis: an acquired resource lacks matching finalization evidence
    \\  patch prompt: inspect acquireRelease usage and scope ownership; add the missing finalizer or close path
    \\  citations: event=4 advice=.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt query=.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt
    \\- action resolve-scoped-fiber status=persisting event=5 kind=fiber_forked label=dogfood child fiber
    \\  subsystem: fiber_runtime
    \\  fix category: structured-concurrency
    \\  diagnosis: a scoped fiber remains active in captured evidence
    \\  patch prompt: inspect scoped fork, join, and interruption paths before the owning scope closes
    \\  citations: event=5 advice=.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt query=.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt
    \\
;

fn localPlanPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-plan.md";
}

fn localPlanPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-remediation-plan.md",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn remediationPosture(verdict: Verdict) RemediationPosture {
    if (std.mem.eql(u8, verdict.status, "clear") or verdict.actions == 0) return .do_not_patch;
    if (verdict.new_actions > 0) return .regression_candidate;
    if (verdict.observed_actions > 0) return .investigate;
    return .patch_candidate;
}

fn postureText(posture: RemediationPosture) []const u8 {
    return switch (posture) {
        .do_not_patch => "do-not-patch",
        .investigate => "investigate",
        .patch_candidate => "patch-candidate",
        .regression_candidate => "regression-candidate",
    };
}

fn evidencePosture(verdict: Verdict) []const u8 {
    if (verdict.new_actions > 0) return "new";
    if (verdict.observed_actions > 0) return "observed";
    if (verdict.persisting_actions > 0) return "persisting";
    return "none";
}

fn parseDiagnosisEvidence(allocator: std.mem.Allocator, diagnosis_report: []const u8) ![]EvidenceAction {
    var evidence = std.ArrayList(EvidenceAction).empty;
    var current: ?EvidenceAction = null;
    errdefer {
        if (current) |item| deinitEvidenceAction(allocator, item);
        deinitEvidence(allocator, evidence.items);
    }

    var lines = std.mem.splitScalar(u8, diagnosis_report, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "- action ")) {
            if (current) |item| try evidence.append(allocator, item);
            current = try parseActionLine(allocator, line);
        } else if (std.mem.startsWith(u8, line, "  subsystem: ")) {
            if (current) |*item| try replaceOwnedField(allocator, &item.subsystem, line["  subsystem: ".len..]);
        } else if (std.mem.startsWith(u8, line, "  fix category: ")) {
            if (current) |*item| try replaceOwnedField(allocator, &item.fix_category, line["  fix category: ".len..]);
        } else if (std.mem.startsWith(u8, line, "  diagnosis: ")) {
            if (current) |*item| try replaceOwnedField(allocator, &item.diagnosis, line["  diagnosis: ".len..]);
        } else if (std.mem.startsWith(u8, line, "  patch prompt: ")) {
            if (current) |*item| try replaceOwnedField(allocator, &item.patch_prompt, line["  patch prompt: ".len..]);
        }
    }
    if (current) |item| try evidence.append(allocator, item);

    return evidence.toOwnedSlice(allocator);
}

fn replaceOwnedField(allocator: std.mem.Allocator, field: *[]const u8, value: []const u8) !void {
    const owned = try allocator.dupe(u8, value);
    allocator.free(field.*);
    field.* = owned;
}

fn parseActionLine(allocator: std.mem.Allocator, line: []const u8) !EvidenceAction {
    const label_marker = " label=";
    const action_prefix, const label = if (std.mem.indexOf(u8, line, label_marker)) |label_index|
        .{ line[0..label_index], line[label_index + label_marker.len ..] }
    else
        .{ line, null };

    var tokens = std.mem.splitScalar(u8, action_prefix, ' ');
    _ = tokens.next() orelse return error.InvalidEvidenceActionLine;
    const action_keyword = tokens.next() orelse return error.InvalidEvidenceActionLine;
    if (!std.mem.eql(u8, action_keyword, "action")) return error.InvalidEvidenceActionLine;
    const action = tokens.next() orelse return error.InvalidEvidenceActionLine;

    var status: ?[]const u8 = null;
    var event_id: ?u64 = null;
    var kind: ?[]const u8 = null;
    while (tokens.next()) |token| {
        if (std.mem.startsWith(u8, token, "status=")) {
            status = token["status=".len..];
        } else if (std.mem.startsWith(u8, token, "event=")) {
            event_id = try std.fmt.parseInt(u64, token["event=".len..], 10);
        } else if (std.mem.startsWith(u8, token, "kind=")) {
            kind = token["kind=".len..];
        }
    }

    const owned_action = try allocator.dupe(u8, action);
    errdefer allocator.free(owned_action);
    const owned_status = try allocator.dupe(u8, status orelse return error.InvalidEvidenceActionLine);
    errdefer allocator.free(owned_status);
    const owned_kind = try allocator.dupe(u8, kind orelse return error.InvalidEvidenceActionLine);
    errdefer allocator.free(owned_kind);
    const owned_label = if (label) |value| try allocator.dupe(u8, value) else null;
    errdefer if (owned_label) |value| allocator.free(value);
    const owned_subsystem = try allocator.dupe(u8, "unknown");
    errdefer allocator.free(owned_subsystem);
    const owned_fix_category = try allocator.dupe(u8, "inspect-evidence");
    errdefer allocator.free(owned_fix_category);
    const owned_diagnosis = try allocator.dupe(u8, "diagnosis unavailable; inspect cited diagnosis report");
    errdefer allocator.free(owned_diagnosis);
    const owned_patch_prompt = try allocator.dupe(u8, "inspect evidence before proposing a patch");
    errdefer allocator.free(owned_patch_prompt);

    return .{
        .action = owned_action,
        .status = owned_status,
        .event_id = event_id orelse return error.InvalidEvidenceActionLine,
        .kind = owned_kind,
        .label = owned_label,
        .subsystem = owned_subsystem,
        .fix_category = owned_fix_category,
        .diagnosis = owned_diagnosis,
        .patch_prompt = owned_patch_prompt,
    };
}

fn deinitEvidence(allocator: std.mem.Allocator, evidence: []const EvidenceAction) void {
    for (evidence) |item| deinitEvidenceAction(allocator, item);
    allocator.free(evidence);
}

fn deinitEvidenceAction(allocator: std.mem.Allocator, item: EvidenceAction) void {
    allocator.free(item.action);
    allocator.free(item.status);
    allocator.free(item.kind);
    if (item.label) |label| allocator.free(label);
    allocator.free(item.subsystem);
    allocator.free(item.fix_category);
    allocator.free(item.diagnosis);
    allocator.free(item.patch_prompt);
}

fn strategyTitle(item: EvidenceAction) []const u8 {
    if (std.mem.eql(u8, item.status, "new")) return "Regression candidate";
    if (std.mem.eql(u8, item.status, "observed")) return "Investigation candidate";
    return "Patch candidate";
}

fn strategyInstruction(action: []const u8) []const u8 {
    if (std.mem.eql(u8, action, "provide-missing-service")) return "Inspect service requirements and provider declarations before wiring a missing provider.";
    if (std.mem.eql(u8, action, "close-resource")) return "Inspect acquire/release ownership around the cited resource event before adding or wiring a finalizer.";
    if (std.mem.eql(u8, action, "resolve-scoped-fiber")) return "Inspect scoped fork, join, interruption, and parent scope close paths.";
    if (std.mem.eql(u8, action, "inspect-retry-exhaustion")) return "Inspect retry policy, failure specificity, and schedule boundaries.";
    if (std.mem.eql(u8, action, "inspect-command-failure")) return "Inspect the failing command output and add a focused regression test or source fix.";
    if (std.mem.eql(u8, action, "inspect-finalizer-failure")) return "Inspect finalizer error handling and cleanup cause preservation.";
    return "Inspect the cited evidence before proposing source changes.";
}

fn formatRemediationPlan(allocator: std.mem.Allocator, input: RemediationInput) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    const posture = remediationPosture(input.verdict);
    const artifact = input.verdict.artifacts[0];

    try output.appendSlice(allocator, "# zigeffect causal remediation plan\n\n");
    try output.appendSlice(allocator, "mode: local\n");
    try output.print(allocator, "target: {s}\n", .{input.target});
    try output.print(allocator, "posture: {s}\n", .{postureText(posture)});
    try output.print(allocator, "plan: {s}\n", .{input.plan_path});
    try output.print(allocator, "verdict: {s}\n", .{input.verdict_path});
    try output.print(allocator, "diagnosis: {s}\n\n", .{input.diagnosis_path});

    try output.appendSlice(allocator, "## Summary\n\n");
    try output.print(allocator, "- status: {s}\n", .{input.verdict.status});
    try output.print(allocator, "- next action: {s}\n", .{input.verdict.next_action});
    try output.print(allocator, "- evidence posture: {s}\n", .{evidencePosture(input.verdict)});
    try output.print(allocator, "- compare guardrail: {s}\n\n", .{input.compare_guardrail});

    try output.appendSlice(allocator, "## Evidence\n\n");
    if (input.evidence.len == 0) {
        try output.appendSlice(allocator, "- no causal advice actions selected\n\n");
    } else {
        for (input.evidence) |item| {
            try output.print(allocator, "- event {d} `{s}` status={s}\n", .{ item.event_id, item.kind, item.status });
            try output.print(allocator, "  - subsystem: {s}\n", .{item.subsystem});
            try output.print(allocator, "  - fix category: {s}\n", .{item.fix_category});
            if (item.label) |label| try output.print(allocator, "  - label: {s}\n", .{label});
            try output.print(allocator, "  - citation: {s}\n", .{artifact.advice_report_path});
        }
        try output.append(allocator, '\n');
    }

    try output.appendSlice(allocator, "## Proposed Remediation\n\n");
    if (posture == .do_not_patch or input.evidence.len == 0) {
        try output.appendSlice(allocator, "- No patch strategy is proposed because the verdict is clear or no advice actions were selected.\n\n");
    } else {
        for (input.evidence, 0..) |item, index| {
            try output.print(allocator, "{d}. {s}: {s} / {s}\n", .{ index + 1, strategyTitle(item), item.subsystem, item.fix_category });
            try output.print(allocator, "   - {s}\n", .{strategyInstruction(item.action)});
            try output.print(allocator, "   - Diagnosis: {s}\n", .{item.diagnosis});
            try output.print(allocator, "   - Patch prompt: {s}\n", .{item.patch_prompt});
            try output.appendSlice(allocator, "   - Add or select a focused causal scenario before broad runtime changes.\n");
        }
        try output.append(allocator, '\n');
    }

    try appendVerificationCommands(allocator, &output, input.target);
    try appendClaimGuardrails(allocator, &output, input.verdict);
    return output.toOwnedSlice(allocator);
}

fn appendVerificationCommands(allocator: std.mem.Allocator, output: *std.ArrayList(u8), target: []const u8) !void {
    try output.appendSlice(allocator, "## Required Verification\n\n");
    if (std.mem.eql(u8, target, "dogfood")) {
        try output.appendSlice(allocator, "- `zig build causal-dev-loop -- baseline`\n");
        try output.appendSlice(allocator, "- `zig build causal-dev-loop -- after`\n");
        try output.appendSlice(allocator, "- `zig build causal-diagnosis -- local`\n");
    } else {
        try output.print(allocator, "- `zig build causal-dev-loop -- baseline {s}`\n", .{target});
        try output.print(allocator, "- `zig build causal-dev-loop -- after {s}`\n", .{target});
        try output.print(allocator, "- `zig build causal-diagnosis -- local {s}`\n", .{target});
    }
    try output.appendSlice(allocator, "- `zig build test --summary none`\n\n");
}

fn appendClaimGuardrails(allocator: std.mem.Allocator, output: *std.ArrayList(u8), verdict: Verdict) !void {
    try output.appendSlice(allocator, "## Claim Guardrails\n\n");
    if (verdict.new_actions > 0) {
        try output.appendSlice(allocator, "- Treat status=new evidence as a possible regression until compare/verdict output proves otherwise.\n");
    } else if (verdict.persisting_actions > 0) {
        try output.appendSlice(allocator, "- Do not claim this patch fixed persisting evidence unless the after verdict is clear or the compare report shows fewer findings.\n");
    } else if (verdict.observed_actions > 0) {
        try output.appendSlice(allocator, "- Do not claim a before/after improvement without capturing a baseline and rerunning the dev loop.\n");
    } else {
        try output.appendSlice(allocator, "- Do not patch unrelated subsystems when the causal verdict is clear.\n");
    }
    try output.appendSlice(allocator, "- Cite event ids from the remediation evidence section in the patch summary.\n");
    try output.appendSlice(allocator, "- Treat this plan as guidance, not permission to edit unrelated subsystems.\n");
}

test "remediation plan path is stable for default target" {
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md",
        localPlanPath(),
    );
}

test "scenario remediation plan path includes slug" {
    const path = try localPlanPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(path);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md",
        path,
    );
}

test "posture uses clear verdict as do not patch" {
    const verdict = Verdict{
        .schema = supported_local_schema,
        .schema_version = 1,
        .status = "clear",
        .next_action = "none",
        .json_artifacts = 1,
        .baseline_pairs = 1,
        .actions = 0,
        .new_actions = 0,
        .persisting_actions = 0,
        .observed_actions = 0,
        .artifacts = &.{.{
            .json_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json",
            .baseline_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
            .advice_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
            .compare_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
            .actions = 0,
            .new_actions = 0,
            .persisting_actions = 0,
            .observed_actions = 0,
        }},
    };

    try std.testing.expectEqual(RemediationPosture.do_not_patch, remediationPosture(verdict));
}

test "posture prioritizes new evidence as regression candidate" {
    const verdict = Verdict{
        .schema = supported_local_schema,
        .schema_version = 1,
        .status = "attention",
        .next_action = "inspect-new-advice",
        .json_artifacts = 1,
        .baseline_pairs = 1,
        .actions = 1,
        .new_actions = 1,
        .persisting_actions = 0,
        .observed_actions = 0,
        .artifacts = &.{.{
            .json_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json",
            .baseline_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
            .advice_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
            .compare_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
            .actions = 1,
            .new_actions = 1,
            .persisting_actions = 0,
            .observed_actions = 0,
        }},
    };

    try std.testing.expectEqual(RemediationPosture.regression_candidate, remediationPosture(verdict));
}

test "diagnosis parser captures evidence actions and multi word labels" {
    const evidence = try parseDiagnosisEvidence(std.testing.allocator, diagnosis_text);
    defer deinitEvidence(std.testing.allocator, evidence);

    try std.testing.expectEqual(@as(usize, 2), evidence.len);
    try std.testing.expectEqualStrings("close-resource", evidence[0].action);
    try std.testing.expectEqualStrings("persisting", evidence[0].status);
    try std.testing.expectEqual(@as(u64, 4), evidence[0].event_id);
    try std.testing.expectEqualStrings("resource_acquired", evidence[0].kind);
    try std.testing.expectEqualStrings("dogfood database", evidence[0].label.?);
    try std.testing.expectEqualStrings("scope_lifecycle", evidence[0].subsystem);
    try std.testing.expectEqualStrings("resource-finalizer", evidence[0].fix_category);
    try std.testing.expect(std.mem.indexOf(u8, evidence[0].patch_prompt, "acquireRelease") != null);
}

test "remediation formatter writes markdown strategy and guardrails" {
    const verdict = Verdict{
        .schema = supported_local_schema,
        .schema_version = 1,
        .status = "attention",
        .next_action = "inspect-persisting-advice",
        .json_artifacts = 1,
        .baseline_pairs = 1,
        .actions = 2,
        .new_actions = 0,
        .persisting_actions = 2,
        .observed_actions = 0,
        .artifacts = &.{.{
            .json_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json",
            .baseline_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
            .advice_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
            .compare_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
            .actions = 2,
            .new_actions = 0,
            .persisting_actions = 2,
            .observed_actions = 0,
        }},
    };
    const evidence = try parseDiagnosisEvidence(std.testing.allocator, diagnosis_text);
    defer deinitEvidence(std.testing.allocator, evidence);

    const report = try formatRemediationPlan(std.testing.allocator, .{
        .target = "dogfood",
        .plan_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md",
        .verdict_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
        .diagnosis_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
        .verdict = verdict,
        .evidence = evidence,
        .compare_guardrail = "no before/after event or finding delta",
    });
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "# zigeffect causal remediation plan") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "posture: patch-candidate") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event 4 `resource_acquired` status=persisting") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "Patch candidate: scope_lifecycle / resource-finalizer") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-dev-loop -- baseline") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "Do not claim this patch fixed persisting evidence") != null);
}
