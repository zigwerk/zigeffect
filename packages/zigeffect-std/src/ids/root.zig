const std = @import("std");
const Capability = @import("../capability/root.zig");
const Clock = @import("../clock/root.zig");
const Random = @import("../random/root.zig");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const capability = Capability.Descriptor{
    .id = "zigeffect-std.ids.uuid7-ulid",
    .kind = .ids,
    .maturity = .production_candidate,
    .package = "zigeffect-std",
    .version = "0.1.0",
    .features = &.{ "uuid-v7", "ulid", "monotonic-ulid" },
    .side_effects = .real,
    .conformance = .{ .schema = "zigeffect.system-primitives-conformance", .version = 1, .receipt = "conformance/system-primitives-live.v1.json", .authority = .live_external, .observed_at_ms = 1783777336000, .valid_until_ms = 1791553336000, .content_sha256 = "sha256:fddc0718cbc27865cde9292dddfd68e7ec0ba093c27954aa9242292001de4d49" },
};

pub const Service = struct {
    pointer: *anyopaque,
    uuid_v7_fn: *const fn (*anyopaque) [36]u8,
    ulid_fn: *const fn (*anyopaque) [26]u8,

    pub fn from(comptime Implementation: type, implementation: *Implementation) Service {
        return .{
            .pointer = implementation,
            .uuid_v7_fn = struct {
                fn call(raw: *anyopaque) [36]u8 {
                    return (@as(*Implementation, @ptrCast(@alignCast(raw)))).uuidV7();
                }
            }.call,
            .ulid_fn = struct {
                fn call(raw: *anyopaque) [26]u8 {
                    return (@as(*Implementation, @ptrCast(@alignCast(raw)))).ulid();
                }
            }.call,
        };
    }

    pub fn uuidV7(self: Service) [36]u8 {
        return self.uuid_v7_fn(self.pointer);
    }
    pub fn ulid(self: Service) [26]u8 {
        return self.ulid_fn(self.pointer);
    }
};

pub const Provider = struct {
    clock: Clock.Service,
    randomness: Random.Service,
    mutex: std.atomic.Mutex = .unlocked,
    last_ulid_ms: u64 = 0,
    last_ulid_random: [10]u8 = .{0} ** 10,

    pub fn init(clock: Clock.Service, randomness: Random.Service) Provider {
        return .{ .clock = clock, .randomness = randomness };
    }
    pub fn asService(self: *Provider) Service {
        return Service.from(Provider, self);
    }

    pub fn uuidV7(self: *Provider) [36]u8 {
        var bytes: [16]u8 = undefined;
        self.randomness.fill(&bytes);
        const timestamp = self.clock.snapshot().wall_millis & 0x0000_ffff_ffff_ffff;
        bytes[0] = @intCast((timestamp >> 40) & 0xff);
        bytes[1] = @intCast((timestamp >> 32) & 0xff);
        bytes[2] = @intCast((timestamp >> 24) & 0xff);
        bytes[3] = @intCast((timestamp >> 16) & 0xff);
        bytes[4] = @intCast((timestamp >> 8) & 0xff);
        bytes[5] = @intCast(timestamp & 0xff);
        bytes[6] = (bytes[6] & 0x0f) | 0x70;
        bytes[8] = (bytes[8] & 0x3f) | 0x80;
        var output: [36]u8 = undefined;
        const hex = "0123456789abcdef";
        var source: usize = 0;
        var target: usize = 0;
        while (source < bytes.len) : (source += 1) {
            if (target == 8 or target == 13 or target == 18 or target == 23) {
                output[target] = '-';
                target += 1;
            }
            output[target] = hex[bytes[source] >> 4];
            output[target + 1] = hex[bytes[source] & 0x0f];
            target += 2;
        }
        return output;
    }

    pub fn ulid(self: *Provider) [26]u8 {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
        defer self.mutex.unlock();
        const millis = self.clock.snapshot().wall_millis;
        if (millis > self.last_ulid_ms) {
            self.last_ulid_ms = millis;
            self.randomness.fill(&self.last_ulid_random);
        } else {
            var index: usize = self.last_ulid_random.len;
            while (index > 0) {
                index -= 1;
                self.last_ulid_random[index] +%= 1;
                if (self.last_ulid_random[index] != 0) break;
            }
        }
        var bytes: [16]u8 = undefined;
        const timestamp = self.last_ulid_ms & 0x0000_ffff_ffff_ffff;
        bytes[0] = @intCast((timestamp >> 40) & 0xff);
        bytes[1] = @intCast((timestamp >> 32) & 0xff);
        bytes[2] = @intCast((timestamp >> 24) & 0xff);
        bytes[3] = @intCast((timestamp >> 16) & 0xff);
        bytes[4] = @intCast((timestamp >> 8) & 0xff);
        bytes[5] = @intCast(timestamp & 0xff);
        @memcpy(bytes[6..], &self.last_ulid_random);
        return encodeUlid(bytes);
    }
};

