# zgraphy M2.3b2 Implementation Plan

1. Register the symbol-resolution requirement, acceptance check and required
   Testing v2 scenario, then load agent context by stable requirement ID.
2. Advance `zigeffect-std.Parser` to structural-facts v2 with owned export and
   lexical type-binding facts, deep validation, summaries and fingerprints.
3. Add failing `zigeffect-parser` tests for named/default/star/namespace/local
   re-exports and for supported versus deliberately omitted receiver bindings.
4. Implement exact tree-sitter export extraction, explicit default identity,
   CommonJS static export facts, bare type bindings and lexical scope spans.
5. Add a source-grounded TypeScript symbol fixture covering Graphify's import,
   barrel, default, cycle, long-chain, receiver and phantom-call regressions.
6. Add a controlled failing `typescript_symbols.zig` test that defines corpus
   ownership, declaration identity, export closure, import/call outcomes,
   candidates, diagnostics, bounds, sort order and fingerprint.
7. Implement deterministic declaration and explicit local-export indexes.
8. Implement bounded named/star/namespace/default re-export closure with cycle
   diagnostics, long chains, local-import aliases and ambiguity retention.
9. Resolve named/default/namespace/import-require/CommonJS bindings through the
   validated M2.3b1 module candidates and export closure.
10. Resolve same-file and imported direct calls without global-name fallback.
11. Resolve namespace, static class, local-new, bare-typed and `this.field`
    member calls through exact scoped type evidence and class-owned methods.
12. Add class/method ownership plus imports-from, alias, re-export,
    instantiation and call graph records; materialize only validated candidates.
13. Run the pinned Graphify AST-only extractor, check in an overlap and
    classified-difference ledger, and require every source-valid shared edge.
14. Run focused parser/symbol scenarios, all prior M2 regressions, full
    standard-library/parser/zgraphy Debug and ReleaseSafe suites, Testing v2
    migration hygiene, manifest-owned project tests and agent safety checks.

