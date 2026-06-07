const std = @import("std");
const causal_run = @import("causal_run");

const audit_schema = "zigeffect.causal.remediation-audit.v1";
const decision_schema = "zigeffect.causal.remediation-decision.v1";
const proposal_schema = "zigeffect.causal.patch-proposal.v1";

const ProposalStatus = enum {
    draft,
    approved,
};

const ProposalOptions = struct {
    mode: []const u8,
    status: ProposalStatus,
    scenario_slug: ?[]const u8 = null,
    summary: []const u8,
    file: []const u8,
    change: []const u8,
};

fn localProposalJsonPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-patch-proposal.json";
}

fn localProposalTextPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-patch-proposal.txt";
}

fn localProposalJsonPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-patch-proposal.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn localProposalTextPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-patch-proposal.txt",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn parseProposalStatus(value: []const u8) ?ProposalStatus {
    if (std.mem.eql(u8, value, "draft")) return .draft;
    if (std.mem.eql(u8, value, "approved")) return .approved;
    return null;
}

fn proposalStatusText(status: ProposalStatus) []const u8 {
    return switch (status) {
        .draft => "draft",
        .approved => "approved",
    };
}

fn parseProposalOptions(args: []const []const u8) !ProposalOptions {
    if (args.len < 2) return error.MissingMode;
    if (!std.mem.eql(u8, args[1], "local")) return error.UnknownMode;
    if (args.len < 3) return error.MissingProposalStatus;

    const status = parseProposalStatus(args[2]) orelse return error.UnknownProposalStatus;
    var scenario_slug: ?[]const u8 = null;
    var summary: ?[]const u8 = null;
    var file: ?[]const u8 = null;
    var change: ?[]const u8 = null;

    var index: usize = 3;
    while (index < args.len) {
        const arg = args[index];
        if (std.mem.startsWith(u8, arg, "--")) {
            if (index + 1 >= args.len) return error.MissingFlagValue;
            const value = args[index + 1];
            if (std.mem.eql(u8, arg, "--summary")) {
                summary = value;
            } else if (std.mem.eql(u8, arg, "--file")) {
                file = value;
            } else if (std.mem.eql(u8, arg, "--change")) {
                change = value;
            } else {
                return error.UnknownFlag;
            }
            index += 2;
        } else {
            if (scenario_slug != null) return error.DuplicateScenarioArgument;
            scenario_slug = arg;
            index += 1;
        }
    }

    return .{
        .mode = "local",
        .status = status,
        .scenario_slug = scenario_slug,
        .summary = summary orelse return error.MissingSummary,
        .file = file orelse return error.MissingFile,
        .change = change orelse return error.MissingChange,
    };
}

fn usage() []const u8 {
    return "usage: zig build causal-patch-proposal -- local draft|approved [scenario] --summary <summary> --file <path> --change <description>\n";
}

test "patch proposal output paths are stable for default and scenario targets" {
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.json",
        localProposalJsonPath(),
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.txt",
        localProposalTextPath(),
    );

    const scenario_json = try localProposalJsonPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario_json);
    const scenario_text = try localProposalTextPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario_text);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-patch-proposal.json",
        scenario_json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-patch-proposal.txt",
        scenario_text,
    );
}

test "parse options accepts draft metadata" {
    const args = [_][]const u8{
        "zigeffect-causal-patch-proposal",
        "local",
        "draft",
        "--summary",
        "tighten scope close ordering",
        "--file",
        "packages/zigeffect/src/core/scope.zig",
        "--change",
        "ensure child finalizers run before parent close is reported",
    };

    const options = try parseProposalOptions(args[0..]);
    try std.testing.expectEqual(ProposalStatus.draft, options.status);
    try std.testing.expect(options.scenario_slug == null);
    try std.testing.expectEqualStrings("tighten scope close ordering", options.summary);
    try std.testing.expectEqualStrings("packages/zigeffect/src/core/scope.zig", options.file);
    try std.testing.expectEqualStrings("ensure child finalizers run before parent close is reported", options.change);
}

test "parse options accepts approved scenario metadata" {
    const args = [_][]const u8{
        "zigeffect-causal-patch-proposal",
        "local",
        "approved",
        "causal-scoped-fiber",
        "--summary",
        "record scoped fiber interruption",
        "--file",
        "packages/zigeffect/src/runtime/fiber.zig",
        "--change",
        "emit interrupted event before release evidence",
    };

    const options = try parseProposalOptions(args[0..]);
    try std.testing.expectEqual(ProposalStatus.approved, options.status);
    try std.testing.expectEqualStrings("causal-scoped-fiber", options.scenario_slug.?);
}

test "parse options requires summary file and change" {
    const missing_summary = [_][]const u8{
        "zigeffect-causal-patch-proposal",
        "local",
        "draft",
        "--file",
        "packages/zigeffect/src/core/scope.zig",
        "--change",
        "change",
    };
    try std.testing.expectError(error.MissingSummary, parseProposalOptions(missing_summary[0..]));

    const missing_file = [_][]const u8{
        "zigeffect-causal-patch-proposal",
        "local",
        "draft",
        "--summary",
        "summary",
        "--change",
        "change",
    };
    try std.testing.expectError(error.MissingFile, parseProposalOptions(missing_file[0..]));

    const missing_change = [_][]const u8{
        "zigeffect-causal-patch-proposal",
        "local",
        "draft",
        "--summary",
        "summary",
        "--file",
        "packages/zigeffect/src/core/scope.zig",
    };
    try std.testing.expectError(error.MissingChange, parseProposalOptions(missing_change[0..]));
}

test "usage names local proposal shape" {
    try std.testing.expectEqualStrings(
        "usage: zig build causal-patch-proposal -- local draft|approved [scenario] --summary <summary> --file <path> --change <description>\n",
        usage(),
    );
}
