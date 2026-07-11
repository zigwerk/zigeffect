import type { JSX } from "solid-js";
import { Overlay } from "./Overlay";

// Full-width overlay host for the secondary artifact views (diff / chain / metadata /
// queries). Keeps the main lenses uncluttered while preserving the rich renderers.
export function AuxOverlay(props: { title: string; onClose: () => void; children: JSX.Element }) {
  return (
    <Overlay onClose={props.onClose}>
      <div class="aux-overlay" onKeyDown={(event) => event.key === "Escape" && props.onClose()}>
        <div class="aux-head">
          <h2>{props.title}</h2>
          <button type="button" class="icon-button" onClick={props.onClose} aria-label="Close">✕</button>
        </div>
        <div class="aux-body">{props.children}</div>
      </div>
    </Overlay>
  );
}
