# zigeffect App Remediation Workbench Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render app remediation audit, app policy decision, and app patch proposal details directly in the read-only SolidJS/`zig-webui` causal workbench.

**Architecture:** Keep artifact interpretation in pure TypeScript helpers under `causalArtifact.ts`, then render the derived model from the existing Chain tab in `App.tsx`. Add local sample artifacts and bridge sample routing, leaving the Zig WebUI bridge and causal artifact schemas unchanged.

**Tech Stack:** Bun, SolidJS, TypeScript, Vite, existing Zig WebUI launcher, existing zigeffect causal app remediation artifacts.

---

## File Structure

- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
  - Add app remediation model types and `deriveAppRemediationModel`.
  - Add `app: AppRemediationModel | null` to `GovernanceModel`.
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
  - Add app audit, policy, proposal, and partial-artifact model tests.
- Modify: `packages/zigeffect/workbench/src/App.tsx`
  - Render app remediation details from the Chain tab.
- Modify: `packages/zigeffect/workbench/src/styles.css`
  - Add responsive app remediation panels, rows, gate chips, and citation groups.
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.ts`
  - Add `?sample=app-audit`, `?sample=app-policy`, and `?sample=app-proposal`.
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.test.ts`
  - Add sample-routing tests.
- Create: `packages/zigeffect/workbench/public/sample-app-remediation-audit.json`
  - Local sample audit.
- Create: `packages/zigeffect/workbench/public/sample-app-policy-decision.json`
  - Local sample policy decision.
- Create: `packages/zigeffect/workbench/public/sample-app-patch-proposal.json`
  - Local sample proposal with citations.
- Modify: `packages/zigeffect/README.md`
  - Document app remediation workbench rendering.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Explain app artifact inspection flow.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark app remediation workbench rendering delivered and advance queue.

## Task 1: Pure App Remediation Model

**Files:**
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`

- [ ] **Step 1: Add failing model tests**

In `causalArtifact.test.ts`, import `deriveAppRemediationModel` and add fixtures:

```ts
const sampleAppAudit = {
  schema: "zigeffect.causal.app-remediation-audit.v1",
  schema_version: 1,
  mode: "local",
  target: "yachdee-platform",
  source: {
    app_artifact: ".zig-cache/causal-artifacts/app.json",
    advice: ".zig-cache/causal-artifacts/app-advice.txt",
  },
  approval_status: "pending",
  applied: false,
  mutation_authority: "none",
  incident_count: 2,
  incidents: [
    {
      action: "fix-app-config",
      event_id: 2,
      event_kind: "assertion_recorded",
      label: "YACHDEE_ENV",
      subsystem: "app_config",
      fix_category: "config-or-secret-binding",
      policy_gate: "config-only",
      query_commands: ["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"],
    },
    {
      action: "wire-app-requirement",
      event_id: 3,
      event_kind: "assertion_recorded",
      label: "HealthService",
      subsystem: "app_service_layer",
      fix_category: "service-provider-or-layer",
      policy_gate: "source-only",
      query_commands: ["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 3"],
    },
  ],
  policy_gates: ["config-only", "source-only"],
  verification_commands: ["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"],
  claim_guardrails: ["Do not claim an app fix without rerunning the app request/job scenario."],
};
```

Add tests:

```ts
test("deriveAppRemediationModel reads app audit incidents and gates", () => {
  const app = deriveAppRemediationModel(sampleAppAudit, { artifactPath: "app-audit.json" });

  expect(app?.kind).toBe("app-remediation-audit");
  expect(app?.target).toBe("yachdee-platform");
  expect(app?.incidents.map((incident) => incident.eventId)).toEqual(["2", "3"]);
  expect(app?.incidents[0]?.policyGate).toBe("config-only");
  expect(app?.policyGates).toEqual(["config-only", "source-only"]);
  expect(app?.verificationCommands).toEqual(["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"]);
  expect(app?.guardrails).toContain("Do not claim an app fix without rerunning the app request/job scenario.");
  expect(app?.sourceSteps.map((step) => step.label)).toEqual(["App artifact", "Advice"]);
});

