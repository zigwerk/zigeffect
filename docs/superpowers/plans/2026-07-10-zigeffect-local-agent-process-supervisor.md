# zigeffect Local Agent Process Supervisor Implementation Plan

## Goal

Connect the local transcript tail to a runner-owned Bun process lifecycle so a
real local agent command can appear live in the workbench from start through
exit.

## Scope

- Add a fakeable process-handle and process-runner contract.
- Add a Bun-backed process runner with owned stdout/stderr pipes.
- Tail stdout, drain bounded stderr, and emit lifecycle/check events.
- Support abort-driven child termination.
- Update the local-first roadmap with M82.

## Steps

- [x] Add failing success, failure, spawn-error, abort, redaction, and Bun smoke
  tests.
- [x] Implement the process supervisor and Bun adapter.
- [x] Update roadmap/docs.
- [x] Run focused tests, workbench tests, typecheck, diff hygiene, and the local
  agent gate.
- [x] Commit the completed milestone without unrelated workspace files.

## Verification

- `bun test --timeout 30000 packages/zigeffect/workbench/src/collector/localAgentProcessSupervisor.test.ts`
- `bun run zigeffect:workbench:test`
- `bun run zigeffect:workbench:typecheck`
- `git diff --check`
- `bun run zigeffect:local-agent-gate`

## Evidence

- Red: the focused Bun test failed because
  `./localAgentProcessSupervisor` did not exist.
- Green: the focused supervisor suite passed with 6 tests and 49 assertions.
- `bun run zigeffect:workbench:test` passed with 190 tests and 855 assertions.
- `bun run zigeffect:workbench:typecheck` passed.
- `git diff --check` passed.
- `bun run zigeffect:local-agent-gate` passed, including the production
  workbench build, 190 workbench tests, 193 Zig tests, std tests/examples,
  redaction checks, and tool hygiene.
