import { For, Show } from "solid-js";
import type { CausalEvent, QueryCommand } from "../causalArtifact";
import type { TraceFindingMark } from "../trace/traceModel";
import { Badge, CommandList, EmptyState, Meta } from "../primitives";

// The one persistent detail rail. Whatever is selected anywhere — a trace row, a DAG
// node, an evidence jump — fills this rail: identity, reference lineage, the cause-path
// breadcrumb (each rung re-selects), the finding callout, the redacted detail, and the
// copyable read-only query commands. It never mutates anything; the only actions copy
// CLI strings.

export function Inspector(props: {
  event: CausalEvent | null;
  causePath: CausalEvent[];
  finding: TraceFindingMark | null;
  commands: QueryCommand[];
  copiedCommand: string | null;
  runMeta: Array<{ label: string; value: string }>;
  onCopy: (command: string) => void;
  onSelect: (id: string) => void;
}) {
  return (
    <aside class="inspector">
      <div class="inspector-head">
        <Show when={props.event} fallback={<strong>Inspector</strong>}>
          {(event) => <span class="insp-eyebrow">event #{event().idText}</span>}
        </Show>
        <span class="lock-pill" title="Read-only viewer">read-only</span>
      </div>

      <Show
        when={props.event}
        fallback={
          <div class="inspector-body">
            <dl class="insp-dl">
              <For each={props.runMeta}>{(item) => <Meta label={item.label} value={item.value} />}</For>
            </dl>
            <EmptyState label="Select an event in the trace or graph to inspect its cause-path, references, and queries." />
          </div>
        }
      >
        {(event) => (
          <div class="inspector-body">
            <div class="insp-identity">
              <div class="insp-kind">
                <h2>{event().kind}</h2>
                <Show when={event().status}>
                  <Badge value={event().status} />
                </Show>
              </div>
            </div>

            <Show when={props.finding}>
              {(finding) => (
                <div classList={{ "finding-callout": true, fail: finding().severity === "fail" }}>
                  <span class="fc-title">Finding #{finding().index} · {finding().title}</span>
                  <span class="fc-summary">{finding().severity === "fail" ? "Failure-severity finding" : "Warning-severity finding"} on this event.</span>
                </div>
              )}
            </Show>

            <section class="insp-section">
              <h4>Identity</h4>
              <dl class="insp-dl">
                <Meta label="label" value={event().label || "—"} />
                <Meta label="type" value={event().typeName || "—"} />
                <Show when={event().serviceKey}>{(value) => <Meta label="service" value={value()} />}</Show>
                <Show when={event().layerName || event().layerId}>
                  <Meta label="layer" value={event().layerName || `layer ${event().layerId}`} />
                </Show>
                <Show when={event().runId}>{(value) => <Meta label="run" value={value()} />}</Show>
                <Show when={event().scopeId}>{(value) => <Meta label="scope" value={value()} />}</Show>
                <Show when={event().fiberId}>{(value) => <Meta label="fiber" value={value()} />}</Show>
                <Show when={event().parentId}>{(value) => <Meta label="parent" value={value()} />}</Show>
                <Show when={event().traceId}>{(value) => <Meta label="trace" value={value()} />}</Show>
                <Show when={event().spanId}>{(value) => <Meta label="span" value={value()} />}</Show>
              </dl>
            </section>

            <Show when={hasRefs(event())}>
              <section class="insp-section">
                <h4>References</h4>
                <div class="ref-pills">
                  <RefPill label="artifact" value={event().artifactId} />
                  <RefPill label="entity" value={event().domainEntityRef} />
                  <RefPill label="subject" value={event().dataSubjectRef} />
                  <RefPill label="schema" value={event().schemaRef} />
                </div>
              </section>
            </Show>

            <Show when={props.causePath.length > 1}>
              <section class="insp-section">
                <h4>Cause path</h4>
                <div class="breadcrumb">
                  <For each={props.causePath}>
                    {(crumb, index) => (
                      <>
                        <Show when={index() > 0}>
                          <span class="crumb-rail">↓</span>
                        </Show>
                        <button
                          type="button"
                          classList={{ crumb: true, head: crumb.idText === event().idText }}
                          onClick={() => props.onSelect(crumb.idText)}
                        >
                          <span class="crumb-id">#{crumb.idText}</span>
                          <span class="crumb-kind">{crumb.kind}</span>
                        </button>
                      </>
                    )}
                  </For>
                </div>
              </section>
            </Show>

            <section class="insp-section">
              <h4>Redacted detail</h4>
              <div class="redacted-block">
                <span class="redacted-tag">safe to share</span>
                <p>{event().redactedDetail || "no detail recorded"}</p>
              </div>
            </section>

            <Show when={props.commands.length > 0}>
              <section class="insp-section">
                <h4>Queries</h4>
                <CommandList commands={props.commands} copiedCommand={props.copiedCommand} onCopy={props.onCopy} compact />
              </section>
            </Show>
          </div>
        )}
      </Show>
    </aside>
  );
}

function RefPill(props: { label: string; value: string }) {
  return (
    <Show when={props.value}>
      <span class="ref-pill">
        <span>{props.label}</span>
        {props.value}
      </span>
    </Show>
  );
}

function hasRefs(event: CausalEvent): boolean {
  return Boolean(event.artifactId || event.domainEntityRef || event.dataSubjectRef || event.schemaRef);
}
