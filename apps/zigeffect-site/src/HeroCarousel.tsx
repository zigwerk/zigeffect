import {
  ArrowLeft,
  ArrowRight,
  CheckCircle2,
  Pause,
  Play,
} from "lucide-solid";
import {
  createEffect,
  createSignal,
  For,
  onCleanup,
  onMount,
  Show,
} from "solid-js";

interface HeroSlide {
  readonly id: "repair" | "inspect" | "ship";
  readonly number: string;
  readonly label: string;
  readonly tabLabel: string;
  readonly beforeAccent: string;
  readonly accent: string;
  readonly afterAccent: string;
  readonly body: string;
  readonly note: string;
  readonly image: string;
  readonly imageAlt: string;
  readonly primaryLabel: string;
  readonly primaryHref: string;
  readonly secondaryLabel: string;
  readonly secondaryHref: string;
  readonly nextLabel: string;
}

const slides: readonly HeroSlide[] = [
  {
    id: "repair",
    number: "01",
    label: "CAUSAL REPAIR LOOP",
    tabLabel: "Repair",
    beforeAccent: "Agents don't guess. They ",
    accent: "repair from evidence",
    afterAccent: ".",
    body: "An agent asks why checkout failed, follows one causal path to the responsible boundary, applies a typed repair and replays the exact failure until the receipt is complete.",
    note: "Query · causal trace · typed patch · deterministic replay",
    image: "/assets/hero-causal-repair.png",
    imageAlt: "A five-stage causal repair loop from an agent query through a failing checkout trace, typed patch, successful replay and verified receipt",
    primaryLabel: "Follow the evidence",
    primaryHref: "/causal-graph",
    secondaryLabel: "See Testing v2",
    secondaryHref: "/testing",
    nextLabel: "Next: inspect the minimal causal path",
  },
  {
    id: "inspect",
    number: "02",
    label: "AGENT MICROSCOPE",
    tabLabel: "Inspect",
    beforeAccent: "Ask the runtime ",
    accent: "why",
    afterAccent: ".",
    body: "One query narrows request, scope, fiber, HTTP, SQL and finalizer activity into the minimal root-cause path—with the owning source line and repaired replay beside it.",
    note: "Minimal causal path · source reference · repaired replay",
    image: "/assets/hero-agent-microscope.png",
    imageAlt: "A causal execution timeline for order 184 with a failed transaction finalizer, minimal evidence path, source reference and passing replay",
    primaryLabel: "Explore causal evidence",
    primaryHref: "/causal-graph",
    secondaryLabel: "See the runtime",
    secondaryHref: "/runtime",
    nextLabel: "Next: carry intent all the way to proof",
  },
  {
    id: "ship",
    number: "03",
    label: "INTENT TO PROOF",
    tabLabel: "Ship",
    beforeAccent: "From intent to ",
    accent: "proof",
    afterAccent: ".",
    body: "A declared requirement becomes a capability-constrained Zig change, observable runtime behavior and deterministic Testing v2 proof—across Yachdee backend and Ziac deployment.",
    note: "Yachdee backend · Ziac deploy · Testing v2 proof",
    image: "/assets/hero-intent-to-proof.png",
    imageAlt: "A four-stage pipeline from a Yachdee checkout requirement through typed Zig and runtime evidence to Testing v2 proof and ready-to-ship verification",
    primaryLabel: "See how it works",
    primaryHref: "/how-it-works",
    secondaryLabel: "Built with ZigEffect",
    secondaryHref: "/built-with",
    nextLabel: "Restart: diagnose, repair and prove",
  },
] as const;

const AUTOPLAY_MS = 7_000;

