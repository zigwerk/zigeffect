# ZigEffect Parser Package Implementation Plan

1. Add a failing `zigeffect-std` contract test for normalized document facts,
   provider substitution, a typed parse effect, causal evidence, validation,
   ownership, and deterministic fingerprints.
2. Implement `zigeffect-std/src/parser/root.zig`, export it as `Parser`, and
   include it in standard-library declaration and architecture checks.
3. Scaffold `packages/zigeffect-parser` with package-native Testing v2 build
   wiring, README, notices, ownership boundary, and the pinned tree-sitter
   runtime and TypeScript/TSX grammars moved from zgraphy.
4. Move the TypeScript AST implementation into `zigeffect-parser`, adapt it to
   the standard result contract, and add its direct API, provider API, and
   ZigEffect layer.
5. Capture a focused failing provider test, then make exact declarations,
   imports, bindings, calls, scopes, spans, limits, and fingerprints pass.
6. Replace zgraphy's native C build wiring with a `zigeffect-parser` dependency
   and a thin compatibility adapter; preserve the existing M2.3 acceptance
   scenario and product API.
7. Move third-party attribution to the owning package and leave an accurate
   zgraphy dependency notice.
8. Run focused standard-library, parser-package, and zgraphy tests; inspect all
   Testing v2 receipts; run Debug and ReleaseSafe package gates, Testing v2
   migration hygiene, and zgraphy agent safety.
9. Update the zgraphy M2.3 specification and roadmap evidence to identify the
   reusable package boundary before starting TypeScript module resolution.
