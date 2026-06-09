const std = @import("std");
const causal_advice = @import("causal_advice");

const app_audit_schema = "zigeffect.causal.app-remediation-audit.v1";
const max_app_incidents: usize = 64;
const max_audit_string_bytes: usize = 256;

const claim_guardrails = [_][]const u8{
    "Do not claim an app fix without rerunning the app request/job scenario that produced the cited artifact.",
    "Do not expose secret values while fixing config or binding incidents.",
    "Do not set applied=true from this audit; only a later reviewed application artifact may do that.",
};

const Options = struct {
    mode: []const u8,
    artifact_path: []const u8,
    target: []const u8,
    proposer: []const u8 = "local-agent",
    out_prefix: ?[]const u8 = null,
};

const OutputPaths = struct {
    json_path: []const u8,
    text_path: []const u8,

    fn deinit(self: OutputPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json_path);
        allocator.free(self.text_path);
    }
};

const AppActionMapping = struct {
    subsystem: []const u8,
    fix_category: []const u8,
    policy_gate: []const u8,
};

const AppIncident = struct {
    action: []const u8,
    status: []const u8,
    event_id: u64,
    event_kind: []const u8,
    label: []const u8,
    subsystem: []const u8,
    fix_category: []const u8,
    policy_gate: []const u8,
    query_commands: []const []const u8,
};

const AppAuditInput = struct {
    mode: []const u8,
    target: []const u8,
    proposer: []const u8,
    artifact_path: []const u8,
    incidents: []const AppIncident,
};

const CurrentIncident = struct {
    action: []const u8,
    status: []const u8,
    event_id: u64,
    event_kind: []const u8,
    label: []const u8,
    subsystem: []const u8,
    fix_category: []const u8,
    policy_gate: []const u8,
    query_commands: std.ArrayList([]const u8),
};

const app_advice_text =
    \\zigeffect causal advice report
    \\artifact: .zig-cache/causal-artifacts/app.json
    \\actions: 3
    \\- action fix-app-config status=observed event=2 kind=assertion_recorded label=YACHDEE_ENV
    \\  why: app request is missing required configuration
    \\  run: zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2
    \\  run: zig build causal-query -- --file .zig-cache/causal-artifacts/app.json lineage 2
    \\- action wire-app-requirement status=observed event=3 kind=assertion_recorded label=HealthService
    \\  why: app service requirement is missing a provider or binding
    \\  run: zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 3
    \\  run: zig build causal-query -- --file .zig-cache/causal-artifacts/app.json requirements 1
    \\- action inspect-app-response-failure status=observed event=4 kind=span_recorded label=app.response
    \\  why: app request recorded a failed response
    \\  run: zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 4
    \\  run: zig build causal-query -- --file .zig-cache/causal-artifacts/app.json lineage 4
    \\
;

fn usage() []const u8 {
    return "usage: zig build causal-app-remediation-audit -- local --artifact <path> --target <name> [--proposer <id>] [--out-prefix <path-prefix>]\n";
}

fn parseOptions(args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingMode;
    if (!std.mem.eql(u8, args[1], "local")) return error.UnknownMode;

    var artifact_path: ?[]const u8 = null;
    var target: ?[]const u8 = null;
    var proposer: []const u8 = "local-agent";
    var out_prefix: ?[]const u8 = null;

    var index: usize = 2;
    while (index < args.len) {
        const arg = args[index];
        if (!std.mem.startsWith(u8, arg, "--")) return error.UnknownArgument;
        if (index + 1 >= args.len) return error.MissingFlagValue;
        const value = args[index + 1];
        if (std.mem.eql(u8, arg, "--artifact")) {
            artifact_path = value;
        } else if (std.mem.eql(u8, arg, "--target")) {
            target = value;
        } else if (std.mem.eql(u8, arg, "--proposer")) {
            proposer = value;
        } else if (std.mem.eql(u8, arg, "--out-prefix")) {
            out_prefix = value;
        } else {
            return error.UnknownFlag;
        }
        index += 2;
    }

    return .{
        .mode = "local",
        .artifact_path = artifact_path orelse return error.MissingArtifact,
        .target = target orelse return error.MissingTarget,
        .proposer = proposer,
        .out_prefix = out_prefix,
    };
}

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try boundedDupe(allocator, out_prefix)
    else blk: {
        if (!std.mem.endsWith(u8, options.artifact_path, ".json")) return error.InvalidArtifactPath;
        break :blk try allocator.dupe(u8, options.artifact_path[0 .. options.artifact_path.len - ".json".len]);
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}-app-remediation-audit.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}-app-remediation-audit.txt", .{prefix}),
    };
}

