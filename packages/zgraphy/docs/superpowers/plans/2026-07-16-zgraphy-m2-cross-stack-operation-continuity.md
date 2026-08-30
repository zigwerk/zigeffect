# zgraphy M2.5 Implementation Plan

1. Register the cross-stack continuity requirement, acceptance check and
   required Testing v2 scenario, validate the manifest and load agent context.
2. Advance `zigeffect-std.Parser` to structural-facts v4 with owned bounded
   `CallArgument` and `CallBinding` facts, validation, summaries, helpers and
   deterministic fingerprint coverage.
3. Add failing `zigeffect-parser` tests for aliased factory calls, multiple
   arguments, nested/member expressions, lexical result bindings, exact spans,
   deterministic order and fact/label limits.
4. Implement TypeScript tree-sitter extraction for call arguments and direct
   call initializers; make Proto results emit empty v4 arrays.
5. Add realistic generated TypeScript and Zig bindings plus ZigEffect
   `GeneratedDriverBinding` registration and deceptive negatives to the
   `fullstack-orders` fixture.
6. Make strict Protobuf-ES RPC lineage preserve the actual generated descriptor
   property spelling and add failing acronym/casing/deception tests.
7. Extend the local Zig AST fact boundary with bounded call arguments while
   preserving existing call and binding resolution behavior.
8. Add a failing `rpc_continuity.zig` scenario for exact frontend client
   construction, generated operation lookup, generated-driver implementation
   containment, registration proof, ambiguity, bounds and order-independent
   fingerprints.
9. Implement the pure continuity resolver and ZigEffect generated-driver recipe
   without repository-global or name-only fallback.
10. Add `invokes_operation` and `handles_operation` to the MVP graph model and
    materialize only resolved observations from the continuity result.
11. Emit deterministic interaction records joining resolved frontend and
    backend participants through canonical operation/request/response identity.
12. Run pinned Graphify 0.9.17 on the enhanced fixture and record exact source
    graph digest, projection loss, quality, latency and memory evidence.
13. Run parser, standard-library and zgraphy focused/full Debug and ReleaseSafe
    suites, Testing v2 migration hygiene, manifest-owned requirement execution
    and the agent safety check.
