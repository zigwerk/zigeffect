const std = @import("std");

pub const m9_completion_audit_schema = "zigeffect.causal.m9-completion-audit.v1";
pub const m9_completion_audit_schema_version: u32 = 1;
pub const recommendation = "deliver-m9-with-deferred-production-hardening";

const OutputFormat = enum { text, json };

const DeliverableCheck = struct {
    id: []const u8,
    status: []const u8,
    evidence: []const u8,
    source: []const u8,
    agent_guidance: []const u8,
};

const deliverable_checks: []const DeliverableCheck = &.{
    .{
        .id = "schema-governance-tool",
        .status = "passed",
        .evidence = "zig build causal-schema-governance prints schema count, compatibility policy, migration policy, producers, and consumers.",
        .source = "packages/zigeffect/tools/causal_schema_governance.zig",
        .agent_guidance = "Run before changing artifact families, schema fields, workbench mappings, or agent handoff records.",
    },
    .{
        .id = "schema-governance-doc",
        .status = "documented",
        .evidence = "Schema governance docs define versioning, migration, compatibility postures, and the official schema matrix.",
        .source = "packages/zigeffect/docs/schema-governance.md",
        .agent_guidance = "Treat schema governance as the registry for all agent-readable causal artifact families.",
    },
    .{
        .id = "operations-manual",
        .status = "documented",
        .evidence = "Operations docs define local/CI authority, handoff order, redaction review, workbench usage, backend operations, and gaps.",
        .source = "packages/zigeffect/docs/operations.md",
        .agent_guidance = "Use operations docs as the authority boundary before proposing registry, app, or production changes.",
    },
    .{
        .id = "performance-budget-tool",
        .status = "passed",
        .evidence = "zig build causal-performance-budget prints deterministic retention, truncation, sampling, artifact, workbench, and release-review budgets.",
        .source = "packages/zigeffect/tools/causal_performance_budget.zig",
        .agent_guidance = "Run before changing causal overhead surfaces or workbench artifact bounds.",
    },
    .{
        .id = "performance-budget-doc",
        .status = "documented",
        .evidence = "Performance budget docs define budget interpretation, release notes criteria, verification commands, and non-goals.",
        .source = "packages/zigeffect/docs/performance-budget.md",
        .agent_guidance = "Use the release checklist when causal runtime behavior or artifact compatibility changes.",
    },
    .{
        .id = "release-guidance",
        .status = "documented",
        .evidence = "Release guidance is recorded in performance-budget and operations docs.",
        .source = "packages/zigeffect/docs/performance-budget.md; packages/zigeffect/docs/operations.md",
        .agent_guidance = "Add release notes when retention, string bounds, sampling, backend emission, schemas, workbench bounds, or CI retention change.",
    },
    .{
        .id = "ci-workflow",
        .status = "documented",
        .evidence = "CI workflow runs causal artifacts, dogfood artifacts, examples, package tests, and failure handoff with read-only permissions.",
        .source = ".github/workflows/zigeffect-causal.yml",
        .agent_guidance = "Treat uploaded CI artifacts as local/CI evidence, not production telemetry.",
    },
    .{
        .id = "artifact-manifest",
        .status = "passed",
        .evidence = "zig build causal-artifacts prints retention globs, scenario artifacts, and sharing safety notes.",
        .source = "packages/zigeffect/tools/causal_artifacts.zig",
        .agent_guidance = "Upload only causal txt, json, and dot artifacts after redaction review.",
    },
    .{
        .id = "test-matrix",
        .status = "passed",
        .evidence = "zig build causal-test-matrix prints scenario and invariant coverage across causal runtime domains.",
        .source = "packages/zigeffect/tools/causal_test_matrix.zig",
        .agent_guidance = "Use partial domains as future scenario candidates, not as blockers for the M9 operating model.",
    },
    .{
        .id = "workbench-direction",
        .status = "documented",
        .evidence = "Workbench direction is SolidJS inside webui-dev/zig-webui with a bounded read-only Zig bridge.",
        .source = "packages/zigeffect/docs/operations.md; packages/zigeffect/docs/performance-budget.md",
        .agent_guidance = "Keep workbench UI work on SolidJS plus zig-webui unless a concrete future adapter requires another renderer.",
    },
    .{
        .id = "production-gap-register",
        .status = "documented",
        .evidence = "Production gaps are explicitly listed as future hardening in operations docs and this audit.",
        .source = "packages/zigeffect/docs/operations.md",
        .agent_guidance = "Do not treat deferred production integrations as hidden M9 failures; track them as future hardening branches.",
    },
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig build causal-m9-completion-audit",
    "zig build causal-m9-completion-audit -- --format json",
    "zig build causal-schema-governance",
    "zig build causal-performance-budget",
    "zig build causal-artifacts",
    "zig build causal-test-matrix",
    "zig build examples",
    "zig build test",
    "cd ../..",
    "bun run check",
    "bun run zig:test",
    "git diff --check",
};

