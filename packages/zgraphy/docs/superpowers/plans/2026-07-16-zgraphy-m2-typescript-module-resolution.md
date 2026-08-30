# zgraphy M2.3b1 Implementation Plan

1. Register the module-resolution requirement, acceptance check, and one
   required Testing v2 scenario; load agent context by stable requirement ID.
2. Extend `zigeffect-std.Parser` and `zigeffect-parser` with failing tests for
   static-string dynamic imports and CommonJS require while preserving computed
   calls as unresolved call facts only.
3. Add a source-grounded monorepo fixture covering Graphify's extension,
   tsconfig, workspace, exports, security, ambiguity, and external-reference
   regression surface.
4. Add a controlled failing resolver test defining corpus ownership, typed
   outcomes, candidate rules, diagnostics, bounds, sort order, and fingerprint.
5. Implement safe repository-relative path normalization and an inventory
   index with exact, ESM-substitution, extension, and directory-index rules.
6. Implement bounded JSONC normalization and tsconfig loading with baseUrl,
   path specificity, ordered fallback targets, recursive string/array extends,
   child overrides, cycle diagnostics, and nearest-config selection.
7. Implement bounded pnpm/npm workspace discovery and package resolution with
   duplicate-name ambiguity, conditional/array/exact/wildcard exports, root
   entry fallbacks, and package containment.
8. Resolve every copied import fact into deterministic outcomes and candidates;
   validate and fingerprint the complete owned result.
9. Add module-reference and resolution graph records, deeply index TS/JS files
   through the shared parser, and materialize local/external/deferred evidence
   without same-name fallback.
10. Add canonical differential expectations for overlapping Graphify facts and
    prove zgraphy candidate/diagnostic improvements do not alter shared truth.
11. Run focused parser and resolver scenarios, prior M2 regressions, full
    Debug/ReleaseSafe package suites, Testing v2 migration hygiene, and
    `zigeffect project check --agent --json`; inspect complete receipts before
    promoting M2.3b1.
