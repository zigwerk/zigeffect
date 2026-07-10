# zigeffect Agentic Application Platform Implementation Plan

## Goal

Deliver M88-M95 from the agentic application platform design as a local-first,
agent-first Zig development system.

## Milestone Sequence

### M88 - Project Contract And Skills

- [x] Add failing `zstd.Project` tests for valid manifests, component graphs,
  name/path validation, requirement and acceptance records, schema versions,
  JSON round trips, redaction, and deterministic file plans.
- [x] Implement `packages/zigeffect-std/src/project/root.zig` and export
  `zstd.Project`.
- [x] Add generated-file plan ownership, deinit, path safety, collision checks,
  and scaffold receipts.
- [x] Commit Codex and Claude zigeffect development skills and document their
  project-local installation contract.
- [x] Update stdlib docs, active roadmap, parity docs, and honesty checks.
- [x] Run stdlib tests/examples and the full local-agent gate.
- [x] Commit M88.

### M89 - Scaffold CLI

- [x] Scaffold `packages/zigeffect-cli` with `zigeffect` executable, library,
  tests, build/install steps, and root Bun commands.
- [x] Add failing parser tests for help/version and
  `new application|service|library|package|system`.
- [x] Add failing generator snapshots for every scaffold kind.
- [x] Implement deterministic templates with effects, layers, Schema, CLI,
  HTTP, SQL, config, tests, causal instrumentation, skills, and manifest.
- [x] Implement safe local writer, dry-run, JSON, conflict, force, and local
  dependency path behavior.
- [x] Add real temp-directory integration tests that run `zig build test` for
  every generated kind.
- [x] Add CLI tests to the local-agent gate and document copyable commands.
- [x] Commit M89.

### M90 - Project Manager

- [x] Add manifest-owned component mutation and graph validation tests.
- [x] Implement `add service|library|package` with atomic manifest updates.
- [x] Implement `generate service|layer|schema|cli|http|sql|test` within a
  selected component.
- [x] Implement `project show|validate|doctor|check|test|dev` with fixed command
  IDs, redacted receipts, cancellation, and no arbitrary argv.
- [x] Generate local agent/workbench launch metadata and dev-session receipts.
- [x] Prove add/generate/check against a real generated system workspace.
- [x] Commit M90.

### M91 - Agent Development Protocol

- [x] Define requirement, task, acceptance, evidence, and handoff schemas.
- [x] Add CLI JSON/JSONL queries for project status, unresolved requirements,
  failed checks, causal evidence, and next actions.
- [x] Integrate provider-neutral session receipts and bounded artifact links.
- [x] Add compatibility, malformed-input, redaction, and replay tests.
- [x] Update both skills to make the protocol the default agent workflow.
- [x] Commit M91.

### M92 - Causal Application SDK

- [x] Design semantic application fact kinds without expanding core taxonomy
  unnecessarily.
- [x] Implement stdlib helpers for config, schema, CLI, HTTP, SQL, external
  calls, artifacts, component dependencies, and acceptance checks.
- [x] Use helpers in generated application/service templates.
- [x] Add deterministic causal traces and structural-equivalence tests across
  supported executors where applicable.
- [x] Commit M92.

### M93 - Workbench Application UX

- [x] Extend the workbench model with project/component/requirement/task/check/
  artifact/application-fact contracts.
- [x] Add component dependency view, requirement and acceptance panels, command
  and artifact inspection, session comparison, graph focus, and recovery state.
- [x] Stream protocol updates through the existing collector boundary.
- [x] Add focused model/controller/UI tests and responsive styles.
- [x] Run a real generated-project browser proof on desktop and mobile.
- [x] Commit M93.

### M94 - Provider Conformance

- [x] Define provider-neutral benchmark scenarios and score schema.
- [x] Add deterministic Codex and Claude fixtures for success, repair, failure,
  cancellation, approval, large output, and recovery.
- [x] Implement offline scorer and comparable receipts.
- [x] Add opt-in real local provider runner with explicit availability checks;
  keep CI network-free.
- [x] Publish benchmark interpretation and non-claims.
- [x] Commit M94.

### M95 - Distribution And Release

- [x] Add install/version/completions and compatibility metadata.
- [x] Add scaffold schema migrations and upgrade dry-runs with conflict-safe
  behavior.
- [x] Add generated snapshot compatibility and public API stability gates.
- [x] Build one local release command covering core/std/CLI/Postgres/workbench,
  generated projects, docs honesty, redaction, and hygiene.
- [x] Reconcile every roadmap/parity/cookbook status claim.
- [x] Run the complete release gate and commit M95.

## Completion Evidence

