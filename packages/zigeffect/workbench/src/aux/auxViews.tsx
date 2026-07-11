import { For, Show, createMemo } from "solid-js";
import type {
  AppCitationGroup,
  AppGateResultModel,
  AppIncidentModel,
  AppReadinessCheckModel,
  AppRemediationModel,
  CausalEvent,
  ChainSourceStep,
  GovernanceModel,
  QueryCommand,
  RemediationChainModel,
  SemanticDiffFinding,
  SemanticDiffFiberTerminal,
  SemanticDiffLineageEdge,
  SemanticDiffModel,
  SemanticDiffResourceFinalization,
  WorkbenchModel,
} from "../causalArtifact";
import type { WorkbenchSession } from "../workbenchBridge";
import { CommandList, EmptyState, Meta, Metric, gateToneClass } from "../primitives";

// The auxiliary artifact views (semantic diff, governance/remediation chain, metadata,
// and the query catalogue). They are reachable as overlays from the command palette /
// "More" menu — secondary to the execution + collaboration lenses but fully preserved.

export function DiffView(props: { diff: SemanticDiffModel | null; onSelectEvent: (id: string) => void }) {
  return (
    <div class="view-stack">
      <div class="view-heading">
        <h2>Semantic diff</h2>
        <span>{props.diff?.schema ?? "no semantic diff"}</span>
      </div>

      <Show when={props.diff} fallback={<EmptyState label="Loaded artifact has no semantic graph diff" />}>
        {(diff) => (
          <>
            <div class="diff-summary">
              <Metric label="resolved findings" value={String(diff().summary.resolvedFindings)} tone={diff().summary.resolvedFindings ? "ok" : undefined} />
              <Metric label="introduced findings" value={String(diff().summary.introducedFindings)} tone={diff().summary.introducedFindings ? "warn" : "ok"} />
              <Metric label="fiber terminals +" value={String(diff().summary.addedFiberTerminals)} />
              <Metric label="resources +" value={String(diff().summary.addedResourceFinalizations)} />
              <Metric label="lineage edges +" value={String(diff().summary.addedLineageEdges)} />
            </div>

            <section class="chain-panel">
              <h3>Artifacts</h3>
              <div class="metadata-grid">
                <Meta label="before" value={diff().beforeArtifact} />
                <Meta label="after" value={diff().afterArtifact} />
                <Meta label="source" value={diff().artifactPath} />
              </div>
            </section>

            <div class="diff-grid">
              <DiffFindingList title="Resolved findings" entries={diff().resolvedFindings} tone="ok" onSelectEvent={props.onSelectEvent} />
              <DiffFindingList title="Introduced findings" entries={diff().introducedFindings} tone="warn" onSelectEvent={props.onSelectEvent} />
              <DiffFiberList title="Added fiber terminals" entries={diff().addedFiberTerminals} onSelectEvent={props.onSelectEvent} />
              <DiffFiberList title="Removed fiber terminals" entries={diff().removedFiberTerminals} onSelectEvent={props.onSelectEvent} />
              <DiffResourceList title="Added resource finalizations" entries={diff().addedResourceFinalizations} onSelectEvent={props.onSelectEvent} />
              <DiffResourceList title="Removed resource finalizations" entries={diff().removedResourceFinalizations} onSelectEvent={props.onSelectEvent} />
              <DiffLineageList title="Added lineage edges" entries={diff().addedLineageEdges} onSelectEvent={props.onSelectEvent} />
              <DiffLineageList title="Removed lineage edges" entries={diff().removedLineageEdges} onSelectEvent={props.onSelectEvent} />
            </div>

            <Show when={diff().warnings.length > 0}>
              <div class="warning-list">
                <For each={diff().warnings}>{(warning) => <span>{warning}</span>}</For>
              </div>
            </Show>
          </>
        )}
      </Show>
    </div>
  );
}