test("deriveGovernanceModel attaches app remediation details", () => {
  const governance = deriveGovernanceModel(sampleAppAudit, { artifactPath: "app-audit.json" });

  expect(governance?.app?.incidents.length).toBe(2);
  expect(governance?.app?.sourceSteps[0]?.workbenchCommand).toBe("zig build causal-workbench -- .zig-cache/causal-artifacts/app.json");
});
```

- [ ] **Step 2: Run and confirm RED**

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: FAIL because `deriveAppRemediationModel` and `GovernanceModel.app`
do not exist yet.

- [ ] **Step 3: Implement the app model types and audit parsing**

Add exported types:

```ts
export type AppRemediationArtifactKind = "app-remediation-audit" | "app-policy-decision" | "app-patch-proposal";

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
export function deriveAppRemediationModel(raw: unknown, options: WorkbenchOptions): AppRemediationModel | null
```

For the first green pass, support app audit source steps:

```ts
const sourceSteps = [
  appSourceStep("app_artifact", "App artifact", source),
  appSourceStep("advice", "Advice", source),
].filter((step): step is ChainSourceStep => step !== null);
```

Add `app: deriveAppRemediationModel(raw, options)` to `GovernanceModel`.

- [ ] **Step 4: Run and confirm GREEN**

Run:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
```

Expected: PASS.

## Task 2: Policy Decision and Proposal Model Coverage

**Files:**
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`

- [ ] **Step 1: Add failing tests for policy and proposal details**

Add `sampleAppPolicy` with:

```ts
gate_results: [
  { gate: "config-only", status: "allow-proposal", detail: "configuration proposal may be drafted without exposing secrets" },
  { gate: "source-only", status: "allow-proposal", detail: "source-only app patch proposal may be drafted" },
]
```

Assert:

```ts
expect(app?.decision).toBe("approve");
expect(app?.gateResults.map((gate) => `${gate.gate}:${gate.status}`)).toEqual([
  "config-only:allow-proposal",
  "source-only:allow-proposal",
]);
expect(app?.sourceSteps.map((step) => step.label)).toEqual(["App remediation audit", "App artifact"]);
expect(app?.verificationCommands).toContain("zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2");
```

Add `sampleAppProposal` with citations:

```ts
citations: {
  source_files: ["apps/platform/src/worker.ts"],
  config_keys: ["YACHDEE_ENV"],
  migration_files: [],
  runbooks: ["docs/runbooks/yachdee-config.md"],
  rollback_plans: ["docs/runbooks/yachdee-rollback.md"],
}
```

Assert:

```ts
expect(app?.proposalStatus).toBe("draft");
expect(app?.citations.map((group) => `${group.label}:${group.values.length}`)).toEqual([
  "Source files:1",
  "Config keys:1",
  "Migration files:0",
  "Runbooks:1",
  "Rollback plans:1",
]);
expect(app?.guardrails).toContain("Config citations name keys or bindings only; never include secret values.");
```

- [ ] **Step 2: Run and confirm RED**

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: FAIL until policy gate results, proposal citations, and source step
mapping are implemented.

- [ ] **Step 3: Implement policy/proposal mapping**

Extend `deriveAppRemediationModel` with:

- policy source step labels:
  - `app_remediation_audit` -> `App remediation audit`
  - `app_artifact` -> `App artifact`
- proposal source step labels:
  - `policy` -> `App policy decision`
  - `app_remediation_audit` -> `App remediation audit`
  - `app_artifact` -> `App artifact`
- `gateResults` from `gate_results[]`.
- `citations` from all five known citation arrays.
- `verificationCommands` from either `verification_commands` or
  `required_verification_commands`.
- `guardrails` from `claim_guardrails`, `guardrails`, and
  `proposal_guardrails`.

- [ ] **Step 4: Run and confirm GREEN**

Run:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
```

Expected: PASS.

## Task 3: Sample Artifacts and Bridge Routing

**Files:**
- Create: `packages/zigeffect/workbench/public/sample-app-remediation-audit.json`
- Create: `packages/zigeffect/workbench/public/sample-app-policy-decision.json`
- Create: `packages/zigeffect/workbench/public/sample-app-patch-proposal.json`
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.ts`
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.test.ts`

- [ ] **Step 1: Add failing sample routing test**

Append:

```ts
test("loadPayloadFromBridge can load app remediation development samples", async () => {
  const samples: Array<[string, string]> = [
    ["?sample=app-audit", "sample-app-remediation-audit.json"],
    ["?sample=app-policy", "sample-app-policy-decision.json"],
    ["?sample=app-proposal", "sample-app-patch-proposal.json"],
  ];

  for (const [search, expected] of samples) {
    const payload = await loadPayloadFromBridge(
      {},
      async (sampleName) => JSON.stringify({ schema: sampleName }),
      search,
    );

    expect(payload.artifactJson).toBe(JSON.stringify({ schema: expected }));
    expect(payload.session?.artifact_path).toBe(expected);
  }
});
```

- [ ] **Step 2: Run and confirm RED**

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: FAIL because every app sample still routes to `sample-artifact.json`.

