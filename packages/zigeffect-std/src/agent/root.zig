const std = @import("std");
const Json = @import("../json/root.zig");
const Jsonl = @import("../jsonl/root.zig");
const Process = @import("../process/root.zig");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const Event = struct {
    sequence: u64,
    agent: []const u8,
    kind: []const u8,
    detail: []const u8,
};

pub const RunReceipt = struct {
    agent: []const u8,
    workspace: []const u8,
    status: []const u8,
};

pub const AgentKind = enum {
    codex,
    claude_code,
    zigeffect,
    human,
    other,
};

pub const AgentStatus = enum {
    idle,
    running,
    reviewing,
    blocked,
    done,
    failed,
};

pub const CheckStatus = enum {
    pending,
    running,
    pass,
    fail,
    warning,
};

pub const AgentStatusEvent = struct {
    agent_id: []const u8,
    agent_kind: AgentKind,
    agent_label: []const u8,
    status: AgentStatus,
    task: []const u8 = "",
    artifact_path: []const u8 = "",
};

pub const CheckEvent = struct {
    label: []const u8,
    command: []const u8 = "",
    status: CheckStatus,
    detail: []const u8 = "",
    artifact_path: []const u8 = "",
};

pub const AdapterSpec = struct {
    id: []const u8,
    kind: AgentKind,
    label: []const u8,
    task: []const u8,
    cwd: []const u8,
    argv_storage: [8][]const u8,
    argv_len: usize,

    pub fn command(self: *const AdapterSpec) Process.Command {
        return .{
            .argv = self.argv_storage[0..self.argv_len],
            .cwd = self.cwd,
        };
    }
};

pub const RunSummary = struct {
    agent_id: []const u8,
    status: []const u8,
    receipt_json: []const u8,

    pub fn deinit(self: *RunSummary, allocator: std.mem.Allocator) void {
        allocator.free(self.receipt_json);
        self.* = undefined;
    }
};

pub const Session = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    workspace: []const u8,
    next_sequence: u64 = 1,
    feed: std.ArrayList(u8) = .empty,

    pub fn init(allocator: std.mem.Allocator, id: []const u8, workspace: []const u8) Session {
        return .{
            .allocator = allocator,
            .id = id,
            .workspace = workspace,
        };
    }

    pub fn deinit(self: *Session) void {
        self.feed.deinit(self.allocator);
    }

    pub fn feedText(self: *const Session) []const u8 {
        return self.feed.items;
    }

    fn takeSequence(self: *Session) std.mem.Allocator.Error![]const u8 {
        const sequence = self.next_sequence;
        self.next_sequence += 1;
        return std.fmt.allocPrint(self.allocator, "{d}", .{sequence});
    }

    fn appendJsonFields(self: *Session, fields: []const Json.Field) std.mem.Allocator.Error!void {
        const event_json = try Json.objectFromFieldsAlloc(self.allocator, fields);
        defer self.allocator.free(event_json);
        try self.feed.appendSlice(self.allocator, event_json);
        try self.feed.append(self.allocator, '\n');
    }

    pub fn recordAgentStatus(self: *Session, event: AgentStatusEvent) std.mem.Allocator.Error!void {
        const sequence = try self.takeSequence();
        defer self.allocator.free(sequence);

        const fields = [_]Json.Field{
            .{ .name = "sequence", .value = sequence },
            .{ .name = "kind", .value = "agent_status" },
            .{ .name = "agent_id", .value = event.agent_id },
            .{ .name = "agent_kind", .value = agentKindName(event.agent_kind) },
            .{ .name = "agent_label", .value = event.agent_label },
            .{ .name = "status", .value = agentStatusName(event.status) },
            .{ .name = "task", .value = event.task },
            .{ .name = "artifact_path", .value = event.artifact_path },
        };
        try self.appendJsonFields(fields[0..]);
    }

    pub fn recordCheck(self: *Session, event: CheckEvent) std.mem.Allocator.Error!void {
        const sequence = try self.takeSequence();
        defer self.allocator.free(sequence);

        const fields = [_]Json.Field{
            .{ .name = "sequence", .value = sequence },
            .{ .name = "kind", .value = "check_result" },
            .{ .name = "label", .value = event.label },
            .{ .name = "command", .value = event.command },
            .{ .name = "status", .value = checkStatusName(event.status) },
            .{ .name = "detail", .value = event.detail },
            .{ .name = "artifact_path", .value = event.artifact_path },
        };
        try self.appendJsonFields(fields[0..]);
    }

    pub fn linkArtifact(self: *Session, key: []const u8, path: []const u8) std.mem.Allocator.Error!void {
        const sequence = try self.takeSequence();
        defer self.allocator.free(sequence);

        const fields = [_]Json.Field{
            .{ .name = "sequence", .value = sequence },
            .{ .name = "kind", .value = "artifact_link" },
            .{ .name = "key", .value = key },
            .{ .name = "path", .value = path },
        };
        try self.appendJsonFields(fields[0..]);
    }

    pub fn recordNextAction(self: *Session, value: []const u8) std.mem.Allocator.Error!void {
        try self.recordValueEvent("next_action", value);
    }

    pub fn recordGuardrail(self: *Session, value: []const u8) std.mem.Allocator.Error!void {
        try self.recordValueEvent("guardrail", value);
    }

    pub fn recordWarning(self: *Session, value: []const u8) std.mem.Allocator.Error!void {
        try self.recordValueEvent("warning", value);
    }

    fn recordValueEvent(self: *Session, kind: []const u8, value: []const u8) std.mem.Allocator.Error!void {
        const sequence = try self.takeSequence();
        defer self.allocator.free(sequence);

        const fields = [_]Json.Field{
            .{ .name = "sequence", .value = sequence },
            .{ .name = "kind", .value = kind },
            .{ .name = "value", .value = value },
        };
        try self.appendJsonFields(fields[0..]);
    }
};

