const std = @import("std");
const fx = @import("zigeffect");

test "root facade exposes domain namespaces and compatibility aliases" {
    const RootEffect = fx.Effect(u32, error{}, fx.TestServices);
    const DomainEffect = fx.effect.Effect(u32, error{}, fx.TestServices);
    try std.testing.expect(RootEffect == DomainEffect);

    try std.testing.expect(fx.Context(fx.TestServices) == fx.core.Context(fx.TestServices));
    try std.testing.expect(fx.Scope == fx.core.Scope);
    try std.testing.expect(fx.Runtime(fx.TestServices) == fx.runtime.Runtime(fx.TestServices));
    try std.testing.expect(fx.FiberRuntime(fx.TestServices) == fx.runtime.FiberRuntime(fx.TestServices));
    try std.testing.expect(fx.Layer(fx.TestServices) == fx.layer.Layer(fx.TestServices));
    try std.testing.expect(fx.Schedule == fx.effect.Schedule);
    try std.testing.expect(fx.Logger == fx.services.Logger);
    try std.testing.expect(fx.Config == fx.services.Config);
    try std.testing.expect(fx.Metrics == fx.services.Metrics);
    try std.testing.expect(fx.Tracing == fx.services.Tracing);
    try std.testing.expect(fx.MemoryFileSystem == fx.services.MemoryFileSystem);
    try std.testing.expect(fx.Clock == fx.services.Clock);
    try std.testing.expect(fx.IdGenerator == fx.services.IdGenerator);
    try std.testing.expect(fx.CausalExtensionDomain == fx.services.CausalExtensionDomain);
    try std.testing.expect(fx.TestEnv == fx.testing.TestEnv);
}
test "runtime backend boundary exposes deterministic capabilities" {
    const backend = fx.deterministicBackend();
    try std.testing.expectEqual(fx.BackendKind.deterministic, backend.kind);
    try std.testing.expect(!backend.can_suspend);
    try std.testing.expect(!backend.can_interrupt_blocking_io);
    try std.testing.expect(!backend.can_supervise);
    try std.testing.expect(!backend.can_parallel);
    try std.testing.expect(!backend.can_persist);
    try std.testing.expect(!backend.can_distribute);

    const durable = fx.durableLocalBackend();
    try std.testing.expectEqual(fx.BackendKind.durable_local, durable.kind);
    try std.testing.expect(durable.can_suspend);
    try std.testing.expect(durable.can_persist);
    try std.testing.expect(!durable.can_distribute);

    const async_backend = fx.asyncLocalBackend();
    try std.testing.expectEqual(fx.BackendKind.async_local, async_backend.kind);
    try std.testing.expect(async_backend.can_suspend);
    try std.testing.expect(async_backend.can_interrupt_blocking_io);
    try std.testing.expect(async_backend.can_parallel);

    const clustered = fx.clusteredBackend();
    try std.testing.expectEqual(fx.BackendKind.clustered, clustered.kind);
    try std.testing.expect(clustered.can_suspend);
    try std.testing.expect(clustered.can_persist);
    try std.testing.expect(clustered.can_distribute);

    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = env.runtime();
    try std.testing.expectEqual(fx.BackendKind.deterministic, runtime.backendCapabilities().kind);

    var fiber_runtime = fx.FiberRuntime(fx.TestServices).init(std.testing.allocator, &env.services);
    defer fiber_runtime.deinit();
    try std.testing.expectEqual(fx.BackendKind.deterministic, fiber_runtime.backendCapabilities().kind);
}

test "root facade exposes data match pattern and trait namespaces" {
    try std.testing.expect(fx.Option(u8) == fx.data.Option(u8));
    try std.testing.expect(fx.Either(u8, error{Bad}) == fx.data.Either(u8, error{Bad}));
    try std.testing.expect(fx.Duration == fx.data.Duration);
    try std.testing.expect(fx.BigDecimal == fx.data.BigDecimal);
    try std.testing.expect(fx.DateTime == fx.data.DateTime);
    try std.testing.expect(fx.Redacted([]const u8) == fx.data.Redacted([]const u8));
    try std.testing.expect(fx.Codec(u8) == fx.traits.Codec(u8));
    try std.testing.expect(@hasDecl(fx, "traits"));
    try std.testing.expect(@hasDecl(fx, "match"));
    try std.testing.expect(@hasDecl(fx, "pattern"));
}
