# zigeffect Local Agent Control API Implementation Plan

## Goal

Add an authenticated, allowlist-only local HTTP control surface over the durable
agent session supervisor.

## Scope

- Add the tool catalog and control receipt contracts.
- Add authenticated standard `fetch(Request)` routing with local CORS.
- Own active abort controllers and background supervisor promises.
- Serve tools, sessions, session detail, health, stop, and receipts.
- Integrate the existing registry, optional store, runner, and event endpoint.

## Steps

- [x] Add failing auth, CORS, metadata, start, stop, conflict, body-limit, and
  receipt tests.
- [x] Implement tool catalog validation and bounded receipt storage.
- [x] Implement HTTP routes and process ownership.
- [x] Update roadmap and local operator docs.
- [x] Run focused tests, workbench tests, typecheck, diff hygiene, and the local
  agent gate.
- [x] Commit M85 without unrelated workspace files.

## Verification

- `bun test --timeout 30000 packages/zigeffect/workbench/src/collector/localAgentControlServer.test.ts packages/zigeffect/workbench/src/collector/localAgentSessionRegistry.test.ts`
- `bun run zigeffect:workbench:test`
- `bun run zigeffect:workbench:typecheck`
- `git diff --check`
- `bun run zigeffect:local-agent-gate`

## Evidence

- Focused control/registry suite: 16 tests passed with 84 assertions.
- Workbench suite: 217 tests passed with 990 assertions.
- Strict workbench TypeScript check passed.
- Workbench production build passed.
- zigeffect-std tests and examples passed.
- Core zigeffect gate: 193 tests passed across 67 build steps.
- Tool hygiene passed with 46 tool files.
- `git diff --check` passed.
