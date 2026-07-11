# ZigEffect Agent Workflow Studio And Control Plane Roadmap

Date: 2026-07-11
Design: `docs/superpowers/specs/2026-07-11-zigeffect-agent-workflow-studio-design.md`
Goal: deliver the complete agent-authored workflow lifecycle from proposal to production operation

## Execution rules

- Work in dependency order and add a failing test before runtime behavior.
- Keep typed execution in Zig; portable plans generate source and never bypass
  compilation.
- Keep proposals immutable and separate approval from application authority.
- Extend runtime `src/` and existing CLI surfaces; do not add report-only tools.
- Preserve concurrent testing-v2 and unrelated worktree changes.
- Update public API locks, compatibility matrices, templates and snapshots when
  contracts change.
- No milestone is complete without focused Debug and ReleaseSafe evidence.

## Milestones

### W0 — Release baseline and contract lock

Requirements: AWS-017, AWS-018

1. Finish or isolate concurrently incomplete repository testing modules.
2. Run existing statechart Debug/ReleaseSafe/public API/hygiene/workbench gates.
3. Run repository local-release and record a clean baseline.
4. Freeze existing definition/artifact v2 and durable-record v1 compatibility.

Acceptance: every pre-existing required gate passes before new schemas land.

### W1 — Native version lineage and semantic diff

Requirements: AWS-001, AWS-002, AWS-005, AWS-017

Files:

- `src/statechart/version.zig`
- `test/statechart_version_test.zig`
- statechart root/public API tests

Tasks:

1. Define version identity, parent identity, change/risk and deployment enums.
2. Compare same-typed definitions without executing reducers.
3. Include states, transitions, guards, actions, invocations, bounds and metadata.
4. Classify metadata/additive/behavioral/migration/breaking changes.
5. Produce deterministic finding ids and compatibility recommendations.

Acceptance: byte/order-stable diff facts and safe classification fixtures.

### W2 — Proposal, proof, review, approval and registry artifacts

Requirements: AWS-001, AWS-003, AWS-004, AWS-005, AWS-007, AWS-017

Files:

- `zigeffect-std/src/statechart/studio.zig`
- std statechart tests and catalog extensions

Tasks:

1. Add versioned bounded artifact parsers/formatters.
2. Bind every record to content, definition and proof digests.
3. Derive proposal status from immutable records.
4. Reject stale/mismatched/expired approvals.
5. Add version registry and atomic history storage with recovery.
6. Add catalog-v2 reader/writer while retaining v1 input.

Acceptance: malformed/future/stale/redaction/allocation/atomic-recovery tests pass.

### W3 — Deterministic simulation and verification

Requirements: AWS-007, AWS-008, AWS-015

Files:

- `src/statechart/simulation.zig`
- `src/statechart/invariant.zig`
- focused model/mutation/migration tests

Tasks:

1. Add bounded event-path simulation over native macrosteps.
2. Add transition/state breakpoints and trace snapshots.
3. Add always, eventually, never, precedes and terminal temporal invariants.
4. Add deterministic transition deletion/guard inversion/target mutation models.
5. Join existing determinism, paths, XState oracle, testing-v2 virtual world and
   budget evidence into proof entries.

Acceptance: shortest replayable failures, honest truncation and stable proof ids.

### W4 — Policy-gated runtime control plane

Requirements: AWS-009, AWS-010, AWS-011, AWS-012

Files:

- `src/statechart/control.zig`
- workflow lifecycle/engine and actor-system adapters
- statechart causal extensions and focused tests

Tasks:

1. Define typed requests, policy decisions, receipts and adapter vtable.
2. Implement inspect/start/signal/suspend/resume/cancel/retry/checkpoint/drain.
3. Enforce expected fingerprint, lease epoch, ownership and idempotency.
4. Add explicit migration/restart deployment adapters.
5. Record accepted, denied, stale, duplicate and failed causal evidence.
6. Build bounded fleet registry queries and health classifications.

Acceptance: no mutation without policy and no stale owner/definition acceptance.

### W5 — Portable agent plan compiler and patterns

Requirements: AWS-006, AWS-013

Files:

