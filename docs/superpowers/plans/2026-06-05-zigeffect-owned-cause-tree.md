# zigeffect Owned Cause Tree Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an allocator-owned recursive cause tree companion API while keeping existing `Exit` ownership stable.

**Architecture:** Implement `CauseTree(Failure)` in `core/result.zig`, export it through the facade, cover it with failing tests first, then update roadmap/docs status. Existing `Exit` remains by-value.

**Tech Stack:** Zig, `bun:test` command wrappers, existing zigeffect core/test modules.

---

## Tasks

- [x] Write failing tests for owned recursive cause trees.
- [x] Verify the tests fail before implementation.
- [x] Implement `CauseTree(Failure)` and formatting/inspection helpers.
- [x] Implement `causeTreeWithFinalizerFailure`.
- [x] Export the new API from `src/zigeffect.zig`.
- [x] Run focused zigeffect tests.
- [x] Update roadmap/errors docs.
- [x] Run full verification.
