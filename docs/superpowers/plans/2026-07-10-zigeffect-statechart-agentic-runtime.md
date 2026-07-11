# ZigEffect Statechart Agentic Runtime Master Roadmap

Date: 2026-07-10
Goal: deliver the statechart/actor subsystem end to end as a flagship agentic-development capability
Design: `docs/superpowers/specs/2026-07-10-zigeffect-statechart-agentic-runtime-design.md`

## Execution Rules

- Work milestone-by-milestone in dependency order.
- Add a failing test before every behavior change.
- Keep the pure semantic kernel independent of Effect, workflow, storage, causal,
  CLI, and workbench code.
- Keep context value-semantic and commands typed; external work runs only through
  Effect adapters.
- Preserve the workflow journal as the durability authority and causal storage as
  linked evidence.
- Add runtime capability under `src/`; do not create report-about-report tools.
- Do not mark a milestone complete without its focused acceptance gates.
- Do not overwrite or reformat unrelated dirty worktree files.

## Requirement Ledger

| ID | Requirement | Owning milestone |
|---|---|---|
| SC-001 | Immutable typed definitions with stable ids and metadata | M1 |
| SC-002 | Deterministic validation and definition fingerprint | M1 |
| SC-003 | Pure transition decisions with ordered guards | M2 |
| SC-004 | Transactional actions, context rollback, and typed commands | M2 |
| SC-005 | Final, targetless, self, internal, and external transitions | M2 |
| SC-006 | Bounded internal/eventless macrosteps | M3 |
| SC-007 | Reachability, dead-end, ambiguity, and cycle analysis | M4 |
| SC-008 | Versioned definition, snapshot, execution, and coverage artifacts | M5 |
| SC-009 | Native JSON, XState v5, Mermaid, and DOT projection | M5 |
| SC-010 | Scoped mailbox-driven machine actors | M6 |
| SC-011 | Inspection subscriptions, children, cancellation, and supervision | M6 |
| SC-012 | Statechart causal facts, mappings, findings, and graph links | M7 |
| SC-013 | Stable agent CLI queries and JSON output | M7 |
| SC-014 | Workflow journal records, replay, snapshots, and migrations | M8 |
| SC-015 | Durable commands through activities, timers, signals, and queues | M8 |
| SC-016 | Crash recovery and idempotent command delivery | M8 |
| SC-017 | Compound states and entry/exit ancestry semantics | M9 |
| SC-018 | Parallel regions and deterministic conflict resolution | M9 |
| SC-019 | Shallow/deep history and completion events | M9 |
| SC-020 | Invoked/spawned actors and actor-system communication | M10 |
| SC-021 | Cluster entity ownership and cross-service trace propagation | M10 |
| SC-022 | Synchronized statechart and actor workbench graph modes | M11 |
| SC-023 | Runtime overlays, coverage, replay scrub, and definition diff | M11 |
| SC-024 | Scaffolding, examples, docs, and agent authoring guidance | M12 |
| SC-025 | Model-based testing and XState path conformance | M12 |
| SC-026 | Security, redaction, resource, performance, and fuzz hardening | M13 |
| SC-027 | Public API, compatibility, migrations, and release evidence | M13 |

## Dependency Graph

```text
M0 design/roadmap
  -> M1 definition
      -> M2 transition kernel
          -> M3 macrosteps
              -> M4 analysis
              -> M5 artifacts/export
              -> M6 actor runtime
                  -> M7 causal/CLI
                  -> M8 workflow durability
                  -> M10 actor systems/cluster
              -> M9 full statecharts
                  -> M10 actor systems/cluster
                  -> M11 workbench
          -> M12 authoring/testing
  -> M13 production/release (consumes all milestones)
```

## M0 — Architecture, Evidence, And Task Contract

Status: completed

Tasks:

1. Record the accepted native-runtime/XState-adapter decision.
2. Record the semantic, ownership, durability, causal, artifact, and workbench boundaries.
3. Record the requirement ledger, milestone dependencies, and verification matrix.
4. Record current candidate-library research and the no-runtime-dependency decision.
5. Preserve existing worktree changes and identify clean extension files.

Acceptance:

- Design spec and this master roadmap exist under `docs/superpowers/`.
- Every product requirement maps to a milestone.
- Initial public semantics and explicit non-decisions are documented.

## M1 — Typed Definition IR And Validation

Requirements: SC-001, SC-002

