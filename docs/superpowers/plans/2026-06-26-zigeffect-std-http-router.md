# zigeffect-std HTTP Router Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Schema-coded local HTTP router/server layer to `zstd.Http`.

**Architecture:** Extend `packages/zigeffect-std/src/http/root.zig` with typed JSON endpoint and tuple router types. Add route result ownership, route receipts, workbench trace JSON, and an effect wrapper. Add a copyable `examples/http_router.zig` and wire it into `zig build examples`.

**Tech Stack:** Zig, `zstd.Schema`, `zstd.Http`, `zstd.Json`, `zstd.Service`, `bun run zigeffect:std:test`.

**Status:** Delivered on 2026-06-26.

---

### Task 1: Red Tests

**Files:**
- Modify: `packages/zigeffect-std/src/http/root.zig`
- Create: `packages/zigeffect-std/examples/http_router.zig`
- Modify: `packages/zigeffect-std/build.zig`

- [ ] Add tests for valid route handling, validation failure, 404, effect facts,
  and the example.
- [ ] Run `bun run zigeffect:std:test` and verify missing-symbol failures.

### Task 2: Router Implementation

**Files:**
- Modify: `packages/zigeffect-std/src/http/root.zig`

- [ ] Add `RouteResult`, `jsonEndpoint`, `router`, and `handleRouteEffect`.
- [ ] Decode request bodies with detailed Schema results.
- [ ] Encode handler outputs with Schema.
- [ ] Emit receipt and trace JSON.
- [ ] Return deterministic redacted error responses.

### Task 3: Docs and Verification

**Files:**
- Modify: `packages/zigeffect-std/README.md`
- Modify: `packages/zigeffect-std/docs/cookbook.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-25-zigeffect-std-effectts-grade-roadmap-design.md`

- [ ] Mark M16 delivered after verification.
- [ ] Run `bun run zigeffect:std:test`.
- [ ] Run `bun run zigeffect:postgres:test`.
- [ ] Run `git diff --check`.
- [ ] Commit M16.
