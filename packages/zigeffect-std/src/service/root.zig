const std = @import("std");
const fx = @import("zigeffect");
const Console = @import("../console/root.zig");
const EnvModule = @import("../env/root.zig");

pub fn Env(comptime services: anytype) type {
    return fx.ServiceEnv(services);
}

pub fn Provider(comptime services: anytype) type {
    const ServiceEnv = fx.ServiceEnv(services);
    const ServicePointers = ServiceEnv.ServicePointers;

    return struct {
        const Self = @This();
        pub const Services = services;

        services: ServicePointers,

        pub fn init(service_pointers: ServicePointers) Self {
            return .{ .services = service_pointers };
        }

        pub fn service(self: *Self, comptime Requested: type) *Requested {
            inline for (services, 0..) |Service, index| {
                if (Requested == Service) return self.services[index];
            }
            return fx.serviceNotFound(Self, Requested);
        }

        pub fn providedServices(self: *const Self, allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            _ = self;
            return fx.ServiceSet.fromTypes(allocator, services);
        }

        pub fn layer(self: *Self) @TypeOf(layerFromEnv(Self, self, services)) {
            return layerFromEnv(Self, self, services);
        }
    };
}

pub fn layerFromEnv(
    comptime ProviderEnv: type,
    env: *ProviderEnv,
    comptime services: anytype,
) @TypeOf(fx.Layer(ProviderEnv).fromEnv(env).provides(services)) {
    return fx.Layer(ProviderEnv).fromEnv(env).provides(services);
}

pub fn access(comptime Service: type, comptime EffectEnv: type) @TypeOf(
    fx.Effect(*Service, error{}, EffectEnv)
        .fromFn(struct {
            fn run(ctx: *fx.Context(EffectEnv)) error{}!*Service {
                return ctx.service(Service);
            }
        }.run)
        .requires(.{Service}),
) {
    return fx.Effect(*Service, error{}, EffectEnv)
        .fromFn(struct {
            fn run(ctx: *fx.Context(EffectEnv)) error{}!*Service {
                return ctx.service(Service);
            }
        }.run)
        .requires(.{Service});
}

pub fn serviceKey(comptime Service: type) []const u8 {
    return @typeName(Service);
}

pub fn recordRequired(ctx: anytype, comptime Service: type, detail: []const u8) ?u64 {
    return ctx.recordCausal(.{
        .kind = .service_required,
        .service_key = serviceKey(Service),
        .status = "required",
        .redacted_detail = detail,
    });
}

pub fn recordProvided(ctx: anytype, comptime Service: type, detail: []const u8) ?u64 {
    return ctx.recordCausal(.{
        .kind = .service_provided,
        .service_key = serviceKey(Service),
        .status = "provided",
        .redacted_detail = detail,
    });
}

pub fn recordOperation(
    ctx: anytype,
    comptime Service: type,
    operation: []const u8,
    status: []const u8,
    detail: []const u8,
) ?u64 {
    return ctx.recordCausal(.{
        .kind = .span_recorded,
        .service_key = serviceKey(Service),
        .label = operation,
        .status = status,
        .redacted_detail = detail,
    });
}

const TestEnv = Env(.{Console.CapturedConsole});
const TestError = error{OutOfMemory};

fn readConsole(ctx: *fx.Context(TestEnv)) TestError![]const u8 {
    const console = ctx.service(Console.CapturedConsole);
    return console.stdoutText();
}

const ReadConsole = fx.Effect([]const u8, TestError, TestEnv)
    .fromFn(readConsole)
    .requires(.{Console.CapturedConsole});

test "Service.Provider resolves multiple services and exposes metadata" {
    var console = Console.CapturedConsole.init(std.testing.allocator);
    defer console.deinit();
    var env = EnvModule.EnvMap.init(std.testing.allocator);
    defer env.deinit();

    const StdProvider = Provider(.{ Console.CapturedConsole, EnvModule.EnvMap });
    var provider = StdProvider.init(.{ &console, &env });

    try provider.service(Console.CapturedConsole).writeOut("ready");
    try provider.service(EnvModule.EnvMap).put("MODE", "test");

    try std.testing.expectEqualStrings("ready", console.stdoutText());
    try std.testing.expectEqualStrings("test", env.get("MODE").?);

    var provided = try provider.providedServices(std.testing.allocator);
    defer provided.deinit();

    try std.testing.expect(provided.contains(@typeName(Console.CapturedConsole)));
    try std.testing.expect(provided.contains(@typeName(EnvModule.EnvMap)));
}

