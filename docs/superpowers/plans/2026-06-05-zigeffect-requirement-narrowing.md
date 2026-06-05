# zigeffect Requirement Narrowing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> and test-driven development.

**Goal:** Add `ServiceEnv` and graph narrowed run APIs so effects can depend on
only the services they use.

**Architecture:** Service narrowing lives under dependency contracts as a
generated environment view. Graph runtime owns the runner APIs because graph
startup is where the full provider set and generated environment are available.

**Tech Stack:** Zig, Bun-driven `zig build test`, existing layer graph tests.

---

## Tasks

- [x] Add RED layer graph test for `fx.ServiceEnv` plus `graph.runNarrowed`.
- [x] Run `bun run zigeffect:test` and confirm the missing API fails.
- [x] Add `src/dependency/narrowing.zig` with `ServiceEnv`.
- [x] Export `ServiceEnv` through `src/zigeffect.zig`.
- [x] Add `LayerGraphRuntime.runNarrowed` and `exitNarrowed`.
- [x] Re-run focused and full verification.
- [x] Update docs/roadmap status.
