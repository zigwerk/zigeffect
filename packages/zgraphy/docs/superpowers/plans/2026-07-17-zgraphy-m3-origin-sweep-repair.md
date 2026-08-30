# zgraphy M3.6 Origin-Owned Sweep and Repair Plan

1. Register `req-m3-origin-sweep-repair`, its acceptance check, and a required
   Testing v2 scenario before changing runtime behavior.
2. Add a failing deterministic scenario covering exact ownership, unchanged
   overlay carry-forward, replacement-over-prune, dependency invalidation,
   legitimate isolated records, malformed ownership, reference cascades,
   index/checkpoint repair, clean-rebuild escalation, pointer safety, redaction,
   and clean-live-overlay equivalence.
3. Implement `origin_ledger.zig` with canonical owners, record references,
   dependencies, origin/freshness policy, bounded JSON persistence, strict
   validation, mark/validate/sweep, carry-forward, overlay replacement, and
   typed sweep accounting.
4. Add a public `OriginOverlay` input to managed rebuild operations and derive
   native ownership for source, manifest, build, ZigEffect, and resolver output.
5. Implement `repair.zig` with bounded typed plans/reports and classify active
   snapshot, index, delta, cache, and invariant failures without mutating the
   active generation.
6. Advance generation/active-pointer contracts to v6, add origin and repair
   artifacts plus `replaces_generation`, and bind them into identity,
   publication, replay, status, and doctor validation.
7. Make the pre-query freshness barrier publish zero-parse index/checkpoint
   repair successors where proof permits, otherwise escalate to a distinct
   cache-backed or clean checkpoint while retaining the last pointer until
   validation succeeds.
8. Export origin and repair contracts through the public facade, update
   freshness capabilities and honest claim boundaries, and preserve all
   Graphify replacement/prune regression semantics.
9. Run the M3.6 controlled scenario, every affected M3 scenario, Debug and
   ReleaseSafe package suites, Testing v2 receipt/coverage/gap audits, manifest
   validation, migration guard, static safety, and agent project check.