fn parseAppAdviceIncidents(
    allocator: std.mem.Allocator,
    artifact_path: []const u8,
    advice_report: []const u8,
) ![]AppIncident {
    _ = artifact_path;
    var incidents = std.ArrayList(AppIncident).empty;
    var current: ?CurrentIncident = null;
    errdefer {
        if (current) |item| deinitCurrentIncident(allocator, item);
        deinitAppIncidents(allocator, incidents.items);
    }

    var lines = std.mem.splitScalar(u8, advice_report, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "- action ")) {
            if (current) |item| {
                try appendFinalIncident(allocator, &incidents, item);
                current = null;
            }
            current = try parseAppActionLine(allocator, line) orelse null;
            continue;
        }
        if (current != null and std.mem.startsWith(u8, line, "  run: ")) {
            try current.?.query_commands.append(allocator, try boundedDupe(allocator, line["  run: ".len..]));
        }
    }

    if (current) |item| {
        try appendFinalIncident(allocator, &incidents, item);
        current = null;
    }

    return incidents.toOwnedSlice(allocator);
}

fn appendFinalIncident(
    allocator: std.mem.Allocator,
    incidents: *std.ArrayList(AppIncident),
    current: CurrentIncident,
) !void {
    var owned = current;
    if (incidents.items.len >= max_app_incidents) {
        deinitCurrentIncident(allocator, owned);
        return error.TooManyAppIncidents;
    }

    const query_commands = try owned.query_commands.toOwnedSlice(allocator);
    try incidents.append(allocator, .{
        .action = owned.action,
        .status = owned.status,
        .event_id = owned.event_id,
        .event_kind = owned.event_kind,
        .label = owned.label,
        .subsystem = owned.subsystem,
        .fix_category = owned.fix_category,
        .policy_gate = owned.policy_gate,
        .query_commands = query_commands,
    });
}

fn parseAppActionLine(allocator: std.mem.Allocator, line: []const u8) !?CurrentIncident {
    const label_marker = " label=";
    const action_prefix, const label = if (std.mem.indexOf(u8, line, label_marker)) |label_index|
        .{ line[0..label_index], line[label_index + label_marker.len ..] }
    else
        .{ line, "" };

    var tokens = std.mem.splitScalar(u8, action_prefix, ' ');
    _ = tokens.next() orelse return error.InvalidAdviceActionLine;
    const action_keyword = tokens.next() orelse return error.InvalidAdviceActionLine;
    if (!std.mem.eql(u8, action_keyword, "action")) return error.InvalidAdviceActionLine;
    const action = tokens.next() orelse return error.InvalidAdviceActionLine;
    const mapping = appMapping(action) orelse return null;

    var status: ?[]const u8 = null;
    var event_id: ?u64 = null;
    var event_kind: ?[]const u8 = null;
    while (tokens.next()) |token| {
        if (std.mem.startsWith(u8, token, "status=")) {
            status = token["status=".len..];
        } else if (std.mem.startsWith(u8, token, "event=")) {
            event_id = try std.fmt.parseInt(u64, token["event=".len..], 10);
        } else if (std.mem.startsWith(u8, token, "kind=")) {
            event_kind = token["kind=".len..];
        }
    }

    return .{
        .action = try boundedDupe(allocator, action),
        .status = try boundedDupe(allocator, status orelse return error.InvalidAdviceActionLine),
        .event_id = event_id orelse return error.InvalidAdviceActionLine,
        .event_kind = try boundedDupe(allocator, event_kind orelse return error.InvalidAdviceActionLine),
        .label = try boundedDupe(allocator, label),
        .subsystem = try boundedDupe(allocator, mapping.subsystem),
        .fix_category = try boundedDupe(allocator, mapping.fix_category),
        .policy_gate = try boundedDupe(allocator, mapping.policy_gate),
        .query_commands = std.ArrayList([]const u8).empty,
    };
}

