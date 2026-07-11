import { For, Show } from "solid-js";
import { EmptyState, Meta, Metric } from "../primitives";
import { receiptIsComplete, type SafetyReceipt } from "./safetyReceipt";

export function SafetyPanel(props: { receipt: SafetyReceipt | null; error?: string; copiedCommand: string | null; onCopy: (command: string) => void }) {
  return (
    <div class="view-stack safety-view">
      <div class="view-heading"><h2>Agent safety</h2><span>read-only evidence</span></div>
      <Show when={props.receipt} fallback={<EmptyState label={props.error ?? "No safety receipt loaded"} />}>
        {(receipt) => <>
          <div class="chain-status">
            <Metric label="verdict" value={receipt().verdict} tone={receipt().verdict === "passed" ? "ok" : "warn"} />
            <Metric label="complete" value={String(receiptIsComplete(receipt()))} tone={receiptIsComplete(receipt()) ? "ok" : "warn"} />
            <Metric label="forbidden" value={String(receipt().static.forbidden)} tone={receipt().static.forbidden ? "warn" : "ok"} />
            <Metric label="live allocations" value={String(receipt().memory.live_allocations)} tone={receipt().memory.live_allocations ? "warn" : "ok"} />
            <Metric label="introduced" value={String(receipt().static.introduced)} tone={receipt().static.introduced ? "warn" : "ok"} />
            <Metric label="resolved" value={String(receipt().static.resolved)} tone={receipt().static.resolved ? "ok" : undefined} />
          </div>
          <section class="chain-panel"><h3>Source and toolchain</h3><div class="metadata-grid">
            <Meta label="project" value={receipt().project} /><Meta label="profile" value={receipt().profile} />
            <Meta label="revision" value={receipt().source_revision} /><Meta label="Zig" value={receipt().toolchain.zig_version} />
            <Meta label="target" value={receipt().toolchain.target} /><Meta label="optimize" value={receipt().toolchain.optimize} />
          </div></section>
          <section class="chain-panel"><h3>Memory and evidence completeness</h3><div class="metadata-grid">
            <Meta label="allocations / frees" value={`${receipt().memory.allocations} / ${receipt().memory.frees}`} />
            <Meta label="peak bytes" value={String(receipt().memory.peak_bytes)} />
            <Meta label="invalid frees" value={String(receipt().memory.invalid_frees)} />
            <Meta label="out of memory" value={String(receipt().memory.out_of_memory)} />
            <For each={Object.entries(receipt().completeness)}>{([key, value]) => <Meta label={key.replaceAll("_", " ")} value={String(value)} />}</For>
          </div></section>
          <section class="chain-panel"><div class="lane-section-head"><h3>Gate matrix</h3><span>{receipt().gates.length}</span></div>
            <div class="diff-entry-list"><For each={receipt().gates} fallback={<EmptyState label="No gates recorded" compact />}>{(gate) =>
              <div classList={{ "diff-entry": true, ok: gate.status === "passed", warning: gate.status !== "passed" }}>
                <span>{gate.required ? "required" : "optional"}</span><strong>{gate.kind} · {gate.status}</strong><small>{gate.detail || "No detail"}</small>
                <Show when={gate.replay_command}><button type="button" onClick={() => props.onCopy(gate.replay_command)}>{props.copiedCommand === gate.replay_command ? "Copied" : "Copy replay"}</button></Show>
              </div>}
            </For></div>
          </section>
          <section class="chain-panel"><div class="lane-section-head"><h3>Source-linked diagnostics</h3><span>{receipt().diagnostics.length}</span></div>
            <div class="diff-entry-list"><For each={receipt().diagnostics} fallback={<EmptyState label="No compiler diagnostics" compact />}>{(diagnostic) =>
              <div class="diff-entry warning"><span>{diagnostic.severity}</span><strong>{diagnostic.file}:{diagnostic.line}:{diagnostic.column}</strong><small>{diagnostic.message}</small></div>}
            </For></div>
          </section>
          <section class="chain-panel"><div class="lane-section-head"><h3>Unsafe inventory</h3><span>{receipt().finding_ids.length}</span></div>
            <div class="diff-entry-list"><For each={receipt().finding_ids} fallback={<EmptyState label="No governed constructs found" compact />}>{(id) =>
              <div class="diff-entry warning"><span>finding</span><strong>{id}</strong><small>Run `zigeffect safety explain {id}` for source and repair guidance.</small></div>}
            </For></div>
          </section>
        </>}
      </Show>
    </div>
  );
}
