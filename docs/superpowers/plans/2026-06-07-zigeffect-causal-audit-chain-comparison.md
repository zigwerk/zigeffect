# zigeffect Causal Audit Chain Comparison Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `zig build causal-audit-chain -- local [scenario]`, a deterministic local report that compares the current session, audit, decision, proposal, before/after causal evidence, and compare report.

**Architecture:** Create `packages/zigeffect/tools/causal_audit_chain.zig` as a focused artifact reader and formatter. It parses the current local chain, classifies proposal evidence ids against before/after event ids, parses finding delta from the compare report, writes JSON/text chain reports, and updates build wiring, manifest, docs, and roadmaps. The command is read-only and preserves the existing remediation safety boundary: audit, decision, and proposal artifacts can explain and constrain patch work, but cannot mutate source or mark work applied.

**Tech Stack:** Zig 0.16, existing `causal_run` artifact directory and scenario registry, Zig std JSON parser, current causal session/audit/decision/proposal schemas.

---

## Roadmap Context

This branch implements the first concrete remediation workbench comparison
after the merged patch-proposal milestone. It should answer: "Did the evidence
behind this proposed change improve after the change was attempted?"

Delivered prerequisites:

- `causal-dev-session` coordinates baseline and assessment artifacts.
- `causal-remediation-audit` writes pending review evidence.
- `causal-remediation-decision` records approval or rejection while preserving
  `applied=false`.
- `causal-patch-proposal` records patch intent without applying edits.

This branch delivers:

- `causal-audit-chain` for default and scenario-local chains.
- JSON/text reports with schema `zigeffect.causal.audit-chain.v1`.
- Event-id classification across before/after causal artifacts.
- Assessment posture from compare finding delta plus event-id fallback.
- Documentation that makes this the first read-only workbench loop slice.

Out of scope:

- patch application;
- policy-backed automatic approval;
- durable history;
- comparing two arbitrary named chain snapshots;
- app-facing adapters.

## Files

- Create: `packages/zigeffect/tools/causal_audit_chain.zig`
  - Owns path helpers, option parsing, source artifact validation, event-id
    classification, assessment, JSON/text formatting, and CLI artifact IO.
- Modify: `packages/zigeffect/build.zig`
  - Adds the tool module, tests, executable, build step, and aggregate examples
    dependency.
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
  - Adds audit-chain artifact paths to the retention manifest and manifest
    tests.
- Modify: `packages/zigeffect/README.md`
  - Adds the command to the local causal-development workflow.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Adds guidance for citing audit-chain evidence in agent summaries.
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
  - Adds scenario-specific audit-chain artifact paths.
- Modify: `packages/zigeffect/docs/roadmap.md`
  - Marks the first audit-chain comparison slice delivered.
