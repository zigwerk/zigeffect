# ZigEffect gRPC Marketing Page Implementation Plan

Date: 2026-07-13

## Goal

Ship an evidence-backed `/grpc` product chapter on `zigeffect.dev` that explains
the native Zig/ZigEffect integration, publishes reproducible performance
observations, answers Go-comparison questions positively and honestly, and
keeps the production-candidate boundary explicit.

## Implementation Steps

1. Add `apps/zigeffect-site/src/grpcPage.test.ts` with failing source contracts
   for the page component, route metadata, FAQ comparison, benchmark values,
   qualification boundary, navigation, prerendering, sitemap, and mobile CSS.
2. Extend `apps/zigeffect-site/src/siteExpansion.test.ts` so `/grpc` participates
   in the complete deep-route and metadata contracts.
3. Add `apps/zigeffect-site/src/GrpcPage.tsx` using the shared `DeepPage`,
   `SectionHeading`, and `CodeWindow` primitives. Build the hero, architecture,
   performance, Go comparison, Cloud Run, qualification, and FAQ sections from
   checked-in evidence.
4. Add `apps/zigeffect-site/src/routes/grpc.tsx` with route-owned metadata and
   `SoftwareSourceCode` plus `FAQPage` JSON-LD.
5. Add `/grpc` to `MarketingRoute`, primary/mobile navigation, footer,
   `app.config.ts`, and `public/sitemap.xml`. Add an explicit link from the
   standard-library gRPC section.
6. Add page-specific responsive CSS to `apps/zigeffect-site/src/styles.css`,
   reusing existing design tokens and ensuring tables/diagrams remain usable at
   390 px.
7. Run the focused new test to prove red-to-green, then run the full ZigEffect
   site tests, TypeScript check, and production build. Inspect build output for
   `/grpc` prerendering and finish with the repository-wide check if focused
   gates pass.

## Verification Commands

```sh
bun test apps/zigeffect-site/src/grpcPage.test.ts
bun run zigeffect-site:test
bun run zigeffect-site:typecheck
bun run zigeffect-site:build
bun run check
```

## Claim Sources

- `packages/zigeffect-grpc/README.md`
- `packages/zigeffect-grpc/THIRD_PARTY_NOTICES.md`
- `packages/zigeffect-grpc/conformance/grpc-live.v2.candidate.json`
- `packages/zigeffect-grpc/conformance/benchmarks-linux-arm64.v1.json`
- `packages/zigeffect-grpc/conformance/cloud-run-arm64-15m.v2.json`
- `packages/zigeffect-grpc/benchmarks/PERFORMANCE.md`
