# zgraphy M3.1 Automatic Freshness Implementation Plan

1. Register the M3.1 requirement, acceptance check and required Testing v2
   scenario in `zigeffect.project.json`.
2. Add a failing fullstack scenario covering initial publication, unchanged
   reuse, mixed edit/delete/rename pruning, semantic invalidation, prior-reader
   pinning, staged interruption and automatic successor activation.
3. Define bounded active-pointer, generation-metadata, refresh and pruning
   receipt contracts in `operations.zig`.
4. Add an advisory non-blocking exclusive update lease whose lifetime is the
   candidate build and activation transaction.
5. Derive stable generation IDs from manifests, graph fingerprint, storage
   identity and recipe version; validate every derived path.
6. Stage snapshot, manifest, health and generation metadata under the immutable
   generation path, then reload and validate the candidate.
7. Compare prior and candidate graphs for explicit pruning accounting and move
   the active pointer only after every invariant passes.
8. Implement the lightweight discovery/ownership freshness check so unchanged
   managed reads report zero reparsed source files.
9. Implement managed graph loading that fails closed on refresh errors and pins
   one active generation path for the read lifetime.
10. Route build/ingest and every graph-reading CLI command through generation
    publication or the automatic freshness barrier; include generation and
    refresh evidence in versioned JSON.
11. Preserve legacy config-v2 artifacts and read-only doctor behavior while
    teaching doctor to prefer active-generation artifacts when available.
12. Update README/roadmap claim boundaries, run focused and complete Debug and
    ReleaseSafe Testing v2 suites, migration guard, project safety and fresh
    agent evidence.
