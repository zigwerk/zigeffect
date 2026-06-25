# zigeffect-std Agent Toolkit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `zstd.Agent` a first-class local agent toolkit for Codex, Claude Code, local process adapters, guardrails, artifacts, check receipts, and workbench-compatible JSONL feeds.

**Architecture:** Keep the toolkit in `packages/zigeffect-std/src/agent/root.zig`. It builds on `zstd.Process`, `zstd.Json`, `zstd.Jsonl`, `zstd.Secrets`, and `zstd.Service`. `Session` owns a redacted JSONL feed and sequence counter. Agent events match the workbench local-dev-session schema (`agent_status`, `check_result`, `artifact_link`, `next_action`, `guardrail`, `warning`). `RunAgentEffect(Env, Runner)` executes a configured process runner, records status/check events, and emits causal facts. Codex and Claude Code support is concrete command construction plus the same process runner path; tests use `Process.FakeRunner`, while local users can supply `Process.LocalRunner`.

**Tech Stack:** Zig, zigeffect `Effect`/`Runtime`/`Context`, `zstd.Process`, `zstd.Service`, redacted JSON/JSONL helpers, Bun-driven Zig test gate.

---

### Task 1: Workbench-Compatible Session Feed

**Files:**
- Modify: `packages/zigeffect-std/src/agent/root.zig`

- [ ] **Step 1: Write the failing test**

Add a test proving sessions own workbench-compatible JSONL:

```zig
test "Agent Session records workbench-compatible redacted events" {
    var session = Session.init(std.testing.allocator, "local-dev", "/repo");
    defer session.deinit();

    try session.recordAgentStatus(.{
        .agent_id = "codex",
        .agent_kind = .codex,
        .agent_label = "Codex",
        .status = .running,
        .task = "editing token=abc123",
    });
    try session.recordCheck(.{
        .label = "std tests",
        .command = "bun run zigeffect:std:test",
        .status = .pass,
        .detail = "19 pass",
    });
    try session.linkArtifact("m10-plan", "docs/superpowers/plans/2026-06-25-zigeffect-std-agent-toolkit.md");
    try session.recordGuardrail("no raw secrets in workbench payloads");

    const feed = session.feedText();
    try std.testing.expect(std.mem.indexOf(u8, feed, "\"kind\":\"agent_status\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, feed, "\"agent_kind\":\"codex\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, feed, "\"kind\":\"check_result\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, feed, "\"kind\":\"artifact_link\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, feed, "\"kind\":\"guardrail\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, feed, "abc123") == null);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun run zigeffect:std:test`

Expected: FAIL because `Session`, typed agent statuses, checks, artifacts, and guardrails are missing.

- [ ] **Step 3: Implement session**

Implement:

- `AgentKind = enum { codex, claude_code, other }` with `agentKindName`.
- `AgentStatus = enum { idle, running, reviewing, blocked, done, failed }`.
- `CheckStatus = enum { pending, running, pass, fail, warning }`.
- `AgentStatusEvent`, `CheckEvent`.
- `Session.init`, `deinit`, `feedText`, `nextSequence`.
- `recordAgentStatus`, `recordCheck`, `linkArtifact`, `recordNextAction`, `recordGuardrail`, `recordWarning`.
- JSONL appending through redacted `Json.objectFromFieldsAlloc`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bun run zigeffect:std:test`

Expected: PASS.

### Task 2: Codex and Claude Code Process Adapters

**Files:**
- Modify: `packages/zigeffect-std/src/agent/root.zig`

- [ ] **Step 1: Write the failing test**

Add a test for concrete command construction:

```zig
test "Agent builds Codex and Claude Code process commands" {
    const codex = codexAdapter("codex-build", "/repo", "implement std");
    try std.testing.expectEqualStrings("codex", codex.command.argv[0]);
    try std.testing.expectEqualStrings("exec", codex.command.argv[1]);
    try std.testing.expectEqualStrings("implement std", codex.command.argv[2]);
    try std.testing.expectEqualStrings("/repo", codex.command.cwd);

    const claude = claudeCodeAdapter("claude-review", "/repo", "review changes");
    try std.testing.expectEqualStrings("claude", claude.command.argv[0]);
    try std.testing.expectEqualStrings("-p", claude.command.argv[1]);
    try std.testing.expectEqualStrings("review changes", claude.command.argv[2]);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun run zigeffect:std:test`

Expected: FAIL because adapter specs are missing.

- [ ] **Step 3: Implement adapter specs**

Implement:

- `AdapterSpec { id, kind, label, task, command }`.
- `codexAdapter(id, cwd, task)` using `Process.Command{ .argv = &.{ "codex", "exec", task }, .cwd = cwd }`.
- `claudeCodeAdapter(id, cwd, task)` using `Process.Command{ .argv = &.{ "claude", "-p", task }, .cwd = cwd }`.
- `localProcessAdapter(id, label, cwd, argv)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bun run zigeffect:std:test`

Expected: PASS.

### Task 3: Effect-Native Agent Runner

**Files:**
- Modify: `packages/zigeffect-std/src/agent/root.zig`

- [ ] **Step 1: Write the failing test**

Add a test that executes an adapter through `Process.FakeRunner`:

```zig
test "Agent runAgentEffect executes process runner and records session plus causal facts" {
    const zstd = @import("../root.zig");

    var session = Session.init(std.testing.allocator, "session-1", "/repo");
    defer session.deinit();
    var runner = zstd.Process.FakeRunner.init(.{
        .exit_code = 0,
        .stdout = "ok token=abc123",
        .stderr = "",
    });

    var provider = zstd.Service.Provider(.{ Session, zstd.Process.FakeRunner }).init(.{ &session, &runner });
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{ Session, zstd.Process.FakeRunner })
        .withCausalStore(&store);

    var summary = try runtime.run(runAgentEffect(@TypeOf(provider), zstd.Process.FakeRunner, codexAdapter("codex", "/repo", "test")));
    defer summary.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("success", summary.status);
    try std.testing.expect(std.mem.indexOf(u8, session.feedText(), "\"status\":\"running\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, session.feedText(), "\"status\":\"done\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, session.feedText(), "abc123") == null);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(zstd.Service.hasOperation(snapshot, Session, "agent.run", "success"));
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun run zigeffect:std:test`

Expected: FAIL because `RunAgentEffect`, `runAgentEffect`, and `RunSummary` are missing.

- [ ] **Step 3: Implement runner**

Implement:

- `RunSummary { agent_id, status, receipt_json }` with `deinit`.
- `RunAgentEffect(Env, Runner)` requiring `Session` and `Runner`.
- Record `agent_status` running before process execution.
- Execute `runner.runOutputAlloc`.
- Record `check_result` for the command.
- Record `agent_status` done/failed after execution.
- Record causal service operation `agent.run`.
- Redact process output in session details but keep raw process output in the process result returned by `zstd.Process`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bun run zigeffect:std:test`

Expected: PASS.

### Task 4: Docs, Verification, Commit

**Files:**
- Modify: `packages/zigeffect-std/README.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-25-zigeffect-std-effectts-grade-roadmap-design.md`

- [ ] **Step 1: Update docs**

Document M10 as delivered: local agent sessions, Codex/Claude Code command adapters, process execution effects, guardrails/artifacts/checks, and workbench-compatible JSONL.

- [ ] **Step 2: Run full gate**

Run:

```bash
bun run zigeffect:std:test
bun run zigeffect:postgres:test
bun run zigeffect:local-agent-gate
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 3: Commit**

Run:

```bash
git add docs/superpowers/plans/2026-06-25-zigeffect-std-agent-toolkit.md \
  docs/superpowers/specs/2026-06-25-zigeffect-std-effectts-grade-roadmap-design.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect-std/README.md \
  packages/zigeffect-std/src/agent/root.zig
git commit -m "Add zigeffect std agent toolkit"
```

Expected: commit succeeds after the verification gate.
