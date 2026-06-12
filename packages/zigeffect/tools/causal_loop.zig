const std = @import("std");
const causal_test = @import("causal_test");
const causal_compare = @import("causal_compare");
const causal_query = @import("causal_query");
const causal_advice = @import("causal_advice");
const causal_run = @import("causal_run");
const causal_artifact = @import("causal_artifact");
const causal_verdict = @import("causal_verdict");

const Phase = enum {
    baseline,
    after,
};

const PackageStatus = enum {
    pass,
    failure,
};

const ScenarioStatus = enum {
    pass,
    expected_failure_observed,
    failure,
};

const LoopPaths = struct {
    before_json_path: []const u8,
    after_json_path: []const u8,
    compare_report_path: []const u8,
    query_report_path: []const u8,
    advice_report_path: []const u8,
    verdict_report_path: []const u8,
    owned: bool = false,

    fn deinit(self: LoopPaths, allocator: std.mem.Allocator) void {
        if (!self.owned) return;
        allocator.free(self.before_json_path);
        allocator.free(self.after_json_path);
        allocator.free(self.compare_report_path);
        allocator.free(self.query_report_path);
        allocator.free(self.advice_report_path);
        allocator.free(self.verdict_report_path);
    }
};

const SummaryInput = struct {
    phase: Phase,
    dogfood_findings: usize,
    package_status: PackageStatus,
    paths: LoopPaths,
    compare_report: ?[]const u8,
    target: []const u8 = "dogfood",
    scenario_status: ?ScenarioStatus = null,
};

const ScenarioCapture = struct {
    status: ScenarioStatus,
    finding_count: usize,
};

const Artifact = struct {
    schema: ?[]const u8 = null,
    schema_version: ?u32 = null,
    event_taxonomy_version: ?u32 = null,
    events: []Event,
};

const Event = struct {
    id: u64,
    kind: []const u8,
    run_id: ?u64,
    parent_id: ?u64,
    fiber_id: ?u64,
    scope_id: ?u64,
    trace_id: ?u64,
    span_id: ?u64,
    label: []const u8,
    type_name: []const u8,
    status: []const u8,
    redacted_detail: []const u8,
};

const dogfood_query_json =
    \\{
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"zigeffect dogfood","type_name":"DogfoodHarness","status":"","redacted_detail":""},
    \\    {"id":2,"kind":"scope_opened","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":1,"trace_id":null,"span_id":null,"label":"dogfood scope","type_name":"","status":"opened","redacted_detail":""},
    \\    {"id":3,"kind":"service_required","run_id":1,"parent_id":2,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"Config","status":"missing","redacted_detail":"missing provider"},
    \\    {"id":4,"kind":"resource_acquired","run_id":1,"parent_id":2,"fiber_id":null,"scope_id":1,"trace_id":null,"span_id":null,"label":"dogfood database","type_name":"DogfoodDatabaseConnection","status":"success","redacted_detail":"left open"},
    \\    {"id":5,"kind":"fiber_forked","run_id":1,"parent_id":2,"fiber_id":42,"scope_id":1,"trace_id":null,"span_id":null,"label":"dogfood child fiber","type_name":"","status":"pending","redacted_detail":""},
    \\    {"id":6,"kind":"schedule_decision","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"dogfood retry policy","type_name":"Schedule.exponential","status":"exhausted","redacted_detail":"retry budget exhausted"}
    \\  ]
    \\}
;

const versioned_dogfood_query_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"zigeffect dogfood","type_name":"DogfoodHarness","status":"","redacted_detail":""},
    \\    {"id":2,"kind":"scope_opened","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":1,"trace_id":null,"span_id":null,"label":"dogfood scope","type_name":"","status":"opened","redacted_detail":""},
    \\    {"id":3,"kind":"service_required","run_id":1,"parent_id":2,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"Config","status":"missing","redacted_detail":"missing provider"},
    \\    {"id":4,"kind":"resource_acquired","run_id":1,"parent_id":2,"fiber_id":null,"scope_id":1,"trace_id":null,"span_id":null,"label":"dogfood database","type_name":"DogfoodDatabaseConnection","status":"success","redacted_detail":"left open"},
    \\    {"id":5,"kind":"fiber_forked","run_id":1,"parent_id":2,"fiber_id":42,"scope_id":1,"trace_id":null,"span_id":null,"label":"dogfood child fiber","type_name":"","status":"pending","redacted_detail":""},
    \\    {"id":6,"kind":"schedule_decision","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"dogfood retry policy","type_name":"Schedule.exponential","status":"exhausted","redacted_detail":"retry budget exhausted"}
    \\  ]
    \\}
