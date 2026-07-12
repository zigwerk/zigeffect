import ArrowRight from "lucide-solid/icons/arrow-right";
import Layers3 from "lucide-solid/icons/layers-3";
import Menu from "lucide-solid/icons/menu";
import X from "lucide-solid/icons/x";
import { createSignal, Show } from "solid-js";

export type MarketingRoute =
  | "product"
  | "how-it-works"
  | "why-zig"
  | "runtime"
  | "causal-graph"
  | "testing"
  | "agents"
  | "standard-library"
  | "workflows"
  | "built-with";

const navItems: readonly { label: string; href: string; route: MarketingRoute }[] = [
  { label: "How it works", href: "/how-it-works", route: "how-it-works" },
  { label: "Runtime", href: "/runtime", route: "runtime" },
  { label: "Testing", href: "/testing", route: "testing" },
  { label: "Agents", href: "/agents", route: "agents" },
  { label: "Stdlib", href: "/standard-library", route: "standard-library" },
  { label: "Workflows", href: "/workflows", route: "workflows" },
  { label: "Built with it", href: "/built-with", route: "built-with" },
] as const;

export function MarketingHeader(props: { readonly current: MarketingRoute }) {
  const [menuOpen, setMenuOpen] = createSignal(false);

  return (
    <>
      <header class="site-header">
        <a class="brand" href="/" aria-label="ZigEffect home">
          <span class="brand-mark"><Layers3 size={24} strokeWidth={1.8} /></span>
          <span>ZigEffect</span>
        </a>

        <nav class="desktop-nav" aria-label="Primary navigation">
          {navItems.map((item) => (
            <a href={item.href} aria-current={item.route === props.current ? "page" : undefined}>{item.label}</a>
          ))}
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
          {navItems.map((item) => (
            <a href={item.href} aria-current={item.route === props.current ? "page" : undefined} onClick={() => setMenuOpen(false)}>{item.label}</a>
          ))}
          <a href="/why-zig" onClick={() => setMenuOpen(false)}>Why Zig</a>
          <a href="/causal-graph" onClick={() => setMenuOpen(false)}>Causal graph</a>
          <a href="/workflows" onClick={() => setMenuOpen(false)}>Workflows</a>
        </nav>
      </Show>
    </>
  );
}

export function MarketingFooter() {
  return (
    <footer class="site-footer deep-footer">
      <a class="brand footer-brand" href="/"><span class="brand-mark"><Layers3 size={21} /></span> ZigEffect</a>
      <p>Built with AI. Grounded in Zig. Verified by evidence.</p>
      <div><a href="/how-it-works">How it works</a><a href="/standard-library">Stdlib</a><a href="/workflows">Workflows</a><a href="/built-with">Proof</a></div>
    </footer>
  );
}

export function NextChapter(props: { readonly eyebrow: string; readonly title: string; readonly copy: string; readonly href: string; readonly label: string }) {
  return (
    <section class="next-chapter">
      <div>
        <p class="section-kicker">{props.eyebrow}</p>
        <h2>{props.title}</h2>
      </div>
      <div>
        <p>{props.copy}</p>
        <a class="button button-light" href={props.href}>{props.label} <ArrowRight size={17} /></a>
      </div>
    </section>
  );
}
