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

const AdviceAction = struct {
    action: []const u8,
    status: []const u8,
    event_id: u64,
    kind: []const u8,
    label: ?[]const u8 = null,
};

const ActionMapping = struct {
    subsystem: []const u8,
    fix_category: []const u8,
    diagnosis: []const u8,
    patch_prompt: []const u8,
};

const ActionCounts = struct {
    new_actions: usize,
    observed_actions: usize,
    persisting_actions: usize,
};

const ComparePosture = enum {
    no_delta,
    improved,
    regression,
    changed,
    unknown,
};

const CompareSummary = struct {
    kind: ComparePosture,
    event_delta: isize = 0,
    finding_delta: isize = 0,
};

const DiagnosisInput = struct {
    target: []const u8,
    diagnosis_path: []const u8,
    verdict_path: []const u8,
    verdict: Verdict,
    actions: []const AdviceAction,
    query_report_path: []const u8,
    query_count: usize,
    compare_posture: CompareSummary,
};

fn localDiagnosisPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-diagnosis.txt";
}

fn localDiagnosisPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-diagnosis.txt",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn localVerdictPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-verdict.json";
}

fn localVerdictPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-verdict.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn queryReportPathForJson(allocator: std.mem.Allocator, json_path: []const u8) ![]const u8 {
    if (std.mem.endsWith(u8, json_path, "-after.json")) {
        return std.fmt.allocPrint(allocator, "{s}-queries.txt", .{json_path[0 .. json_path.len - "-after.json".len]});
    }
    if (!std.mem.endsWith(u8, json_path, ".json")) return error.InvalidVerdictArtifactPath;
    return std.fmt.allocPrint(allocator, "{s}-queries.txt", .{json_path[0 .. json_path.len - ".json".len]});
}

fn validateLocalVerdict(verdict: Verdict) !void {
    if (!std.mem.eql(u8, verdict.schema, supported_local_schema)) return error.UnsupportedVerdictSchema;
    if (verdict.schema_version != 1) return error.UnsupportedVerdictSchema;
    if (verdict.artifacts.len == 0) return error.EmptyVerdictArtifacts;
}

fn parseAdviceActions(allocator: std.mem.Allocator, advice_report: []const u8) ![]AdviceAction {
    var actions = std.ArrayList(AdviceAction).empty;
    errdefer deinitAdviceActions(allocator, actions.items);

    var lines = std.mem.splitScalar(u8, advice_report, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "- action ")) continue;
        const parsed = try parseAdviceActionLine(allocator, line);
        errdefer deinitAdviceAction(allocator, parsed);
        try actions.append(allocator, parsed);
    }

    return actions.toOwnedSlice(allocator);
}

fn parseAdviceActionLine(allocator: std.mem.Allocator, line: []const u8) !AdviceAction {
    var tokens = std.mem.splitScalar(u8, line, ' ');
    _ = tokens.next() orelse return error.InvalidAdviceActionLine;
    const action_keyword = tokens.next() orelse return error.InvalidAdviceActionLine;
    if (!std.mem.eql(u8, action_keyword, "action")) return error.InvalidAdviceActionLine;
    const action = tokens.next() orelse return error.InvalidAdviceActionLine;

    var status: ?[]const u8 = null;
    var event_id: ?u64 = null;
    var kind: ?[]const u8 = null;
    var label: ?[]const u8 = null;
    while (tokens.next()) |token| {
        if (std.mem.startsWith(u8, token, "status=")) {
            status = token["status=".len..];
        } else if (std.mem.startsWith(u8, token, "event=")) {
            event_id = try std.fmt.parseInt(u64, token["event=".len..], 10);
        } else if (std.mem.startsWith(u8, token, "kind=")) {
            kind = token["kind=".len..];
        } else if (std.mem.startsWith(u8, token, "label=")) {
            label = token["label=".len..];
        }
    }

    const owned_action = try allocator.dupe(u8, action);
    errdefer allocator.free(owned_action);
    const owned_status = try allocator.dupe(u8, status orelse return error.InvalidAdviceActionLine);
    errdefer allocator.free(owned_status);
    const owned_kind = try allocator.dupe(u8, kind orelse return error.InvalidAdviceActionLine);
    errdefer allocator.free(owned_kind);
    const owned_label = if (label) |value| try allocator.dupe(u8, value) else null;
    errdefer if (owned_label) |value| allocator.free(value);

    return .{
        .action = owned_action,
        .status = owned_status,
        .event_id = event_id orelse return error.InvalidAdviceActionLine,
        .kind = owned_kind,
        .label = owned_label,
    };
}

