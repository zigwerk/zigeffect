---
name: zigeffect-development
description: Build, change, debug, test, or review the Zgraphy ZigEffect application using its project manifest, typed services and layers, ManagedRuntime, Testing v2, durable causal graph, deterministic replay, and proof-carrying handoffs.
---

# ZigEffect Development

Treat `zigeffect.project.json` and structured runtime evidence as truth.
Terminal output is a bounded diagnostic artifact, never acceptance proof.

## Proof-carrying causal loop

1. Run `zigeffect agent context --task <id-or-summary> --budget 65536 --json`.
   Retain source identity, manifest digest, graph cursor, authority, omissions,
   affected scenarios, and proof references.
2. Bind the request to a requirement, acceptance check, component, fixed
   command, and deterministic scenario. State the expected before/action/after
   causal path and the application slice that must remain unchanged.
3. Respect every supplied work packet: allowed and excluded paths,
   dependencies, verification commands, graph baseline, lease, and fencing
   token. Never invent unavailable coordination or authority.
4. Add the failing native Testing v2 scenario first. Implement through public
   component facades and `zigeffect_std` with typed services, effects, layers,
   errors, scopes, and one process-level `zstd.ManagedRuntime`.
5. Run `zigeffect test affected --changed <path> --json`, then the smallest
   selected scenario. Require current, identity-matched proof at
   `.zigeffect/tests/process-receipts/<scenario>.json` and
   `.zigeffect/handoffs/tests/<scenario>.json`.
6. Treat `.zigeffect/tests/raw-receipts/`, latest-run views, and terminal text
   as diagnostic only. Compare `zigeffect graph since <cursor> --limit 256
   --json` with the counterfactual and query `zigeffect graph path <from> <to>
   --limit 128 --json` for exact durable relationships.
7. Re-query `agent context`. Reject stale proof, undeclared or overlapping
   paths, expired fencing tokens, missing dependency proof, required gaps,
   dropped evidence, and unread truncation before integration.

## Architecture and verification

- Libraries export tags, effects, layers, schemas, and typed errors; they never
  hide an independent runtime.
- The application composes one root layer and one managed runtime. Recording,
  embedded NenDB, the application map, and checked shutdown are runtime-owned.
- Controlled acceptance runtimes use the owning project or component root.
  Query at least one mapped assertion ID through the project-mounted graph
  before publishing; a temporary graph cannot support CLI proof.
- Use deterministic providers in tests and semantic facts at external,
  workflow, statechart, artifact, and acceptance boundaries.
- Never persist credentials, personal data, raw payloads, or terminal
  scrollback in causal or proof artifacts.

Run the requirement scenario, coverage and gaps, the manifest-owned project
test command, and `zigeffect project check --agent --json`. Inspect the Testing
v2 suite receipt for a complete pass with equal discovered/executed counts and
no pending tests, leaks, or logged errors. Hand off exact stable receipt and
proof paths, replay commands, causal IDs, limitations, and remaining authority
needs.

For multi-agent work, return a proof bundle bound to the work packet, source
baseline, lease fencing token, changed paths, verification digests, receipts,
and causal IDs. Independent qualifiers do not repair candidates. Repair memory
is advice, not current proof or authority.
