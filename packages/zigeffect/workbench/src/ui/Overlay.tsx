import type { JSX } from "solid-js";

// A modal scrim that closes on backdrop click. Shared by the command palette and the
// auxiliary-view overlays.
export function Overlay(props: { onClose: () => void; children: JSX.Element }) {
  return (
    <div
      class="overlay-scrim"
      onClick={(event) => {
        if (event.target === event.currentTarget) {
          props.onClose();
        }
      }}
    >
      {props.children}
    </div>
  );
}