fn deinitAdviceActions(allocator: std.mem.Allocator, actions: []const AdviceAction) void {
    for (actions) |action| deinitAdviceAction(allocator, action);
    allocator.free(actions);
}

fn deinitAdviceAction(allocator: std.mem.Allocator, action: AdviceAction) void {
    allocator.free(action.action);
    allocator.free(action.status);
    allocator.free(action.kind);
    if (action.label) |label| allocator.free(label);
}

fn mapAction(action: []const u8) ActionMapping {
    if (std.mem.eql(u8, action, "provide-missing-service")) {
        return .{
            .subsystem = "service_resolution",
            .fix_category = "code-or-layer-provider",
            .diagnosis = "a required service has no matching provider in the captured run",
            .patch_prompt = "inspect service requirements and provider declarations; add or wire the missing provider if this is not an intentional fixture",
        };
    }
    if (std.mem.eql(u8, action, "close-resource")) {
        return .{
            .subsystem = "scope_lifecycle",
            .fix_category = "resource-finalizer",
            .diagnosis = "an acquired resource lacks matching finalization evidence",
            .patch_prompt = "inspect acquireRelease usage and scope ownership; add the missing finalizer or close path",
        };
    }
    if (std.mem.eql(u8, action, "resolve-scoped-fiber")) {
        return .{
            .subsystem = "fiber_runtime",
            .fix_category = "structured-concurrency",
            .diagnosis = "a scoped fiber remains active in captured evidence",
            .patch_prompt = "inspect scoped fork, join, and interruption paths before the owning scope closes",
        };
    }
    if (std.mem.eql(u8, action, "inspect-retry-exhaustion")) {
        return .{
            .subsystem = "schedule_retry",
            .fix_category = "retry-policy-or-failure-specificity",
            .diagnosis = "a retry schedule exhausted its budget",
            .patch_prompt = "inspect retry policy, failure specificity, and schedule boundaries",
        };
    }
    if (std.mem.eql(u8, action, "inspect-command-failure")) {
        return .{
            .subsystem = "development_command",
            .fix_category = "test-or-command-failure",
            .diagnosis = "a development command recorded a failed assertion",
            .patch_prompt = "inspect the failing command output and add a focused regression test or source fix",
        };
    }
    if (std.mem.eql(u8, action, "inspect-finalizer-failure")) {
        return .{
            .subsystem = "scope_lifecycle",
            .fix_category = "finalizer-error-handling",
            .diagnosis = "a cleanup finalizer failed",
            .patch_prompt = "inspect finalizer error handling and cleanup cause preservation",
        };
    }
    return .{
        .subsystem = "unknown",
        .fix_category = "inspect-evidence",
        .diagnosis = "an unknown causal advice action was selected",
        .patch_prompt = "inspect the cited advice and query reports before proposing a change",
    };
}

fn dominantEvidence(counts: ActionCounts) []const u8 {
    if (counts.new_actions > 0) return "new";
    if (counts.observed_actions > 0) return "observed";
    if (counts.persisting_actions > 0) return "persisting";
    return "none";
}

fn parseComparePosture(compare_report: []const u8) CompareSummary {
    const event_delta = parseSignedLineValue(compare_report, "event delta:") orelse 0;
    const finding_delta = parseSignedLineValue(compare_report, "finding delta:") orelse 0;
    const kind: ComparePosture = if (compare_report.len == 0)
        .unknown
    else if (event_delta == 0 and finding_delta == 0)
        .no_delta
    else if (finding_delta < 0)
        .improved
    else if (finding_delta > 0)
        .regression
    else
        .changed;
    return .{
        .kind = kind,
        .event_delta = event_delta,
        .finding_delta = finding_delta,
    };
}

fn parseSignedLineValue(text: []const u8, prefix: []const u8) ?isize {
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, prefix)) continue;
        const value_text = std.mem.trim(u8, line[prefix.len..], " \t");
        return std.fmt.parseInt(isize, value_text, 10) catch null;
    }
    return null;
}

