# ZigEffect Agent-Causal Development Hardening Plan

1. Add failing unit tests for caller-owned causal stores, backend restoration,
   manifest-enriched application maps, and empty graph baselines.
2. Add failing scaffold contract tests requiring one real runtime-backed
   acceptance scenario instead of detached synthetic evidence.
3. Implement safe causal backend swapping and caller-store support in the
   canonical managed runtime; expose the TestContext bridge.
4. Load validated manifest intent into managed-runtime state and publish agent
   application-map schema v2 with exact bounded workflow commands.
5. Refactor generated application/service templates around `rootLayer`,
   `program`, `runWithOptions`, and a single causal acceptance test; update
   scaffold snapshots and generated skills/docs.
6. Make graph status/since return a read-only empty baseline for a graph that
   has not been created.
7. Extend generated-project integration coverage to execute compatibility,
   validation, agent discovery, affected selection, requirement tests, receipt
   inspection, graph delta, coverage/gaps, and handoff.
8. Re-run architecture guards and review the remaining non-kernel adapter debt;
   harden inaccurate production claims and migrate safe wrapper boundaries that
   fit this design without creating parallel runtime abstractions.
9. Run the engine, standard library, CLI unit and integration, gRPC, browser,
   schema, formatting, architecture, tool-hygiene, and Testing v2 receipt gates.
10. Manually scaffold one application and follow the documented agent workflow
    from the pre-change graph cursor through the post-change causal delta and
    handoff, recording exact bounded evidence and remaining limitations.
