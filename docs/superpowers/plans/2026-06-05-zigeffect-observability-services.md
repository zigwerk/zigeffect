# zigeffect Observability Services Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> and keep tests red/green.

**Goal:** Add structured log entries, metrics histograms/snapshots, and trace
span ids while preserving existing test service APIs.

**Architecture:** Changes stay in `packages/zigeffect/src/services/logger.zig`,
`metrics.zig`, and `tracing.zig`, with tests in `services_test.zig`.

**Verification:** `bun run zigeffect:test`, `bun run zig:test`,
`bun run typecheck`.

## Tasks

- [x] Add failing observability tests in `packages/zigeffect/test/services_test.zig`.
- [x] Add logger levels, fields, and structured entries.
- [x] Add metrics histograms and snapshots.
- [x] Add tracing span ids and parent relationships.
- [x] Update usage, parity, and roadmap docs.
- [x] Run full verification.
