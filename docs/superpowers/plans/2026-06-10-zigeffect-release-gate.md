# zigeffect Release Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Milestone 46 by adding one release-gate command, a durable
workflow crash recovery example, release report artifacts, CI artifact paths,
README quickstart, migration notes, and a completion report.

**Architecture:** `zig build release-gate` composes existing focused gates and
the new report tool. `workflow_crash_recovery.zig` proves the file journal can
trim a partial trailing row and replay committed workflow state. Docs explain
how to run the gate and how to migrate deterministic programs to durable
workflow and cluster runtime surfaces.

**Tech Stack:** Zig, Zig build system, Bun scripts, GitHub Actions, Markdown.

---

## File Responsibilities

Create:

- `packages/zigeffect/examples/workflow_crash_recovery.zig`: durable workflow
  crash recovery example and test.
- `packages/zigeffect/tools/release_gate_report.zig`: deterministic release
  gate text and JSON report writer.
- `packages/zigeffect/docs/migration-to-durable-runtime.md`: migration notes.
- `docs/superpowers/reports/2026-06-10-zigeffect-milestone-46-completion.md`:
  milestone completion report.

Modify:

- `packages/zigeffect/build.zig`: wire the new example, report tool, and
  `release-gate` step.
- `packages/zigeffect/README.md`: add quickstart and docs links.
- `.github/workflows/zigeffect-causal.yml`: run the release gate and upload
  release-gate reports.
- `package.json`: add `zigeffect:release`.
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`:
  mark Milestone 46 complete after verification.
- `docs/superpowers/plans/2026-06-10-zigeffect-release-gate.md`: track this
  plan.

## Task 1: Add The Red Release Gate Wiring

- [x] Add build wiring for `examples/workflow_crash_recovery.zig`.
- [x] Add build wiring for `tools/release_gate_report.zig`.
- [x] Add `zig build release-gate` that depends on the package test gate,
  public API review, storage conformance, property crash tests, performance
  bounds, examples, causal artifact generation, and release report generation.
- [x] Add `zigeffect:release` to `package.json`.
- [x] Run `(cd packages/zigeffect && zig build release-gate)` and confirm it
  fails because the new example and report tool files are absent.

## Task 2: Implement The Crash Recovery Example

- [x] Create `packages/zigeffect/examples/workflow_crash_recovery.zig`.
- [x] Write a scenario that appends committed workflow events to
  `FileJournalStore`, appends a partial trailing JSON row, reopens the store,
  and reports recovered partial bytes plus replay state.
- [x] Add a test that asserts the committed state survives and the partial row
  is trimmed.
- [x] Run `(cd packages/zigeffect && zig build examples)` and confirm the new
  example passes.

## Task 3: Implement The Release Report Tool

- [x] Create `packages/zigeffect/tools/release_gate_report.zig`.
- [x] Write text and JSON reports with schema, command, included gate names,
  proof labels, artifact paths, migration doc path, and completion report path.
- [x] Write tests for stable report paths and required content.
- [x] Run `(cd packages/zigeffect && zig build release-gate)` and confirm the
  release gate passes.

## Task 4: Add Docs And CI Paths

- [x] Update README with release-gate quickstart and docs links.
- [x] Add `packages/zigeffect/docs/migration-to-durable-runtime.md`.
- [ ] Add the Milestone 46 completion report under `docs/superpowers/reports/`.
- [x] Update `.github/workflows/zigeffect-causal.yml` to run
  `zig build release-gate --summary none`.
- [x] Add `.zig-cache/release-gate/*.txt` and `.zig-cache/release-gate/*.json`
  to the CI artifact upload paths.

## Task 5: Verify And Close Milestone 46

- [ ] Run:

```bash
(cd packages/zigeffect && zig build release-gate)
bun run zigeffect:test
bun run zig:test
(cd packages/zigeffect && zig build examples)
zig fmt --check packages/zigeffect/build.zig \
  packages/zigeffect/examples/workflow_crash_recovery.zig \
  packages/zigeffect/tools/release_gate_report.zig
git diff --check
```

- [ ] Run a scoped marker scan over new and edited M46 files.
- [ ] Mark Milestone 46 roadmap deliverables and acceptance complete.
- [ ] Re-run the focused release gate and diff checks after the roadmap edit.
- [ ] Commit the milestone with a clear message.