Populate after each milestone with commit, tests, generated-project builds, and
browser/provider receipts. The goal is complete only when every checkbox above
is delivered or explicitly proven impossible by an external constraint.

### M88 Evidence

- `zstd.Project`: 6 focused contract tests within a 26-test stdlib artifact.
- Skills: Codex and Claude frontmatter/YAML parse checks passed. The optional
  upstream Python validator could not start because its environment lacks
  `PyYAML`; no validator pass is claimed.
- Local-agent gate: 256 workbench tests, production workbench build, stdlib
  tests/examples, 193 core tests across 67 build steps, raw core tests, tool
  hygiene, and `git diff --check` passed on 2026-07-10.

### M89 Evidence

- CLI: 9 parser/planner/writer/execution tests passed; the executable and Bun
  entry point reported version `0.1.0`.
- Generated-project integration: all five kinds passed Debug and ReleaseSafe;
  the system's API, worker, and shared package also passed independently.
- Expanded local-agent gate: 256 workbench tests and production build, stdlib
  tests/examples, 193 configured core tests across 67 steps, 850 raw core
  tests, tool hygiene, and `git diff --check` passed on 2026-07-10.

### M90 Evidence

- CLI: 10 parser/planner/writer/manager tests passed.
- Real system: added and independently built `analytics`, generated an API
  schema, validated the updated graph, passed aggregate Debug/ReleaseSafe,
  passed every original child plus the new child, ran manifest-owned `check`,
  and verified `.zigeffect/receipts/check.json`.

### M91 Evidence

- Protocol: provider-neutral status/handoff round trips, unknown-version,
  malformed-input, duplicate-id, bound, and sentinel-secret tests passed.
- CLI: 14 tests passed; generated-system integration persisted and parsed a
  Codex handoff after a real manifest-owned project check.

### M92 Evidence

- Application SDK: 49 stdlib tests passed, including all nine semantic fact
  kinds, stable core-taxonomy mapping, causal and JSON redaction, bounded
  validation, every receipt allocation failure, and changed-reference/lineage
  structural regressions.
- Scaffolds: 14 CLI tests proved application and service plans contain all nine
  helpers; the real generated-project integration passed every kind in Debug
  and ReleaseSafe with deterministic allocation-failure and schedule tests.

### M93 Evidence

- Workbench: typecheck, 269 focused and regression tests, and the production
  Vite build passed. The collector test uses a real WebSocket client and rejects
  malformed project versions before broadcast.
- Browser: the project-development sample rendered the generated system graph,
  requirements, checks, sessions, approvals, artifacts, and all nine semantic
  fact kinds at 1440x1000 and 390x844. Selecting `api-service` narrowed three
  requirements to one and nine facts to seven; selecting Schema event 3 opened
  its cause path and `InvoiceResponse.v1` reference in the shared Inspector.

### M94 Evidence

- Conformance: the checked-in provider-neutral matrix parsed and scored 14/14
  passing cases, covering the same seven lifecycle scenarios for Codex and
  Claude Code with `complete_provider_matrix: true`.
- Safety/CLI: 56 stdlib tests and 19 CLI tests passed, including allocation
  failure, secret rejection, sequence/version/duplicate rejection, incomplete
  matrix gate failure, opt-in enforcement, provider/command matching, bounded
  output, unavailable executable behavior, and persisted real-run receipts.
- Claims: benchmark docs distinguish deterministic offline protocol evidence
  from controlled repeated real-provider studies; CI performs no provider or
  network invocation.

### M95 Evidence

- Distribution: a stage-installed `zigeffect 0.2.0` binary emitted non-empty
  Bash, Zsh, and Fish completions and a machine-readable Zig/project/template/
  core/stdlib compatibility report.
- Upgrades: tests prove pristine-state adoption, v0-to-v1 manifest migration,
  preservation of user-owned application source, SHA-256 managed-file checks,
  and exit-code-3 whole-apply refusal for an edited agent skill.
- Compatibility: 24 CLI tests pin all five scaffold kinds to the committed
  versioned snapshot; the generated-project integration compiled every kind in
  Debug and ReleaseSafe, compiled system children independently, and passed
  compatibility plus no-op upgrade checks.
- Final release: `bun run zigeffect:local-release` passed with the stage-installed
  CLI, 56/56 stdlib tests and all examples, 24/24 CLI tests, the full generated
  project matrix, 14/14 provider cases, 855/855 core tests in both Debug and
  ReleaseSafe, 7/7 public API tests, the 241-step core release gate with 461/461
  tests, Postgres/QUIC/zio gates, 269/269 Workbench tests plus typecheck/build,
  docs honesty, redaction coverage, and tool hygiene on Zig 0.16.0.
