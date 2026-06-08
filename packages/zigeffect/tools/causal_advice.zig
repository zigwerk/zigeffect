const std = @import("std");
const causal_artifact = @import("causal_artifact");

pub const default_artifact_path = ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json";

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

const AdviceStatus = enum {
    observed,
    new,
    persisting,
};

const advice_sample_json =
    \\{
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"zigeffect dogfood","type_name":"DogfoodHarness","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"scope_opened","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":1,"trace_id":null,"span_id":null,"label":"dogfood scope","type_name":"","status":"opened","redacted_detail":""},
    \\    {"id":3,"kind":"service_required","run_id":1,"parent_id":2,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"services.config.Config","status":"missing","redacted_detail":"missing provider"},
    \\    {"id":4,"kind":"resource_acquired","run_id":1,"parent_id":2,"fiber_id":null,"scope_id":1,"trace_id":null,"span_id":null,"label":"dogfood database","type_name":"DogfoodDatabaseConnection","status":"success","redacted_detail":"left open"},
    \\    {"id":5,"kind":"fiber_forked","run_id":1,"parent_id":2,"fiber_id":42,"scope_id":1,"trace_id":null,"span_id":null,"label":"dogfood child fiber","type_name":"","status":"pending","redacted_detail":""},
    \\    {"id":6,"kind":"schedule_decision","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"dogfood retry policy","type_name":"Schedule.exponential","status":"exhausted","redacted_detail":"retry budget exhausted"},
    \\    {"id":7,"kind":"resource_finalized","run_id":1,"parent_id":4,"fiber_id":null,"scope_id":1,"trace_id":null,"span_id":null,"label":"cleanup","type_name":"FailedFinalizer","status":"failure","redacted_detail":"finalizer failed"}
    \\  ]
    \\}
;

const assertion_failure_json =
    \\{
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"package-tests-failure-fixture","type_name":"CausalCommandScenario","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"effect_started","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Package Tests Failure Fixture","type_name":"DevelopmentCommand","status":"started","redacted_detail":""},
    \\    {"id":3,"kind":"assertion_recorded","run_id":1,"parent_id":2,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"package-tests-failure-fixture","type_name":"CommandExit","status":"failure","redacted_detail":"command exited with code 1"}
    \\  ]
    \\}
;

const no_advice_json =
    \\{
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"passing scenario","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"exit_recorded","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"passing scenario","type_name":"Command","status":"success","redacted_detail":""}
    \\  ]
    \\}
;

const future_taxonomy_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 2,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future taxonomy","type_name":"Fixture","status":"started","redacted_detail":""}
    \\  ]
    \\}
;

const future_schema_unknown_kind_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 2,
    \\  "event_taxonomy_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future schema","type_name":"Fixture","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"effect_suspended","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future event","type_name":"Fixture","status":"pending","redacted_detail":""}
    \\  ]
    \\}
;

const advice_delta_before_json =
    \\{
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"before","type_name":"Harness","status":"started","redacted_detail":""},
    \\    {"id":30,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"services.config.Config","status":"missing","redacted_detail":"missing provider"}
    \\  ]
    \\}
;

const advice_delta_after_json =
    \\{
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"after","type_name":"Harness","status":"started","redacted_detail":""},
    \\    {"id":3,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"services.config.Config","status":"missing","redacted_detail":"missing provider"},
    \\    {"id":9,"kind":"assertion_recorded","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"package-tests","type_name":"CommandExit","status":"failure","redacted_detail":"command failed"}
    \\  ]
    \\}
;

