/**
 * The `zgraphy.query.v4` answer, as something the panel can render without
 * re-deciding what it means.
 *
 * The reason this is a derivation module rather than a type cast: an answer from
 * a retrieval system carries a verdict *and* the evidence for the verdict, and a
 * panel that shows one without the other is worse than a panel that shows
 * neither. A ranked list with no scores reads as authoritative. A `high`
 * confidence badge with no reason cannot be disagreed with. So the model makes
 * both mandatory, and the component cannot render a score bar without the number
 * behind it.
 */

export type RetrievalConfidence = "high" | "low";

export type CodeResult = {
  id: string;
  label: string;
  kind: string;
  path: string;
  line: number;
  /** Combined rank, already normalised by the engine. */
  score: number;
  /**
   * The three signals, kept apart on purpose. A result that scores 0.8 on
   * keyword alone and one that scores 0.8 across all three are different claims,
   * and collapsing them into the total is exactly the information a reader needs
   * to judge a ranking they did not compute.
   */
  keywordScore: number;
  vectorScore: number;
  graphScore: number;
  /** How many distinct query terms this result actually matched. */
  matchedTerms: number;
};

export type CodeQueryModel = {
  query: string;
  embedder: string;
  generation: string;
  treeVerified: boolean;
  confidence: RetrievalConfidence;
  /**
   * Empty when confidence is `high`. Present and non-empty whenever it is
   * `low` — a verdict the reader cannot interrogate is one they can only obey.
   */
  confidenceReason: string;
  /** Nodes actually scored, and the corpus they were drawn from. */
  scanned: number;
  corpus: number;
  results: CodeResult[];
  /** Terms the query contributed, for showing which ones a result matched. */
  queryTermCount: number;
};

export class InvalidCodeQueryArtifact extends Error {}

const supportedSchema = "zgraphy.query.v4";

function record(value: unknown, context: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new InvalidCodeQueryArtifact(`${context} is not an object`);
  }
  return value as Record<string, unknown>;
}

function text(value: unknown, context: string): string {
  if (typeof value !== "string") throw new InvalidCodeQueryArtifact(`${context} is not a string`);
  return value;
}

function optionalText(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function count(value: unknown, context: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new InvalidCodeQueryArtifact(`${context} is not a number`);
  }
  return value;
}

/**
 * A score the panel is allowed to draw as a proportion of a bar.
 *
 * Clamped rather than trusted. The engine normalises, but this model is the
 * boundary between a Zig process and a layout that multiplies by a pixel width,
 * and a stray 1.4 would silently render a bar past its container rather than
 * announce a bad artifact.
 */
function unitScore(value: unknown, context: string): number {
  const raw = count(value, context);
  if (raw < 0) return 0;
  if (raw > 1) return 1;
  return raw;
}

function confidenceOf(value: unknown): RetrievalConfidence {
  if (value === "high" || value === "low") return value;
  throw new InvalidCodeQueryArtifact(`confidence "${String(value)}" is not one this build understands`);
}

/**
 * Number of distinct terms in `query`, matching how the engine tokenises for
 * `matched_terms` closely enough to say "2 of 3" rather than a bare "2".
 *
 * Deliberately approximate and deliberately only ever used as a denominator to
 * display: if it disagrees with the engine the worst case is a ratio that reads
 * oddly, not a result that ranks wrongly.
 */
export function queryTermCount(query: string): number {
  const terms = query
    .split(/[^A-Za-z0-9_]+/u)
    .map((term) => term.trim())
    .filter((term) => term.length > 0)
    .map((term) => term.toLowerCase());
  return new Set(terms).size;
}

export function deriveCodeQueryModel(raw: unknown): CodeQueryModel {
  const root = record(raw, "artifact");
  const schema = text(root.schema, "schema");
  if (schema !== supportedSchema) {
    throw new InvalidCodeQueryArtifact(`schema ${schema} is not ${supportedSchema}`);
  }

  const confidence = confidenceOf(root.confidence);
  const confidenceReason = optionalText(root.confidence_reason);
  // A low verdict with no stated reason is the one combination the panel must
  // not render: it would show a warning the reader has no way to evaluate.
  if (confidence === "low" && confidenceReason.length === 0) {
    throw new InvalidCodeQueryArtifact("low confidence carries no reason");
  }

  const rawResults = root.results;
  if (!Array.isArray(rawResults)) throw new InvalidCodeQueryArtifact("results is not an array");

  const query = text(root.query, "query");
  return {
    query,
    embedder: text(root.embedder, "embedder"),
    generation: optionalText(root.generation),
    treeVerified: root.tree_verified === true,
    confidence,
    confidenceReason,
    scanned: count(root.scanned, "scanned"),
    corpus: count(root.corpus, "corpus"),
    queryTermCount: queryTermCount(query),
    results: rawResults.map((entry, index) => {
      const item = record(entry, `results[${index}]`);
      return {
        // Node ids exceed Number.MAX_SAFE_INTEGER — they are 64-bit hashes — so
        // they are carried as text. Parsing one to a number would collide
        // distinct symbols in the key of a list.
        id: String(item.id ?? index),
        label: text(item.label, `results[${index}].label`),
        kind: text(item.kind, `results[${index}].kind`),
        path: optionalText(item.path),
        line: typeof item.line === "number" ? item.line : 0,
        score: unitScore(item.score, `results[${index}].score`),
        keywordScore: unitScore(item.keyword_score, `results[${index}].keyword_score`),
        vectorScore: unitScore(item.vector_score, `results[${index}].vector_score`),
        graphScore: unitScore(item.graph_score, `results[${index}].graph_score`),
        matchedTerms: typeof item.matched_terms === "number" ? item.matched_terms : 0,
      };
    }),
  };
}

/**
 * Whether the answer is bounded rather than exhaustive, and what to say about it.
 *
 * Two independent bounds, and they mean different things. The scan was bounded
 * if fewer nodes were scored than exist — the engine generates candidates from
 * postings plus one hop, so this is normal and is the reason a query is fast,
 * but a reader comparing "3 results" against "the whole repository" is drawing
 * the wrong conclusion. The list is bounded if it came back exactly full, in
 * which case a further result may exist and was never shown.
 */
export const CODE_QUERY_LIMIT = 8;

/**
 * The answer to show, from whichever source is attached.
 *
 * Same shape as the other receipt loaders: a `?code=` override for pointing at a
 * captured answer, and a bundled sample otherwise. The sample is a real
 * `zgraphy query --json` capture, so a drift in the engine's JSON breaks the
 * panel's tests rather than only its rendering.
 */
export async function loadCodeQuery(): Promise<CodeQueryModel> {
  const params = new URLSearchParams(typeof window === "undefined" ? "" : window.location.search);
  const path = params.get("code") ?? "sample-repository-query.json";
  const response = await fetch(path);
  if (!response.ok) throw new Error(`failed to load repository query (${response.status})`);
  return deriveCodeQueryModel(JSON.parse(await response.text()) as unknown);
}

export function truncationNotice(model: CodeQueryModel, limit: number): string {
  const bounded: string[] = [];
  if (model.results.length >= limit) {
    bounded.push(`showing the top ${limit} — raise the limit to see more`);
  }
  if (model.corpus > 0 && model.scanned < model.corpus) {
    const share = Math.max(1, Math.round((model.scanned / model.corpus) * 100));
    bounded.push(`scored ${model.scanned} of ${model.corpus} nodes (${share}%) — candidates, not the whole graph`);
  }
  return bounded.join("; ");
}
