# ZigEffect Effectful Package Platform Implementation Plan

Date: 2026-07-15
Design: `docs/superpowers/specs/2026-07-15-zigeffect-effectful-package-platform-design.md`

1. Capture the current first-party package inventory and legacy-symbol counts.
2. Add a failing repository architecture gate for CLI scaffold invariants,
   runtime/graph ownership, Testing v2, and ratcheted legacy usage.
3. Add failing standard-library tests for a stable portable gRPC client tag,
   canonical call effect, deterministic layer substitution, and causal facts.
4. Add failing native gRPC tests for scoped registry/channel/server layers,
   generated requirement-typed handler effects, route layers, runtime-handle
   child execution, and application-map/graph evidence.
5. Replace `GeneratedEffectServer(..., Env)` with a requirements-limited
   generated adapter and remove manual request scopes.
6. Replace persistent channel, pool, registry, and native server
   `LayerWithError` environments with canonical scoped layers.
7. Rewrite the Cloud Run example as one generated-style root layer and one
   `zstd.ManagedRuntime`; retain transport internals below its service layers.
8. Verify `zigeffect-grpc-web` remains generated-contract driven, bounded,
   cancellable, and correlated with server requests without owning a runtime.
9. Update the stdlib/gRPC roadmaps, repository skill, CLI templates, package
   policy, and architecture documentation.
10. Regenerate Protobuf/Protobuf-ES outputs and scaffold snapshots when their
    contracts change.
11. Run focused TDD gates, then stdlib, native gRPC, browser gRPC, CLI scaffold,
    generated-project, Buf, interop, Testing v2 migration, architecture, tool
    hygiene, formatting, and documentation checks.
12. Inspect every required Testing v2 receipt and report any unrun external or
    platform qualification lane explicitly.
