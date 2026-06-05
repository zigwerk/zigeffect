# zigeffect Module Scaffold Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a compile-checked text scaffold generator for zigeffect module folders.

**Architecture:** Implement the generator under `packages/zigeffect/tools`, test pure rendering logic, and wire the tool test into `zig build examples`.

**Tech Stack:** Zig tool module, existing zigeffect `build.zig`, Bun verification commands.

---

## Tasks

- [x] Write failing scaffold generator test.
- [x] Verify the test fails through `zig build examples`.
- [x] Implement `renderModuleTemplate` and CLI `main`.
- [x] Wire the tool executable/test into `build.zig`.
- [x] Run `zig build examples`.
- [x] Update README/module-pattern/roadmap docs.
- [x] Run full verification.
