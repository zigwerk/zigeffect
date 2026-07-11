# zigeffect WebTransport Workbench Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stream local agent-session evidence through WebTransport-shaped frames and show transport health in the workbench Dev Session view.

**Architecture:** `zigeffect-quic` produces deterministic WebTransport dev-frame JSONL and receipts. The Solid workbench parses those frames back into local dev-session events, tracks transport status, and renders a transport panel without requiring live network tests.

**Tech Stack:** Zig 0.16, zigeffect-std, zigeffect-quic, Bun tests, SolidJS.

---

### Task 1: QUIC Dev-Session Bridge

**Files:**
- Modify: `packages/zigeffect-quic/src/root.zig`
- Modify: `packages/zigeffect-quic/examples/webtransport_receipt.zig`

- [x] Add failing tests for bridging `zstd.Agent.Session` JSONL into WebTransport frame JSONL.
- [x] Implement `bridgeLocalDevSessionJsonlAlloc`, bridge summaries, and redacted receipt JSON.
- [x] Update the WebTransport example to emit bridge output.

### Task 2: Workbench Frame Parser and Model

**Files:**
- Modify: `packages/zigeffect/workbench/src/localDevSessionFeed.ts`
- Modify: `packages/zigeffect/workbench/src/localDevSessionFeed.test.ts`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`

- [x] Add failing tests for WebTransport-framed local dev-session events.
- [x] Add `transport_status` events and `LocalDevTransportModel`.
- [x] Accept numeric string sequence fields from std-generated JSONL.

### Task 3: Workbench UI

**Files:**
- Modify: `packages/zigeffect/workbench/src/App.tsx`
- Modify: `packages/zigeffect/workbench/src/App.test.tsx`
- Modify: `packages/zigeffect/workbench/src/styles.css`

- [x] Add failing tests for transport UI labels.
- [x] Render transport metrics/panel/timeline rows in the Dev Session view.

### Task 4: Docs and Verification

**Files:**
- Modify: `packages/zigeffect-quic/README.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-25-zigeffect-std-effectts-grade-roadmap-design.md`

- [x] Mark M19 delivered in docs.
- [x] Run `bun run zigeffect:quic:test`.
- [x] Run `bun run zigeffect:workbench:test`.
- [x] Run `bun run zigeffect:workbench:typecheck`.
- [x] Run `bun run zigeffect:std:test`.
- [x] Run `git diff --check`.
- [x] Run `bun run zigeffect:local-agent-gate`.

## Verification Evidence

- `bun run zigeffect:quic:test` passed.
- `bun run zigeffect:workbench:test` passed: 103 pass, 0 fail.
- `bun run zigeffect:workbench:typecheck` passed.
- `bun run zigeffect:std:test` passed.
- `git diff --check` passed.
- `bun run zigeffect:local-agent-gate` passed, including the workbench build,
  zigeffect main test suite, std tests/examples, and tool hygiene gate.
