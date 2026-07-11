import { For, Show, createMemo, createSignal } from "solid-js";
import { EmptyState, Meta, Metric } from "../primitives";
import { testRunIsComplete, type TestRunReceipt } from "./testReceipt";

export function TestPanel(props: { run: TestRunReceipt | null; error?: string; copiedCommand: string | null; onCopy: (command: string) => void; onSelectEvent: (id: string) => void }) {
  const [requirement, setRequirement] = createSignal("all");
  const [component, setComponent] = createSignal("all");
  const [scenario, setScenario] = createSignal("all");
  const visible = createMemo(() => (props.run?.receipts ?? []).filter((receipt) =>
    (requirement() === "all" || receipt.scenario.requirement === requirement()) &&
    (component() === "all" || receipt.scenario.component === component()) &&
    (scenario() === "all" || receipt.scenario.id === scenario())));
  return <div class="view-stack test-view">
    <div class="view-heading"><h2>Tests</h2><span>requirement-linked runtime evidence</span></div>
    <Show when={props.run} fallback={<EmptyState label={props.error ?? "No test run receipt loaded"} />}>
      {(run) => <>
        <div class="chain-status">
          <Metric label="status" value={run().status} tone={run().status === "passed" ? "ok" : "warn"} />
          <Metric label="passed" value={String(run().passed)} tone="ok" /><Metric label="failed" value={String(run().failed)} tone={run().failed ? "warn" : "ok"} />
          <Metric label="incomplete" value={String(run().incomplete)} tone={run().incomplete ? "warn" : "ok"} />
          <Metric label="complete" value={String(testRunIsComplete(run()))} tone={testRunIsComplete(run()) ? "ok" : "warn"} />
          <Metric label="introduced" value={String(run().introduced_failures)} tone={run().introduced_failures ? "warn" : undefined} />
          <Metric label="resolved" value={String(run().resolved_failures)} tone={run().resolved_failures ? "ok" : undefined} />
        </div>
        <div class="test-filters">
          <label>Requirement<select value={requirement()} onChange={(event) => setRequirement(event.currentTarget.value)}><option value="all">All</option><For each={[...new Set(run().receipts.map((item) => item.scenario.requirement))]}>{(value) => <option value={value}>{value}</option>}</For></select></label>
          <label>Component<select value={component()} onChange={(event) => setComponent(event.currentTarget.value)}><option value="all">All</option><For each={[...new Set(run().receipts.map((item) => item.scenario.component))]}>{(value) => <option value={value}>{value}</option>}</For></select></label>
          <label>Scenario<select value={scenario()} onChange={(event) => setScenario(event.currentTarget.value)}><option value="all">All</option><For each={run().receipts}>{(item) => <option value={item.scenario.id}>{item.scenario.id}</option>}</For></select></label>
        </div>
        <For each={visible()} fallback={<EmptyState label="No tests match these filters" compact />}>
          {(receipt) => <section classList={{ "chain-panel": true, warning: receipt.status !== "passed" }}>
            <div class="lane-section-head"><h3>{receipt.scenario.label}</h3><span>{receipt.status}</span></div>
            <div class="metadata-grid"><Meta label="scenario" value={receipt.scenario.id} /><Meta label="requirement" value={receipt.scenario.requirement} /><Meta label="component" value={receipt.scenario.component} /><Meta label="seed / fault" value={`${receipt.seed} / ${receipt.fault_kind}${receipt.fault_index === null ? "" : `:${receipt.fault_index}`}`} /><Meta label="executor" value={receipt.executor} /><Meta label="source revision" value={receipt.source_revision} /></div>
            <div class="metadata-grid"><Meta label="native protocol" value={receipt.execution.native_receipt ? "validated" : "missing"} /><Meta label="target" value={receipt.execution.target || "unknown"} /><Meta label="optimization" value={receipt.execution.optimize || "unknown"} /><Meta label="worktree" value={receipt.execution.worktree_dirty ? "dirty" : "clean"} /><Meta label="coverage" value={`${receipt.coverage.hits}/${receipt.coverage.targets}`} /><Meta label="required gaps" value={String(receipt.coverage.required_gaps)} /></div>
            <Show when={receipt.replay_command}><button type="button" onClick={() => props.onCopy(receipt.replay_command)}>{props.copiedCommand === receipt.replay_command ? "Copied" : "Copy deterministic replay"}</button></Show>
            <Show when={receipt.minimal_case}>{(minimal) => <div class="test-counterexample"><strong>Minimal counterexample</strong><code>{minimal().input}</code><small>{minimal().shrink_steps} shrink steps · {minimal().shrink_path || "default shrinker"} · case {minimal().case_index}</small></div>}</Show>
            <Show when={receipt.coverage_targets.length}><div class="diff-entry-list"><For each={receipt.coverage_targets}>{(target) => {
              const hit = () => receipt.coverage_hits.some((item) => item.target_id === target.id);
              return <div classList={{ "diff-entry": true, ok: hit(), warning: target.required && !hit() }}><span>{hit() ? "covered" : target.required ? "required gap" : "advisory gap"}</span><strong>{target.label}</strong><small>{target.dimension} · {target.id}</small><Show when={!hit() && target.repair_hint}><small>Repair: {target.repair_hint}</small></Show><Show when={!hit() && target.next_command}><button type="button" onClick={() => props.onCopy(target.next_command)}>{props.copiedCommand === target.next_command ? "Copied" : "Copy next command"}</button></Show></div>}}</For></div></Show>
            <Show when={receipt.evidence.length}><div class="diff-entry-list test-evidence-grid"><For each={receipt.evidence}>{(item) => <div classList={{ "diff-entry": true, ok: item.summary.status === "passed", warning: item.summary.status !== "passed" }}><span>{item.summary.status}</span><strong>{item.kind.replaceAll("_", " ")}</strong><small>{item.summary.executed}/{item.summary.planned} explored · {item.summary.failed} failed · {item.summary.unsupported} unsupported{item.summary.truncated ? " · bounded/truncated" : ""}</small><Show when={item.summary.artifact}><small>Artifact: {item.summary.artifact}</small></Show><Show when={item.summary.replay_token}><button type="button" onClick={() => props.onCopy(item.summary.replay_token)}>{props.copiedCommand === item.summary.replay_token ? "Copied" : "Copy evidence replay"}</button></Show></div>}</For></div></Show>
            <div class="diff-entry-list"><For each={receipt.assertions} fallback={<EmptyState label="No assertions recorded" compact />}>{(assertion) => <div classList={{ "diff-entry": true, ok: assertion.status === "passed", warning: assertion.status === "failed" }}><span>{assertion.status}</span><strong>{assertion.label}</strong><small>{assertion.detail || `${assertion.expected} → ${assertion.actual}`}</small><Show when={assertion.source.path}><small>{assertion.source.path}:{assertion.source.line}:{assertion.source.column}</small></Show><For each={assertion.causal_event_ids}>{(id) => <button type="button" onClick={() => props.onSelectEvent(String(id))}>Event #{id}</button>}</For><Show when={assertion.repair_hint}><small>Repair: {assertion.repair_hint}</small></Show></div>}</For></div>
            <div class="metadata-grid"><For each={Object.entries(receipt.memory)}>{([key, value]) => <Meta label={`memory ${key.replaceAll("_", " ")}`} value={String(value)} />}</For><For each={Object.entries(receipt.causal)}>{([key, value]) => <Meta label={`causal ${key.replaceAll("_", " ")}`} value={String(value)} />}</For><For each={Object.entries(receipt.completeness)}>{([key, value]) => <Meta label={key.replaceAll("_", " ")} value={String(value)} />}</For></div>
            <For each={receipt.limitations}>{(limitation) => <div class="test-limitation">Limited: {limitation}</div>}</For>
          </section>}
        </For>
      </>}
    </Show>
  </div>;
}
