# zigeffect Examples Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> and test-driven development.

**Goal:** Add compile-checked examples for module startup, graph bootstrap, and
test fake layers.

**Architecture:** Examples live in `packages/zigeffect/examples/` and compile
against the public `zigeffect` facade. `build.zig` exposes an `examples` step.

**Tech Stack:** Zig build examples plus existing Bun/Zig verification commands.

---

## Tasks

- [x] Add `examples/readiness.zig` with database service, startup effect, graph
  bootstrap, and fake-service test.
- [x] Add `zig build examples` wiring.
- [x] Run `cd packages/zigeffect && zig build examples`.
- [x] Link examples from README/module-pattern/roadmap.
- [x] Run full verification.