fn formatDiagnosisReport(allocator: std.mem.Allocator, input: DiagnosisInput) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    const counts = ActionCounts{
        .new_actions = input.verdict.new_actions,
        .observed_actions = input.verdict.observed_actions,
        .persisting_actions = input.verdict.persisting_actions,
    };
    const dominant = dominantEvidence(counts);

    try output.appendSlice(allocator, "zigeffect causal diagnosis\n");
    try output.appendSlice(allocator, "mode: local\n");
    try output.print(allocator, "target: {s}\n", .{input.target});
    try output.print(allocator, "diagnosis: {s}\n", .{input.diagnosis_path});
    try output.print(allocator, "verdict: {s}\n", .{input.verdict_path});
    try output.print(allocator, "status: {s}\n", .{input.verdict.status});
    try output.print(allocator, "next_action: {s}\n", .{input.verdict.next_action});
    try output.print(allocator, "actions: {d}\n", .{input.verdict.actions});
    try output.print(allocator, "new_actions: {d}\n", .{input.verdict.new_actions});
    try output.print(allocator, "persisting_actions: {d}\n", .{input.verdict.persisting_actions});
    try output.print(allocator, "observed_actions: {d}\n\n", .{input.verdict.observed_actions});

    try output.appendSlice(allocator, "summary:\n");
    try output.print(allocator, "- diagnosis status: {s}\n", .{input.verdict.status});
    try output.print(allocator, "- dominant evidence: {s}\n", .{dominant});
    try output.print(allocator, "- patch posture: {s}\n", .{patchPosture(input.verdict, dominant)});
    try output.print(allocator, "- compare posture: {s}\n", .{comparePostureText(input.compare_posture)});
    try output.print(allocator, "- query report: {s} ({d} queries)\n\n", .{ input.query_report_path, input.query_count });

    try output.appendSlice(allocator, "evidence:\n");
    if (input.actions.len == 0) {
        try output.appendSlice(allocator, "- no causal advice actions selected\n");
    } else {
        for (input.actions) |action| {
            const mapping = mapAction(action.action);
            try output.print(
                allocator,
                "- action {s} status={s} event={d} kind={s}",
                .{ action.action, action.status, action.event_id, action.kind },
            );
            if (action.label) |label| try output.print(allocator, " label={s}", .{label});
            try output.append(allocator, '\n');
            try output.print(allocator, "  subsystem: {s}\n", .{mapping.subsystem});
            try output.print(allocator, "  fix category: {s}\n", .{mapping.fix_category});
            try output.print(allocator, "  diagnosis: {s}\n", .{mapping.diagnosis});
            try output.print(allocator, "  patch prompt: {s}\n", .{mapping.patch_prompt});
            try output.print(
                allocator,
                "  citations: event={d} advice={s} query={s}\n",
                .{ action.event_id, input.verdict.artifacts[0].advice_report_path, input.query_report_path },
            );
        }
    }

    try output.appendSlice(allocator, "\nnext patch brief:\n");
    try output.appendSlice(allocator, "- cite event ids from the evidence section\n");
    try output.appendSlice(allocator, "- explain whether evidence is new, persisting, or observed\n");
    try output.appendSlice(allocator, "- use the compare posture before claiming behavior changed\n");
    try output.appendSlice(allocator, "- propose code, config, layer, test, or scenario-registry changes only\n");

    return output.toOwnedSlice(allocator);
}

fn patchPosture(verdict: Verdict, dominant: []const u8) []const u8 {
    if (verdict.actions == 0) return "no advice actions were selected from the after artifact";
    if (std.mem.eql(u8, dominant, "new")) return "new causal evidence may indicate a regression introduced by the current patch";
    if (std.mem.eql(u8, dominant, "observed")) return "causal evidence exists without a baseline comparison";
    return "existing causal findings remain; do not claim this patch fixed them";
}

fn comparePostureText(summary: CompareSummary) []const u8 {
    return switch (summary.kind) {
        .no_delta => "no before/after event or finding delta",
        .improved => "finding count decreased; verify event ids before claiming a fix",
        .regression => "finding count increased; treat this as possible regression evidence",
        .changed => "events changed without finding-count movement; inspect compare report",
        .unknown => "compare report unavailable or unreadable",
    };
}

fn usage() []const u8 {
    return "usage: zig build causal-diagnosis -- local [scenario]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-diagnosis error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn readArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingDiagnosisInput,
        else => return err,
    };
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn queryCount(query_report: []const u8) usize {
    return std.mem.count(u8, query_report, "query: ");
}