function DiffFindingList(props: { title: string; entries: SemanticDiffFinding[]; tone: "ok" | "warn"; onSelectEvent: (id: string) => void }) {
  return (
    <section class="diff-panel">
      <div class="lane-section-head">
        <h3>{props.title}</h3>
        <span>{props.entries.length}</span>
      </div>
      <div class="diff-entry-list">
        <For each={props.entries} fallback={<EmptyState label="No entries" compact />}>
          {(entry) => (
            <button
              type="button"
              classList={{ "diff-entry": true, ok: props.tone === "ok", warning: props.tone === "warn" }}
              disabled={!selectableDiffEventId(entry.eventId)}
              onClick={() => selectDiffEvent(props.onSelectEvent, entry.eventId)}
            >
              <span>#{entry.eventId}</span>
              <strong>{entry.kind}</strong>
              <small>{entry.owner}</small>
            </button>
          )}
        </For>
      </div>
    </section>
  );
}

function DiffFiberList(props: { title: string; entries: SemanticDiffFiberTerminal[]; onSelectEvent: (id: string) => void }) {
  return (
    <section class="diff-panel">
      <div class="lane-section-head">
        <h3>{props.title}</h3>
        <span>{props.entries.length}</span>
      </div>
      <div class="diff-entry-list">
        <For each={props.entries} fallback={<EmptyState label="No entries" compact />}>
          {(entry) => (
            <button
              type="button"
              class="diff-entry"
              disabled={!selectableDiffEventId(entry.eventId)}
              onClick={() => selectDiffEvent(props.onSelectEvent, entry.eventId)}
            >
              <span>fiber {entry.fiberId}</span>
              <strong>{entry.terminalKind}</strong>
              <small>#{entry.eventId} / {entry.status}</small>
            </button>
          )}
        </For>
      </div>
    </section>
  );
}

function DiffResourceList(props: { title: string; entries: SemanticDiffResourceFinalization[]; onSelectEvent: (id: string) => void }) {
  return (
    <section class="diff-panel">
      <div class="lane-section-head">
        <h3>{props.title}</h3>
        <span>{props.entries.length}</span>
      </div>
      <div class="diff-entry-list">
        <For each={props.entries} fallback={<EmptyState label="No entries" compact />}>
          {(entry) => (
            <button
              type="button"
              class="diff-entry"
              disabled={!selectableDiffEventId(entry.eventId)}
              onClick={() => selectDiffEvent(props.onSelectEvent, entry.eventId)}
            >
              <span>scope {entry.scopeId}</span>
              <strong>{entry.typeName}</strong>
              <small>resource {entry.resourceId} / event #{entry.eventId}</small>
            </button>
          )}
        </For>
      </div>
    </section>
  );
}

function DiffLineageList(props: { title: string; entries: SemanticDiffLineageEdge[]; onSelectEvent: (id: string) => void }) {
  return (
    <section class="diff-panel">
      <div class="lane-section-head">
        <h3>{props.title}</h3>
        <span>{props.entries.length}</span>
      </div>
      <div class="diff-entry-list">
        <For each={props.entries} fallback={<EmptyState label="No entries" compact />}>
          {(entry) => (
            <button
              type="button"
              class="diff-entry"
              disabled={!selectableDiffEventId(entry.toEventId, entry.fromEventId)}
              onClick={() => selectDiffEvent(props.onSelectEvent, entry.toEventId, entry.fromEventId)}
            >
              <span>#{entry.fromEventId} -&gt; #{entry.toEventId}</span>
              <strong>{entry.edgeKind}</strong>
              <small>semantic edge</small>
            </button>
          )}
        </For>
      </div>
    </section>
  );
}

function selectableDiffEventId(...ids: string[]): string | null {
  return ids.find((id) => id.length > 0 && id !== "unknown" && id !== "null") ?? null;
}

function selectDiffEvent(onSelectEvent: (id: string) => void, ...ids: string[]) {
  const id = selectableDiffEventId(...ids);
  if (id) {
    onSelectEvent(id);
  }
}

