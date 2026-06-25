const std = @import("std");
const causal_run = @import("causal_run");

const schema_name = "zigeffect.causal.dev-session.v1";

const SessionPhase = enum {
    baseline_captured,
    assessed,
    failed,
};

const SessionAction = enum {
    start,
    assess,
    status,
};

const CommandStatus = enum {
    ok,
    failed,
    skipped,
};

const CommandRecord = struct {
    name: []const u8,
    argv: []const []const u8,
    status: CommandStatus,
    exit_code: ?i32,
    stdout_snippet: []const u8 = "",
    stderr_snippet: []const u8 = "",
};

const SessionArtifacts = struct {
    session_json_path: []const u8,
    session_text_path: []const u8,
    before_json_path: []const u8,
    after_json_path: []const u8,
    verdict_json_path: []const u8,
    diagnosis_text_path: []const u8,
    remediation_plan_path: []const u8,
    remediation_audit_json_path: []const u8,
    remediation_audit_text_path: []const u8,
};

const SessionRecord = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    phase: SessionPhase,
    status: []const u8,
    commands: []const CommandRecord,
    artifacts: SessionArtifacts,
};

const Options = struct {
    action: SessionAction,
    scenario_slug: ?[]const u8,
};

const RunOutput = struct {
    status: CommandStatus,
    exit_code: ?i32,
    stdout: []const u8,
    stderr: []const u8,
};

const Runner = struct {
    ptr: *anyopaque,
    runFn: *const fn (*anyopaque, std.mem.Allocator, []const []const u8) anyerror!RunOutput,

    fn run(self: Runner, allocator: std.mem.Allocator, argv: []const []const u8) !RunOutput {
        return self.runFn(self.ptr, allocator, argv);
    }
};

const ProcessRunner = struct {
    io: std.Io,

    fn runner(self: *ProcessRunner) Runner {
        return .{
            .ptr = self,
            .runFn = run,
        };
    }

    fn run(ptr: *anyopaque, allocator: std.mem.Allocator, argv: []const []const u8) !RunOutput {
        const self: *ProcessRunner = @ptrCast(@alignCast(ptr));
        const result = std.process.run(allocator, self.io, .{
            .argv = argv,
            .stdout_limit = .limited(64 * 1024),
            .stderr_limit = .limited(64 * 1024),
        }) catch |err| {
            return .{
                .status = .failed,
                .exit_code = null,
                .stdout = try allocator.dupe(u8, ""),
                .stderr = try allocator.dupe(u8, @errorName(err)),
            };
        };

        return .{
            .status = statusForTerm(result.term),
            .exit_code = exitCodeForTerm(result.term),
            .stdout = result.stdout,
            .stderr = result.stderr,
        };
    }
};

const FakeRunner = struct {
    outputs: []const RunOutput,
    index: usize = 0,
    calls: std.ArrayList([]const []const u8) = .empty,

    fn init(outputs: []const RunOutput) FakeRunner {
        return .{ .outputs = outputs };
    }

    fn runner(self: *FakeRunner) Runner {
        return .{
            .ptr = self,
            .runFn = run,
        };
    }

    fn run(ptr: *anyopaque, allocator: std.mem.Allocator, argv: []const []const u8) !RunOutput {
        const self: *FakeRunner = @ptrCast(@alignCast(ptr));
        const owned_argv = try allocator.alloc([]const u8, argv.len);
        @memcpy(owned_argv, argv);
        try self.calls.append(allocator, owned_argv);

        if (self.index >= self.outputs.len) return error.MissingFakeOutput;
        const output = self.outputs[self.index];
        self.index += 1;
        return .{
            .status = output.status,
            .exit_code = output.exit_code,
            .stdout = try allocator.dupe(u8, output.stdout),
            .stderr = try allocator.dupe(u8, output.stderr),
        };
    }

    fn deinit(self: *FakeRunner, allocator: std.mem.Allocator) void {
        for (self.calls.items) |argv| allocator.free(argv);
        self.calls.deinit(allocator);
    }
};

fn statusForTerm(term: std.process.Child.Term) CommandStatus {
    return switch (term) {
        .exited => |code| if (code == 0) .ok else .failed,
        else => .failed,
    };
}

fn exitCodeForTerm(term: std.process.Child.Term) ?i32 {
    return switch (term) {
        .exited => |code| @intCast(code),
        else => null,
    };
}

fn defaultSessionArtifacts() SessionArtifacts {
    return .{
        .session_json_path = causal_run.artifact_dir ++ "/zigeffect-causal-dev-session.json",
        .session_text_path = causal_run.artifact_dir ++ "/zigeffect-causal-dev-session.txt",
        .before_json_path = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-before.json",
        .after_json_path = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-after.json",
        .verdict_json_path = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-verdict.json",
        .diagnosis_text_path = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-diagnosis.txt",
        .remediation_plan_path = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-plan.md",
        .remediation_audit_json_path = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-audit.json",
        .remediation_audit_text_path = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-audit.txt",
    };
}

fn scenarioSessionArtifacts(allocator: std.mem.Allocator, slug: []const u8) !SessionArtifacts {
    return .{
        .session_json_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-session-{s}.json", .{ causal_run.artifact_dir, slug }),
        .session_text_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-session-{s}.txt", .{ causal_run.artifact_dir, slug }),
        .before_json_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-before.json", .{ causal_run.artifact_dir, slug }),
        .after_json_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-after.json", .{ causal_run.artifact_dir, slug }),
        .verdict_json_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-verdict.json", .{ causal_run.artifact_dir, slug }),
        .diagnosis_text_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-diagnosis.txt", .{ causal_run.artifact_dir, slug }),
        .remediation_plan_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-remediation-plan.md", .{ causal_run.artifact_dir, slug }),
        .remediation_audit_json_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-remediation-audit.json", .{ causal_run.artifact_dir, slug }),
        .remediation_audit_text_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-remediation-audit.txt", .{ causal_run.artifact_dir, slug }),
    };
}