Files:

- `packages/zigeffect/src/statechart/definition.zig`
- `packages/zigeffect/src/statechart/root.zig`
- `packages/zigeffect/test/statechart_definition_test.zig`
- `packages/zigeffect/test/public_api_stability_test.zig`

Test-first tasks:

1. Add failing tests for enum and tagged-union event metadata.
2. Add failing tests for stable state, event, transition, action, and command ids.
3. Add failing tests for duplicate ids, missing targets, missing initial state,
   final-state outgoing transitions, and invalid bounds.
4. Add failing tests for stable definition fingerprints across identical builds.
5. Implement typed node, transition, guard, action, bounds, source-ref, and metadata types.
6. Implement deterministic validation with stable finding ids.
7. Re-export the facade through `zigeffect.zig` and lock the API in public tests.

Acceptance:

- Valid definitions construct without allocation.
- Invalid definitions return deterministic diagnostics or compile errors as appropriate.
- Function pointers never appear in metadata or fingerprints.
- `zig build test-raw` and `zig build public-api-review` pass.

## M2 — Pure Transition Kernel

Requirements: SC-003, SC-004, SC-005

Files:

- `packages/zigeffect/src/statechart/machine.zig`
- `packages/zigeffect/test/statechart_machine_test.zig`

Test-first tasks:

1. Select transitions by active state, event tag, definition order, and guard order.
2. Support event payloads for tagged unions and plain enum events.
3. Stage a context copy and bounded typed command buffer.
4. Execute exit, transition, and entry actions in deterministic order.
5. Roll back context and commands when an action or bound fails.
6. Support ignored events, invalid events, targetless transitions, explicit
   self-reentry, internal transitions, external transitions, and final states.
7. Emit a typed decision with previous/next snapshots and stable fingerprints.
8. Prove same definition/snapshot/event produces the same decision.

Acceptance:

- Kernel imports no service, workflow, storage, causal, or OS modules.
- No command is released from a rejected decision.
- Property tests prove determinism and rollback.
- Debug and ReleaseSafe focused tests pass.

## M3 — Internal Events And Bounded Macrosteps

Requirements: SC-006

Files:

- `packages/zigeffect/src/statechart/macrostep.zig`
- `packages/zigeffect/test/statechart_macrostep_test.zig`

Test-first tasks:

1. Add a bounded FIFO internal-event queue.
2. Add eventless transitions after external/internal transitions.
3. Stabilize until no eventless transition remains.
4. Detect deterministic eventless cycles and macrostep exhaustion.
5. Bound transitions, internal events, commands, and inspection records.
6. Preserve transactional rollback for an entire failed macrostep.

Acceptance:

- Infinite eventless logic terminates with a typed bound error.
- Transient states remain visible in inspection microsteps.
- Allocation and bound failure tests pass.

## M4 — Static Analysis And Model Graph

Requirements: SC-007

Files:

- `packages/zigeffect/src/statechart/analysis.zig`
- `packages/zigeffect/test/statechart_analysis_test.zig`

Test-first tasks:

1. Build deterministic adjacency and reverse-adjacency models.
2. Report unreachable states and non-final dead ends.
3. Report ambiguous unguarded transitions and statically shadowed fallbacks.
4. Report immediate eventless cycles and unsafe self loops.
5. Compute state, event, and transition coverage requirements.
6. Generate bounded shortest and simple paths for flat machines.
7. Emit stable source-linked diagnostics and repair hints.

Acceptance:

- Analysis never executes guards or actions.
- Output ordering and finding ids are stable.
- Path generation is bounded and deterministic.

## M5 — Artifacts And XState Interoperability

Requirements: SC-008, SC-009

Files:

- `packages/zigeffect/src/statechart/artifact.zig`
- `packages/zigeffect-std/src/statechart/`
- `packages/zigeffect/test/statechart_artifact_test.zig`
- `packages/zigeffect-std/test/statechart_test.zig`

Test-first tasks:

1. Define versioned definition, snapshot, execution, and coverage schemas.
2. Format bounded native JSON with redacted context policy.
3. Parse current schemas and fail closed on future/missing migrations.
4. Export XState v5-compatible configuration using symbolic implementations.
5. Export Mermaid `stateDiagram-v2` and Graphviz DOT.
6. Report projection loss rather than silently changing semantics.
7. Add deterministic golden fixtures and round-trip tests.

Acceptance:

