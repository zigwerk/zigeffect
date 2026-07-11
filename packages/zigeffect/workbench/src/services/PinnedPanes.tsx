import { For, Show, createMemo } from "solid-js";
import { deriveWorkbenchModel, parseArtifactJson } from "../causalArtifact";
import type { ServiceSummary } from "../hub/protocol";

// Side-by-side monitors for pinned services (hub mode). Each pane is a compact,
// ambient live trace — newest events first, no controls — fed by that service's
// own buffer. Interaction PROMOTES: clicking the pane title or a row focuses the
// service in the main workspace (and selects the event), where the full
// trace/DAG/inspector live. The shared inspector never shows two services at
// once, so cross-service event-id collisions can't mislead it.
export function PinnedPanes(props: {
  pinned: string[];
  services: ServiceSummary[];
  artifactJson: (serviceKey: string) => string;
  droppedFrames: (serviceKey: string) => number;
  onUnpin: (serviceKey: string) => void;
  onPromote: (serviceKey: string, eventId: string | null) => void;
}) {
  return (
    <Show when={props.pinned.length > 0}>
      <div class="pinned-strip" role="complementary" aria-label="Pinned services">
        <For each={props.pinned}>
          {(serviceKey) => {
            const model = createMemo(() => {
              try {
                return deriveWorkbenchModel(parseArtifactJson(props.artifactJson(serviceKey)), {
                  artifactPath: serviceKey,
                });
              } catch {
                return null;
              }
            });
            const status = () =>
              props.services.find((service) => service.service_key === serviceKey)?.status ?? "stopped";
            const findingsCount = () => model()?.findings.length ?? 0;
            // Newest first: a monitor pane must show the latest activity without scrolling.
            const rows = createMemo(() => (model()?.events ?? []).slice(-80).reverse());
            return (
              <section class="pinned-pane">
                <header class="pinned-head">
                  <span class={`status-dot ${status()}`} title={status()} />
                  <button
                    type="button"
                    class="pinned-name"
                    title={`focus ${serviceKey}`}
                    onClick={() => props.onPromote(serviceKey, null)}
                  >
                    {serviceKey}
                  </button>
                  <span class="pinned-count">{model()?.events.length ?? 0}</span>
                  <button type="button" class="pinned-unpin" title="unpin" onClick={() => props.onUnpin(serviceKey)}>
                    ✕
                  </button>
                </header>
                <Show when={findingsCount() > 0}>
                  <div class="pinned-findings">
                    {findingsCount()} finding{findingsCount() === 1 ? "" : "s"}
                  </div>
                </Show>
                <Show when={props.droppedFrames(serviceKey) > 0}>
                  <div class="pinned-gap">trace starts mid-run</div>
                </Show>
                <div class="pinned-rows">
                  <For each={rows()}>
                    {(event) => (
                      <button type="button" class="pinned-row" onClick={() => props.onPromote(serviceKey, event.idText)}>
                        <span class="pinned-id">#{event.idText}</span>
                        <span class="pinned-kind">{event.kind}</span>
                        <span class="pinned-label">{event.label}</span>
                        <span class="pinned-status">{event.status}</span>
                      </button>
                    )}
                  </For>
                </div>
              </section>
            );
          }}
        </For>
      </div>
    </Show>
  );
}
