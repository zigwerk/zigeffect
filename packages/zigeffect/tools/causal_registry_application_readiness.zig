const std = @import("std");

const registry_patch_suffix = "-registry-patch.json";
const readiness_suffix = "-registry-application-readiness";

const Decision = enum {
    approve,
    reject,
};

const Options = struct {
    registry_patch_path: []const u8,
    decision: Decision,
    decided_by: []const u8 = "local-reviewer",
    policy: []const u8 = "manual-review",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        if (self.verified_commands.len > 0) allocator.free(self.verified_commands);
    }
};

const ReadinessPaths = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: ReadinessPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 3) return error.MissingRegistryPatchPath;
    if (!std.mem.eql(u8, args[1], "--from-registry-patch")) return error.UnknownFlag;
    if (!std.mem.endsWith(u8, args[2], registry_patch_suffix)) return error.InvalidRegistryPatchPath;
    if (args.len < 4) return error.MissingDecision;

    const decision: Decision = if (std.mem.eql(u8, args[3], "approve"))
        .approve
    else if (std.mem.eql(u8, args[3], "reject"))
        .reject
    else
        return error.UnknownDecision;

    var decided_by: []const u8 = "local-reviewer";
    var policy: []const u8 = "manual-review";
    var reason: ?[]const u8 = null;
    var verified_commands = std.ArrayList([]const u8).empty;
    errdefer verified_commands.deinit(allocator);

    var index: usize = 4;
    while (index < args.len) {
        const arg = args[index];
        if (index + 1 >= args.len) return error.MissingFlagValue;
        const value = args[index + 1];

        if (std.mem.eql(u8, arg, "--by")) {
            decided_by = value;
        } else if (std.mem.eql(u8, arg, "--policy")) {
            policy = value;
        } else if (std.mem.eql(u8, arg, "--reason")) {
            reason = value;
        } else if (std.mem.eql(u8, arg, "--verified-command")) {
            try verified_commands.append(allocator, value);
        } else {
            return error.UnknownFlag;
        }
        index += 2;
    }

    const final_reason = reason orelse return error.MissingReason;
    if (final_reason.len == 0) return error.MissingReason;

    return .{
        .registry_patch_path = args[2],
        .decision = decision,
        .decided_by = decided_by,
        .policy = policy,
        .reason = final_reason,
        .verified_commands = try verified_commands.toOwnedSlice(allocator),
    };
}

fn readinessPathsFromRegistryPatch(allocator: std.mem.Allocator, registry_patch_path: []const u8) !ReadinessPaths {
    if (!std.mem.endsWith(u8, registry_patch_path, registry_patch_suffix)) return error.InvalidRegistryPatchPath;
    const prefix = registry_patch_path[0 .. registry_patch_path.len - registry_patch_suffix.len];

    const json = try std.fmt.allocPrint(allocator, "{s}{s}.json", .{ prefix, readiness_suffix });
    errdefer allocator.free(json);
    const text = try std.fmt.allocPrint(allocator, "{s}{s}.txt", .{ prefix, readiness_suffix });

    return .{ .json = json, .text = text };
}

fn decisionText(decision: Decision) []const u8 {
    return switch (decision) {
        .approve => "approve",
        .reject => "reject",
    };
}

fn usage() []const u8 {
    return "usage: zig build causal-registry-application-readiness -- --from-registry-patch <registry-patch.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]...\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-registry-application-readiness error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

test "registry readiness parses approve decision and verified commands" {
    const options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-application-readiness",
        "--from-registry-patch",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json",
        "approve",
        "--reason",
        "reviewed registry entry and docs",
        "--by",
        "local-reviewer",
        "--policy",
        "manual-review",
        "--verified-command",
        "zig build causal-run learned-dogfood-service-resolution",
        "--verified-command",
        "zig build examples",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json",
        options.registry_patch_path,
    );
    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings("local-reviewer", options.decided_by);
    try std.testing.expectEqualStrings("manual-review", options.policy);
    try std.testing.expectEqualStrings("reviewed registry entry and docs", options.reason);
    try std.testing.expectEqual(@as(usize, 2), options.verified_commands.len);
}

test "registry readiness rejects missing path reason and unknown flags" {
    try std.testing.expectError(error.MissingRegistryPatchPath, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-application-readiness",
    }));
    try std.testing.expectError(error.InvalidRegistryPatchPath, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-application-readiness",
        "--from-registry-patch",
        "registry-patch.json",
        "approve",
        "--reason",
        "x",
    }));
    try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-application-readiness",
        "--from-registry-patch",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json",
        "reject",
    }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-application-readiness",
        "--from-registry-patch",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json",
        "approve",
        "--reason",
        "x",
        "--actor",
        "reviewer",
    }));
}

test "registry readiness output paths are derived from registry patch path" {
    const paths = try readinessPathsFromRegistryPatch(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json",
    );
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application-readiness.json",
        paths.json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application-readiness.txt",
        paths.text,
    );
}