- Artifacts contain no function pointers, services, credentials, or raw context by default.
- Golden outputs are byte-stable.
- `zigeffect-std` tests/examples pass without disturbing unrelated causal-graph work.

## M6 — Effect Actor Runtime And Inspection

Requirements: SC-010, SC-011

Files:

- `packages/zigeffect/src/statechart/actor.zig`
- `packages/zigeffect/src/statechart/inspect.zig`
- `packages/zigeffect/test/statechart_actor_test.zig`

Test-first tasks:

1. Implement stable actor instance ids and parent/child ownership.
2. Implement bounded mailbox offer/take/overflow policies.
3. Process one event at a time through the pure kernel.
4. Publish bounded snapshot and inspection subscriptions.
5. Execute typed commands through injected Effect services.
6. Feed command completion/failure back as typed events.
7. Implement scoped start/stop/interruption and supervisor decisions.
8. Prove isolation between multiple actors using one definition.

Acceptance:

- Actor shutdown drains or rejects events according to explicit policy.
- Child resources finalize with their parent scope.
- Deterministic fakes cover clocks, executors, and concurrency.

## M7 — Causal Evidence, Embedded Graph, And Agent Queries

Requirements: SC-012, SC-013

Files:

- `packages/zigeffect/src/statechart/causal.zig`
- `packages/zigeffect/src/services/causal.zig`
- `packages/zigeffect-cli/src/`
- focused causal and CLI tests

Test-first tasks:

1. Add the statechart causal extension domain and generic event kind.
2. Map statechart execution records to causal envelopes with stable correlation.
3. Mirror accepted actor decisions after authoritative state changes.
4. Record guard, macrostep, command, child, replay, and divergence evidence.
5. Add redaction, truncation, taxonomy, backend, JSONL, DOT, and graph-storage tests.
6. Implement `statechart list/show/instances/trace/explain/coverage/paths/export`.
7. Emit stable JSON and actionable source-linked diagnostics.

Acceptance:

- Structural statechart evidence is non-sampleable.
- Causal backend failure cannot duplicate an accepted transition.
- CLI accepts no arbitrary execution or unsafe path inputs.
- Tool-hygiene gate remains green with no new `causal_*` report tools.

## M8 — Durable Workflow Statecharts

Requirements: SC-014, SC-015, SC-016

Files:

- `packages/zigeffect/src/workflow/statechart.zig`
- workflow journal/store/replay schema migrations
- focused workflow crash and property tests

Test-first tasks:

1. Add versioned machine instance, event, decision, snapshot, and command records.
2. Rebuild snapshots by folding journal records.
3. Add snapshot checkpoints with bounded replay fallback.
4. Map commands onto activities, timers, signals, queues, and child workflows.
5. Enforce idempotency keys and exactly-once decision acceptance.
6. Test every crash point between decision, append, command dispatch, and result.
7. Add schema migrations and future-version fail-closed behavior.
8. Mirror successful journal appends through the existing causal decorator pattern.

Acceptance:

- Journal history is sufficient to reconstruct every snapshot.
- Replay performs no external command twice.
- Crash/property/storage conformance tests pass in Debug and ReleaseSafe.

## M9 — Compound, Parallel, And History Semantics

Requirements: SC-017, SC-018, SC-019

Files:

- statechart definition/kernel/analysis extensions
- SCXML-derived conformance fixtures

Test-first tasks:

1. Represent atomic, compound, parallel, final, and history nodes.
2. Resolve initial descendants and active configurations.
3. Select descendant-before-ancestor transitions.
4. Compute least common compound ancestors and entry/exit sets.
5. Resolve conflict-free parallel transitions deterministically.
6. Record shallow and deep history configurations.
7. Generate done events for compound and parallel completion.
8. Extend analysis, artifacts, fingerprints, coverage, and projections.

Acceptance:

- Entry/exit order matches documented SCXML-derived fixtures.
- Parallel processing uses deterministic logical concurrency, not implicit threads.
- Hierarchy depth and active-region bounds fail safely.

## M10 — Invoked Actors, Actor Systems, And Cluster Ownership

Requirements: SC-020, SC-021

Files:

- statechart actor/runtime extensions
- cluster entity adapter
- actor-system and cluster tests

Test-first tasks:

