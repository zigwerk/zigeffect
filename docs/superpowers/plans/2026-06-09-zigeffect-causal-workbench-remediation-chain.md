# zigeffect Causal Workbench Remediation Chain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only Chain tab that lets the SolidJS/Zig WebUI workbench inspect remediation and governance chain artifacts.

**Architecture:** Keep artifact interpretation in pure TypeScript model helpers under `causalArtifact.ts`, then render those helpers from `App.tsx`. The Zig bridge remains a single bounded payload loader in this slice; linked artifacts are shown as source-path entry points and copyable workbench commands.

**Tech Stack:** Bun, SolidJS, TypeScript, Vite, Zig WebUI launcher already present.

---

## Files

- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
  - Add governance/remediation chain model types and pure derivation helpers.
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
  - Add tests for supported schemas, chain source paths, event classifications,
    guardrails, verification commands, and partial artifact tolerance.
- Modify: `packages/zigeffect/workbench/src/App.tsx`
  - Add Chain tab rendering and copyable source artifact commands.
- Modify: `packages/zigeffect/workbench/src/styles.css`
  - Add responsive styling for chain status, source path rows,
    classification columns, verification commands, and guardrails.
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.ts`
  - Let local development load `sample-chain-artifact.json` when
    `?sample=chain` is present.
- Create: `packages/zigeffect/workbench/public/sample-chain-artifact.json`
  - Browser-verifiable sample audit-chain artifact.
- Modify: `packages/zigeffect/README.md`
  - Mention launching the workbench on audit-chain/governance artifacts.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Update M6 evidence and next action after the branch lands.

## Task 1: Pure Governance Model

**Files:**
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`

- [ ] **Step 1: Write failing tests**

Add imports:

```ts
import {
  deriveGovernanceModel,
  deriveRemediationChainModel,
} from "./causalArtifact";
```

Add this sample object near `sampleArtifact`:

```ts
const sampleAuditChain = {
  schema: "zigeffect.causal.audit-chain.v1",
  schema_version: 1,
  mode: "local",
  target: "package-tests",
  assessment: "unchanged",
  source: {
    session: ".zig-cache/causal-artifacts/zigeffect-causal-dev-session-package-tests.json",
    audit: ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-remediation-audit.json",
    decision: ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-remediation-decision.json",
    proposal: ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-patch-proposal.json",
    before: ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-before.json",
    after: ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-after.json",
    compare: ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-compare.txt",
  },
  proposal_status: "ready-for-review",
  approval_status: "approved",
  approved: true,
  applied: false,
  finding_delta: 0,
  event_ids: [1, 2, 3, 5],
  disappeared_event_ids: [1],
  persisting_event_ids: [2],
  appeared_event_ids: [3],
  missing_event_ids: [5],
  verification_commands: ["zig build examples", "zig build test --summary none"],
  claim_guardrails: ["Do not claim remediation without verification."],
  proposal_guardrails: ["This proposal does not apply source changes."],
  chain_guardrails: ["Chain comparison is evidence, not authorization to edit source."],
};
```

Add tests:

```ts
test("deriveRemediationChainModel normalizes audit-chain evidence", () => {
  const chain = deriveRemediationChainModel(sampleAuditChain, {
    artifactPath: ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-audit-chain.json",
  });

  expect(chain).toBeDefined();
  expect(chain?.schema).toBe("zigeffect.causal.audit-chain.v1");
  expect(chain?.target).toBe("package-tests");
  expect(chain?.assessment).toBe("unchanged");
  expect(chain?.approvalStatus).toBe("approved");
  expect(chain?.applied).toBe(false);
  expect(chain?.sourceSteps.map((step) => step.kind)).toEqual([
    "session",
    "audit",
    "decision",
    "proposal",
    "before",
    "after",
    "compare",
  ]);
  expect(chain?.classifications.persisting).toEqual(["2"]);
  expect(chain?.verificationCommands).toEqual(["zig build examples", "zig build test --summary none"]);
  expect(chain?.guardrails).toContain("Chain comparison is evidence, not authorization to edit source.");
});

test("deriveGovernanceModel detects supported governance artifacts", () => {
  const governance = deriveGovernanceModel(sampleAuditChain, { artifactPath: "chain.json" });

  expect(governance?.kind).toBe("audit-chain");
  expect(governance?.summary).toContain("package-tests");
});

test("deriveRemediationChainModel tolerates partial chain artifacts", () => {
  const chain = deriveRemediationChainModel({
    schema: "zigeffect.causal.audit-chain.v1",
    source: { before: "before.json" },
  }, { artifactPath: "partial-chain.json" });

  expect(chain?.target).toBe("unknown");
  expect(chain?.sourceSteps.map((step) => step.kind)).toEqual(["before"]);
  expect(chain?.warnings).toContain("artifact schema_version is missing");
  expect(chain?.classifications.disappeared).toEqual([]);
});
```

