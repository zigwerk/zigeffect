# zigeffect causal workbench — UX/UI reimagining (design)

Date: 2026-06-29
Surface: `packages/zigeffect/workbench` (SolidJS + Vite + @antv/g6)
Status: design locked, implementing

## Problem

The workbench is a read-only viewer for zigeffect causal-execution artifacts. Today
it is nine flat, same-weight tabs (Timeline, Dev Session, Findings, Graph, Visual
Graph, Diff, Chain, Queries, Metadata) on a pale sage theme, where everything is an
identical bordered white card covered in shouty uppercase micro-labels. Concrete
failures:

- **No visual hierarchy** — the eye has nowhere to land.
- **"Program execution" is never actually visualized** — the Timeline is a flat list
  with no sense of logical time, causality, concurrency (fibers), or nesting (scopes).
- **Two confusing graph tabs** — a text-list "Graph" and a G6 "Visual Graph" that is
  buried under a metric strip and duplicated by a giant text fallback.
- **Findings (the six real failure patterns) are under-emphasized**, one quiet tab.
- **The human↔AI dev-session is a flat data dump** disconnected from the trace it
  describes.

## Locked direction (from the user)

1. **Theme** — dark by default with a one-click **light** toggle; a full two-palette
   design-token system. Aesthetic bar: Linear / Sentry / Jaeger / Temporal.
2. **Scope** — full reimagining. Centerpiece is (a) a real time-ordered **swimlane
   trace** (runs › scopes › fibers over a *logical-sequence* axis) and (b) exactly
   **one** interactive **causal DAG** (G6) with findings **pinned**. Findings and the
   cause-path are woven *into* the trace. One persistent **inspector** stays in sync
   across every view.
3. **Headline** — a top-level **lens switcher** reorients the whole app between
   *Execution-first* and *Human↔AI-collaboration-first*. Both are first-class.

Stack constraints: keep SolidJS, keep G6 for the DAG, keep the existing TypeScript
data model and `derive*` functions (no Zig/wire-format changes), plain CSS with
design tokens (no Tailwind in the workbench), keep read-only safety framing, keep
live-attach (`?live=ws://…`) working.

## Key data fact

Causal events carry **no timestamps**. They are ordered by a monotonic `id`. So the
trace x-axis (here, the *vertical* reading axis) is **logical sequence**, and lanes
are the structural grouping (run › scope › fiber, with resources inside scopes and
`schedule_decision` retries). `parentId` gives causal edges; `causePathForEvent`
walks the parent chain to a root. Static samples are tiny (6–9 events); live mode
accumulates up to 1000 frames. The design must look intentional at N=9 and scale.

## North star

One continuous, read-only **evidence surface**. A program execution is told as a
single logical-time story (id 1→N), and the human↔AI collaboration that produced it
is the *second face* of that same story, bound by one selection. Nine tabs collapse
into one shell with two lenses and one persistent inspector.

## Information architecture

**Lenses (top axis, replaces tabs):** `Execution` | `Collaboration`. One persisted signal.

**Three primary surfaces**, reused under both lenses, only re-weighted:
1. **Trace** — the logical-sequence swimlane (hero in Execution; evidence strip in Collaboration).
2. **Graph** — the single G6 causal DAG (companion in Execution; minimap in Collaboration).
3. **Collab** — the agent / check / turn board (slim ribbon in Execution; hero in Collaboration).

**Persistent chrome (lens-independent):** TopBar (artifact breadcrumb, read-only lock,
live dot + frame count, lens switcher, theme toggle, ⌘K hint, filter controls);
FindingsBand (six severity counters/filters) above the trace; Inspector right rail.

**Where the nine tabs went:** Timeline→Trace hero; Graph (text)→deleted, absorbed;
Visual Graph→the single Graph/DAG (no duplicate fallback); Findings→FindingsBand +
inline marks + inspector callout; Dev Session→Collab surface; Diff/Chain/Metadata/
Queries→reachable as auxiliary overlay views (⌘K + "More" menu) and inspector modes,
reusing their existing rich renderers, restyled to tokens.