1. Invoke and stop child machine actors from state entry/exit.
2. Spawn durable and ephemeral children with explicit ownership.
3. Implement typed send, reply, correlation, dead-letter, and timeout behavior.
4. Persist child references and restore durable actor trees.
5. Add receptionist/registry-style logical addressing.
6. Map long-lived machines to cluster entities with lease fencing.
7. Propagate trace/boundary ids across service and cluster messages.
8. Test supervisor restart/escalation and shard recovery.

Acceptance:

- Parent interruption cannot orphan children.
- Lease loss fences journal writes and command execution.
- Cross-service traces join into one causal investigation.

## M11 — SolidJS Workbench Statechart And Actor Views

Requirements: SC-022, SC-023

Files:

- `packages/zigeffect/workbench/src/statechart/`
- workbench artifact/model, graph adapter, inspector, fixtures, tests

Test-first tasks:

1. Parse versioned statechart artifacts into a pure TypeScript model.
2. Add graph modes `causal`, `statechart`, and `actors` to the one G6 surface.
3. Render nested/parallel states, transitions, guards, actions, and current configuration.
4. Overlay visited paths, counts, failures, commands, coverage, and replay position.
5. Synchronize graph, trace, findings, collaboration evidence, and inspector selection.
6. Add definition-version diff and replay scrub without mutation authority.
7. Load XState projections in tests and compare reachable graph paths.
8. Add desktop/mobile browser and nonblank-canvas verification.

Acceptance:

- Humans can inspect all agent-authored machine logic and the exact path taken.
- Workbench remains local, bounded, redacted, read-only, and usable without Stately.
- Tests, typecheck, build, desktop, and mobile checks pass.

## M12 — Agent Authoring, Scaffolds, Examples, And Model Testing

Requirements: SC-024, SC-025

Files:

- `zigeffect generate/add` templates and snapshots
- `packages/zigeffect/examples/`
- `packages/zigeffect-std/examples/`
- agent/application documentation

Test-first tasks:

1. Add generators for machine, actor, durable workflow machine, and test model.
2. Add compile-time diagnostics that teach the correct repair.
3. Generate source descriptions and stable ids by default.
4. Add minimal, guarded, command, durable, hierarchical, parallel, and actor-system examples.
5. Generate shortest-path and transition-coverage tests.
6. Add XState/Mermaid export commands and workbench launch links.
7. Update Codex/Claude agent guidance and project capabilities.
8. Prove scaffold builds/tests in Debug and ReleaseSafe.

Acceptance:

- A new agent can generate, run, inspect, test, and visualize a machine without
  hand-writing framework wiring.
- Generated projects remain user-owned and upgrade-safe.

## M13 — Production Hardening And Release

Requirements: SC-026, SC-027

Test-first tasks:

1. Add fuzz/property suites for definitions, events, replay, artifacts, and migrations.
2. Add allocation-failure and resource-bound coverage for every owned structure.
3. Add redaction sentinels and hostile context/event/description fixtures.
4. Add performance budgets for transition latency, mailbox throughput, replay, and graph size.
5. Add public API and schema compatibility matrices.
6. Add audit-chain evidence for every acceptance gate.
7. Run Debug, ReleaseSafe, workbench browser, scaffold, CLI, std, and repository gates.
8. Document unpassed gates honestly and produce the final agent handoff.

Acceptance commands:

```sh
cd packages/zigeffect && zig build test-raw
cd packages/zigeffect && zig build test-raw -Doptimize=ReleaseSafe
cd packages/zigeffect && zig build public-api-review
cd packages/zigeffect && ./tools/check_tool_hygiene.sh
bun run zigeffect:std:test
bun run zigeffect:cli:test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
bun run check
bun run zig:test
bun run zigeffect:local-release
git diff --check
```

Final acceptance:

- All SC-001 through SC-027 requirements have passing evidence.
- Every documented schema has compatibility and migration coverage.
- Agent CLI and workbench can explain one local, durable, and clustered machine run.
- XState projection equivalence passes for the supported feature matrix.
- No secrets or raw unsafe context appear in artifacts or evidence.
- The goal is handed off with bounded causal evidence and no unreported failed gate.

## Current Work Queue

All M0-M13 implementation work is complete. The closed blocker ledger and exact
verification record live in
`docs/superpowers/specs/2026-07-10-zigeffect-statechart-production-readiness-audit.md`.
Future work is additive product evolution: new SCXML features, new storage or
transport adapters, and richer workbench authoring must each add their own
compatibility and conformance evidence rather than weakening the current gates.