;

const future_taxonomy_dogfood_query_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 2,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"zigeffect dogfood","type_name":"DogfoodHarness","status":"","redacted_detail":""},
    \\    {"id":2,"kind":"scope_opened","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":1,"trace_id":null,"span_id":null,"label":"dogfood scope","type_name":"","status":"opened","redacted_detail":""},
    \\    {"id":3,"kind":"service_required","run_id":1,"parent_id":2,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"Config","status":"missing","redacted_detail":"missing provider"},
    \\    {"id":4,"kind":"resource_acquired","run_id":1,"parent_id":2,"fiber_id":null,"scope_id":1,"trace_id":null,"span_id":null,"label":"dogfood database","type_name":"DogfoodDatabaseConnection","status":"success","redacted_detail":"left open"},
    \\    {"id":5,"kind":"fiber_forked","run_id":1,"parent_id":2,"fiber_id":42,"scope_id":1,"trace_id":null,"span_id":null,"label":"dogfood child fiber","type_name":"","status":"pending","redacted_detail":""},
    \\    {"id":6,"kind":"schedule_decision","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"dogfood retry policy","type_name":"Schedule.exponential","status":"exhausted","redacted_detail":"retry budget exhausted"}
    \\  ]
    \\}
;

const future_schema_unknown_kind_dogfood_query_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 2,
    \\  "event_taxonomy_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"zigeffect dogfood","type_name":"DogfoodHarness","status":"","redacted_detail":""},
    \\    {"id":2,"kind":"effect_suspended","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future event","type_name":"DogfoodHarness","status":"pending","redacted_detail":""}
    \\  ]
    \\}
;

const no_finding_query_json =
    \\{
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"passing scenario","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"exit_recorded","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"passing scenario","type_name":"Command","status":"success","redacted_detail":""}
    \\  ]
    \\}
;

fn loopPaths() LoopPaths {
    return .{
        .before_json_path = causal_test.artifact_dir ++ "/zigeffect-causal-dev-loop-before.json",
        .after_json_path = causal_test.artifact_dir ++ "/zigeffect-causal-dev-loop-after.json",
        .compare_report_path = causal_test.artifact_dir ++ "/zigeffect-causal-dev-loop-compare.txt",
        .query_report_path = causal_test.artifact_dir ++ "/zigeffect-causal-dev-loop-queries.txt",
        .advice_report_path = causal_test.artifact_dir ++ "/zigeffect-causal-dev-loop-advice.txt",
        .verdict_report_path = causal_test.artifact_dir ++ "/zigeffect-causal-dev-loop-verdict.json",
    };
}

fn loopPathsForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) std.mem.Allocator.Error!LoopPaths {
    const before_json_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-before.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(before_json_path);
    const after_json_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-after.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(after_json_path);
    const compare_report_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-compare.txt", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(compare_report_path);
    const query_report_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-queries.txt", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(query_report_path);
    const advice_report_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-advice.txt", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(advice_report_path);
    const verdict_report_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-verdict.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(verdict_report_path);

    return .{
        .before_json_path = before_json_path,
        .after_json_path = after_json_path,
        .compare_report_path = compare_report_path,
        .query_report_path = query_report_path,
        .advice_report_path = advice_report_path,
        .verdict_report_path = verdict_report_path,
        .owned = true,
    };
}

