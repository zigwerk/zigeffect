const std = @import("std");
const Capability = @import("../capability/root.zig");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const service_key = "zigeffect/default/Clock";

pub const Instant = struct {
    millis: u64,
};

pub const Snapshot = struct { wall_millis: u64, monotonic_nanos: i128 };

pub const Service = struct {
    pointer: *anyopaque,
    wall_fn: *const fn (*anyopaque) u64,
    monotonic_fn: *const fn (*anyopaque) i128,
    sleep_fn: *const fn (*anyopaque, u64) anyerror!void,

    pub fn from(comptime Provider: type, provider: *Provider) Service {
        return .{
            .pointer = provider,
            .wall_fn = struct {
                fn call(raw: *anyopaque) u64 {
                    return (@as(*Provider, @ptrCast(@alignCast(raw)))).wallMillis();
                }
            }.call,
            .monotonic_fn = struct {
                fn call(raw: *anyopaque) i128 {
                    return (@as(*Provider, @ptrCast(@alignCast(raw)))).monotonicNanos();
                }
            }.call,
            .sleep_fn = struct {
                fn call(raw: *anyopaque, millis: u64) anyerror!void {
                    return (@as(*Provider, @ptrCast(@alignCast(raw)))).sleepMillis(millis);
                }
            }.call,
        };
    }

    pub fn snapshot(self: Service) Snapshot {
        return .{ .wall_millis = self.wall_fn(self.pointer), .monotonic_nanos = self.monotonic_fn(self.pointer) };
    }
    pub fn sleepMillis(self: Service, millis: u64) !void {
        return self.sleep_fn(self.pointer, millis);
    }
};

pub const RealClock = struct {
    pub const capability = Capability.Descriptor{
        .id = "zigeffect-std.clock.system",
        .kind = .clock,
        .maturity = .production_candidate,
        .package = "zigeffect-std",
        .version = "0.1.0",
        .features = &.{ "wall", "monotonic", "sleep" },
        .side_effects = .real,
        .conformance = .{ .schema = "zigeffect.system-primitives-conformance", .version = 1, .receipt = "conformance/system-primitives-live.v1.json", .authority = .live_external, .observed_at_ms = 1783777336000, .valid_until_ms = 1791553336000, .content_sha256 = "sha256:fddc0718cbc27865cde9292dddfd68e7ec0ba093c27954aa9242292001de4d49" },
    };

    io: std.Io,
    pub fn init(io: std.Io) RealClock {
        return .{ .io = io };
    }
    pub fn asService(self: *RealClock) Service {
        return Service.from(RealClock, self);
    }
    pub fn wallMillis(_: *RealClock) u64 {
        var value: std.c.timeval = undefined;
        if (std.c.gettimeofday(&value, null) != 0 or value.sec < 0) return 0;
        return @as(u64, @intCast(value.sec)) * std.time.ms_per_s + @as(u64, @intCast(@divTrunc(value.usec, std.time.us_per_ms)));
    }
    pub fn monotonicNanos(self: *RealClock) i128 {
        return std.Io.Clock.awake.now(self.io).nanoseconds;
    }
    pub fn sleepMillis(self: *RealClock, millis: u64) !void {
        try (std.Io.Clock.Duration{ .raw = .fromMilliseconds(@intCast(millis)), .clock = .awake }).sleep(self.io);
    }
};

pub const FakeClock = struct {
    pub const capability = Capability.Builtin.fake_clock;

    current_millis: u64,
    slept_millis: u64 = 0,
    sleep_count: usize = 0,

    pub fn init(start_millis: u64) FakeClock {
        return .{ .current_millis = start_millis };
    }

    pub fn now(self: FakeClock) Instant {
        return .{ .millis = self.current_millis };
    }

    pub fn asService(self: *FakeClock) Service {
        return Service.from(FakeClock, self);
    }
    pub fn wallMillis(self: *FakeClock) u64 {
        return self.current_millis;
    }
    pub fn monotonicNanos(self: *FakeClock) i128 {
        return @as(i128, self.current_millis) * std.time.ns_per_ms;
    }
    pub fn sleepMillis(self: *FakeClock, millis: u64) !void {
        self.sleep(millis);
    }

    pub fn advance(self: *FakeClock, millis: u64) void {
        self.current_millis += millis;
    }

    pub fn sleep(self: *FakeClock, millis: u64) void {
        self.slept_millis += millis;
        self.sleep_count += 1;
        self.advance(millis);
    }
};

/// Reads the active runtime Clock reference. Like Effect's Clock reference,
/// this is a default service and therefore adds no explicit requirement.
pub fn currentTimeMillis() fx.kernel.Effect(u64, error{}, .{}) {
    return fx.kernel.Effect(u64, error{}, .{}).fromFn(struct {
        fn run(ctx: *fx.kernel.ContextView(.{})) error{}!u64 {
            const value = ctx.clock().nowMs();
            _ = StdService.recordSemantic(
                ctx,
                .span_recorded,
                service_key,
                "Clock.currentTimeMillis",
                "success",
                "read active runtime clock",
            );
            return value;
        }
    }.run);
}

pub fn sleep(millis: u64) fx.kernel.Effect(void, error{}, .{}).Stateful(u64) {
    return fx.kernel.Effect(void, error{}, .{}).fromState(u64, millis, struct {
        fn run(delay: u64, ctx: *fx.kernel.ContextView(.{})) error{}!void {
            const scheduled = ctx.recordCausal(.{
                .kind = .timer_scheduled,
                .service_key = service_key,
                .label = "Clock.sleep",
                .status = "scheduled",
                .redacted_detail = "bounded delay",
            });
            ctx.clock().sleep(delay);
            _ = ctx.recordCausal(.{
                .kind = .timer_fired,
                .parent_id = scheduled,
                .service_key = service_key,
                .label = "Clock.sleep",
                .status = "success",
                .redacted_detail = "delay completed",
            });
        }
    }.run);
}

test "Clock fake advances and records sleeps" {
    var clock = FakeClock.init(100);

    try std.testing.expectEqual(@as(u64, 100), clock.now().millis);
    clock.advance(25);
    try std.testing.expectEqual(@as(u64, 125), clock.now().millis);
    clock.sleep(50);
    try std.testing.expectEqual(@as(u64, 175), clock.now().millis);
    try std.testing.expectEqual(@as(u64, 50), clock.slept_millis);
    try std.testing.expectEqual(@as(usize, 1), clock.sleep_count);
}

test "Clock service has equivalent deterministic wall monotonic and sleep decisions" {
    var clock = FakeClock.init(1_000);
    const service = clock.asService();
    try service.sleepMillis(25);
    const snapshot = service.snapshot();
    try std.testing.expectEqual(@as(u64, 1_025), snapshot.wall_millis);
    try std.testing.expectEqual(@as(i128, 1_025 * std.time.ns_per_ms), snapshot.monotonic_nanos);
}

test "Clock default service effects compose through one ManagedRuntime" {
    var clock = fx.kernel.Clock.fake(1_000);
    const root = fx.kernel.Layer.empty();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{});
    defer runtime.deinit();

    try runtime.run(sleep(25).withClock(&clock));
    const current = try runtime.run(currentTimeMillis().withClock(&clock));
    try std.testing.expectEqual(@as(u64, 1_025), current);
}
