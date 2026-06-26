# zigeffect Postgres Maturity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:test-driven-development and verification-before-completion.

**Goal:** Complete M17 by making the local SQL/Postgres stack typed,
receipt-producing, migration-aware, and safer for local agent development.

## Tasks

- [x] Add failing std SQL tests for row JSON redaction, Schema-backed typed row
  decoding, pool leases/stats, and transaction rollback receipts.
- [x] Implement driver-neutral SQL row JSON, typed query decoding, lease/stats,
  and transaction helpers.
- [x] Add failing Postgres tests for JSON query wrapping, migration planning,
  apply SQL generation, redacted receipts, and CLI output.
- [x] Implement Postgres migration planning/apply SQL/CLI building blocks and
  wire the example into `packages/zigeffect-postgres/build.zig`.
- [x] Update README, cookbook, and roadmap docs.
- [x] Run `bun run zigeffect:std:test`, `bun run zigeffect:postgres:test`,
  `git diff --check`, and the local agentic development gate before committing.

## Verification

Primary checks:

```sh
bun run zigeffect:std:test
bun run zigeffect:postgres:test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
git diff --check
bun run zigeffect:local-agent-gate
```
