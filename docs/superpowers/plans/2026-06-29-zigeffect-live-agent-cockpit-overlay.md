# zigeffect Live Agent Cockpit Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stream local agent development events through the existing live workbench socket and render them in the Dev Session tab.

**Architecture:** Extend the live source subscriber with optional local dev-session events. Add a local dev-session buffer to the live artifact handle. Add collector endpoints that accept agent JSONL or event JSON and broadcast normalized events over `/live`.

**Tech Stack:** Bun tests, SolidJS live attach helpers, zigeffect workbench collector, existing `localDevSessionFeed.ts`.

---

### Task 1: Browser Live Agent Event Buffer

**Files:**
- Modify: `packages/zigeffect/workbench/src/liveAttach.ts`
- Modify: `packages/zigeffect/workbench/src/liveAttach.test.ts`

- [x] Add failing tests proving `webSocketLiveSource` parses local dev-session events and `createLiveArtifact` exposes a live local session.
- [x] Add optional `onLocalDevEvent` to `LiveSubscriber`.
- [x] Add `LiveLocalDevSessionBuffer` over `applyLocalDevSessionEvents`.
- [x] Add `localDevSession()` and `localDevSessionEventCount()` to `LiveArtifactHandle`.
- [x] Run `bun run zigeffect:workbench:test`.

### Task 2: Collector Agent Feed Ingest

**Files:**
- Modify: `packages/zigeffect/workbench/src/collector/collector.ts`
- Modify: `packages/zigeffect/workbench/src/collector/collector.test.ts`

- [x] Add failing collector tests for `POST /agent-feed` broadcasting redacted local dev-session events.
- [x] Add collector methods `ingestAgentEvent` and `ingestAgentFeed`.
- [x] Add `POST /agent-events` and `POST /agent-feed` handlers.
- [x] Run `bun run zigeffect:workbench:test`.

### Task 3: Dev Session Overlay Wiring

**Files:**
- Modify: `packages/zigeffect/workbench/src/App.tsx`
- Modify: `packages/zigeffect/workbench/src/App.test.tsx`

- [x] Add a source-level test that live local sessions are considered by the app.
- [x] Use `live.localDevSession()` as the Dev Session fallback in live mode.
- [x] Run `bun run zigeffect:workbench:typecheck`.

### Task 4: Docs and Verification

**Files:**
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/plans/2026-06-29-zigeffect-live-agent-cockpit-overlay.md`

- [x] Update the roadmap local agentic development status.
- [x] Run `bun run zigeffect:workbench:test`.
- [x] Run `bun run zigeffect:workbench:typecheck`.
- [x] Run `git diff --check`.

## Verification Evidence

- Red run: `bun run zigeffect:workbench:test` failed on missing live local
  session APIs, missing WebSocket parsing, missing `/agent-feed`, and missing App
  fallback.
- Green run: `bun run zigeffect:workbench:test` passed: 107 pass, 0 fail.
- `bun run zigeffect:workbench:typecheck` passed.
- `git diff --check` passed.
- `bun run zigeffect:local-agent-gate` passed.
