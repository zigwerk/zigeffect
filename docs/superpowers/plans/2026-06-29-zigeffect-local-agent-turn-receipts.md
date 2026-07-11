# zigeffect Local Agent Turn Receipts Implementation Plan

## Goal

Add turn-level local agent receipts to the workbench model and live session feed.

## Scope

- Add `LocalDevTurnModel` and `turns` to local dev-session models.
- Parse static `turns` from local dev-session artifacts.
- Parse/apply live `agent_turn` events.
- Show turn rows in the Dev Session timeline and expose a turn count metric.
- Update roadmap/docs with M80.

## Steps

- [x] Add failing tests for static turns and live `agent_turn` events.
- [x] Implement turn types, static parsing, and health/timeline projection.
- [x] Implement live event parsing/apply/upsert behavior.
- [x] Add the Dev Session turn metric.
- [x] Update roadmap/docs.
- [x] Run workbench tests, typecheck, diff hygiene, and local agent gate.
- [x] Commit the completed milestone.

## Verification

- `bun run zigeffect:workbench:test`
- `bun run zigeffect:workbench:typecheck`
- `git diff --check`
- `bun run zigeffect:local-agent-gate`

## Evidence

- Red: `bun run zigeffect:workbench:test` failed on missing turn metric,
  missing `session.turns`, and unsupported live `agent_turn` events.
- Green: `bun run zigeffect:workbench:test` passed with 118 tests after turn
  receipts were implemented.
- `bun run zigeffect:workbench:typecheck` passed.
- `git diff --check` passed.
- `bun run zigeffect:local-agent-gate` passed, including the workbench build,
  118 workbench tests, 189 Zig tests, std tests/examples, and tool hygiene.
