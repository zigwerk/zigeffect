# ZigEffect Marketing Site Implementation Plan

Date: 2026-07-12
Design: `docs/superpowers/specs/2026-07-12-zigeffect-marketing-site-design.md`

## 1. Contract and test-first scaffold

- Add `apps/zigeffect-site` as a SolidStart sibling of `apps/ziac-site`.
- Add package scripts to the repository root.
- Write failing tests for SEO metadata, navigation/story copy, three carousel frames,
  Ziac/Yachdee proof, backend-after-JavaScript vision, reduced-motion behavior, and
  required accessibility labels.

## 2. Visual assets

- Produce three hero infographic assets grounded in the selected mockups.
- Keep the assets image-native; use the established icon library for interface icons.
- Optimize the assets for a roughly 720 x 520 desktop slot and responsive containment.

## 3. Hero and shell

- Implement the shared enterprise header, responsive navigation, wordmark, and CTAs.
- Implement a controlled three-frame carousel with automatic and manual progression,
  pause/resume, direct step selection, keyboard support, and reduced-motion behavior.
- Match the selected hero typography, slate controls, orange emphasis, and whitespace.

## 4. Story sections

- Implement the human-foundation bridge.
- Implement the intent-to-evidence runtime story.
- Implement Ziac and Yachdee case studies.
- Implement the backend-after-JavaScript thesis and runtime capability summary.
- Implement the final developer CTA and footer.

## 5. Verification

- Run focused site tests, repository typecheck integration, and production build.
- Start the local site and capture 1440 x 1024 and 390 x 844 states.
- Exercise carousel, pause/resume, direct slide selection, navigation, and mobile menu.
- Check browser console errors.
- Compare source references and implementation in one visual QA input.
- Fix every P0/P1/P2 issue and record a passing `apps/zigeffect-site/design-qa.md`.

