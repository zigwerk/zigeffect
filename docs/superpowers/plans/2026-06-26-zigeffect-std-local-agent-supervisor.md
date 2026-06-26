# zigeffect-std Local Agent Supervisor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add M14 local agent supervision so zigeffect-std can run local agent/tool processes, capture redacted artifacts, apply guardrails, and stream workbench-compatible JSONL.

**Architecture:** Extend `packages/zigeffect-std/src/agent/root.zig` with supervisor types and functions that reuse `Session`, `AdapterSpec`, and `Process.Command`. Add `examples/agent_supervisor.zig`, wire it into `packages/zigeffect-std/build.zig`, and document the milestone in README/cookbook/roadmap files.

**Tech Stack:** Zig, `zigeffect_std`, `zstd.Agent`, `zstd.Process`, `zig build test`, `zig build examples`, `bun run zigeffect:std:test`.

**Status:** Delivered on 2026-06-26.

---

### Task 1: Supervisor API Tests

**Files:**
- Modify: `packages/zigeffect-std/src/agent/root.zig`

- [ ] Add tests proving multi-tool supervisor output, fail-fast behavior,
  redaction, artifacts, and effect-runtime causal facts.
- [ ] Run `bun run zigeffect:std:test` and verify missing-symbol failures.

### Task 2: Supervisor Implementation

**Files:**
- Modify: `packages/zigeffect-std/src/agent/root.zig`

- [ ] Add `SupervisedTool`, `SupervisorPolicy`, `SupervisorArtifact`,
  `SupervisorSummary`, `runSupervisorAlloc`, and `runSupervisorEffect`.
- [ ] Redact feed details and artifact content with `zstd.Secrets`.
- [ ] Emit only workbench-supported local dev session event kinds.

### Task 3: Copyable Example

**Files:**
- Create: `packages/zigeffect-std/examples/agent_supervisor.zig`
- Modify: `packages/zigeffect-std/build.zig`

- [ ] Add an example that runs one local process through the supervisor.
- [ ] Add a test showing the example feed and artifacts are redacted.
- [ ] Wire the example into `zig build examples`.

### Task 4: Docs and Roadmap

**Files:**
- Modify: `packages/zigeffect-std/README.md`
- Modify: `packages/zigeffect-std/docs/cookbook.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-25-zigeffect-std-effectts-grade-roadmap-design.md`

- [ ] Mark M14 delivered after verification.
- [ ] Document the supervisor API and example.

### Task 5: Verification and Commit

- [ ] Run `bun run zigeffect:std:test`.
- [ ] Run `bun run zigeffect:postgres:test`.
- [ ] Run `git diff --check`.
- [ ] Run `bun run zigeffect:local-agent-gate`.
- [ ] Commit M14.
