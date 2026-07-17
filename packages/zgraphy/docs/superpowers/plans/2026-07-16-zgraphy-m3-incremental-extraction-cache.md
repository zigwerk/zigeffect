# zgraphy M3.2 Incremental Extraction Cache Implementation Plan

1. Register the M3.2 requirement, acceptance check and required Testing v2
   scenario before editing runtime behavior.
2. Add a failing deterministic fullstack scenario for cold population, warm
   zero-parse reuse, one-file edit, delete/rename, corrupt-entry recovery,
   clean-full equivalence and staged interruption.
3. Add `extraction_cache.zig` with bounded content-addressed keys, typed Zig and
   standard parser-result codecs, atomic writes, strict reads and execution
   statistics.
4. Add ownership-transfer parser-result entry points to Zig and Proto resolver
   corpora so decoded facts enter the existing resolution pipeline without a
   second parse.
5. Teach `indexer.buildRepository` to load or populate structural facts for
   Zig, TypeScript/JavaScript and Proto while keeping raw-source-only analyzers
   and all deterministic global resolvers unchanged.
6. Build a deterministic generation extraction manifest from cache units and
   source-qualified graph dependencies, then compute direct changes and the
   reverse transitive invalidation closure against the predecessor manifest.
7. Extend build and publication receipts with cache hits, misses, rejected
   entries, writes, reparsed files, direct invalidations and closure counts
   without including execution-local statistics in generation identity.
8. Advance the generation recipe and pointer metadata to bind the extraction
   manifest path and digest, and validate that manifest during candidate reload
   and active-generation health checks.
9. Preserve M3.1 locking, immutable snapshots, atomic activation, pinned reads,
   fail-closed refresh and legacy compatibility mirrors.
10. Isolate zgraphy's own managed-runtime causal store from the target
    application's imported `.zigeffect/graph` so unchanged CLI invocations do
    not mutate graph truth or generation identity.
11. Expose bounded cache/invalidation evidence through status/build JSON and
    update README/roadmap claim boundaries.
12. Run the focused scenario first, then affected tests, the complete Debug and
    ReleaseSafe Testing v2 suites, migration guard, project safety, coverage,
    gaps and current-source agent evidence reconciliation.
