# zigeffect Roadmap M28-M31 Plan

Date: 2026-06-24

## Implementation Checklist

- [x] M28: add command inbox client tests.
- [x] M28: implement `LiveCommandInboxResponse` validation and `fetchLiveCommands`.
- [x] M29: add core polled command batch tests.
- [x] M29: implement `runCausalLiveCommandPolledBatch`.
- [x] M30: add schema governance tests for new artifact schemas.
- [x] M30: register new artifact families.
- [x] M31: add external alert delivery envelope tests.
- [x] M31: implement redacted alert delivery JSON.
- [x] Update roadmap and future-agent briefing.
- [x] Run focused formatter/tests.
- [x] Run release verification gates.
- [x] Commit M28-M31.

## Verification Log

- `zig fmt packages/zigeffect/src/services/causal_live_command.zig packages/zigeffect/src/services/causal_ops_alert.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/causal_live_command_test.zig packages/zigeffect/test/causal_ops_alert_test.zig packages/zigeffect/tools/causal_schema_governance.zig` — pass.
- `bun test packages/zigeffect/workbench/src/liveAttach.test.ts` — 16 pass.
- `cd packages/zigeffect && zig build test-raw` — pass.
- `bun run zigeffect:workbench:test` — 75 pass.
- `cd packages/zigeffect-zio && zig build test` — pass.
- `packages/zigeffect/tools/check_tool_hygiene.sh` — pass.
- `bun run zigeffect:workbench:typecheck` — pass.
- `bun run zigeffect:workbench:build` — pass.
- `git diff --check` — pass.
- `bun run zigeffect:test` — pass.
- `bun run zigeffect:release` — pass.
