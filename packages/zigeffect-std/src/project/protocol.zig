const std = @import("std");
const Secrets = @import("../secrets/root.zig");

pub const handoff_schema = "zigeffect.agent-handoff.v1";
pub const status_schema = "zigeffect.project-status.v1";
pub const max_protocol_items: usize = 4096;

pub const ProtocolError = error{
    UnsupportedSchema,
    InvalidProtocol,
    DuplicateId,
    BrokenReference,
    LimitExceeded,
    SecretDetected,
};

pub const TaskStatus = enum { planned, active, completed, blocked };
pub const EvidenceKind = enum { source, test_result, causal_fact, artifact, approval, diagnostic };

pub const Task = struct {
    id: []const u8,
    requirement: []const u8,
    component: []const u8,
    summary: []const u8,
    status: TaskStatus = .planned,
};

pub const Evidence = struct {
    id: []const u8,
    requirement: []const u8,
    acceptance_check: ?[]const u8 = null,
    component: []const u8,
    kind: EvidenceKind,
    artifact: []const u8 = "",
    causal_event_ids: []const u64 = &.{},
    summary: []const u8,
};

pub const NextAction = struct {
    id: []const u8,
    requirement: []const u8,
    component: []const u8,
    summary: []const u8,
    command: ?[]const u8 = null,
};

pub const ProjectStatus = struct {
    schema: []const u8 = status_schema,
    project: []const u8,
    requirements_total: usize,
    requirements_open: usize,
    checks_total: usize,
    checks_pending: usize,
    checks_failed: usize,
    tasks: []const Task = &.{},
    evidence: []const Evidence = &.{},
    next_actions: []const NextAction = &.{},

    pub fn validate(self: ProjectStatus) ProtocolError!void {
        if (!std.mem.eql(u8, self.schema, status_schema)) return error.UnsupportedSchema;
        try validateCommon(self.project, self.tasks, self.evidence, self.next_actions);
        if (self.requirements_open > self.requirements_total or self.checks_pending + self.checks_failed > self.checks_total) {
            return error.InvalidProtocol;
        }
    }

    pub fn jsonAlloc(self: ProjectStatus, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        return std.json.Stringify.valueAlloc(allocator, self, .{});
    }
};

pub const AgentHandoff = struct {
    schema: []const u8 = handoff_schema,
    project: []const u8,
    provider: []const u8,
    session: []const u8,
    summary: []const u8,
    tasks: []const Task = &.{},
    evidence: []const Evidence = &.{},
    next_actions: []const NextAction = &.{},
    blockers: []const []const u8 = &.{},

    pub fn validate(self: AgentHandoff) ProtocolError!void {
        if (!std.mem.eql(u8, self.schema, handoff_schema)) return error.UnsupportedSchema;
        try validateText(self.provider);
        try validateText(self.session);
        try validateText(self.summary);
        for (self.blockers) |blocker| try validateText(blocker);
        try validateCommon(self.project, self.tasks, self.evidence, self.next_actions);
    }

    pub fn jsonAlloc(self: AgentHandoff, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        return std.json.Stringify.valueAlloc(allocator, self, .{});
    }
};

pub const ParsedHandoff = std.json.Parsed(AgentHandoff);

pub fn parseHandoff(allocator: std.mem.Allocator, input: []const u8) !ParsedHandoff {
    var parsed = try std.json.parseFromSlice(AgentHandoff, allocator, input, .{ .allocate = .alloc_always });
    errdefer parsed.deinit();
    try parsed.value.validate();
    return parsed;
}

fn validateCommon(project: []const u8, tasks: []const Task, evidence: []const Evidence, actions: []const NextAction) ProtocolError!void {
    try validateText(project);
    if (tasks.len > max_protocol_items or evidence.len > max_protocol_items or actions.len > max_protocol_items) return error.LimitExceeded;
    for (tasks, 0..) |task, index| {
        try validateText(task.id);
        try validateText(task.requirement);
        try validateText(task.component);
        try validateText(task.summary);
        for (tasks[0..index]) |previous| if (std.mem.eql(u8, previous.id, task.id)) return error.DuplicateId;
    }
    for (evidence, 0..) |item, index| {
        try validateText(item.id);
        try validateText(item.requirement);
        try validateText(item.component);
        try validateText(item.summary);
        if (item.acceptance_check) |check| try validateText(check);
        if (item.artifact.len != 0) try validateText(item.artifact);
        for (evidence[0..index]) |previous| if (std.mem.eql(u8, previous.id, item.id)) return error.DuplicateId;
    }
    for (actions, 0..) |action, index| {
        try validateText(action.id);
        try validateText(action.requirement);
        try validateText(action.component);
        try validateText(action.summary);
        if (action.command) |command| try validateText(command);
        for (actions[0..index]) |previous| if (std.mem.eql(u8, previous.id, action.id)) return error.DuplicateId;
    }
}

fn validateText(value: []const u8) ProtocolError!void {
    if (value.len == 0) return error.InvalidProtocol;
    if (Secrets.containsSecret(value)) return error.SecretDetected;
}

test "agent handoff round trips provider-neutral tasks evidence and actions" {
    const handoff = AgentHandoff{
        .project = "billing-system",
        .provider = "codex",
        .session = "session-42",
        .summary = "implemented typed invoice validation",
        .tasks = &.{.{ .id = "task-invoice", .requirement = "req-invoice", .component = "api", .summary = "validate invoice", .status = .completed }},
        .evidence = &.{.{ .id = "evidence-test", .requirement = "req-invoice", .acceptance_check = "check-invoice", .component = "api", .kind = .test_result, .artifact = ".zigeffect/receipts/check.json", .causal_event_ids = &.{ 41, 42 }, .summary = "tests passed" }},
        .next_actions = &.{.{ .id = "next-review", .requirement = "req-invoice", .component = "api", .summary = "review migration", .command = "check" }},
    };
    const json = try handoff.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    var parsed = try parseHandoff(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expectEqualStrings("codex", parsed.value.provider);
    try std.testing.expectEqual(@as(usize, 2), parsed.value.evidence[0].causal_event_ids.len);
}

test "agent protocol rejects unknown versions duplicates limits and secrets" {
    var unknown = AgentHandoff{ .schema = "zigeffect.agent-handoff.v9", .project = "app", .provider = "claude", .session = "one", .summary = "done" };
    try std.testing.expectError(error.UnsupportedSchema, unknown.validate());
    unknown.schema = handoff_schema;
    unknown.tasks = &.{
        .{ .id = "same", .requirement = "req", .component = "app", .summary = "one" },
        .{ .id = "same", .requirement = "req", .component = "app", .summary = "two" },
    };
    try std.testing.expectError(error.DuplicateId, unknown.validate());

    const secret = AgentHandoff{ .project = "app", .provider = "codex", .session = "one", .summary = "authorization: Bearer sentinel-secret-for-tests" };
    try std.testing.expectError(error.SecretDetected, secret.validate());

    const too_many = try std.testing.allocator.alloc(Task, max_protocol_items + 1);
    defer std.testing.allocator.free(too_many);
    const limited = AgentHandoff{ .project = "app", .provider = "codex", .session = "one", .summary = "bounded", .tasks = too_many };
    try std.testing.expectError(error.LimitExceeded, limited.validate());
    try std.testing.expectError(error.SyntaxError, parseHandoff(std.testing.allocator, "{not-json"));
}
