import {
  Activity,
  ArrowRight,
  Bot,
  Braces,
  Check,
  Cloud,
  Code2,
  Database,
  GitBranch,
  Layers3,
  Menu,
  Network,
  ShieldCheck,
  Sparkles,
  SquareTerminal,
  Workflow,
  X,
} from "lucide-solid";
import { createSignal, onCleanup, onMount, Show } from "solid-js";
import { HeroCarousel } from "./HeroCarousel";

const navItems = [
  { label: "How it works", href: "/how-it-works" },
  { label: "Runtime", href: "/runtime" },
  { label: "Testing", href: "/testing" },
  { label: "Agents", href: "/agents" },
  { label: "Stdlib", href: "/standard-library" },
  { label: "Workflows", href: "/workflows" },
  { label: "Built with it", href: "/built-with" },
] as const;

const capabilities = [
  { icon: Braces, title: "Typed effects", copy: "Success, failure and required services stay explicit from source to runtime." },
  { icon: Layers3, title: "Scoped resources", copy: "Fibers, connections and finalizers remain attached to a visible ownership model." },
  { icon: GitBranch, title: "Causal evidence", copy: "Every important action records what happened, why, and what it caused next." },
  { icon: Workflow, title: "Durable statecharts", copy: "Long-lived workflows stay typed, replayable, inspectable and governable." },
  { icon: ShieldCheck, title: "Testing v2", copy: "Deterministic scenarios publish complete receipts with exact replay evidence." },
  { icon: Network, title: "Real boundaries", copy: "HTTP, Postgres, storage, transport, telemetry, Redis and S3 run through typed adapters." },
] as const;

