# zgraphy M4.1 Semantic Recipe Registry Implementation Plan

1. Register `req-m4-semantic-recipe-registry`, its acceptance check and required
   Testing v2 scenario; close the now-earned M3 manifest statuses.
2. Add a failing deterministic acceptance test for registry identity,
   dependency order, current fullstack validation, unknown-recipe rejection and
   unchanged M2/M3 output semantics.
3. Implement `src/semantic_recipes.zig` with the canonical typed definitions,
   lookup, registry fingerprint and fail-closed graph validation.
4. Move request-path/feature reuse and publication behind the bounded
   `materializeRequestPath` API while leaving parser/resolver assembly in
   `indexer.zig`.
5. Export the registry publicly and enforce it at store save/load and generation
   candidate validation boundaries.
6. Run the focused scenario and inspect its Testing v2 receipt for complete
   execution, leaks, logged errors and causal findings.
7. Run affected M2 request-path and M3 derived/invalidation/persistence tests,
   then Debug and ReleaseSafe package suites.
8. Run manifest validation and the project agent check; update roadmap evidence
   only for behavior proven by current receipts.