fn formatSummary(allocator: std.mem.Allocator, input: SummaryInput) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal dev loop\n");
    try output.print(allocator, "phase: {s}\n", .{@tagName(input.phase)});
    try output.print(allocator, "target: {s}\n", .{input.target});
    if (input.scenario_status) |status| {
        try output.print(allocator, "scenario status: {s}\n", .{@tagName(status)});
        try output.print(allocator, "scenario findings: {d}\n", .{input.dogfood_findings});
    } else {
        try output.print(allocator, "dogfood findings: {d}\n", .{input.dogfood_findings});
    }

    switch (input.phase) {
        .baseline => {
            try output.print(allocator, "before json: {s}\n", .{input.paths.before_json_path});
            try output.print(allocator, "package-tests: {s}\n", .{@tagName(input.package_status)});
            if (input.scenario_status != null) {
                try output.print(allocator, "next: zig build causal-dev-loop -- after {s}\n", .{input.target});
            } else {
                try output.appendSlice(allocator, "next: zig build causal-dev-loop -- after\n");
            }
        },
        .after => {
            try output.print(allocator, "after json: {s}\n", .{input.paths.after_json_path});
            try output.print(allocator, "compare report: {s}\n", .{input.paths.compare_report_path});
            try output.print(allocator, "query report: {s}\n", .{input.paths.query_report_path});
            try output.print(allocator, "advice report: {s}\n", .{input.paths.advice_report_path});
            try output.print(allocator, "verdict: {s}\n", .{input.paths.verdict_report_path});
            try output.print(allocator, "package-tests: {s}\n", .{@tagName(input.package_status)});
            if (input.compare_report) |report| {
                try output.appendSlice(allocator, "compare summary:\n");
                try output.appendSlice(allocator, report);
                if (report.len == 0 or report[report.len - 1] != '\n') try output.append(allocator, '\n');
            }
            try output.appendSlice(allocator, "next: inspect verdict\n");
        },
    }

    return output.toOwnedSlice(allocator);
}

fn exitCodeForPackageStatus(status: PackageStatus) u8 {
    return switch (status) {
        .pass => 0,
        .failure => 1,
    };
}