export function ChainView(props: {
  governance: GovernanceModel | null;
  events: CausalEvent[];
  copiedCommand: string | null;
  onCopy: (command: string) => void;
  onSelectEvent: (id: string) => void;
}) {
  return (
    <div class="view-stack">
      <div class="view-heading">
        <h2>Governance chain</h2>
        <span>{props.governance?.kind ?? "no governance artifact"}</span>
      </div>

      <Show when={props.governance} fallback={<EmptyState label="Loaded artifact has no remediation chain" />}>
        {(governance) => (
          <Show
            when={governance().app}
            fallback={(
              <Show when={governance().chain} fallback={<GovernanceSummary governance={governance()} />}>
                {(chain) => (
                  <>
                    <ChainStatus chain={chain()} />
                    <div class="chain-grid">
                      <ChainSources steps={chain().sourceSteps} copiedCommand={props.copiedCommand} onCopy={props.onCopy} />
                      <ChainVerification chain={chain()} copiedCommand={props.copiedCommand} onCopy={props.onCopy} />
                    </div>
                    <ChainClassifications chain={chain()} />
                    <ChainGuardrails chain={chain()} />
                    <div class="warning-list">
                      <For each={[...governance().warnings, ...chain().warnings]} fallback={<EmptyState label="No chain warnings" compact />}>
                        {(warning) => <span>{warning}</span>}
                      </For>
                    </div>
                  </>
                )}
              </Show>
            )}
          >
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
        )}
      </Show>
    </div>
  );
}

function GovernanceSummary(props: { governance: GovernanceModel }) {
  return (
    <>
      <div class="chain-status">
        <Metric label="schema" value={props.governance.schema} />
        <Metric label="kind" value={props.governance.kind} />
        <Metric label="target" value={props.governance.target} />
        <Metric label="applied" value={String(props.governance.applied ?? "unknown")} />
        <Metric label="authority" value={props.governance.mutationAuthority ?? "none"} tone="ok" />
      </div>
      <div class="chain-panel">
        <h3>{props.governance.summary}</h3>
        <EmptyState label="This governance artifact has no audit-chain source graph" compact />
      </div>
    </>
  );
}

function ChainStatus(props: { chain: RemediationChainModel }) {
  return (
    <div class="chain-status">
      <Metric label="target" value={props.chain.target} />
      <Metric label="assessment" value={props.chain.assessment} tone={props.chain.assessment === "regressed" ? "warn" : "ok"} />
      <Metric label="approval" value={props.chain.approvalStatus} />
      <Metric label="applied" value={String(props.chain.applied ?? "unknown")} tone={props.chain.applied ? "warn" : "ok"} />
      <Metric label="delta" value={props.chain.findingDelta} />
    </div>
  );
}

function ChainSources(props: { steps: ChainSourceStep[]; copiedCommand: string | null; onCopy: (command: string) => void }) {
  return (
    <section class="chain-panel">
      <h3>Source artifacts</h3>
      <div class="chain-source-list">
        <For each={props.steps} fallback={<EmptyState label="No source artifact paths" compact />}>
          {(step) => <ChainSourceRow step={step} copiedCommand={props.copiedCommand} onCopy={props.onCopy} />}
        </For>
      </div>
    </section>
  );
}

function ChainSourceRow(props: { step: ChainSourceStep; copiedCommand: string | null; onCopy: (command: string) => void }) {
  return (
    <div class="chain-source-row">
      <span>{props.step.label}</span>
      <code>{props.step.path}</code>
      <Show when={props.step.workbenchCommand} fallback={<small>text artifact</small>}>
        {(command) => (
          <button type="button" onClick={() => props.onCopy(command())}>
            {props.copiedCommand === command() ? "Copied" : "Copy"}
          </button>
        )}
      </Show>
    </div>
  );
}

function ChainVerification(props: { chain: RemediationChainModel; copiedCommand: string | null; onCopy: (command: string) => void }) {
  const commands = createMemo<QueryCommand[]>(() => props.chain.verificationCommands.map((command, index) => ({ label: `verify ${index + 1}`, command })));
  return (
    <section class="chain-panel">
      <h3>Verification</h3>
      <CommandList commands={commands()} copiedCommand={props.copiedCommand} onCopy={props.onCopy} compact />
    </section>
  );
}

