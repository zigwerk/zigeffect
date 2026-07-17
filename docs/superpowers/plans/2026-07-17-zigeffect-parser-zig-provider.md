# Shared Zig Document Parser Provider Implementation Plan

1. Preserve the existing `req-m2-zig-parser-boundary` acceptance contract and
   extend its source ownership/evidence to the reusable parser package.
2. Add a failing identity assertion showing zgraphy still owns the Zig parser.
3. Move the compiler-AST implementation into
   `packages/zigeffect-parser/src/zig.zig`, namespace its schema/provider
   identity, and add explicit AST node and syntax-depth limits.
4. Export `zigeffect-parser.Zig` and add provider-native deterministic,
   malformed-input, and limit tests.
5. Replace `packages/zgraphy/src/zig_parser.zig` with a compatibility facade;
   preserve all downstream parser, resolution, indexing, cache, and RPC APIs.
6. Update parser/zgraphy documentation and manifest source roots without
   claiming common-service Zig support or deferred document families.
7. Run focused red/green tests, both package suites in Debug and ReleaseSafe,
   zgraphy's affected and controlled scenarios, full project test, Testing v2
   migration hygiene, formatting, diff checks, and agent safety evidence.