- [ ] **Step 3: Add sample JSON files and bridge mapping**

Update `sampleNameFromSearch`:

```ts
const sample = params.get("sample");
if (sample === "chain") return "sample-chain-artifact.json";
if (sample === "app-audit") return "sample-app-remediation-audit.json";
if (sample === "app-policy") return "sample-app-policy-decision.json";
if (sample === "app-proposal") return "sample-app-patch-proposal.json";
return "sample-artifact.json";
```

Create the three sample JSON files using the fixtures from Tasks 1 and 2.

- [ ] **Step 4: Run and confirm GREEN**

Run:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:build
```

Expected: PASS and Vite includes the sample assets.

## Task 4: Chain Tab App Remediation Rendering

**Files:**
- Modify: `packages/zigeffect/workbench/src/App.tsx`
- Modify: `packages/zigeffect/workbench/src/styles.css`

- [ ] **Step 1: Add app view components**

Import app model types:

```ts
type AppRemediationModel,
type AppIncidentModel,
type AppGateResultModel,
type AppCitationGroup,
```

Change `ChainView` to accept:

```ts
events: CausalEvent[];
onSelectEvent: (id: string) => void;
```

When calling it:

```tsx
<ChainView
  governance={governance()}
  events={current().events}
  copiedCommand={copiedCommand()}
  onCopy={copyCommand}
  onSelectEvent={setSelectedId}
/>
```

Render app details before the core audit-chain fallback:

```tsx
<Show when={governance().app} fallback={...existing chain rendering...}>
  {(app) => (
    <AppRemediationView
      app={app()}
      events={props.events}
      copiedCommand={props.copiedCommand}
      onCopy={props.onCopy}
      onSelectEvent={props.onSelectEvent}
    />
  )}
</Show>
```

Add components:

- `AppRemediationView`
- `AppRemediationStatus`
- `AppPolicyGates`
- `AppIncidents`
- `AppCitations`
- `AppVerification`
- `AppGuardrails`

Use existing `Metric`, `CommandList`, `ChainSources`, and `EmptyState` helpers.

- [ ] **Step 2: Add CSS**

Add classes:

```css
.app-remediation-grid
.app-remediation-full
.app-incident-list
.app-incident-row
.app-event-button
.gate-chip-list
.gate-chip
.gate-chip.allow
.gate-chip.review
.gate-chip.blocked
.gate-result-list
.citation-grid
.citation-group
.citation-group code
```

Keep grids responsive with `minmax(0, 1fr)` and use the current border radius,
colors, and typography scale.

- [ ] **Step 3: Run UI checks**

Run:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
```

Expected: PASS.

## Task 5: Documentation and Roadmap

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update workbench docs**

In README and agent guide, state that the Chain tab renders:

- app incidents;
- app policy gate results;
- app patch proposal citations;
- verification commands;
- guardrails;
- source artifact workbench commands.

Keep the read-only warning explicit.

- [ ] **Step 2: Update roadmap queue**

Change M8 status to:

```text
app remediation audit artifacts, app policy gate decisions, draft app patch proposal artifacts, and detailed SolidJS workbench rendering exist
```

Set next branch to:

```text
codex/zigeffect-app-human-review-boundary
```

- [ ] **Step 3: Run stale text checks**

Run:

```sh
rg -n "detailed workbench rendering remains|move to app remediation workbench" docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md packages/zigeffect
git diff --check
```

Expected: no stale roadmap text and no whitespace errors.

## Task 6: Full Verification and Commit

**Files:**
- All files changed above.

- [ ] **Step 1: Run full verification**

Run:

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

Expected: all commands pass.

- [ ] **Step 2: Review status**

Run:

```sh
git status --short
```

Expected: only intended app-remediation workbench files plus the pre-existing
untracked durable workflows roadmap.

- [ ] **Step 3: Commit implementation**

Run:

```sh
git add packages/zigeffect/workbench/src/causalArtifact.ts \
  packages/zigeffect/workbench/src/causalArtifact.test.ts \
  packages/zigeffect/workbench/src/App.tsx \
  packages/zigeffect/workbench/src/styles.css \
  packages/zigeffect/workbench/src/workbenchBridge.ts \
  packages/zigeffect/workbench/src/workbenchBridge.test.ts \
  packages/zigeffect/workbench/public/sample-app-remediation-audit.json \
  packages/zigeffect/workbench/public/sample-app-policy-decision.json \
  packages/zigeffect/workbench/public/sample-app-patch-proposal.json \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/agent-guide.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md

git commit -m "feat(zigeffect): render app remediation workbench details"
```

Expected: commit succeeds and the next roadmap branch is ready.
