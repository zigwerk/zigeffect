# Production Telemetry Workbench Read-Only Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a read-only SolidJS/webui workbench preview for production telemetry NenDB retention fixture artifacts and emit a record-only preview contract artifact.

**Architecture:** Add a typed workbench model for `zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1`, render it in a new Telemetry tab, and add a small Zig contract tool that verifies ready retention evidence before handing off to CI artifact preview. The UI remains local/read-only; the Zig tool records review evidence and never writes NenDB or durable state.

**Tech Stack:** Zig 0.16 build tools, Bun, `bun:test`, SolidJS, `webui-dev/zig-webui`, existing zigeffect workbench TypeScript.

---

## Files

- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.ts`
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.test.ts`
- Modify: `packages/zigeffect/workbench/src/App.tsx`
- Modify: `packages/zigeffect/workbench/src/styles.css`
- Add: `packages/zigeffect/workbench/public/sample-production-telemetry-nendb-retention-fixtures.json`
- Add: `packages/zigeffect/tools/causal_production_telemetry_workbench_readonly_preview.zig`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Add: `packages/zigeffect/docs/production-telemetry-workbench-readonly-preview.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/production-hardening-completion-audit.md`
- Modify: `packages/zigeffect/docs/production-telemetry-nendb-retention-fixtures.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

---

### Task 1: Workbench Parser Model

**Files:**
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`

- [ ] **Step 1: Write failing parser tests**

Add tests near the governance tests:

```ts
test("deriveProductionTelemetryPreviewModel reads ready NenDB retention fixtures", () => {
  const preview = deriveProductionTelemetryPreviewModel(sampleProductionTelemetryRetention, {
    artifactPath: "retention.json",
  });

  expect(preview?.schema).toBe("zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1");
  expect(preview?.status).toBe("ready");
  expect(preview?.readyForNextBranch).toBe(true);
  expect(preview?.authority.nendbWriteEnabled).toBe(false);
  expect(preview?.authority.durableWriteEnabled).toBe(false);
  expect(preview?.sources.map((source) => source.kind)).toEqual([
    "local-pipeline",
    "boundary",
    "proposal",
    "readiness",
    "fixtures",
  ]);
  expect(preview?.mappingFixtures.map((fixture) => fixture.id)).toContain("nendb-runtime-event-node-fixture");
  expect(preview?.mappingFixtures[0]?.retainedFields).toContain("event_id_ref");
  expect(preview?.validationChecks).toContain("nendb-write-disabled");
  expect(preview?.verificationCommands).toContain("zig build causal-production-telemetry-local-pipeline-fixtures");
  expect(preview?.nextBranch).toBe("codex/zigeffect-causal-production-telemetry-workbench-readonly-preview");
});

test("deriveProductionTelemetryPreviewModel reads blocked retention fixtures", () => {
  const preview = deriveProductionTelemetryPreviewModel({
    ...sampleProductionTelemetryRetention,
    decision: "reject",
    retention_fixture_status: "blocked",
    ready_for_next_branch: false,
    checks: [{ name: "decision-approved", status: "fail", detail: "reviewer rejected" }],
  }, { artifactPath: "blocked-retention.json" });

  expect(preview?.status).toBe("blocked");
  expect(preview?.readyForNextBranch).toBe(false);
  expect(preview?.checks[0]).toEqual({ name: "decision-approved", status: "fail", detail: "reviewer rejected" });
});
```

Add a `sampleProductionTelemetryRetention` constant with the schema, source paths, authority flags, one mapping fixture, checks, validation checks, blocked claims, required commands, verified commands, and next branch from the NenDB retention artifact.

- [ ] **Step 2: Verify tests fail**

Run:

```sh
bun test --timeout 30000 packages/zigeffect/workbench/src/causalArtifact.test.ts
```

Expected: fail because `deriveProductionTelemetryPreviewModel` is not exported.

- [ ] **Step 3: Implement parser types and helpers**

In `causalArtifact.ts`, add:

