# zigeffect Local Agent Artifact Capture Implementation Plan

## Goal

Add redacted stdout/stderr/error artifact capture to the local agent runtime so
the workbench can show concrete evidence for local Codex, Claude Code, and
zigeffect tool runs.

## Scope

- Extend the runtime with a fakeable artifact sink.
- Add a Bun file sink for local development.
- Emit workbench-compatible `artifact_link` events for written artifacts.
- Attach artifact paths to `check_result` events.
- Update the roadmap to add M79.

## Steps

- [x] Add failing artifact capture tests.
- [x] Export/reuse the local dev-session redaction helper.
- [x] Implement runtime artifact writing and artifact link emission.
- [x] Implement a Bun-backed artifact sink.
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
  `bunLocalAgentArtifactSink` was not exported yet.
- Green: `bun run zigeffect:workbench:test` passed with 115 tests after artifact
  capture was implemented.
- `bun run zigeffect:workbench:typecheck` passed.
- `git diff --check` passed.
- `bun run zigeffect:local-agent-gate` passed, including the workbench build,
  115 workbench tests, 189 Zig tests, std tests/examples, and tool hygiene.
