# zigeffect Causal Dev Harness Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing zigeffect causal dev harness the explicit recovery path for local self-improving development work.

**Architecture:** Preserve the current Zig harness and improve its entrypoints and agent-facing text. Root Bun scripts call existing Zig build steps, `causal_loop.zig` emits runnable query commands, and docs explain the baseline/after/failure workflow.

**Tech Stack:** Bun scripts, Zig build steps, existing zigeffect causal tools, Markdown docs.

**Status:** Delivered in `07f49b57 feat(zigeffect): recover causal dev harness workflow`.

---

### Task 1: Make Dev-Loop Query Commands Runnable

**Files:**
- Modify: `packages/zigeffect/tools/causal_loop.zig`

- [x] **Step 1: Write the failing test**

Update `test "query report runs selected dogfood follow-up queries"` to expect:

```zig
try std.testing.expect(std.mem.indexOf(u8, report, "query: zig build causal-query -- --file .zig-cache/causal-artifacts/after.json cause 3") != null);
```

- [x] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect
zig test --dep causal_test --dep causal_compare --dep causal_query --dep causal_advice --dep causal_run --dep causal_artifact --dep causal_verdict -Mroot=tools/causal_loop.zig -Mcausal_test=tools/causal_test.zig -Mcausal_compare=tools/causal_compare.zig -Mcausal_query=tools/causal_query.zig -Mcausal_advice=tools/causal_advice.zig -Mcausal_run=tools/causal_run.zig -Mcausal_artifact=tools/causal_artifact.zig -Mcausal_verdict=tools/causal_verdict.zig --dep zigeffect -Mzigeffect=src/zigeffect.zig
```

Expected: FAIL because reports currently start query lines with `causal-query`.
Actual recovery note: this direct focused command later failed on local Zig
module wiring with `module 'zigeffect' declared but not used`; the recovery was
verified through the package build steps and `zig build examples`.

- [x] **Step 3: Implement the minimal change**

In `appendQuery`, change the command prefix from:

```zig
try command.print(allocator, "causal-query -- --file {s}", .{artifact_path});
```

to:

```zig
try command.print(allocator, "zig build causal-query -- --file {s}", .{artifact_path});
```

- [x] **Step 4: Verify green**

Run the same focused test command. Expected: PASS.

### Task 2: Add Root Bun Harness Scripts

**Files:**
- Modify: `package.json`

- [x] **Step 1: Add scripts**

Add these scripts:

```json
"zigeffect:causal-test": "cd packages/zigeffect && zig build causal-test",
"zigeffect:causal-dev-test": "cd packages/zigeffect && zig build causal-dev-test",
"zigeffect:causal-catalog": "cd packages/zigeffect && zig build causal-catalog",
"zigeffect:causal-artifacts": "cd packages/zigeffect && zig build causal-artifacts",
"zigeffect:causal-ci-handoff": "cd packages/zigeffect && zig build causal-ci-handoff",
"zigeffect:causal-loop:baseline": "cd packages/zigeffect && zig build causal-dev-loop -- baseline",
"zigeffect:causal-loop:after": "cd packages/zigeffect && zig build causal-dev-loop -- after"
```

- [x] **Step 2: Verify scripts**

Run:

```bash
bun run zigeffect:causal-catalog
bun run zigeffect:causal-artifacts
bun run zigeffect:causal-dev-test
```

Expected: each command exits 0.

### Task 3: Document The Recovery Workflow

**Files:**
- Create: `packages/zigeffect/docs/causal-dev-harness.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`

- [x] **Step 1: Add the guide**

Create a guide covering:

- root Bun commands;
- package failure workflow;
- before/after workflow;
- CI handoff workflow;
- safety boundaries and non-goals.

- [x] **Step 2: Link from agent guide**

Add a short reference near the causal dev-loop section so agents can find the
new guide.

### Task 4: Final Verification And Commit

**Files:**
- All files touched in this plan.

- [x] **Step 1: Run focused checks**

```bash
cd packages/zigeffect
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
zig test --dep causal_test --dep causal_compare --dep causal_query --dep causal_advice --dep causal_run --dep causal_artifact --dep causal_verdict -Mroot=tools/causal_loop.zig -Mcausal_test=tools/causal_test.zig -Mcausal_compare=tools/causal_compare.zig -Mcausal_query=tools/causal_query.zig -Mcausal_advice=tools/causal_advice.zig -Mcausal_run=tools/causal_run.zig -Mcausal_artifact=tools/causal_artifact.zig -Mcausal_verdict=tools/causal_verdict.zig --dep zigeffect -Mzigeffect=src/zigeffect.zig
```

Expected: all commands exit 0.
Actual recovery note: the direct `zig test ... -Mzigeffect=src/zigeffect.zig`
command was not the final verification path; `zig build examples` plus the
root causal harness scripts were used to prove the runnable workflow.

- [x] **Step 2: Run repo checks**

```bash
bun run check
bun run zig:test
git diff --check
```

Expected: all commands exit 0.

- [x] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-06-12-zigeffect-causal-dev-harness-recovery-design.md docs/superpowers/plans/2026-06-12-zigeffect-causal-dev-harness-recovery-implementation.md package.json packages/zigeffect/tools/causal_loop.zig packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/causal-dev-harness.md
git commit -m "feat(zigeffect): recover causal dev harness workflow"
```

## Completion Evidence

- Commit: `07f49b57 feat(zigeffect): recover causal dev harness workflow`
- Root scripts: `zigeffect:causal-test`, `zigeffect:causal-dev-test`,
  `zigeffect:causal-catalog`, `zigeffect:causal-artifacts`,
  `zigeffect:causal-ci-handoff`, `zigeffect:causal-loop:baseline`,
  `zigeffect:causal-loop:after`
- Guide: `packages/zigeffect/docs/causal-dev-harness.md`
