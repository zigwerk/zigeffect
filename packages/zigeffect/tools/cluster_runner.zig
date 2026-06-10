const std = @import("std");
const fx = @import("zigeffect");

pub const ClusterRunnerCliError = error{
    MissingArgument,
    UnknownArgument,
    InvalidNumber,
    MissingRunnerId,
    MissingMachineId,
    MissingStorageDir,
    MissingShardCount,
    MissingRunnerIndex,
    MissingRunnerCount,
};

pub const ClusterRunnerCliOptions = struct {
    help: bool = false,
    runner_id: []const u8 = "",
    machine_id: []const u8 = "",
    storage_dir: []const u8 = "",
    shard_count: fx.ShardCount = 0,
    runner_index: usize = 0,
    runner_count: usize = 0,
    lease_ttl_ms: u64 = 5_000,
    refresh_interval_ms: u64 = 1_000,
    tick_ms: u64 = 100,
    max_ticks: usize = 1,
    simulate_death_after_ticks: ?usize = null,
};

pub fn usage() []const u8 {
    return "usage: zig build cluster-runner -- --runner-id <id> --machine-id <id> --storage-dir <path> --shard-count <n> --runner-index <n> --runner-count <n> [--max-ticks <n>] [--simulate-death-after-ticks <n>]\n";
}

pub fn parseClusterRunnerArgs(args: []const []const u8) (ClusterRunnerCliError || std.fmt.ParseIntError)!ClusterRunnerCliOptions {
    var options = ClusterRunnerCliOptions{};
    var index: usize = 0;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            options.help = true;
            return options;
        } else if (std.mem.eql(u8, arg, "--runner-id")) {
            options.runner_id = try nextValue(args, &index);
        } else if (std.mem.eql(u8, arg, "--machine-id")) {
            options.machine_id = try nextValue(args, &index);
        } else if (std.mem.eql(u8, arg, "--storage-dir")) {
            options.storage_dir = try nextValue(args, &index);
        } else if (std.mem.eql(u8, arg, "--shard-count")) {
            options.shard_count = try parseNumber(fx.ShardCount, try nextValue(args, &index));
        } else if (std.mem.eql(u8, arg, "--runner-index")) {
            options.runner_index = try parseNumber(usize, try nextValue(args, &index));
        } else if (std.mem.eql(u8, arg, "--runner-count")) {
            options.runner_count = try parseNumber(usize, try nextValue(args, &index));
        } else if (std.mem.eql(u8, arg, "--lease-ttl-ms")) {
            options.lease_ttl_ms = try parseNumber(u64, try nextValue(args, &index));
        } else if (std.mem.eql(u8, arg, "--refresh-interval-ms")) {
            options.refresh_interval_ms = try parseNumber(u64, try nextValue(args, &index));
        } else if (std.mem.eql(u8, arg, "--tick-ms")) {
            options.tick_ms = try parseNumber(u64, try nextValue(args, &index));
        } else if (std.mem.eql(u8, arg, "--max-ticks")) {
            options.max_ticks = try parseNumber(usize, try nextValue(args, &index));
        } else if (std.mem.eql(u8, arg, "--simulate-death-after-ticks")) {
            options.simulate_death_after_ticks = try parseNumber(usize, try nextValue(args, &index));
        } else {
            return error.UnknownArgument;
        }
    }

    if (options.runner_id.len == 0) return error.MissingRunnerId;
    if (options.machine_id.len == 0) return error.MissingMachineId;
    if (options.storage_dir.len == 0) return error.MissingStorageDir;
    if (options.shard_count == 0) return error.MissingShardCount;
    if (options.runner_count == 0) return error.MissingRunnerCount;
    if (options.runner_index >= options.runner_count) return error.MissingRunnerIndex;
    return options;
}

