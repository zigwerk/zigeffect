const std = @import("std");
const fx = @import("zigeffect");

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

/// Owns one service-interface value and exposes it as a layer environment.
/// This is the compact composition path for vtable-style std services such as
/// Clock.Service or Http.Client. The underlying implementation still owns its
/// own lifetime unless it was acquired by a scoped layer builder.
pub fn ValueProvider(comptime Service: type) type {
    return struct {
        const Self = @This();

        value: Service,

        pub fn init(value: Service) Self {
            return .{ .value = value };
        }

        pub fn service(self: *Self, comptime Requested: type) *Requested {
            if (Requested == Service) return &self.value;
            return fx.serviceNotFound(Self, Requested);
        }

        pub fn providedServices(self: *const Self, allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            _ = self;
            return fx.ServiceSet.fromTypes(allocator, .{Service});
        }

        pub fn layer(self: *Self) @TypeOf(layerFromEnv(Self, self, .{Service})) {
            return layerFromEnv(Self, self, .{Service});
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

/// Semantic operation identity returned by `beginOperation`. Completion facts
/// point directly at this event, so an application snapshot can reconstruct an
/// external call without log-message correlation.
pub const Operation = struct {
    event_id: ?u64,
    service_key: []const u8,
    label: []const u8,
};

pub fn beginOperation(
    ctx: anytype,
    stable_service_key: []const u8,
    label: []const u8,
    redacted_detail: []const u8,
) Operation {
    return .{
        .event_id = ctx.recordCausal(.{
            .kind = .io_wait_started,
            .service_key = stable_service_key,
            .label = label,
            .status = "running",
            .redacted_detail = redacted_detail,
        }),
        .service_key = stable_service_key,
        .label = label,
    };
}

pub fn completeOperation(
    ctx: anytype,
    operation: Operation,
    status: []const u8,
    redacted_detail: []const u8,
) ?u64 {
    return ctx.recordCausal(.{
        .kind = .io_completed,
        .parent_id = operation.event_id,
        .cause_event_id = if (std.mem.eql(u8, status, "failure")) operation.event_id else null,
        .service_key = operation.service_key,
        .label = operation.label,
        .status = status,
        .redacted_detail = redacted_detail,
    });
}

pub fn recordSemantic(
    ctx: anytype,
    kind: fx.CausalEventKind,
    stable_service_key: []const u8,
    label: []const u8,
    status: []const u8,
    redacted_detail: []const u8,
) ?u64 {
    return ctx.recordCausal(.{
        .kind = kind,
        .service_key = stable_service_key,
        .label = label,
        .status = status,
        .redacted_detail = redacted_detail,
    });
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

pub fn findOperation(
    snapshot: anytype,
    comptime Service: type,
    operation: []const u8,
    status: ?[]const u8,
) ?usize {
    for (snapshot.events, 0..) |event, index| {
        if (event.kind != fx.CausalEventKind.span_recorded) continue;
        if (!std.mem.eql(u8, event.service_key, serviceKey(Service))) continue;
        if (!std.mem.eql(u8, event.label, operation)) continue;
        if (status) |expected_status| {
            if (!std.mem.eql(u8, event.status, expected_status)) continue;
        }
        return index;
    }
    return null;
}

pub fn hasOperation(snapshot: anytype, comptime Service: type, operation: []const u8, status: ?[]const u8) bool {
    return findOperation(snapshot, Service, operation, status) != null;
}

const TestConsole = struct {
    output: []const u8 = "",
    fn writeOut(self: *TestConsole, text_value: []const u8) void {
        self.output = text_value;
    }
    fn stdoutText(self: TestConsole) []const u8 {
        return self.output;
    }
};

const TestEnv = struct {
    mode: ?[]const u8 = null,
    fn put(self: *TestEnv, name: []const u8, value: []const u8) void {
        if (std.mem.eql(u8, name, "MODE")) self.mode = value;
    }
    fn get(self: TestEnv, name: []const u8) ?[]const u8 {
        return if (std.mem.eql(u8, name, "MODE")) self.mode else null;
    }
};

test "Service.Provider resolves multiple services and exposes metadata" {
    var console = TestConsole{};
    var env = TestEnv{};

    const StdProvider = Provider(.{ TestConsole, TestEnv });
    var provider = StdProvider.init(.{ &console, &env });

    provider.service(TestConsole).writeOut("ready");
    provider.service(TestEnv).put("MODE", "test");

    try std.testing.expectEqualStrings("ready", console.stdoutText());
    try std.testing.expectEqualStrings("test", env.get("MODE").?);

    var provided = try provider.providedServices(std.testing.allocator);
    defer provided.deinit();

    try std.testing.expect(provided.contains(@typeName(TestConsole)));
    try std.testing.expect(provided.contains(@typeName(TestEnv)));
}

test "Service.ValueProvider owns an interface value and supplies it through a layer graph" {
    const Greeting = struct { prefix: []const u8 };
    var provider = ValueProvider(Greeting).init(.{ .prefix = "hello" });
    const service_layer = provider.layer();
    const Layers = @TypeOf(.{service_layer});
    const EnvType = fx.LayerGraphEnv(Layers);
    var graph = fx.layerGraph(std.testing.allocator, .{service_layer});
    defer graph.deinit();

    const resolved = try graph.run(access(Greeting, EnvType));
    try std.testing.expectEqualStrings("hello", resolved.prefix);
}

test "layer graph composition records layer effect service and scope facts automatically" {
    const Greeting = struct { prefix: []const u8 };
    const GreetingProvider = Provider(.{Greeting});
    var greeting = Greeting{ .prefix = "hello" };
    var provider = GreetingProvider.init(.{&greeting});
    const service_layer = provider.layer();
    const Layers = @TypeOf(.{service_layer});
    const EnvType = fx.LayerGraphEnv(Layers);
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var graph = fx.layerGraph(std.testing.allocator, .{service_layer}).withCausalStore(&store);
    defer graph.deinit();

    const resolved = try graph.run(access(Greeting, EnvType));
    try std.testing.expectEqualStrings("hello", resolved.prefix);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    var saw_layer = false;
    var saw_effect = false;
    var saw_scope = false;
    var service_parent: ?u64 = null;
    for (snapshot.events) |event| {
        if (event.kind == .layer_started) saw_layer = true;
        if (event.kind == .effect_started) saw_effect = true;
        if (event.kind == .scope_closed and std.mem.eql(u8, event.status, "success")) saw_scope = true;
        if (event.kind == .service_required and std.mem.eql(u8, event.service_key, @typeName(Greeting)) and std.mem.eql(u8, event.status, "resolved")) {
            service_parent = event.parent_id;
        }
    }
    try std.testing.expect(saw_layer);
    try std.testing.expect(saw_effect);
    try std.testing.expect(saw_scope);
    try std.testing.expect(service_parent != null);
}

test "Service.layerFromEnv provides services through fx.Layer" {
    var console = TestConsole{};
    console.writeOut("layer-output");

    var provider = Provider(.{TestConsole}).init(.{&console});
    const layer = layerFromEnv(@TypeOf(provider), &provider, .{TestConsole});
    const ProviderEnv = @TypeOf(provider);
    const ReadConsole = fx.Effect([]const u8, error{}, ProviderEnv)
        .fromFn(struct {
            fn run(ctx: *fx.Context(ProviderEnv)) error{}![]const u8 {
                return ctx.service(TestConsole).stdoutText();
            }
        }.run)
        .requires(.{TestConsole});

    try std.testing.expectEqualStrings("layer-output", try layer.provide(std.testing.allocator, ReadConsole));
}

test "Service.access returns an effect that requires and resolves the service" {
    var console = TestConsole{};
    console.writeOut("access-output");

    var provider = Provider(.{TestConsole}).init(.{&console});
    var runtime = fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{TestConsole});

    const AccessConsole = access(TestConsole, @TypeOf(provider));
    var required = try @TypeOf(AccessConsole).requiredServices(std.testing.allocator);
    defer required.deinit();

    try std.testing.expect(required.contains(@typeName(TestConsole)));
    const resolved = try runtime.run(AccessConsole);
    try std.testing.expectEqualStrings("access-output", resolved.stdoutText());
}

test "Service.access participates in runtime dependency validation" {
    var console = TestConsole{};

    var provider = Provider(.{TestConsole}).init(.{&console});
    var runtime = fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider);

    const AccessConsole = access(TestConsole, @TypeOf(provider));
    try std.testing.expectError(error.MissingServiceRequirement, runtime.run(AccessConsole));
}

test "Service records required provided and operation causal facts" {
    var console = TestConsole{};
    var provider = Provider(.{TestConsole}).init(.{&console});

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var scope = fx.Scope.init(std.testing.allocator);
    defer scope.deinit();

    var ctx = fx.Context(@TypeOf(provider)).init(std.testing.allocator, &provider, &scope)
        .withCausalStore(&store);

    _ = recordRequired(&ctx, TestConsole, "read stdout");
    _ = recordProvided(&ctx, TestConsole, "fake console");
    _ = recordOperation(&ctx, TestConsole, "writeOut", "success", "wrote line");

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expectEqual(@as(usize, 3), snapshot.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.service_required, snapshot.events[0].kind);
    try std.testing.expectEqualStrings(serviceKey(TestConsole), snapshot.events[0].service_key);
    try std.testing.expectEqual(fx.CausalEventKind.service_provided, snapshot.events[1].kind);
    try std.testing.expectEqualStrings(serviceKey(TestConsole), snapshot.events[1].service_key);
    try std.testing.expectEqual(fx.CausalEventKind.span_recorded, snapshot.events[2].kind);
    try std.testing.expectEqualStrings("writeOut", snapshot.events[2].label);
    try std.testing.expectEqualStrings("success", snapshot.events[2].status);
}

test "Service operation details are redacted by the causal store" {
    var console = TestConsole{};
    var provider = Provider(.{TestConsole}).init(.{&console});

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var scope = fx.Scope.init(std.testing.allocator);
    defer scope.deinit();

    var ctx = fx.Context(@TypeOf(provider)).init(std.testing.allocator, &provider, &scope)
        .withCausalStore(&store);

    _ = recordOperation(&ctx, TestConsole, "writeOut", "success", "token=abc123");

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expect(std.mem.indexOf(u8, snapshot.events[0].redacted_detail, "abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, snapshot.events[0].redacted_detail, "redacted") != null);
}