fn sessionArtifactsForScenario(allocator: std.mem.Allocator, scenario_slug: ?[]const u8) !SessionArtifacts {
    if (scenario_slug) |slug| return scenarioSessionArtifacts(allocator, slug);
    return defaultSessionArtifacts();
}

fn deinitOwnedSessionArtifacts(allocator: std.mem.Allocator, artifacts: SessionArtifacts) void {
    allocator.free(artifacts.session_json_path);
    allocator.free(artifacts.session_text_path);
    allocator.free(artifacts.before_json_path);
    allocator.free(artifacts.after_json_path);
    allocator.free(artifacts.verdict_json_path);
    allocator.free(artifacts.diagnosis_text_path);
    allocator.free(artifacts.remediation_plan_path);
    allocator.free(artifacts.remediation_audit_json_path);
    allocator.free(artifacts.remediation_audit_text_path);
}

fn deinitSessionArtifactsForScenario(allocator: std.mem.Allocator, scenario_slug: ?[]const u8, artifacts: SessionArtifacts) void {
    if (scenario_slug != null) deinitOwnedSessionArtifacts(allocator, artifacts);
}

fn deinitSessionRecord(allocator: std.mem.Allocator, record: SessionRecord) void {
    for (record.commands) |command| {
        allocator.free(command.argv);
        allocator.free(command.stdout_snippet);
        allocator.free(command.stderr_snippet);
    }
    allocator.free(record.commands);
    if (!std.mem.eql(u8, record.target, "dogfood")) {
        deinitOwnedSessionArtifacts(allocator, record.artifacts);
    }
}

fn formatPhase(phase: SessionPhase) []const u8 {
    return switch (phase) {
        .baseline_captured => "baseline-captured",
        .assessed => "assessed",
        .failed => "failed",
    };
}

fn formatCommandStatus(status: CommandStatus) []const u8 {
    return switch (status) {
        .ok => "ok",
        .failed => "failed",
        .skipped => "skipped",
    };
}

fn parseAction(arg: []const u8) ?SessionAction {
    if (std.mem.eql(u8, arg, "start")) return .start;
    if (std.mem.eql(u8, arg, "assess")) return .assess;
    if (std.mem.eql(u8, arg, "status")) return .status;
    return null;
}

fn parseOptions(args: []const []const u8) !Options {
    if (args.len == 0) return error.MissingAction;
    const action = parseAction(args[0]) orelse return error.UnknownAction;
    if (args.len > 2) return error.DuplicateScenarioArgument;
    const scenario_slug = if (args.len == 2) blk: {
        _ = causal_run.scenarioByName(args[1]) catch |err| return err;
        break :blk args[1];
    } else null;
    return .{
        .action = action,
        .scenario_slug = scenario_slug,
    };
}

fn appendArgv(allocator: std.mem.Allocator, output: *std.ArrayList(u8), argv: []const []const u8) !void {
    for (argv, 0..) |arg, index| {
        if (index != 0) try output.appendSlice(allocator, " ");
        try output.appendSlice(allocator, arg);
    }
}

fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '"' => try output.appendSlice(allocator, "\\\""),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

fn appendJsonStringField(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    indent: []const u8,
    name: []const u8,
    value: []const u8,
    trailing_comma: bool,
) !void {
    try output.appendSlice(allocator, indent);
    try appendJsonString(allocator, output, name);
    try output.appendSlice(allocator, ": ");
    try appendJsonString(allocator, output, value);
    if (trailing_comma) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendNextAction(allocator: std.mem.Allocator, output: *std.ArrayList(u8), record: SessionRecord) !void {
    switch (record.phase) {
        .baseline_captured => {
            try output.appendSlice(allocator, "zig build causal-dev-session -- assess");
            if (!std.mem.eql(u8, record.target, "dogfood")) try output.print(allocator, " {s}", .{record.target});
        },
        .assessed => {
            try output.appendSlice(allocator, "zig build causal-remediation-decision -- local approve|reject");
            if (!std.mem.eql(u8, record.target, "dogfood")) try output.print(allocator, " {s}", .{record.target});
        },
        .failed => try output.appendSlice(allocator, "inspect failed command output and rerun the session command"),
    }
}

fn appendNextActionsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), record: SessionRecord) !void {
    try output.appendSlice(allocator, "  \"next_actions\": [\n    ");
    var action = std.ArrayList(u8).empty;
    defer action.deinit(allocator);
    try appendNextAction(allocator, &action, record);
    try appendJsonString(allocator, output, action.items);
    try output.appendSlice(allocator, "\n  ],\n");
}

fn formatSessionId(allocator: std.mem.Allocator, record: SessionRecord) ![]const u8 {
    return std.fmt.allocPrint(allocator, "zigeffect-local-{s}-{s}", .{ record.target, formatPhase(record.phase) });
}

fn sessionTitle() []const u8 {
    return "zigeffect local development session";
}

fn sessionGoal() []const u8 {
    return "Develop zigeffect locally with agent-visible causal evidence.";
}

