# zigeffect Test Service Layers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> and test-driven development.

**Goal:** Add reusable fake-service layer builders on `TestEnv`.

**Architecture:** Test layer helpers live in `src/testing/test_env.zig` and
delegate to existing `Layer(TestServices).fromEnv(...).provides(...)`.

**Tech Stack:** Zig, Bun-driven `zig build test`, existing dependency/layer
tests.

---

## Tasks

- [x] Add RED tests for `loggerLayer`, `configLayer`, and `serviceLayer`.
- [x] Run `bun run zigeffect:test` and confirm missing helpers fail.
- [x] Implement generic and named `TestEnv` layer helpers.
- [x] Re-run focused and full verification.
- [x] Update docs/roadmap status.