## Lens switcher mechanic

A two-segment sliding-thumb pill in the topbar bound to one signal
`lens(): "execution" | "collaboration"`, default `execution`, persisted to
`localStorage("zigeffect.lens")` and honored from `?lens=`. The switch **never
navigates and never unmounts** panels — it sets `data-lens` on the workspace; CSS
re-weights the same grid (and `order`). The trace and the single G6 DAG stay mounted
across the toggle (G6 re-fit, not re-instantiated), so selection persists with no
flash. Both lenses share one `selectionModel` (`selectedId` + `selectionKind`).

## New pure logic (unit-tested, TDD)

`src/trace/traceModel.ts`:

- **`deriveTraceModel(events, lanes, findings) → TraceModel`** with
  `{ rows, laneColumns, scopeBands, resourceTenures, fiberRails, findingMarks, seqIndexById }`.
  - `seqIndexById` — monotonic, stable index per event = the single source of truth
    for row position (overlays compute geometry from `row-h × index`, never DOM reads).
    Stable as live frames append.
  - `laneColumns` — deterministic column assignment in fixed order
    run→scope→fiber→resource→retry; inactive lanes flagged collapsible.
  - `scopeBands` — pair `scope_opened`↔`scope_closed` by `scopeId`; unclosed ⇒
    `endIndex=null` (open-ended), never throws.
  - `resourceTenures` — pair `resource_acquired`↔`resource_finalized`; no finalize ⇒
    `leaked=true` (red dangling stub).
  - `fiberRails` — pair `fiber_forked`↔`fiber_joined|fiber_interrupted`;
    `pendingAtScopeClose=true` when a fiber outlives its owning scope band.
  - `findingMarks` — one **severity table** (single source of truth), shared by trace
    marks, DAG pins, and findings counters, so "finding N" has one identity everywhere.
- **`resolveEvidenceEventId(entity, session, findings) → string | null`** —
  resolution order `lastEventId → eventId → issue-highlight ref → null`. `null` is an
  honest "no causal evidence" outcome, not a hole.

## Severity table (locked, 2-tier)

`fail`: `retry_budget_exhausted`, `finalizer_failure`, `assertion_failure`.
`warn`: `service_requirement_without_provider`, `fiber_pending_after_scope_close`,
`resource_acquired_without_finalization` (leak — warn severity, but still renders the
red dangling resource stub).

## Design tokens (two palettes, CSS custom properties)

All tokens on `:root`; overridden under `:root[data-theme="light"]`. One indigo accent
+ a strict ok/warn/fail triad. The G6 canvas reads the **same** vars via
`getComputedStyle` so the graph matches the chrome.

- **Dark (default):** `--bg-0:#0B0E14` `--bg-1:#11151D` `--bg-2:#141821`
  `--surface:#161B26` `--surface-hi:#1E2430` `--surface-sunken:#0D1014`
  `--border:#232B3A` `--border-strong:#323A48`; text `#E6EAF2 / #A6B0C3 / #6B7689`;
  `--accent:#6E8BFF` `--accent-live:#34D2C8`; `--ok:#37C2A6` `--warn:#E5A13A`
  `--fail:#F2555A`; tone fills `rgba(55,194,166,.12) / rgba(229,161,58,.14) /
  rgba(242,85,90,.16)`; agent hues codex `#A78BFA` claude `#E8915B` zigeffect `#5BD1C4`
  human `#7FA6FF` other `#8A93A6`.
- **Light:** `--bg-0:#F7F8FB` surfaces `#FFFFFF` `--surface-hi:#EEF1F8`
  `--border:#E2E6EE`; text `#151A22 / #475067 / #7A8294`; `--accent:#3F5BD8`
  `--ok:#0FA98C` `--warn:#B5781A` `--fail:#D23B45`; tone fills at higher opacity for
  white-bg contrast; agent hues desaturated.