fn zigeffectAgentStatus(record: SessionRecord) []const u8 {
    return switch (record.phase) {
        .baseline_captured => "running",
        .assessed => "done",
        .failed => "failed",
    };
}

fn zigeffectAgentTask(record: SessionRecord) []const u8 {
    return switch (record.phase) {
        .baseline_captured => "baseline captured; edit source locally",
        .assessed => "assessment complete; review audit",
        .failed => "inspect failed command output",
    };
}

fn zigeffectAgentArtifact(record: SessionRecord) []const u8 {
    return switch (record.phase) {
        .baseline_captured => record.artifacts.before_json_path,
        .assessed => record.artifacts.remediation_audit_json_path,
        .failed => record.artifacts.session_json_path,
    };
}

fn appendJsonNullField(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    indent: []const u8,
    name: []const u8,
    trailing_comma: bool,
) !void {
    try output.appendSlice(allocator, indent);
    try appendJsonString(allocator, output, name);
    try output.appendSlice(allocator, ": null");
    if (trailing_comma) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendSessionIdentityJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), record: SessionRecord) !void {
    const session_id = try formatSessionId(allocator, record);
    defer allocator.free(session_id);

    try appendJsonStringField(allocator, output, "  ", "session_id", session_id, true);
    try appendJsonStringField(allocator, output, "  ", "title", sessionTitle(), true);
    try appendJsonStringField(allocator, output, "  ", "goal", sessionGoal(), true);
}

fn appendAgentJson(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    id: []const u8,
    label: []const u8,
    kind: []const u8,
    status: []const u8,
    task: []const u8,
    artifact_path: []const u8,
    trailing_comma: bool,
) !void {
    try output.appendSlice(allocator, "    {\n");
    try appendJsonStringField(allocator, output, "      ", "id", id, true);
    try appendJsonStringField(allocator, output, "      ", "label", label, true);
    try appendJsonStringField(allocator, output, "      ", "kind", kind, true);
    try appendJsonStringField(allocator, output, "      ", "status", status, true);
    try appendJsonStringField(allocator, output, "      ", "current_task", task, true);
    if (artifact_path.len == 0) {
        try appendJsonNullField(allocator, output, "      ", "artifact_path", false);
    } else {
        try appendJsonStringField(allocator, output, "      ", "artifact_path", artifact_path, false);
    }
    try output.appendSlice(allocator, "    }");
    if (trailing_comma) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendSessionAgentsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), record: SessionRecord) !void {
    try output.appendSlice(allocator, "  \"agents\": [\n");
    try appendAgentJson(
        allocator,
        output,
        "codex",
        "Codex",
        "codex",
        "idle",
        "not attached to this receipt",
        "",
        true,
    );
    try appendAgentJson(
        allocator,
        output,
        "claude-code",
        "Claude Code",
        "claude-code",
        "idle",
        "not attached to this receipt",
        "",
        true,
    );
    try appendAgentJson(
        allocator,
        output,
        "zigeffect-tools",
        "zigeffect tools",
        "zigeffect",
        zigeffectAgentStatus(record),
        zigeffectAgentTask(record),
        zigeffectAgentArtifact(record),
        false,
    );
    try output.appendSlice(allocator, "  ],\n");
}

fn checkStatus(command: CommandRecord) []const u8 {
    return switch (command.status) {
        .ok => "pass",
        .failed => "fail",
        .skipped => "skipped",
    };
}

fn commandArtifactPath(artifacts: SessionArtifacts, command_name: []const u8) []const u8 {
    if (std.mem.indexOf(u8, command_name, "baseline") != null) return artifacts.before_json_path;
    if (std.mem.indexOf(u8, command_name, "after") != null) return artifacts.after_json_path;
    if (std.mem.eql(u8, command_name, "causal-dev-agent")) return artifacts.verdict_json_path;
    if (std.mem.eql(u8, command_name, "causal-diagnosis")) return artifacts.diagnosis_text_path;
    if (std.mem.eql(u8, command_name, "causal-remediation-plan")) return artifacts.remediation_plan_path;
    if (std.mem.eql(u8, command_name, "causal-remediation-audit")) return artifacts.remediation_audit_json_path;
    return "";
}

fn commandDetail(command: CommandRecord) []const u8 {
    if (command.stderr_snippet.len != 0) return command.stderr_snippet;
    return command.stdout_snippet;
}

