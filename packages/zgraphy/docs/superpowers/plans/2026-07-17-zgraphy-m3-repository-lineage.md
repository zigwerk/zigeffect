# zgraphy M3.5 Repository Context and Change Lineage Plan

1. Register `req-m3-repository-lineage`, its acceptance check, and controlled
   Testing v2 scenario before implementing runtime behavior.
2. Add a failing deterministic scenario covering unique rename, move-chain,
   ambiguous duplicate content, context-only branch change, linked-worktree
   identity, redaction, delta causes, and clean-current-graph equivalence.
3. Implement a bounded native repository-context reader for primary Git,
   linked worktrees, symbolic/detached/unborn HEAD, loose refs, packed refs, and
   non-Git repositories.
4. Implement the canonical lineage artifact, exact-content reconciliation,
   ambiguity accounting, carry-forward validation, and atomic persistence.
5. Advance generation and active-pointer contracts to v5 and bind context and
   lineage identities into generation identity, candidate validation, recovery,
   status, and doctor.
6. Add `renamed` and `moved` canonical-delta source causes and derive them only
   from validated confident lineage records.
7. Export the public context/lineage contracts through the zgraphy facade and
   update capability and roadmap claim boundaries.
8. Run the M3.5 scenario, all affected M3 scenarios, Debug and ReleaseSafe
   package suites, Testing v2 receipt audit, manifest validation, migration
   guard, safety gates, and agent project check.
