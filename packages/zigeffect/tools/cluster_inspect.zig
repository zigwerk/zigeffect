const std = @import("std");
const fx = @import("zigeffect");

const OutputFormat = enum { text, json };
const max_runner_specs = 32;

pub const ClusterInspectCliError = error{
    UnknownFlag,
    MissingFlagValue,
    UnknownFormat,
    InvalidNumber,
    MissingStorageDir,
    MissingShardCount,
    InvalidRunnerSpec,
    TooManyRunnerSpecs,
};

pub const RunnerSpec = struct {
    machine_id: []const u8 = "",
    runner_id: []const u8 = "",
    name: []const u8 = "",
    started_at_ms: u64 = 0,
    heartbeat_at_ms: ?u64 = null,
};

pub const ClusterInspectCliOptions = struct {
    help: bool = false,
    storage_dir: []const u8 = "",
    shard_count: fx.ShardCount = 0,
    lease_ttl_ms: fx.RunnerLeaseTtlMs = 5_000,
    now_ms: u64 = 0,
    format: OutputFormat = .text,
    runner_count: usize = 0,
    runners: [max_runner_specs]RunnerSpec = [_]RunnerSpec{.{}} ** max_runner_specs,

    pub fn runnerSlice(self: *const ClusterInspectCliOptions) []const RunnerSpec {
        return self.runners[0..self.runner_count];
    }
};

pub fn usage() []const u8 {
    return "usage: zig build cluster-inspect -- --storage-dir <path> --shard-count <n> [--format text|json] [--now-ms <ms>] [--lease-ttl-ms <ms>] [--runner machine:runner:name:started-ms[:heartbeat-ms]]\n";
}

pub fn parseClusterInspectArgs(args: []const []const u8) !ClusterInspectCliOptions {
    var options = ClusterInspectCliOptions{};
    var index: usize = 0;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            options.help = true;
            return options;
        } else if (std.mem.eql(u8, arg, "--storage-dir")) {
            options.storage_dir = try nextValue(args, &index);
        } else if (std.mem.eql(u8, arg, "--shard-count")) {
            options.shard_count = try parseNumber(fx.ShardCount, try nextValue(args, &index));
        } else if (std.mem.eql(u8, arg, "--lease-ttl-ms")) {
            options.lease_ttl_ms = try parseNumber(fx.RunnerLeaseTtlMs, try nextValue(args, &index));
        } else if (std.mem.eql(u8, arg, "--now-ms")) {
            options.now_ms = try parseNumber(u64, try nextValue(args, &index));
        } else if (std.mem.eql(u8, arg, "--format")) {
            options.format = try parseOutputFormat(try nextValue(args, &index));
        } else if (std.mem.eql(u8, arg, "--json")) {
            options.format = .json;
        } else if (std.mem.eql(u8, arg, "--runner")) {
            if (options.runner_count >= max_runner_specs) return error.TooManyRunnerSpecs;
            options.runners[options.runner_count] = try parseRunnerSpec(try nextValue(args, &index));
            options.runner_count += 1;
        } else {
            return error.UnknownFlag;
        }
    }

    if (options.storage_dir.len == 0) return error.MissingStorageDir;
    if (options.shard_count == 0) return error.MissingShardCount;
    return options;
}

pub fn runClusterInspect(allocator: std.mem.Allocator, io: std.Io, options: ClusterInspectCliOptions) ![]const u8 {
    if (options.help) return allocator.dupe(u8, usage());
    if (options.storage_dir.len == 0) return error.MissingStorageDir;
    if (options.shard_count == 0) return error.MissingShardCount;

    var cwd = std.Io.Dir.cwd();
    var storage_dir = try cwd.openDir(io, options.storage_dir, .{});
    defer storage_dir.close(io);

    var runner_storage = try fx.FileRunnerStorage.open(allocator, io, &storage_dir, .{});
    defer runner_storage.deinit();
    var message_storage = try fx.FileMessageStorage.open(allocator, io, &storage_dir, .{});
    defer message_storage.deinit();

    var registry = fx.LocalRunnerRegistry.init(allocator);
    defer registry.deinit();
    var controller = try fx.RealClusterController.init(allocator, .{
        .runner_storage = runner_storage.asRunnerStorage(),
        .message_storage = message_storage.asMessageStorage(),
        .registry = &registry,
        .options = .{
            .shard_count = options.shard_count,
            .lease_ttl_ms = options.lease_ttl_ms,
        },
    });

    for (options.runnerSlice()) |spec| {
        const address = fx.runnerAddress(spec.machine_id, spec.runner_id);
        _ = try controller.admitRunner(.{
            .address = address,
            .name = spec.name,
            .started_at_ms = spec.started_at_ms,
        });
        if (spec.heartbeat_at_ms) |heartbeat_at_ms| {
            _ = try controller.recordHeartbeat(.{
                .address = address,
                .sequence = 1,
                .observed_at_ms = heartbeat_at_ms,
            });
        }
    }

    var report = try controller.inspectCluster(allocator, options.now_ms);
    defer report.deinit();
    return switch (options.format) {
        .text => fx.formatClusterInspectionText(allocator, report),
        .json => fx.formatClusterInspectionJson(allocator, report),
    };
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseClusterInspectArgs(args[1..]) catch |err| failUsage(err);
    const output = try runClusterInspect(init.gpa, init.io, options);
    defer init.gpa.free(output);
    std.debug.print("{s}", .{output});
}

