# zigeffect Roadmap M24-M27 Plan

Date: 2026-06-24

## Implementation Checklist

- [x] M24: add collector command inbox tests.
- [x] M24: implement `commandsSince` and `GET /commands`.
- [x] M25: add eval diff artifact tests.
- [x] M25: implement `runAgentEvalWithDiffArtifact`.
- [x] M26: add ops artifact response tests.
- [x] M26: implement access-controlled redacted artifact JSON.
- [x] M27: add runner lineage artifact tests.
- [x] M27: implement deployment metadata lineage JSON.
- [x] Update roadmap and future-agent briefing.
- [x] Run focused formatter/tests.
- [x] Run release verification gates.
- [x] Commit M24-M27.

## Verification Log

- `zig fmt packages/zigeffect/src/services/agent_eval.zig packages/zigeffect/src/services/causal_ops_storage.zig packages/zigeffect/src/services/causal_runner_lineage.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/agent_eval_test.zig packages/zigeffect/test/causal_ops_storage_test.zig packages/zigeffect/test/causal_runner_lineage_test.zig` — pass.
- `bun test packages/zigeffect/workbench/src/collector/collector.test.ts` — 7 pass.
- `cd packages/zigeffect && zig build test-raw` — pass.
- `bun run zigeffect:workbench:test` — 73 pass.
- `cd packages/zigeffect-zio && zig build test` — pass.
- `packages/zigeffect/tools/check_tool_hygiene.sh` — pass.
- `bun run zigeffect:workbench:typecheck` — pass.
- `bun run zigeffect:workbench:build` — pass.
- `git diff --check` — pass.
- `bun run zigeffect:test` — pass.
- `bun run zigeffect:release` — pass.