fn runLocal(init: std.process.Init, scenario_slug: ?[]const u8) !void {
    const allocator = init.gpa;
    const verdict_path = if (scenario_slug) |slug| try localVerdictPathForScenario(allocator, slug) else localVerdictPath();
    defer if (scenario_slug != null) allocator.free(verdict_path);
    const diagnosis_path = if (scenario_slug) |slug| try localDiagnosisPathForScenario(allocator, slug) else localDiagnosisPath();
    defer if (scenario_slug != null) allocator.free(diagnosis_path);
    const target = scenario_slug orelse "dogfood";

    const verdict_json = try readArtifact(init.io, allocator, verdict_path);
    defer allocator.free(verdict_json);
    var parsed = try std.json.parseFromSlice(Verdict, allocator, verdict_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try validateLocalVerdict(parsed.value);

    const artifact = parsed.value.artifacts[0];
    const advice_report = try readArtifact(init.io, allocator, artifact.advice_report_path);
    defer allocator.free(advice_report);
    const query_report_path = try queryReportPathForJson(allocator, artifact.json_path);
    defer allocator.free(query_report_path);
    const query_report = try readArtifact(init.io, allocator, query_report_path);
    defer allocator.free(query_report);
    const compare_report = if (artifact.compare_report_path) |path| try readArtifact(init.io, allocator, path) else "";
    defer if (artifact.compare_report_path != null) allocator.free(compare_report);

    const actions = try parseAdviceActions(allocator, advice_report);
    defer deinitAdviceActions(allocator, actions);

    const report = try formatDiagnosisReport(allocator, .{
        .target = target,
        .diagnosis_path = diagnosis_path,
        .verdict_path = verdict_path,
        .verdict = parsed.value,
        .actions = actions,
        .query_report_path = query_report_path,
        .query_count = queryCount(query_report),
        .compare_posture = parseComparePosture(compare_report),
    });
    defer allocator.free(report);

    try writeArtifact(init.io, diagnosis_path, report);
    std.debug.print("{s}", .{report});
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 2) failUsage(error.MissingMode);
    if (args.len > 3) failUsage(error.TooManyArguments);
    if (!std.mem.eql(u8, args[1], "local")) failUsage(error.UnknownMode);

    const scenario_slug: ?[]const u8 = if (args.len == 3) blk: {
        _ = causal_run.scenarioByName(args[2]) catch |err| failUsage(err);
        break :blk args[2];
    } else null;

    runLocal(init, scenario_slug) catch |err| switch (err) {
        error.MissingDiagnosisInput,
        error.UnsupportedVerdictSchema,
        error.EmptyVerdictArtifacts,
        error.InvalidVerdictArtifactPath,
        error.InvalidArtifactPath,
        => failUsage(err),
        else => return err,
    };
}

const advice_text =
    \\zigeffect causal advice report
    \\artifact: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json
    \\baseline: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json
    \\actions: 2
    \\- action provide-missing-service status=persisting event=3 kind=service_required label=Config
    \\  why: service requirement is missing a provider
    \\- action inspect-command-failure status=new event=9 kind=assertion_recorded label=package-tests
    \\  why: development command recorded a failed assertion
    \\
;

const no_delta_compare_text =
    \\zigeffect causal compare report
    \\before events: 8
    \\after events: 8
    \\event delta: +0
    \\before findings: 4
    \\after findings: 4
    \\finding delta: +0
    \\added events:
    \\- none
    \\removed events:
    \\- none
    \\changed events:
    \\- none
    \\
;

const regression_compare_text =
    \\zigeffect causal compare report
    \\before events: 2
    \\after events: 3
    \\event delta: +1
    \\before findings: 0
    \\after findings: 1
    \\finding delta: +1
    \\added events:
    \\- event id=9 kind=assertion_recorded label=package-tests status=failure
    \\removed events:
    \\- none
    \\changed events:
    \\- none
    \\
;

test "diagnosis path is stable for default target" {
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
        localDiagnosisPath(),
    );
}

test "scenario diagnosis path includes slug" {
    const path = try localDiagnosisPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(path);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt",
        path,
    );
}

test "advice action parser captures action status event kind and label" {
    const actions = try parseAdviceActions(std.testing.allocator, advice_text);
    defer deinitAdviceActions(std.testing.allocator, actions);

    try std.testing.expectEqual(@as(usize, 2), actions.len);
    try std.testing.expectEqualStrings("provide-missing-service", actions[0].action);
    try std.testing.expectEqualStrings("persisting", actions[0].status);
    try std.testing.expectEqual(@as(u64, 3), actions[0].event_id);
    try std.testing.expectEqualStrings("service_required", actions[0].kind);
    try std.testing.expectEqualStrings("Config", actions[0].label.?);
}

test "action mapping names subsystem and fix category" {
    const mapped = mapAction("provide-missing-service");

    try std.testing.expectEqualStrings("service_resolution", mapped.subsystem);
    try std.testing.expectEqualStrings("code-or-layer-provider", mapped.fix_category);
    try std.testing.expect(std.mem.indexOf(u8, mapped.diagnosis, "required service") != null);
}

test "unknown action mapping remains inspectable" {
    const mapped = mapAction("new-action");

    try std.testing.expectEqualStrings("unknown", mapped.subsystem);
    try std.testing.expectEqualStrings("inspect-evidence", mapped.fix_category);
}

