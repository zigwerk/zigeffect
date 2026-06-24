# zigeffect Roadmap M40-M43 Plan

Date: 2026-06-24

## Implementation Checklist

- [x] M40: add local command daemon harness tests.
- [x] M40: implement `runLiveCommandDaemon`.
- [x] M41: add linked eval diff artifact writer tests.
- [x] M41: implement linked artifact/link sink composition.
- [x] M42: add service-discovery endpoint selection tests.
- [x] M42: implement endpoint selection report.
- [x] M43: add ops artifact HTTP request adapter tests.
- [x] M43: implement method/path-gated adapter.
- [x] Update roadmap and future-agent briefing.
- [x] Run focused formatter/tests.
- [x] Run release verification gates.
- [x] Commit M40-M43.

## Verification Log

- Red checks before implementation:
  - `bun test packages/zigeffect/workbench/src/liveAttach.test.ts` failed on
    missing `runLiveCommandDaemon`.
  - `cd packages/zigeffect && zig build test-raw` failed on missing
    `runAgentEvalAndWriteLinkedDiffArtifact`,
    `selectClusterTransportServiceDiscoveryEndpoint`, and
    `serveCausalOpsArtifactHttpRequest`.
- `zig fmt ...` completed with no output.
- `bun test packages/zigeffect/workbench/src/liveAttach.test.ts`: 18 pass, 0 fail.
- `cd packages/zigeffect && zig build test-raw`: exit 0.
- `bun run zigeffect:workbench:test`: 77 pass, 0 fail.
- `bun run zigeffect:workbench:typecheck`: exit 0.
- `bun run zigeffect:workbench:build`: built successfully.
- `cd packages/zigeffect-zio && zig build test`: exit 0.
- `packages/zigeffect/tools/check_tool_hygiene.sh`: passed, 46 tool files.
- `git diff --check`: exit 0.
- `bun run zigeffect:test`: exit 0.
- `bun run zigeffect:release`: exit 0; release gate reports written.