fn appMapping(action: []const u8) ?AppActionMapping {
    if (std.mem.eql(u8, action, "fix-app-config")) return .{
        .subsystem = "app_config",
        .fix_category = "config-or-secret-binding",
        .policy_gate = "config-only",
    };
    if (std.mem.eql(u8, action, "wire-app-requirement")) return .{
        .subsystem = "app_service_layer",
        .fix_category = "service-provider-or-layer",
        .policy_gate = "source-only",
    };
    if (std.mem.eql(u8, action, "inspect-app-response-failure")) return .{
        .subsystem = "app_request_path",
        .fix_category = "response-or-handler-failure",
        .policy_gate = "source-only",
    };
    if (std.mem.eql(u8, action, "inspect-app-retry-exhaustion")) return .{
        .subsystem = "app_dependency",
        .fix_category = "retry-policy-or-upstream",
        .policy_gate = "source-only",
    };
    if (std.mem.eql(u8, action, "close-app-resource")) return .{
        .subsystem = "app_resource_scope",
        .fix_category = "resource-finalizer",
        .policy_gate = "source-only",
    };
    if (std.mem.eql(u8, action, "resolve-app-fiber")) return .{
        .subsystem = "app_fiber_runtime",
        .fix_category = "structured-concurrency",
        .policy_gate = "source-only",
    };
    return null;
}

fn deinitAppIncidents(allocator: std.mem.Allocator, incidents: []const AppIncident) void {
    for (incidents) |incident| {
        allocator.free(incident.action);
        allocator.free(incident.status);
        allocator.free(incident.event_kind);
        allocator.free(incident.label);
        allocator.free(incident.subsystem);
        allocator.free(incident.fix_category);
        allocator.free(incident.policy_gate);
        for (incident.query_commands) |command| allocator.free(command);
        allocator.free(incident.query_commands);
    }
    allocator.free(incidents);
}

fn deinitCurrentIncident(allocator: std.mem.Allocator, incident: CurrentIncident) void {
    var owned = incident;
    allocator.free(incident.action);
    allocator.free(incident.status);
    allocator.free(incident.event_kind);
    allocator.free(incident.label);
    allocator.free(incident.subsystem);
    allocator.free(incident.fix_category);
    allocator.free(incident.policy_gate);
    for (incident.query_commands.items) |command| allocator.free(command);
    owned.query_commands.deinit(allocator);
}

fn formatAppAuditJson(allocator: std.mem.Allocator, input: AppAuditInput) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, app_audit_schema);
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
    try output.appendSlice(allocator, "  \"source\": {\n");
    try output.appendSlice(allocator, "    \"app_artifact\": ");
    try appendJsonString(allocator, &output, input.artifact_path);
    try output.appendSlice(allocator, ",\n    \"advice\": \"inline-generated\"\n  },\n");
    try output.appendSlice(allocator, "  \"approval_status\": \"pending\",\n");
    try output.appendSlice(allocator, "  \"applied\": false,\n");
    try output.appendSlice(allocator, "  \"mutation_authority\": \"none\",\n");
    try output.print(allocator, "  \"incident_count\": {d},\n", .{input.incidents.len});
    try output.appendSlice(allocator, "  \"incidents\": [\n");
    for (input.incidents, 0..) |incident, index| {
        if (index > 0) try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "    {\n");
        try output.appendSlice(allocator, "      \"action\": ");
        try appendJsonString(allocator, &output, incident.action);
        try output.appendSlice(allocator, ",\n      \"event_id\": ");
        try output.print(allocator, "{d}", .{incident.event_id});
        try output.appendSlice(allocator, ",\n      \"event_kind\": ");
        try appendJsonString(allocator, &output, incident.event_kind);
        try output.appendSlice(allocator, ",\n      \"label\": ");
        try appendJsonString(allocator, &output, incident.label);
        try output.appendSlice(allocator, ",\n      \"subsystem\": ");
        try appendJsonString(allocator, &output, incident.subsystem);
        try output.appendSlice(allocator, ",\n      \"fix_category\": ");
        try appendJsonString(allocator, &output, incident.fix_category);
        try output.appendSlice(allocator, ",\n      \"policy_gate\": ");
        try appendJsonString(allocator, &output, incident.policy_gate);
        try output.appendSlice(allocator, ",\n      \"query_commands\": ");
        try appendStringArray(allocator, &output, incident.query_commands);
        try output.appendSlice(allocator, "\n    }");
    }
    try output.appendSlice(allocator, "\n  ],\n");
    try output.appendSlice(allocator, "  \"policy_gates\": ");
    try appendPolicyGatesJson(allocator, &output, input.incidents);
    try output.appendSlice(allocator, ",\n  \"verification_commands\": ");
    try appendVerificationCommandsJson(allocator, &output, input.incidents);
    try output.appendSlice(allocator, ",\n  \"claim_guardrails\": ");
    try appendStringArray(allocator, &output, &claim_guardrails);
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatAppAuditText(allocator: std.mem.Allocator, input: AppAuditInput) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect app remediation audit\n");
    try output.print(allocator, "schema: {s}\n", .{app_audit_schema});
    try output.print(allocator, "mode: {s}\n", .{input.mode});
    try output.print(allocator, "target: {s}\n", .{input.target});
    try output.print(allocator, "proposer: {s}\n", .{input.proposer});
    try output.appendSlice(allocator, "approval_status: pending\n");
    try output.appendSlice(allocator, "applied: false\n");
    try output.appendSlice(allocator, "mutation_authority: none\n");
    try output.print(allocator, "incidents: {d}\n\n", .{input.incidents.len});

    try output.appendSlice(allocator, "source:\n");
    try output.print(allocator, "- app artifact: {s}\n", .{input.artifact_path});
    try output.appendSlice(allocator, "- advice: inline-generated\n\n");

    try output.appendSlice(allocator, "policy gates:\n");
    try appendPolicyGatesText(allocator, &output, input.incidents);
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "incidents:\n");
    for (input.incidents) |incident| {
        try output.print(
            allocator,
            "- event {d} action={s} gate={s} subsystem={s} label={s}\n",
            .{ incident.event_id, incident.action, incident.policy_gate, incident.subsystem, incident.label },
        );
    }
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "verification:\n");
    try appendVerificationCommandsText(allocator, &output, input.incidents);
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "claim guardrails:\n");
    for (claim_guardrails) |guardrail| try output.print(allocator, "- {s}\n", .{guardrail});
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "next:\n");
    try output.appendSlice(allocator, "- review app incident evidence before proposing source, config, migration, or operational changes\n");
    try output.appendSlice(allocator, "- run the cited causal-query commands before drafting a patch proposal\n");
    try output.appendSlice(allocator, "- hand this audit to the later app policy gate before any apply step\n");

    return output.toOwnedSlice(allocator);
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

