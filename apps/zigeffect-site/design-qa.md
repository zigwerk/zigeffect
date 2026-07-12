# ZigEffect Site and Hero Design QA

## Evidence

- Source visual truth: `qa/source-ziac-how-it-works.png`
- Existing ZigEffect visual system reference: `qa/source-selected-runtime.png`
- Browser-rendered implementation: `qa/how-it-works-desktop.png`
- Same-input comparison: `qa/how-it-works-comparison.png`
- Focused implementation evidence: `qa/runtime-mid-desktop.png`
- Product-proof image evidence: `qa/built-with-desktop.png`
- Existing responsive system evidence: `qa/mobile-proof.png`
- Selected hero source truth: the three full-page Causal Repair Loop, Agent Microscope,
  and Intent to Proof concepts supplied and approved in the design iteration
- Browser-rendered hero states: `qa/hero-repair.png`, `qa/hero-inspect.png`,
  and `qa/hero-ship.png`
- Same-input hero comparisons: `qa/hero-repair-comparison.png`,
  `qa/hero-inspect-comparison.png`, and `qa/hero-ship-comparison.png`
- Live system-building evidence: homepage `#system-building`, the
  `/standard-library` opening and content sections, and `/workflows` at the
  hero and durable-primitives states
- Browser viewport used for expanded-page capture: 1294 x 1029
- State: all three homepage story tabs selected with autoplay paused; top of
  `/how-it-works`; focused runtime section after reveal animation; Ziac case study after reveal animation

## Hero comparison

The approved concepts are now a single three-part story rather than competing alternatives:
Repair explains the causal repair loop, Inspect exposes the runtime's minimal evidence path,
and Ship carries a requirement through ZigEffect to deterministic proof. Each rendered state
was compared beside its corresponding source concept in the three `hero-*-comparison.png`
files. The implementation preserves the source hierarchy, technical specificity, warm-white
canvas, slate controls, orange causal path, and restrained line-work while adapting each
diagram to the live carousel's 45/55 desktop split.

The dedicated 1536 x 1024 infographic assets contain the concrete UI and evidence details
that made the source concepts persuasive. The live page owns the headings, body copy, links,
tabs, controls, and accessible descriptions, so the story remains navigable and meaningful
outside the images. No generic feature-icon composition remains in the hero.

## Full-view comparison

The Ziac How It Works source and ZigEffect How It Works implementation were composed
into one comparison image at `qa/how-it-works-comparison.png`. The implementation keeps
the source family's enterprise header, left editorial narrative, right technical visual,
strong two-column proportions, restrained borders, generous white space, and long-form
chapter pacing. ZigEffect intentionally replaces Ziac blue with its selected slate and
orange system and replaces the infrastructure topology with a concrete
requirement-to-runtime-to-replay journey.

The implementation has slightly more below-the-fold content visible at the source capture's
height because it adds a four-part proof strip before the first chapter. This is an
intentional comprehension aid and does not change the hero hierarchy.

## Focused comparison evidence

`qa/runtime-mid-desktop.png` verifies the most detail-sensitive section: the code window,
plain-language explanation card, sticky navigation, large editorial heading, and transition
into a deep-slate band. Code remains readable, the two columns align, reveal animations
settle to full opacity, and the dark band retains AA-friendly contrast.

`qa/built-with-desktop.png` verifies the real Ziac operations asset is sharp, uncropped,
and paired with specific infrastructure copy and outlined technical icons. No placeholder
or generated stock asset stands in for product evidence.

## Required fidelity surfaces

- **Fonts and typography:** Inter/system sans, bold editorial display text, and restrained
  monospace labels match the selected ZigEffect direction. Headline wrapping, optical weight,
  line height, underlines, and small utility text remain coherent across the hero and detail sections.
- **Spacing and layout rhythm:** The 68px sticky header, hero proportions, section insets,
  thin proof strip, alternating long-form bands, 4–6px radii, and restrained shadows extend
  the established visual system without becoming a card wall.
- **Colors and visual tokens:** `#172033` slate, warm white, cloud gray, hairline boundaries,
  and `#f7a41d` orange are consistently applied. Orange remains an editorial and causal accent;
  primary controls remain slate.