- **Type:** Inter / JetBrains-Mono fallback; scale 11/12/13/15/19/24; weights 450/600/750;
  **sentence-case** labels (not uppercase). Mono for ids/commands/refs.
- **Space (4px base):** 4/8/12/16/24/32. **Radius:** 6/10/14/pill.
  **Elevation:** border + one soft shadow. **Lane metrics as tokens:** `--row-h`
  22px (comfortable) / 14px (compact), `--gutter-w` 200px, `--inspector-w` 380px.
- **Motion:** `--ease:cubic-bezier(.2,.7,.2,1)`; 120/180/240ms; selected row =
  `background:--surface-hi; box-shadow: inset 2px 0 0 --accent`;
  `prefers-reduced-motion` zeroes durations and disables the live flash + spine draw.

## Interaction model

- **Selection spine** — one signal; clicking anywhere (trace row, DAG node, finding
  pin/counter, cause-path breadcrumb, collab Evidence↳) writes `selectedId`; the trace
  scrolls to + highlights the row and draws the indigo cause-path spine, the DAG
  centers + halos the node, the FindingsBand marks the pill, the inspector fills.
- **Hover** — tint to `--surface-hi`, ghost cause-path preview, delayed tooltip.
- **Keyboard** — ↑/↓ move by sequence; ←/→ parent/first-child; `f` next finding;
  ⌘K palette; ⌘1/⌘2 lens; theme toggle; `/` focus filter; Esc clear.
- **Filtering** — `filterEvents` drives `visibleEvents()` everywhere; filtered-out rows
  collapse to an "N hidden" spacer (preserve id continuity). FindingsBand pills act as
  cause-path focus filters.
- **Live-stream** — frames append at trace bottom + DAG (debounced graph update,
  freeze existing node positions); 1-row `--ok` flash; live dot + counter; new-finding
  toast; auto-follow with "↓ N new".
- **Theme toggle** — flips `data-theme` on `<html>`, bumps a `themeVersion` signal;
  trace SVG and G6 re-read CSS vars.

## Scope decisions (this pass)

Implemented in full: token system, dual-lens shell, swimlane TraceCanvas + cause-path
overlay, FindingsBand, single themed DAG (delete text Graph + fallback), CollabBoard
with evidence jumps, persistent Inspector, restyled Diff/Chain/Metadata/Queries as
auxiliary views, and a lightweight ⌘K palette.

Deferred (explicit, follow-up): row **virtualization** (unnecessary at current data
sizes — all rows render with CSS containment; safe to N≈1000), live-mode toast +
auto-follow polish, full keyboard map. The trace overlay still uses `row-h × index`
geometry so virtualization can drop in later without layout change.

A richer demo sample (`public/sample-rich-trace.json`, `?sample=rich`) is added so the
swimlane + DAG + findings show off beyond the 9-event default.

## Risks & mitigations

- **G6 capability** (pins/halo/theme re-read may exceed `@dschz/solid-g6`): isolate all
  G6 specifics in `DagPanel` + `visualGraphAdapter`; start with built-in state APIs.
- **Overlay drift**: positions strictly from `row-h × seqIndex`, never DOM reads.
- **`numericId` nullable / live append**: y-order falls back numericId → parsed idText
  → insertion order; index stable on append.
- **Two-palette contrast**: required contrast pass on the three tone fills + agent hues
  on white.
- **Both lenses first-class**: width ratios + auto-framing give each a clear focal point;
  panels stay mounted (no G6 re-init) for a flash-free morph.
- **Scope**: rewrite of App.tsx view layer + one adapter edit; all existing `derive*`
  functions stay untouched as the contract — only **add** `deriveTraceModel` +
  `resolveEvidenceEventId`.
