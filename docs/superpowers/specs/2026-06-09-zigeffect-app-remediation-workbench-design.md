# zigeffect App Remediation Workbench Design

## Context

M8 now has a complete non-mutating app remediation artifact chain:

```text
app causal artifact
  -> app remediation audit
  -> app policy decision
  -> app patch proposal
```

The SolidJS workbench already recognizes these schemas as governance artifacts,
but the Chain tab only shows a generic summary unless the artifact is a core
`audit-chain`. This branch should make the app-facing artifacts useful to
agents and developers by rendering their actual remediation details:

- app incident rows;
- policy gates and gate results;
- query commands and verification commands;
- source artifact links;
- proposal citations for app files, config keys, migrations, runbooks, and
  rollback plans;
- guardrails and warnings.

Product design brief: extend the existing read-only SolidJS workbench hosted by
`zig-webui`. Match the current dense developer-tool UI, use the existing Chain
tab and copy-button interaction patterns, and keep every surface read-only.

## Goals

- Add a pure TypeScript app remediation model in
  `packages/zigeffect/workbench/src/causalArtifact.ts`.
- Parse all three app governance artifact schemas:
  - `zigeffect.causal.app-remediation-audit.v1`
  - `zigeffect.causal.app-policy-decision.v1`
  - `zigeffect.causal.app-patch-proposal.v1`
- Render app remediation details inside the existing Chain tab in
  `packages/zigeffect/workbench/src/App.tsx`.
- Add local sample artifacts and bridge query strings:
  - `?sample=app-audit`
  - `?sample=app-policy`
  - `?sample=app-proposal`
- Keep the UI read-only and bounded; no editing, applying, approval, registry,
  config, migration, or rollback actions are introduced.
- Update README, agent docs, and the master roadmap so M8 workbench rendering is
  marked delivered and the next branch is the human-review boundary for
  high-risk app gates.

## Non-Goals

- No React rewrite. The workbench remains SolidJS.
- No replacement of the Zig WebUI launcher.
- No file opening, source editing, mutation, approval, migration execution, or
  rollback execution.
- No new durable backend, no Cockroach adapter work, and no NenDB work in this
  UI slice.
- No attempt to load linked artifacts recursively. Linked JSON paths are shown
  as copyable `zig build causal-workbench -- <path>` commands.

## Model Design

Add these exported types:

```ts
export type AppRemediationArtifactKind =
  | "app-remediation-audit"
  | "app-policy-decision"
  | "app-patch-proposal";

export type AppIncidentModel = {
  action: string;
  eventId: string;
  eventKind: string;
  label: string;
  subsystem: string;
  fixCategory: string;
  policyGate: string;
  queryCommands: string[];
};

export type AppGateResultModel = {
  gate: string;
  status: string;
  detail: string;
};

export type AppCitationGroup = {
  label: string;
  values: string[];
};

export type AppRemediationModel = {
  artifactPath: string;
  schema: string;
  schemaVersion: string;
  kind: AppRemediationArtifactKind;
  mode: string;
  target: string;
  summary: string;
  decision: string;
  proposalStatus: string;
  approvalStatus: string;
  approved: boolean | null;
  applied: boolean | null;
  mutationAuthority: string | null;
  sourceSteps: ChainSourceStep[];
  incidents: AppIncidentModel[];
  policyGates: string[];
  gateResults: AppGateResultModel[];
  citations: AppCitationGroup[];
  eventIds: string[];
  verificationCommands: string[];
  guardrails: string[];
  warnings: string[];
};
```

Add:

```ts
export function deriveAppRemediationModel(
  raw: unknown,
  options: WorkbenchOptions,
): AppRemediationModel | null;
```

`deriveGovernanceModel` should include `app: AppRemediationModel | null` so the
Chain tab can choose between core audit-chain rendering and app remediation
rendering without reparsing.

### Artifact Field Mapping

For app remediation audits:

- `incidents[]` becomes incident rows.
- `policy_gates[]` becomes gate chips.
- `verification_commands[]` becomes copyable verification commands.
- `claim_guardrails[]` becomes guardrails.
- `source.app_artifact` and `source.advice` become source steps.

For app policy decisions:

- `decision`, `approval_status`, `applied`, and `mutation_authority` become
  status metrics.
- `policy_gates[]` and `gate_results[]` become gate panels.
- `required_verification_commands[]` becomes verification commands.
- `guardrails[]` becomes guardrails.
- `source.app_remediation_audit` and `source.app_artifact` become source steps.

For app patch proposals:

- `proposal_status`, `approval_status`, `approved`, `applied`, and
  `mutation_authority` become status metrics.
- `policy_gates[]` becomes gate chips.
- `citations.source_files`, `config_keys`, `migration_files`, `runbooks`, and
  `rollback_plans` become citation groups.
- `required_verification_commands[]`, `claim_guardrails[]`, and
  `proposal_guardrails[]` become verification/guardrail panels.
- `source.policy`, `source.app_remediation_audit`, and `source.app_artifact`
  become source steps.

The model must tolerate partial artifacts by using `"unknown"`, empty lists,
and warnings rather than throwing from the UI.

## UI Design

Extend the existing Chain tab:

```tsx
<Show when={governance().app} fallback={...existing chain summary...}>
  {(app) => <AppRemediationView app={app()} ... />}
</Show>
```

The app view should include:

- Status strip: target, kind, decision or proposal status, approval, applied,
  authority.
- Source artifacts panel: same copy command pattern as Chain source rows.
- Policy gates panel: gate chips and gate result details.
- Incidents panel: rows for event id, action, gate, subsystem, fix category,
  label, and query commands.
- Citations panel: source files, config keys, migrations, runbooks, rollback
  plans; hide empty groups through an empty-state message.
- Verification panel: copyable commands from the artifact.
- Guardrails panel: combined claim/policy/proposal guardrails.
- Warning panel: partial-artifact warnings.

Event ids inside incident rows should be buttons when an event with that id is
loaded in the same artifact. When the current artifact is governance-only and
contains no runtime events, event ids are displayed as inert chips.

## Samples

Add these public samples:

- `sample-app-remediation-audit.json`
- `sample-app-policy-decision.json`
- `sample-app-patch-proposal.json`

Extend `workbenchBridge.ts` sample routing:

```text
?sample=app-audit -> sample-app-remediation-audit.json
?sample=app-policy -> sample-app-policy-decision.json
?sample=app-proposal -> sample-app-patch-proposal.json
```

These samples should be small, realistic, redacted, and non-mutating.

## Testing

Use TDD:

- `causalArtifact.test.ts` for pure model parsing:
  - app audit incidents/gates/query commands;
  - app policy decision gate results/source links;
  - app patch proposal citations/guardrails;
  - partial artifact warnings.
- `workbenchBridge.test.ts` for sample routing.
- Existing workbench test/typecheck/build commands:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
```

Full branch verification:

```sh
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
bun run check
bun run zig:test
git diff --check
```

## Roadmap Impact

After this branch, M8 should say app remediation audits, app policy gate
decisions, app patch proposals, and app remediation workbench rendering are
delivered. The next recommended branch should be:

```text
codex/zigeffect-app-human-review-boundary
```

That branch should define how high-risk app gates can move from
`needs-human-review` into reviewable proposal artifacts without granting
automatic mutation authority.

## Self-Review

- No placeholders remain.
- The design preserves the read-only app remediation boundary.
- The chosen UI path remains SolidJS plus `zig-webui`.
- The scope is focused on workbench model, UI rendering, samples, and docs.
- High-risk app gate human review remains a future branch, not hidden UI
  behavior in this one.
