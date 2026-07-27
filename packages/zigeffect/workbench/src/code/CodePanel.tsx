import { For, Show, createMemo, createSignal } from "solid-js";
import { truncationNotice, type CodeQueryModel, type CodeResult } from "./repositoryQuery";

// The code perspective. Where the execution lens answers "what did this run do",
// this one answers "where is the code that does X" — the same graph, asked a
// different question.
//
// Its whole design premise is that a ranking nobody computed is a ranking nobody
// can check. So every row carries the three signals that produced its position,
// the header carries the engine's own confidence verdict *and* its reason, and
// the bound on the answer is stated rather than left for the reader to infer
// from a suspiciously round number of rows.

const signals: Array<{ key: keyof Pick<CodeResult, "keywordScore" | "vectorScore" | "graphScore">; label: string; hint: string }> = [
  { key: "keywordScore", label: "kw", hint: "keyword — inverse document frequency, weighted by which field matched" },
  { key: "vectorScore", label: "vec", hint: "vector — cosine against the query embedding" },
  { key: "graphScore", label: "gr", hint: "graph — the best score among this node's neighbours" },
];

/** One signal as a proportion of its bar, with the number kept beside it. */
function SignalBar(props: { label: string; hint: string; value: number }) {
  return (
    <span class="code-signal" title={props.hint}>
      <span class="cs-label">{props.label}</span>
      <span class="cs-track" role="presentation">
        {/* Width is the score. The numeric value stays visible next to it —
            a bar alone communicates a shape, and the reader may need to
            compare two results that look the same at this width. */}
        <span class="cs-fill" style={{ width: `${Math.round(props.value * 100)}%` }} />
      </span>
      <span class="cs-value">{props.value.toFixed(2)}</span>
    </span>
  );
}

export function CodePanel(props: {
  model: CodeQueryModel | null;
  error: string | null;
  limit: number;
  /** Runs a new query. Absent when no engine is attached, which disables the box. */
  onQuery?: (text: string) => void;
  pending?: boolean;
  onSelect?: (result: CodeResult) => void;
}) {
  const [draft, setDraft] = createSignal("");
  const notice = createMemo(() => (props.model ? truncationNotice(props.model, props.limit) : ""));
  const live = () => typeof props.onQuery === "function";

  const submit = (event: Event) => {
    event.preventDefault();
    const text = draft().trim();
    if (text.length === 0 || !props.onQuery) return;
    props.onQuery(text);
  };

  return (
    <section class="code-panel">
      <form class="code-query" onSubmit={submit}>
        <input
          type="search"
          class="cq-input"
          placeholder={live() ? "Ask the repository — e.g. resolve imports" : "No engine attached"}
          aria-label="Repository query"
          disabled={!live()}
          value={draft()}
          onInput={(event) => setDraft(event.currentTarget.value)}
        />
        <button type="submit" class="cq-run" disabled={!live() || props.pending === true || draft().trim().length === 0}>
          {props.pending === true ? "Running…" : "Query"}
        </button>
      </form>

      <Show when={props.error}>
        {(message) => (
          <p class="code-error" role="alert">
            {message()}
          </p>
        )}
      </Show>

      <Show when={props.model} fallback={<Show when={!props.error}><p class="code-empty">No answer yet.</p></Show>}>
        {(model) => (
          <>
            <header class="code-verdict">
              <span classList={{ "cv-confidence": true, low: model().confidence === "low" }}>
                {model().confidence === "low" ? "Low confidence" : "High confidence"}
              </span>
              {/* The reason is the difference between a verdict and an
                  instruction. `low` without it cannot be argued with, which is
                  why the model refuses to produce that combination at all. */}
              <Show when={model().confidenceReason.length > 0}>
                <span class="cv-reason">{model().confidenceReason}</span>
              </Show>
              <span class="cv-embedder" title="The embedding function these vector scores came from">
                {model().embedder}
              </span>
              <Show when={model().treeVerified}>
                <span class="cv-verified" title="Answered from a parse this build verified">
                  tree-verified
                </span>
              </Show>
            </header>

            <Show when={notice().length > 0}>
              <p class="code-truncation" role="status">
                {notice()}
              </p>
            </Show>

            <ol class="code-results">
              <For each={model().results}>
                {(result) => (
                  <li
                    classList={{ "code-result": true, selectable: typeof props.onSelect === "function" }}
                    onClick={() => props.onSelect?.(result)}
                  >
                    <div class="cr-head">
                      <span class="cr-label">{result.label}</span>
                      <span class="cr-kind">{result.kind}</span>
                      <span class="cr-where">
                        {result.path}
                        <Show when={result.line > 0}>{`:${result.line}`}</Show>
                      </span>
                      <span class="cr-score" title="Combined rank">
                        {result.score.toFixed(3)}
                      </span>
                    </div>
                    <div class="cr-signals">
                      <For each={signals}>
                        {(signal) => (
                          <SignalBar label={signal.label} hint={signal.hint} value={result[signal.key]} />
                        )}
                      </For>
                      {/* "matched 1 of 3" separates an isolated hit from a
                          corroborated one — two results can score alike while
                          one answered the whole question and the other a word
                          of it. */}
                      <Show when={model().queryTermCount > 0}>
                        <span
                          classList={{ "cr-terms": true, partial: result.matchedTerms < model().queryTermCount }}
                          title="Distinct query terms this result matched"
                        >
                          matched {result.matchedTerms} of {model().queryTermCount}
                        </span>
                      </Show>
                    </div>
                  </li>
                )}
              </For>
            </ol>

            <Show when={model().results.length === 0}>
              <p class="code-empty">Nothing matched “{model().query}”.</p>
            </Show>
          </>
        )}
      </Show>
    </section>
  );
}
