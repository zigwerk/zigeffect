# zigeffect Local Agent Session Registry Implementation Plan

## Goal

Add durable, bounded local session ownership beneath the agent process
supervisor.

## Scope

- Add the deterministic registry model and versioned snapshot validation.
- Add fakeable text storage plus an atomic Bun file store.
- Integrate registry lifecycle updates into every process-supervisor path.
- Kill and settle a started child when initial collector delivery fails.
- Update local-first roadmap and operator docs with M84.

## Steps

- [x] Add failing registry lifecycle, redaction, recovery, capacity, persistence,
  and supervisor cleanup tests.
- [x] Implement the bounded registry and snapshot restore.
- [x] Implement storage helpers and atomic Bun file storage.
- [x] Integrate registry ownership and cleanup into the process supervisor.
- [x] Update roadmap/docs.
- [x] Run focused tests, workbench tests, typecheck, diff hygiene, and the local
  agent gate.
- [x] Commit M84 without unrelated workspace files.

## Verification

- `bun test --timeout 30000 packages/zigeffect/workbench/src/collector/localAgentSessionRegistry.test.ts packages/zigeffect/workbench/src/collector/localAgentProcessSupervisor.test.ts`
- `bun run zigeffect:workbench:test`
- `bun run zigeffect:workbench:typecheck`
- `git diff --check`
- `bun run zigeffect:local-agent-gate`

## Evidence

- Red: the focused suite failed because `./localAgentSessionRegistry` did not
  exist. Follow-up red tests caught missing retained-text bounds and missing
  supervisor write-through persistence.
- Green: focused registry/supervisor coverage passed with 15 tests and 89
  assertions.
- `bun run zigeffect:workbench:test` passed with 210 tests and 946 assertions.
- `bun run zigeffect:workbench:typecheck` passed.
- `git diff --check` passed.
- `bun run zigeffect:local-agent-gate` passed, including the production
  workbench build, 210 workbench tests, 193 Zig tests, std tests/examples, and
  tool hygiene.
