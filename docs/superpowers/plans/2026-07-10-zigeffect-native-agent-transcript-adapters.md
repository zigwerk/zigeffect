# zigeffect Native Agent Transcript Adapters Implementation Plan

## Goal

Close the remaining local-first adapter gap with tested Codex and Claude Code
public-stream normalization.

## Scope

- Add representative offline JSONL fixtures for both CLIs.
- Add defensive provider adapter parsers with bounded snippets.
- Add safe Codex and Claude process-tool builders.
- Wire optional adapters through transcript tail and process supervision.
- Update the local-first roadmap and usage docs.

## Steps

- [x] Add failing fixture, parser, command-builder, and supervisor-wiring tests.
- [x] Implement Codex and Claude Code adapters.
- [x] Wire adapters through transcript tail and process supervision.
- [x] Update roadmap/docs and fixture provenance.
- [x] Run focused tests, workbench tests, typecheck, diff hygiene, and the local
  agent gate.
- [x] Commit M83 without unrelated workspace files.

## Verification

- `bun test --timeout 30000 packages/zigeffect/workbench/src/collector/localAgentTranscriptAdapters.test.ts packages/zigeffect/workbench/src/collector/localAgentProcessSupervisor.test.ts`
- `bun run zigeffect:workbench:test`
- `bun run zigeffect:workbench:typecheck`
- `git diff --check`
- `bun run zigeffect:local-agent-gate`

## Evidence

- Red: focused tests failed because `./localAgentTranscriptAdapters` did not
  exist. Follow-up red tests caught quoted JSON secret leakage, dropped parallel
  Claude tool uses, unsupported Codex collaboration items, and declined-command
  status.
- Green: focused adapter/tail/supervisor/redaction coverage passed with 26 tests
  and 136 assertions.
- `bun run zigeffect:workbench:test` passed with 201 tests and 906 assertions.
- `bun run zigeffect:workbench:typecheck` passed.
- `git diff --check` passed.
- `bun run zigeffect:local-agent-gate` passed, including the production
  workbench build, 201 workbench tests, 193 Zig tests, std tests/examples,
  redaction checks, and tool hygiene.
