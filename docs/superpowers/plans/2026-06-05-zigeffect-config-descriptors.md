# zigeffect Config Descriptors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> and keep tests red/green.

**Goal:** Add typed config descriptors, defaults, parse errors, and safe
diagnostics over the current in-memory config service.

**Architecture:** Changes stay in `packages/zigeffect/src/services/config.zig`
with public access through existing `fx.Config` / `fx.ConfigError` aliases.

**Verification:** `bun run zigeffect:test`, `bun run zig:test`,
`bun run typecheck`.

## Tasks

- [x] Add failing typed descriptor and diagnostic tests in
  `packages/zigeffect/test/services_test.zig`.
- [x] Add descriptor types/constructors and `Config.read`.
- [x] Add `InvalidConfigValue` and `formatConfigError`.
- [x] Update usage, errors, parity, and roadmap docs.
- [x] Run full verification.
