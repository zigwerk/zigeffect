# zgraphy M3.4 Canonical Delta Journal Implementation Plan

1. Register the M3.4 requirement, acceptance check, component-owned sources,
   fixed command, seed, and required Testing v2 scenario before changing
   runtime behavior.
2. Add one failing deterministic acceptance scenario for cold checkpoint
   replay, unchanged reuse, edit/delete/exclude tombstones, clean-full
   equivalence, malformed journals, interrupted publication, and both recovery
   lanes.
3. Add a runtime `delta_journal.zig` boundary with bounded schema-v1 header,
   typed operation records, footer, exact-byte digest, strict phase/order
   validation, atomic write, inspection, and replay APIs.
4. Implement complete field-aware equality for nodes/vectors, edges,
   hyperedges, and supernodes; compute tombstone plus upsert pairs for changed
   identities and omit exact unchanged records.
5. Implement deterministic canonical graph cloning and use it for publication
   and replay so native index fingerprints cannot depend on parent append
   history.
6. Derive deletion, exclusion, replacement, dependency-invalidation, and
   reconciled-absence causes from the previous content manifest, current
   discovery result, filesystem presence, and extraction invalidation closure,
   preserving replacement-over-delete semantics.
7. Extend immutable generation paths, metadata, active pointers, generation
   identity, CLI JSON, and freshness capabilities with journal schema, path,
   digest, parent, and bounded operation summaries.
8. Write the full target checkpoint and delta journal before metadata; strictly
   replay the journal against its exact parent during candidate validation and
   require graph/index equality before activation.
9. Add a read-only generation loader that prefers a healthy full checkpoint and
   can reconstruct from one healthy parent plus journal when the target
   snapshot is unavailable; never repair or move pointers during reads.
10. Extend active health and doctor so journal damage degrades update evidence
    while a valid full checkpoint remains safely queryable, and both invalid
    representations fail closed into automatic refresh or a typed error.
11. Port Graphify changed/unchanged/deleted/excluded, hyperedge carry/prune,
    root/path normalization, and replace-wins regressions into the native
    acceptance scenario without modifying the pinned reference checkout.
12. Run the focused scenario, affected tests, complete Debug and ReleaseSafe
    Testing v2 suites, migration guard, deterministic CLI smoke, manifest
    validation, coverage/gaps, project safety, and current-source agent evidence
    reconciliation.
