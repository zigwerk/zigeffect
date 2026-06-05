# zigeffect Module And Application Pattern Design

Date: 2026-06-05

## Goal

Deliver roadmap section 13 as a docs-first pattern for large systems built with
`zigeffect`.

## Contracts

- A feature module owns service contract, layer, effects, tests, and docs.
- Production startup uses `layerGraph` and validates dependency reports before
  execution.
- Tests use `TestEnv`, test layers, and deterministic assertions.
- App code imports the public `zigeffect` facade; implementation modules import
  local domain files directly.

## Non-Goals

- No code generator yet.
- No app template command yet.
- No production database example wired into Yachdee app code yet.