```ts
export type ProductionTelemetryMappingFixture = {
  id: string;
  sourceEnvelope: string;
  targetSchema: string;
  label: string;
  retainedFields: string[];
  blockedFields: string[];
};

export type ProductionTelemetryCheck = {
  name: string;
  status: string;
  detail: string;
};

export type ProductionTelemetryAuthority = {
  applied: boolean | null;
  mutationAuthority: string | null;
  liveTelemetryEnabled: boolean | null;
  networkSendEnabled: boolean | null;
  collectorEndpointConfigured: boolean | null;
  otlpSerializationEnabled: boolean | null;
  runtimePipelineEnabled: boolean | null;
  durableWriteEnabled: boolean | null;
  nendbWriteEnabled: boolean | null;
  ciGateEnabled: boolean | null;
};

export type ProductionTelemetryPreviewModel = {
  artifactPath: string;
  schema: string;
  schemaVersion: string;
  status: string;
  decision: string;
  readyForNextBranch: boolean | null;
  recommendation: string;
  nextBranch: string;
  sources: ChainSourceStep[];
  authority: ProductionTelemetryAuthority;
  checks: ProductionTelemetryCheck[];
  mappingFixtures: ProductionTelemetryMappingFixture[];
  validationChecks: string[];
  implementationGates: string[];
  nonGoals: string[];
  blockedClaims: string[];
  requiredCommands: string[];
  verifiedCommands: string[];
  verificationCommands: string[];
  warnings: string[];
};
```

Add `deriveProductionTelemetryPreviewModel(raw, options)` that returns `null` unless the schema is `zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1` or `zigeffect.causal.production-telemetry-workbench-readonly-preview.v1`.

- [ ] **Step 4: Run parser tests**

Run:

```sh
bun test --timeout 30000 packages/zigeffect/workbench/src/causalArtifact.test.ts
```

Expected: pass.

---

### Task 2: Workbench Sample And Bridge

**Files:**
- Add: `packages/zigeffect/workbench/public/sample-production-telemetry-nendb-retention-fixtures.json`
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.ts`
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.test.ts`

- [ ] **Step 1: Write failing bridge test**

Add:

```ts
test("loadPayloadFromBridge can load the production telemetry retention sample", async () => {
  const payload = await loadPayloadFromBridge({}, async (sampleName) => {
    expect(sampleName).toBe("sample-production-telemetry-nendb-retention-fixtures.json");
    return JSON.stringify({ schema: "zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1" });
  }, "?sample=production-telemetry");

  expect(payload.session?.artifact_path).toBe("sample-production-telemetry-nendb-retention-fixtures.json");
  expect(payload.artifactJson).toContain("production-telemetry-nendb-retention-fixtures");
});
```

- [ ] **Step 2: Verify test fails**

Run:

```sh
bun test --timeout 30000 packages/zigeffect/workbench/src/workbenchBridge.test.ts
```

Expected: fail because the sample name is not mapped.

- [ ] **Step 3: Add sample mapping and sample JSON**

Add to `sampleNameFromSearch`:

```ts
if (sample === "production-telemetry") return "sample-production-telemetry-nendb-retention-fixtures.json";
```

Create the sample JSON with representative ready retention evidence, including two mapping fixtures and the full disabled authority boundary.

- [ ] **Step 4: Run bridge and parser tests**

Run:

```sh
bun test --timeout 30000 packages/zigeffect/workbench/src/workbenchBridge.test.ts packages/zigeffect/workbench/src/causalArtifact.test.ts
```

Expected: pass.

---

### Task 3: Telemetry Tab UI

