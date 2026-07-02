import { For, Show } from "solid-js";
import type { QueryCommand } from "./causalArtifact";

// Shared visual atoms used across every surface and the auxiliary views. Keeping them
// in one place is what lets the whole workbench speak a single visual language.

export function Badge(props: { value: string }) {
  return <span class={`badge status-${props.value.replaceAll("_", "-")}`}>{props.value || "—"}</span>;
}

export function Metric(props: { label: string; value: string; tone?: "ok" | "warn" }) {
  return (
    <div classList={{ metric: true, ok: props.tone === "ok", warn: props.tone === "warn" }}>
      <span>{props.label}</span>
      <strong>{props.value}</strong>
    </div>
  );
}

export function Meta(props: { label: string; value: string }) {
  return (
    <>
      <dt>{props.label}</dt>
      <dd>{props.value}</dd>
    </>
  );
}

export function EmptyState(props: { label: string; compact?: boolean }) {
  return <div classList={{ "empty-state": true, compact: props.compact }}>{props.label}</div>;
}

export function CommandList(props: {
  commands: QueryCommand[];
  copiedCommand: string | null;
  onCopy: (command: string) => void;
  compact?: boolean;
}) {
  return (
    <div class="command-list">
      <For each={props.commands} fallback={<EmptyState label="No commands" compact />}>
        {(item) => (
          <div class="command-row">
            <Show when={!props.compact}>
              <span class="cmd-label">{item.label}</span>
            </Show>
            <code>{item.command}</code>
            <button
              type="button"
              classList={{ "copy-chip": true, copied: props.copiedCommand === item.command }}
              onClick={() => props.onCopy(item.command)}
            >
              {props.copiedCommand === item.command ? "Copied" : "Copy"}
            </button>
          </div>
        )}
      </For>
    </div>
  );
}

export function gateToneClass(value: string): string {
  if (value.includes("block") || value.includes("reject") || value.includes("unknown")) {
    return "blocked";
  }
  if (value.includes("migration") || value.includes("operational") || value.includes("rollback") || value.includes("human")) {
    return "review";
  }
  return "allow";
}

const agentHueVar: Record<string, string> = {
  codex: "var(--agent-codex)",
  "claude-code": "var(--agent-claude)",
  zigeffect: "var(--agent-zigeffect)",
  human: "var(--agent-human)",
  other: "var(--agent-other)",
};

export function agentHue(kind: string): string {
  return agentHueVar[kind] ?? "var(--agent-other)";
}