test "dominant evidence prioritizes new then observed then persisting" {
    try std.testing.expectEqualStrings("new", dominantEvidence(.{
        .new_actions = 1,
        .observed_actions = 5,
        .persisting_actions = 9,
    }));
    try std.testing.expectEqualStrings("observed", dominantEvidence(.{
        .new_actions = 0,
        .observed_actions = 1,
        .persisting_actions = 9,
    }));
    try std.testing.expectEqualStrings("persisting", dominantEvidence(.{
        .new_actions = 0,
        .observed_actions = 0,
        .persisting_actions = 1,
    }));
    try std.testing.expectEqualStrings("none", dominantEvidence(.{
        .new_actions = 0,
        .observed_actions = 0,
        .persisting_actions = 0,
    }));
}

test "compare parser identifies no delta" {
    const posture = parseComparePosture(no_delta_compare_text);

    try std.testing.expectEqual(ComparePosture.no_delta, posture.kind);
    try std.testing.expectEqual(@as(isize, 0), posture.finding_delta);
    try std.testing.expectEqual(@as(isize, 0), posture.event_delta);
}

test "compare parser identifies regression" {
    const posture = parseComparePosture(regression_compare_text);

    try std.testing.expectEqual(ComparePosture.regression, posture.kind);
    try std.testing.expectEqual(@as(isize, 1), posture.finding_delta);
}

test "attention diagnosis report includes patch prompt and citations" {
    const verdict = Verdict{
        .schema = supported_local_schema,
        .schema_version = 1,
        .status = "attention",
        .next_action = "inspect-new-advice",
        .json_artifacts = 1,
        .baseline_pairs = 1,
        .actions = 2,
        .new_actions = 1,
        .persisting_actions = 1,
        .observed_actions = 0,
        .artifacts = &.{
            .{
                .json_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json",
                .baseline_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
                .advice_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
                .compare_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
                .actions = 2,
                .new_actions = 1,
                .persisting_actions = 1,
                .observed_actions = 0,
            },
        },
    };
    const actions = try parseAdviceActions(std.testing.allocator, advice_text);
    defer deinitAdviceActions(std.testing.allocator, actions);

    const report = try formatDiagnosisReport(std.testing.allocator, .{
        .target = "dogfood",
        .diagnosis_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
        .verdict_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
        .verdict = verdict,
        .actions = actions,
        .query_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt",
        .query_count = 4,
        .compare_posture = parseComparePosture(regression_compare_text),
    });
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal diagnosis") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "dominant evidence: new") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "subsystem: service_resolution") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "fix category: code-or-layer-provider") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "citations: event=3") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "patch prompt: inspect service requirements and provider declarations") != null);
}

test "clear diagnosis report has no evidence actions" {
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
        .artifacts = &.{
            .{
                .json_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-after.json",
                .baseline_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-before.json",
                .advice_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-advice.txt",
                .compare_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-compare.txt",
                .actions = 0,
                .new_actions = 0,
                .persisting_actions = 0,
                .observed_actions = 0,
            },
        },
    };
    const report = try formatDiagnosisReport(std.testing.allocator, .{
        .target = "causal-scoped-fiber",
        .diagnosis_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt",
        .verdict_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json",
        .verdict = verdict,
        .actions = &.{},
        .query_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-queries.txt",
        .query_count = 0,
        .compare_posture = parseComparePosture(no_delta_compare_text),
    });
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "diagnosis status: clear") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "no causal advice actions selected") != null);
}

test "usage names local mode" {
    try std.testing.expectEqualStrings(
        "usage: zig build causal-diagnosis -- local [scenario]\n",
        usage(),
    );
}

test "unsupported verdict schema is rejected" {
    const verdict = Verdict{
        .schema = "zigeffect.causal.other.v1",
        .schema_version = 1,
        .status = "clear",
        .next_action = "none",
        .json_artifacts = 0,
        .baseline_pairs = 0,
        .actions = 0,
        .new_actions = 0,
        .persisting_actions = 0,
        .observed_actions = 0,
        .artifacts = &.{},
    };

    try std.testing.expectError(error.UnsupportedVerdictSchema, validateLocalVerdict(verdict));
}

test "empty verdict artifacts are rejected" {
    const verdict = Verdict{
        .schema = supported_local_schema,
        .schema_version = 1,
        .status = "clear",
        .next_action = "none",
        .json_artifacts = 0,
        .baseline_pairs = 0,
        .actions = 0,
        .new_actions = 0,
        .persisting_actions = 0,
        .observed_actions = 0,
        .artifacts = &.{},
    };

    try std.testing.expectError(error.EmptyVerdictArtifacts, validateLocalVerdict(verdict));
}