fn exitCodeForScenarioStatus(status: ScenarioStatus) u8 {
    return switch (status) {
        .pass,
        .expected_failure_observed,
        => 0,
        .failure => 1,
    };
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn buildQueryReport(allocator: std.mem.Allocator, json: []const u8, artifact_path: []const u8) ![]const u8 {
    var parsed = try std.json.parseFromSlice(Artifact, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    var seen = std.ArrayList([]const u8).empty;
    defer {
        for (seen.items) |command| allocator.free(command);
        seen.deinit(allocator);
    }

    var body = std.ArrayList(u8).empty;
    defer body.deinit(allocator);
    var query_count: usize = 0;

    const events = parsed.value.events;
    for (events) |event| {
        if (std.mem.eql(u8, event.kind, "service_required") and std.mem.eql(u8, event.status, "missing")) {
            try appendCauseAndLineageQueries(allocator, &body, json, artifact_path, &seen, &query_count, event.id);
            if (event.run_id) |run_id| try appendU64Query(allocator, &body, json, artifact_path, &seen, &query_count, "requirements", run_id);
        } else if (std.mem.eql(u8, event.kind, "resource_acquired") and !hasFinalizedResource(events, event)) {
            try appendCauseAndLineageQueries(allocator, &body, json, artifact_path, &seen, &query_count, event.id);
            if (event.scope_id) |scope_id| try appendU64Query(allocator, &body, json, artifact_path, &seen, &query_count, "resources", scope_id);
        } else if ((std.mem.eql(u8, event.kind, "fiber_forked") or std.mem.eql(u8, event.kind, "fiber_started")) and (std.mem.eql(u8, event.status, "pending") or std.mem.eql(u8, event.status, "running"))) {
            try appendCauseAndLineageQueries(allocator, &body, json, artifact_path, &seen, &query_count, event.id);
            try appendQuery(allocator, &body, json, artifact_path, &seen, &query_count, &.{ "fibers", event.status });
        } else if (std.mem.eql(u8, event.kind, "schedule_decision") and std.mem.eql(u8, event.status, "exhausted")) {
            try appendCauseAndLineageQueries(allocator, &body, json, artifact_path, &seen, &query_count, event.id);
            if (event.run_id) |run_id| try appendU64Query(allocator, &body, json, artifact_path, &seen, &query_count, "retries", run_id);
        } else if (std.mem.eql(u8, event.kind, "assertion_recorded") and std.mem.eql(u8, event.status, "failure")) {
            try appendCauseAndLineageQueries(allocator, &body, json, artifact_path, &seen, &query_count, event.id);
        } else if (std.mem.eql(u8, event.kind, "resource_finalized") and std.mem.eql(u8, event.status, "failure")) {
            try appendCauseAndLineageQueries(allocator, &body, json, artifact_path, &seen, &query_count, event.id);
            if (event.scope_id) |scope_id| try appendU64Query(allocator, &body, json, artifact_path, &seen, &query_count, "resources", scope_id);
        }
    }

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, "zigeffect causal query report\n");
    try causal_artifact.appendArtifactCompatibilityWarnings(&output, allocator, artifact_path, .{
        .schema = parsed.value.schema,
        .schema_version = parsed.value.schema_version,
        .event_taxonomy_version = parsed.value.event_taxonomy_version,
    });
    try causal_artifact.appendUnknownEventKindWarnings(&output, allocator, artifact_path, parsed.value.events);
    try output.print(allocator, "queries: {d}\n", .{query_count});
    if (query_count == 0) {
        try output.appendSlice(allocator, "- no follow-up queries selected\n");
    } else {
        try output.appendSlice(allocator, body.items);
    }
    return output.toOwnedSlice(allocator);
}

fn appendCauseAndLineageQueries(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    json: []const u8,
    artifact_path: []const u8,
    seen: *std.ArrayList([]const u8),
    query_count: *usize,
    event_id: u64,
) !void {
    try appendU64Query(allocator, output, json, artifact_path, seen, query_count, "cause", event_id);
    try appendU64Query(allocator, output, json, artifact_path, seen, query_count, "lineage", event_id);
}

fn appendU64Query(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    json: []const u8,
    artifact_path: []const u8,
    seen: *std.ArrayList([]const u8),
    query_count: *usize,
    query_name: []const u8,
    value: u64,
) !void {
    const value_text = try std.fmt.allocPrint(allocator, "{d}", .{value});
    defer allocator.free(value_text);
    try appendQuery(allocator, output, json, artifact_path, seen, query_count, &.{ query_name, value_text });
}

fn appendQuery(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    json: []const u8,
    artifact_path: []const u8,
    seen: *std.ArrayList([]const u8),
    query_count: *usize,
    args: []const []const u8,
) !void {
    var command = std.ArrayList(u8).empty;
    errdefer command.deinit(allocator);
    try command.print(allocator, "zig build causal-query -- --file {s}", .{artifact_path});
    for (args) |arg| try command.print(allocator, " {s}", .{arg});
    const command_text = try command.toOwnedSlice(allocator);
    errdefer allocator.free(command_text);

    for (seen.items) |existing| {
        if (std.mem.eql(u8, existing, command_text)) {
            allocator.free(command_text);
            return;
        }
    }

    try seen.append(allocator, command_text);
    query_count.* += 1;
    try output.print(allocator, "query: {s}\n", .{command_text});
    const result = try causal_query.runQueryWithOptions(allocator, json, args, .{
        .include_artifact_warnings = false,
    });
    defer allocator.free(result);
    try output.appendSlice(allocator, result);
    if (result.len == 0 or result[result.len - 1] != '\n') try output.append(allocator, '\n');
}

fn hasFinalizedResource(events: []const Event, acquired: Event) bool {
    for (events) |event| {
        if (!std.mem.eql(u8, event.kind, "resource_finalized")) continue;
        if (event.scope_id != acquired.scope_id) continue;
        if (!std.mem.eql(u8, event.type_name, acquired.type_name)) continue;
        return true;
    }
    return false;
}

fn writeDogfoodArtifacts(io: std.Io, artifacts: causal_test.ArtifactSet) !void {
    try writeArtifact(io, artifacts.report_path, artifacts.report);
    try writeArtifact(io, artifacts.json_path, artifacts.json);
    try writeArtifact(io, artifacts.dot_path, artifacts.dot);
}

fn writeCommandArtifacts(io: std.Io, artifacts: causal_run.CommandArtifacts) !void {
    try writeArtifact(io, artifacts.report_path, artifacts.report);
    try writeArtifact(io, artifacts.json_path, artifacts.json);
    try writeArtifact(io, artifacts.dot_path, artifacts.dot);
}

fn captureDogfood(io: std.Io, allocator: std.mem.Allocator, target_json_path: []const u8) !usize {
    const artifacts = try causal_test.buildDogfoodArtifacts(allocator);
    defer artifacts.deinit(allocator);

    try writeDogfoodArtifacts(io, artifacts);
    try writeArtifact(io, target_json_path, artifacts.json);

    return artifacts.finding_count;
}

fn commandFailed(term: std.process.Child.Term) bool {
    return switch (term) {
        .exited => |code| code != 0,
        else => true,
    };
}

fn scenarioStatusForTerm(scenario: causal_run.Scenario, term: std.process.Child.Term) ScenarioStatus {
    const failed = commandFailed(term);
    return switch (scenario.expectation) {
        .expected_pass => if (failed) .failure else .pass,
        .expected_failure => if (failed) .expected_failure_observed else .failure,
    };
}

fn packageStatusFromScenarioStatus(status: ScenarioStatus) PackageStatus {
    return switch (status) {
        .pass,
        .expected_failure_observed,
        => .pass,
        .failure => .failure,
    };
}

fn captureScenario(
    io: std.Io,
    allocator: std.mem.Allocator,
    scenario: causal_run.Scenario,
    target_json_path: []const u8,
) !ScenarioCapture {
    const result = std.process.run(allocator, io, .{
        .argv = scenario.argv,
        .stdout_limit = .limited(64 * 1024),
        .stderr_limit = .limited(64 * 1024),
    }) catch |err| {
        const artifacts = try causal_run.buildCommandArtifacts(allocator, scenario, .{
            .term = .{ .unknown = 0 },
            .stdout = "",
            .stderr = @errorName(err),
        });
        defer artifacts.deinit(allocator);
        try writeCommandArtifacts(io, artifacts);
        try writeArtifact(io, target_json_path, artifacts.json);
        return .{
            .status = .failure,
            .finding_count = artifacts.finding_count,
        };
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const artifacts = try causal_run.buildCommandArtifacts(allocator, scenario, .{
        .term = result.term,
        .stdout = result.stdout,
        .stderr = result.stderr,
    });
    defer artifacts.deinit(allocator);
    try writeCommandArtifacts(io, artifacts);
    try writeArtifact(io, target_json_path, artifacts.json);

    return .{
        .status = scenarioStatusForTerm(scenario, result.term),
        .finding_count = artifacts.finding_count,
    };
}

fn runPackageTests(io: std.Io, allocator: std.mem.Allocator) !PackageStatus {
    const scenario = try causal_run.scenarioByName("package-tests");
    const result = std.process.run(allocator, io, .{
        .argv = scenario.argv,
        .stdout_limit = .limited(64 * 1024),
        .stderr_limit = .limited(64 * 1024),
    }) catch |err| {
        const artifacts = try causal_run.buildFailureArtifacts(allocator, scenario, .{
            .term = .{ .unknown = 0 },
            .stdout = "",
            .stderr = @errorName(err),
        });
        defer artifacts.deinit(allocator);
        try writeCommandArtifacts(io, artifacts);
        return .failure;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (commandFailed(result.term)) {
        const artifacts = try causal_run.buildFailureArtifacts(allocator, scenario, .{
            .term = result.term,
            .stdout = result.stdout,
            .stderr = result.stderr,
        });
        defer artifacts.deinit(allocator);
        try writeCommandArtifacts(io, artifacts);
        return .failure;
    }

    return .pass;
}

fn runBaseline(init: std.process.Init, scenario: ?causal_run.Scenario) !u8 {
    const allocator = init.gpa;
    const paths = if (scenario) |target| try loopPathsForScenario(allocator, target.slug) else loopPaths();
    defer paths.deinit(allocator);

    const target = if (scenario) |selected| selected.slug else "dogfood";
    const capture = if (scenario) |selected| try captureScenario(init.io, allocator, selected, paths.before_json_path) else ScenarioCapture{
        .status = .pass,
        .finding_count = try captureDogfood(init.io, allocator, paths.before_json_path),
    };
    const package_status = if (scenario) |selected|
        if (std.mem.eql(u8, selected.slug, "package-tests"))
            packageStatusFromScenarioStatus(capture.status)
        else
            try runPackageTests(init.io, allocator)
    else
        try runPackageTests(init.io, allocator);
    const summary = try formatSummary(allocator, .{
        .phase = .baseline,
        .dogfood_findings = capture.finding_count,
        .package_status = package_status,
        .paths = paths,
        .compare_report = null,
        .target = target,
        .scenario_status = if (scenario != null) capture.status else null,
    });
    defer allocator.free(summary);
    std.debug.print("{s}", .{summary});
    const scenario_exit = if (scenario != null) exitCodeForScenarioStatus(capture.status) else 0;
    return @max(scenario_exit, exitCodeForPackageStatus(package_status));
}

fn readLoopArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingBaselineArtifact,
        else => return err,
    };
}

fn runAfter(init: std.process.Init, scenario: ?causal_run.Scenario) !u8 {
    const allocator = init.gpa;
    const paths = if (scenario) |target| try loopPathsForScenario(allocator, target.slug) else loopPaths();
    defer paths.deinit(allocator);
    const before = try readLoopArtifact(init.io, allocator, paths.before_json_path);
    defer allocator.free(before);

    const target = if (scenario) |selected| selected.slug else "dogfood";
    const capture = if (scenario) |selected| try captureScenario(init.io, allocator, selected, paths.after_json_path) else ScenarioCapture{
        .status = .pass,
        .finding_count = try captureDogfood(init.io, allocator, paths.after_json_path),
    };
    const after = try readLoopArtifact(init.io, allocator, paths.after_json_path);
    defer allocator.free(after);

    const compare_report = try causal_compare.runCompare(allocator, before, after);
    defer allocator.free(compare_report);
    try writeArtifact(init.io, paths.compare_report_path, compare_report);
    const query_report = try buildQueryReport(allocator, after, paths.after_json_path);
    defer allocator.free(query_report);
    try writeArtifact(init.io, paths.query_report_path, query_report);
    const advice_report = try causal_advice.buildAdviceReportWithBaseline(
        allocator,
        before,
        paths.before_json_path,
        after,
        paths.after_json_path,
    );
    defer allocator.free(advice_report);
    try writeArtifact(init.io, paths.advice_report_path, advice_report);
    const verdict_inputs: []const causal_verdict.ArtifactVerdictInput = &.{
        .{
            .json_path = paths.after_json_path,
            .baseline_path = paths.before_json_path,
            .advice_report_path = paths.advice_report_path,
            .compare_report_path = paths.compare_report_path,
        },
    };
    const verdict_advice_reports: []const []const u8 = &.{advice_report};
    const verdict = try causal_verdict.formatVerdictJson(
        allocator,
        "zigeffect.causal.dev-loop-verdict.v1",
        verdict_inputs,
        verdict_advice_reports,
    );
    defer allocator.free(verdict);
    try writeArtifact(init.io, paths.verdict_report_path, verdict);

    const package_status = if (scenario) |selected|
        if (std.mem.eql(u8, selected.slug, "package-tests"))
            packageStatusFromScenarioStatus(capture.status)
        else
            try runPackageTests(init.io, allocator)
    else
        try runPackageTests(init.io, allocator);
    const summary = try formatSummary(allocator, .{
        .phase = .after,
        .dogfood_findings = capture.finding_count,
        .package_status = package_status,
        .paths = paths,
        .compare_report = compare_report,
        .target = target,
        .scenario_status = if (scenario != null) capture.status else null,
    });
    defer allocator.free(summary);
    std.debug.print("{s}", .{summary});
    const scenario_exit = if (scenario != null) exitCodeForScenarioStatus(capture.status) else 0;
    return @max(scenario_exit, exitCodeForPackageStatus(package_status));
}

fn parsePhase(arg: []const u8) ?Phase {
    if (std.mem.eql(u8, arg, "baseline")) return .baseline;
    if (std.mem.eql(u8, arg, "after")) return .after;
    return null;
}

fn usage() []const u8 {
    return "usage: zig build causal-dev-loop -- <baseline|after> [scenario]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-dev-loop error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 2) failUsage(error.MissingPhase);
    if (args.len > 3) failUsage(error.TooManyArguments);

    const phase = parsePhase(args[1]) orelse failUsage(error.UnknownPhase);
    const scenario = if (args.len == 3) causal_run.scenarioByName(args[2]) catch |err| failUsage(err) else null;
    const exit_code = switch (phase) {
        .baseline => try runBaseline(init, scenario),
        .after => runAfter(init, scenario) catch |err| switch (err) {
            error.MissingBaselineArtifact => failUsage(err),
            else => return err,
        },
    };
    if (exit_code != 0) std.process.exit(exit_code);
}

test "dev loop paths are stable" {
    const paths = loopPaths();
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
        paths.before_json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json",
        paths.after_json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
        paths.compare_report_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt",
        paths.query_report_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
        paths.advice_report_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
        paths.verdict_report_path,
    );
}