function ChainClassifications(props: { chain: RemediationChainModel }) {
  const groups = createMemo(() => [
    { label: "disappeared", ids: props.chain.classifications.disappeared },
    { label: "persisting", ids: props.chain.classifications.persisting },
    { label: "appeared", ids: props.chain.classifications.appeared },
    { label: "missing", ids: props.chain.classifications.missing },
  ]);
  return (
    <section class="chain-panel">
      <div class="lane-section-head">
        <h3>Event classification</h3>
        <span>{props.chain.classifications.eventIds.length} cited ids</span>
      </div>
      <div class="chain-classification-grid">
        <For each={groups()}>
          {(group) => (
            <div class="chain-id-list">
              <span>{group.label}</span>
              <For each={group.ids} fallback={<small>none</small>}>
                {(id) => <strong>#{id}</strong>}
              </For>
            </div>
          )}
        </For>
      </div>
    </section>
  );
}

function ChainGuardrails(props: { chain: RemediationChainModel }) {
  return (
    <section class="chain-panel">
      <h3>Guardrails</h3>
      <div class="guardrail-list">
        <For each={props.chain.guardrails} fallback={<EmptyState label="No guardrails recorded" compact />}>
          {(guardrail) => <span>{guardrail}</span>}
        </For>
      </div>
    </section>
  );
}

function AppRemediationView(props: {
  app: AppRemediationModel;
  events: CausalEvent[];
  copiedCommand: string | null;
  onCopy: (command: string) => void;
  onSelectEvent: (id: string) => void;
}) {
  return (
    <>
      <AppRemediationStatus app={props.app} />
      <div class="app-remediation-grid">
        <ChainSources steps={props.app.sourceSteps} copiedCommand={props.copiedCommand} onCopy={props.onCopy} />
        <AppPolicyGates gates={props.app.policyGates} results={props.app.gateResults} />
      </div>
      <AppIncidents
        incidents={props.app.incidents}
        events={props.events}
        copiedCommand={props.copiedCommand}
        onCopy={props.onCopy}
        onSelectEvent={props.onSelectEvent}
      />
      <div class="app-remediation-grid">
        <AppCitations citations={props.app.citations} />
        <AppVerification commands={props.app.verificationCommands} copiedCommand={props.copiedCommand} onCopy={props.onCopy} />
      </div>
      <Show when={props.app.kind === "app-application"}>
        <div class="app-remediation-grid">
          <AppEvidenceGroups title="Change evidence" groups={props.app.changeEvidence} />
          <AppBeforeAfterEvidence before={props.app.beforeEvidence} after={props.app.afterEvidence} />
        </div>
      </Show>
      <Show when={props.app.checks.length || props.app.applicationSteps.length}>
        <div class="app-remediation-grid">
          <AppReadinessChecks checks={props.app.checks} />
          <AppApplicationSteps steps={props.app.applicationSteps} />
        </div>
      </Show>
      <AppGuardrails guardrails={props.app.guardrails} />
      <div class="warning-list">
        <For each={props.app.warnings} fallback={<EmptyState label="No app remediation warnings" compact />}>
          {(warning) => <span>{warning}</span>}
        </For>
      </div>
    </>
  );
}

function AppRemediationStatus(props: { app: AppRemediationModel }) {
  const posture = props.app.kind === "app-application"
    ? props.app.applicationStatus
    : props.app.kind === "app-application-readiness"
      ? props.app.readinessStatus
      : props.app.kind === "app-patch-proposal"
        ? props.app.proposalStatus
        : props.app.decision;
  return (
    <div class="chain-status app-status">
      <Metric label="target" value={props.app.target} />
      <Metric label="kind" value={props.app.kind} />
      <Metric label="posture" value={posture === "unknown" ? props.app.approvalStatus : posture} />
      <Show when={props.app.readyForApplication !== null}>
        <Metric label="ready" value={String(props.app.readyForApplication)} tone={props.app.readyForApplication ? "ok" : "warn"} />
      </Show>
      <Metric label="approval" value={props.app.approvalStatus} />
      <Metric label="applied" value={String(props.app.applied ?? "unknown")} tone={props.app.applied ? "warn" : "ok"} />
      <Metric label="authority" value={props.app.mutationAuthority ?? "none"} tone={props.app.mutationAuthority === "none" ? "ok" : "warn"} />
    </div>
  );
}

function AppPolicyGates(props: { gates: string[]; results: AppGateResultModel[] }) {
  return (
    <section class="chain-panel">
      <div class="lane-section-head">
        <h3>Policy gates</h3>
        <span>{props.gates.length || props.results.length}</span>
      </div>
      <div class="gate-chip-list">
        <For each={props.gates} fallback={<EmptyState label="No policy gates" compact />}>
          {(gate) => <span class={`gate-chip ${gateToneClass(gate)}`}>{gate}</span>}
        </For>
      </div>
      <div class="gate-result-list">
        <For each={props.results} fallback={<EmptyState label="No gate result details" compact />}>
          {(result) => (
            <div class="gate-result-row">
              <span class={`gate-chip ${gateToneClass(result.status || result.gate)}`}>{result.status}</span>
              <strong>{result.gate}</strong>
              <p>{result.detail || "No detail recorded"}</p>
            </div>
          )}
        </For>
      </div>
    </section>
  );
}

function AppIncidents(props: {
  incidents: AppIncidentModel[];
  events: CausalEvent[];
  copiedCommand: string | null;
  onCopy: (command: string) => void;
  onSelectEvent: (id: string) => void;
}) {
  const eventIds = createMemo(() => new Set(props.events.map((event) => event.idText)));
  return (
    <section class="chain-panel app-remediation-full">
      <div class="lane-section-head">
        <h3>App incidents</h3>
        <span>{props.incidents.length}</span>
      </div>
      <div class="app-incident-list">
        <For each={props.incidents} fallback={<EmptyState label="No app incidents recorded" compact />}>
          {(incident) => (
            <div class="app-incident-row">
              <Show
                when={eventIds().has(incident.eventId)}
                fallback={<span class="app-event-chip">#{incident.eventId}</span>}
              >
                <button type="button" class="app-event-button" onClick={() => props.onSelectEvent(incident.eventId)}>
                  #{incident.eventId}
                </button>
              </Show>
              <div>
                <strong>{incident.action}</strong>
                <span>{incident.label}</span>
              </div>
              <span class={`gate-chip ${gateToneClass(incident.policyGate)}`}>{incident.policyGate}</span>
              <small>{incident.subsystem}</small>
              <small>{incident.fixCategory}</small>
              <CommandList
                commands={incident.queryCommands.map((command, index) => ({ label: `query ${index + 1}`, command }))}
                copiedCommand={props.copiedCommand}
                onCopy={props.onCopy}
                compact
              />
            </div>
          )}
        </For>
      </div>
    </section>
  );
}

function AppCitations(props: { citations: AppCitationGroup[] }) {
  return (
    <section class="chain-panel">
      <h3>Citations</h3>
      <div class="citation-grid">
        <For each={props.citations} fallback={<EmptyState label="No citation groups" compact />}>
          {(group) => (
            <div class="citation-group">
              <span>{group.label}</span>
              <For each={group.values} fallback={<small>none</small>}>
                {(value) => <code>{value}</code>}
              </For>
            </div>
          )}
        </For>
      </div>
    </section>
  );
}

function AppEvidenceGroups(props: { title: string; groups: AppCitationGroup[] }) {
  return (
    <section class="chain-panel">
      <h3>{props.title}</h3>
      <div class="citation-grid">
        <For each={props.groups} fallback={<EmptyState label="No evidence groups" compact />}>
          {(group) => (
            <div class="citation-group">
              <span>{group.label}</span>
              <For each={group.values} fallback={<small>none</small>}>
                {(value) => <code>{value}</code>}
              </For>
            </div>
          )}
        </For>
      </div>
    </section>
  );
}

function AppBeforeAfterEvidence(props: { before: string[]; after: string[] }) {
  return (
    <section class="chain-panel">
      <h3>Before and after</h3>
      <div class="citation-grid">
        <div class="citation-group">
          <span>Before</span>
          <For each={props.before} fallback={<small>none</small>}>
            {(value) => <code>{value}</code>}
          </For>
        </div>
        <div class="citation-group">
          <span>After</span>
          <For each={props.after} fallback={<small>none</small>}>
            {(value) => <code>{value}</code>}
          </For>
        </div>
      </div>
    </section>
  );
}

function AppVerification(props: { commands: string[]; copiedCommand: string | null; onCopy: (command: string) => void }) {
  const commands = createMemo<QueryCommand[]>(() => props.commands.map((command, index) => ({ label: `verify ${index + 1}`, command })));
  return (
    <section class="chain-panel">
      <h3>Verification</h3>
      <CommandList commands={commands()} copiedCommand={props.copiedCommand} onCopy={props.onCopy} compact />
    </section>
  );
}

function AppReadinessChecks(props: { checks: AppReadinessCheckModel[] }) {
  return (
    <section class="chain-panel">
      <div class="lane-section-head">
        <h3>Readiness checks</h3>
        <span>{props.checks.length}</span>
      </div>
      <div class="gate-result-list">
        <For each={props.checks} fallback={<EmptyState label="No readiness checks" compact />}>
          {(check) => (
            <div class="gate-result-row">
              <span class={`gate-chip ${gateToneClass(check.status)}`}>{check.status}</span>
              <strong>{check.name}</strong>
              <p>{check.detail || "No detail recorded"}</p>
            </div>
          )}
        </For>
      </div>
    </section>
  );
}

function AppApplicationSteps(props: { steps: string[] }) {
  return (
    <section class="chain-panel">
      <h3>Application steps</h3>
      <div class="guardrail-list">
        <For each={props.steps} fallback={<EmptyState label="No application steps recorded" compact />}>
          {(step) => <span>{step}</span>}
        </For>
      </div>
    </section>
  );
}

function AppGuardrails(props: { guardrails: string[] }) {
  return (
    <section class="chain-panel app-remediation-full">
      <h3>Guardrails</h3>
      <div class="guardrail-list">
        <For each={props.guardrails} fallback={<EmptyState label="No app guardrails recorded" compact />}>
          {(guardrail) => <span>{guardrail}</span>}
        </For>
      </div>
    </section>
  );
}

export function MetadataView(props: { model: WorkbenchModel; session: WorkbenchSession | null }) {
  const sessionWarnings = () => props.session?.warnings ?? [];
  return (
    <div class="view-stack">
      <div class="view-heading">
        <h2>Metadata</h2>
        <span>{props.model.safeToShare}</span>
      </div>
      <dl class="metadata-grid">
        <Meta label="artifact" value={props.model.artifactPath} />
        <Meta label="schema" value={props.model.schema} />
        <Meta label="schema version" value={props.model.schemaVersion} />
        <Meta label="taxonomy version" value={props.model.taxonomyVersion} />
        <Meta label="events" value={String(props.model.events.length)} />
        <Meta label="findings" value={String(props.model.findings.length)} />
        <Meta label="read only" value={String(props.session?.read_only ?? true)} />
        <Meta label="bytes" value={String(props.session?.artifact_bytes ?? "unknown")} />
      </dl>
      <div class="warning-list">
        <For each={[...props.model.warnings, ...sessionWarnings()]} fallback={<EmptyState label="No metadata warnings" compact />}>
          {(warning) => <span>{warning}</span>}
        </For>
      </div>
    </div>
  );
}

export function QueriesView(props: {
  artifactPath: string;
  selected: CausalEvent | null;
  commands: QueryCommand[];
  copiedCommand: string | null;
  onCopy: (command: string) => void;
}) {
  const snapshot = `zig build causal-query -- --file ${props.artifactPath} snapshot`;
  const commands = createMemo<QueryCommand[]>(() => [{ label: "Snapshot", command: snapshot }, ...props.commands]);
  return (
    <div class="view-stack">
      <div class="view-heading">
        <h2>Query catalogue</h2>
        <span>{props.selected ? `event #${props.selected.idText}` : "artifact"}</span>
      </div>
      <CommandList commands={commands()} copiedCommand={props.copiedCommand} onCopy={props.onCopy} />
    </div>
  );
}
