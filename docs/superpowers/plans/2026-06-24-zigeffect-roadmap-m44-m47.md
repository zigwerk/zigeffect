# zigeffect Roadmap M44-M47 Plan

Date: 2026-06-24

## Implementation Checklist

- [x] M44: add daemon lifecycle event tests.
- [x] M44: implement `onLifecycle` events in `runLiveCommandDaemon`.
- [x] M45: add in-memory discovery registry tests.
- [x] M45: implement owned endpoint registry and selection.
- [x] M46: add linked eval manifest tests.
- [x] M46: implement manifest formatter and schema governance entry.
- [x] M47: add ops HTTP response header tests.
- [x] M47: attach fixed response headers to ops artifact responses.
- [x] Update roadmap and future-agent briefing.
- [x] Run focused formatter/tests.
- [x] Run release verification gates.
- [x] Commit M44-M47.

## Verification Log

- RED: `bun test packages/zigeffect/workbench/src/liveAttach.test.ts` failed before implementation because no lifecycle events were emitted.
- RED: `cd packages/zigeffect && zig build test-raw` failed before implementation because the linked eval manifest formatter, ops artifact header type, and in-memory service discovery registry did not exist.
- GREEN focused: `bun test packages/zigeffect/workbench/src/liveAttach.test.ts` passed with 19 tests.
- GREEN focused: `cd packages/zigeffect && zig build test-raw` passed after adding the flat linked-manifest artifact paths expected by the new regression.
- Workbench: `bun run zigeffect:workbench:test` passed with 78 tests.
- Workbench: `bun run zigeffect:workbench:typecheck` exited 0.
- Workbench: `bun run zigeffect:workbench:build` exited 0.
- ZIO adapter: `cd packages/zigeffect-zio && zig build test` exited 0.
- Hygiene: `packages/zigeffect/tools/check_tool_hygiene.sh` passed with 46 tool files.
- Whitespace: `git diff --check` exited 0.
- Package gates: `bun run zigeffect:test` exited 0.
- Release gate: `bun run zigeffect:release` exited 0 and wrote `.zig-cache/release-gate/zigeffect-release-gate.{txt,json}`.