pub fn buildAdviceReport(allocator: std.mem.Allocator, json: []const u8, artifact_path: []const u8) ![]const u8 {
    var parsed = try std.json.parseFromSlice(Artifact, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    return formatAdviceReport(
        allocator,
        artifact_path,
        null,
        parsed.value.events,
        null,
        .{
            .schema = parsed.value.schema,
            .schema_version = parsed.value.schema_version,
            .event_taxonomy_version = parsed.value.event_taxonomy_version,
        },
    );
}

pub fn buildAdviceReportWithBaseline(
    allocator: std.mem.Allocator,
    baseline_json: []const u8,
    baseline_path: []const u8,
    json: []const u8,
    artifact_path: []const u8,
) ![]const u8 {
    var baseline = try std.json.parseFromSlice(Artifact, allocator, baseline_json, .{ .ignore_unknown_fields = true });
    defer baseline.deinit();

    var parsed = try std.json.parseFromSlice(Artifact, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    var baseline_signatures = try collectActionSignatures(allocator, baseline.value.events);
    defer {
        for (baseline_signatures.items) |signature| allocator.free(signature);
        baseline_signatures.deinit(allocator);
    }

    return formatAdviceReport(
        allocator,
        artifact_path,
        baseline_path,
        parsed.value.events,
        baseline_signatures.items,
        .{
            .schema = parsed.value.schema,
            .schema_version = parsed.value.schema_version,
            .event_taxonomy_version = parsed.value.event_taxonomy_version,
        },
    );
}

fn formatAdviceReport(
    allocator: std.mem.Allocator,
    artifact_path: []const u8,
    baseline_path: ?[]const u8,
    events: []const Event,
    baseline_signatures: ?[]const []const u8,
    metadata: causal_artifact.ArtifactMetadata,
) ![]const u8 {
    var body = std.ArrayList(u8).empty;
    defer body.deinit(allocator);
    var action_count: usize = 0;

    for (events) |event| {
        const action = actionNameForEvent(events, event) orelse continue;
        const status = try adviceStatusForEvent(allocator, baseline_signatures, action, event);
        try appendAdviceAction(allocator, &body, artifact_path, action, status, event);
        action_count += 1;
    }

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, "zigeffect causal advice report\n");
    try output.print(allocator, "artifact: {s}\n", .{artifact_path});
    if (baseline_path) |path| try output.print(allocator, "baseline: {s}\n", .{path});
    try causal_artifact.appendArtifactCompatibilityWarnings(&output, allocator, artifact_path, metadata);
    try causal_artifact.appendUnknownEventKindWarnings(&output, allocator, artifact_path, events);
    try output.print(allocator, "actions: {d}\n", .{action_count});
    if (action_count == 0) {
        try output.appendSlice(allocator, "- no causal advice selected\n");
    } else {
        try output.appendSlice(allocator, body.items);
    }
    return output.toOwnedSlice(allocator);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    var file_path: ?[]const u8 = null;
    var baseline_path: ?[]const u8 = null;
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--file")) {
            index += 1;
            if (index >= args.len) failUsage(error.MissingFileArgument);
            file_path = args[index];
        } else if (std.mem.eql(u8, arg, "--before")) {
            index += 1;
            if (index >= args.len) failUsage(error.MissingBeforeArgument);
            baseline_path = args[index];
        } else if (file_path == null) {
            file_path = arg;
        } else {
            failUsage(error.UnknownArgument);
        }
    }

    const resolved_file_path = file_path orelse default_artifact_path;
    const json = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        resolved_file_path,
        allocator,
        .limited(1024 * 1024),
    );
    defer allocator.free(json);

    const report = if (baseline_path) |path| blk: {
        const baseline_json = try std.Io.Dir.cwd().readFileAlloc(
            init.io,
            path,
            allocator,
            .limited(1024 * 1024),
        );
        defer allocator.free(baseline_json);
        break :blk buildAdviceReportWithBaseline(allocator, baseline_json, path, json, resolved_file_path);
    } else buildAdviceReport(allocator, json, resolved_file_path);

    const resolved_report = report catch |err| switch (err) {
        error.SyntaxError,
        error.UnexpectedToken,
        error.UnknownField,
        error.MissingField,
        => failUsage(err),
        else => return err,
    };
    defer allocator.free(resolved_report);
    std.debug.print("{s}", .{resolved_report});
}

fn usage() []const u8 {
    return "usage: zig build causal-advice -- [--before <before.json>] [--file <path>|<path>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-advice error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(1);
}

fn appendActionHeader(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    action: []const u8,
    status: AdviceStatus,
    event: Event,
) std.mem.Allocator.Error!void {
    try output.print(
        allocator,
        "- action {s} status={s} event={d} kind={s}",
        .{ action, @tagName(status), event.id, event.kind },
    );
    if (event.label.len > 0) try output.print(allocator, " label={s}", .{event.label});
    try output.append(allocator, '\n');
}

