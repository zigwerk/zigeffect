const std = @import("std");
const causal_run = @import("causal_run");

const Options = struct {
    mode: []const u8,
    scenario_slug: ?[]const u8 = null,
};

const Recommendation = enum {
    add_scenario,
    refine_scenario,
    none,
};

const RecommendationInput = struct {
    scenario_slug: ?[]const u8,
    verdict_status: []const u8,
    actions: usize,
    new_actions: usize,
    persisting_actions: usize,
    audit_chain_assessment: []const u8,
    persisting_event_ids: []const u64,
    appeared_event_ids: []const u64,
};

fn defaultScenarioProposalJsonPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-scenario-proposal.json";
}

fn defaultScenarioProposalTextPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-scenario-proposal.txt";
}

fn scenarioScenarioProposalJsonPath(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-scenario-proposal.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn scenarioScenarioProposalTextPath(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-scenario-proposal.txt",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn parseOptions(args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingMode;
    if (!std.mem.eql(u8, args[1], "local")) return error.UnknownMode;
    if (args.len > 3) return error.DuplicateScenarioArgument;

    const scenario_slug = if (args.len == 3) blk: {
        _ = try causal_run.scenarioByName(args[2]);
        break :blk args[2];
    } else null;

    return .{ .mode = "local", .scenario_slug = scenario_slug };
}

fn chooseRecommendation(input: RecommendationInput) Recommendation {
    const has_new_evidence =
        input.new_actions > 0 or
        input.appeared_event_ids.len > 0 or
        std.mem.eql(u8, input.audit_chain_assessment, "regressed");
    const has_persisting_evidence =
        input.persisting_actions > 0 or
        input.persisting_event_ids.len > 0 or
        std.mem.eql(u8, input.audit_chain_assessment, "unchanged");
    const has_action_evidence =
        input.actions > 0 or
        !std.mem.eql(u8, input.verdict_status, "clear");

    if (!has_new_evidence and !has_persisting_evidence and !has_action_evidence) return .none;
    return if (input.scenario_slug == null) .add_scenario else .refine_scenario;
}

test "scenario proposal default and scenario paths are deterministic" {
    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-scenario-proposal.json",
        defaultScenarioProposalJsonPath(),
    );
    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-scenario-proposal.txt",
        defaultScenarioProposalTextPath(),
    );

    const json = try scenarioScenarioProposalJsonPath(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(json);
    const text = try scenarioScenarioProposalTextPath(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(text);

    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json",
        json,
    );
    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.txt",
        text,
    );
}

test "scenario proposal parses local default and scenario options" {
    const default_options = try parseOptions(&.{ "zigeffect-causal-scenario-proposal", "local" });
    try std.testing.expectEqual(@as(?[]const u8, null), default_options.scenario_slug);

    const scenario_options = try parseOptions(&.{ "zigeffect-causal-scenario-proposal", "local", "causal-scoped-fiber" });
    try std.testing.expectEqualStrings("causal-scoped-fiber", scenario_options.scenario_slug.?);

    try std.testing.expectError(error.MissingMode, parseOptions(&.{"zigeffect-causal-scenario-proposal"}));
    try std.testing.expectError(error.UnknownMode, parseOptions(&.{ "zigeffect-causal-scenario-proposal", "remote" }));
}

test "scenario proposal recommendation uses verdict and audit-chain posture" {
    try std.testing.expectEqual(Recommendation.none, chooseRecommendation(.{
        .scenario_slug = "causal-scoped-fiber",
        .verdict_status = "clear",
        .actions = 0,
        .new_actions = 0,
        .persisting_actions = 0,
        .audit_chain_assessment = "inconclusive",
        .persisting_event_ids = &.{},
        .appeared_event_ids = &.{},
    }));
    try std.testing.expectEqual(Recommendation.add_scenario, chooseRecommendation(.{
        .scenario_slug = null,
        .verdict_status = "attention",
        .actions = 2,
        .new_actions = 0,
        .persisting_actions = 2,
        .audit_chain_assessment = "unchanged",
        .persisting_event_ids = &.{ 3, 4 },
        .appeared_event_ids = &.{},
    }));
    try std.testing.expectEqual(Recommendation.refine_scenario, chooseRecommendation(.{
        .scenario_slug = "causal-scoped-fiber",
        .verdict_status = "attention",
        .actions = 1,
        .new_actions = 1,
        .persisting_actions = 0,
        .audit_chain_assessment = "regressed",
        .persisting_event_ids = &.{},
        .appeared_event_ids = &.{9},
    }));
}