pub fn runClusterRunner(allocator: std.mem.Allocator, io: std.Io, options: ClusterRunnerCliOptions) !void {
    var cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, options.storage_dir);
    var storage_dir = try cwd.openDir(io, options.storage_dir, .{});
    defer storage_dir.close(io);

    var runner_storage = try fx.FileRunnerStorage.open(allocator, io, &storage_dir, .{});
    defer runner_storage.deinit();
    var message_storage = try fx.FileMessageStorage.open(allocator, io, &storage_dir, .{});
    defer message_storage.deinit();

    var local_runner = try fx.LocalClusterRunner.init(allocator, .{
        .runner = fx.runnerAddress(options.machine_id, options.runner_id),
        .runner_storage = runner_storage.asRunnerStorage(),
        .message_storage = message_storage.asMessageStorage(),
        .shard_count = options.shard_count,
        .runner_index = options.runner_index,
        .runner_count = options.runner_count,
        .lease_options = .{
            .ttl_ms = options.lease_ttl_ms,
            .refresh_interval_ms = options.refresh_interval_ms,
        },
    });
    defer local_runner.deinit();

    var plan = try local_runner.acquireBalancedShards(0);
    defer plan.deinit();

    const Handler = struct {
        pub fn handle(_: *fx.EntityScope, envelope: fx.EntityEnvelope) !fx.EntityHandlerResult {
            if (envelope.kind == .ask) return .{ .reply = "" };
            return .noreply;
        }
    };

    var tick: usize = 0;
    while (tick < options.max_ticks) : (tick += 1) {
        if (options.simulate_death_after_ticks) |death_tick| {
            if (tick >= death_tick) return;
        }
        _ = try local_runner.tick(Handler, @as(u64, @intCast(tick)) * options.tick_ms);
    }

    _ = try local_runner.shutdown(@as(u64, @intCast(options.max_ticks)) * options.tick_ms);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseClusterRunnerArgs(args[1..]) catch |err| failUsage(err);
    if (options.help) {
        std.debug.print("{s}", .{usage()});
        return;
    }
    try runClusterRunner(init.gpa, init.io, options);
}

fn nextValue(args: []const []const u8, index: *usize) ClusterRunnerCliError![]const u8 {
    index.* += 1;
    if (index.* >= args.len) return error.MissingArgument;
    return args[index.*];
}

fn parseNumber(comptime T: type, value: []const u8) std.fmt.ParseIntError!T {
    return std.fmt.parseUnsigned(T, value, 10);
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("cluster-runner error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

test "cluster runner parses help" {
    const options = try parseClusterRunnerArgs(&.{"--help"});
    try std.testing.expect(options.help);
}

test "cluster runner parses required options" {
    const options = try parseClusterRunnerArgs(&.{
        "--runner-id",    "runner-a",
        "--machine-id",   "machine-local",
        "--storage-dir",  ".zig-cache/local-cluster",
        "--shard-count",  "8",
        "--runner-index", "1",
        "--runner-count", "2",
        "--max-ticks",    "3",
    });
    try std.testing.expectEqualStrings("runner-a", options.runner_id);
    try std.testing.expectEqual(@as(fx.ShardCount, 8), options.shard_count);
    try std.testing.expectEqual(@as(usize, 1), options.runner_index);
    try std.testing.expectEqual(@as(usize, 3), options.max_ticks);
}

test "cluster runner validates required options" {
    try std.testing.expectError(error.MissingRunnerId, parseClusterRunnerArgs(&.{
        "--machine-id",   "machine-local",
        "--storage-dir",  ".zig-cache/local-cluster",
        "--shard-count",  "8",
        "--runner-index", "0",
        "--runner-count", "2",
    }));
    try std.testing.expectError(error.InvalidCharacter, parseClusterRunnerArgs(&.{
        "--runner-id",    "runner-a",
        "--machine-id",   "machine-local",
        "--storage-dir",  ".zig-cache/local-cluster",
        "--shard-count",  "eight",
        "--runner-index", "0",
        "--runner-count", "2",
    }));
}
