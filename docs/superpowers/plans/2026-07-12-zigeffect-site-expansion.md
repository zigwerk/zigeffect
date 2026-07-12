# ZigEffect Marketing Site Expansion Implementation Plan

Date: 2026-07-12
Design: `docs/superpowers/specs/2026-07-12-zigeffect-site-expansion-design.md`

## 1. Contract tests

- Add tests for all route modules, prerender entries, sitemap URLs, shared navigation,
  chapter handoffs, and route-specific metadata.
- Add content contracts for the layman overview, effects/runtime, causal evidence,
  Testing v2, manifest-first agent loop, durable workflows, and real product proof.
- Run the tests once and record the expected failures before implementation.

## 2. Shared marketing system

- Extract the landing page header/footer into shared marketing chrome.
- Add shared deep-page hero, proof strip, editorial section, code window, receipt,
  chapter navigation, and final CTA patterns.
- Reuse the existing reveal behavior with a no-JavaScript-safe default.

## 3. Page implementation

- Build `/how-it-works` first as the complete requirement-to-replay journey.
- Build `/why-zig`, `/runtime`, `/causal-graph`, `/testing`, `/agents`, `/workflows`,
  and `/built-with` with route-specific examples and honest boundaries.
- Update landing-page links so its claims lead to the relevant explanation or proof.

## 4. Discovery

- Add route metadata and JSON-LD helpers.
- Prerender all routes and update the sitemap.

## 5. Verification

- Run focused ZigEffect site tests, typecheck, and production build.
- Exercise primary navigation, chapter navigation, a deep page, and mobile menu in
  the in-app browser.
- Capture desktop and mobile screenshots, compare them with the established ZigEffect
  and Ziac references, fix P0/P1/P2 issues, and update `design-qa.md` to pass.

