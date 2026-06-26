# zigeffect QUIC Adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an optional `zigeffect-quic` adapter package around `quic-zig` while keeping `zstd.Http` stable.

**Architecture:** The new package imports `zigeffect_std` and `quic`, implements clients that satisfy the existing `sendAlloc` shape, and supplies deterministic fakes/receipts for CI. Live QUIC is compile-tested but not exercised by default.

**Tech Stack:** Zig 0.16, zigeffect-std, quic-zig, Bun package scripts.

---

### Task 1: Package Skeleton and Dependency

**Files:**
- Create: `packages/zigeffect-quic/build.zig`
- Create: `packages/zigeffect-quic/build.zig.zon`
- Create: `packages/zigeffect-quic/src/root.zig`
- Modify: `package.json`

- [x] Add a package with `zigeffect_std` and pinned `quic` dependencies.
- [x] Add root script `zigeffect:quic:test`.

### Task 2: HTTP/3 Client Contract

**Files:**
- Modify: `packages/zigeffect-quic/src/root.zig`

- [x] Add failing tests for fake QUIC HTTP send, redacted receipts, and effect
  integration.
- [x] Implement `ClientConfig`, `FakeQuicHttpClient`, `QuicHttpClient`, and
  receipt helpers.

### Task 3: WebTransport Receipts

**Files:**
- Modify: `packages/zigeffect-quic/src/root.zig`

- [x] Add failing tests for WebTransport stream/datagram receipt redaction.
- [x] Implement deterministic WebTransport message and receipt helpers.

### Task 4: Examples and Docs

**Files:**
- Create: `packages/zigeffect-quic/examples/http3_smoke.zig`
- Create: `packages/zigeffect-quic/examples/webtransport_receipt.zig`
- Create: `packages/zigeffect-quic/README.md`
- Modify: `packages/zigeffect/docs/roadmap.md`

- [x] Wire examples into `zig build examples`.
- [x] Document experimental status, local verification, and copyable usage.

### Task 5: Verification

- [x] Run `bun run zigeffect:quic:test`.
- [x] Run `bun run zigeffect:std:test`.
- [x] Run `git diff --check`.
- [x] Run `bun run zigeffect:local-agent-gate`.
