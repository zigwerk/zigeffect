# zigeffect Causal Advice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add deterministic causal advice reports so zigeffect development agents receive bounded next actions from saved causal artifacts.

**Architecture:** Create a new `causal_advice.zig` tool that parses causal JSON artifacts and emits rule-based action guidance. Wire it into `build.zig` as `zig build causal-advice`, then import it into `causal_loop.zig` so `causal-dev-loop -- after` writes an advice report beside compare and query reports.

**Tech Stack:** Zig 0.16, `std.json.parseFromSlice`, `std.Io`, existing `causal_artifact`, existing `causal_loop` report-writing pattern, Bun repo scripts.

---

## Files

- Create: `packages/zigeffect/tools/causal_advice.zig`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_loop.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`

## Task 1: RED Advice Tool Tests

- [ ] **Step 1: Create `packages/zigeffect/tools/causal_advice.zig` with failing tests**

Add sample causal JSON, a placeholder `buildAdviceReport`, and tests expecting:

```txt
zigeffect causal advice report
action provide-missing-service event=3
action close-resource event=4
action resolve-scoped-fiber event=5
action inspect-retry-exhaustion event=6
```

Also add tests for:

- `inspect-command-failure` from `assertion_recorded status=failure`;
- `inspect-finalizer-failure` from `resource_finalized status=failure`;
- empty advice output;
- taxonomy warning output.

- [ ] **Step 2: Verify RED**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: fail when the new tool test target is wired, or initially fail with
no build step before wiring.

## Task 2: Build The Advice Tool

- [ ] **Step 1: Add the build module**

In `packages/zigeffect/build.zig`, add `causal_advice_tool_module` after
`causal_query_tool_module`, import `causal_artifact`, add executable, build
step, and tests.

- [ ] **Step 2: Add examples aggregate dependencies**

Add the advice executable and tests to `examples_step`.

- [ ] **Step 3: Verify RED/compile failure**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: fail until `buildAdviceReport` is implemented.

## Task 3: Implement Advice Report Logic

- [ ] **Step 1: Parse artifacts**

Add `Artifact` and `Event` structs with `ignore_unknown_fields = true`.

- [ ] **Step 2: Implement advice selection**

Implement rules for:

- missing service;
- unfinalized resource;
- pending/running fiber;
- exhausted retry;
- assertion failure;
- finalizer failure.

- [ ] **Step 3: Format deterministic actions**

Each action should include `event`, `kind`, `label`, `why`, and exact
`zig build causal-query -- --file <artifact> ...` commands.

- [ ] **Step 4: Implement CLI**

Support:

```sh
zig build causal-advice -- --file <path>
zig build causal-advice -- <path>
```

Invalid args should print usage and exit nonzero without a Zig stack trace.

- [ ] **Step 5: Verify GREEN**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: pass.

## Task 4: Integrate Advice Into The Development Loop

- [ ] **Step 1: Import advice module**

In `build.zig`, add:

```zig
causal_loop_tool_module.addImport("causal_advice", causal_advice_tool_module);
```

- [ ] **Step 2: Add advice paths**

In `causal_loop.zig`, add `advice_report_path` to `LoopPaths`, default and
scenario path generation, deinit handling, and tests.

- [ ] **Step 3: Write advice during after phase**

In `runAfter`, after query report generation, call:

```zig
const advice_report = try causal_advice.buildAdviceReport(allocator, after, paths.after_json_path);
defer allocator.free(advice_report);
try writeArtifact(init.io, paths.advice_report_path, advice_report);
```

- [ ] **Step 4: Include path in summary**

After-phase summaries should print:

```txt
advice report: <path>
```

- [ ] **Step 5: Verify loop**

Run:

```sh
cd packages/zigeffect && zig build causal-dev-loop -- baseline
cd packages/zigeffect && zig build causal-dev-loop -- after
```

Expected: after phase writes advice report and prints its path.

## Task 5: Docs, Verification, And Commit

- [ ] **Step 1: Update docs**

Document:

- `zig build causal-advice -- --file <path>`;
- default and scenario advice report paths;
- advice is deterministic and non-mutating;
- development loop writes advice during the after phase.

- [ ] **Step 2: Run full verification**

Run:

```sh
cd packages/zigeffect && zig build causal-package-failure-fixture
cd packages/zigeffect && zig build causal-advice -- --file .zig-cache/causal-artifacts/zigeffect-causal-package-tests-failure-fixture.json
cd packages/zigeffect && zig build causal-dev-loop -- baseline
cd packages/zigeffect && zig build causal-dev-loop -- after
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test --summary none
bun run zig:test
git diff --check
```

- [ ] **Step 3: Commit**

Run:

```sh
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-advice-design.md \
  docs/superpowers/plans/2026-06-07-zigeffect-causal-advice.md \
  docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md \
  packages/zigeffect/tools/causal_advice.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/tools/causal_loop.zig \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/agent-observable-runtime.md \
  packages/zigeffect/docs/causal-scenarios.md \
  packages/zigeffect/docs/roadmap.md
git commit -m "feat(zigeffect): add causal advice reports"
```

## Self-Review

- Spec coverage: The plan covers the standalone advice command, deterministic
  advice rules, loop integration, docs, verification, and commit.
- Placeholder scan: No placeholder-only implementation steps remain.
- Type consistency: The plan consistently uses `causal-advice`,
  `causal_advice.zig`, and `advice_report_path`.