- [ ] **Step 2: Run tests to verify red**

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: fail because `deriveGovernanceModel` and
`deriveRemediationChainModel` do not exist.

- [ ] **Step 3: Implement minimal model**

Add exported types:

```ts
export type GovernanceArtifactKind =
  | "audit-chain"
  | "remediation-audit"
  | "remediation-decision"
  | "patch-proposal"
  | "registry-readiness"
  | "registry-application"
  | "policy-decision";

export type ChainSourceKind = "session" | "audit" | "decision" | "proposal" | "before" | "after" | "compare";

export type ChainSourceStep = {
  kind: ChainSourceKind;
  label: string;
  path: string;
  workbenchCommand: string | null;
};

export type EventClassifications = {
  eventIds: string[];
  disappeared: string[];
  persisting: string[];
  appeared: string[];
  missing: string[];
};

export type RemediationChainModel = {
  artifactPath: string;
  schema: string;
  schemaVersion: string;
  kind: "audit-chain";
  mode: string;
  target: string;
  assessment: string;
  proposalStatus: string;
  approvalStatus: string;
  approved: boolean | null;
  applied: boolean | null;
  findingDelta: string;
  sourceSteps: ChainSourceStep[];
  classifications: EventClassifications;
  verificationCommands: string[];
  guardrails: string[];
  warnings: string[];
};

export type GovernanceModel = {
  artifactPath: string;
  schema: string;
  schemaVersion: string;
  kind: GovernanceArtifactKind;
  target: string;
  summary: string;
  applied: boolean | null;
  mutationAuthority: string | null;
  chain: RemediationChainModel | null;
  warnings: string[];
};
```

Implement:

- `deriveRemediationChainModel(raw, options)`;
- `deriveGovernanceModel(raw, options)`;
- `chainSourceSteps(source)`;
- `eventIdList(value)`;
- `stringList(value)`;
- schema-to-kind mapping for supported governance schemas.

Generate workbench commands only for JSON paths:

```ts
path.endsWith(".json") ? `zig build causal-workbench -- ${path}` : null
```

- [ ] **Step 4: Run focused tests to verify green**

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: all workbench tests pass.

- [ ] **Step 5: Commit**

```sh
git add packages/zigeffect/workbench/src/causalArtifact.ts packages/zigeffect/workbench/src/causalArtifact.test.ts
git commit -m "feat(zigeffect): derive workbench remediation chain model"
```

## Task 2: Chain Sample And Local Loader

**Files:**
- Create: `packages/zigeffect/workbench/public/sample-chain-artifact.json`
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.ts`
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.test.ts`

- [ ] **Step 1: Write failing bridge test**

Add a test that installs a fake `location.search` and asserts the chain sample
path is requested:

```ts
test("loadPayloadFromBridge can load the chain development sample", async () => {
  const payload = await loadPayloadFromBridge(
    {},
    async (sampleName) => JSON.stringify({ schema: sampleName }),
    "?sample=chain",
  );

  expect(payload.artifactJson).toBe(JSON.stringify({ schema: "sample-chain-artifact.json" }));
  expect(payload.session?.artifact_path).toBe("sample-chain-artifact.json");
});
```

- [ ] **Step 2: Run test to verify red**

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: fail because the sample loader does not accept a sample name or query
string.

- [ ] **Step 3: Implement loader support**

Change:

```ts
type SampleArtifactLoader = () => Promise<string>;
```

to:

```ts
type SampleArtifactLoader = (sampleName: string) => Promise<string>;
```

Change `loadPayloadFromBridge` to accept a third argument:

```ts
export async function loadPayloadFromBridge(
  bridge: BridgeWindow,
  loadSample: SampleArtifactLoader = loadSampleArtifact,
  search = window.location.search,
): Promise<LoadedPayload> {
  const sampleName = sampleNameFromSearch(search);
  ...
  artifactJson: await loadSample(sampleName),
  session: session ?? {
    schema: "zigeffect.causal.workbench-session.v1",
    artifact_path: sampleName,
    read_only: true,
    warnings: ["development sample artifact"],
  },
}
```

Add:

```ts
function sampleNameFromSearch(search: string): string {
  const params = new URLSearchParams(search);
  return params.get("sample") === "chain" ? "sample-chain-artifact.json" : "sample-artifact.json";
}

async function loadSampleArtifact(sampleName: string): Promise<string> {
  const response = await fetch(`./${sampleName}`);
  return response.text();
}
```

