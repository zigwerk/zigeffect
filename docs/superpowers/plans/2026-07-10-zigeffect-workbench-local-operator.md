# zigeffect Workbench Local Operator Implementation Plan

## Goal

Deliver M86 as a tested local-only SolidJS control surface over M85.

## Steps

- [x] Add failing server-contract tests for prompt metadata and persistence
  health, then implement the bounded additions.
- [x] Add failing typed-client tests for loopback validation, route parsing,
  response bounds, auth, errors, and ephemeral token bootstrap.
- [x] Implement the validated local control client.
- [x] Add failing operator-controller tests for refresh, detail, polling,
  actions, stale work, authorization failure, and cleanup.
- [x] Implement the single-flight Solid operator controller.
- [x] Add failing composition tests, then implement the supported loopback Bun
  host with built-in Codex/Claude tools and durable recovery.
- [x] Add failing UI wiring assertions, then build the operator panel and
  integrate it above the collaboration artifact view.
- [x] Add responsive styling and Lucide control icons.
- [x] Update roadmap and local operator documentation.
- [x] Run focused tests, the workbench suite, strict typecheck, production
  build, browser desktop/mobile verification, diff hygiene, and the full local
  agent gate.
- [x] Commit M86 without unrelated workspace files.

## Verification

- `bun test --timeout 30000 packages/zigeffect/workbench/src/collector/localAgentControlServer.test.ts packages/zigeffect/workbench/src/collector/localAgentControlHost.test.ts packages/zigeffect/workbench/src/localAgentControlClient.test.ts packages/zigeffect/workbench/src/collab/localAgentOperator.test.ts packages/zigeffect/workbench/src/collab/localAgentOperatorUi.test.tsx`
- `bun run zigeffect:workbench:test`
- `bun run zigeffect:workbench:typecheck`
- `bun run zigeffect:workbench:build`
- Browser screenshots at desktop and mobile widths.
- `git diff --check`
- `bun run zigeffect:local-agent-gate`

## Evidence

- Focused M86 server/host/client/controller/UI suite: 26 tests passed with 164
  assertions.
- Workbench suite: 236 tests passed with 1,111 assertions.
- Strict workbench TypeScript check and production code-split build passed.
- Real loopback browser proof launched an inert allowlisted process, observed
  durable running history/detail and an accepted start receipt, stopped it once,
  and observed interrupted exit `143`, three posted events, and an accepted stop
  receipt.
- Desktop `1440x1000` and mobile `390x844` screenshots had no horizontal
  overflow or out-of-bounds controls; browser console had no warnings/errors.
- zigeffect-std tests and examples passed.
- Core zigeffect gate: 193 tests passed across 67 build steps.
- Tool hygiene passed with 46 tool files.
- `git diff --check` passed.
