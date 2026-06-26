# zigeffect Workbench Dev Session UX Design

Date: 2026-06-26

Status: delivered on 2026-06-26.

## Decision

Upgrade the SolidJS workbench's local development session view so it is useful
for M13 cookbook feeds and M14 supervisor output.

The existing `Agents` tab already renders local agents, checks, artifacts,
commands, next actions, guardrails, and warnings. M15 keeps that data model and
adds a richer derived UX: health summary, command/check timeline, and explicit
Schema/CLI issue highlights.

## Goals

- Keep the existing tab id (`agents`) so old URLs and tests remain stable.
- Rename the tab label to "Dev Session" for clearer intent.
- Add pure model helpers for:
  - local dev health summary.
  - development timeline items.
  - Schema/CLI issue highlights.
- Render the helpers in the Agents/Dev Session tab.
- Keep the view dense and operational, not a marketing page.
- Preserve existing local dev session parsing and live-feed behavior.

## Non-Goals

- No new backend or collector protocol.
- No new graph renderer; the existing visual graph remains the graph view.
- No write actions from the browser.
- No CSS theme overhaul.

## UX Shape

The Dev Session tab should show:

- target/phase/status plus pass/fail/running check counts.
- session metadata.
- a timeline combining agent status, checks, commands, artifacts, guardrails,
  warnings, and next actions.
- Schema/CLI issue highlights from failed checks, warnings, or command details.
- existing local agent rows, check rows, artifact rows, and copyable commands.

## Testing

Required coverage:

- tab label changes to "Dev Session" while id stays `agents`.
- health summary counts pass/fail/running checks and blocked/failed agents.
- timeline derives stable rows from agents/checks/commands/artifacts/actions.
- issue highlights detect Schema/CLI failure detail without leaking secrets.
- workbench typecheck and tests pass.
