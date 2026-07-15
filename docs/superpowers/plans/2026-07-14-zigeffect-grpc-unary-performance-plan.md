# ZigEffect gRPC Unary Performance Implementation Plan

Date: 2026-07-14

1. Add focused failing tests for TCP_NODELAY configuration, coalesced flushes,
   nghttp2 stream user-data lookup, shared bounded handler scheduling, unary
   completion lifetime, borrowed identity decoding, and response ownership
   transfer.
2. Add client/server low-latency socket options and a reusable bounded nghttp2
   flush buffer.
3. Install and clear server stream user data and remove callback-path linear
   lookup.
4. Generalize the incremental executor into the bounded server handler
   executor, add unary jobs and completion dispatch, and prove reset and
   connection teardown cannot race job storage.
5. Classify reserved headers before ownership, remove request metadata
   duplication, keep common header values in bounded inline storage, and add
   fixed common response headers/trailers.
6. Add borrowed unary frame decoding and ownership-transferring response APIs;
   update generated typed binding behavior and tests.
7. Upgrade the benchmark driver and harness for warm-up exclusion,
   repetitions/duration, p99.9, channel sweeps, and relative budgets.
8. Run focused tests after each boundary, then the package-native test,
   migration hygiene, external interoperability, Connect conformance, and
   benchmark smoke gates. Inspect Testing v2 and benchmark receipts directly.
9. Update the performance engineering record with measured results and keep
   native Linux release measurements explicitly unverified until they run on
   committed source.
10. Sweep the bounded handler worker count on Linux and adopt the measured
    default without removing the per-service configuration override.
11. Replace stale marketing performance copy with the same-receipt schema-v2
    diagnostic, label it as candidate evidence, and retain the exact promotion
    boundary.
12. Synchronize the repository README, package README, Cloud Run guide,
    `AGENTS.md`, and both repository-owned `zigeffect-development` skills.
13. Run focused site tests, typecheck, production build, package-native Testing
    v2 verification, documentation checks, and a local visual review before
    committing only the intended gRPC work to `master`.