- Modify:
  `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
  - Updates the remediation-control roadmap with the delivered chain step.
- Modify:
  `docs/superpowers/specs/2026-06-07-zigeffect-self-improving-dev-harness-roadmap.md`
  - Updates Milestone 4 with the specific command and acceptance surface.

## Tasks

### Task 0: Documentation Checkpoint

**Files:**
- Modify:
  `docs/superpowers/specs/2026-06-07-zigeffect-causal-audit-chain-comparison-design.md`
- Modify:
  `docs/superpowers/plans/2026-06-07-zigeffect-causal-audit-chain-comparison.md`

- [ ] Update the design with roadmap position, use cases, validation rules, and
  acceptance criteria.
- [ ] Update this plan with files, scope, TDD checkpoints, verification, and
  out-of-scope boundaries.
- [ ] Run `git diff --check`.
- [ ] Commit: `docs(zigeffect): plan causal audit chain comparison`.

### Task 1: Schema, Paths, Parser, And Classification Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_audit_chain.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] Write failing tests for default and scenario output paths:
  - default JSON:
    `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-audit-chain.json`;
  - default text:
    `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-audit-chain.txt`;
  - scenario JSON:
    `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-audit-chain.json`;
  - scenario text:
    `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-audit-chain.txt`.
- [ ] Write failing tests for `classifyEventIds` with disappeared, persisting,
  appeared, and missing ids.
- [ ] Write failing tests for finding-delta parsing from compare-report text.
- [ ] Wire the test module into `build.zig`.
- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Confirm the new tests fail because the helpers are not implemented yet.
- [ ] Implement path helpers, classification helpers, finding-delta parser, and
  usage.
- [ ] Verify `cd packages/zigeffect && zig build examples` passes.
- [ ] Commit: `feat(zigeffect): add causal audit chain classifier`.

### Task 2: Report Formatting And Validation

**Files:**
- Modify: `packages/zigeffect/tools/causal_audit_chain.zig`

- [ ] Add session, audit, decision, proposal, and causal event JSON structs.
- [ ] Write failing tests for JSON/text reports that include assessment,
  source paths, proposal status, event-id classifications, finding delta,
  verification commands, claim guardrails, and proposal guardrails.
- [ ] Implement schema validation, target consistency checks, assessment rules,
  JSON formatter, and text formatter.
- [ ] Verify `cd packages/zigeffect && zig build examples` passes.
- [ ] Commit: `feat(zigeffect): format causal audit chain reports`.

### Task 3: CLI, Build Step, And Integration

**Files:**
- Modify: `packages/zigeffect/tools/causal_audit_chain.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] Add executable build step `causal-audit-chain`.
- [ ] Implement artifact readers and writers.
- [ ] Run default integration:
  - `zig build causal-dev-session -- start`;
  - `zig build causal-dev-session -- assess`;
  - `zig build causal-remediation-decision -- local approve --reason "Audit chain integration check"`;
  - `zig build causal-patch-proposal -- local approved --summary "Audit chain integration proposal" --file packages/zigeffect/tools/causal_audit_chain.zig --change "Compare proposal evidence against after artifacts"`;
  - `zig build causal-audit-chain -- local`.
- [ ] Run scenario integration:
  - `zig build causal-dev-session -- start causal-scoped-fiber`;
  - `zig build causal-dev-session -- assess causal-scoped-fiber`;
  - `zig build causal-remediation-decision -- local approve causal-scoped-fiber --reason "Audit chain scenario integration check"`;
  - `zig build causal-patch-proposal -- local approved causal-scoped-fiber --summary "Audit chain scenario proposal" --file packages/zigeffect/examples/causal_scoped_fiber.zig --change "Compare scenario evidence against after artifacts"`;
  - `zig build causal-audit-chain -- local causal-scoped-fiber`.
- [ ] Confirm both text reports include `assessment:`, `approved: true`,
  `applied: false`, `event classification:`, and `chain guardrails:`.
- [ ] Commit: `feat(zigeffect): write causal audit chain artifacts`.

### Task 4: Manifest, Docs, Roadmaps, And Final Verification

**Files:**
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-self-improving-dev-harness-roadmap.md`

- [ ] Add audit-chain JSON/text paths to `causal-artifacts` manifest and tests.
- [ ] Document `zig build causal-audit-chain -- local [scenario]`.
- [ ] Mark the audit-chain comparison first slice delivered.
- [ ] Verify:
  `git diff --check`,
  `cd packages/zigeffect && zig build causal-artifacts`,
  `cd packages/zigeffect && zig build examples`,
  `cd packages/zigeffect && zig build test --summary none`,
  `bun run check`,
  `bun run zig:test`.
- [ ] Merge to `master` and delete the branch when verification passes.

## Self-Review

- Spec coverage: the plan covers command shape, paths, schema validation,
  event-id classification, finding-delta parsing, artifacts, docs, and full
  verification.
- Scope check: patch application remains future work; this slice is read-only.
- Ambiguity check: local mode reads the current chain, not two arbitrary named
  chain snapshots.
- TDD check: Tasks 1 and 2 require red tests before helper/report
  implementation. Task 3 performs CLI integration after the tested core
  behavior exists.
