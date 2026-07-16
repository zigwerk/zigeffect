# zgraphy M2.2 Implementation Plan

1. Register `req-m2-zig-resolution` and its required Testing v2 scenario in
   `zigeffect.project.json`; rerun agent context using the stable requirement.
2. Add a controlled failing acceptance test for the `zig-ambiguity` fixture.
   It requires parser binding facts, an ambiguous two-candidate resolution,
   deterministic fingerprinting, graph candidate edges, and improved canonical
   differential evidence.
3. Extend `zig_parser.zig` with bounded import-binding, variable-binding, and
   initializer field-reference facts. Update validation, ordering, summaries,
   ownership, and fingerprints without weakening M2.1 behavior.
4. Implement `zig_resolution.zig` as an independently testable corpus pass with
   normalized import targets, exact source-qualified symbols, scope-aware local
   binding flow, explicit outcomes, candidate deduplication, limits, validation,
   deterministic ordering, and fingerprints.
5. Refactor `indexer.zig` so repository builds parse each Zig file once, index
   its parsed structural facts, resolve the complete Zig corpus, and materialize
   local binding plus `dispatches_to` edges only from validated evidence.
6. Append the v1 runtime `dispatches_to` relation, map it to semantic-v2, and
   project it to benchmark-v1 `selects_candidate`. Derive the canonical
   ambiguity fact only when graph candidate evidence exactly supports it.
7. Run the focused scenario through `zigeffect test affected`, inspect its
   Testing v2 and process receipts, then run M2.1 regression and native M0
   differential tests.
8. Run the manifest-owned Debug and ReleaseSafe gates, inspect the suite receipt
   for complete discovered/executed counts, zero pending tests, zero leaks and
   zero logged errors, then update roadmap/evidence status for M2.2.
