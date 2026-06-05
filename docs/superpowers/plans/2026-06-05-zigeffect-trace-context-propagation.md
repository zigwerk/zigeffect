# zigeffect Trace Context Propagation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> and test-driven development.

**Goal:** Propagate trace/span ids through runtime-created contexts.

**Architecture:** `Context` stores optional trace metadata. Runtime, fiber
runtime, and graph runtime copy their active trace context into contexts they
construct; observability services remain independent.

**Tech Stack:** Zig, Bun-driven `zig build test`, existing runtime/fiber/layer
tests.

---

## Tasks

- [x] Add RED tests for regular runtime, fiber runtime, and graph runtime trace
  context propagation.
- [x] Run `bun run zigeffect:test` and confirm missing APIs/fields fail.
- [x] Add trace fields to `Context`.
- [x] Add `withTraceContext` and context propagation to runtime, fiber runtime,
  and graph runtime.
- [x] Re-run focused and full verification.
- [x] Update docs/roadmap status.