test "scenario dev loop paths include scenario slug" {
    const paths = try loopPathsForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-before.json",
        paths.before_json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-after.json",
        paths.after_json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-compare.txt",
        paths.compare_report_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-queries.txt",
        paths.query_report_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-advice.txt",
        paths.advice_report_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json",
        paths.verdict_report_path,
    );
}

test "baseline summary points to after phase" {
    const paths = loopPaths();
    const summary = try formatSummary(std.testing.allocator, .{
        .phase = .baseline,
        .dogfood_findings = 4,
        .package_status = .pass,
        .paths = paths,
        .compare_report = null,
    });
    defer std.testing.allocator.free(summary);

    try std.testing.expect(std.mem.indexOf(u8, summary, "zigeffect causal dev loop") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "phase: baseline") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "package-tests: pass") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "next: zig build causal-dev-loop -- after") != null);
}

test "after summary includes compare and query report paths" {
    const paths = loopPaths();
    const summary = try formatSummary(std.testing.allocator, .{
        .phase = .after,
        .dogfood_findings = 4,
        .package_status = .pass,
        .paths = paths,
        .compare_report = "zigeffect causal compare report\nfinding delta: +0\n",
    });
    defer std.testing.allocator.free(summary);

    try std.testing.expect(std.mem.indexOf(u8, summary, "phase: after") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "compare report: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "query report: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "advice report: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "next: inspect verdict") != null);
}

test "package failure status exits nonzero" {
    try std.testing.expectEqual(@as(u8, 0), exitCodeForPackageStatus(.pass));
    try std.testing.expectEqual(@as(u8, 1), exitCodeForPackageStatus(.failure));
}

test "scenario status treats expected failure as observed evidence" {
    const missing = try causal_run.scenarioByName("missing-service-compile-fail");
    const passing = try causal_run.scenarioByName("causal-scoped-fiber");

    try std.testing.expectEqual(ScenarioStatus.expected_failure_observed, scenarioStatusForTerm(missing, .{ .exited = 1 }));
    try std.testing.expectEqual(ScenarioStatus.failure, scenarioStatusForTerm(missing, .{ .exited = 0 }));
    try std.testing.expectEqual(ScenarioStatus.pass, scenarioStatusForTerm(passing, .{ .exited = 0 }));
    try std.testing.expectEqual(ScenarioStatus.failure, scenarioStatusForTerm(passing, .{ .exited = 1 }));
}

test "query report runs selected dogfood follow-up queries" {
    const report = try buildQueryReport(std.testing.allocator, dogfood_query_json, ".zig-cache/causal-artifacts/after.json");
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal query report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "query: zig build causal-query -- --file .zig-cache/causal-artifacts/after.json cause 3") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal.query: requirements 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal.query: resources 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal.query: fibers pending") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal.query: retries 1") != null);
}

