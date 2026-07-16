# ZigEffect Agent and Skill Proof-Loop Upgrade

Date: 2026-07-16
Status: accepted for implementation

## Intent

Every repository-owned or generated coding agent that develops, maintains, or
qualifies ZigEffect or Ziac software must use the proof-carrying causal
development plane as its normal operating loop. Codex, Claude Code, and Gemini
must receive equivalent executable guidance and must exchange structured
context, receipts, causal paths, and proof handoffs rather than prose-only
summaries.

## Canonical loop

1. Orient with `zigeffect agent context` or Ziac MCP `ziac_context`; retain the
   source identity, manifest digest, graph cursor, authority, omissions, and
   proof references.
2. Bind work to a requirement, acceptance check, component, scenario, and
   manifest-owned command. State a before/action/after causal counterfactual.
3. When a coordinator supplies a work packet, respect its baseline, allowed and
   excluded paths, dependencies, verification commands, lease fencing token,
   and graph cursor. Never invent missing authority or claim a lease through an
   unavailable adapter.
4. Add the failing deterministic native scenario first, then implement through
   public services, layers, typed errors, scoped resources, and one managed
   runtime.
5. Run the smallest affected scenario. Read the stable controlled process
   receipt and proof handoff; raw package receipts and terminal output are
   diagnostic only.
6. Compare the graph delta with the counterfactual and query exact durable
   paths for asserted relationships.
7. Re-query context after the change. Integration requires current source and
   manifest identities, a complete native receipt, no required gaps, and a
   proof bundle compatible with the work packet and lease.
8. Run project gates and hand off exact artifact paths, replay commands, causal
   IDs, limitations, and remaining authority requirements.

Controlled application acceptance runtimes mount their durable graph at the
owning project or component root. A mapped assertion ID is proof only after the
same ID can be queried through that project-mounted graph; a temporary fixture
graph must never be published as though the application CLI can address it.

## Multi-agent contract

- Give each implementer a bounded work packet and independent path scope.
- Treat overlapping changed paths, stale baselines, missing dependency proofs,
  and expired fencing tokens as integration failures.
- Qualifiers consume immutable candidates and may not repair them.
- A full package suite may update raw receipts and suite receipts but must not
  replace stable CLI-controlled scenario evidence.
- Repair memory is advice only; every new source revision needs current proof.

## Distribution

- Keep root Codex, Claude, and Gemini ZigEffect skills semantically identical.
- Generated ZigEffect projects install all three skill paths.
- Keep the checked-in reference system synchronized with the generated skill.
- Keep existing first-party applications such as Zgraphy synchronized instead
  of waiting for them to be regenerated.
- Ziac scaffolds install one equivalent Ziac skill for all three harnesses.
- Ziac provider skills are canonical under `packages/ziac/src/agent-kit` and are
  copied byte-for-byte into root `.agents`, `.claude`, and `.gemini` paths.
- Provider agent definitions are canonical under `agent-kit/agents` and root
  copies must match their harness variant.

## Acceptance criteria

- Every relevant skill starts from the one-call context artifact and names the
  authoritative receipt, proof handoff, raw-receipt distinction, graph delta,
  graph path, and final re-query.
- Every mutating provider agent follows test-first affected execution and emits
  a proof-carrying handoff; the qualifier remains read-only and independently
  validates the same identities.
- Generated ZigEffect and Ziac projects contain equivalent Codex, Claude, and
  Gemini instructions.
- Scaffold snapshots and version metadata change intentionally.
- Skill validation, synchronization guards, Testing v2, generated-project, and
  package-native tests pass.
