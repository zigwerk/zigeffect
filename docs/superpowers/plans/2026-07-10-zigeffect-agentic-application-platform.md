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

- [ ] Scaffold `packages/zigeffect-cli` with `zigeffect` executable, library,
  tests, build/install steps, and root Bun commands.
- [ ] Add failing parser tests for help/version and
  `new application|service|library|package|system`.
- [ ] Add failing generator snapshots for every scaffold kind.
- [ ] Implement deterministic templates with effects, layers, Schema, CLI,
  HTTP, SQL, config, tests, causal instrumentation, skills, and manifest.
- [ ] Implement safe local writer, dry-run, JSON, conflict, force, and local
  dependency path behavior.
- [ ] Add real temp-directory integration tests that run `zig build test` for
  every generated kind.
- [ ] Add CLI tests to the local-agent gate and document copyable commands.
- [ ] Commit M89.

### M90 - Project Manager

- [ ] Add manifest-owned component mutation and graph validation tests.
- [ ] Implement `add service|library|package` with atomic manifest updates.
- [ ] Implement `generate service|layer|schema|cli|http|sql|test` within a
  selected component.
- [ ] Implement `project show|validate|doctor|check|test|dev` with fixed command
  IDs, redacted receipts, cancellation, and no arbitrary argv.
- [ ] Generate local agent/workbench launch metadata and dev-session receipts.
- [ ] Prove add/generate/check against a real generated system workspace.
- [ ] Commit M90.

### M91 - Agent Development Protocol

- [ ] Define requirement, task, acceptance, evidence, and handoff schemas.
- [ ] Add CLI JSON/JSONL queries for project status, unresolved requirements,
  failed checks, causal evidence, and next actions.
- [ ] Integrate provider-neutral session receipts and bounded artifact links.
- [ ] Add compatibility, malformed-input, redaction, and replay tests.
- [ ] Update both skills to make the protocol the default agent workflow.
- [ ] Commit M91.

### M92 - Causal Application SDK

- [ ] Design semantic application fact kinds without expanding core taxonomy
  unnecessarily.
- [ ] Implement stdlib helpers for config, schema, CLI, HTTP, SQL, external
  calls, artifacts, component dependencies, and acceptance checks.
- [ ] Use helpers in generated application/service templates.
- [ ] Add deterministic causal traces and structural-equivalence tests across
  supported executors where applicable.
- [ ] Commit M92.

### M93 - Workbench Application UX

- [ ] Extend the workbench model with project/component/requirement/task/check/
  artifact/application-fact contracts.
- [ ] Add component dependency view, requirement and acceptance panels, command
  and artifact inspection, session comparison, graph focus, and recovery state.
- [ ] Stream protocol updates through the existing collector boundary.
- [ ] Add focused model/controller/UI tests and responsive styles.
- [ ] Run a real generated-project browser proof on desktop and mobile.
- [ ] Commit M93.

### M94 - Provider Conformance

- [ ] Define provider-neutral benchmark scenarios and score schema.
- [ ] Add deterministic Codex and Claude fixtures for success, repair, failure,
  cancellation, approval, large output, and recovery.
- [ ] Implement offline scorer and comparable receipts.
- [ ] Add opt-in real local provider runner with explicit availability checks;
  keep CI network-free.
- [ ] Publish benchmark interpretation and non-claims.
- [ ] Commit M94.

### M95 - Distribution And Release

- [ ] Add install/version/completions and compatibility metadata.
- [ ] Add scaffold schema migrations and upgrade dry-runs with conflict-safe
  behavior.
- [ ] Add generated snapshot compatibility and public API stability gates.
- [ ] Build one local release command covering core/std/CLI/Postgres/workbench,
  generated projects, docs honesty, redaction, and hygiene.
- [ ] Reconcile every roadmap/parity/cookbook status claim.
- [ ] Run the complete release gate and commit M95.

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
