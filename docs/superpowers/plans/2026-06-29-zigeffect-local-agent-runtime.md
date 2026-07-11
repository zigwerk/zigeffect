# zigeffect Local Agent Runtime Implementation Plan

## Goal

Add a local Bun runtime that can supervise Codex, Claude Code, zigeffect, and
other local commands, then stream sanitized workbench-compatible agent events
into the collector.

## Scope

- Add a fakeable local agent runtime module under the workbench collector.
- Add tests for event ordering, redaction, failures, fail-fast behavior, and the
  Bun-backed process runner.
- Update the roadmap to reflect that live local process execution now has a
  first implementation.

## Steps

- [x] Add failing tests for the runtime contract.
- [x] Implement the runtime with sanitized `POST /agent-events` emission.
- [x] Implement the Bun process runner.
- [x] Update roadmap/docs.
- [x] Run workbench tests, typecheck, diff hygiene, and local agent gate.
- [x] Commit the completed milestone.

## Verification

- `bun run zigeffect:workbench:test`
- `bun run zigeffect:workbench:typecheck`
- `git diff --check`
- `bun run zigeffect:local-agent-gate`

## Evidence

- Red: `bun run zigeffect:workbench:test` failed because
  `./localAgentRuntime` did not exist.
- Green: `bun run zigeffect:workbench:test` passed with 112 tests after the
  runtime implementation.
- `bun run zigeffect:workbench:typecheck` passed.
- `git diff --check` passed.
- `bun run zigeffect:local-agent-gate` passed, including the workbench build,
  112 workbench tests, 189 Zig tests, std tests/examples, and tool hygiene.
