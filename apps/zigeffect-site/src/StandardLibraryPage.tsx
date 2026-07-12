import Boxes from "lucide-solid/icons/boxes";
import Braces from "lucide-solid/icons/braces";
import CloudCog from "lucide-solid/icons/cloud-cog";
import Database from "lucide-solid/icons/database";
import GitBranch from "lucide-solid/icons/git-branch";
import Network from "lucide-solid/icons/network";
import ShieldCheck from "lucide-solid/icons/shield-check";
import Wrench from "lucide-solid/icons/wrench";
import { For } from "solid-js";
import { CodeWindow, DeepPage, SectionHeading } from "./DeepPage";

const moduleFamilies = [
  {
    index: "01",
    title: "Model the application",
    copy: "Typed services, schemas, capabilities and lifecycle boundaries give an agent a small, explicit vocabulary for application structure.",
    modules: ["Service", "Schema", "Capability", "Application", "Boundary"],
  },
  {
    index: "02",
    title: "Reach the outside world",
    copy: "HTTP, SQL, processes, files, workspaces and object storage expose fallible I/O through typed effects and replaceable layers.",
    modules: ["Http", "Sql", "Process", "FileSystem", "Workspace", "ObjectStorage"],
  },
  {
    index: "03",
    title: "Move and coordinate data",
    copy: "Streams, sinks, queues, pub/sub, brokers, caches and outboxes cover the ordinary plumbing of multi-service backends.",
    modules: ["Stream", "Sink", "Queue", "PubSub", "Broker", "Cache", "Outbox"],
  },
  {
    index: "04",
    title: "Control uncertainty",
    copy: "Deterministic time, randomness, identifiers and schedules combine with resilience policies instead of hiding retries in ad hoc loops.",
    modules: ["Clock", "Randomness", "Ids", "Schedule", "Resilience"],
  },
  {
    index: "05",
    title: "Operate with evidence",
    copy: "Config, secrets, logging, observability and the causal graph make boundaries inspectable without leaking sensitive values into evidence.",
    modules: ["Config", "Secrets", "Console", "Observability", "CausalGraph", "Security"],
  },
  {
    index: "06",
    title: "Develop with agents",
    copy: "Project contracts, agent sessions, deterministic testing and safety checks turn generated code into a governed engineering loop.",
    modules: ["Project", "Agent", "Testing", "Safety", "Cli", "Statechart"],
  },
] as const;

