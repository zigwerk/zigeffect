# zigeffect Causal Advice Deltas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make causal advice distinguish new after-patch evidence from persisting baseline evidence.

**Architecture:** Extend `causal_advice.zig` with reusable advice action collection and stable action signatures. Keep `buildAdviceReport` for single-artifact output, add `buildAdviceReportWithBaseline`, update CLI parsing for `--before`, and have `causal_loop.zig` call the before-aware helper during `after`.

**Tech Stack:** Zig 0.16, `std.json.parseFromSlice`, existing `causal_advice.zig`, `causal_loop.zig`, `std.ArrayList`, Bun repo scripts.

---

## Files

- Modify: `packages/zigeffect/tools/causal_advice.zig`
- Modify: `packages/zigeffect/tools/causal_loop.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`

## Task 1: RED Tests For Advice Status

- [ ] **Step 1: Add single-artifact status expectation**

Update the existing advice tests to expect:

```txt
action provide-missing-service status=observed event=3
```

- [ ] **Step 2: Add before/after tests**

Add tests for `buildAdviceReportWithBaseline`:

- matching action with different event id becomes `status=persisting`;
- after-only action becomes `status=new`;
- header includes `baseline: <path>`.

- [ ] **Step 3: Verify RED**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: fail because status labels and `buildAdviceReportWithBaseline` do not
exist.

## Task 2: Implement Action Collection And Status Formatting

- [ ] **Step 1: Add `AdviceStatus` and `AdviceAction`**

Represent action data separately from final formatting.

- [ ] **Step 2: Extract current rule loop into `collectActions`**

Collect after actions with action name, event, why text, and query commands.

- [ ] **Step 3: Add stable matching**

Implement a signature comparison based on action name, event kind, label,
type_name, status, `run_id`, and `scope_id`.

- [ ] **Step 4: Format statuses**

Single artifact uses `observed`; before-aware output uses `persisting` or
`new`.

- [ ] **Step 5: Verify GREEN**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: pass.

## Task 3: CLI Before Flag

- [ ] **Step 1: Add CLI parsing for `--before`**

Support:

```sh
zig build causal-advice -- --before <before.json> --file <after.json>
zig build causal-advice -- --file <after.json> --before <before.json>
```

- [ ] **Step 2: Verify CLI behavior**

Run:

```sh
cd packages/zigeffect
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
zig build causal-advice -- --before .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json --file .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json
```

Expected: output includes `baseline:` and `status=persisting`.

## Task 4: Loop Integration

- [ ] **Step 1: Change `runAfter`**

Replace the single-artifact advice call with:

```zig
const advice_report = try causal_advice.buildAdviceReportWithBaseline(
    allocator,
    before,
    paths.before_json_path,
    after,
    paths.after_json_path,
);
```

- [ ] **Step 2: Verify loop advice**

Run:

```sh
cd packages/zigeffect && zig build causal-dev-loop -- baseline && zig build causal-dev-loop -- after
rg "status=persisting" packages/zigeffect/.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt
```

Expected: at least one persisting action is present.

## Task 5: Docs, Verification, And Commit

- [ ] **Step 1: Update docs**

Document:

- `--before <before.json>`;
- `status=observed`, `status=persisting`, and `status=new`;
- loop advice is before-aware during after phase.

- [ ] **Step 2: Run full verification**

Run:

```sh
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test --summary none
cd packages/zigeffect && zig build causal-dev-loop -- baseline
cd packages/zigeffect && zig build causal-dev-loop -- after
cd packages/zigeffect && zig build causal-advice -- --before .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json --file .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json
bun run zig:test
git diff --check
```

- [ ] **Step 3: Commit**

Run:

```sh
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-advice-deltas-design.md \
  docs/superpowers/plans/2026-06-07-zigeffect-causal-advice-deltas.md \
  docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md \
  packages/zigeffect/tools/causal_advice.zig \
  packages/zigeffect/tools/causal_loop.zig \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/agent-observable-runtime.md \
  packages/zigeffect/docs/causal-scenarios.md \
  packages/zigeffect/docs/roadmap.md
git commit -m "feat(zigeffect): make causal advice delta-aware"
```

## Self-Review

- Spec coverage: The plan covers status labels, before-aware matching, CLI
  flags, loop integration, docs, verification, and commit.
- Placeholder scan: No placeholder-only implementation steps remain.
- Type consistency: The plan consistently uses `status=observed`,
  `status=persisting`, `status=new`, `--before`, and
  `buildAdviceReportWithBaseline`.
