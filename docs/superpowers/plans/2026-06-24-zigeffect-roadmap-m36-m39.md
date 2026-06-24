# zigeffect Roadmap M36-M39 Plan

Date: 2026-06-24

## Implementation Checklist

- [x] M36: add local command polling loop tests.
- [x] M36: implement `runLiveCommandPollingLoop`.
- [x] M37: add eval diff artifact link tests.
- [x] M37: implement artifact link JSON and schema governance entry.
- [x] M38: add service discovery endpoint validation tests.
- [x] M38: implement transport discovery validation.
- [x] M39: add HTTP-shaped ops artifact response tests.
- [x] M39: implement status/body wrapper.
- [x] Update roadmap and future-agent briefing.
- [x] Run focused formatter/tests.
- [x] Run release verification gates.
- [x] Commit M36-M39.

## Verification Log

- `zig fmt ...` completed with no output.
- `bun test packages/zigeffect/workbench/src/liveAttach.test.ts`: 17 pass, 0 fail.
- `cd packages/zigeffect && zig build test-raw`: exit 0.
- `bun run zigeffect:workbench:test`: 76 pass, 0 fail.
- `bun run zigeffect:workbench:typecheck`: exit 0.
- `bun run zigeffect:workbench:build`: built successfully.
- `cd packages/zigeffect-zio && zig build test`: exit 0.
- `packages/zigeffect/tools/check_tool_hygiene.sh`: passed, 46 tool files.
- `git diff --check`: exit 0.
- `bun run zigeffect:test`: exit 0.
- `bun run zigeffect:release`: exit 0; release gate reports written.
