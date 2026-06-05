# zigeffect Static Requirements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans and test-driven development.

**Goal:** Add compile-time requirement comparison helpers for static
provider/consumer metadata.

**Architecture:** Extend `dependency/validation.zig`; expose helper aliases from
the package facade; add type-level metadata declarations to required effects
where needed.

**Verification:** `bun run zigeffect:test`, `bun run zig:test`,
`bun run typecheck`.

---

## Tasks

- [x] Add RED tests and a compile-fail fixture for static requirement checks.
- [x] Add `RequiredServices` metadata to required effect wrappers.
- [x] Implement static requirement helper and assertion diagnostic.
- [x] Update docs/roadmap and run full verification.