fn appendSessionChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), record: SessionRecord) !void {
    try output.appendSlice(allocator, "  \"checks\": [\n");
    for (record.commands, 0..) |command, index| {
        var command_text = std.ArrayList(u8).empty;
        defer command_text.deinit(allocator);
        try appendArgv(allocator, &command_text, command.argv);

        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringField(allocator, output, "      ", "label", command.name, true);
        try appendJsonStringField(allocator, output, "      ", "command", command_text.items, true);
        try appendJsonStringField(allocator, output, "      ", "status", checkStatus(command), true);
        try appendJsonStringField(allocator, output, "      ", "detail", commandDetail(command), true);
        const artifact_path = commandArtifactPath(record.artifacts, command.name);
        if (artifact_path.len == 0) {
            try appendJsonNullField(allocator, output, "      ", "artifact_path", false);
        } else {
            try appendJsonStringField(allocator, output, "      ", "artifact_path", artifact_path, false);
        }
        try output.appendSlice(allocator, "    }");
        if (index + 1 != record.commands.len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");
}

fn formatSessionJson(allocator: std.mem.Allocator, record: SessionRecord) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonStringField(allocator, &output, "  ", "schema", record.schema, true);
    try output.print(allocator, "  \"schema_version\": {d},\n", .{record.schema_version});
    try appendJsonStringField(allocator, &output, "  ", "mode", record.mode, true);
    try appendJsonStringField(allocator, &output, "  ", "target", record.target, true);
    try appendJsonStringField(allocator, &output, "  ", "phase", formatPhase(record.phase), true);
    try appendJsonStringField(allocator, &output, "  ", "status", record.status, true);
    try appendSessionIdentityJson(allocator, &output, record);

    try output.appendSlice(allocator, "  \"commands\": [\n");
    for (record.commands, 0..) |command, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringField(allocator, &output, "      ", "name", command.name, true);
        try appendJsonStringField(allocator, &output, "      ", "status", formatCommandStatus(command.status), true);
        if (command.exit_code) |exit_code| {
            try output.print(allocator, "      \"exit_code\": {d},\n", .{exit_code});
        } else {
            try output.appendSlice(allocator, "      \"exit_code\": null,\n");
        }
        try output.appendSlice(allocator, "      \"argv\": [");
        for (command.argv, 0..) |arg, arg_index| {
            if (arg_index != 0) try output.appendSlice(allocator, ", ");
            try appendJsonString(allocator, &output, arg);
        }
        try output.appendSlice(allocator, "],\n");
        try appendJsonStringField(allocator, &output, "      ", "stdout_snippet", command.stdout_snippet, true);
        try appendJsonStringField(allocator, &output, "      ", "stderr_snippet", command.stderr_snippet, false);
        try output.appendSlice(allocator, "    }");
        if (index + 1 != record.commands.len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");
    try appendSessionChecksJson(allocator, &output, record);
    try appendSessionAgentsJson(allocator, &output, record);

    try output.appendSlice(allocator, "  \"artifacts\": {\n");
    try appendJsonStringField(allocator, &output, "    ", "session_json", record.artifacts.session_json_path, true);
    try appendJsonStringField(allocator, &output, "    ", "session_text", record.artifacts.session_text_path, true);
    try appendJsonStringField(allocator, &output, "    ", "before_json", record.artifacts.before_json_path, true);
    try appendJsonStringField(allocator, &output, "    ", "after_json", record.artifacts.after_json_path, true);
    try appendJsonStringField(allocator, &output, "    ", "verdict_json", record.artifacts.verdict_json_path, true);
    try appendJsonStringField(allocator, &output, "    ", "diagnosis_text", record.artifacts.diagnosis_text_path, true);
    try appendJsonStringField(allocator, &output, "    ", "remediation_plan", record.artifacts.remediation_plan_path, true);
    try appendJsonStringField(allocator, &output, "    ", "remediation_audit_json", record.artifacts.remediation_audit_json_path, true);
    try appendJsonStringField(allocator, &output, "    ", "remediation_audit_text", record.artifacts.remediation_audit_text_path, false);
    try output.appendSlice(allocator, "  },\n");
    try appendNextActionsJson(allocator, &output, record);
    try output.appendSlice(allocator, "  \"guardrails\": [\n");
    try output.appendSlice(allocator, "    \"source edits remain outside causal tools\",\n");
    try output.appendSlice(allocator, "    \"approval and remediation application require explicit review\"\n");
    try output.appendSlice(allocator, "  ]\n");
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

fn formatSessionText(allocator: std.mem.Allocator, record: SessionRecord) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    const session_id = try formatSessionId(allocator, record);
    defer allocator.free(session_id);

    try output.appendSlice(allocator, "zigeffect causal dev session\n");
    try output.print(allocator, "schema: {s}\n", .{record.schema});
    try output.print(allocator, "schema_version: {d}\n", .{record.schema_version});
    try output.print(allocator, "mode: {s}\n", .{record.mode});
    try output.print(allocator, "session_id: {s}\n", .{session_id});
    try output.print(allocator, "title: {s}\n", .{sessionTitle()});
    try output.print(allocator, "goal: {s}\n", .{sessionGoal()});
    try output.print(allocator, "target: {s}\n", .{record.target});
    try output.print(allocator, "phase: {s}\n", .{formatPhase(record.phase)});
    try output.print(allocator, "status: {s}\n\n", .{record.status});

    try output.appendSlice(allocator, "artifacts:\n");
    try output.print(allocator, "- session json: {s}\n", .{record.artifacts.session_json_path});
    try output.print(allocator, "- session text: {s}\n", .{record.artifacts.session_text_path});
    try output.print(allocator, "- before: {s}\n", .{record.artifacts.before_json_path});
    try output.print(allocator, "- after: {s}\n", .{record.artifacts.after_json_path});
    try output.print(allocator, "- verdict: {s}\n", .{record.artifacts.verdict_json_path});
    try output.print(allocator, "- diagnosis: {s}\n", .{record.artifacts.diagnosis_text_path});
    try output.print(allocator, "- remediation plan: {s}\n", .{record.artifacts.remediation_plan_path});
    try output.print(allocator, "- audit: {s}\n", .{record.artifacts.remediation_audit_json_path});
    try output.print(allocator, "- audit text: {s}\n\n", .{record.artifacts.remediation_audit_text_path});

    try output.appendSlice(allocator, "agents:\n");
    try output.appendSlice(allocator, "- Codex status=idle task=not attached to this receipt\n");
    try output.appendSlice(allocator, "- Claude Code status=idle task=not attached to this receipt\n");
    try output.print(
        allocator,
        "- zigeffect tools status={s} task={s} artifact={s}\n\n",
        .{ zigeffectAgentStatus(record), zigeffectAgentTask(record), zigeffectAgentArtifact(record) },
    );

    try output.appendSlice(allocator, "checks:\n");
    for (record.commands) |command| {
        try output.print(allocator, "- {s} status={s}", .{ command.name, checkStatus(command) });
        const artifact_path = commandArtifactPath(record.artifacts, command.name);
        if (artifact_path.len != 0) try output.print(allocator, " artifact={s}", .{artifact_path});
        const detail = commandDetail(command);
        if (detail.len != 0) try output.print(allocator, " detail={s}", .{detail});
        try output.append(allocator, '\n');
    }
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "commands:\n");
    for (record.commands) |command| {
        try output.print(allocator, "- {s} status={s}", .{ command.name, formatCommandStatus(command.status) });
        if (command.exit_code) |exit_code| try output.print(allocator, " exit={d}", .{exit_code});
        try output.appendSlice(allocator, " argv=`");
        try appendArgv(allocator, &output, command.argv);
        try output.appendSlice(allocator, "`\n");
        if (command.stdout_snippet.len != 0) try output.print(allocator, "  stdout: {s}\n", .{command.stdout_snippet});
        if (command.stderr_snippet.len != 0) try output.print(allocator, "  stderr: {s}\n", .{command.stderr_snippet});
    }
    try output.appendSlice(allocator, "\n");

    try output.appendSlice(allocator, "guardrails:\n");
    try output.appendSlice(allocator, "- source edits remain outside causal tools\n");
    try output.appendSlice(allocator, "- approval and remediation application require explicit review\n\n");

    switch (record.phase) {
        .baseline_captured => {
            try output.appendSlice(allocator, "next: ");
            try appendNextAction(allocator, &output, record);
            try output.append(allocator, '\n');
        },
        .assessed => {
            try output.appendSlice(allocator, "next: ");
            try appendNextAction(allocator, &output, record);
            try output.append(allocator, '\n');
        },
        .failed => {
            try output.appendSlice(allocator, "next: ");
            try appendNextAction(allocator, &output, record);
            try output.append(allocator, '\n');
        },
    }

    return output.toOwnedSlice(allocator);
}

fn copySnippet(allocator: std.mem.Allocator, value: []const u8) ![]const u8 {
    const max_len: usize = 512;
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    var last_was_space = false;
    for (value) |byte| {
        if (output.items.len >= max_len) break;
        const normalized: ?u8 = switch (byte) {
            '\n', '\r', '\t' => ' ',
            else => byte,
        };
        if (normalized == ' ') {
            if (output.items.len == 0 or last_was_space) continue;
            try output.append(allocator, ' ');
            last_was_space = true;
            continue;
        }
        try output.append(allocator, normalized.?);
        last_was_space = false;
    }

    if (output.items.len > 0 and output.items[output.items.len - 1] == ' ') {
        output.items.len -= 1;
    }
    return output.toOwnedSlice(allocator);
}

fn copyArgv(allocator: std.mem.Allocator, argv: []const []const u8) ![]const []const u8 {
    const owned = try allocator.alloc([]const u8, argv.len);
    @memcpy(owned, argv);
    return owned;
}

fn commandFailed(command: CommandRecord) bool {
    return command.status == .failed;
}

fn runCommandRecord(
    allocator: std.mem.Allocator,
    runner: Runner,
    name: []const u8,
    argv: []const []const u8,
) !CommandRecord {
    const output = try runner.run(allocator, argv);
    defer allocator.free(output.stdout);
    defer allocator.free(output.stderr);

    return .{
        .name = name,
        .argv = try copyArgv(allocator, argv),
        .status = output.status,
        .exit_code = output.exit_code,
        .stdout_snippet = try copySnippet(allocator, output.stdout),
        .stderr_snippet = try copySnippet(allocator, output.stderr),
    };
}

fn deinitCommandRecords(allocator: std.mem.Allocator, commands: []const CommandRecord) void {
    for (commands) |command| {
        allocator.free(command.argv);
        allocator.free(command.stdout_snippet);
        allocator.free(command.stderr_snippet);
    }
}

fn targetName(scenario_slug: ?[]const u8) []const u8 {
    return scenario_slug orelse "dogfood";
}

fn runStart(allocator: std.mem.Allocator, runner: Runner, scenario_slug: ?[]const u8) !SessionRecord {
    const artifacts = try sessionArtifactsForScenario(allocator, scenario_slug);
    errdefer deinitSessionArtifactsForScenario(allocator, scenario_slug, artifacts);

    var commands = std.ArrayList(CommandRecord).empty;
    errdefer {
        deinitCommandRecords(allocator, commands.items);
        commands.deinit(allocator);
    }

    const command = if (scenario_slug) |slug|
        try runCommandRecord(allocator, runner, "causal-dev-loop baseline", &.{ "zig", "build", "causal-dev-loop", "--", "baseline", slug })
    else
        try runCommandRecord(allocator, runner, "causal-dev-loop baseline", &.{ "zig", "build", "causal-dev-loop", "--", "baseline" });
    try commands.append(allocator, command);

    const failed = commandFailed(command);
    return .{
        .schema = schema_name,
        .schema_version = 1,
        .mode = "local",
        .target = targetName(scenario_slug),
        .phase = if (failed) .failed else .baseline_captured,
        .status = if (failed) "failed" else "ready-for-edit",
        .commands = try commands.toOwnedSlice(allocator),
        .artifacts = artifacts,
    };
}

fn appendAssessCommand(
    allocator: std.mem.Allocator,
    commands: *std.ArrayList(CommandRecord),
    runner: Runner,
    name: []const u8,
    argv: []const []const u8,
) !bool {
    const command = try runCommandRecord(allocator, runner, name, argv);
    try commands.append(allocator, command);
    return commandFailed(command);
}

fn runAssessWithBaselineCheck(
    allocator: std.mem.Allocator,
    runner: Runner,
    scenario_slug: ?[]const u8,
    has_baseline: bool,
) !SessionRecord {
    if (!has_baseline) return error.MissingBaselineArtifact;

    const artifacts = try sessionArtifactsForScenario(allocator, scenario_slug);
    errdefer deinitSessionArtifactsForScenario(allocator, scenario_slug, artifacts);

    var commands = std.ArrayList(CommandRecord).empty;
    errdefer {
        deinitCommandRecords(allocator, commands.items);
        commands.deinit(allocator);
    }

    var failed = false;
    if (scenario_slug) |slug| {
        failed = try appendAssessCommand(allocator, &commands, runner, "causal-dev-loop after", &.{ "zig", "build", "causal-dev-loop", "--", "after", slug });
        if (!failed) failed = try appendAssessCommand(allocator, &commands, runner, "causal-dev-agent", &.{ "zig", "build", "causal-dev-agent", "--", "local", slug });
        if (!failed) failed = try appendAssessCommand(allocator, &commands, runner, "causal-diagnosis", &.{ "zig", "build", "causal-diagnosis", "--", "local", slug });
        if (!failed) failed = try appendAssessCommand(allocator, &commands, runner, "causal-remediation-plan", &.{ "zig", "build", "causal-remediation-plan", "--", "local", slug });
        if (!failed) failed = try appendAssessCommand(allocator, &commands, runner, "causal-remediation-audit", &.{ "zig", "build", "causal-remediation-audit", "--", "local", slug });
    } else {
        failed = try appendAssessCommand(allocator, &commands, runner, "causal-dev-loop after", &.{ "zig", "build", "causal-dev-loop", "--", "after" });
        if (!failed) failed = try appendAssessCommand(allocator, &commands, runner, "causal-dev-agent", &.{ "zig", "build", "causal-dev-agent", "--", "local" });
        if (!failed) failed = try appendAssessCommand(allocator, &commands, runner, "causal-diagnosis", &.{ "zig", "build", "causal-diagnosis", "--", "local" });
        if (!failed) failed = try appendAssessCommand(allocator, &commands, runner, "causal-remediation-plan", &.{ "zig", "build", "causal-remediation-plan", "--", "local" });
        if (!failed) failed = try appendAssessCommand(allocator, &commands, runner, "causal-remediation-audit", &.{ "zig", "build", "causal-remediation-audit", "--", "local" });
    }

    return .{
        .schema = schema_name,
        .schema_version = 1,
        .mode = "local",
        .target = targetName(scenario_slug),
        .phase = if (failed) .failed else .assessed,
        .status = if (failed) "failed" else "audit-ready",
        .commands = try commands.toOwnedSlice(allocator),
        .artifacts = artifacts,
    };
}

fn missingBaselineRecord(allocator: std.mem.Allocator, scenario_slug: ?[]const u8) !SessionRecord {
    const artifacts = try sessionArtifactsForScenario(allocator, scenario_slug);
    errdefer deinitSessionArtifactsForScenario(allocator, scenario_slug, artifacts);
    return .{
        .schema = schema_name,
        .schema_version = 1,
        .mode = "local",
        .target = targetName(scenario_slug),
        .phase = .failed,
        .status = "missing-baseline",
        .commands = try allocator.alloc(CommandRecord, 0),
        .artifacts = artifacts,
    };
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn writeSessionArtifacts(io: std.Io, allocator: std.mem.Allocator, record: SessionRecord) !void {
    const json = try formatSessionJson(allocator, record);
    defer allocator.free(json);
    const text = try formatSessionText(allocator, record);
    defer allocator.free(text);
    try writeArtifact(io, record.artifacts.session_json_path, json);
    try writeArtifact(io, record.artifacts.session_text_path, text);
    std.debug.print("{s}", .{text});
}

fn artifactExists(io: std.Io, path: []const u8) !bool {
    const file = std.Io.Dir.cwd().openFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    defer file.close(io);
    return true;
}

fn readArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingSessionArtifact,
        else => return err,
    };
}