pub fn UuidV7Effect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = [36]u8;
        pub const FailureType = error{};
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Service};
        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }
        pub fn run(_: @This(), ctx: *fx.Context(EffectEnv)) error{}![36]u8 {
            const result = ctx.service(Service).uuidV7();
            _ = StdService.recordOperation(ctx, Service, "ids.uuid-v7", "success", "generated UUIDv7");
            return result;
        }
    };
}

pub fn UlidEffect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = [26]u8;
        pub const FailureType = error{};
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Service};
        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }
        pub fn run(_: @This(), ctx: *fx.Context(EffectEnv)) error{}![26]u8 {
            const result = ctx.service(Service).ulid();
            _ = StdService.recordOperation(ctx, Service, "ids.ulid", "success", "generated monotonic ULID");
            return result;
        }
    };
}

pub fn uuidV7Effect(comptime EffectEnv: type) UuidV7Effect(EffectEnv) {
    return .{};
}
pub fn ulidEffect(comptime EffectEnv: type) UlidEffect(EffectEnv) {
    return .{};
}

fn encodeUlid(bytes: [16]u8) [26]u8 {
    const alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
    var output: [26]u8 = undefined;
    for (0..26) |character| {
        var value: u8 = 0;
        for (0..5) |bit| {
            const virtual_bit: isize = @as(isize, @intCast(character * 5 + bit)) - 2;
            value <<= 1;
            if (virtual_bit >= 0 and virtual_bit < 128) {
                const source: usize = @intCast(virtual_bit);
                value |= (bytes[source / 8] >> @intCast(7 - source % 8)) & 1;
            }
        }
        output[character] = alphabet[value];
    }
    return output;
}

test "UUIDv7 and ULID decisions replay and stay ordered" {
    var clock = Clock.FakeClock.init(1_700_000_000_000);
    var first_random = Random.Deterministic.init(7);
    var second_random = Random.Deterministic.init(7);
    var first = Provider.init(clock.asService(), first_random.asService());
    var second = Provider.init(clock.asService(), second_random.asService());
    const first_uuid = first.uuidV7();
    const second_uuid = second.uuidV7();
    try std.testing.expectEqualSlices(u8, &first_uuid, &second_uuid);
    const earlier = first.ulid();
    const later = first.ulid();
    try std.testing.expect(std.mem.order(u8, &earlier, &later) == .lt);
    const versioned = first.uuidV7();
    try std.testing.expectEqual(@as(u8, '7'), versioned[14]);
}

test "ID effects use the declared ID service through a layer graph" {
    var clock = Clock.FakeClock.init(1_700_000_000_000);
    var random = Random.Deterministic.init(7);
    var ids = Provider.init(clock.asService(), random.asService());
    var service_provider = StdService.ValueProvider(Service).init(ids.asService());
    const ids_layer = service_provider.layer();
    const EnvType = fx.LayerGraphEnv(@TypeOf(.{ids_layer}));
    var graph = fx.layerGraph(std.testing.allocator, .{ids_layer});
    defer graph.deinit();

    const uuid = try graph.run(uuidV7Effect(EnvType));
    const ulid_value = try graph.run(ulidEffect(EnvType));
    try std.testing.expectEqual(@as(u8, '7'), uuid[14]);
    try std.testing.expectEqual(@as(usize, 26), ulid_value.len);
}
