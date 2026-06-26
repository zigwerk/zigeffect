# zigeffect Postgres Maturity Design

## Goal

Make M17 a local-production database milestone instead of another surface-area
milestone. The std SQL contract should prove typed query decoding, pool
lifecycle, transaction receipts, and redaction without depending on a live
database. The Postgres adapter should provide real local `psql` migration
planning/apply SQL and CLI-ready building blocks while staying outside the core
engine.

## Scope

- Add Schema-backed SQL row decoding to `zstd.Sql`.
- Add deterministic row/result JSON rendering with sentinel-secret redaction.
- Add pool lease/stats lifecycle helpers that are usable in local agent tools.
- Add transaction run receipts with rollback/failure evidence.
- Add Postgres migration planning, apply SQL generation, redacted receipts, and
  a sample migration CLI.
- Update docs, cookbook, roadmap, and tests.

## Non-Goals

- Do not implement a wire-protocol Postgres client in this milestone.
- Do not require a running Postgres instance in CI.
- Do not add hosted deployment behavior.
- Do not replace the existing `psql` adapter boundary.

## Architecture

`packages/zigeffect-std/src/sql/root.zig` remains driver-neutral. It owns SQL
values, rows, fake database, typed row decoding, pool lifecycle, transaction
receipts, and effect facts.

`packages/zigeffect-postgres/src/root.zig` owns Postgres-specific local details:
safe `psql` argument construction, JSON row query wrapping, migration table SQL,
plan/apply SQL, and redacted migration receipts. A small example CLI demonstrates
how a project wires its own migrations into those helpers.

## Acceptance Criteria

- A `zstd.Sql` caller can render SQL rows to JSON and decode them through
  `zstd.Schema` with path-aware row index issues.
- Text row fields, statements, migration IDs, URLs, and receipts never expose
  sentinel tokens, passwords, bearer tokens, or URL userinfo.
- Pool checkout can be represented as a lease and stats can be serialized for
  workbench/agent receipts.
- Transaction helpers record committed and rolled-back outcomes without leaving
  fake databases in an active transaction.
- Postgres migration planning detects pending/skipped migrations, generates
  executable apply SQL, and renders a redacted JSON receipt.
- A sample `zigeffect-postgres-migrate` example builds and tests without a live
  database.