fn appendAdviceAction(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    artifact_path: []const u8,
    action: []const u8,
    status: AdviceStatus,
    event: Event,
) std.mem.Allocator.Error!void {
    try appendActionHeader(allocator, output, action, status, event);
    if (std.mem.eql(u8, action, "provide-missing-service")) {
        try output.appendSlice(allocator, "  why: service requirement is missing a provider\n");
        try appendEventQuery(allocator, output, artifact_path, "cause", event.id);
        if (event.run_id) |run_id| try appendU64Query(allocator, output, artifact_path, "requirements", run_id);
    } else if (std.mem.eql(u8, action, "close-resource")) {
        try output.appendSlice(allocator, "  why: resource acquisition has no matching finalization event\n");
        try appendEventQuery(allocator, output, artifact_path, "cause", event.id);
        if (event.scope_id) |scope_id| try appendU64Query(allocator, output, artifact_path, "resources", scope_id);
    } else if (std.mem.eql(u8, action, "resolve-scoped-fiber")) {
        try output.appendSlice(allocator, "  why: scoped fiber remains active in causal evidence\n");
        try appendEventQuery(allocator, output, artifact_path, "cause", event.id);
        try appendTextQuery(allocator, output, artifact_path, "fibers", event.status);
    } else if (std.mem.eql(u8, action, "inspect-retry-exhaustion")) {
        try output.appendSlice(allocator, "  why: retry schedule exhausted its budget\n");
        try appendEventQuery(allocator, output, artifact_path, "cause", event.id);
        if (event.run_id) |run_id| try appendU64Query(allocator, output, artifact_path, "retries", run_id);
    } else if (std.mem.eql(u8, action, "inspect-command-failure")) {
        try output.appendSlice(allocator, "  why: development command recorded a failed assertion\n");
        try appendEventQuery(allocator, output, artifact_path, "cause", event.id);
        try appendEventQuery(allocator, output, artifact_path, "lineage", event.id);
    } else if (std.mem.eql(u8, action, "inspect-finalizer-failure")) {
        try output.appendSlice(allocator, "  why: resource finalizer failed during cleanup\n");
        try appendEventQuery(allocator, output, artifact_path, "cause", event.id);
        if (event.scope_id) |scope_id| try appendU64Query(allocator, output, artifact_path, "resources", scope_id);
    }
}

fn actionNameForEvent(events: []const Event, event: Event) ?[]const u8 {
    if (std.mem.eql(u8, event.kind, "service_required") and std.mem.eql(u8, event.status, "missing")) {
        return "provide-missing-service";
    }
    if (std.mem.eql(u8, event.kind, "resource_acquired") and !hasFinalizedResource(events, event)) {
        return "close-resource";
    }
    if ((std.mem.eql(u8, event.kind, "fiber_forked") or std.mem.eql(u8, event.kind, "fiber_started")) and (std.mem.eql(u8, event.status, "pending") or std.mem.eql(u8, event.status, "running"))) {
        return "resolve-scoped-fiber";
    }
    if (std.mem.eql(u8, event.kind, "schedule_decision") and std.mem.eql(u8, event.status, "exhausted")) {
        return "inspect-retry-exhaustion";
    }
    if (std.mem.eql(u8, event.kind, "assertion_recorded") and std.mem.eql(u8, event.status, "failure")) {
        return "inspect-command-failure";
    }
    if (std.mem.eql(u8, event.kind, "resource_finalized") and std.mem.eql(u8, event.status, "failure")) {
        return "inspect-finalizer-failure";
    }
    return null;
}

fn collectActionSignatures(allocator: std.mem.Allocator, events: []const Event) std.mem.Allocator.Error!std.ArrayList([]const u8) {
    var signatures = std.ArrayList([]const u8).empty;
    errdefer {
        for (signatures.items) |signature| allocator.free(signature);
        signatures.deinit(allocator);
    }

    for (events) |event| {
        const action = actionNameForEvent(events, event) orelse continue;
        const signature = try actionSignature(allocator, action, event);
        try signatures.append(allocator, signature);
    }

    return signatures;
}

fn adviceStatusForEvent(
    allocator: std.mem.Allocator,
    baseline_signatures: ?[]const []const u8,
    action: []const u8,
    event: Event,
) std.mem.Allocator.Error!AdviceStatus {
    const signatures = baseline_signatures orelse return .observed;
    const signature = try actionSignature(allocator, action, event);
    defer allocator.free(signature);

    for (signatures) |existing| {
        if (std.mem.eql(u8, existing, signature)) return .persisting;
    }
    return .new;
}

