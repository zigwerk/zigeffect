import { For, Show } from "solid-js";
import type { ServiceSummary } from "../hub/protocol";

// The multi-service drill-down: auto-discovered services (with a live status dot),
// each expandable to the layers seen within it. Clicking a service focuses it — the
// whole workspace then renders that service's live trace. The ⧉ toggle pins a
// service as a compact side pane (watch several services at once); clicking a
// layer chip focuses the service AND filters its trace to that layer. Only shown
// in hub mode (`?hub=<ws-url>`); absent it, the workbench is single-artifact.
export function ServicesRail(props: {
  services: ServiceSummary[];
  focused: string | null;
  pinned: string[];
  connected: boolean;
  onFocus: (serviceKey: string) => void;
  onTogglePin: (serviceKey: string) => void;
  onLayer: (serviceKey: string, layerName: string) => void;
}) {
  const isPinned = (serviceKey: string) => props.pinned.includes(serviceKey);
  return (
    <aside class="services-rail">
      <div class="rail-head">
        <span class="rail-title">Services</span>
        <span class="rail-count">{props.services.length}</span>
      </div>

      <Show
        when={props.services.length > 0}
        fallback={<div class="rail-empty">Waiting for a service to stream into the hub…</div>}
      >
        <div class="rail-list">
          <For each={props.services}>
            {(service) => (
              <div classList={{ "service-item": true, focused: props.focused === service.service_key }}>
                <div class="service-row">
                  <button type="button" class="service-btn" onClick={() => props.onFocus(service.service_key)}>
                    <span class={`status-dot ${service.status}`} title={service.status} />
                    <span class="service-name">{service.service_key}</span>
                    <span class="service-count">{service.frame_count}</span>
                  </button>
                  <button
                    type="button"
                    classList={{ "pin-btn": true, pinned: isPinned(service.service_key) }}
                    title={isPinned(service.service_key) ? "unpin side pane" : "pin as side pane"}
                    aria-pressed={isPinned(service.service_key)}
                    onClick={() => props.onTogglePin(service.service_key)}
                  >
                    ⧉
                  </button>
                </div>
                <Show when={service.layers.length > 0}>
                  <div class="layer-list">
                    <For each={service.layers}>
                      {(layer) => {
                        const name = layer.layer_name || `layer ${layer.layer_id}`;
                        return (
                          <button
                            type="button"
                            class="layer-chip"
                            title={`filter ${service.service_key} to ${name}`}
                            onClick={() => props.onLayer(service.service_key, name)}
                          >
                            {name}
                          </button>
                        );
                      }}
                    </For>
                  </div>
                </Show>
              </div>
            )}
          </For>
        </div>
      </Show>

      <Show when={!props.connected}>
        <div class="rail-disconnected">hub disconnected</div>
      </Show>
    </aside>
  );
}