**Files:**
- Modify: `packages/zigeffect/workbench/src/App.tsx`
- Modify: `packages/zigeffect/workbench/src/styles.css`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`

- [ ] **Step 1: Write source-level UI test**

Add a small test near `visualGraphUi.test.ts` or extend that file:

```ts
test("Telemetry preview UI exposes read-only production telemetry panels", async () => {
  const source = await Bun.file("packages/zigeffect/workbench/src/App.tsx").text();

  expect(source).toContain('type Tab = "timeline"');
  expect(source).toContain('"telemetry"');
  expect(source).toContain("function ProductionTelemetryPreview");
  expect(source).toContain("function ProductionTelemetryMappings");
  expect(source).toContain("function ProductionTelemetryAuthority");
  expect(source).toContain("deriveProductionTelemetryPreviewModel");
});
```

- [ ] **Step 2: Verify test fails**

Run:

```sh
bun test --timeout 30000 packages/zigeffect/workbench/src/visualGraphUi.test.ts
```

Expected: fail because the functions/tab are absent.

- [ ] **Step 3: Wire the model and tab**

In `App.tsx`:

```ts
import {
  type ProductionTelemetryPreviewModel,
  deriveProductionTelemetryPreviewModel,
} from "./causalArtifact";
```

Add `telemetry` to `Tab` and `tabs`.

Create:

```ts
const productionTelemetry = createMemo(() => {
  const raw = parsed()?.raw;
  const current = model();
  if (!raw || !current) return null;
  return deriveProductionTelemetryPreviewModel(raw, { artifactPath: current.artifactPath });
});
```

Render `<ProductionTelemetryPreview preview={productionTelemetry()} ... />` in the tab switch.

- [ ] **Step 4: Add UI components**

Add functions in `App.tsx`:

```tsx
function ProductionTelemetryPreview(props: {
  preview: ProductionTelemetryPreviewModel | null;
  copiedCommand: string | null;
  onCopy: (command: string) => void;
}) {
  return (
    <div class="view-stack">
      <div class="view-heading">
        <h2>Telemetry</h2>
        <span>{props.preview?.status ?? "no production telemetry preview"}</span>
      </div>
      <Show when={props.preview} fallback={<EmptyState label="Loaded artifact has no production telemetry preview" />}>
        {(preview) => (
          <>
            <div class="chain-status telemetry-status">
              <Metric label="status" value={preview().status} tone={preview().status === "ready" ? "ok" : "warn"} />
              <Metric label="ready" value={String(preview().readyForNextBranch)} tone={preview().readyForNextBranch ? "ok" : "warn"} />
              <Metric label="authority" value={preview().authority.mutationAuthority ?? "none"} tone={preview().authority.mutationAuthority === "none" ? "ok" : "warn"} />
              <Metric label="next" value={preview().nextBranch} />
            </div>
            <div class="telemetry-grid">
              <ChainSources steps={preview().sources} copiedCommand={props.copiedCommand} onCopy={props.onCopy} />
              <ProductionTelemetryAuthority authority={preview().authority} />
            </div>
            <ProductionTelemetryMappings fixtures={preview().mappingFixtures} />
            <div class="telemetry-grid">
              <ProductionTelemetryChecks title="Checks" checks={preview().checks.map((check) => `${check.status}: ${check.name} - ${check.detail}`)} />
              <ProductionTelemetryChecks title="Validation" checks={preview().validationChecks} />
            </div>
            <CommandList commands={preview().verificationCommands.map((command) => ({ label: "Verify", command }))} copiedCommand={props.copiedCommand} onCopy={props.onCopy} />
            <ProductionTelemetryChecks title="Blocked claims" checks={preview().blockedClaims} />
          </>
        )}
      </Show>
    </div>
  );
}

function ProductionTelemetryMappings(props: { fixtures: ProductionTelemetryPreviewModel["mappingFixtures"] }) {
  return (
    <section class="telemetry-panel">
      <div class="lane-section-head">
        <h3>NenDB mapping fixtures</h3>
        <span>{props.fixtures.length}</span>
      </div>
      <div class="telemetry-map-list">
        <For each={props.fixtures} fallback={<EmptyState label="No mapping fixtures" compact />}>
          {(fixture) => (
            <div class="telemetry-map-row">
              <strong>{fixture.id}</strong>
              <code>{fixture.sourceEnvelope} -> {fixture.targetSchema}</code>
              <span>{fixture.label}</span>
              <div class="telemetry-field-list">
                <For each={fixture.retainedFields}>{(field) => <span>{field}</span>}</For>
              </div>
              <div class="telemetry-field-list blocked">
                <For each={fixture.blockedFields}>{(field) => <span>{field}</span>}</For>
              </div>
            </div>
          )}
        </For>
      </div>
    </section>
  );
}