fn actionSignature(allocator: std.mem.Allocator, action: []const u8, event: Event) std.mem.Allocator.Error![]const u8 {
    var signature = std.ArrayList(u8).empty;
    errdefer signature.deinit(allocator);

    try signature.print(
        allocator,
        "action={s}|kind={s}|label={s}|type={s}|status={s}|",
        .{ action, event.kind, event.label, event.type_name, event.status },
    );
    if (event.run_id) |run_id| {
        try signature.print(allocator, "run={d}|", .{run_id});
    } else {
        try signature.appendSlice(allocator, "run=null|");
    }
    if (event.scope_id) |scope_id| {
        try signature.print(allocator, "scope={d}", .{scope_id});
    } else {
        try signature.appendSlice(allocator, "scope=null");
    }

    return signature.toOwnedSlice(allocator);
}

fn appendEventQuery(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    artifact_path: []const u8,
    query: []const u8,
    event_id: u64,
) std.mem.Allocator.Error!void {
    try appendU64Query(allocator, output, artifact_path, query, event_id);
}

fn appendU64Query(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    artifact_path: []const u8,
    query: []const u8,
    value: u64,
) std.mem.Allocator.Error!void {
    try output.print(
        allocator,
        "  run: zig build causal-query -- --file {s} {s} {d}\n",
        .{ artifact_path, query, value },
    );
}

fn appendTextQuery(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    artifact_path: []const u8,
    query: []const u8,
    value: []const u8,
) std.mem.Allocator.Error!void {
    try output.print(
        allocator,
        "  run: zig build causal-query -- --file {s} {s} {s}\n",
        .{ artifact_path, query, value },
    );
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

test "advice report turns dogfood findings into deterministic actions" {
    const report = try buildAdviceReport(std.testing.allocator, advice_sample_json, ".zig-cache/causal-artifacts/after.json");
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal advice report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "artifact: .zig-cache/causal-artifacts/after.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "action provide-missing-service status=observed event=3 kind=service_required label=Config") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "run: zig build causal-query -- --file .zig-cache/causal-artifacts/after.json cause 3") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "run: zig build causal-query -- --file .zig-cache/causal-artifacts/after.json requirements 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "action close-resource status=observed event=4 kind=resource_acquired label=dogfood database") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "run: zig build causal-query -- --file .zig-cache/causal-artifacts/after.json resources 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "action resolve-scoped-fiber status=observed event=5 kind=fiber_forked label=dogfood child fiber") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "run: zig build causal-query -- --file .zig-cache/causal-artifacts/after.json fibers pending") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "action inspect-retry-exhaustion status=observed event=6 kind=schedule_decision label=dogfood retry policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "run: zig build causal-query -- --file .zig-cache/causal-artifacts/after.json retries 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "action inspect-finalizer-failure status=observed event=7 kind=resource_finalized label=cleanup") != null);
}

test "advice report captures command assertion failures" {
    const report = try buildAdviceReport(std.testing.allocator, assertion_failure_json, ".zig-cache/causal-artifacts/package.json");
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "action inspect-command-failure status=observed event=3 kind=assertion_recorded label=package-tests-failure-fixture") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "run: zig build causal-query -- --file .zig-cache/causal-artifacts/package.json lineage 3") != null);
}

test "before-aware advice marks persisting and new actions" {
    const report = try buildAdviceReportWithBaseline(
        std.testing.allocator,
        advice_delta_before_json,
        ".zig-cache/causal-artifacts/before.json",
        advice_delta_after_json,
        ".zig-cache/causal-artifacts/after.json",
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "baseline: .zig-cache/causal-artifacts/before.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "action provide-missing-service status=persisting event=3 kind=service_required label=Config") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "action inspect-command-failure status=new event=9 kind=assertion_recorded label=package-tests") != null);
}

test "advice report is explicit when no actions are selected" {
    const report = try buildAdviceReport(std.testing.allocator, no_advice_json, ".zig-cache/causal-artifacts/pass.json");
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "actions: 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "no causal advice selected") != null);
}

test "advice report warns when taxonomy is newer than supported" {
    const report = try buildAdviceReport(std.testing.allocator, future_taxonomy_json, ".zig-cache/causal-artifacts/future.json");
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "warning: .zig-cache/causal-artifacts/future.json event_taxonomy_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "actions: 0") != null);
}

test "advice report warns on future schema and unknown event kind" {
    const report = try buildAdviceReport(std.testing.allocator, future_schema_unknown_kind_json, ".zig-cache/causal-artifacts/future-schema.json");
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "warning: .zig-cache/causal-artifacts/future-schema.json schema_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "warning: .zig-cache/causal-artifacts/future-schema.json event kind effect_suspended unknown to supported taxonomy=1") != null);
}