export function ProductLanding() {
  const [menuOpen, setMenuOpen] = createSignal(false);

  onMount(() => {
    const revealTargets = document.querySelectorAll<HTMLElement>("[data-reveal]");
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      },
      { threshold: 0.12, rootMargin: "0px 0px -5%" },
    );
    revealTargets.forEach((target) => observer.observe(target));
    onCleanup(() => observer.disconnect());
  });

  return (
    <div class="site-shell">
      <header class="site-header">
        <a class="brand" href="/" aria-label="ZigEffect home">
          <span class="brand-mark"><Layers3 size={24} strokeWidth={1.8} /></span>
          <span>ZigEffect</span>
        </a>

        <nav class="desktop-nav" aria-label="Primary navigation">
          {navItems.map((item) => <a href={item.href}>{item.label}</a>)}
        </nav>

        <div class="header-actions">
          <a class="header-link" href="/causal-graph">Causal graph</a>
          <a class="button button-primary button-small" href="/how-it-works#first-project">
            Get started <ArrowRight size={16} />
          </a>
          <button
            class="menu-button"
            type="button"
            aria-label={menuOpen() ? "Close navigation" : "Open navigation"}
            aria-expanded={menuOpen()}
            onClick={() => setMenuOpen(!menuOpen())}
          >
            {menuOpen() ? <X size={21} /> : <Menu size={21} />}
          </button>
        </div>
      </header>

      <Show when={menuOpen()}>
        <nav class="mobile-nav" aria-label="Mobile navigation">
          {navItems.map((item) => <a href={item.href} onClick={() => setMenuOpen(false)}>{item.label}</a>)}
          <a href="/causal-graph" onClick={() => setMenuOpen(false)}>Causal graph</a>
        </nav>
      </Show>

      <main>
        <HeroCarousel />

        <section class="foundation-section section" id="foundation">
          <div class="section-inner foundation-grid" data-reveal>
            <div>
              <p class="section-kicker">STANDING ON THE SHOULDERS OF GIANTS</p>
              <h2>Human-made foundations.<br /><span>Agent-scale leverage.</span></h2>
            </div>
            <div class="foundation-copy">
              <p class="lead">Zig was made by humans. That matters.</p>
              <p>
                Its explicit memory, direct control and small language surface give us a core we can inspect and trust.
                We love that foundation. ZigEffect does not replace it—it builds an agent-readable runtime around it.
              </p>
              <p>
                The result is a novel assembly of typed effects, structured concurrency, causal graphs, deterministic
                testing and production adapters. Familiar ideas, combined for a new kind of development loop.
              </p>
              <a class="text-link" href="/runtime">See what the runtime adds <ArrowRight size={16} /></a>
            </div>
          </div>
        </section>

        <section class="runtime-section section" id="runtime">
          <div class="section-inner" data-reveal>
            <div class="section-heading section-heading-light">
              <p class="section-kicker">NOT ANOTHER AI WRAPPER</p>
              <h2>The runtime is the difference.</h2>
              <p>Agents do not need more prose. They need a system that exposes typed intent, live structure and replayable evidence.</p>
            </div>

            <div class="runtime-flow" id="architecture">
              <div class="runtime-step">
                <span><Bot size={20} /></span>
                <small>01</small>
                <strong>Agent intent</strong>
                <p>A requirement, acceptance check and bounded authority.</p>
              </div>
              <ArrowRight class="runtime-arrow" size={20} />
              <div class="runtime-step">
                <span><Code2 size={20} /></span>
                <small>02</small>
                <strong>Typed program</strong>
                <p>Effects, errors, services and resource ownership compile together.</p>
              </div>
              <ArrowRight class="runtime-arrow" size={20} />
              <div class="runtime-step">
                <span><Activity size={20} /></span>
                <small>03</small>
                <strong>Causal execution</strong>
                <p>Scopes, fibers, retries and external boundaries become queryable facts.</p>
              </div>
              <ArrowRight class="runtime-arrow" size={20} />
              <div class="runtime-step">
                <span><ShieldCheck size={20} /></span>
                <small>04</small>
                <strong>Verified receipt</strong>
                <p>Complete evidence, zero hidden pending work and an exact replay path.</p>
              </div>
            </div>

            <div class="runtime-proof">
              <code><span>const</span> program = Effect.fromFn(run);</code>
              <div>
                <span><Check size={14} /> requirements 12/12</span>
                <span><Check size={14} /> pending fibers 0</span>
                <span><Check size={14} /> leaks 0</span>
                <span><Check size={14} /> replay ready</span>
              </div>
            </div>
          </div>
        </section>

        <section class="system-layer-section section" id="system-building">
          <div class="section-inner" data-reveal>
            <div class="section-heading">
              <p class="section-kicker">THE SYSTEM-BUILDING LAYER</p>
              <h2>Agents should assemble systems,<br /><span>not rediscover plumbing.</span></h2>
              <p>ZigEffect combines a broad typed standard library with durable control flow, so an agent can move from a requirement to a complete multi-service backend without inventing a new pattern at every boundary.</p>
            </div>

            <div class="system-layer-grid">
              <article class="system-layer-card">
                <div class="system-layer-index">01 / STANDARD LIBRARY</div>
                <SquareTerminal size={27} />
                <h3>40+ modules. One effect model.</h3>
                <p>Services, schemas, HTTP, SQL, files, processes, queues, pub/sub, outbox, storage, config, secrets, resilience, observability, testing and agent tooling share one public facade.</p>
                <div class="system-module-rail"><span>Http</span><span>Sql</span><span>Queue</span><span>Storage</span><span>Testing</span></div>
                <a class="text-link" href="/standard-library">Explore the standard library <ArrowRight size={16} /></a>
              </article>

              <article class="system-layer-card system-layer-card-dark">
                <div class="system-layer-index">02 / DURABLE CONTROL FLOW</div>
                <Workflow size={27} />
                <h3>State machines that survive reality.</h3>
                <p>Typed statecharts, activities, timers, signals, queues, actors, journals, recovery and governed control make long-lived work visible to both operators and agents.</p>
                <div class="system-state-rail"><span>received</span><span>waiting</span><span>recovered</span><strong>complete</strong></div>
                <a class="text-link text-link-light" href="/workflows">See durable workflows <ArrowRight size={16} /></a>
              </article>
            </div>

            <div class="assembly-thesis">
              <GitBranch size={22} />
              <p><strong>The novel part is the assembly.</strong> Familiar systems ideas become one agent-readable path from typed intent, through efficient execution and durable coordination, to causal diagnosis and deterministic proof.</p>
            </div>
          </div>
        </section>

        <section class="built-section section" id="built-with">
          <div class="section-inner" data-reveal>
            <div class="section-heading">
              <p class="section-kicker">BUILT WITH ZIGEFFECT</p>
              <h2>Not a future demo.<br /><span>Our actual systems.</span></h2>
              <p>ZigEffect is being shaped by the demands of products that cross application, infrastructure and cloud boundaries.</p>
            </div>

            <div class="product-proof-list">
              <article class="product-proof">
                <div class="product-index">01</div>
                <div class="product-name">
                  <span class="product-icon"><Cloud size={23} /></span>
                  <div><h3>Ziac</h3><p>Agent-native Google Cloud infrastructure.</p></div>
                </div>
                <div class="product-domains">
                  <span>Infrastructure</span><span>Cloud</span><span>Provider RPC</span>
                </div>
                <p class="product-description">
                  Ziac uses typed plans, causal deployment evidence and specialist agents to build and operate global cloud systems without losing control of what changes.
                </p>
                <a href="/built-with" aria-label="Read the Ziac proof">Read the proof <ArrowRight size={16} /></a>
              </article>

              <article class="product-proof">
                <div class="product-index">02</div>
                <div class="product-name">
                  <span class="product-icon"><Database size={23} /></span>
                  <div><h3>Yachdee</h3><p>A real multi-service product platform.</p></div>
                </div>
                <div class="product-domains">
                  <span>Backend</span><span>Infrastructure</span><span>Cloud</span>
                </div>
                <p class="product-description">
                  Yachdee exercises the full application path: HTTP services, durable workflows, PostgreSQL, object storage, telemetry and agent-verifiable release evidence.
                </p>
                <a href="/built-with" aria-label="Read the Yachdee proof">Read the proof <ArrowRight size={16} /></a>
              </article>
            </div>
          </div>
        </section>

        <section class="vision-section section" id="vision">
          <div class="section-inner vision-grid" data-reveal>
            <div class="vision-statement">
              <p class="section-kicker">THE NEXT BACKEND ERA</p>
              <h2>The backend after <span class="orange-underline">JavaScript</span>.</h2>
              <p class="vision-lead">
                Our vision is simple: JavaScript stops being the default backend language because agents remove the old productivity tradeoff.
              </p>
            </div>

            <div class="vision-copy">
              <p>
                Tokens are cheap. Explicit systems code is valuable. Zig can be repetitive and boilerplate-heavy—but writing clear,
                efficient, repetitive code is exactly what language models are good at.
              </p>
              <p>
                The missing piece was never typing speed. It was the runtime and tooling required for agents to diagnose the hardest
                failures, understand ownership and concurrency, and prove that a repair made the system better.
              </p>
              <blockquote>
                Let agents write the repetition. Let Zig keep the machine honest.
              </blockquote>
            </div>
          </div>

          <div class="section-inner economics-grid" data-reveal>
            <div><strong>01</strong><h3>Cheap generation</h3><p>Agents absorb the cost of explicit types, adapters and repetitive boundary code.</p></div>
            <div><strong>02</strong><h3>Efficient execution</h3><p>Programs keep Zig's small binaries, direct control and predictable resource use.</p></div>
            <div><strong>03</strong><h3>Evidence-rich debugging</h3><p>Causal graphs turn difficult runtime behavior into bounded, queryable facts.</p></div>
            <div><strong>04</strong><h3>Compounding trust</h3><p>Every accepted change leaves deterministic tests, receipts and replay behind.</p></div>
          </div>
        </section>

        <section class="capabilities-section section" id="agents">
          <div class="section-inner" data-reveal>
            <div class="section-heading compact-heading">
              <p class="section-kicker">ONE COHERENT DEVELOPMENT SYSTEM</p>
              <h2>Everything an agent needs to do serious backend work.</h2>
            </div>
            <div class="capability-list">
              {capabilities.map((capability, index) => {
                const Icon = capability.icon;
                return (
                  <article>
                    <span class="capability-number">0{index + 1}</span>
                    <Icon size={21} />
                    <h3>{capability.title}</h3>
                    <p>{capability.copy}</p>
                  </article>
                );
              })}
            </div>
          </div>
        </section>

        <section class="start-section section" id="start">
          <div class="start-orbit" aria-hidden="true"><Sparkles size={28} /></div>
          <div class="section-inner start-grid" data-reveal>
            <div>
              <p class="section-kicker">START WITH A REAL SYSTEM</p>
              <h2>Build the backend<br />agents were waiting for.</h2>
            </div>
            <div>
              <p>Run the reference application, inspect its causal graph, break a boundary and replay the repair with complete evidence.</p>
              <div class="start-actions">
                <a class="button button-light" href="/how-it-works#first-project">Open the quickstart <ArrowRight size={17} /></a>
                <a class="text-link text-link-light" href="/causal-graph">Read the architecture <ArrowRight size={16} /></a>
              </div>
            </div>
          </div>
        </section>
      </main>

      <footer class="site-footer">
        <a class="brand footer-brand" href="/"><span class="brand-mark"><Layers3 size={21} /></span> ZigEffect</a>
        <p>Built with AI. Grounded in Zig.</p>
        <div><a href="/runtime">Runtime</a><a href="/built-with">Proof</a><a href="/how-it-works">How it works</a></div>
      </footer>
    </div>
  );
}
