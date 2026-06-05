# zigeffect Config Schema Loading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> and test-driven development.

**Goal:** Add schema-wide typed config loading through `Config.schema` and
`Config.readSchema`.

**Architecture:** The schema helper lives in `src/services/config.zig` and
reuses existing descriptors plus `Config.read`. No new provider subsystem is
introduced.

**Tech Stack:** Zig, Bun-driven `zig build test`, existing service tests.

---

## Tasks

- [x] Add RED service test for typed struct schema loading.
- [x] Run `bun run zigeffect:test` and confirm the missing API fails.
- [x] Implement schema validation, `Config.schema`, and `Config.readSchema`.
- [x] Re-run focused and full verification.
- [x] Update docs/roadmap status.
