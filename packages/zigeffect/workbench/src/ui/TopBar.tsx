import { For, Show } from "solid-js";
import type { LocalDevHealthSummary } from "../causalArtifact";
import type { Lens, ThemeMode } from "../theme";
import { Segmented } from "./Segmented";

const lensOptions: Array<{ value: Lens; label: string }> = [
  { value: "execution", label: "Execution" },
  { value: "collaboration", label: "Collaboration" },
];

// Persistent chrome: identity, the lens switcher (the headline control), filters, live
// status, health, theme toggle, and the command-palette entry point.
export function TopBar(props: {
  artifactPath: string;
  schema: string;
  lens: Lens;
  theme: ThemeMode;
  isLive: boolean;
  liveFrameCount: number;
  health: LocalDevHealthSummary | null;
  search: string;
  kind: string;
  status: string;
  kinds: string[];
  statuses: string[];
  onSearch: (value: string) => void;
  onKind: (value: string) => void;
  onStatus: (value: string) => void;
  onLens: (lens: Lens) => void;
  onToggleTheme: () => void;
  onOpenPalette: () => void;
}) {
  return (
    <header class="topbar">
      <div class="brand">
        <span class="brand-mark" />
        <span class="brand-text">
          <span class="brand-eyebrow">zigeffect causal workbench</span>
          <span class="brand-title">{props.artifactPath}</span>
        </span>
      </div>

      <div class="topbar-center">
        <Segmented ariaLabel="Workbench lens" options={lensOptions} value={props.lens} onChange={props.onLens} />
      </div>

      <div class="topbar-right">
        <input
          class="filter-control"
          aria-label="Search events"
          value={props.search}
          placeholder="Search events…"
          onInput={(event) => props.onSearch(event.currentTarget.value)}
        />
        <select
          class="filter-select"
          aria-label="Filter by event kind"
          value={props.kind}
          onChange={(event) => props.onKind(event.currentTarget.value)}
        >
          <option value="all">All kinds</option>
          <For each={props.kinds}>{(value) => <option value={value}>{value}</option>}</For>
        </select>
        <select
          class="filter-select"
          aria-label="Filter by event status"
          value={props.status}
          onChange={(event) => props.onStatus(event.currentTarget.value)}
        >
          <option value="all">All statuses</option>
          <For each={props.statuses}>{(value) => <option value={value}>{value}</option>}</For>
        </select>

        <Show when={props.health}>
          {(health) => <span class={`health-pill ${health().health}`}>{health().health}</span>}
        </Show>

        <span classList={{ "live-indicator": true, "is-live": props.isLive }} title={props.isLive ? "Streaming live" : "Static snapshot"}>
          <span class="live-dot" />
          {props.isLive ? `live · ${props.liveFrameCount}` : "static"}
        </span>

        <button type="button" class="kbd-hint" onClick={props.onOpenPalette} title="Command palette">
          <kbd>⌘K</kbd>
        </button>

        <button type="button" class="icon-button" onClick={props.onToggleTheme} title="Toggle theme" aria-label="Toggle theme">
          {props.theme === "dark" ? "☀" : "☾"}
        </button>
      </div>
    </header>
  );
}
