# zgraphy M3.8 Retention and Garbage Collection Implementation Plan

1. Register `req-m3-retention-gc`, its acceptance check, and one required
   deterministic Testing v2 scenario in `zigeffect.project.json` before runtime
   behavior changes.
2. Add a failing acceptance scenario covering config defaults/bounds, automatic
   multi-generation retention, pins, complete-manifest cache liveness,
   Graphify cache regressions, reader contention, dry-run/apply identity,
   corruption fail-closed behavior, redaction, recovery, and clean equivalence.
3. Add `retention.zig` through the public facade with bounded policy, strict
   generation/pin/manifest inventory, canonical mark closure, typed actions,
   deterministic plan fingerprint, apply/idempotence, and atomic receipts.
4. Add shared generation-reader and exclusive nonblocking GC leases, preserving
   update-before-reader lock ordering and holding shared leases through complete
   generation artifact loading.
5. Extend backward-compatible config-v2 defaults and validation for automatic
   GC, generation count, and grace period.
6. Integrate applied collection after activation and on unchanged freshness,
   while treating reader contention or post-publication GC failure as explicit
   retention state rather than a graph publication failure.
7. Add repository-bound pin/unpin operations and dry-run-default `zgraphy gc`
   with explicit `--apply`, versioned bounded output, and no path/source leak.
8. Extend publication, status v9, doctor, capability reporting, README,
   Graphify parity ledger, and roadmap with exact delivered behavior and
   remaining nonclaims.
9. Run the focused scenario, all M3 scenarios, full Debug and ReleaseSafe
   Testing v2 suites, receipt audits, coverage/gaps, formatting, diff integrity,
   migration guard, manifest-owned project test, and agent safety gate.
10. Mark the requirement satisfied only after current source receipts prove the
    complete boundary, then proceed to M3 long-churn and Graphify performance
    exit evidence.