export function StandardLibraryPage() {
  return (
    <DeepPage
      current="standard-library"
      eyebrow="ZIGEFFECT STANDARD LIBRARY"
      title={<>The parts of a backend, <span>already speaking effects.</span></>}
      lede="40+ public modules give agents one coherent, typed surface for application structure, I/O, data, reliability, operations, testing, and long-lived control flow."
      facts={["40+ public modules", "Typed boundaries", "Deterministic fakes", "Production adapters"]}
      visual={<div class="stdlib-mini"><strong>zigeffect_std</strong><div><span>Service</span><span>Http</span><span>Sql</span><span>Queue</span><span>Testing</span><span>Statechart</span></div><i>one public facade · one effect model</i></div>}
      primary={{ href: "#module-families", label: "Explore the modules" }}
      next={{ eyebrow: "NEXT / LONG-LIVED WORK", title: "Now give the system durable control flow.", copy: "See how journals, activities, signals, queues, actors, and typed statecharts carry work across time, failure, and deployment.", href: "/workflows", label: "Explore durable workflows" }}
    >
      <section class="deep-section">
        <SectionHeading
          eyebrow="01 / THE ASSEMBLY"
          title="One coherent vocabulary for a whole backend."
          copy="Agents are excellent at explicit, repetitive composition when the pieces follow the same rules. ZigEffect's library makes success, failure, requirements, resources, fakes, and evidence look consistent from HTTP ingress to SQL, queues, storage, and tests."
        />
        <div class="assembly-flow" data-reveal>
          <span><Braces size={20} /><strong>Typed intent</strong><small>service + schema</small></span>
          <span><Network size={20} /><strong>System boundary</strong><small>HTTP + SQL + storage</small></span>
          <span><GitBranch size={20} /><strong>Causal evidence</strong><small>facts + ownership</small></span>
          <span><ShieldCheck size={20} /><strong>Verified result</strong><small>test + receipt</small></span>
        </div>
      </section>

      <section class="deep-band deep-band-dark" id="module-families">
        <div class="deep-band-inner">
          <SectionHeading
            eyebrow="02 / PUBLIC SURFACE"
            title="Organized around jobs, not framework trivia."
            copy="The library is broad because real systems are broad. The important constraint is that each family enters through a public facade and participates in the same typed effect, layer, scope, and evidence model."
          />
          <div class="module-matrix" data-reveal>
            <For each={moduleFamilies}>
              {(family) => (
                <article>
                  <span>{family.index}</span>
                  <h3>{family.title}</h3>
                  <p>{family.copy}</p>
                  <ul>{family.modules.map((name) => <li>{name}</li>)}</ul>
                </article>
              )}
            </For>
          </div>
        </div>
      </section>

      <section class="deep-section">
        <SectionHeading
          eyebrow="03 / NORMAL ZIG"
          title="The facade stays small at the call site."
          copy="An agent imports one library, asks the environment for the capabilities a function needs, and composes ordinary Zig values. Tests replace those layers with deterministic providers without rewriting the program."
        />
        <div class="two-column-example">
          <CodeWindow label="orders/service.zig" badge="public facade">{`const zstd = @import("zigeffect_std");
const fx = zstd.fx;

const PlaceOrder = fx.Effect(Order, PlaceOrderError, AppEnv)
    .fromFn(placeOrder)
    .requires(.{ CustomerStore, Inventory, OrderStore });

const appLayer = fx.Layer(AppEnv)
    .fromEnv(&env)
    .provides(.{ CustomerStore, Inventory, OrderStore });

const order = try appLayer.provide(allocator, PlaceOrder);`}</CodeWindow>
          <div class="plain-card">
            <Boxes size={25} />
            <h3>The repetition becomes an advantage.</h3>
            <p>Every service exposes the same visible shape: input schema, typed errors, required environment, resource scope, external facts, and deterministic test layer.</p>
            <strong>An agent learns the pattern once, then applies it across the system.</strong>
          </div>
        </div>
      </section>

      <section class="deep-section deep-section-warm">
        <SectionHeading
          eyebrow="04 / REAL BOUNDARIES"
          title="The same program runs against fakes and production adapters."
          copy="HTTP, SQL, clock, IDs, storage, process, and broker capabilities are dependencies rather than hidden globals. Local tests get deterministic implementations; deployed services receive adapters with explicit configuration and capability descriptors."
        />
        <div class="adapter-lanes" data-reveal>
          <article><Wrench size={22} /><span>Development</span><h3>Deterministic layer</h3><p>In-memory stores, virtual time, seeded identifiers, bounded faults, and captured evidence.</p></article>
          <article><Database size={22} /><span>Integration</span><h3>Real boundary layer</h3><p>PostgreSQL, HTTP, object storage, broker, process, and telemetry adapters under controlled authority.</p></article>
          <article><CloudCog size={22} /><span>Production</span><h3>Declared posture</h3><p>Configuration, secrets, limits, health, capability maturity, and operational evidence stay inspectable.</p></article>
        </div>
        <p class="boundary-note"><ShieldCheck size={18} /> Adapters declare their production posture. A shared interface does not pretend every provider has identical guarantees or maturity.</p>
      </section>

      <section class="deep-section">
        <SectionHeading
          eyebrow="05 / WHY IT MATTERS FOR AGENTS"
          title="Stop making every agent invent the plumbing again."
          copy="A broad standard library reduces ambiguity at exactly the boundaries where generated systems usually become inconsistent: retries, cancellation, cleanup, serialization, secrets, I/O, testing, and operational evidence."
        />
        <div class="decision-grid" data-reveal>
          <article><Braces size={22} /><span>Generate</span><h3>Conventional code</h3><p>Scaffolds and public facades make structure predictable across components.</p></article>
          <article><GitBranch size={22} /><span>Diagnose</span><h3>Semantic boundaries</h3><p>The same modules emit causal facts an agent can query instead of reconstructing from logs.</p></article>
          <article><ShieldCheck size={22} /><span>Prove</span><h3>Deterministic substitutes</h3><p>Tests exercise the real program with controlled services, faults, clocks, and receipts.</p></article>
        </div>
      </section>
    </DeepPage>
  );
}
