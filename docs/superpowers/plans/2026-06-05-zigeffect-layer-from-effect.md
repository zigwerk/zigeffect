# zigeffect Layer.fromEffect Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> and test-driven development.

**Goal:** Add graph-startup `Layer.fromEffect` support.

**Architecture:** The layer constructor lives in `src/layer/layer.zig`.
Effect-backed layers project their effect environment from graph startup
contexts and reuse the existing layer wrapper metadata APIs.

**Tech Stack:** Zig, Bun-driven `zig build test`, existing layer graph tests.

---

## Tasks

- [x] Add RED layer graph test for an effect-backed database layer.
- [x] Run `bun run zigeffect:test` and confirm missing `fromEffect` fails.
- [x] Implement `EffectLayer` and `Layer.fromEffect`.
- [x] Preserve effect requirement metadata in `EffectLayer.requiredServices`.
- [x] Re-run focused and full verification.
- [x] Update docs/roadmap status.
