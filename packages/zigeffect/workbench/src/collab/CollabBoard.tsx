import { For, Show, createMemo } from "solid-js";
import {
  deriveLocalDevHealthSummary,
  deriveLocalDevIssueHighlights,
  type LocalDevAgentModel,
  type LocalDevCheckModel,
  type LocalDevSessionModel,
  type LocalDevTransportModel,
  type LocalDevTurnModel,
  type QueryCommand,
} from "../causalArtifact";
import { resolveEvidenceEventId } from "../trace/traceModel";
import { Badge, CommandList, EmptyState, Meta, Metric, agentHue } from "../primitives";

// The Human <-> AI collaboration lens. The hero when the lens is "collaboration", a slim
// ribbon's worth of summary when the lens is "execution". Every card that can name a
// causal event renders an "Evidence" jump that selects it across the whole app; when no
// event can be resolved it says so honestly rather than faking a link.
export function CollabBoard(props: {
  session: LocalDevSessionModel | null;
  validEventIds: Set<string>;
  copiedCommand: string | null;
  onCopy: (command: string) => void;
  onSelectEvent: (id: string) => void;
}) {
  const health = createMemo(() => (props.session ? deriveLocalDevHealthSummary(props.session) : null));
  const issues = createMemo(() => (props.session ? deriveLocalDevIssueHighlights(props.session) : []));
  const commands = createMemo<QueryCommand[]>(() => {
    const session = props.session;
    if (!session) {
      return [];
    }
    return [
      ...session.commands.filter((command) => command.command.length > 0).map((command) => ({ label: command.label, command: command.command })),
      ...session.artifacts.filter((artifact) => artifact.workbenchCommand !== null).map((artifact) => ({ label: artifact.label, command: artifact.workbenchCommand! })),
    ];
  });

  return (
    <section class="stage-pane">
      <div class="pane-head">
        <div class="pane-title">
          <h2>Human &amp; AI session</h2>
          <span class="pane-sub">{props.session?.status ?? "no local session"}</span>
        </div>
      </div>

      <Show
        when={props.session}
        fallback={
          <div class="collab">
            <EmptyState label="Loaded artifact has no local agent development session" />
          </div>
        }
      >
        {(session) => (
          <div class="collab">
            <div class="agent-summary">
              <Metric label="target" value={session().target} />
              <Metric label="phase" value={session().phase} />
              <Metric label="health" value={health()?.health ?? "unknown"} tone={health()?.health === "fail" ? "warn" : "ok"} />
              <Metric label="status" value={session().status} tone={session().status === "failed" ? "warn" : "ok"} />
              <Metric label="pass" value={String(health()?.passedChecks ?? 0)} tone="ok" />
              <Metric label="fail" value={String(health()?.failedChecks ?? 0)} tone={(health()?.failedChecks ?? 0) ? "warn" : "ok"} />
              <Metric label="agents" value={String(session().agents.length)} />
              <Metric label="commands" value={String(health()?.commandCount ?? 0)} />
              <Metric label="turns" value={String(health()?.turnCount ?? 0)} />
              <Metric label="artifacts" value={String(health()?.artifactCount ?? 0)} />
              <Metric label="transports" value={String(health()?.transportCount ?? 0)} />
            </div>

            <div class="redacted-block">
              <span>goal</span>
              <p style="font-family:var(--font-sans);color:var(--text-1)">{session().goal}</p>
            </div>

            <div class="collab-hero">
              <div class="collab-col">
                <div class="collab-section-head">
                  <h3>Agents</h3>
                  <span class="count">{session().agents.length}</span>
                </div>
                <For each={session().agents} fallback={<EmptyState label="No agents" compact />}>
                  {(agent) => (
                    <AgentCard
                      agent={agent}
                      validEventIds={props.validEventIds}
                      onSelectEvent={props.onSelectEvent}
                    />
                  )}
                </For>

                <Show when={session().turns.length > 0}>
                  <div class="collab-section-head">
                    <h3>Turn stream</h3>
                    <span class="count">{session().turns.length}</span>
                  </div>
                  <div class="turn-stream">
                    <For each={session().turns}>
                      {(turn) => (
                        <TurnCard turn={turn} />
                      )}
                    </For>
                  </div>
                </Show>

                <Show when={commands().length > 0}>
                  <div class="collab-section-head">
                    <h3>Command receipts</h3>
                    <span class="count">{commands().length}</span>
                  </div>
                  <CommandList commands={commands()} copiedCommand={props.copiedCommand} onCopy={props.onCopy} compact />
                </Show>
              </div>

              <div class="collab-col">
                <div class="collab-section-head">
                  <h3>Checks</h3>
                  <span class="count">{session().checks.length}</span>
                </div>
                <For each={session().checks} fallback={<EmptyState label="No checks" compact />}>
                  {(check) => <CheckCard check={check} />}
                </For>

                <div class="collab-section-head">
                  <h3>Transports</h3>
                  <span class="count">{session().transports.length}</span>
                </div>
                <For each={session().transports} fallback={<EmptyState label="No transports" compact />}>
                  {(transport) => <TransportCard transport={transport} />}
                </For>

                <Show when={issues().length > 0}>
                  <div class="collab-section-head">
                    <h3>Schema / CLI issues</h3>
                    <span class="count">{issues().length}</span>
                  </div>
                  <For each={issues()}>
                    {(issue) => (
                      <div class="check-card fail">
                        <Badge value={issue.source} />
                        <div class="check-body">
                          <span class="check-name">{issue.label}</span>
                          <span class="check-detail">{issue.detail}</span>
                        </div>
                      </div>
                    )}
                  </For>
                </Show>

                <Show when={session().guardrails.length > 0}>
                  <div class="collab-section-head">
                    <h3>Guardrails</h3>
                    <span class="count">{session().guardrails.length}</span>
                  </div>
                  <div class="guardrail-list">
                    <For each={session().guardrails}>{(guardrail) => <span>{guardrail}</span>}</For>
                  </div>
                </Show>

                <Show when={session().nextActions.length > 0}>
                  <div class="collab-section-head">
                    <h3>Next actions</h3>
                    <span class="count">{session().nextActions.length}</span>
                  </div>
                  <dl class="metadata-grid">
                    <For each={session().nextActions}>{(action, index) => <Meta label={`step ${index() + 1}`} value={action} />}</For>
                  </dl>
                </Show>
              </div>
            </div>

            <Show when={session().warnings.length > 0}>
              <div class="warning-list">
                <For each={session().warnings}>{(warning) => <span>{warning}</span>}</For>
              </div>
            </Show>
          </div>
        )}
      </Show>
    </section>
  );
}