export function HeroCarousel() {
  const [activeIndex, setActiveIndex] = createSignal(0);
  const [playing, setPlaying] = createSignal(true);
  const [reducedMotion, setReducedMotion] = createSignal(false);
  const activeSlide = () => slides[activeIndex()]!;

  const select = (index: number, pause = true) => {
    setActiveIndex((index + slides.length) % slides.length);
    if (pause) setPlaying(false);
  };

  const previous = () => select(activeIndex() - 1);
  const next = () => select(activeIndex() + 1);

  onMount(() => {
    const media = window.matchMedia("(prefers-reduced-motion: reduce)");
    const applyPreference = () => {
      setReducedMotion(media.matches);
      if (media.matches) setPlaying(false);
    };
    applyPreference();
    media.addEventListener("change", applyPreference);
    onCleanup(() => media.removeEventListener("change", applyPreference));
  });

  createEffect(() => {
    if (!playing() || reducedMotion()) return;
    const timer = window.setInterval(() => {
      setActiveIndex((current) => (current + 1) % slides.length);
    }, AUTOPLAY_MS);
    onCleanup(() => window.clearInterval(timer));
  });

  const handleKeyDown = (event: KeyboardEvent) => {
    if (event.key === "ArrowLeft") {
      event.preventDefault();
      previous();
    }
    if (event.key === "ArrowRight") {
      event.preventDefault();
      next();
    }
  };

  return (
    <section
      class="hero-carousel"
      id="top"
      aria-roledescription="carousel"
      aria-label="The ZigEffect story"
      tabindex="0"
      onKeyDown={handleKeyDown}
    >
      <div class="hero-slide-wrap" aria-live="polite" aria-atomic="true">
        <Show keyed when={activeSlide()}>
          {(slide) => (
            <article class="hero-slide" aria-label={`${slide.number} ${slide.label}`}>
              <div class="hero-copy">
                <p class="hero-kicker">{slide.number} / {slide.label}</p>
                <h1>
                  {slide.beforeAccent}
                  <span class="orange-underline">{slide.accent}</span>
                  {slide.afterAccent}
                </h1>
                <p class="hero-summary">{slide.body}</p>

                <div class="hero-actions">
                  <a class="button button-primary" href={slide.primaryHref}>
                    {slide.primaryLabel} <ArrowRight size={17} />
                  </a>
                  <a class="button button-secondary" href={slide.secondaryHref}>
                    {slide.secondaryLabel} <ArrowRight size={17} />
                  </a>
                </div>

                <p class="hero-note"><CheckCircle2 size={16} /> {slide.note}</p>

                <div class="story-tabs" role="tablist" aria-label="Choose a story chapter">
                  <For each={slides}>
                    {(item, index) => (
                      <button
                        type="button"
                        role="tab"
                        aria-selected={activeIndex() === index()}
                        aria-controls={`hero-panel-${item.id}`}
                        classList={{ "story-tab": true, "is-active": activeIndex() === index() }}
                        onClick={() => select(index())}
                      >
                        <span>{item.number}</span> {item.tabLabel}
                      </button>
                    )}
                  </For>
                </div>

                <div class="story-controls">
                  <button type="button" class="story-control" aria-label="Previous story" onClick={previous}>
                    <ArrowLeft size={17} />
                  </button>
                  <button type="button" class="story-control" aria-label="Next story" onClick={next}>
                    <ArrowRight size={17} />
                  </button>
                  <Show
                    when={playing()}
                    fallback={
                      <button type="button" class="story-control" aria-label="Play carousel" onClick={() => setPlaying(true)}>
                        <Play size={16} />
                      </button>
                    }
                  >
                    <button type="button" class="story-control" aria-label="Pause carousel" onClick={() => setPlaying(false)}>
                      <Pause size={16} />
                    </button>
                  </Show>
                </div>
              </div>

              <div class="hero-visual" id={`hero-panel-${slide.id}`} role="tabpanel">
                <img src={slide.image} alt={slide.imageAlt} width="1536" height="1024" />
              </div>
            </article>
          )}
        </Show>
      </div>

      <div class="hero-progress" aria-hidden="true">
        <For each={slides}>
          {(_, index) => (
            <span classList={{ "is-complete": index() < activeIndex(), "is-active": index() === activeIndex() }}>
              <i classList={{ "is-playing": playing() && !reducedMotion() }} />
            </span>
          )}
        </For>
        <p>{activeSlide().nextLabel} <ArrowRight size={16} /></p>
      </div>
    </section>
  );
}
