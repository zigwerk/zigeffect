# ZigEffect Proof-Carrying Development Plane Implementation Plan

Date: 2026-07-16
Design: `docs/superpowers/specs/2026-07-16-zigeffect-proof-carrying-development-plane-design.md`

## Phase 0 — Baseline and contracts

1. Capture compatibility, manifest validation, agent status, test inventory,
   graph status, and relevant Testing v2 suite receipts.
2. Add a Ziac requirement, acceptance check, and deterministic scenario for the
   development context endpoint before changing behavior.
3. Add failing tests for all contracts below.

Exit: failures demonstrate the missing behavior rather than syntax errors in
the test harness.

## Phase 1 — Causal context and graph proof

1. Add allocation-free `CausalContextV2`, `CausalLink`, link kinds, validation,
   merging, and public exports to ZigEffect core.
2. Stamp context through kernel managed-runtime handles and semantic recording.
3. Persist context/link projections in JSONL and NenDB node properties.
4. Project context into OTel attributes and add a combined log/span OTLP
   envelope without creating a second telemetry truth.
5. Add parent-chain path queries to live databases and read-only snapshots.
6. Add `AssertionRecorder.eventPath` with bounded path IDs.

Exit: core and standard-library focused tests prove propagation, persistence,
OTLP equality, and path evidence.

## Phase 2 — Development services

1. Add public `zigeffect_std.Development` module.
2. Implement pure evidence reconciliation from manifest + Testing v2 run receipt
   + current source identity.
3. Implement the bounded deterministic context compiler.
4. Implement durable task transition contracts, `WorkPacket`, `ProofBundle`,
   proof verification, lease fencing, federation addresses, and redacted repair
   episodes.
5. Expose services/layers so applications can replace stores, clocks, and
   evidence readers in tests.

Exit: unit tests cover passing, stale, missing, failed, and mismatched evidence;
budget boundaries; every task transition; lease conflicts; proof mismatch;
federated addresses; and repair redaction.

## Phase 3 — CLI and runtime integration

1. Replace the CLI's existence-only evidence logic with the reconciler.
2. Add `zigeffect agent context` options for task, byte budget, changed paths,
   and graph cursor.
3. Add `zigeffect graph path <from> <to>` and use the same graph path contract
   as Testing v2.
4. Upgrade runtime application-map schema to advertise causal context v2,
   graph paths, and the canonical one-call development workflow.
5. Keep all output versioned, bounded, valid JSON, and secret scanned.

Exit: CLI integration tests show that the previously pending Ziac requirements
are derived passed from matching receipts and that stale receipts stay open.

## Phase 4 — Ziac and scaffolds

1. Add a read-only `ziac_context` MCP tool using the canonical development
   context artifact; retain explicit process authority for verification.
2. Wire the Ziac application root layer to development services and record task
   context on workflow/plan/apply boundaries.
3. Update ZigEffect and Ziac scaffold templates, skills, README, and agent loop
   documentation.
4. Synchronize scaffold contract snapshots and repository-owned skill copies.

Exit: Ziac MCP and generated-project tests prove the endpoint and architecture;
Testing v2 migration checks pass.

## Phase 5 — Hardening and handoff

1. Run affected tests after each change, then complete core, std, CLI, Ziac, and
   scaffold gates.
2. Inspect every Testing v2 suite artifact for equal discovered/executed counts,
   zero pending tests, leaks, logged errors, and unreported truncation.
3. Compare causal graph before/after cursors and query the proof path produced by
   the new acceptance scenario.
4. Run tool hygiene, architecture, docs/link, and source safety checks.
5. Review the diff for duplicated abstractions, unbounded allocations, unsafe
   ownership, accidental compatibility shims, and misleading claims.

Exit: all required evidence passes or any external/credential/platform limit is
explicitly reported as a limitation rather than promoted to complete.

## Delivery record

Completed 2026-07-16. Phases 0–5 shipped through `CausalContextV2`, exact W3C
propagation, graph paths and counterfactual assertions, the public
`zstd.Development` services, exact evidence reconciliation, bounded context
compilation, durable tasks/leases/work packets/proofs/federation/repair memory,
CLI context and graph-path commands, automatic focused-test handoffs, Ziac's
effectful `ziac_context` endpoint, and template-v12 scaffolds. Package-native
Testing v2, generated-project, architecture, migration, and tool-hygiene gates
were used for the final handoff.

## Implementation order and rollback boundaries

- Core context and graph changes are independently testable and land first.
- Development contracts are pure and can be reverted without changing graph
  persistence.
- CLI adoption switches only after reconciliation tests pass.
- Ziac and scaffold adoption consume public facades and contain no copied
  reconciliation logic.
- OTLP remains a projection; disabling an exporter never disables local causal
  recording.
