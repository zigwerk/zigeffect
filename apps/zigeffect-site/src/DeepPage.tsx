import ArrowRight from "lucide-solid/icons/arrow-right";
import CheckCircle2 from "lucide-solid/icons/circle-check-big";
import type { JSX } from "solid-js";
import { onCleanup, onMount } from "solid-js";
import { MarketingFooter, MarketingHeader, NextChapter, type MarketingRoute } from "./MarketingChrome";

interface DeepPageProps {
  readonly current: MarketingRoute;
  readonly eyebrow: string;
  readonly title: JSX.Element;
  readonly lede: string;
  readonly visual: JSX.Element;
  readonly facts: readonly string[];
  readonly children: JSX.Element;
  readonly next: { readonly eyebrow: string; readonly title: string; readonly copy: string; readonly href: string; readonly label: string };
  readonly primary?: { readonly href: string; readonly label: string };
}

export function DeepPage(props: DeepPageProps) {
  onMount(() => {
    const targets = document.querySelectorAll<HTMLElement>("[data-reveal]");
    if (!("IntersectionObserver" in window)) {
      targets.forEach((target) => target.classList.add("is-visible"));
      return;
    }
    const observer = new IntersectionObserver((entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      }
    }, { threshold: 0.08, rootMargin: "0px 0px -4%" });
    targets.forEach((target) => observer.observe(target));
    onCleanup(() => observer.disconnect());
  });

  return (
    <div class="site-shell deep-page">
      <MarketingHeader current={props.current} />
      <main>
        <section class="deep-hero">
          <div class="deep-hero-copy">
            <p class="section-kicker">{props.eyebrow}</p>
            <h1>{props.title}</h1>
            <p>{props.lede}</p>
            <div class="hero-actions">
              <a class="button button-primary" href={props.primary?.href ?? "#story"}>{props.primary?.label ?? "Follow the story"} <ArrowRight size={17} /></a>
              <a class="button button-secondary" href="/how-it-works">Start with the overview <ArrowRight size={17} /></a>
            </div>
          </div>
          <div class="deep-hero-visual">{props.visual}</div>
        </section>

        <div class="deep-proof-strip" aria-label="Chapter summary">
          {props.facts.map((fact) => <span><CheckCircle2 size={16} /><strong>{fact}</strong></span>)}
        </div>

        <div id="story">{props.children}</div>
        <NextChapter {...props.next} />
      </main>
      <MarketingFooter />
    </div>
  );
}

export function CodeWindow(props: { readonly label: string; readonly badge?: string; readonly children: JSX.Element }) {
  return (
    <figure class="code-window">
      <figcaption><span>{props.label}</span>{props.badge && <strong>{props.badge}</strong>}</figcaption>
      <pre><code>{props.children}</code></pre>
    </figure>
  );
}

export function SectionHeading(props: { readonly eyebrow: string; readonly title: string; readonly copy: string }) {
  return (
    <div class="deep-section-heading" data-reveal>
      <p class="section-kicker">{props.eyebrow}</p>
      <h2>{props.title}</h2>
      <p>{props.copy}</p>
    </div>
  );
}

