import Cloud from "lucide-solid/icons/cloud";
import Database from "lucide-solid/icons/database";
import Globe2 from "lucide-solid/icons/earth";
import Network from "lucide-solid/icons/network";
import ServerCog from "lucide-solid/icons/server-cog";
import ShieldCheck from "lucide-solid/icons/shield-check";
import { DeepPage, SectionHeading } from "./DeepPage";

export function BuiltWithPage() {
  return (
    <DeepPage
      current="built-with"
      eyebrow="BUILT WITH ZIGEFFECT"
      title={<>Not a toy benchmark. <span>Our actual systems.</span></>}
      lede="Ziac and Yachdee are the pressure behind ZigEffect: infrastructure and application products spanning agents, HTTP, Provider RPC, databases, object storage, workflows, telemetry, deployment, and cloud operations."
      facts={["Backend", "Infrastructure", "Cloud", "Deterministic proof"]}
      visual={<div class="product-spine"><span>Ziac infrastructure</span><strong>ZigEffect runtime + evidence</strong><span>Yachdee backend</span><i>Testing v2 closes both loops</i></div>}
      next={{ eyebrow: "START THE STORY AGAIN", title: "One runtime. One visible development loop.", copy: "Return to the complete overview and follow a change from requirement to verified replay.", href: "/how-it-works", label: "How ZigEffect works" }}
    >
      <section class="deep-section"><SectionHeading eyebrow="01 / ZIAC" title="Agent-native infrastructure without losing the graph." copy="Ziac uses ZigEffect to model infrastructure intent, provider boundaries, saved plans, capabilities, rollout events, causal diagnosis, and verification as one governed system." /><div class="case-study" data-reveal><div class="case-copy"><span class="case-index">01</span><h3>Infrastructure as compiled intent.</h3><p>A specialist agent can inspect a Google Cloud estate, compile a typed plan, preflight APIs and IAM, simulate rollout and recovery, and request application of the exact approved digest.</p><ul><li><Cloud size={17} /> Global Cloud Run and load balancing</li><li><Network size={17} /> IAM, VPC, DNS, traffic, and dependency graphs</li><li><ServerCog size={17} /> Provider RPC and bounded apply authority</li><li><ShieldCheck size={17} /> Causal deployment and verification receipts</li></ul></div><figure class="case-image"><img src="/assets/ziac-operations.png" alt="Ziac operations dashboard showing an agent session, infrastructure graph, deployment progress, and causal evidence." loading="lazy" /><figcaption>Real Ziac operations surface · shared graph and causal evidence</figcaption></figure></div></section>
      <section class="deep-band deep-band-dark"><div class="deep-band-inner"><SectionHeading eyebrow="02 / YACHDEE" title="A real multi-service application path." copy="Yachdee exercises the product side: Cloudflare request boundaries, typed application services, CockroachDB, object storage, offline sync, durable processes, infrastructure, and release evidence." /><div class="yachdee-map" data-reveal><span><Globe2 size={20} /><strong>Cloudflare edge</strong><small>HTTP + auth + routing</small></span><span><ServerCog size={20} /><strong>Zig services</strong><small>effects + scopes + fibers</small></span><span><Database size={20} /><strong>CockroachDB</strong><small>canonical application data</small></span><span><Cloud size={20} /><strong>R2 + cloud</strong><small>objects + infrastructure</small></span><span><ShieldCheck size={20} /><strong>Testing v2</strong><small>release evidence</small></span></div></div></section>
      <section class="deep-section deep-section-warm"><SectionHeading eyebrow="03 / ONE PRESSURE TEST" title="Backend, infrastructure, and cloud should not become three agent languages." copy="The same typed effects, service environments, ownership rules, causal vocabulary, deterministic scenarios, and receipt model cross the stack. The adapters change; the way an agent reasons does not." /><div class="pressure-grid" data-reveal><article><strong>Application</strong><p>Requests, data, storage, background work, and user-visible outcomes.</p></article><article><strong>Infrastructure</strong><p>Plans, dependencies, providers, rollout, policy, and recovery.</p></article><article><strong>Operations</strong><p>Live events, findings, causal paths, repairs, replay, and handoff.</p></article></div></section>
      <section class="deep-section"><SectionHeading eyebrow="04 / WHAT THIS PROVES" title="Real use exposes the missing pieces." copy="These products do not prove every workload or platform. They force the framework to confront ordinary production concerns: ownership, failure, concurrency, external systems, long-lived work, change authority, evidence budgets, and developer experience." /><div class="honesty-card" data-reveal><ShieldCheck size={26} /><div><h3>The proof is cumulative.</h3><p>Every delivered boundary adds a compile-tested adapter, deterministic scenario, causal vocabulary, receipt contract, and real application pressure—not a slide claiming the problem is solved.</p></div></div></section>
    </DeepPage>
  );
}

