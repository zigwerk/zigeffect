# zigeffect Local Agent Transcript Tail Implementation Plan

## Goal

Add a local stream adapter that converts transcript lines from long-running
agent processes into live `agent_turn` events.

## Scope

- Add transcript line parsing for JSONL and tagged plaintext turns.
- Add a stream tailer that handles chunk boundaries and trailing partial lines.
- Post normalized events through the existing local agent event endpoint helper.
- Update roadmap/docs with M81.

## Steps

- [x] Add failing parser and stream tail tests.
- [x] Implement transcript line parsing.
- [x] Implement stream tailing and event posting.
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
  `./localAgentTranscriptTail` did not exist.
- Green: `bun run zigeffect:workbench:test` passed with 121 tests after the
  transcript tail adapter was implemented.
- `bun run zigeffect:workbench:typecheck` passed.
- `git diff --check` passed.
- `bun run zigeffect:local-agent-gate` passed, including the workbench build,
  121 workbench tests, 189 Zig tests, std tests/examples, and tool hygiene.