fn runStatus(init: std.process.Init, scenario_slug: ?[]const u8) !void {
    const allocator = init.gpa;
    const artifacts = try sessionArtifactsForScenario(allocator, scenario_slug);
    defer deinitSessionArtifactsForScenario(allocator, scenario_slug, artifacts);

    const text = try readArtifact(init.io, allocator, artifacts.session_text_path);
    defer allocator.free(text);
    std.debug.print("{s}", .{text});
}

fn usage() []const u8 {
    return "usage: zig build causal-dev-session -- start|assess|status [scenario]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-dev-session error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn runMain(init: std.process.Init, options: Options) !void {
    var process_runner = ProcessRunner{ .io = init.io };
    const runner = process_runner.runner();

    switch (options.action) {
        .start => {
            const record = try runStart(init.gpa, runner, options.scenario_slug);
            defer deinitSessionRecord(init.gpa, record);
            try writeSessionArtifacts(init.io, init.gpa, record);
            if (record.phase == .failed) std.process.exit(1);
        },
        .assess => {
            const artifacts = try sessionArtifactsForScenario(init.gpa, options.scenario_slug);
            defer deinitSessionArtifactsForScenario(init.gpa, options.scenario_slug, artifacts);
            if (!try artifactExists(init.io, artifacts.before_json_path)) {
                const record = try missingBaselineRecord(init.gpa, options.scenario_slug);
                defer deinitSessionRecord(init.gpa, record);
                try writeSessionArtifacts(init.io, init.gpa, record);
                failUsage(error.MissingBaselineArtifact);
            }

            const record = try runAssessWithBaselineCheck(init.gpa, runner, options.scenario_slug, true);
            defer deinitSessionRecord(init.gpa, record);
            try writeSessionArtifacts(init.io, init.gpa, record);
            if (record.phase == .failed) std.process.exit(1);
        },
        .status => try runStatus(init, options.scenario_slug),
    }
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(args[1..]) catch |err| switch (err) {
        error.MissingAction,
        error.UnknownAction,
        error.DuplicateScenarioArgument,
        error.UnknownScenario,
        => failUsage(err),
    };

    runMain(init, options) catch |err| switch (err) {
        error.MissingBaselineArtifact,
        error.MissingSessionArtifact,
        error.InvalidArtifactPath,
        => failUsage(err),
        else => return err,
    };
}