fn appendStringArray(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const []const u8) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, value);
    }
    try output.append(allocator, ']');
}

fn appendPolicyGatesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), incidents: []const AppIncident) !void {
    var values = std.ArrayList([]const u8).empty;
    defer values.deinit(allocator);
    for (incidents) |incident| {
        if (!containsString(values.items, incident.policy_gate)) try values.append(allocator, incident.policy_gate);
    }
    try appendStringArray(allocator, output, values.items);
}

fn appendVerificationCommandsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), incidents: []const AppIncident) !void {
    var values = std.ArrayList([]const u8).empty;
    defer values.deinit(allocator);
    for (incidents) |incident| {
        for (incident.query_commands) |command| {
            if (!containsString(values.items, command)) try values.append(allocator, command);
        }
    }
    try appendStringArray(allocator, output, values.items);
}

fn appendPolicyGatesText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), incidents: []const AppIncident) !void {
    var values = std.ArrayList([]const u8).empty;
    defer values.deinit(allocator);
    for (incidents) |incident| {
        if (containsString(values.items, incident.policy_gate)) continue;
        try values.append(allocator, incident.policy_gate);
        try output.print(allocator, "- {s}\n", .{incident.policy_gate});
    }
}

fn appendVerificationCommandsText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), incidents: []const AppIncident) !void {
    var values = std.ArrayList([]const u8).empty;
    defer values.deinit(allocator);
    for (incidents) |incident| {
        for (incident.query_commands) |command| {
            if (containsString(values.items, command)) continue;
            try values.append(allocator, command);
            try output.print(allocator, "- `{s}`\n", .{command});
        }
    }
}

fn containsString(values: []const []const u8, candidate: []const u8) bool {
    for (values) |value| {
        if (std.mem.eql(u8, value, candidate)) return true;
    }
    return false;
}

fn boundedDupe(allocator: std.mem.Allocator, value: []const u8) ![]const u8 {
    return allocator.dupe(u8, value[0..@min(value.len, max_audit_string_bytes)]);
}

