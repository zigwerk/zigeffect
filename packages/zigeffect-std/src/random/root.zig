const std = @import("std");
const Capability = @import("../capability/root.zig");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const service_key = "zigeffect/default/Random";

pub const Service = struct {
    pointer: *anyopaque,
    fill_fn: *const fn (*anyopaque, []u8) void,
    pub fn from(comptime Provider: type, provider: *Provider) Service {
        return .{ .pointer = provider, .fill_fn = struct {
            fn fill(raw: *anyopaque, output: []u8) void {
                (@as(*Provider, @ptrCast(@alignCast(raw)))).fill(output);
            }
        }.fill };
    }
    pub fn fill(self: Service, output: []u8) void {
        self.fill_fn(self.pointer, output);
    }
    pub fn integer(self: Service, comptime T: type) T {
        var value: T = undefined;
        self.fill(std.mem.asBytes(&value));
        return value;
    }
};

pub const Crypto = struct {
    pub const capability = Capability.Descriptor{
        .id = "zigeffect-std.random.crypto",
        .kind = .randomness,
        .maturity = .production_candidate,
        .package = "zigeffect-std",
        .version = "0.1.0",
        .features = &.{"os-csprng"},
        .side_effects = .real,
        .conformance = .{ .schema = "zigeffect.system-primitives-conformance", .version = 1, .receipt = "conformance/system-primitives-live.v1.json", .authority = .live_external, .observed_at_ms = 1783777336000, .valid_until_ms = 1791553336000, .content_sha256 = "sha256:fddc0718cbc27865cde9292dddfd68e7ec0ba093c27954aa9242292001de4d49" },
    };
    io: std.Io,
    pub fn init(io: std.Io) Crypto {
        return .{ .io = io };
    }
    pub fn asService(self: *Crypto) Service {
        return Service.from(Crypto, self);
    }
    pub fn asDefault(self: *Crypto) fx.kernel.Random {
        return fx.kernel.Random.from(Crypto, self);
    }
    pub fn fill(self: *Crypto, output: []u8) void {
        self.io.random(output);
    }
};

pub const Deterministic = struct {
    pub const capability = Capability.Descriptor{
        .id = "zigeffect-std.random.deterministic",
        .kind = .randomness,
        .maturity = .deterministic_model,
        .package = "zigeffect-std",
        .version = "0.1.0",
        .features = &.{"seeded"},
        .side_effects = .modeled,
    };
    generator: std.Random.DefaultPrng,
    mutex: std.atomic.Mutex = .unlocked,
    pub fn init(seed: u64) Deterministic {
        return .{ .generator = .init(seed) };
    }
    pub fn asService(self: *Deterministic) Service {
        return Service.from(Deterministic, self);
    }
    pub fn asDefault(self: *Deterministic) fx.kernel.Random {
        return fx.kernel.Random.from(Deterministic, self);
    }
    pub fn fill(self: *Deterministic, output: []u8) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
        defer self.mutex.unlock();
        self.generator.random().bytes(output);
    }
};

pub fn fill(output: []u8) fx.kernel.Effect(void, error{}, .{}).Stateful([]u8) {
    return fx.kernel.Effect(void, error{}, .{}).fromState([]u8, output, struct {
        fn run(target: []u8, ctx: *fx.kernel.ContextView(.{})) error{}!void {
            ctx.random().fill(target);
            _ = StdService.recordSemantic(
                ctx,
                .span_recorded,
                service_key,
                "Random.fill",
                "success",
                "filled bounded caller-owned bytes",
            );
        }
    }.run);
}

pub fn integer(comptime T: type) fx.kernel.Effect(T, error{}, .{}) {
    return fx.kernel.Effect(T, error{}, .{}).fromFn(struct {
        fn run(ctx: *fx.kernel.ContextView(.{})) error{}!T {
            const value = ctx.random().integer(T);
            _ = StdService.recordSemantic(
                ctx,
                .span_recorded,
                service_key,
                "Random.integer",
                "success",
                @typeName(T),
            );
            return value;
        }
    }.run);
}

test "deterministic randomness exactly replays a seed" {
    var first = Deterministic.init(42);
    var second = Deterministic.init(42);
    var left: [64]u8 = undefined;
    var right: [64]u8 = undefined;
    first.fill(&left);
    second.fill(&right);
    try std.testing.expectEqualSlices(u8, &left, &right);
}

test "Randomness effects replay through deterministic default-service overrides" {
    var first = Deterministic.init(42);
    var second = Deterministic.init(42);
    const root = fx.kernel.Layer.empty();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{});
    defer runtime.deinit();

    const left = try runtime.run(integer(u64).withDefaults(.{ .random = first.asDefault() }));
    const right = try runtime.run(integer(u64).withDefaults(.{ .random = second.asDefault() }));
    try std.testing.expectEqual(left, right);
}
