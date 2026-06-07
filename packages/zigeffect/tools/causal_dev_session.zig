const std = @import("std");
const causal_run = @import("causal_run");

const schema_name = "zigeffect.causal.dev-session.v1";

const SessionPhase = enum {
    baseline_captured,
    assessed,
    failed,
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

fn appendArgv(allocator: std.mem.Allocator, output: *std.ArrayList(u8), argv: []const []const u8) !void {
    for (argv, 0..) |arg, index| {
        if (index != 0) try output.appendSlice(allocator, " ");
        try output.appendSlice(allocator, arg);
    }
}

fn formatSessionText(allocator: std.mem.Allocator, record: SessionRecord) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal dev session\n");
    try output.print(allocator, "schema: {s}\n", .{record.schema});
    try output.print(allocator, "schema_version: {d}\n", .{record.schema_version});
    try output.print(allocator, "mode: {s}\n", .{record.mode});
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

    try output.appendSlice(allocator, "commands:\n");
    for (record.commands) |command| {
        try output.print(allocator, "- {s} status={s}", .{ command.name, formatCommandStatus(command.status) });
        if (command.exit_code) |exit_code| try output.print(allocator, " exit={d}", .{exit_code});
        try output.appendSlice(allocator, " argv=`");
        try appendArgv(allocator, &output, command.argv);
        try output.appendSlice(allocator, "`\n");
    }
    try output.appendSlice(allocator, "\n");

    try output.appendSlice(allocator, "guardrails:\n");
    try output.appendSlice(allocator, "- source edits remain outside causal tools\n");
    try output.appendSlice(allocator, "- approval and remediation application require explicit review\n\n");

    switch (record.phase) {
        .baseline_captured => {
            try output.appendSlice(allocator, "next: zig build causal-dev-session -- assess");
            if (!std.mem.eql(u8, record.target, "dogfood")) try output.print(allocator, " {s}", .{record.target});
            try output.appendSlice(allocator, "\n");
        },
        .assessed => {
            try output.appendSlice(allocator, "next: zig build causal-remediation-decision -- local approve|reject");
            if (!std.mem.eql(u8, record.target, "dogfood")) try output.print(allocator, " {s}", .{record.target});
            try output.appendSlice(allocator, "\n");
        },
        .failed => {
            try output.appendSlice(allocator, "next: inspect failed command output and rerun the session command\n");
        },
    }

    return output.toOwnedSlice(allocator);
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
