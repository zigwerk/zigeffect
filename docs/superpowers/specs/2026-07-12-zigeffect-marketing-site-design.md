# ZigEffect Marketing Site Design

Date: 2026-07-12
Status: Approved through visual direction and user feedback

## Product goal

Create a public developer landing page for ZigEffect that explains a new category:
an agent-verifiable application runtime for building efficient backend, infrastructure,
and cloud systems in Zig.

The page must help a skeptical backend engineer understand four ideas quickly:

1. Zig is a human-made, explicit foundation that deserves trust.
2. ZigEffect adds typed effects, structured concurrency, causal evidence, and
   deterministic testing so coding agents can reason from facts rather than logs.
3. Ziac and Yachdee are concrete products being built across backend, infrastructure,
   and cloud with this approach.
4. Cheap agent tokens change the economics of explicit systems code: repetitive,
   boilerplate-heavy Zig becomes a strength when agents can write and debug it with
   the right runtime and evidence.

## Positioning

Primary promise:

> Build with AI. Keep the evidence.

Category statement:

> The agent-verifiable application runtime for Zig.

The page presents the end of JavaScript-first backend development as a product
vision, not an unsupported benchmark claim. ZigEffect does not disparage human-made
software; it explicitly celebrates Zig as the trusted human foundation that makes
the agentic layer possible.

## Visual direction

ZigEffect is a sibling to the Ziac marketing site. It inherits Ziac's enterprise
grid, thin rules, generous white space, restrained shadows, sharp typography, and
technical illustration language.

The ZigEffect variation combines:

- Google Cloud-style product clarity and infrastructure diagrams;
- Zig's warm orange identity;
- dark slate and charcoal controls;
- orange text emphasis, underlines, graph activity, and section rules;
- warm white and cloud-gray surfaces;
- square 4–6px radii and hairline borders.

Orange must not fill primary buttons. Avoid generic robot imagery, people, neon,
glassmorphism, decorative gradients, and feature-card walls.

## Hero carousel

The first viewport is a three-act carousel. Copy and infographic transition together.
Each frame communicates one idea and remains understandable in under five seconds.

### Frame 1: Human foundation

- Label: `01 / HUMAN FOUNDATION`
- Headline: `Zig gives us a core we can trust.`
- Story: explicit memory, explicit errors, no hidden runtime; human-made engineering
  becomes the foundation for agent-scale development.
- Visual: one clean Zig foundation plane with four annotations: explicit, fast,
  portable, human-made. The next runtime layer is only faintly suggested.

### Frame 2: Agent-readable runtime

- Label: `02 / AGENT-READABLE RUNTIME`
- Headline: `A runtime agents can reason about.`
- Story: typed effects, scopes, fibers, services, and causal evidence make runtime
  behavior inspectable instead of inferred.
- Visual: the selected layered architecture—Zig foundation, ZigEffect engine, causal
  graph—simplified for the available frame.

### Frame 3: Production proof

- Label: `03 / PROOF IN PRODUCTION`
- Headline: `Real products. Complete evidence.`
- Story: Ziac and Yachdee use ZigEffect across backend, infrastructure, and cloud.
- Visual: a single source/runtime spine branching to Ziac infrastructure and Yachdee
  backend/cloud services, converging on a verified Testing v2 receipt.

The carousel auto-advances on a calm interval, pauses after direct interaction,
supports previous/next, play/pause, keyboard navigation, visible progress, reduced
motion, and direct step selection.

## Page narrative

After the hero:

1. **Human-made foundations. Agent-scale leverage.** A narrative bridge from Zig to
   ZigEffect, using large editorial statements rather than a feature inventory.
2. **Not another AI wrapper.** Show the runtime path from intent to typed effect,
   external boundary, causal graph, replay, and verified receipt.
3. **Built with ZigEffect.** Ziac and Yachdee case studies with explicit backend,
   infrastructure, cloud, and evidence use cases.
4. **The backend after JavaScript.** Explain the economic thesis: agents remove the
   typing and repetition penalty while Zig retains explicitness, efficiency, and
   debuggability.
5. **Runtime capabilities.** A restrained list of typed effects, scoped resources,
   statecharts, Testing v2, real adapters, and causal Workbench—not a dense card wall.
6. **Final CTA.** Invite developers to start with the reference system or read the
   architecture.

## Interaction and accessibility

- All navigation and CTA targets resolve to meaningful on-page sections or public
  repository documentation.
- Mobile navigation is keyboard and screen-reader accessible.
- Carousel controls expose labels, selected state, and polite slide announcements.
- Focus styles use a visible orange/slate outline.
- `prefers-reduced-motion` removes auto-advance and transform-heavy transitions.
- Text and controls meet WCAG AA contrast on white and slate surfaces.
- Desktop target: 1440 x 1024. Mobile target: 390 x 844.

## Acceptance criteria

- The above-the-fold implementation visibly matches the selected mockups' proportions,
  typography, palette, control style, and information density.
- The hero carousel works through all three frames and remains stable on mobile.
- Ziac and Yachdee appear as real, specific use cases.
- The backend-after-JavaScript thesis is clear, provocative, and framed as vision.
- Site metadata, sitemap, robots, tests, typecheck, and production build pass.
- Browser QA covers desktop, mobile, carousel interaction, menu interaction, console
  errors, and visual comparison against the supplied design references.

