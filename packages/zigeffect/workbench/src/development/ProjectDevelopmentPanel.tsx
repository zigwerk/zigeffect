import { For, Show, createMemo, createSignal } from "solid-js";
import { Badge, EmptyState, Metric } from "../primitives";
import {
  compareProjectSessions,
  focusProjectDevelopment,
  type ProjectDevelopmentModel,
} from "./projectDevelopment";

export function ProjectDevelopmentPanel(props: {
  model: ProjectDevelopmentModel;
  validEventIds: Set<string>;
  copiedCommand: string | null;
  onCopy: (command: string) => void;
  onSelectEvent: (id: string) => void;
}) {
  const [component, setComponent] = createSignal<string | null>(null);
  const [session, setSession] = createSignal<string | null>(props.model.currentSession);
  const [baseline, setBaseline] = createSignal<string | null>(props.model.baselineSession);
  const [comparisonTarget, setComparisonTarget] = createSignal<string | null>(props.model.currentSession);
  const selectedSession = createMemo(() =>
    session() && props.model.sessions.some((item) => item.id === session()) ? session() : null,
  );
  const focused = createMemo(() => focusProjectDevelopment(props.model, {
    component: component(),
    session: selectedSession(),
  }));
  const comparison = createMemo(() => {
    const left = baseline();
    const right = comparisonTarget();
    return left && right && left !== right
      ? compareProjectSessions(props.model, left, right)
      : null;
  });

  return (
    <section class="project-development" aria-label="Project development">
      <div class="project-development-head">
        <div>
          <span class="project-kicker">zigeffect project</span>
          <h3>{props.model.project}</h3>
          <small>{props.model.kind} · v{props.model.version}</small>
        </div>
        <div class="project-state">
          <Badge value={props.model.connection} />
          <Badge value={props.model.recovery} />
          <Badge value={props.model.approval} />
        </div>
      </div>

      <div class="project-metrics">
        <Metric label="components" value={String(props.model.components.length)} />
        <Metric label="open requirements" value={String(props.model.requirements.filter((item) => item.status !== "satisfied").length)} />
        <Metric label="failed checks" value={String(props.model.checks.filter((item) => item.status === "failed").length)} tone={props.model.checks.some((item) => item.status === "failed") ? "warn" : "ok"} />
        <Metric label="application facts" value={String(props.model.applicationFacts.length)} />
        <Metric label="sessions" value={String(props.model.sessions.length)} />
      </div>

      <div class="project-filters">
        <label>
          <span>Component</span>
          <select value={component() ?? ""} onChange={(event) => setComponent(event.currentTarget.value || null)}>
            <option value="">All components</option>
            <For each={props.model.components}>{(item) => <option value={item.id}>{item.id}</option>}</For>
          </select>
        </label>
        <label>
          <span>Session</span>
          <select value={selectedSession() ?? ""} onChange={(event) => setSession(event.currentTarget.value || null)}>
            <option value="">All sessions</option>
            <For each={props.model.sessions}>{(item) => <option value={item.id}>{item.provider} · {item.id}</option>}</For>
          </select>
        </label>
      </div>

      <div class="project-development-grid">
        <div class="project-development-column">
          <div class="collab-section-head"><h3><span aria-hidden="true">◇</span> Components</h3><span class="count">{focused().components.length}</span></div>
          <div class="component-map">
            <For each={focused().components} fallback={<EmptyState label="No components in focus" compact />}>
              {(item) => (
                <button type="button" classList={{ "component-node": true, selected: component() === item.id }} onClick={() => setComponent(item.id)}>
                  <strong>{item.id}</strong>
                  <span>{item.kind} · {item.path}</span>
                  <small>{item.dependsOn.length ? `depends on ${item.dependsOn.join(", ")}` : "no component dependencies"}</small>
                </button>
              )}
            </For>
          </div>

          <div class="collab-section-head"><h3>Requirements</h3><span class="count">{focused().requirements.length}</span></div>
          <For each={focused().requirements} fallback={<EmptyState label="No requirements in focus" compact />}>
            {(requirement) => (
              <div classList={{ "requirement-row": true, warning: requirement.status === "blocked" }}>
                <div class="requirement-title"><Badge value={requirement.status} /><strong>{requirement.summary}</strong><small>{requirement.id} · {requirement.component}</small></div>
                <For each={requirement.checks}>
                  {(check) => <div classList={{ "acceptance-row": true, fail: check.status === "failed" }}><Badge value={check.status} /><span>{check.expectation}</span><code>{check.command}</code></div>}
                </For>
                <For each={requirement.evidence}>
                  {(evidence) => (
                    <div class="evidence-row">
                      <span>{evidence.kind}</span><strong>{evidence.summary}</strong>
                      <Show when={evidence.eventIds.find((id) => props.validEventIds.has(id))}>
                        {(id) => <button type="button" title="Focus causal evidence" onClick={() => props.onSelectEvent(id())}>↗</button>}
                      </Show>
                    </div>
                  )}
                </For>
              </div>
            )}
          </For>

          <div class="collab-section-head"><h3>Tasks and next actions</h3><span class="count">{focused().tasks.length + focused().nextActions.length}</span></div>
          <div class="project-list">
            <For each={focused().tasks}>{(task) => <div><Badge value={task.status} /><strong>{task.summary}</strong><small>{task.id}</small></div>}</For>
            <For each={focused().nextActions}>{(action) => <div><Badge value="next" /><strong>{action.summary}</strong><small>{action.command ?? "no command"}</small></div>}</For>
          </div>
        </div>

        <div class="project-development-column">
          <div class="collab-section-head"><h3>Sessions</h3><span class="count">{props.model.sessions.length}</span></div>
          <div class="project-session-list">
            <For each={props.model.sessions} fallback={<EmptyState label="No project sessions" compact />}>
              {(item) => (
                <button type="button" classList={{ "project-session": true, selected: selectedSession() === item.id }} onClick={() => setSession(item.id)}>
                  <strong>{item.provider}</strong><span>{item.id}</span>
                  <Badge value={item.status} /><Badge value={item.approval} /><small>{item.recovery} · {item.connection}</small>
                </button>
              )}
            </For>
          </div>

          <Show when={props.model.sessions.length > 1}>
            <div class="collab-section-head"><h3><span aria-hidden="true">↔</span> Session comparison</h3></div>
            <div class="comparison-controls">
              <select aria-label="Baseline session" value={baseline() ?? ""} onChange={(event) => setBaseline(event.currentTarget.value || null)}>
                <option value="">Baseline</option>
                <For each={props.model.sessions}>{(item) => <option value={item.id}>{item.id}</option>}</For>
              </select>
              <select aria-label="Current session" value={comparisonTarget() ?? ""} onChange={(event) => setComparisonTarget(event.currentTarget.value || null)}>
                <option value="">Current</option>
                <For each={props.model.sessions}>{(item) => <option value={item.id}>{item.id}</option>}</For>
              </select>
            </div>
            <Show when={comparison()}>
              {(value) => <div class="comparison-summary"><Metric label="tasks added" value={String(value().tasksAdded)} /><Metric label="evidence added" value={String(value().evidenceAdded)} /><Metric label="artifacts added" value={String(value().artifactsAdded)} /></div>}
            </Show>
          </Show>

          <div class="collab-section-head"><h3>Commands</h3><span class="count">{focused().commands.length}</span></div>
          <div class="project-list">
            <For each={focused().commands}>
              {(command) => <div><code>{command.command}</code><small>{command.id}</small><button type="button" title={`Copy ${command.id}`} onClick={() => props.onCopy(command.command)}><span aria-hidden="true">⧉</span>{props.copiedCommand === command.command ? <span>Copied</span> : null}</button></div>}
            </For>
          </div>

          <div class="collab-section-head"><h3>Artifacts</h3><span class="count">{focused().artifacts.length}</span></div>
          <div class="project-list">
            <For each={focused().artifacts} fallback={<EmptyState label="No artifacts in focus" compact />}>
              {(artifact) => <div><Badge value={artifact.kind} /><code>{artifact.path}</code><small>{artifact.acceptanceCheck ?? artifact.requirement ?? "project"}</small></div>}
            </For>
          </div>

          <div class="collab-section-head"><h3>Application facts</h3><span class="count">{focused().applicationFacts.length}</span></div>
          <div class="application-fact-list">
            <For each={focused().applicationFacts} fallback={<EmptyState label="No application facts in focus" compact />}>
              {(fact) => (
                <button type="button" disabled={!props.validEventIds.has(fact.eventId)} onClick={() => props.onSelectEvent(fact.eventId)}>
                  <Badge value={fact.status} /><strong>{fact.kind.replaceAll("_", " ")}</strong>
                  <span>{fact.schemaRef || fact.domainEntityRef || fact.artifactId || fact.serviceKey || fact.detail}</span>
                  <code>event {fact.eventId}</code>
                </button>
              )}
            </For>
          </div>
        </div>
      </div>
    </section>
  );
}