function AgentCard(props: {
  agent: LocalDevAgentModel;
  validEventIds: Set<string>;
  onSelectEvent: (id: string) => void;
}) {
  const evidenceId = createMemo(() => resolveEvidenceEventId({ lastEventId: props.agent.lastEventId }, props.validEventIds));
  return (
    <div class="agent-card" style={`--hue:${agentHue(props.agent.kind)}`}>
      <span class="agent-avatar">{props.agent.kind.slice(0, 2)}</span>
      <div class="agent-body">
        <span class="agent-name">{props.agent.label}</span>
        <span class="agent-task">{props.agent.currentTask ?? props.agent.artifactPath ?? "no active task"}</span>
        <EvidenceJump evidenceId={evidenceId()} onSelectEvent={props.onSelectEvent} />
      </div>
      <Badge value={props.agent.status} />
    </div>
  );
}

function TurnCard(props: { turn: LocalDevTurnModel }) {
  // Turn records carry no event id in the current schema, so there is no honest evidence
  // jump to render here — the card stays clean rather than showing a permanent
  // "no causal evidence" affordance.
  return (
    <div class="turn-card" style={`--hue:${agentHue(props.turn.agentKind)}`}>
      <div class="turn-head">
        <span class="turn-agent">{props.turn.agentLabel}</span>
        <span class="turn-role">{props.turn.role}</span>
        <Badge value={props.turn.status} />
      </div>
      <span class="turn-summary">{props.turn.summary || props.turn.output || props.turn.input || props.turn.id}</span>
    </div>
  );
}

function CheckCard(props: { check: LocalDevCheckModel }) {
  return (
    <div classList={{ "check-card": true, fail: props.check.status === "fail", running: props.check.status === "running" }}>
      <Badge value={props.check.status} />
      <div class="check-body">
        <span class="check-name">{props.check.label}</span>
        <span class="check-detail">{props.check.detail || props.check.command || props.check.artifactPath || "no detail"}</span>
      </div>
    </div>
  );
}

function TransportCard(props: { transport: LocalDevTransportModel }) {
  return (
    <div classList={{ "check-card": true, fail: props.transport.status === "failed" || props.transport.status === "closed" }}>
      <Badge value={props.transport.protocol} />
      <div class="check-body">
        <span class="check-name">{props.transport.status}</span>
        <span class="check-detail">{props.transport.detail || props.transport.url || props.transport.sessionId || `${props.transport.frameCount} frames`}</span>
      </div>
    </div>
  );
}

function EvidenceJump(props: { evidenceId: string | null; onSelectEvent: (id: string) => void }) {
  return (
    <Show
      when={props.evidenceId}
      fallback={<span class="evidence-jump empty">no causal evidence</span>}
    >
      {(id) => (
        <button type="button" class="evidence-jump" onClick={() => props.onSelectEvent(id())}>
          Evidence ↳ #{id()}
        </button>
      )}
    </Show>
  );
}
