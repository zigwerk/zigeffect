# zigeffect Observability Metadata Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans and test-driven development.

**Goal:** Add timestamp/trace/span metadata to logger entries and trace
ids/attributes to tracing spans.

**Architecture:** Keep metadata in `services/logger.zig` and
`services/tracing.zig`; preserve existing APIs by delegating them to richer
entry/span constructors.

**Verification:** `bun run zigeffect:test`, `bun run zig:test`,
`bun run typecheck`.

---

## Tasks

- [x] Add RED tests for logger metadata and tracing trace ids/attributes.
- [x] Add logger metadata structs and `logWithContext`.
- [x] Add tracing trace ids, attributes, and `startSpanWithAttributes`.
- [x] Update docs/roadmap and run full verification.
