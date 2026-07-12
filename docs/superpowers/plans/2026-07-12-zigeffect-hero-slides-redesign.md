# ZigEffect Hero Slides Redesign Plan

Date: 2026-07-12
Design: `docs/superpowers/specs/2026-07-12-zigeffect-hero-slides-redesign.md`

1. Add failing source-contract tests for the three selected slide ids, labels, copy,
   tabs, asset paths, CTAs, and removal of the old asset references.
2. Generate three standalone infographic assets from the selected full-page concepts
   using the built-in image generator, inspect them, and save them under
   `apps/zigeffect-site/public/assets/`.
3. Update `HeroCarousel.tsx` and any needed image sizing styles without altering the
   working interaction model.
4. Run tests, typecheck, build, and in-app browser QA for all three states.
5. Compare each selected reference against its rendered slide, fix P0/P1/P2 issues,
   and update `apps/zigeffect-site/design-qa.md`.

