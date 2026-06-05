# zigeffect Backend Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> and keep tests red/green.

**Goal:** Expose deterministic runtime backend capabilities as the compatibility
boundary for future async backends.

**Architecture:** Add `packages/zigeffect/src/runtime/backend.zig`; expose it
through the runtime namespace and root facade. `Runtime` and `FiberRuntime`
store/expose capabilities.

**Verification:** `bun run zigeffect:test`, `bun run zig:test`,
`bun run typecheck`.

## Tasks

- [x] Add failing backend capability tests.
- [x] Add `runtime/backend.zig` with `BackendKind`, `BackendCapabilities`, and
  `deterministicBackend`.
- [x] Add backend capability fields/helpers to `Runtime` and `FiberRuntime`.
- [x] Expose backend APIs through `src/zigeffect.zig`.
- [x] Update architecture, usage/parity/roadmap docs.
- [x] Run full verification.