function ProductionTelemetryAuthority(props: { authority: ProductionTelemetryPreviewModel["authority"] }) {
  return (
    <section class="telemetry-panel">
      <div class="lane-section-head">
        <h3>Authority</h3>
        <span>read-only</span>
      </div>
      <div class="live-priority-strip">
        <Metric label="applied" value={String(props.authority.applied)} tone={props.authority.applied ? "warn" : "ok"} />
        <Metric label="live" value={String(props.authority.liveTelemetryEnabled)} tone={props.authority.liveTelemetryEnabled ? "warn" : "ok"} />
        <Metric label="network" value={String(props.authority.networkSendEnabled)} tone={props.authority.networkSendEnabled ? "warn" : "ok"} />
        <Metric label="runtime" value={String(props.authority.runtimePipelineEnabled)} tone={props.authority.runtimePipelineEnabled ? "warn" : "ok"} />
        <Metric label="durable" value={String(props.authority.durableWriteEnabled)} tone={props.authority.durableWriteEnabled ? "warn" : "ok"} />
        <Metric label="NenDB" value={String(props.authority.nendbWriteEnabled)} tone={props.authority.nendbWriteEnabled ? "warn" : "ok"} />
      </div>
    </section>
  );
}

function ProductionTelemetryChecks(props: { title: string; checks: string[] }) {
  return (
    <section class="telemetry-panel">
      <div class="lane-section-head">
        <h3>{props.title}</h3>
        <span>{props.checks.length}</span>
      </div>
      <div class="guardrail-list">
        <For each={props.checks} fallback={<EmptyState label={`No ${props.title.toLowerCase()}`} compact />}>
          {(check) => <span>{check}</span>}
        </For>
      </div>
    </section>
  );
}
```

Reuse `Metric`, `ChainSources`, `CommandList`, `Badge`, and `EmptyState`.

- [ ] **Step 5: Add styles**

Add compact, non-card-nested CSS classes:

```css
.telemetry-grid { display: grid; grid-template-columns: minmax(0, 1.1fr) minmax(280px, 0.9fr); gap: 14px; }
.telemetry-panel { border: 1px solid #d6ddd2; border-radius: 6px; background: #fff; padding: 12px; }
.telemetry-map-list { display: grid; gap: 10px; }
.telemetry-map-row { display: grid; gap: 8px; border-top: 1px solid #edf0ea; padding-top: 10px; }
.telemetry-field-list { display: flex; flex-wrap: wrap; gap: 6px; }
```

- [ ] **Step 6: Verify UI tests**

Run:

```sh
bun run zigeffect:workbench:typecheck
bun test --timeout 30000 packages/zigeffect/workbench/src
```

Expected: pass.

---

### Task 4: Preview Contract Tool

**Files:**
- Add: `packages/zigeffect/tools/causal_production_telemetry_workbench_readonly_preview.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Write failing Zig tests**

Create the tool file with tests first. Constants:

```zig
pub const production_telemetry_workbench_readonly_preview_schema = "zigeffect.causal.production-telemetry-workbench-readonly-preview.v1";
pub const recommendation = "start-production-telemetry-ci-artifact-preview";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-artifact-preview";
```

Tests must assert:

- schema and branch constants;
- `--from-retention <json> approve|reject --reason <reason>`;
- ready output contains `preview_status: ready`, `read_only_preview=true`, `solid_webui_enabled=true`;
- blocked output remains `durable_write_enabled=false` and `nendb_write_enabled=false`;
- required commands include `bun run zigeffect:workbench:typecheck`, `bun run zigeffect:workbench:test`, `zig build examples`, and `zig build test`.

- [ ] **Step 2: Verify red**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_workbench_readonly_preview.zig
```

Expected: fail with intentional red failures or missing implementation.

- [ ] **Step 3: Implement minimal tool**

Follow the parser/evaluator/formatter pattern from
`tools/causal_production_telemetry_nendb_retention_fixtures.zig`, but adapt:

- input struct reads source retention fields;
- checks require retention schema v1, status ready, approved decision, source
  checks pass, mapping fixtures present, disabled authority, and exact
  verification commands;
- output emits JSON/text artifacts next to the source path with
  `-workbench-readonly-preview` suffix.

- [ ] **Step 4: Wire build**

In `build.zig`, add module/executable/run/test step after the NenDB retention
tool:

```zig
const causal_production_telemetry_workbench_readonly_preview_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_telemetry_workbench_readonly_preview.zig"),
    .target = target,
    .optimize = optimize,
});
```

Add step name `causal-production-telemetry-workbench-readonly-preview` and add
the executable/test dependencies to `examples_step` and `test_step`.

- [ ] **Step 5: Verify tool**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_workbench_readonly_preview.zig
zig build causal-production-telemetry-workbench-readonly-preview -- \
  --from-retention ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures.json \
  approve \
  --reason "read-only SolidJS webui preview reviewed" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Expected: ready artifact with next branch `codex/zigeffect-causal-production-telemetry-ci-artifact-preview`.

---

### Task 5: Governance, Backlog, And Docs

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Add: `packages/zigeffect/docs/production-telemetry-workbench-readonly-preview.md`
- Modify docs listed in the Files section.

- [ ] **Step 1: Add schema governance entry**

Register `zigeffect.causal.production-telemetry-workbench-readonly-preview.v1`,
bump schema count from 57 to 58, and assert text/json reports contain
`workbench-readonly-preview`.

- [ ] **Step 2: Update backlog**

Mark `production-telemetry-workbench-readonly-preview` delivered, update:

```zig
pub const recommendation = "start-production-telemetry-ci-artifact-preview";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-ci-artifact-preview";
```

Add verification commands for the preview tool and workbench tests.

- [ ] **Step 3: Write docs**

Create `production-telemetry-workbench-readonly-preview.md` covering command,
UI tab, sample artifact, read-only boundary, status meanings, agent guidance,
and verification.

Update README, operations, roadmap, completion audit, schema governance, and
master roadmap to point from workbench preview to CI artifact preview.

- [ ] **Step 4: Verify docs/tool reports**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_schema_governance.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json 2> ../../.zig-cache/causal-artifacts/schema-governance.json
rg '"schema_count": 58|production-telemetry-workbench-readonly-preview|workbench-readonly-preview' ../../.zig-cache/causal-artifacts/schema-governance.json
zig build causal-production-hardening-backlog -- --format json 2> ../../.zig-cache/causal-artifacts/production-hardening-backlog.json
rg 'start-production-telemetry-ci-artifact-preview|codex/zigeffect-causal-production-telemetry-ci-artifact-preview|production-telemetry-workbench-readonly-preview' ../../.zig-cache/causal-artifacts/production-hardening-backlog.json
```

Use `zig build causal-schema-governance` instead of direct `zig test` if module imports require build wiring.

---

### Task 6: Full Verification And Commit

**Files:** all modified files.

- [ ] **Step 1: Run focused frontend verification**

```sh
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:test
```

Expected: pass.

- [ ] **Step 2: Run full zigeffect verification**

```sh
cd packages/zigeffect
zig build examples
zig build test
```

Expected: pass.

- [ ] **Step 3: Run repo verification**

```sh
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: pass.

- [ ] **Step 4: Commit**

```sh
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md packages/zigeffect/README.md packages/zigeffect/build.zig packages/zigeffect/docs packages/zigeffect/tools packages/zigeffect/workbench
git commit -m "feat(zigeffect): add production telemetry workbench preview"
```
