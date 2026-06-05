# zigeffect Config Providers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans and test-driven development.

**Goal:** Add provider-style config loading and a layer-friendly config
environment while preserving existing descriptors.

**Architecture:** Keep provider parsing inside `services/config.zig`; use the
existing layer/service contracts for graph startup consumption.

**Verification:** `bun run zigeffect:test`, `bun run zig:test`,
`bun run typecheck`.

---

## Tasks

- [x] Add RED tests for entry loading, dotenv parsing, and `ConfigEnv` graph
  startup consumption.
- [x] Add `ConfigEntry`, `Config.loadEntries`, and `Config.loadDotEnv`.
- [x] Add `ConfigEnv` and facade exports.
- [x] Update docs/roadmap and run full verification.