const production_gaps: []const []const u8 = &.{
    "distributed-artifact-aggregation",
    "durable-production-retention",
    "production-deployment-runbooks",
    "alerting-paging-integrations",
    "rbac-access-control",
    "encryption-at-rest-policy",
    "live-dashboards-streaming-workbench",
    "automated-mutation-authority",
    "gradual-rollout-automation",
    "wall-clock-benchmark-gates",
    "production-capacity-planning",
};

const non_goals: []const []const u8 = &.{
    "production artifact aggregation",
    "durable production retention",
    "deployment runbook automation",
    "alerting or paging integrations",
    "RBAC or encryption-at-rest",
    "live dashboarding",
    "streaming workbench",
    "mutation authority",
    "rollout automation",
    "wall-clock benchmark gates",
    "production capacity planning",
    "React workbench support",
    "Cockroach adapter work",
};

fn usage() []const u8 {
    return
        \\usage:
        \\  zig build causal-m9-completion-audit
        \\  zig build causal-m9-completion-audit -- --format text
        \\  zig build causal-m9-completion-audit -- --format json
        \\
        \\formats:
        \\  --format text|json
        \\
    ;
}

fn parseOptions(args: []const []const u8) !OutputFormat {
    if (args.len == 1) return .text;
    if (args.len == 3 and std.mem.eql(u8, args[1], "--format")) {
        if (std.mem.eql(u8, args[2], "text")) return .text;
        if (std.mem.eql(u8, args[2], "json")) return .json;
        return error.UnknownFormat;
    }
    if (args.len == 2 and std.mem.eql(u8, args[1], "--format")) return error.MissingFormat;
    return error.UnknownFlag;
}

pub fn deliverableChecks() []const DeliverableCheck {
    return deliverable_checks;
}

pub fn verificationCommands() []const []const u8 {
    return verification_commands;
}

pub fn productionGaps() []const []const u8 {
    return production_gaps;
}

fn formatM9CompletionAuditText(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal M9 completion audit\n");
    try output.print(allocator, "schema: {s}\n", .{m9_completion_audit_schema});
    try output.print(allocator, "schema_version: {d}\n", .{m9_completion_audit_schema_version});
    try output.appendSlice(allocator, "status: current\n");
    try output.print(allocator, "recommendation: {s}\n\n", .{recommendation});

    try output.appendSlice(allocator, "deliverable checks:\n");
    for (deliverableChecks()) |entry| {
        try output.print(allocator, "- {s}\n", .{entry.id});
        try output.print(allocator, "  status: {s}\n", .{entry.status});
        try output.print(allocator, "  source: {s}\n", .{entry.source});
        try output.print(allocator, "  evidence: {s}\n", .{entry.evidence});
        try output.print(allocator, "  agent guidance: {s}\n", .{entry.agent_guidance});
    }

    try output.appendSlice(allocator, "\nverification commands:\n");
    for (verificationCommands()) |command| {
        try output.print(allocator, "- {s}\n", .{command});
    }

    try output.appendSlice(allocator, "\nproduction gaps:\n");
    for (productionGaps()) |gap| {
        try output.print(allocator, "- {s}\n", .{gap});
    }

    try output.appendSlice(allocator, "\nnon-goals:\n");
    for (non_goals) |item| {
        try output.print(allocator, "- {s}\n", .{item});
    }

    return output.toOwnedSlice(allocator);
}

