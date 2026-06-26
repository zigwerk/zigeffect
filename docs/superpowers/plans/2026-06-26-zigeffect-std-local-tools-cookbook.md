# zigeffect-std Local Tools Cookbook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add M13 cookbook examples that prove `zigeffect-std` can build real local developer tools with typed CLI boundaries, workspace/process receipts, agent JSONL, and HTTP/SQL contracts.

**Architecture:** Keep all example logic in `packages/zigeffect-std/examples/` so it compiles against the public `zigeffect_std` facade. Add one cookbook markdown file under `packages/zigeffect-std/docs/`, wire every example executable and test into `packages/zigeffect-std/build.zig`, and update the std README plus zigeffect roadmap.

**Tech Stack:** Zig, `zigeffect_std`, `zig build test`, `zig build examples`, `bun run zigeffect:std:test`.

**Status:** Delivered on 2026-06-26.

---

### Task 1: Add Cookbook Docs

**Files:**
- Create: `packages/zigeffect-std/docs/cookbook.md`
- Modify: `packages/zigeffect-std/README.md`

- [ ] Write cookbook sections for `schema_cli`, `workspace_doctor`, `agent_dev_session`, `http_sql_smoke`, and `local_toolbelt`.
- [ ] Link the cookbook from the README.
- [ ] Keep the docs grounded in commands that `zig build examples` actually builds.

### Task 2: Add Example Build Gate

**Files:**
- Modify: `packages/zigeffect-std/build.zig`

- [ ] Replace the single-example wiring with a reusable `addExample` helper.
- [ ] Keep `hello.zig` built and tested.
- [ ] Add executables and tests for every new cookbook example.

### Task 3: Add Schema CLI Example

**Files:**
- Create: `packages/zigeffect-std/examples/schema_cli.zig`

- [ ] Write tests for source precedence and issue JSON.
- [ ] Implement `runSchemaCli` with typed command decoding.
- [ ] Assert sentinel values are redacted from issue JSON.

### Task 4: Add Workspace Doctor Example

**Files:**
- Create: `packages/zigeffect-std/examples/workspace_doctor.zig`

- [ ] Write tests for ignored snapshots, check receipts, and redaction.
- [ ] Implement a deterministic in-memory workspace doctor.
- [ ] Emit JSON suitable for a local artifact.

### Task 5: Add Agent Dev Session Example

**Files:**
- Create: `packages/zigeffect-std/examples/agent_dev_session.zig`

- [ ] Write tests for workbench-compatible JSONL.
- [ ] Implement a local agent session feed with check, guardrail, artifact, and process receipt events.
- [ ] Assert sentinel process details are redacted.

### Task 6: Add HTTP/SQL Smoke Example

**Files:**
- Create: `packages/zigeffect-std/examples/http_sql_smoke.zig`

- [ ] Write tests for schema-validated request handling.
- [ ] Implement a fake HTTP/SQL smoke path with deterministic JSON output.
- [ ] Keep it service-free and locally runnable.

### Task 7: Add Local Toolbelt Example

**Files:**
- Create: `packages/zigeffect-std/examples/local_toolbelt.zig`

- [ ] Write tests for one composed local command run.
- [ ] Implement a compact command that combines schema CLI, workspace snapshot, process receipt, and agent event output.
- [ ] Keep it as a copyable pattern rather than a hidden framework.

### Task 8: Roadmap and Verification

**Files:**
- Modify: `packages/zigeffect/docs/roadmap.md`

- [ ] Mark the standard-library row as M1-M13 delivered.
- [ ] Run `bun run zigeffect:std:test`.
- [ ] Run `bun run zigeffect:postgres:test`.
- [ ] Run `git diff --check`.
- [ ] Run `bun run zigeffect:local-agent-gate`.
- [ ] Commit the milestone when verification passes.
