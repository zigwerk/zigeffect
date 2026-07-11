# ZigEffect Testing v2 Repository Migration Plan

Date: 2026-07-11
Design: `docs/superpowers/specs/2026-07-11-zigeffect-testing-v2-repository-migration-design.md`

## M131 — Suite receipt contract (TDD)

- Add failing tests for valid, incomplete, duplicate, leaking, logged-error, and failed suite receipts.
- Implement the dependency-neutral versioned receipt contract and atomic writer in core.
- Export receipt parsing through `zigeffect_std.Testing` without duplicating the wire model.

## M132 — Zig compiler runner (TDD)

- Add compatibility tests for runner exports and build-server mode.
- Implement the Zig 0.16 server runner while preserving metadata, per-test result, allocator, logging, tracing, and fuzz behavior.
- Record all discovered and executed tests and atomically publish the suite receipt.

## M133 — Core and standard library migration

- Export the runner build module from core and re-export it from std.
- Route every core and std test artifact, including examples and release gates, through the V2 runner.
- Add package-level semantic acceptance coverage for Testing v2 itself.
- Verify Debug and ReleaseSafe.

## M134 — Adapters, CLI, and first-party project migration

- Migrate CLI unit/integration, Postgres, QUIC, ZIO, Ziac, and Zgroach test artifacts.
- Add meaningful Testing v2 semantic scenarios to packages that can import `zigeffect_std`.
- Verify each package-native test command and receipt.

## M135 — Generated project migration

- Update executable, library, and system build templates to use the runner exported by `zigeffect-std`.
- Update scaffold contract snapshots and template version/compatibility metadata.
- Extend generated-project tests to assert complete suite receipts in Debug and ReleaseSafe.

## M136 — Agent workflow and documentation

- Document legacy-unit migration, semantic scenario guidance, receipt locations, replay, and failure triage.
- Update `.agents` and `.claude` ZigEffect skills in lockstep.
- Add a repository check that rejects new unmigrated first-party test artifacts.

## M137 — Full proof

- Run package-native Debug and ReleaseSafe gates.
- Run generated-project integration tests and the full local-release script.
- Inspect emitted receipts and report exact counts and any limitations.