fn nextValue(args: []const []const u8, index: *usize) ClusterInspectCliError![]const u8 {
    index.* += 1;
    if (index.* >= args.len) return error.MissingFlagValue;
    return args[index.*];
}

fn parseOutputFormat(value: []const u8) ClusterInspectCliError!OutputFormat {
    if (std.mem.eql(u8, value, "text")) return .text;
    if (std.mem.eql(u8, value, "json")) return .json;
    return error.UnknownFormat;
}

fn parseNumber(comptime T: type, value: []const u8) ClusterInspectCliError!T {
    return std.fmt.parseUnsigned(T, value, 10) catch error.InvalidNumber;
}

fn parseRunnerSpec(value: []const u8) ClusterInspectCliError!RunnerSpec {
    var parts = std.mem.splitScalar(u8, value, ':');
    const machine_id = parts.next() orelse return error.InvalidRunnerSpec;
    const runner_id = parts.next() orelse return error.InvalidRunnerSpec;
    const name = parts.next() orelse return error.InvalidRunnerSpec;
    const started_at_ms = parts.next() orelse return error.InvalidRunnerSpec;
    const heartbeat_at_ms = parts.next();
    if (parts.next() != null) return error.InvalidRunnerSpec;
    if (machine_id.len == 0 or runner_id.len == 0 or name.len == 0 or started_at_ms.len == 0) return error.InvalidRunnerSpec;

    return .{
        .machine_id = machine_id,
        .runner_id = runner_id,
        .name = name,
        .started_at_ms = try parseNumber(u64, started_at_ms),
        .heartbeat_at_ms = if (heartbeat_at_ms) |value_ms| try parseNumber(u64, value_ms) else null,
    };
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("cluster-inspect error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

test "cluster inspect parses help" {
    const options = try parseClusterInspectArgs(&.{"--help"});
    try std.testing.expect(options.help);
}

test "cluster inspect parses storage format and runner specs" {
    const options = try parseClusterInspectArgs(&.{
        "--storage-dir", ".zig-cache/local-cluster",
        "--shard-count", "8",
        "--format",      "json",
        "--now-ms",      "1200",
        "--runner",      "machine-real:runner-a:runner-a:1000:1010",
        "--runner",      "machine-real:runner-b:runner-b:1000",
    });
    try std.testing.expectEqualStrings(".zig-cache/local-cluster", options.storage_dir);
    try std.testing.expectEqual(@as(fx.ShardCount, 8), options.shard_count);
    try std.testing.expectEqual(OutputFormat.json, options.format);
    try std.testing.expectEqual(@as(usize, 2), options.runner_count);
    try std.testing.expectEqualStrings("runner-a", options.runners[0].name);
    try std.testing.expectEqual(@as(?u64, 1010), options.runners[0].heartbeat_at_ms);
    try std.testing.expectEqual(@as(?u64, null), options.runners[1].heartbeat_at_ms);
}

test "cluster inspect validates required and malformed options" {
    try std.testing.expectError(error.MissingStorageDir, parseClusterInspectArgs(&.{
        "--shard-count", "8",
    }));
    try std.testing.expectError(error.MissingShardCount, parseClusterInspectArgs(&.{
        "--storage-dir", ".zig-cache/local-cluster",
    }));
    try std.testing.expectError(error.UnknownFormat, parseClusterInspectArgs(&.{
        "--storage-dir", ".zig-cache/local-cluster",
        "--shard-count", "8",
        "--format",      "yaml",
    }));
    try std.testing.expectError(error.InvalidRunnerSpec, parseClusterInspectArgs(&.{
        "--storage-dir", ".zig-cache/local-cluster",
        "--shard-count", "8",
        "--runner",      "machine-only",
    }));
}
