# zigeffect Roadmap M32-M35 Plan

Date: 2026-06-24

## Implementation Checklist

- [x] M32: add command poll loop tests.
- [x] M32: implement bounded callback-based poll loop.
- [x] M33: add eval diff artifact writer tests.
- [x] M33: implement eval diff artifact sink runner.
- [x] M34: add runner deployment validation tests.
- [x] M34: implement metadata validation report.
- [x] M35: add alert delivery sink tests.
- [x] M35: implement `deliverCausalOpsAlert`.
- [x] Update roadmap and future-agent briefing.
- [x] Run focused formatter/tests.
- [x] Run release verification gates.
- [x] Commit M32-M35.

## Verification Log

- `zig fmt packages/zigeffect/src/services/causal_live_command.zig packages/zigeffect/src/services/agent_eval.zig packages/zigeffect/src/services/causal_runner_lineage.zig packages/zigeffect/src/services/causal_ops_alert.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/causal_live_command_test.zig packages/zigeffect/test/agent_eval_test.zig packages/zigeffect/test/causal_runner_lineage_test.zig packages/zigeffect/test/causal_ops_alert_test.zig` — pass.
- `cd packages/zigeffect && zig build test-raw` — pass.
- `bun run zigeffect:workbench:test` — 75 pass.
- `cd packages/zigeffect-zio && zig build test` — pass.
- `packages/zigeffect/tools/check_tool_hygiene.sh` — pass.
- `bun run zigeffect:workbench:typecheck` — pass.
- `bun run zigeffect:workbench:build` — pass.
- `git diff --check` — pass.
- `bun run zigeffect:test` — pass.
- `bun run zigeffect:release` — pass.
