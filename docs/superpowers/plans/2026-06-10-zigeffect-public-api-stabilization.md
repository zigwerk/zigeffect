# zigeffect Public API Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Milestone 45 by producing a public API review artifact,
locking the durable workflow and cluster facade shape with a focused test, and
documenting ownership, errors, schema versioning, direct-style Zig clarity, and
backend compatibility.

**Architecture:** The public review is a documentation contract under
`packages/zigeffect/docs/`. The public API stability test is a compile-time
contract under `packages/zigeffect/test/` and is available through a dedicated
`zig build public-api-review` step plus the normal all-test import.

**Tech Stack:** Zig, Zig build system, Bun wrapper verification commands,
Markdown documentation.

---

## File Responsibilities

Create:

- `packages/zigeffect/docs/public-api-review.md`: Milestone 45 review artifact
  and compatibility contract.
- `packages/zigeffect/test/public_api_stability_test.zig`: compile-time public
  API surface lock.

Modify:

- `packages/zigeffect/build.zig`: add focused `public-api-review` test step.
- `packages/zigeffect/test/all_test.zig`: import the public API stability test.
- `packages/zigeffect/README.md`: link the public API review.
- `packages/zigeffect/docs/architecture.md`: link the public API review from
  the facade contract section.
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`:
  mark Milestone 45 complete after verification.
- `docs/superpowers/plans/2026-06-10-zigeffect-public-api-stabilization.md`:
  track this plan.

## Task 1: Add The Public API Test Harness

- [x] Add `public-api-review` build wiring to `packages/zigeffect/build.zig`
  that points at `test/public_api_stability_test.zig`.
- [x] Import `public_api_stability_test.zig` from
  `packages/zigeffect/test/all_test.zig`.
- [x] Run `(cd packages/zigeffect && zig build public-api-review)` and confirm
  the gate fails because the test file is absent.

## Task 2: Lock The Public API Surface

- [x] Create `packages/zigeffect/test/public_api_stability_test.zig`.
- [x] Assert required root namespaces exist:
  `core`, `dependency`, `effect`, `runtime`, `layer`, `services`, `testing`,
  `traits`, `data`, `match`, `pattern`, `workflow`, `cluster`, `storage`, and
  `performance`.
- [x] Assert workflow stable exports exist for workflow definitions, activity
  definitions, journal stores, workflow engine, workflow context, durable clock,
  durable deferreds, durable signals, durable queues, scheduler, lifecycle, and
  ownership helpers.
- [x] Assert cluster stable exports exist for entity identity, local actor
  runtime, mailbox storage, message storage, runner storage, shard leases,
  fencing, cluster runtime, transport, cluster workflow engine, timer wakeups,
  durable queue indexes, local cluster runners, and ownership helpers.
- [x] Assert selected top-level aliases point to namespace exports.
- [x] Assert workflow, cluster, storage, and performance schema constants remain
  version `1`.
- [x] Assert public error sets include the documented members.
- [x] Run `(cd packages/zigeffect && zig build public-api-review)` and confirm
  the focused gate passes.

## Task 3: Write The Public API Review Artifact

- [x] Add `packages/zigeffect/docs/public-api-review.md`.
- [x] Cover namespace naming, stable durable workflow exports, stable cluster
  exports, ownership and allocator contracts, error-set and diagnostic policy,
  schema versioning, direct-style Zig clarity, and backend compatibility.
- [x] Include a review closeout table that records no unresolved naming or
  ownership issues.
- [x] Link the new document from `packages/zigeffect/README.md`.
- [x] Link the new document from `packages/zigeffect/docs/architecture.md`.

## Task 4: Verify The Milestone

- [ ] Run:

```bash
(cd packages/zigeffect && zig build public-api-review)
bun run zigeffect:test
bun run zig:test
(cd packages/zigeffect && zig build examples)
zig fmt --check \
  packages/zigeffect/test/public_api_stability_test.zig \
  packages/zigeffect/test/all_test.zig \
  packages/zigeffect/build.zig
git diff --check
```

- [ ] Run a scoped marker scan over the new M45 files and edited roadmap lines.
- [ ] Update the roadmap Milestone 45 deliverables and acceptance after the
  verification gate passes.
- [ ] Re-run the focused gate and diff checks after the roadmap edit.
- [ ] Commit the milestone with a clear message.
