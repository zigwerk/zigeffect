import CircleDot from "lucide-solid/icons/circle-dot";
import GitBranch from "lucide-solid/icons/git-branch";
import Search from "lucide-solid/icons/search";
import ShieldCheck from "lucide-solid/icons/shield-check";
import TerminalSquare from "lucide-solid/icons/square-terminal";
import { CodeWindow, DeepPage, SectionHeading } from "./DeepPage";

export function CausalGraphPage() {
  return (
    <DeepPage
      current="causal-graph"
      eyebrow="THE CAUSAL GRAPH"
      title={<>Ask the runtime <span>why.</span></>}
      lede="Logs tell you what was printed. The causal graph records what owned what, which event caused the next one, where a retry came from, and whether the evidence is complete."
      facts={["Queryable relationships", "Minimal causal paths", "Redacted by default", "Completeness disclosed"]}
      visual={<div class="causal-mini"><span>request</span><span>scope</span><span>fiber</span><span class="is-selected">SQL timeout</span><span>retry</span><span>success</span><strong>cause_event_id → exact lineage</strong></div>}
      next={{ eyebrow: "NEXT / PROOF", title: "Turn evidence into a deterministic test.", copy: "Testing v2 binds requirements, failures, assertions, and exact replay into one native receipt.", href: "/testing", label: "Explore Testing v2" }}
    >
      <section class="deep-section"><SectionHeading eyebrow="01 / FROM SCROLLBACK TO STRUCTURE" title="A timestamp is not a relationship." copy="Text logs are useful, but they make the reader reconstruct ownership and causality. ZigEffect emits compact structural events for runs, scopes, fibers, services, resources, retries, exits, and findings into one graph." /><div class="compare-grid" data-reveal><article class="log-wall"><h3>Log archaeology</h3><code>10:14:03 retrying request</code><code>10:14:03 database timeout</code><code>10:14:03 scope closed</code><code>10:14:03 request failed</code><p>Which timeout caused which retry? Which scope owned the transaction?</p></article><article class="causal-answer"><h3>Minimal causal path</h3><ol><li><CircleDot size={14} /> request checkout-184</li><li><CircleDot size={14} /> transaction acquired by scope-12</li><li><CircleDot size={14} /> SQL timeout caused retry-2</li><li><CircleDot size={14} /> transaction finalized</li></ol><p>The relationships are stored, not inferred.</p></article></div></section>
      <section class="deep-band deep-band-dark"><div class="deep-band-inner"><SectionHeading eyebrow="02 / ASK PRECISE QUESTIONS" title="The graph is an interface for agents." copy="Instead of pasting thousands of lines into a model, an agent asks bounded questions and receives the smallest useful answer with stable event identities." /><div class="query-grid" data-reveal><code><Search size={16} /> cause 43</code><code><GitBranch size={16} /> lineage 43</code><code><TerminalSquare size={16} /> fibers pending</code><code><Search size={16} /> resources leaked</code><code><Search size={16} /> retries checkout-184</code><code><ShieldCheck size={16} /> findings</code></div></div></section>
      <section class="deep-section"><SectionHeading eyebrow="03 / THE EVENT CONTRACT" title="Each fact keeps enough context to be useful." copy="Events carry run_id, parent_id, fiber_id, scope_id, cause_event_id, boundary references, source references, and typed outcome details where they apply. Identifiers connect a finding to the code and runtime owner responsible for it." /><CodeWindow label="zigeffect.causal.v1" badge="bounded + redacted">{`{
  "event_id": "43",
  "kind": "retry_decision",
  "run_id": "checkout-184",
  "scope_id": "12",
  "fiber_id": "7",
  "cause_event_id": "41",
  "decision": "retry",
  "source": "checkout/payment.zig:88"
}`}</CodeWindow></section>
      <section class="deep-section deep-section-warm"><SectionHeading eyebrow="04 / HONEST EVIDENCE" title="The graph tells you when it cannot tell the whole story." copy="Artifacts disclose max events, dropped events, sampled events, and truncated fields. Routine sampleable detail can be bounded; finding evidence is never sampled. If required evidence was dropped or truncated, an agent must treat the answer as incomplete." /><div class="honesty-grid" data-reveal><article><strong>Retained</strong><span>1,204 events</span><p>Within the configured evidence budget.</p></article><article><strong>Sampled</strong><span>routine detail only</span><p>Never the evidence supporting a finding.</p></article><article><strong>Truncated</strong><span>0 required fields</span><p>Any required loss remains visible.</p></article></div></section>
    </DeepPage>
  );
}

