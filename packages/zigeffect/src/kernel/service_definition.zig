const service_mod = @import("service.zig");
const context_mod = @import("context.zig");
const layer_mod = @import("layer.zig");

/// Defines a service tag and its canonical live layer together. The returned
/// type is itself a service tag, so effects require `.{MyService}` directly.
///
/// Required fields:
/// - key: stable service identity
/// - API: abstract API value type
/// - Failure: typed acquisition error
/// - Requirements: construction-only service tags
/// - acquire: fn (*ContextView(Requirements)) Failure!API
///
/// Optional fields:
/// - release: fn (*API) void (makes the layer scoped)
/// - default_dependencies: fn () Layer (used by Default)
pub fn defineService(comptime definition: anytype) type {
    const Definition = @TypeOf(definition);
    inline for (.{ "key", "API", "Failure", "Requirements", "acquire" }) |field| {
        if (!@hasField(Definition, field)) {
            @compileError("zigeffect defineService missing field: " ++ field);
        }
    }
    if (definition.key.len == 0) @compileError("zigeffect service keys must not be empty");

    const has_release = @hasField(Definition, "release");
    const has_default_dependencies = @hasField(Definition, "default_dependencies");

    return struct {
        const Self = @This();

        pub const service_key = definition.key;
        pub const API = definition.API;
        pub const operations: []const []const u8 = if (@hasDecl(API, "operations"))
            API.operations
        else
            &.{};
        pub const FailureType = definition.Failure;
        pub const ConstructionRequirements = definition.Requirements;

        pub const WithoutDependenciesLayer = if (has_release)
            layer_mod.ScopedLayer(
                Self,
                FailureType,
                ConstructionRequirements,
                definition.acquire,
                definition.release,
            )
        else
            layer_mod.EffectLayer(
                Self,
                FailureType,
                ConstructionRequirements,
                definition.acquire,
            );

        pub const DefaultLayer = if (has_default_dependencies)
            layer_mod.ProvidedLayer(
                WithoutDependenciesLayer,
                @TypeOf(definition.default_dependencies()),
                false,
            )
        else
            WithoutDependenciesLayer;

        pub fn DefaultWithoutDependencies() WithoutDependenciesLayer {
            if (comptime has_release) {
                return layer_mod.Layer.scoped(
                    Self,
                    FailureType,
                    ConstructionRequirements,
                    definition.acquire,
                    definition.release,
                );
            }
            return layer_mod.Layer.effect(
                Self,
                FailureType,
                ConstructionRequirements,
                definition.acquire,
            );
        }

        pub fn Default() DefaultLayer {
            const live = DefaultWithoutDependencies();
            if (comptime has_default_dependencies) {
                const dependencies = definition.default_dependencies();
                if (comptime !service_mod.subset(ConstructionRequirements, @TypeOf(dependencies).OutputServices)) {
                    @compileError(
                        "zigeffect service Default dependencies do not provide every construction requirement",
                    );
                }
                return layer_mod.Layer.provide(live, dependencies);
            }
            if (comptime ConstructionRequirements.len != 0) {
                @compileError(
                    "zigeffect service has construction requirements but no default_dependencies factory; " ++
                        "use DefaultWithoutDependencies and wire the layer explicitly",
                );
            }
            return live;
        }

        comptime {
            service_mod.assertServiceTag(Self);
            const Acquire = @TypeOf(definition.acquire);
            const expected: *const fn (*context_mod.ContextView(ConstructionRequirements)) FailureType!API = definition.acquire;
            _ = Acquire;
            _ = expected;
            if (has_release) {
                const release: *const fn (*API) void = definition.release;
                _ = release;
            }
        }
    };
}
