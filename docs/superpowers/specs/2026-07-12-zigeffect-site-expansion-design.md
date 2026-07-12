# ZigEffect Marketing Site Expansion Design

Date: 2026-07-12
Status: Approved by direct user request
Extends: `2026-07-12-zigeffect-marketing-site-design.md`

## Goal

Turn the ZigEffect landing page into a complete developer education and product
marketing site. A reader who has never used Zig, typed effects, structured
concurrency, causal graphs, or deterministic testing should be able to understand
what ZigEffect does, why it exists, how an agent uses it, and where it is already
being exercised.

The benchmark is the depth and confidence of the Ziac marketing site: dedicated
routes, long-form story arcs, precise examples, real proof, strong cross-linking,
and a shared visual system. The ZigEffect site keeps its own warm-white, slate,
charcoal, and Zig-orange identity.

## Information architecture

The public site contains nine chapters:

1. `/` — the category and vision landing page.
2. `/how-it-works` — a layperson-friendly end-to-end overview.
3. `/why-zig` — why a human-made, explicit systems language is the foundation.
4. `/runtime` — effects, services, layers, scopes, fibers, and resource ownership.
5. `/causal-graph` — how execution becomes queryable evidence instead of log archaeology.
6. `/testing` — Testing v2, deterministic worlds, semantic assertions, receipts, and replay.
7. `/agents` — the manifest-first agent development loop from requirement to handoff.
8. `/workflows` — typed statecharts and durable long-lived processes.
9. `/built-with` — real Ziac and Yachdee backend, infrastructure, and cloud use cases.

The primary navigation exposes the overview and highest-intent destinations. Each
deep page includes chapter navigation and a next-step handoff so the experience
reads as a connected book rather than a route directory.

## Content model

Every deep page follows the same comprehension ladder:

1. **Plain-English promise** — the idea in one sentence without framework vocabulary.
2. **Everyday analogy** — a small mental model that explains why the idea exists.
3. **Concrete backend example** — one checkout/order/request scenario carried through the page.
4. **Mechanism** — the exact ZigEffect concepts and public contracts involved.
5. **Agent view** — what an agent can inspect, query, change, or prove.
6. **Honest boundary** — what is not claimed or what still remains the application's responsibility.
7. **Next chapter** — a clear handoff into the next part of the system.

Copy must distinguish shipped capabilities from vision. Performance, safety, and
exactly-once claims stay bounded to the evidence and semantics documented by the
framework.

## Page narratives

### How it works

Follow one change: “make checkout retry safely.” The reader sees the declared
requirement, typed Zig program, explicit services and ownership, causal execution,
deterministic failure test, repair, verified replay, and handoff receipt. The page
introduces concepts before naming them.

### Why Zig

Explain that agents change the economics of repetition. Zig's explicit allocators,
errors, dependencies, and control are inspectable constraints—not friction to hide.
Avoid unsupported speed rankings and language-safety claims.

### Runtime

Explain effects as executable descriptions around normal Zig functions; layers as
wiring; scopes as ownership boundaries; fibers as supervised concurrent work; and
executors as replaceable ways to run the same program. Use a request-owned database
connection example.

### Causal graph

Contrast a wall of timestamped logs with a minimal causal path. Show run, scope,
fiber, service, resource, retry, and exit relationships; explain completeness,
retention, sampling, truncation, redaction, and why finding evidence is never sampled.

### Testing

Show a requirement-linked scenario, deterministic providers, injected failure,
semantic assertions, a native receipt, and an exact replay command. Explain that
unsupported, incomplete, leaked, or pending work fails closed.

### Agents

Show the agent loop: validate the project contract, select declared work, add a
failing scenario, implement through public boundaries, test affected work, inspect
receipt and causal ids, replay, run the safety gate, and publish a bounded handoff.

### Workflows

Explain durable statecharts as visible business process logic: typed states and
events, pure decisions, commands outside the transaction, journal-backed recovery,
idempotency, human review, and separately authorized control.

### Built with

Use Ziac and Yachdee as honest proof of pressure. Ziac exercises infrastructure,
provider RPC, global deployment, and operations. Yachdee exercises HTTP services,
data, storage, durable workflows, telemetry, infrastructure, and cloud boundaries.

## Visual system

- Preserve the landing page's Inter typography, deep slate, warm white, hairline
  rules, 4–6px radii, restrained shadows, charcoal buttons, and orange editorial accents.
- Use Lucide's outlined technical icons consistently; never use emoji or generic AI imagery.
- Diagrams are readable product UI: real source snippets, receipts, timelines,
  manifests, query results, and workflow states. Decorative illustration is secondary.
- Alternate white, warm, mist, and deep-slate bands to pace long-form pages.
- Large editorial headings and generous whitespace carry the story; dense card walls do not.
- All code and receipt examples are horizontally safe on 390px screens.

## Interaction and accessibility

- The header, mobile menu, chapter navigation, in-page anchors, and next-page links work.
- Current routes expose `aria-current="page"`.
- Interactive examples use semantic tabs only where a real state changes.
- Focus states are visible, reduced motion disables reveal transforms, and content
  remains present when IntersectionObserver is unavailable.
- Desktop QA target: 1440 × 1024. Mobile QA target: 390 × 844.

## SEO and discovery

Every route owns a unique title, description, canonical URL, Open Graph metadata,
Twitter metadata, and appropriate JSON-LD. All routes are prerendered and listed in
the sitemap. The How It Works hub uses `HowTo`; deep explanations use `TechArticle`;
the proof route uses `ItemList`.

## Acceptance criteria

- Nine routes render and are linked through shared navigation.
- The How It Works hub tells the complete requirement-to-replay story in lay terms.
- Each deep page contains at least one concrete example and one honest boundary.
- Runtime, causal, testing, agents, and workflows content matches the framework docs.
- Ziac and Yachdee are shown as concrete cross-stack proof.
- Route, content, navigation, SEO, sitemap, typecheck, and production-build tests pass.
- Browser QA passes on desktop and mobile with no console errors or broken primary links.

