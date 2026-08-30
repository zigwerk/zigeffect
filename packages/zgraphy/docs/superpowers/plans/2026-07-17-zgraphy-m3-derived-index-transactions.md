# zgraphy M3.3 Derived Record and Native Index Implementation Plan

1. Register the M3.3 requirement, acceptance check and required Testing v2
   scenario before changing runtime behavior.
2. Add one failing deterministic scenario covering cold recomputation, warm
   semantic reuse, unrelated and proof-source edits, deletion, adjacency,
   path-field retrieval, snapshot reload/corruption, clean-full equivalence and
   staged interruption.
3. Extend the extraction-cache session with a bounded preview of direct and
   predecessor/current reverse-transitive invalidation after base graph
   materialization, while retaining the final post-semantic manifest as the
   generation contract.
4. Load the previous active graph before indexing and pass it as read-only
   candidate input; never alias its allocator or make it authoritative.
5. Refactor RPC semantic materialization around a bounded interaction context
   and local recipe-input fingerprint that includes every required/optional
   participant, evidence span and proof edge but excludes unrelated corpus
   state.
6. Reuse a prior hyperedge/supernode pair only after fingerprint, closure,
   participant, member, proof and completeness checks; otherwise recompute from
   current context. Record separate reused/recomputed counters.
7. Add transactionally maintained NenDB outgoing/incoming relation and incident
   adjacency indexes with complete rollback on node/edge append failure.
8. Add field-aware lexical postings for label/path/search text with bounded
   frequencies, transactional node ownership, deterministic stats and query
   accessors.
9. Route `hasEdge`, relation checks, shortest path, keyword scoring and hybrid
   graph propagation through the native indexes without changing public result
   contracts.
10. Add complete secondary-index validation and deterministic fingerprinting
    against canonical nodes/edges.
11. Advance the snapshot to v3, retain v1/v2 reads, bind index schema/stats/
    fingerprint in the footer, and verify reconstructed indexes on load.
12. Advance generation and CLI schemas, expose bounded semantic reuse/index
    evidence, and validate indexes before candidate activation.
13. Port the applicable Graphify unchanged-hyperedge, changed replacement,
    deletion prune, skipped-member and affected-adjacency regressions into the
    native scenario.
14. Run the focused scenario, affected tests, complete Debug and ReleaseSafe
    Testing v2 suites, migration guard, CLI smoke, project safety, coverage,
    gaps and current-source agent evidence reconciliation.