pub fn eventJsonAlloc(allocator: std.mem.Allocator, event: Event) ![]const u8 {
    const sequence = try std.fmt.allocPrint(allocator, "{d}", .{event.sequence});
    defer allocator.free(sequence);

    const fields = [_]Json.Field{
        .{ .name = "sequence", .value = sequence },
        .{ .name = "agent", .value = event.agent },
        .{ .name = "kind", .value = event.kind },
        .{ .name = "detail", .value = event.detail },
    };
    return Json.objectFromFieldsAlloc(allocator, fields[0..]);
}

pub fn appendEventJsonlAlloc(
    allocator: std.mem.Allocator,
    feed: []const u8,
    event: Event,
) ![]const u8 {
    const event_json = try eventJsonAlloc(allocator, event);
    defer allocator.free(event_json);
    return Jsonl.appendRecordAlloc(allocator, feed, event_json);
}

pub fn receiptJsonAlloc(allocator: std.mem.Allocator, receipt: RunReceipt) ![]const u8 {
    const fields = [_]Json.Field{
        .{ .name = "agent", .value = receipt.agent },
        .{ .name = "workspace", .value = receipt.workspace },
        .{ .name = "status", .value = receipt.status },
    };
    return Json.objectFromFieldsAlloc(allocator, fields[0..]);
}

pub fn agentKindName(kind: AgentKind) []const u8 {
    return switch (kind) {
        .codex => "codex",
        .claude_code => "claude-code",
        .zigeffect => "zigeffect",
        .human => "human",
        .other => "other",
    };
}

pub fn agentStatusName(status: AgentStatus) []const u8 {
    return @tagName(status);
}

pub fn checkStatusName(status: CheckStatus) []const u8 {
    return @tagName(status);
}

pub fn codexAdapter(id: []const u8, cwd: []const u8, task: []const u8) AdapterSpec {
    return .{
        .id = id,
        .kind = .codex,
        .label = "Codex",
        .task = task,
        .cwd = cwd,
        .argv_storage = .{ "codex", "exec", task, "", "", "", "", "" },
        .argv_len = 3,
    };
}

