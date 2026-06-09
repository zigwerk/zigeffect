# zigeffect Causal Workbench Graphs Design

Date: 2026-06-09

## Purpose

This slice extends the read-only SolidJS causal workbench with a richer graph
investigation surface before the project moves into app-facing runtime
adapters. The current Graph tab lists parent, scope, and fiber relationships as
plain rows. That is useful, but it does not yet answer the investigation
questions agents and humans naturally ask first:

- what caused the selected event;
- which runtime lane owns it;
- which scopes, fibers, resources, and retries are unhealthy;
- which events are roots or orphans;
- where a finding sits in the graph.

The goal is still a viewer. It must not apply remediation, change source,
modify scenario registries, or write policy decisions.

## Design Brief

- Product: local zigeffect causal workbench.
- Visual source: existing `packages/zigeffect/workbench` UI.
- Interaction level: full interaction for the Graph tab within the current
  single-artifact workbench.
- Look: dense operational tool, quiet colors, stable panels, compact controls,
  no marketing surface.

## Scope

In scope:

- TypeScript graph model derived from the already loaded causal artifact.
- Cause path for the selected event.
- Parent edge list with root/orphan handling.
- Runtime lanes for:
  - runs;
  - scopes;
  - fibers;
  - resources;
  - retries.
- Lane health derived from event statuses and existing findings.
- Clickable graph rows that update the existing inspector.
- Tests for graph derivation.
- README/design/plan notes for the graph slice.

Out of scope:

- Source mutation.
- Registry application.
- Policy decisions.
- Multi-artifact loading.
- Remediation-chain visualization from external artifacts.
- Custom force-directed canvas/SVG graph layout.

The remediation-chain workbench view should be a separate follow-up slice. It
needs chain artifact discovery/loading for diagnosis, remediation plan, audit,
decision, patch proposal, registry patch, readiness, application, and policy
records. Adding labels for those without loading the actual chain would be
visually busy and weak evidence.

## Architecture

Add pure model functions in `packages/zigeffect/workbench/src/causalArtifact.ts`
so graph derivation is tested without rendering:

- `deriveGraphModel(events, findings)` returns root events, orphan events,
  parent edges, and runtime lanes.
- `causePathForEvent(events, eventId)` returns the ordered root-to-event path
  when parent links can be followed.
- Lane health is deterministic:
  - `failure` when any lane event has `status=failure`;
  - `warning` when any lane event owns a finding, is missing, exhausted,
    pending, or running;
  - `ok` otherwise.

The Solid renderer uses the graph model only. It does not re-derive graph
semantics in JSX beyond filtering and display.

## UI

The Graph tab should become a scan-first investigation page:

1. Cause path strip for the selected event.
2. Runtime lane summary with counts for roots, edges, orphans, lanes, and
   unhealthy lanes.
3. Lane columns/cards grouped by lane kind.
4. Relationship edge list for parent links.
5. Orphan event section when parent ids reference missing events.

Every event reference is clickable and updates the existing inspector. Text
must wrap inside compact panels on desktop and mobile.

Implementation note: this branch keeps the workbench on SolidJS inside the
Zig WebUI launcher. React remains a viable renderer alternative for larger app
surfaces, but SolidJS is the chosen workbench path because the current surface
is compact, local, and runtime-adjacent.

## Safety

- Read-only only.
- Existing copyable query commands remain advisory.
- Graph model tolerates partial and older artifacts.
- Missing parent ids are represented as orphans, not crashes.
- Loops in parent chains are cut off deterministically.

## Verification

Focused checks:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
```

Browser checks:

```sh
bun run zigeffect:workbench:dev -- --port <free-port>
```

Open the workbench, verify the Graph tab renders cause path, lane cards,
relationship rows, and no horizontal overflow on mobile.

Integration checks before commit:

```sh
bun run check
bun run zig:test
git diff --check
```
