const std = @import("std");
const causal_run = @import("causal_run");

const readiness_suffix = "-registry-application-readiness.json";
const application_suffix = "-registry-application";
const readiness_schema = "zigeffect.causal.registry-application-readiness.v1";
const application_schema = "zigeffect.causal.registry-application.v1";

const Mode = enum {
    plan,
    record_applied,
};

const Options = struct {
    readiness_path: []const u8,
    mode: Mode,
    applied_by: []const u8 = "local-reviewer",
    policy: []const u8 = "manual-application",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        if (self.verified_commands.len > 0) allocator.free(self.verified_commands);
    }
};

const ApplicationPaths = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: ApplicationPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 3) return error.MissingReadinessPath;
    if (!std.mem.eql(u8, args[1], "--from-readiness")) return error.UnknownFlag;
    if (!std.mem.endsWith(u8, args[2], readiness_suffix)) return error.InvalidReadinessPath;
    if (args.len < 4) return error.MissingMode;

    const mode: Mode = if (std.mem.eql(u8, args[3], "plan"))
        .plan
    else if (std.mem.eql(u8, args[3], "record-applied"))
        .record_applied
    else
        return error.UnknownMode;

    var applied_by: []const u8 = "local-reviewer";
    var policy: []const u8 = "manual-application";
    var reason: ?[]const u8 = null;
    var verified_commands = std.ArrayList([]const u8).empty;
    errdefer verified_commands.deinit(allocator);

    var index: usize = 4;
    while (index < args.len) {
        if (index + 1 >= args.len) return error.MissingFlagValue;
        const flag = args[index];
        const value = args[index + 1];

        if (std.mem.eql(u8, flag, "--by")) {
            applied_by = value;
        } else if (std.mem.eql(u8, flag, "--policy")) {
            policy = value;
        } else if (std.mem.eql(u8, flag, "--reason")) {
            reason = value;
        } else if (std.mem.eql(u8, flag, "--verified-command")) {
            try verified_commands.append(allocator, value);
        } else {
            return error.UnknownFlag;
        }
        index += 2;
    }

    const final_reason = reason orelse return error.MissingReason;
    if (final_reason.len == 0) return error.MissingReason;

    return .{
        .readiness_path = args[2],
        .mode = mode,
        .applied_by = applied_by,
        .policy = policy,
        .reason = final_reason,
        .verified_commands = try verified_commands.toOwnedSlice(allocator),
    };
}

fn applicationPathsFromReadiness(allocator: std.mem.Allocator, readiness_path: []const u8) !ApplicationPaths {
    if (!std.mem.endsWith(u8, readiness_path, readiness_suffix)) return error.InvalidReadinessPath;
    const prefix = readiness_path[0 .. readiness_path.len - readiness_suffix.len];

    const json = try std.fmt.allocPrint(allocator, "{s}{s}.json", .{ prefix, application_suffix });
    errdefer allocator.free(json);
    const text = try std.fmt.allocPrint(allocator, "{s}{s}.txt", .{ prefix, application_suffix });

    return .{ .json = json, .text = text };
}

fn modeText(mode: Mode) []const u8 {
    return switch (mode) {
        .plan => "plan",
        .record_applied => "record-applied",
    };
}

fn usage() []const u8 {
    return "usage: zig build causal-registry-apply -- --from-readiness <registry-application-readiness.json> plan|record-applied --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]...\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-registry-apply error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

test "registry apply parses plan mode and metadata" {
    const options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json",
        "plan",
        "--reason",
        "prepare manual registry application",
        "--by",
        "local-reviewer",
        "--policy",
        "manual-application",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json",
        options.readiness_path,
    );
    try std.testing.expectEqual(Mode.plan, options.mode);
    try std.testing.expectEqualStrings("local-reviewer", options.applied_by);
    try std.testing.expectEqualStrings("manual-application", options.policy);
    try std.testing.expectEqualStrings("prepare manual registry application", options.reason);
    try std.testing.expectEqual(@as(usize, 0), options.verified_commands.len);
}

test "registry apply parses record-applied verification commands" {
    const options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-registry-application-readiness.json",
        "record-applied",
        "--reason",
        "registry and docs updated",
        "--verified-command",
        "zig build causal-run package-tests",
        "--verified-command",
        "zig build examples",
        "--verified-command",
        "zig build test --summary none",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Mode.record_applied, options.mode);
    try std.testing.expectEqual(@as(usize, 3), options.verified_commands.len);
}

test "registry apply rejects missing path reason unknown mode and bad suffix" {
    try std.testing.expectError(error.MissingReadinessPath, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-apply",
    }));
    try std.testing.expectError(error.InvalidReadinessPath, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/readiness.json",
        "plan",
        "--reason",
        "x",
    }));
    try std.testing.expectError(error.UnknownMode, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json",
        "apply",
        "--reason",
        "x",
    }));
    try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json",
        "plan",
    }));
}

test "registry apply output paths derive from readiness path" {
    const paths = try applicationPathsFromReadiness(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application-readiness.json",
    );
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application.json",
        paths.json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application.txt",
        paths.text,
    );
}