fn readArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingAppArtifact,
        else => return err,
    };
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn runLocal(init: std.process.Init, options: Options) !void {
    const allocator = init.gpa;
    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    const artifact_json = try readArtifact(init.io, allocator, options.artifact_path);
    defer allocator.free(artifact_json);

    const advice_report = try causal_advice.buildAdviceReport(allocator, artifact_json, options.artifact_path);
    defer allocator.free(advice_report);

    const incidents = try parseAppAdviceIncidents(allocator, options.artifact_path, advice_report);
    defer deinitAppIncidents(allocator, incidents);
    if (incidents.len == 0) return error.NoAppRemediationActions;

    const input = AppAuditInput{
        .mode = options.mode,
        .target = options.target,
        .proposer = options.proposer,
        .artifact_path = options.artifact_path,
        .incidents = incidents,
    };

    const json_report = try formatAppAuditJson(allocator, input);
    defer allocator.free(json_report);
    const text_report = try formatAppAuditText(allocator, input);
    defer allocator.free(text_report);

    try writeArtifact(init.io, paths.json_path, json_report);
    try writeArtifact(init.io, paths.text_path, text_report);
    std.debug.print("{s}", .{text_report});
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-remediation-audit error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(args) catch |err| failUsage(err);
    runLocal(init, options) catch |err| switch (err) {
        error.MissingAppArtifact,
        error.InvalidArtifactPath,
        error.NoAppRemediationActions,
        error.InvalidAdviceActionLine,
        error.TooManyAppIncidents,
        => failUsage(err),
        else => return err,
    };
}

test "usage text names app audit flags" {
    try std.testing.expectEqualStrings(
        "usage: zig build causal-app-remediation-audit -- local --artifact <path> --target <name> [--proposer <id>] [--out-prefix <path-prefix>]\n",
        usage(),
    );
}

test "output paths derive from artifact path and out prefix" {
    const defaults = try outputPathsForOptions(std.testing.allocator, .{
        .mode = "local",
        .artifact_path = ".zig-cache/causal-artifacts/app.json",
        .target = "yachdee-platform",
    });
    defer defaults.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-app-remediation-audit.json",
        defaults.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-app-remediation-audit.txt",
        defaults.text_path,
    );

    const custom = try outputPathsForOptions(std.testing.allocator, .{
        .mode = "local",
        .artifact_path = ".zig-cache/causal-artifacts/app.json",
        .target = "yachdee-platform",
        .out_prefix = ".zig-cache/causal-artifacts/yachdee-platform",
    });
    defer custom.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/yachdee-platform-app-remediation-audit.json",
        custom.json_path,
    );
}

test "app advice parser keeps only app remediation actions" {
    const incidents = try parseAppAdviceIncidents(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/app.json",
        app_advice_text,
    );
    defer deinitAppIncidents(std.testing.allocator, incidents);

    try std.testing.expectEqual(@as(usize, 3), incidents.len);
    try std.testing.expectEqualStrings("fix-app-config", incidents[0].action);
    try std.testing.expectEqual(@as(u64, 2), incidents[0].event_id);
    try std.testing.expectEqualStrings("config-only", incidents[0].policy_gate);
    try std.testing.expectEqualStrings("app_config", incidents[0].subsystem);
    try std.testing.expectEqualStrings("YACHDEE_ENV", incidents[0].label);
    try std.testing.expectEqual(@as(usize, 2), incidents[0].query_commands.len);
}

test "app audit JSON records pending non-mutating app evidence" {
    const incidents = try parseAppAdviceIncidents(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/app.json",
        app_advice_text,
    );
    defer deinitAppIncidents(std.testing.allocator, incidents);

    const json = try formatAppAuditJson(std.testing.allocator, .{
        .mode = "local",
        .target = "yachdee-platform",
        .proposer = "local-agent",
        .artifact_path = ".zig-cache/causal-artifacts/app.json",
        .incidents = incidents,
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\": \"zigeffect.causal.app-remediation-audit.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"approval_status\": \"pending\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"policy_gates\": [\"config-only\", \"source-only\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "redacted_detail") == null);
}

test "app audit text mirrors policy gates and guardrails" {
    const incidents = try parseAppAdviceIncidents(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/app.json",
        app_advice_text,
    );
    defer deinitAppIncidents(std.testing.allocator, incidents);

    const text = try formatAppAuditText(std.testing.allocator, .{
        .mode = "local",
        .target = "yachdee-platform",
        .proposer = "local-agent",
        .artifact_path = ".zig-cache/causal-artifacts/app.json",
        .incidents = incidents,
    });
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect app remediation audit") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "- config-only") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "- source-only") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "Do not set applied=true") != null);
}
