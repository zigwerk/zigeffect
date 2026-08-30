# zgraphy M2.6 Native Request-path Meaning Plan

1. Register `req-m2-request-path-meaning`, its acceptance check and a required
   Testing v2 scenario in `zigeffect.project.json` before behavior changes.
2. Add a failing deterministic fullstack test for typed request-path
   participants, feature membership, proof steps, differential completeness,
   negative lookalikes, determinism and snapshot round-trip.
3. Extend RPC observations with exact supporting binding/container symbols and
   spans; bump their internal schema/fingerprint and preserve ambiguity rules.
4. Add callback-reference facts to TypeScript symbol resolution and materialize
   the native `passes_callback` relation without treating arbitrary arguments
   as calls.
5. Materialize nested Zig declaration ownership by source containment and emit
   `covers` from test declarations to uniquely resolved callees.
6. Add bounded source evidence, hyperedge, participant, supernode member and
   proof-step types to `model.RepositoryGraph`, including ownership,
   canonicalization, validation, stable IDs and lookup helpers.
7. Materialize request paths solely from resolved RPC interactions, then add
   exact client/service and adjacent UI/loader/test projections.
8. Materialize one feature supernode per request path with deterministic
   completeness, synopsis, members, evidence and proof steps.
9. Include semantic records in graph health and fingerprints; reject dangling
   participants, invalid members and unproved steps.
10. Introduce complete snapshot-v2 writes with hyperedge/supernode records and
    footer counts while retaining snapshot-v1 reads and rollback identity.
11. Extend `zgraphy explain` and status/build summaries with bounded semantic
    counts and proof-carrying JSON.
12. Upgrade the native differential adapter to match native facts, hyperedges
    and supernodes and require full `fullstack-orders` gold coverage.
13. Run the focused failing scenario, full Debug and ReleaseSafe Testing v2
    suites, migration guard, project safety and fresh agent evidence.
14. Re-run the pinned Graphify comparison only if benchmark inputs or measured
    claims change; otherwise preserve the prior receipt and report the newly
    demonstrated quality dimensions without inventing performance evidence.
