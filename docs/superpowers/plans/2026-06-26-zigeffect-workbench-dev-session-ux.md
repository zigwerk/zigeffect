# zigeffect Workbench Dev Session UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the SolidJS workbench Agents tab excellent for local agent development by adding health summary, timeline, command receipts, and Schema/CLI issue highlights.

**Architecture:** Add pure derivation helpers to `packages/zigeffect/workbench/src/causalArtifact.ts` and cover them in `causalArtifact.test.ts`. Update `App.tsx` to render those helpers inside the existing agents tab, then add focused App tests and CSS classes in `styles.css`.

**Tech Stack:** SolidJS, TypeScript, Bun test, Vite, existing workbench model types.

**Status:** Delivered on 2026-06-26.

---

### Task 1: Model Helper Tests

**Files:**
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`

- [ ] Add tests for local dev health summary.
- [ ] Add tests for local dev timeline rows.
- [ ] Add tests for Schema/CLI issue highlights and redaction.
- [ ] Run `bun run zigeffect:workbench:test` and verify missing-export failures.

### Task 2: Model Helpers

**Files:**
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`

- [ ] Add `LocalDevHealthSummary`, `LocalDevTimelineItem`,
  `LocalDevIssueHighlight` types.
- [ ] Implement `deriveLocalDevHealthSummary`.
- [ ] Implement `deriveLocalDevTimeline`.
- [ ] Implement `deriveLocalDevIssueHighlights`.

### Task 3: UI Tests and Render

**Files:**
- Modify: `packages/zigeffect/workbench/src/App.test.tsx`
- Modify: `packages/zigeffect/workbench/src/App.tsx`
- Modify: `packages/zigeffect/workbench/src/styles.css`

- [ ] Add a test proving the `agents` tab label is "Dev Session".
- [ ] Render health metrics, timeline, and issue highlights in
  `AgentDevelopmentView`.
- [ ] Add responsive, dense CSS for timeline and issue rows.

### Task 4: Docs and Verification

**Files:**
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-25-zigeffect-std-effectts-grade-roadmap-design.md`

- [ ] Mark M15 delivered after verification.
- [ ] Run `bun run zigeffect:workbench:test`.
- [ ] Run `bun run zigeffect:workbench:typecheck`.
- [ ] Run `bun run zigeffect:std:test`.
- [ ] Run `git diff --check`.
- [ ] Commit M15.