fn expectArgv(actual: []const []const u8, expected: []const []const u8) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, 0..) |expected_arg, index| {
        try std.testing.expectEqualStrings(expected_arg, actual[index]);
    }
}

test "default session paths are deterministic" {
    const paths = defaultSessionArtifacts();

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-session.json",
        paths.session_json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-session.txt",
        paths.session_text_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
        paths.before_json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
        paths.remediation_audit_json_path,
    );
}

test "scenario session paths include slug" {
    const paths = try scenarioSessionArtifacts(std.testing.allocator, "causal-scoped-fiber");
    defer deinitOwnedSessionArtifacts(std.testing.allocator, paths);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-session-causal-scoped-fiber.json",
        paths.session_json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-after.json",
        paths.after_json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.txt",
        paths.remediation_audit_text_path,
    );
}

test "session text shows next assessment command after baseline" {
    const commands = [_]CommandRecord{
        .{
            .name = "causal-dev-loop baseline",
            .argv = &.{ "zig", "build", "causal-dev-loop", "--", "baseline" },
            .status = .ok,
            .exit_code = 0,
        },
    };
    const record = SessionRecord{
        .schema = schema_name,
        .schema_version = 1,
        .mode = "local",
        .target = "dogfood",
        .phase = .baseline_captured,
        .status = "ready-for-edit",
        .commands = commands[0..],
        .artifacts = defaultSessionArtifacts(),
    };
    const report = try formatSessionText(std.testing.allocator, record);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal dev session") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "phase: baseline-captured") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "next: zig build causal-dev-session -- assess") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "source edits remain outside causal tools") != null);
}

