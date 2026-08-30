# zgraphy M3.9 Exit Qualification Implementation Plan

1. Register `req-m3-exit-qualification`, its acceptance check and required
   Testing v2 scenario before runtime changes.
2. Add a failing deterministic scenario for strict churn/performance receipt
   validation, claim gating, quantiles, ratios and the 32-transition managed
   churn sequence.
3. Implement `src/m3_qualification.zig` with bounded schemas, validation,
   canonical statistics, growth budgets, checked ratios and scoped claims.
4. Export the contract through `src/root.zig` and add strict `benchmark churn`
   and `benchmark performance` CLI subcommands.
5. Implement the actual managed long-churn observations and close functional,
   equivalence, GC, reader, branch, exclusion and repair assertions.
6. Add `benchmarks/run_m3_qualification.py` for fresh paired ReleaseSafe
   zgraphy and pinned Graphify incremental process samples, redacted local
   execution and exact identity generation.
7. Run the external comparison, inspect the complete receipt and profile any
   target miss without weakening the corpus, samples, correctness gates or
   target.
8. Optimize the measured responsible runtime boundary with focused regression
   evidence until the scoped 5x latency and 0.5x RSS targets pass, or leave M3
   explicitly open with the measured deficit.
9. Update the evaluation contract, parity ledger, README and roadmap only to
   the evidence actually earned.
10. Run the requirement scenario, M3 aggregate, full Debug and ReleaseSafe
    suites, Testing v2 migration, project test/check and agent handoff gates.

## Completion evidence

All ten plan items are complete. The current-source paired ReleaseSafe receipt
is comparison eligible and passes both M3 targets: zgraphy records a 97,703,291
ns median managed one-file update versus Graphify's 547,151,584 ns, a 5.6001x
speedup, and 14,794,752 bytes median peak RSS versus 79,200,256 bytes, a 0.1868x
ratio. The receipt is bound to pinned Graphify 0.9.17, the identified source,
corpus, machine, toolchain and configuration, with one warmup and seven samples.

The complete Debug and ReleaseSafe Testing v2 suites pass 43/43 with zero
pending tests, leaks or logged errors. The final agent check passes every
required gate with zero forbidden source-policy findings. The only compatibility
warning is the known repository-wide generated-scaffold template upgrade and is
outside zgraphy's M3 runtime evidence.
