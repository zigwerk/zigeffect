const std = @import("std");
const Secrets = @import("../secrets/root.zig");
const Capability = @import("../capability/root.zig");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const EnvVar = struct {
    name: []const u8,
    value: []const u8,
    secret: bool = false,
};

pub const Command = struct {
    argv: []const []const u8,
    cwd: []const u8 = "",
    env: []const EnvVar = &.{},
};

pub const Result = struct {
    exit_code: i32,
    stdout: []const u8 = "",
    stderr: []const u8 = "",
};

pub const Receipt = struct {
    command: []const u8,
    status: []const u8,
    exit_code: i32,

    pub fn deinit(self: *Receipt, allocator: std.mem.Allocator) void {
        allocator.free(self.command);
    }
};

pub const RunOutput = struct {
    receipt: Receipt,
    stdout: []const u8,
    stderr: []const u8,

    pub fn deinit(self: *RunOutput, allocator: std.mem.Allocator) void {
        self.receipt.deinit(allocator);
        allocator.free(self.stdout);
        allocator.free(self.stderr);
    }
};

pub const FakeRunner = struct {
    pub const capability = Capability.Builtin.fake_process_runner;

    result: Result,

    pub fn init(result: Result) FakeRunner {
        return .{ .result = result };
    }

    pub fn runAlloc(
        self: FakeRunner,
        allocator: std.mem.Allocator,
        command: Command,
    ) !Receipt {
        const command_text = try formatCommandAlloc(allocator, command);
        defer allocator.free(command_text);

        return .{
            .command = try Secrets.redactAlloc(allocator, command_text),
            .status = if (self.result.exit_code == 0) "success" else "failure",
            .exit_code = self.result.exit_code,
        };
    }

    pub fn runOutputAlloc(
        self: FakeRunner,
        allocator: std.mem.Allocator,
        command: Command,
    ) !RunOutput {
        const receipt = try self.runAlloc(allocator, command);
        errdefer {
            var mutable_receipt = receipt;
            mutable_receipt.deinit(allocator);
        }

        return .{
            .receipt = receipt,
            .stdout = try allocator.dupe(u8, self.result.stdout),
            .stderr = try allocator.dupe(u8, self.result.stderr),
        };
    }
};

pub const LocalRunner = struct {
    pub const capability = Capability.Builtin.local_process_runner;

    io: std.Io,
    stdout_limit: std.Io.Limit = .limited(1024 * 1024),
    stderr_limit: std.Io.Limit = .limited(1024 * 1024),
    reserve_amount: usize = 256,

    pub fn init(io: std.Io) LocalRunner {
        return .{ .io = io };
    }

    pub fn runOutputAlloc(
        self: LocalRunner,
        allocator: std.mem.Allocator,
        command: Command,
    ) !RunOutput {
        const run_result = try std.process.run(allocator, self.io, .{
            .argv = command.argv,
            .cwd = if (command.cwd.len == 0) .inherit else .{ .path = command.cwd },
            .stdout_limit = self.stdout_limit,
            .stderr_limit = self.stderr_limit,
            .reserve_amount = self.reserve_amount,
        });
        errdefer {
            allocator.free(run_result.stdout);
            allocator.free(run_result.stderr);
        }

        const receipt = try receiptAlloc(allocator, command, exitCodeFromTerm(run_result.term));
        errdefer {
            var mutable_receipt = receipt;
            mutable_receipt.deinit(allocator);
        }

        return .{
            .receipt = receipt,
            .stdout = run_result.stdout,
            .stderr = run_result.stderr,
        };
    }
};

pub fn RunEffect(comptime EffectEnv: type, comptime Runner: type) type {
    return struct {
        pub const SuccessType = RunOutput;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Runner};

        command: Command,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!RunOutput {
            const runner = ctx.service(Runner);
            const output = runner.runOutputAlloc(ctx.allocator, self.command) catch |err| {
                const detail = formatCommandAlloc(ctx.allocator, self.command) catch {
                    _ = StdService.recordOperation(ctx, Runner, "run", "failure", @errorName(err));
                    return err;
                };
                defer ctx.allocator.free(detail);
                _ = StdService.recordOperation(ctx, Runner, "run", "failure", detail);
                return err;
            };
            _ = StdService.recordOperation(ctx, Runner, "run", output.receipt.status, output.receipt.command);
            return output;
        }
    };
}

pub fn runEffect(
    comptime EffectEnv: type,
    comptime Runner: type,
    command: Command,
) RunEffect(EffectEnv, Runner) {
    return .{ .command = command };
}

fn formatCommandAlloc(allocator: std.mem.Allocator, command: Command) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    for (command.argv, 0..) |arg, index| {
        if (index != 0) try output.append(allocator, ' ');
        try output.appendSlice(allocator, arg);
    }

    return output.toOwnedSlice(allocator);
}

fn receiptAlloc(allocator: std.mem.Allocator, command: Command, exit_code: i32) !Receipt {
    const command_text = try formatCommandAlloc(allocator, command);
    defer allocator.free(command_text);

    return .{
        .command = try Secrets.redactAlloc(allocator, command_text),
        .status = if (exit_code == 0) "success" else "failure",
        .exit_code = exit_code,
    };
}

fn exitCodeFromTerm(term: std.process.Child.Term) i32 {
    return switch (term) {
        .exited => |code| @intCast(code),
        .signal => |signal| 128 + @as(i32, @intCast(@intFromEnum(signal))),
        .stopped => |signal| 128 + @as(i32, @intCast(@intFromEnum(signal))),
        .unknown => |code| @intCast(code),
    };
}

test "Process fake runner returns redacted receipts" {
    const runner = FakeRunner.init(.{ .exit_code = 0, .stdout = "ok" });
    var receipt = try runner.runAlloc(std.testing.allocator, .{
        .argv = &.{ "echo", "token=abc123" },
        .cwd = "/repo",
    });
    defer receipt.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("[REDACTED]", receipt.command);
    try std.testing.expectEqualStrings("success", receipt.status);
    try std.testing.expectEqual(@as(i32, 0), receipt.exit_code);
}

test "Process runEffect uses fake runner and records redacted causal facts" {
    const zstd = @import("../root.zig");

    var runner = FakeRunner.init(.{ .exit_code = 0, .stdout = "token=abc123" });
    var provider = zstd.Service.Provider(.{FakeRunner}).init(.{&runner});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{FakeRunner})
        .withCausalStore(&store);

    var output = try runtime.run(runEffect(@TypeOf(provider), FakeRunner, .{
        .argv = &.{ "echo", "token=abc123" },
    }));
    defer output.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("[REDACTED]", output.receipt.command);
    try std.testing.expectEqualStrings("token=abc123", output.stdout);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    const event_index = zstd.Service.findOperation(snapshot, FakeRunner, "run", "success");
    try std.testing.expect(event_index != null);
    try std.testing.expect(std.mem.indexOf(u8, snapshot.events[event_index.?].redacted_detail, "abc123") == null);
}

test "Process local runner executes a real local command with bounded capture" {
    var runner = LocalRunner.init(std.testing.io);
    var output = try runner.runOutputAlloc(std.testing.allocator, .{
        .argv = &.{ "/bin/echo", "hello-local" },
    });
    defer output.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(i32, 0), output.receipt.exit_code);
    try std.testing.expectEqualStrings("success", output.receipt.status);
    try std.testing.expect(std.mem.indexOf(u8, output.stdout, "hello-local") != null);
}