pub fn claudeCodeAdapter(id: []const u8, cwd: []const u8, task: []const u8) AdapterSpec {
    return .{
        .id = id,
        .kind = .claude_code,
        .label = "Claude Code",
        .task = task,
        .cwd = cwd,
        .argv_storage = .{ "claude", "-p", task, "", "", "", "", "" },
        .argv_len = 3,
    };
}

pub fn localProcessAdapter(
    id: []const u8,
    label: []const u8,
    cwd: []const u8,
    argv: []const []const u8,
) error{TooManyArguments}!AdapterSpec {
    var argv_storage = [_][]const u8{ "", "", "", "", "", "", "", "" };
    if (argv.len > argv_storage.len) return error.TooManyArguments;
    const argv_len = argv.len;
    for (argv[0..argv_len], 0..) |arg, index| {
        argv_storage[index] = arg;
    }
    return .{
        .id = id,
        .kind = .other,
        .label = label,
        .task = label,
        .cwd = cwd,
        .argv_storage = argv_storage,
        .argv_len = argv_len,
    };
}

pub fn RunAgentEffect(comptime EffectEnv: type, comptime Runner: type) type {
    return struct {
        pub const SuccessType = RunSummary;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{ Session, Runner };

        adapter: AdapterSpec,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!RunSummary {
            const session = ctx.service(Session);
            const runner = ctx.service(Runner);

            try session.recordAgentStatus(.{
                .agent_id = self.adapter.id,
                .agent_kind = self.adapter.kind,
                .agent_label = self.adapter.label,
                .status = .running,
                .task = self.adapter.task,
            });

            const command = self.adapter.command();
            var output = runner.runOutputAlloc(ctx.allocator, command) catch |err| {
                _ = session.recordAgentStatus(.{
                    .agent_id = self.adapter.id,
                    .agent_kind = self.adapter.kind,
                    .agent_label = self.adapter.label,
                    .status = .failed,
                    .task = @errorName(err),
                }) catch {};
                _ = StdService.recordOperation(ctx, Session, "agent.run", "failure", self.adapter.id);
                return err;
            };
            defer output.deinit(ctx.allocator);

            const status: []const u8 = if (output.receipt.exit_code == 0) "success" else "failure";
            try session.recordCheck(.{
                .label = self.adapter.label,
                .command = output.receipt.command,
                .status = if (output.receipt.exit_code == 0) .pass else .fail,
                .detail = output.stdout,
            });
            try session.recordAgentStatus(.{
                .agent_id = self.adapter.id,
                .agent_kind = self.adapter.kind,
                .agent_label = self.adapter.label,
                .status = if (output.receipt.exit_code == 0) .done else .failed,
                .task = self.adapter.task,
            });

            const receipt_json = try receiptJsonAlloc(ctx.allocator, .{
                .agent = self.adapter.id,
                .workspace = session.workspace,
                .status = status,
            });
            errdefer ctx.allocator.free(receipt_json);

            _ = StdService.recordOperation(ctx, Session, "agent.run", status, self.adapter.id);
            return .{
                .agent_id = self.adapter.id,
                .status = status,
                .receipt_json = receipt_json,
            };
        }
    };
}

pub fn runAgentEffect(comptime EffectEnv: type, comptime Runner: type, adapter: AdapterSpec) RunAgentEffect(EffectEnv, Runner) {
    return .{ .adapter = adapter };
}