Create `sample-chain-artifact.json` with the same fields as `sampleAuditChain`
from Task 1.

- [ ] **Step 4: Run focused tests**

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: all workbench tests pass.

- [ ] **Step 5: Commit**

```sh
git add packages/zigeffect/workbench/public/sample-chain-artifact.json packages/zigeffect/workbench/src/workbenchBridge.ts packages/zigeffect/workbench/src/workbenchBridge.test.ts
git commit -m "feat(zigeffect): add remediation chain workbench sample"
```

## Task 3: Chain Tab UI

**Files:**
- Modify: `packages/zigeffect/workbench/src/App.tsx`
- Modify: `packages/zigeffect/workbench/src/styles.css`

- [ ] **Step 1: Add model assertions that support UI fields**

Extend the Task 1 chain model test with:

```ts
expect(chain?.sourceSteps.find((step) => step.kind === "before")?.workbenchCommand).toBe(
  "zig build causal-workbench -- .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-before.json",
);
expect(chain?.guardrails.length).toBe(3);
expect(chain?.classifications.eventIds).toEqual(["1", "2", "3", "5"]);
```

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: fail if source commands, combined guardrails, or event id strings are
not implemented.

- [ ] **Step 2: Render Chain tab**

In `App.tsx`:

- add `{ id: "chain", label: "Chain" }` to `tabs`;
- derive `governanceModel` from the loaded raw artifact:

```ts
governance: deriveGovernanceModel(raw, { artifactPath }),
```

- render:

```tsx
<Match when={activeTab() === "chain"}>
  <ChainView governance={current().governance} copiedCommand={copiedCommand()} onCopy={copyCommand} />
</Match>
```

Add `ChainView`, `ChainStatusStrip`, `ChainSources`, `ChainClassifications`,
`ChainVerification`, and `ChainGuardrails` components. Use existing `Metric`,
`CommandList`, and `EmptyState` helpers where they fit.

- [ ] **Step 3: Add responsive styles**

Add classes:

- `.chain-status`
- `.chain-grid`
- `.chain-panel`
- `.chain-source-row`
- `.chain-classification-grid`
- `.chain-id-list`
- `.guardrail-list`

At mobile width, collapse `.chain-status`, `.chain-grid`, and
`.chain-classification-grid` to one column.

- [ ] **Step 4: Run focused checks**

Run:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
```

Expected: all pass.

- [ ] **Step 5: Browser verify chain sample**

Run:

```sh
bun run zigeffect:workbench:dev -- --port 5179
```

Open `http://127.0.0.1:5179/?sample=chain`, switch to Chain, and verify:

- status strip shows `unchanged`, `approved`, and `false`;
- source rows include before/after/compare/audit/decision/proposal;
- event classification lists show `1`, `2`, `3`, and `5` in their respective
  groups;
- mobile viewport has no horizontal overflow;
- browser console has no errors.

- [ ] **Step 6: Commit**

```sh
git add packages/zigeffect/workbench/src/App.tsx packages/zigeffect/workbench/src/styles.css
git commit -m "feat(zigeffect): render remediation chain workbench tab"
```

## Task 4: Docs And Final Verification

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-09-zigeffect-causal-workbench-remediation-chain-design.md`
- Modify: `docs/superpowers/plans/2026-06-09-zigeffect-causal-workbench-remediation-chain.md`

- [ ] **Step 1: Update README and roadmap**

Add README text near the workbench command:

```md
The Chain tab also recognizes remediation/governance artifacts such as
`zigeffect.causal.audit-chain.v1`, showing source artifact paths, evidence id
classifications, verification commands, and guardrails while remaining
read-only.
```

Update M6 in the master roadmap to say the graph and chain workbench branches
exist and the next branch is app-facing runtime.

- [ ] **Step 2: Run full verification**

Run:

```sh
bun run check
bun run zig:test
git diff --check
```

Expected:

- `bun run check` passes;
- `bun run zig:test` passes;
- `git diff --check` exits zero.

- [ ] **Step 3: Commit**

```sh
git add packages/zigeffect/README.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md docs/superpowers/specs/2026-06-09-zigeffect-causal-workbench-remediation-chain-design.md docs/superpowers/plans/2026-06-09-zigeffect-causal-workbench-remediation-chain.md
git commit -m "docs(zigeffect): document remediation chain workbench"
```

## Self-Review

- Spec coverage: the plan covers read-only chain parsing, local sample loading,
  Chain tab rendering, browser/mobile verification, and roadmap docs.
- Placeholder scan: no placeholder markers are present.
- Scope check: companion artifact loading is intentionally out of this branch
  because the current Zig WebUI bridge is a single bounded artifact payload.
