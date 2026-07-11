# zigeffect Bidirectional PTY Sessions Implementation Plan

## Goal

Deliver M87 native PTY ownership, bounded authenticated terminal controls, and
an xterm.js workbench surface.

## Steps

- [x] Add failing deterministic PTY supervisor tests for lifecycle, I/O,
  redaction, retention gaps, limits, abort, and cleanup.
- [x] Implement the fakeable Bun terminal runner and bounded PTY supervisor.
- [x] Add a real Bun PTY smoke test.
- [x] Add failing control API tests for tool mode, terminal reads, input, resize,
  batch rejection, retention, and input secrecy.
- [x] Integrate PTY ownership and routes into the control server and host.
- [x] Add interactive Codex/Claude host tools without bypass flags.
- [x] Add failing browser-client/controller terminal contract tests.
- [x] Implement validated terminal client methods and cursor polling.
- [x] Add xterm.js and fit-addon dependencies, then build the lazy terminal
  surface with desktop/mobile operator integration.
- [x] Run an inert real-browser launch/input/output/resize/exit proof.
- [x] Update roadmap and local operator documentation.
- [x] Run focused tests, full workbench tests, strict typecheck, production
  build, diff hygiene, and the full local agent gate.
- [x] Commit M87 without unrelated workspace files.

## Verification

- Focused PTY supervisor/control/client/operator/UI tests.
- Real Bun PTY smoke test.
- `bun run zigeffect:workbench:test`
- `bun run zigeffect:workbench:typecheck`
- `bun run zigeffect:workbench:build`
- Desktop and mobile browser screenshots plus console check.
- `git diff --check`
- `bun run zigeffect:local-agent-gate`

## Evidence

- Workbench: 256 tests and 1,237 assertions pass.
- Core/local gate: 193 Zig tests pass; standard-library tests/examples and tool
  hygiene pass.
- Strict workbench typecheck and production build pass. xterm.js remains a lazy
  production chunk.
- Native Bun smoke proves TTY detection, input, output, resize, and exit.
- Real loopback browser proof launched `/bin/sh`, rendered
  `pty-browser-ok`/`desktop-pty-ok`, propagated fit dimensions, exited cleanly,
  retained completed output, and produced no browser warnings/errors.
- Responsive proof covers `1280 x 720` and `390 x 844` with no horizontal
  overflow; mobile terminal focus is breakpoint-scoped and desktop preserves
  the operator header.
- `git diff --check` passes and unrelated Court Series drafts remain excluded.