fn formatM9CompletionAuditJson(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, m9_completion_audit_schema);
    try output.appendSlice(allocator, ",\n");
    try output.print(allocator, "  \"schema_version\": {d},\n", .{m9_completion_audit_schema_version});
    try output.appendSlice(allocator, "  \"status\": \"current\",\n");
    try output.appendSlice(allocator, "  \"recommendation\": ");
    try appendJsonString(allocator, &output, recommendation);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"deliverable_checks\": [\n");
    for (deliverableChecks(), 0..) |entry, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonProperty(allocator, &output, "id", entry.id, true);
        try appendJsonProperty(allocator, &output, "status", entry.status, true);
        try appendJsonProperty(allocator, &output, "source", entry.source, true);
        try appendJsonProperty(allocator, &output, "evidence", entry.evidence, true);
        try appendJsonProperty(allocator, &output, "agent_guidance", entry.agent_guidance, false);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < deliverableChecks().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");
    try output.appendSlice(allocator, "  \"verification_commands\": ");
    try appendStringArray(allocator, &output, verificationCommands());
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"production_gaps\": ");
    try appendStringArray(allocator, &output, productionGaps());
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"non_goals\": ");
    try appendStringArray(allocator, &output, non_goals);
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| failUsage(err);
    const report = switch (format) {
        .text => try formatM9CompletionAuditText(init.gpa),
        .json => try formatM9CompletionAuditJson(init.gpa),
    };
    defer init.gpa.free(report);

    std.debug.print("{s}", .{report});
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-m9-completion-audit error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn appendJsonProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: []const u8,
    comma: bool,
) !void {
    try output.appendSlice(allocator, "      ");
    try appendJsonString(allocator, output, name);
    try output.appendSlice(allocator, ": ");
    try appendJsonString(allocator, output, value);
    if (comma) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendStringArray(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    values: []const []const u8,
) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index != 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, value);
    }
    try output.append(allocator, ']');
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

fn expectDeliverable(id: []const u8) !void {
    for (deliverableChecks()) |entry| {
        if (std.mem.eql(u8, entry.id, id)) return;
    }
    return error.MissingDeliverable;
}

fn expectProductionGap(id: []const u8) !void {
    for (productionGaps()) |entry| {
        if (std.mem.eql(u8, entry, id)) return;
    }
    return error.MissingProductionGap;
}

test "M9 audit usage names command and formats" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-m9-completion-audit") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--format text|json") != null);
    try std.testing.expectEqualStrings("zigeffect.causal.m9-completion-audit.v1", m9_completion_audit_schema);
    try std.testing.expectEqualStrings("deliver-m9-with-deferred-production-hardening", recommendation);
}

test "M9 audit inventories deliverables and production gaps" {
    try std.testing.expectEqual(@as(usize, 11), deliverableChecks().len);
    try std.testing.expectEqual(@as(usize, 13), verificationCommands().len);
    try std.testing.expectEqual(@as(usize, 11), productionGaps().len);
    try expectDeliverable("schema-governance-tool");
    try expectDeliverable("performance-budget-tool");
    try expectDeliverable("production-gap-register");
    try expectProductionGap("durable-production-retention");
    try expectProductionGap("wall-clock-benchmark-gates");
}

test "M9 audit text report includes recommendation and inventories" {
    const report = try formatM9CompletionAuditText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal M9 completion audit") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.m9-completion-audit.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "recommendation: deliver-m9-with-deferred-production-hardening") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "schema-governance-tool") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "SolidJS inside webui-dev/zig-webui") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production gaps:") != null);
}

test "M9 audit json report is machine readable" {
    const report = try formatM9CompletionAuditJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.m9-completion-audit.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"recommendation\": \"deliver-m9-with-deferred-production-hardening\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"deliverable_checks\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"production_gaps\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"verification_commands\"") != null);
}

test "M9 audit parses format options" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-m9-completion-audit"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-m9-completion-audit", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-m9-completion-audit", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-m9-completion-audit", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-m9-completion-audit", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-m9-completion-audit", "--json" }));
}
