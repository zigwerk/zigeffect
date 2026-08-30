# zgraphy M3.7 Watch and Update Coordinator Implementation Plan

1. Register `req-m3-watch-coordinator`, its acceptance check, and the required
   deterministic scenario in `zigeffect.project.json` before behavior changes.
2. Add a failing Testing v2 scenario for statechart validity, logical debounce,
   mixed repository mutation, output-loop exclusion, lease contention, durable
   pre/late drain, failure persistence, cancellation, corruption rejection,
   redaction, clean equivalence, and a current post-watch query.
3. Add `watch_coordinator.zig` through the public zgraphy facade with a typed
   ZigEffect statechart, bounded options, pure coordinator state, commands,
   summaries, and logical-time transition API.
4. Add the repository-bound checksummed pending-request artifact with canonical
   merge, atomic publication, explicit acknowledgement, strict bounded decode,
   and fail-closed validation.
5. Add a no-follow metadata observation fingerprint that ignores zgraphy's
   owned runtime/output subtree and uses repository limits without reading
   source bodies.
6. Add one operations wrapper that attempts the existing `ensureFresh` engine,
   translates `UpdateInProgress` into durable contention, and drains preexisting
   and late requests for a bounded number of passes.
7. Compose the foreground `zgraphy watch` command with ZigEffect lifecycle and
   signal services, monotonic polling, debounce/retry bounds, optional
   `--max-cycles`, versioned JSON summary, and no ambient network/process
   authority.
8. Extend build/status/doctor capability and queue-health views while preserving
   redaction and explicitly leaving daemon/hooks/retention/GC unsupported.
9. Run the focused scenario, all affected M3 scenarios, Debug and ReleaseSafe
   suites, Testing v2 receipt audit, coverage/gaps, formatting, diff integrity,
   migration guard, manifest-owned test, and agent safety gate.
10. Mark the manifest check passed and requirement satisfied only after current
    source evidence is complete, then update README/ROADMAP with exact delivered
    behavior and nonclaims.
