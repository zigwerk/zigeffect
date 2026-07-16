# ZigEffect Agent and Skill Proof-Loop Implementation Plan

Date: 2026-07-16
Design: `docs/superpowers/specs/2026-07-16-zigeffect-agent-skill-proof-loop-design.md`

## Phase 1 — Contract tests

1. Extend ZigEffect scaffold tests to require Codex, Claude, and Gemini skill
   installation and the full proof-loop vocabulary.
2. Extend Ziac scaffold and agent-kit tests to require context-first operation,
   stable receipt/proof identities, graph paths, final context reconciliation,
   and immutable qualification.
3. Add a synchronization guard for canonical skill and agent copies.

## Phase 2 — Core ZigEffect skill

1. Upgrade the root skill with the eight-step proof loop and multi-agent work
   packet/proof rules.
2. Synchronize Claude and Gemini copies.
3. Upgrade the generated application skill, reference-system copies, and
   first-party Zgraphy application copies.
4. Add Gemini installation to generated projects and bump the scaffold contract.

## Phase 3 — Ziac skills and agents

1. Make `ziac_context` the first Ziac diagnostic request and preserve the
   ZigEffect context/receipt/graph/proof lifecycle.
2. Upgrade provider development, maintenance, and qualification skills.
3. Upgrade Codex, Claude, and Gemini provider agent definitions.
4. Synchronize agent-kit canonical sources, workspace copies, and scaffolded
   static instructions.
5. Keep the Ziac scaffold compatibility receipt aligned with the ZigEffect CLI
   template contract so a newly generated app is compatible immediately.

## Phase 4 — Verification

1. Validate skill frontmatter and metadata.
2. Run synchronization, formatting, scaffold snapshot, generated-project,
   Testing v2 migration, package-native, and Ziac focused/full gates.
3. Inspect complete suite receipts and report any unsupported external gate.