test "Agent formats local session events as redacted JSONL" {
    const event = Event{
        .sequence = 7,
        .agent = "codex",
        .kind = "process_output",
        .detail = "token=abc123",
    };

    const feed = try appendEventJsonlAlloc(std.testing.allocator, "", event);
    defer std.testing.allocator.free(feed);

    try std.testing.expect(std.mem.indexOf(u8, feed, "token=abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, feed, "[REDACTED]") != null);
    try std.testing.expect(std.mem.endsWith(u8, feed, "\n"));
}

test "Agent run receipt includes agent workspace and status" {
    const receipt = try receiptJsonAlloc(std.testing.allocator, .{
        .agent = "claude-code",
        .workspace = "/repo",
        .status = "success",
    });
    defer std.testing.allocator.free(receipt);

    try std.testing.expect(std.mem.indexOf(u8, receipt, "\"agent\":\"claude-code\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "\"workspace\":\"/repo\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "\"status\":\"success\"") != null);
}

test "Agent Session records workbench-compatible redacted events" {
    var session = Session.init(std.testing.allocator, "local-dev", "/repo");
    defer session.deinit();

    try session.recordAgentStatus(.{
        .agent_id = "codex",
        .agent_kind = .codex,
        .agent_label = "Codex",
        .status = .running,
        .task = "editing token=abc123",
    });
    try session.recordCheck(.{
        .label = "std tests",
        .command = "bun run zigeffect:std:test",
        .status = .pass,
        .detail = "19 pass",
    });
    try session.linkArtifact("m10-plan", "docs/superpowers/plans/2026-06-25-zigeffect-std-agent-toolkit.md");
    try session.recordGuardrail("no raw secrets in workbench payloads");

    const feed = session.feedText();
    try std.testing.expect(std.mem.indexOf(u8, feed, "\"kind\":\"agent_status\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, feed, "\"agent_kind\":\"codex\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, feed, "\"kind\":\"check_result\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, feed, "\"kind\":\"artifact_link\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, feed, "\"kind\":\"guardrail\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, feed, "abc123") == null);
}

test "Agent builds Codex and Claude Code process commands" {
    const codex = codexAdapter("codex-build", "/repo", "implement std");
    const codex_command = codex.command();
    try std.testing.expectEqualStrings("codex", codex_command.argv[0]);
    try std.testing.expectEqualStrings("exec", codex_command.argv[1]);
    try std.testing.expectEqualStrings("implement std", codex_command.argv[2]);
    try std.testing.expectEqualStrings("/repo", codex_command.cwd);

    const claude = claudeCodeAdapter("claude-review", "/repo", "review changes");
    const claude_command = claude.command();
    try std.testing.expectEqualStrings("claude", claude_command.argv[0]);
    try std.testing.expectEqualStrings("-p", claude_command.argv[1]);
    try std.testing.expectEqualStrings("review changes", claude_command.argv[2]);

    const local = try localProcessAdapter("local", "Local Tool", "/repo", &.{ "zig", "build", "test" });
    const local_command = local.command();
    try std.testing.expectEqualStrings("zig", local_command.argv[0]);
    try std.testing.expectEqualStrings("build", local_command.argv[1]);
    try std.testing.expectEqualStrings("test", local_command.argv[2]);
}

test "Agent runAgentEffect executes process runner and records session plus causal facts" {
    const zstd = @import("../root.zig");

    var session = Session.init(std.testing.allocator, "session-1", "/repo");
    defer session.deinit();
    var runner = zstd.Process.FakeRunner.init(.{
        .exit_code = 0,
        .stdout = "ok token=abc123",
        .stderr = "",
    });

    var provider = zstd.Service.Provider(.{ Session, zstd.Process.FakeRunner }).init(.{ &session, &runner });
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{ Session, zstd.Process.FakeRunner })
        .withCausalStore(&store);

    var summary = try runtime.run(runAgentEffect(@TypeOf(provider), zstd.Process.FakeRunner, codexAdapter("codex", "/repo", "test")));
    defer summary.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("success", summary.status);
    try std.testing.expect(std.mem.indexOf(u8, session.feedText(), "\"status\":\"running\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, session.feedText(), "\"status\":\"done\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, session.feedText(), "abc123") == null);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(zstd.Service.hasOperation(snapshot, Session, "agent.run", "success"));
}
