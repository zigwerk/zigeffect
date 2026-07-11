# ZigEffect Statechart Production Readiness Audit

Date: 2026-07-10
Roadmap: `docs/superpowers/plans/2026-07-10-zigeffect-statechart-agentic-runtime.md`
Design: `docs/superpowers/specs/2026-07-10-zigeffect-statechart-agentic-runtime-design.md`
Production guide: `packages/zigeffect/docs/statecharts-production.md`

## Verdict

The 25 implementation blockers identified by the initial audit are closed with
executable evidence. The subsystem is suitable as ZigEffect's production
statechart offering within its documented feature and storage/transport
contracts. It is not presented as a complete implementation of the entire SCXML
standard, nor does it claim exactly-once behavior from arbitrary external
systems.

The native Zig runtime remains authoritative. XState v5 is an executable
projection/conformance oracle and visualization ecosystem adapter, not a runtime
dependency in deployed Zig programs.

## Closed blocker ledger

| # | Closure | Primary evidence |
|---:|---|---|
| 1 | Flat and hierarchical initialization are typed transactions; actors and durable machines cannot skip initial entry/invocation behavior. | `statechart_machine_test.zig`, `statechart_configuration_test.zig`, `statechart_actor_test.zig`, `workflow_statechart_test.zig` |
| 2 | History default guards, actions, targets, and transition ids use the normal microstep algorithm. | `statechart_configuration_test.zig` |
| 3 | SCXML-derived fixtures cover external self re-entry, internal descendant transitions, parallel conflict order, descendant entry, and completion re-entry. | `statechart_scxml_conformance_test.zig` |
| 4 | Completion duplicate and nested FIFO ordering policy is implemented and documented. | configuration tests and `statecharts-production.md` |
| 5 | Context value semantics are recursively enforced for structs, arrays, optionals, and tagged unions; aliases/resources are rejected. | `definition.isValueContext`, definition tests |
| 6 | Native action purity is an explicit trusted-code boundary with a replay determinism audit that detects mutable-global output divergence. | `determinism.zig`, `statechart_determinism_test.zig` |
| 7 | Durable flat and hierarchical snapshots include active configurations and history. | `DurableConfigurationStatechart`, workflow statechart tests |
| 8 | Typed command adapters map into workflow activities, timers, signals, queues, and idempotent parent-linked child workflows, then feed typed outcomes back. | workflow statechart and workflow engine tests |
| 9 | Checkpoint/compaction, explicit migration, future-version failure, deduplication, command-receipt recovery, and crash windows are tested. | `workflow_statechart_test.zig` |
| 10 | Catalog writes use atomic temp/current/backup rotation with backup recovery. | `zigeffect-std/src/statechart/root.zig` tests |
| 11 | State invocation metadata emits start/stop commands at entry/exit lifecycle boundaries. | configuration and actor tests |
| 12 | Command completion/failure receipts automatically produce typed machine events, including crash recovery between receipt and event commit. | workflow statechart tests |
| 13 | Stop/restart/resume/escalate supervision and durable actor-tree checkpoint/restore are implemented. | `statechart_actor_system_test.zig` |
| 14 | Actor ownership, cluster transport/routing, lease storage, stale-owner fencing, shard recovery primitives, and journal fence integration are exercised end to end at their adapter boundaries. | cluster suite, actor-system fence test, workflow fenced-journal test |
| 15 | Actor mutation is executor/thread confined and schedule exploration is part of generated acceptance scaffolds. | actor foreign-thread test, scaffold tests |
| 16 | Supported native path fixtures run against XState v5's actor transition algorithm. | `xstateOracle.test.ts` |
| 17 | The workbench constructs an independent executable XState machine and reports first divergence/equivalence. | `xstateOracle.ts`, workbench browser evidence |
| 18 | Definition diff, guard rejection, command failure, replay, and exact source-reference inspection are available. | `statechartModel.test.ts`, `DagPanel.tsx` |
| 19 | Renderer metadata now truthfully identifies the native deterministic SVG renderer. | statechart model/UI tests |
| 20 | Explicit definition and instance selectors drive all statechart and actor surfaces. | `App.tsx`, `DagPanel.tsx`, browser verification |
| 21 | All public v2 u64 identities are decimal strings; legacy numbers beyond JavaScript's safe range fail closed. | Zig artifact and TypeScript parser tests |
| 22 | Schema identifiers, legacy readers, explicit durable migration, future failure, and a compatibility matrix are published. | artifact/std/workflow tests, production guide |
| 23 | Redaction, hostile metadata, output limits, allocation failure, malformed replay, and bounded property tests are present. | artifact/causal/workbench tests |
| 24 | Transition, actor, durable replay, and graph-model regression budgets are executable. | `statechart_performance_test.zig`, workbench graph-size test |
| 25 | Debug, ReleaseSafe, public API, hygiene, std, CLI, scaffold, package release, workbench test/typecheck/build, root test/typecheck, and Zig workspace gates were executed after implementation. | verification record below |

## Product boundary decision

Every workflow is an independently addressable actor with a stable instance
identity, journal, causal correlation, and visualization. It is not an
independent network service by default. Promote an actor to a service boundary
only for independent deployment, scaling, security ownership, fault isolation,
or data residency. Artifact and trace contracts remain identical across that
boundary.

## Verification record

Passing commands on 2026-07-10:

- `packages/zigeffect: zig build test-raw` (936/936)
- `packages/zigeffect: zig build test-raw -Doptimize=ReleaseSafe` (936/936)
- `packages/zigeffect: zig build public-api-review` (8/8)
- `packages/zigeffect: ./tools/check_tool_hygiene.sh`
- `packages/zigeffect: zig build release-gate`
- `packages/zigeffect-std: zig build test`
- `packages/zigeffect-cli: zig build test && zig build integration-test`
- `bun run zigeffect:workbench:test`
- `bun run zigeffect:workbench:typecheck`
- `bun run zigeffect:workbench:build`
- `bun run typecheck`
- `bun run test`
- `bun run zig:test`
- `git diff --check`

The in-app browser also verified a production Vite build/dev surface with
definition and instance selectors, XState equivalence, replay position, and an
exact source reference for the selected transition.

`bun run zigeffect:local-release` passed its statechart-owning std and CLI unit
layers during the final audit. Its last repository-wide attempt stopped when a
concurrently added, unrelated `zigeffect-std/src/testing/schedules.zig` module
contained tests for a not-yet-present `explore` implementation. That incomplete
testing-v2 work is outside this statechart roadmap. The repository-wide script
must be rerun after that separate module lands before a release tag; this does
not weaken the completed subsystem gates above.

## Release claims

Allowed: production statecharts for the documented ZigEffect semantics,
production-oriented durable agent workflows, and XState-conformant projection
for the supported feature matrix.

Disallowed: fully SCXML-conformant, arbitrary-effect exactly-once, or universal
storage/transport correctness without running the chosen adapter conformance
suite.