test "Service.layerFromEnv provides services through fx.Layer" {
    var console = Console.CapturedConsole.init(std.testing.allocator);
    defer console.deinit();
    try console.writeOut("layer-output");

    var provider = Provider(.{Console.CapturedConsole}).init(.{&console});
    const layer = layerFromEnv(@TypeOf(provider), &provider, .{Console.CapturedConsole});

    try std.testing.expectEqualStrings("layer-output", try layer.provide(std.testing.allocator, ReadConsole));
}

test "Service.access returns an effect that requires and resolves the service" {
    var console = Console.CapturedConsole.init(std.testing.allocator);
    defer console.deinit();
    try console.writeOut("access-output");

    var provider = Provider(.{Console.CapturedConsole}).init(.{&console});
    var runtime = fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{Console.CapturedConsole});

    const AccessConsole = access(Console.CapturedConsole, @TypeOf(provider));
    var required = try AccessConsole.requiredServices(std.testing.allocator);
    defer required.deinit();

    try std.testing.expect(required.contains(@typeName(Console.CapturedConsole)));
    const resolved = try runtime.run(AccessConsole);
    try std.testing.expectEqualStrings("access-output", resolved.stdoutText());
}

test "Service.access participates in runtime dependency validation" {
    var console = Console.CapturedConsole.init(std.testing.allocator);
    defer console.deinit();

    var provider = Provider(.{Console.CapturedConsole}).init(.{&console});
    var runtime = fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider);

    const AccessConsole = access(Console.CapturedConsole, @TypeOf(provider));
    try std.testing.expectError(error.MissingServiceRequirement, runtime.run(AccessConsole));
}

test "Service records required provided and operation causal facts" {
    var console = Console.CapturedConsole.init(std.testing.allocator);
    defer console.deinit();
    var provider = Provider(.{Console.CapturedConsole}).init(.{&console});

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var scope = fx.Scope.init(std.testing.allocator);
    defer scope.deinit();

    var ctx = fx.Context(@TypeOf(provider)).init(std.testing.allocator, &provider, &scope)
        .withCausalStore(&store);

    _ = recordRequired(&ctx, Console.CapturedConsole, "read stdout");
    _ = recordProvided(&ctx, Console.CapturedConsole, "fake console");
    _ = recordOperation(&ctx, Console.CapturedConsole, "writeOut", "success", "wrote line");

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expectEqual(@as(usize, 3), snapshot.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.service_required, snapshot.events[0].kind);
    try std.testing.expectEqualStrings(serviceKey(Console.CapturedConsole), snapshot.events[0].service_key);
    try std.testing.expectEqual(fx.CausalEventKind.service_provided, snapshot.events[1].kind);
    try std.testing.expectEqualStrings(serviceKey(Console.CapturedConsole), snapshot.events[1].service_key);
    try std.testing.expectEqual(fx.CausalEventKind.span_recorded, snapshot.events[2].kind);
    try std.testing.expectEqualStrings("writeOut", snapshot.events[2].label);
    try std.testing.expectEqualStrings("success", snapshot.events[2].status);
}

test "Service operation details are redacted by the causal store" {
    var console = Console.CapturedConsole.init(std.testing.allocator);
    defer console.deinit();
    var provider = Provider(.{Console.CapturedConsole}).init(.{&console});

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var scope = fx.Scope.init(std.testing.allocator);
    defer scope.deinit();

    var ctx = fx.Context(@TypeOf(provider)).init(std.testing.allocator, &provider, &scope)
        .withCausalStore(&store);

    _ = recordOperation(&ctx, Console.CapturedConsole, "writeOut", "success", "token=abc123");

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expect(std.mem.indexOf(u8, snapshot.events[0].redacted_detail, "abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, snapshot.events[0].redacted_detail, "redacted") != null);
}