- **Image quality and asset fidelity:** The Ziac operations screenshot is a real source asset
  and remains sharp at its natural aspect ratio. Lucide provides all technical icons. No emoji,
  custom inline SVG, placeholder illustration, or generic AI imagery was introduced.
- **Copy and content:** Each route has a plain-English promise, concrete checkout/order example,
  exact framework mechanisms, an agent view, an honest boundary, and a connected next chapter.
  Safety, performance, evidence completeness, and exactly-once semantics remain bounded to the
  framework's documented claims.

## Interaction and responsive evidence

- Repair, Inspect, and Ship tabs all select the corresponding content and pause autoplay.
- Previous/next buttons and ArrowLeft/ArrowRight keyboard navigation move between slides.
- Play/pause state, reduced-motion handling, descriptive alt text, and real destination links
  remain present for every slide.
- All ten routes rendered in the in-app browser with unique titles and H1s.
- The new Standard Library page renders six module families, has an active
  shared-navigation state, and reports `scrollWidth === innerWidth` at 1294px.
- The expanded Workflows page renders five durable primitive cards, activates
  the Workflows navigation item, and reports `scrollWidth === innerWidth`.
- The homepage system-building section resolves both Standard Library and
  Workflows links and reports no horizontal overflow.
- Every expanded route reported `scrollWidth === innerWidth` at the browser viewport.
- Primary navigation from How It Works to Runtime worked and updated `aria-current="page"`.
- Sticky navigation, in-page anchors, next-chapter links, and proof links resolve.
- Browser console and warning check returned zero entries across the route sweep.
- The deep-page responsive contract is covered by `siteExpansion.test.ts`: the 760px layout
  collapses the hero, grids, workflows, receipts, and chapter navigation, while code windows
  retain horizontal scrolling.
- Existing 390 x 844 browser evidence for the shared ZigEffect header, buttons, typography,
  and overflow behavior remains at `qa/mobile-proof.png`. The in-app viewport override did not
  produce a separate narrow capture for the new route, so this remains a P3 verification gap,
  not a visible P0/P1/P2 defect.

## Comparison history

1. **Initial implementation:** The expanded pages inherited the landing-page tokens but had
   no route-aware navigation, chapter structure, or real proof image.
2. **Fixes applied:** Added shared current-route navigation, a consistent deep-page system,
   eight dedicated routes, connected chapter handoffs, and the real Ziac operations asset.
3. **Post-fix evidence:** `qa/how-it-works-comparison.png`, `qa/runtime-mid-desktop.png`, and
   `qa/built-with-desktop.png` show no remaining actionable P0, P1, or P2 issue.
4. **Hero story upgrade:** Replaced the abstract Foundation/Runtime/Proof illustrations with
   the approved Repair/Inspect/Ship sequence and compared all three live states against the
   selected source concepts. No actionable P0, P1, or P2 issue remains in the hero.
5. **System-building story:** Added a balanced light/dark homepage assembly section,
   a full Standard Library chapter, and a substantially deeper durable workflow and
   statechart chapter. Desktop inspection found no overflow, broken hierarchy, or
   navigation conflict at the 1294px verification viewport.

## Findings

No actionable P0, P1, or P2 issues remain.

## Follow-up polish

- P3: Capture a dedicated 390 x 844 screenshot of `/how-it-works` when the in-app viewport
  override is available again; the responsive CSS and shared mobile system are already verified.
- P3: Replace current internal Get Started anchors with the public installation/docs URL when
  that publication destination is finalized.

## Implementation checklist

- [x] Source and implementation compared in the same input
- [x] All three hero states captured and compared
- [x] Tabs, buttons, keyboard navigation, and play/pause exercised
- [x] Typography, spacing, colors, image fidelity, and copy checked
- [x] Ten routes rendered and primary navigation exercised
- [x] Long-form code and dark-band detail inspected
- [x] Product proof asset inspected
- [x] Console errors checked
- [x] Tests, typecheck, and production build run

final result: passed
