# zigeffect workbench UX/UI reimagining — implementation plan

Design: `docs/superpowers/specs/2026-06-29-zigeffect-workbench-uxui-reimagining-design.md`
Target: `packages/zigeffect/workbench`
Verify: `bun run zigeffect:workbench:typecheck` · `bun run zigeffect:workbench:test` ·
preview (`bun run zigeffect:workbench:dev`) screenshots in dark + light.

## Constraints to honor

- Existing `derive*` functions in `causalArtifact.ts` are the **contract** — do not
  change them; only **add** `deriveTraceModel` + `resolveEvidenceEventId`.
- `verbatimModuleSyntax` → `import type` for type-only imports. `noUncheckedIndexedAccess`
  → guard array/Map access. Strict mode.
- Baseline before change: **121 pass / 0 fail**, typecheck clean. End state: green.
- Brittle source-grep tests (`App.test.tsx`, `visualGraphUi.test.ts`,
  `visualGraphAdapter.test.ts`) assert old structure strings — update them to the new
  structure, preserving behavioral intent (tab/lens exposure, transports, theme, etc.).
- Logic tests (`causalArtifact.test.ts`, `liveAttach.test.ts`,
  `localDevSessionFeed.test.ts`, collector, bridge, frame) stay green unchanged.

## File plan

New:
- `src/theme.ts` — theme + lens signals, persistence (`localStorage`, `?lens=`/`?theme=`),
  `themeVersion`.
- `src/trace/traceModel.ts` (+ `traceModel.test.ts`) — `deriveTraceModel`,
  `resolveEvidenceEventId`, severity table.
- `src/trace/TraceCanvas.tsx`, `src/trace/CausePathOverlay.tsx`.
- `src/findings/FindingsBand.tsx`.
- `src/graph/DagPanel.tsx`.
- `src/collab/CollabBoard.tsx`.
- `src/inspector/Inspector.tsx`.
- `src/ui/AppShell.tsx`, `TopBar.tsx`, `Segmented.tsx`, `LensSwitcher.tsx`,
  `ThemeToggle.tsx`, `CommandPalette.tsx`, `AuxView.tsx`.
- `src/primitives.tsx` — Badge, Chip, RefPill, CommandRow, Card, EmptyState, Metric, Meta.
- `public/sample-rich-trace.json` (+ `dist/`), `?sample=rich` mapping in `workbenchBridge.ts`.

Edited:
- `src/styles.css` — full rewrite to the token system + all component styles.
- `src/visualGraphAdapter.tsx` — tone fills/strokes read CSS vars; dagre rankdir TB;
  selection/finding emphasis; theme re-read.
- `src/App.tsx` — becomes thin: wires `createResource(loadPayload)` + live + derive
  functions + signals into `AppShell`; keep `workbenchTabsForArtifact` export shape for
  tests (re-expressed as lenses/aux views), keep `live?.localDevSession()` overlay wiring.
- Tests updated to the new structure.

## Milestones (each independently verifiable)

- **M1 — tokens + shell skeleton.** Rewrite `styles.css` token system + grid; `theme.ts`;
  `AppShell` (3-region grid, lens signal persisted, theme toggle flips `data-theme`);
  TopBar + Segmented + LensSwitcher + ThemeToggle; primitives. Verify: chrome renders
  both themes, lens swap re-weights regions, typecheck clean.
- **M2 — trace model (TDD).** Write `traceModel.test.ts` first, then `traceModel.ts`:
  seq stability, scope/resource/fiber pairing, severity table, evidence resolution.
  Verify: new tests green.
- **M3 — TraceCanvas + cause-path spine.** Swimlane from the model, sticky id ruler,
  lane columns, resource tenure bars, retry ticks, `CausePathOverlay` from row math,
  select-sync. Verify: selecting a row draws the spine; rich sample renders.
- **M4 — FindingsBand + inline marks.** Six counters/filters + inline ring marks +
  gutter severity, sharing the severity table. Verify: counter click focuses cause-path.
- **M5 — single themed DAG.** Edit `visualGraphAdapter` to read CSS vars + dagre TB +
  selection/finding emphasis; `DagPanel`; delete text "Graph" tab + duplicate fallback.
  Verify: theme flip recolors nodes; node click selects everywhere.
- **M6 — Inspector rail.** Bind to `selectedId` across selection kinds; cause-path
  breadcrumb, refs pills, redactedDetail, `queryCommandsForEvent` copy chips. Verify:
  select from trace or DAG → inspector fills; chips copy CLI strings (never execute).
- **M7 — Collaboration lens.** `CollabBoard` hero (agents/checks/turns/commands/
  guardrails/nextActions), `Evidence↳` via `resolveEvidenceEventId`, honest no-evidence
  tags, transports panel, turn count. Verify: Evidence click selects event; lens toggle
  preserves selection.
- **M8 — aux views + ⌘K + integration.** Restyled Diff/Chain/Metadata/Queries as
  overlay aux views reachable via "More" menu + ⌘K; final `App.tsx` wiring; update tests.
  Verify: full suite green, typecheck clean, dark+light screenshots in both lenses.

## Verification gates

1. `bun run zigeffect:workbench:typecheck` → exit 0.
2. `bun run zigeffect:workbench:test` → all green (updated brittle tests + new trace tests).
3. Preview: dark + light × Execution + Collaboration lenses; select an event and confirm
   the spine + inspector + DAG sync; load `?sample=rich`; confirm `?live=` path still
   mounts.
4. Final adversarial review workflow on the diff (correctness + a11y/contrast + token
   discipline), then address findings.