test "query report accepts versioned causal artifacts" {
    const report = try buildQueryReport(std.testing.allocator, versioned_dogfood_query_json, ".zig-cache/causal-artifacts/after.json");
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal query report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "queries: 12") != null);
}

test "query report warns once when artifact taxonomy is newer than supported" {
    const report = try buildQueryReport(std.testing.allocator, future_taxonomy_dogfood_query_json, ".zig-cache/causal-artifacts/after.json");
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "warning: .zig-cache/causal-artifacts/after.json event_taxonomy_version=2 newer than supported=1") != null);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, report, "warning:"));
    try std.testing.expect(std.mem.indexOf(u8, report, "queries: 12") != null);
}

test "query report warns on future schema and unknown event kind" {
    const report = try buildQueryReport(std.testing.allocator, future_schema_unknown_kind_dogfood_query_json, ".zig-cache/causal-artifacts/future.json");
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "warning: .zig-cache/causal-artifacts/future.json schema_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "warning: .zig-cache/causal-artifacts/future.json event kind effect_suspended unknown to supported taxonomy=1") != null);
}

test "query report is explicit when no follow-up queries are selected" {
    const report = try buildQueryReport(std.testing.allocator, no_finding_query_json, ".zig-cache/causal-artifacts/after.json");
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "queries: 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "no follow-up queries selected") != null);
}
