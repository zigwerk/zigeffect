import { For } from "solid-js";

// One reusable sliding segmented control — the single tactile signature shared by the
// lens switch, the DAG perspective/layout pickers, and the trace density toggle.

export function Segmented<T extends string>(props: {
  options: Array<{ value: T; label: string }>;
  value: T;
  onChange: (value: T) => void;
  ariaLabel?: string;
  compact?: boolean;
}) {
  return (
    <div classList={{ segmented: true, compact: props.compact }} role="tablist" aria-label={props.ariaLabel}>
      <For each={props.options}>
        {(option) => (
          <button
            type="button"
            role="tab"
            aria-selected={props.value === option.value}
            classList={{ active: props.value === option.value }}
            onClick={() => props.onChange(option.value)}
          >
            {option.label}
          </button>
        )}
      </For>
    </div>
  );
}