test "assessed session text points at remediation audit and decision command" {
    const commands = [_]CommandRecord{
        .{
            .name = "causal-dev-loop after",
            .argv = &.{ "zig", "build", "causal-dev-loop", "--", "after", "causal-scoped-fiber" },
            .status = .ok,
            .exit_code = 0,
        },
        .{
            .name = "causal-remediation-audit",
            .argv = &.{ "zig", "build", "causal-remediation-audit", "--", "local", "causal-scoped-fiber" },
            .status = .ok,
            .exit_code = 0,
        },
    };
    const paths = try scenarioSessionArtifacts(std.testing.allocator, "causal-scoped-fiber");
    defer deinitOwnedSessionArtifacts(std.testing.allocator, paths);

    const record = SessionRecord{
        .schema = schema_name,
        .schema_version = 1,
        .mode = "local",
        .target = "causal-scoped-fiber",
        .phase = .assessed,
        .status = "audit-ready",
        .commands = commands[0..],
        .artifacts = paths,
    };
    const report = try formatSessionText(std.testing.allocator, record);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "target: causal-scoped-fiber") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "audit: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "next: zig build causal-remediation-decision -- local approve|reject causal-scoped-fiber") != null);
}

test "session json includes local agents and command checks" {
    const commands = [_]CommandRecord{
        .{
            .name = "causal-dev-loop after",
            .argv = &.{ "zig", "build", "causal-dev-loop", "--", "after" },
            .status = .ok,
            .exit_code = 0,
            .stdout_snippet = "after artifact captured",
        },
        .{
            .name = "causal-remediation-audit",
            .argv = &.{ "zig", "build", "causal-remediation-audit", "--", "local" },
            .status = .ok,
            .exit_code = 0,
            .stdout_snippet = "audit ready",
        },
    };
    const record = SessionRecord{
        .schema = schema_name,
        .schema_version = 1,
        .mode = "local",
        .target = "dogfood",
        .phase = .assessed,
        .status = "audit-ready",
        .commands = commands[0..],
        .artifacts = defaultSessionArtifacts(),
    };
    const json = try formatSessionJson(std.testing.allocator, record);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"session_id\": \"zigeffect-local-dogfood-assessed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"kind\": \"codex\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"id\": \"claude-code\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"id\": \"zigeffect-tools\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"checks\": [") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"label\": \"causal-dev-loop after\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\": \"pass\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"artifact_path\": \".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json\"") != null);
}

