const std = @import("std");
const causal_run = @import("causal_run");

const policy_schema = "zigeffect.causal.policy-decision.v1";
const default_policy_name = "local-causal-self-improvement-v1";

const Options = struct {
    mode: []const u8,
    scenario_slug: ?[]const u8 = null,
    evaluated_by: []const u8 = "local-policy-engine",
    policy: []const u8 = default_policy_name,
};

const PolicyDecisionPaths = struct {
    audit_json: []const u8,
    decision_json: []const u8,
    proposal_json: []const u8,
    audit_chain_json: []const u8,
    scenario_proposal_json: []const u8,
    registry_patch_json: []const u8,
    registry_readiness_json: []const u8,
    registry_application_json: []const u8,
    output_json: []const u8,
    output_text: []const u8,

    fn deinit(self: PolicyDecisionPaths, allocator: std.mem.Allocator, options: Options) void {
        if (options.scenario_slug == null) return;
        allocator.free(self.audit_json);
        allocator.free(self.decision_json);
        allocator.free(self.proposal_json);
        allocator.free(self.audit_chain_json);
        allocator.free(self.scenario_proposal_json);
        allocator.free(self.registry_patch_json);
        allocator.free(self.registry_readiness_json);
        allocator.free(self.registry_application_json);
        allocator.free(self.output_json);
        allocator.free(self.output_text);
    }
};

fn parseOptions(args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingMode;
    if (!std.mem.eql(u8, args[1], "local")) return error.UnknownMode;

    var scenario_slug: ?[]const u8 = null;
    var evaluated_by: []const u8 = "local-policy-engine";
    var policy: []const u8 = default_policy_name;

    var index: usize = 2;
    while (index < args.len) {
        const arg = args[index];
        if (std.mem.startsWith(u8, arg, "--")) {
            if (index + 1 >= args.len) return error.MissingFlagValue;
            const value = args[index + 1];
            if (std.mem.eql(u8, arg, "--by")) {
                evaluated_by = value;
            } else if (std.mem.eql(u8, arg, "--policy")) {
                if (!std.mem.eql(u8, value, default_policy_name)) return error.UnknownPolicy;
                policy = value;
            } else {
                return error.UnknownFlag;
            }
            index += 2;
        } else {
            if (scenario_slug != null) return error.DuplicateScenarioArgument;
            _ = try causal_run.scenarioByName(arg);
            scenario_slug = arg;
            index += 1;
        }
    }

    return .{
        .mode = "local",
        .scenario_slug = scenario_slug,
        .evaluated_by = evaluated_by,
        .policy = policy,
    };
}

fn defaultPolicyDecisionPaths() PolicyDecisionPaths {
    return .{
        .audit_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-audit.json",
        .decision_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-decision.json",
        .proposal_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-patch-proposal.json",
        .audit_chain_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-audit-chain.json",
        .scenario_proposal_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-scenario-proposal.json",
        .registry_patch_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-registry-patch.json",
        .registry_readiness_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-registry-application-readiness.json",
        .registry_application_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-registry-application.json",
        .output_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-policy-decision.json",
        .output_text = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-policy-decision.txt",
    };
}

fn scenarioPolicyDecisionPaths(allocator: std.mem.Allocator, scenario_slug: []const u8) !PolicyDecisionPaths {
    const audit_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-remediation-audit.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(audit_json);
    const decision_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-remediation-decision.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(decision_json);
    const proposal_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-patch-proposal.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(proposal_json);
    const audit_chain_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-audit-chain.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(audit_chain_json);
    const scenario_proposal_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-scenario-proposal.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(scenario_proposal_json);
    const registry_patch_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-registry-patch.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(registry_patch_json);
    const registry_readiness_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-registry-application-readiness.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(registry_readiness_json);
    const registry_application_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-registry-application.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(registry_application_json);
    const output_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-policy-decision.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(output_json);
    const output_text = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-policy-decision.txt", .{ causal_run.artifact_dir, scenario_slug });

    return .{
        .audit_json = audit_json,
        .decision_json = decision_json,
        .proposal_json = proposal_json,
        .audit_chain_json = audit_chain_json,
        .scenario_proposal_json = scenario_proposal_json,
        .registry_patch_json = registry_patch_json,
        .registry_readiness_json = registry_readiness_json,
        .registry_application_json = registry_application_json,
        .output_json = output_json,
        .output_text = output_text,
    };
}

fn policyDecisionPathsForOptions(allocator: std.mem.Allocator, options: Options) !PolicyDecisionPaths {
    if (options.scenario_slug) |slug| return scenarioPolicyDecisionPaths(allocator, slug);
    return defaultPolicyDecisionPaths();
}

test "policy decision parses default and scenario local invocations" {
    const default_args = [_][]const u8{
        "zigeffect-causal-policy-decision",
        "local",
        "--by",
        "local-agent",
    };
    const default_options = try parseOptions(default_args[0..]);
    try std.testing.expectEqualStrings("local", default_options.mode);
    try std.testing.expect(default_options.scenario_slug == null);
    try std.testing.expectEqualStrings(default_policy_name, default_options.policy);
    try std.testing.expectEqualStrings("local-agent", default_options.evaluated_by);

    const scenario_args = [_][]const u8{
        "zigeffect-causal-policy-decision",
        "local",
        "causal-scoped-fiber",
        "--policy",
        default_policy_name,
    };
    const scenario_options = try parseOptions(scenario_args[0..]);
    try std.testing.expectEqualStrings("causal-scoped-fiber", scenario_options.scenario_slug.?);
    try std.testing.expectEqualStrings(default_policy_name, scenario_options.policy);
}

test "policy decision rejects unknown local policy" {
    const args = [_][]const u8{
        "zigeffect-causal-policy-decision",
        "local",
        "--policy",
        "experimental-remote-policy",
    };
    try std.testing.expectError(error.UnknownPolicy, parseOptions(args[0..]));
}

test "policy decision output paths are stable for default and scenario targets" {
    const default_options = Options{ .mode = "local", .scenario_slug = null };
    const default_paths = try policyDecisionPathsForOptions(std.testing.allocator, default_options);
    defer default_paths.deinit(std.testing.allocator, default_options);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-policy-decision.json",
        default_paths.output_json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-policy-decision.txt",
        default_paths.output_text,
    );

    const scenario_options = Options{ .mode = "local", .scenario_slug = "causal-scoped-fiber" };
    const scenario_paths = try policyDecisionPathsForOptions(std.testing.allocator, scenario_options);
    defer scenario_paths.deinit(std.testing.allocator, scenario_options);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-policy-decision.json",
        scenario_paths.output_json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-policy-decision.txt",
        scenario_paths.output_text,
    );
}
