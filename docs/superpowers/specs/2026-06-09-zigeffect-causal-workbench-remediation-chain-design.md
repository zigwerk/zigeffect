# zigeffect Causal Workbench Remediation Chain Design

Date: 2026-06-09

## Purpose

This slice extends the read-only SolidJS causal workbench so it can inspect
remediation and governance evidence, not only raw `zigeffect.causal.v1` runtime
event artifacts. The immediate target is `zigeffect.causal.audit-chain.v1`,
because that artifact already summarizes the before/after evidence posture and
links the remediation audit, manual decision, patch proposal, causal before and
after runs, compare report, verification commands, and guardrails.

The workbench remains a viewer. It must not apply remediation, edit source,
update the scenario registry, run policy decisions, or treat advisory policy
records as mutation authority.

## Current State

The workbench bridge loads one bounded artifact payload and one session payload:

- `tools/causal_workbench.zig` exposes `zigeffect_load_artifact` and
  `zigeffect_load_session` through Zig WebUI.
- `tools/causal_workbench_session.zig` records a read-only session and a single
  selected artifact path.
- `workbench/src/causalArtifact.ts` currently normalizes event artifacts and
  derives timeline, findings, graph lanes, and query commands.
- `workbench/src/App.tsx` renders timeline, findings, graph, query, metadata,
  and inspector views.

The remediation pipeline already emits linked artifacts under
`.zig-cache/causal-artifacts/`:

```text
dev-session
  -> remediation audit
  -> remediation decision
  -> patch proposal
  -> audit chain
  -> scenario proposal
  -> registry patch
  -> registry application readiness
  -> registry application record
  -> policy decision
```

The first workbench step is to inspect that chain from the selected artifact.
Loading every linked artifact through the bridge is intentionally left for a
later multi-payload bridge slice.

## Scope

In scope:

- Parse known governance schemas enough for workbench display:
  - `zigeffect.causal.audit-chain.v1`;
  - `zigeffect.causal.remediation-audit.v1`;
  - `zigeffect.causal.remediation-decision.v1`;
  - `zigeffect.causal.patch-proposal.v1`;
  - `zigeffect.causal.registry-application-readiness.v1`;
  - `zigeffect.causal.registry-application.v1`;
  - `zigeffect.causal.policy-decision.v1`.
- Derive a remediation chain model from a selected audit-chain artifact.
- Show:
  - assessment and approval/application state;
  - source artifact paths;
  - event id classifications;
  - verification commands;
  - claim/proposal/chain guardrails;
  - suggested follow-up workbench commands for source artifacts.
- Add a Chain tab to the existing SolidJS workbench.
- Add a development sample chain artifact so browser verification can exercise
  the Chain tab without a Zig bridge.
- Keep causal event artifacts working exactly as they do now.

Out of scope:

- Loading multiple linked artifacts through the Zig bridge.
- Rendering before/after event diffs from linked artifact contents.
- Applying source patches, registry patches, or policy results.
- Running CLI commands from the UI.
- Persisting workbench state outside the local session.

## Data Model

Add pure TypeScript model helpers beside the current causal artifact model:

- `deriveGovernanceModel(raw, options)` returns `null` for ordinary causal event
  artifacts and a display model for supported governance artifacts.
- `deriveRemediationChainModel(raw, options)` returns a chain model only for
  `zigeffect.causal.audit-chain.v1`.
- Chain source paths are normalized into ordered steps:
  - session;
  - audit;
  - decision;
  - proposal;
  - before;
  - after;
  - compare.
- Event classifications are normalized from:
  - `event_ids`;
  - `disappeared_event_ids`;
  - `persisting_event_ids`;
  - `appeared_event_ids`;
  - `missing_event_ids`.

The parser must tolerate partial and older artifacts. Missing optional fields
produce empty lists, `unknown` labels, or warning text rather than crashes.

## UI

The Chain tab is a scan-first evidence page:

1. Status strip for schema, target, assessment, approval status, and applied
   state.
2. Ordered source path pipeline with copyable/openable workbench command text.
3. Event classification columns for disappeared, persisting, appeared, and
   missing ids.
4. Verification command list.
5. Guardrail list.

If the selected artifact is not a supported governance artifact, the Chain tab
shows an empty state that explains the loaded schema has no remediation chain.

The UI must remain dense and operational, match the existing 6px-radius
workbench style, and wrap long artifact paths on mobile without horizontal
overflow.

## Safety

- All chain UI is read-only.
- Follow-up commands are displayed as text only.
- `applied=true` is shown as recorded evidence, not treated as authorization.
- Policy decisions remain advisory. The UI must surface `mutation_authority`
  when present.
- The workbench continues to avoid secrets and external services for local
  artifact viewing.

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

Open `http://127.0.0.1:<port>/?sample=chain`, switch to Chain, and verify:

- status strip renders assessment, approval, and applied state;
- source pipeline includes before, after, compare, audit, decision, and
  proposal paths;
- event classifications render disappeared, persisting, appeared, and missing
  ids;
- mobile viewport has no document or element horizontal overflow;
- browser console has no errors.

Integration checks before final commit:

```sh
bun run check
bun run zig:test
git diff --check
```
