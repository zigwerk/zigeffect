---
name: zigeffect-development
description: Build, change, debug, test, or review this ZigEffect reference application using its project manifest, public services and layers, ManagedRuntime, Testing v2, causal graph, deterministic replay, and proof-carrying handoffs.
---

# ZigEffect Development

Treat `zigeffect.project.json` and structured evidence as truth. Terminal output
is diagnostic only.

## Proof-carrying causal loop

1. Run `zigeffect agent context --task <id-or-summary> --budget 65536 --json`.
   Retain source/manifest identity, graph cursor, authority, omissions, affected
   scenarios, and proof references.
2. Bind the request to a requirement, acceptance check, component, fixed
   command, and scenario. State the before/action/after causal counterfactual.
3. Respect supplied work-packet paths, dependencies, verification commands,
   lease, and fencing token; do not invent missing authority.
4. Add the failing deterministic scenario first. Implement with public
   component facades, typed services/effects/layers, scoped resources, and the
   one process-level `zstd.ManagedRuntime`.
5. Run `zigeffect test affected --changed <path> --json` and the smallest
   scenario. Require current stable evidence at
   `.zigeffect/tests/process-receipts/<scenario>.json` and
   `.zigeffect/handoffs/tests/<scenario>.json`.
   Mount controlled runtimes at the owning project or component root and query
   a mapped assertion ID through the project-mounted graph before publishing.
6. Treat `.zigeffect/tests/raw-receipts/`, latest-run views, and terminal text as
   diagnostics. Compare `graph since` with the counterfactual and query
   `zigeffect graph path <from> <to> --limit 128 --json` for exact proof.
7. Re-query context and reject stale identities, conflicting paths, expired
   fencing, missing dependency proof, required gaps, or incomplete evidence.

Compose statecharts with `zstd.Statechart.Effect.layer`/`step`, journals with
`zstd.Workflow.journalLayer`/`append`, lifecycle signals at the root, and every
API request or worker job with a bounded handle from the one owning runtime.

Run the requirement scenario, coverage/gaps, the project test command, and
`zigeffect project check --agent --json`. Inspect the Testing v2 suite receipt
for a complete pass with equal discovered/executed counts and no pending tests,
leaks, or logged errors. Hand off receipt/proof paths, replay commands, causal
IDs, limitations, and remaining authority needs.

Multi-agent implementers return proof bundles bound to their work packet,
source baseline, fencing token, changed paths, verification digests, receipts,
and causal IDs. Independent qualifiers do not repair candidates.