- `zigeffect-std/src/statechart/plan.zig`
- CLI generator/templates and focused tests

Tasks:

1. Define bounded `WorkflowPlan v1` JSON and validation.
2. Expand reusable patterns with namespaced stable ids.
3. Generate deterministic typed Zig definition/action/adapter skeletons.
4. Emit requirements, invariants, tests and source descriptions.
5. Compile generated Debug/ReleaseSafe projects for all patterns.

Acceptance: identical plan produces identical source/digest and every pattern is
visible, analyzable and independently replaceable.

### W6 — CLI workflow lifecycle

Requirements: AWS-016

1. Add propose/verify/review/approve/apply/simulate/control/fleet/migrate parsing.
2. Keep read-only commands available without mutation authority.
3. Require dry-run support and explicit policy for mutations.
4. Write immutable receipts and atomic version/proposal stores.
5. Update completions, help, compatibility snapshots and generated skills.

Acceptance: manifest-owned paths only, no unsafe ids, generated projects green.

### W7 — SolidJS Statechart Studio

Requirements: AWS-014

Files:

- `workbench/src/statechart/studioModel.ts`
- proposal/simulation/proof/fleet/operations UI components
- App/model/styles/browser tests

Tasks:

1. Parse all new schemas with strict bounds and u64 strings.
2. Add proposal and version selectors plus graph semantic diff.
3. Add simulator event path, breakpoint and replay controls.
4. Add proof matrix, gaps and invariant failure navigation.
5. Add fleet/instance pending-work and health inspection.
6. Send permitted controls only through authenticated host boundary.
7. Verify desktop/narrow viewport and nonblank graph behavior.

Acceptance: a human can understand proposed logic, proof and live impact before
requesting any mutation.

### W8 — Production adapters, migration and chaos

Requirements: AWS-012, AWS-015

1. Add snapshot migration registry/dry-run/reverse-availability checks.
2. Add drain-and-replace and new-instances-only deployment fixtures.
3. Exercise crash points around proposal apply, registry swap and control receipt.
4. Exercise redelivery, partition, stale fence and conflicting catalog writes.
5. Add fleet and Studio performance/resource budgets.

Acceptance: deterministic recovery with no unreported partial application.

### W9 — Examples, docs and final release

Requirements: AWS-018

1. Add end-to-end approval, parallel research, saga and remediation examples.
2. Publish operator, author, migration and security guides.
3. Run Debug, ReleaseSafe, public API, hygiene, std, CLI integration, generated
   projects, workbench test/typecheck/build, browser, repository and local release.
4. Record exact evidence and every intentionally unsupported feature.

Acceptance: AWS-001 through AWS-018 have executable evidence and one complete
agent-plan-to-durable-operation demonstration.

## Current work queue

1. W0–W8 implementation complete in the shared worktree.
2. W9 final Debug/ReleaseSafe/public API/hygiene/std/CLI/generated-project/
   Workbench/local-release evidence complete and recorded in the release ledger.
3. In-app browser visual inspection remains externally blocked by the browser
   URL safety policy; do not bypass that control. This is the only remaining
   manual sign-off and does not represent an unverified runtime or build gate.

## Delivered implementation map

- W1: native semantic version diff and deployment recommendations.
- W2: digest-recomputed proposal, proof, review, approval, application and
  version-history contracts with decimal-string u64 wire identities.
- W3: flat and hierarchical bounded simulation, breakpoints, time travel,
  temporal invariants and deterministic mutation catalogs.
- W4: default-deny control plane, causal/idempotent receipts, actor-system and
  durable workflow adapters, governed approval policy and fleet snapshots.
- W5: strict portable plan compiler plus twelve explicit agentic patterns,
  including hierarchical parallel research and negative terminal paths.
- W6: plan compilation, pattern, governance, version, Studio, fleet and control
  evidence CLI workflows with preview-by-default and root-confined writes.
- W7: SolidJS Statechart Studio with auditable logic, proof, governance, fleet,
  version diff, replay and XState equivalence surfaces.
- W8: exact-fingerprint reversible migration registry, atomic catalog recovery,
  mutation points, generated Debug/ReleaseSafe pattern matrix and full-range
  identity tests.
