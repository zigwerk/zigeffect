# zigeffect Environment Mismatch Diagnostics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> and test-driven development.

**Goal:** Add stable compile-time environment mismatch diagnostics for public
zigeffect runner APIs.

**Architecture:** A new dependency contract helper owns the compile-time
assertion. Layer, runtime, fiber, and graph runner APIs call it before dynamic
service validation or execution.

**Tech Stack:** Zig, Bun-driven `zig build test`, existing compile-fail harness.

---

## Tasks

- [x] Add RED compile-fail fixtures for mismatched `Layer.provide`,
  `Runtime.run`, and `FiberRuntime.fork`.
- [x] Run `bun run zigeffect:test` and confirm the new fixture expectations fail.
- [x] Add `src/dependency/contracts.zig` with `assertEffectEnvironment`.
- [x] Wire the assertion into layer, runtime, fiber, and graph runner entry
  points.
- [x] Export the contracts helper through `src/zigeffect.zig`.
- [x] Re-run focused and full verification.
- [x] Update docs/roadmap status.