test "session text includes local agents and command checks" {
    const commands = [_]CommandRecord{
        .{
            .name = "causal-dev-loop baseline",
            .argv = &.{ "zig", "build", "causal-dev-loop", "--", "baseline" },
            .status = .ok,
            .exit_code = 0,
        },
    };
    const record = SessionRecord{
        .schema = schema_name,
        .schema_version = 1,
        .mode = "local",
        .target = "dogfood",
        .phase = .baseline_captured,
        .status = "ready-for-edit",
        .commands = commands[0..],
        .artifacts = defaultSessionArtifacts(),
    };
    const report = try formatSessionText(std.testing.allocator, record);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "agents:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "- Codex status=idle task=not attached to this receipt") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "- zigeffect tools status=running task=baseline captured; edit source locally") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "checks:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "- causal-dev-loop baseline status=pass artifact=.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json") != null);
}

test "parse options accepts start without scenario" {
    const options = try parseOptions(&.{"start"});

    try std.testing.expectEqual(SessionAction.start, options.action);
    try std.testing.expectEqual(@as(?[]const u8, null), options.scenario_slug);
}

test "parse options accepts assess with known scenario" {
    const options = try parseOptions(&.{ "assess", "causal-scoped-fiber" });

    try std.testing.expectEqual(SessionAction.assess, options.action);
    try std.testing.expectEqualStrings("causal-scoped-fiber", options.scenario_slug.?);
}

test "parse options rejects duplicate scenario arguments" {
    try std.testing.expectError(
        error.DuplicateScenarioArgument,
        parseOptions(&.{ "assess", "causal-scoped-fiber", "causal-retry-exhaustion" }),
    );
}

test "parse options rejects unknown scenarios" {
    try std.testing.expectError(error.UnknownScenario, parseOptions(&.{ "start", "unknown-scenario" }));
}

test "start runs exact baseline command" {
    var fake = FakeRunner.init(&.{
        .{ .status = .ok, .exit_code = 0, .stdout = "", .stderr = "" },
    });
    defer fake.deinit(std.testing.allocator);

    const record = try runStart(std.testing.allocator, fake.runner(), null);
    defer deinitSessionRecord(std.testing.allocator, record);

    try std.testing.expectEqual(@as(usize, 1), fake.calls.items.len);
    try expectArgv(fake.calls.items[0], &.{ "zig", "build", "causal-dev-loop", "--", "baseline" });
    try std.testing.expectEqual(SessionPhase.baseline_captured, record.phase);
    try std.testing.expectEqualStrings("ready-for-edit", record.status);
}

test "assess runs exact analysis command chain for scenario" {
    var fake = FakeRunner.init(&.{
        .{ .status = .ok, .exit_code = 0, .stdout = "", .stderr = "" },
        .{ .status = .ok, .exit_code = 0, .stdout = "", .stderr = "" },
        .{ .status = .ok, .exit_code = 0, .stdout = "", .stderr = "" },
        .{ .status = .ok, .exit_code = 0, .stdout = "", .stderr = "" },
        .{ .status = .ok, .exit_code = 0, .stdout = "", .stderr = "" },
    });
    defer fake.deinit(std.testing.allocator);

    const record = try runAssessWithBaselineCheck(std.testing.allocator, fake.runner(), "causal-scoped-fiber", true);
    defer deinitSessionRecord(std.testing.allocator, record);

    try std.testing.expectEqual(@as(usize, 5), fake.calls.items.len);
    try expectArgv(fake.calls.items[0], &.{ "zig", "build", "causal-dev-loop", "--", "after", "causal-scoped-fiber" });
    try expectArgv(fake.calls.items[1], &.{ "zig", "build", "causal-dev-agent", "--", "local", "causal-scoped-fiber" });
    try expectArgv(fake.calls.items[2], &.{ "zig", "build", "causal-diagnosis", "--", "local", "causal-scoped-fiber" });
    try expectArgv(fake.calls.items[3], &.{ "zig", "build", "causal-remediation-plan", "--", "local", "causal-scoped-fiber" });
    try expectArgv(fake.calls.items[4], &.{ "zig", "build", "causal-remediation-audit", "--", "local", "causal-scoped-fiber" });
    try std.testing.expectEqual(SessionPhase.assessed, record.phase);
    try std.testing.expectEqualStrings("audit-ready", record.status);
}

test "failed command records are included in session report" {
    var fake = FakeRunner.init(&.{
        .{ .status = .failed, .exit_code = 1, .stdout = "before stdout", .stderr = "after failed" },
    });
    defer fake.deinit(std.testing.allocator);

    const record = try runStart(std.testing.allocator, fake.runner(), null);
    defer deinitSessionRecord(std.testing.allocator, record);

    try std.testing.expectEqual(SessionPhase.failed, record.phase);
    try std.testing.expectEqualStrings("failed", record.status);

    const report = try formatSessionText(std.testing.allocator, record);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "causal-dev-loop baseline status=failed exit=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "next: inspect failed command output and rerun the session command") != null);
}

test "command output snippets are compact single-line text" {
    var fake = FakeRunner.init(&.{
        .{ .status = .failed, .exit_code = 1, .stdout = "line one\nline two", .stderr = "first\tsecond\r\nthird" },
    });
    defer fake.deinit(std.testing.allocator);

    const record = try runStart(std.testing.allocator, fake.runner(), null);
    defer deinitSessionRecord(std.testing.allocator, record);

    const report = try formatSessionText(std.testing.allocator, record);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "stdout: line one line two") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "stderr: first second third") != null);
}
