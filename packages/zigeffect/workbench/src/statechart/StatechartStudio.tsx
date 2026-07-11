import { For, Show } from "solid-js";
import type { StatechartDefinitionArtifact } from "./statechartModel";
import type { StudioChange, StudioModel } from "./studioModel";

const proofLabels: Array<[keyof NonNullable<StudioChange["proof"]>, string]> = [
  ["validation", "Definition"],
  ["analysis", "Analysis"],
  ["paths", "Paths"],
  ["coverage", "Coverage"],
  ["determinism", "Determinism"],
  ["xstate", "XState"],
  ["temporal", "Temporal"],
  ["faults", "Faults"],
  ["performance", "Performance"],
];

export function StatechartStudio(props: {
  model: StudioModel;
  definition: StatechartDefinitionArtifact | null;
  onCopy?: (value: string) => void;
}) {
  const changes = () => props.definition
    ? props.model.changes.filter((change) => change.proposal.machine_id === props.definition?.id)
    : props.model.changes;
  const selected = () => changes()[0] ?? null;
  const fleet = () => props.definition ? props.model.fleet.filter((instance) => instance.machineId === props.definition?.id) : props.model.fleet;

  return (
    <div class="statechart-studio" aria-label="Statechart Studio">
      <header class="studio-hero">
        <div>
          <span class="eyebrow">Agent-authored workflow governance</span>
          <h3>{props.definition?.id ?? "Statechart Studio"}</h3>
          <p>{props.definition?.description || "Inspect typed workflow logic, verification evidence, review, and deployment lineage."}</p>
        </div>
        <Show when={selected()} fallback={<span class="studio-status empty">No proposal</span>}>
          {(change) => <span class={`studio-status ${change().status}`}>{change().status}</span>}
        </Show>
      </header>

      <div class="studio-grid">
        <section class="studio-card logic-card">
          <div class="studio-card-head"><h4>Logic humans can audit</h4><span>{props.definition?.states.length ?? 0} states · {props.definition?.transitions.length ?? 0} transitions</span></div>
          <Show when={props.definition} fallback={<p class="studio-empty">Select a statechart definition to inspect its logic.</p>}>
            {(definition) => (
              <div class="studio-logic">
                <div class="studio-state-list">
                  <For each={definition().states}>{(state) => (
                    <div class="studio-logic-row">
                      <span class={`studio-kind ${state.kind}`}>{state.kind}</span>
                      <strong>{state.id}</strong>
                      <span>{state.parent ? `inside ${state.parent}` : state.description || "root state"}</span>
                    </div>
                  )}</For>
                </div>
                <div class="studio-transition-list">
                  <For each={definition().transitions}>{(transition) => (
                    <button type="button" class="studio-transition" onClick={() => props.onCopy?.(`${transition.source} --${transition.event ?? "always"}--> ${transition.target ?? "internal"}`)}>
                      <strong>{transition.source}</strong><span>{transition.event ?? "always"}</span><strong>{transition.target ?? "internal"}</strong>
                      <Show when={transition.guard}><em>guard: {transition.guard}</em></Show>
                    </button>
                  )}</For>
                </div>
              </div>
            )}
          </Show>
        </section>

        <section class="studio-card proof-card">
          <div class="studio-card-head"><h4>Production proof</h4><span>{selected()?.proofComplete ? "complete" : "required"}</span></div>
          <Show when={selected()?.proof} fallback={<p class="studio-empty">No proof bundle has been attached.</p>}>
            {(proof) => (
              <>
                <div class="proof-matrix">
                  <For each={proofLabels}>{([field, label]) => {
                    const status = () => String(proof()[field]);
                    return <div class={`proof-check ${status()}`}><span>{label}</span><strong>{status()}</strong></div>;
                  }}</For>
                </div>
                <div class="mutation-score"><span>Mutation score</span><strong>{proof().mutation_killed}/{proof().mutation_total}</strong></div>
              </>
            )}
          </Show>
        </section>

        <section class="studio-card governance-card">
          <div class="studio-card-head"><h4>Immutable change chain</h4><span>exact digest bindings</span></div>
          <Show when={selected()} fallback={<p class="studio-empty">No proposed change for this definition.</p>}>
            {(change) => (
              <div class="governance-chain">
                <ChainStep label="Proposal" value={`v${change().proposal.base_version} → v${change().proposal.next_version}`} complete />
                <ChainStep label="Proof" value={change().proof?.proof_id ?? "missing"} complete={change().proofComplete} />
                <ChainStep label="Human review" value={change().review?.decision ?? "pending"} complete={change().review?.decision === "accepted"} />
                <ChainStep label="Approval" value={change().approval?.decision ?? "pending"} complete={change().approval?.decision === "approved"} />
                <ChainStep label="Application" value={change().application ? `event ${change().application?.causal_event_id}` : "not applied"} complete={change().application !== null} />
                <For each={change().issues}>{(issue) => <div class="studio-warning">{issue}</div>}</For>
              </div>
            )}
          </Show>
        </section>

        <section class="studio-card fleet-card">
          <div class="studio-card-head"><h4>Fleet & release contract</h4><span>{fleet().length} live instances</span></div>
          <Show when={fleet().length > 0}>
            <div class="studio-fleet">
              <For each={fleet()}>{(instance) => <div class="fleet-row"><span class={`fleet-health ${instance.health}`}/><strong>#{instance.instanceId}</strong><span>{instance.status} · {instance.owner}</span><span>{instance.pending + instance.mailboxDepth} pending</span></div>}</For>
            </div>
          </Show>
          <dl class="studio-contract">
            <dt>Definition fingerprint</dt><dd>{props.definition?.fingerprint ?? "—"}</dd>
            <dt>Version</dt><dd>{props.definition?.version ?? "—"}</dd>
            <dt>XState oracle</dt><dd>required proof</dd>
            <dt>Mutation authority</dt><dd>separate approval + control capability</dd>
            <dt>Runtime posture</dt><dd>bounded, deterministic, fail closed</dd>
          </dl>
        </section>
      </div>
    </div>
  );
}

function ChainStep(props: { label: string; value: string; complete: boolean }) {
  return <div classList={{ "chain-step": true, complete: props.complete }}><span class="chain-dot"/><div><strong>{props.label}</strong><span>{props.value}</span></div></div>;
}
