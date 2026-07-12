import { describe, expect, test } from "bun:test";

async function source(relativePath: string): Promise<string> {
  const file = Bun.file(new URL(relativePath, import.meta.url));
  return (await file.exists()) ? file.text() : "";
}

const landingSource = await source("./ProductLanding.tsx");
const carouselSource = await source("./HeroCarousel.tsx");
const styleSource = await source("./styles.css");

describe("ZigEffect marketing site contract", () => {
  test("teaches the selected repair inspect and ship story through three carousel frames", () => {
    expect(carouselSource).toContain("CAUSAL REPAIR LOOP");
    expect(carouselSource).toContain("AGENT MICROSCOPE");
    expect(carouselSource).toContain("INTENT TO PROOF");
    expect(carouselSource).toContain("Agents don't guess.");
    expect(carouselSource).toContain("repair from evidence");
    expect(carouselSource).toContain("Ask the runtime");
    expect(carouselSource).toContain("From intent to");
    expect(carouselSource).toContain('"Repair"');
    expect(carouselSource).toContain('"Inspect"');
    expect(carouselSource).toContain('"Ship"');
    expect(carouselSource).toContain("/assets/hero-causal-repair.png");
    expect(carouselSource).toContain("/assets/hero-agent-microscope.png");
    expect(carouselSource).toContain("/assets/hero-intent-to-proof.png");
    expect(carouselSource).not.toContain("/assets/foundation-plane.png");
    expect(carouselSource).not.toContain("/assets/agent-runtime.png");
    expect(carouselSource).not.toContain("/assets/production-proof.png");
    expect(carouselSource).toContain('role="tablist"');
    expect(carouselSource).toContain('aria-live="polite"');
    expect(carouselSource).toContain("setInterval");
  });

  test("uses dark controls with orange editorial accents", () => {
    expect(styleSource).toContain("--slate: #172033");
    expect(styleSource).toContain("--orange: #f7a41d");
    expect(styleSource).toContain(".button-primary");
    expect(styleSource).toContain("background: var(--slate)");
    expect(styleSource).toContain(".orange-underline");
  });

  test("shows Ziac and Yachdee as real cross-stack proof", () => {
    expect(landingSource).toContain("BUILT WITH ZIGEFFECT");
    expect(landingSource).toContain("Ziac");
    expect(landingSource).toContain("Yachdee");
    expect(landingSource).toContain("Backend");
    expect(landingSource).toContain("Infrastructure");
    expect(landingSource).toContain("Cloud");
  });

  test("states the post-JavaScript backend vision without hiding the tradeoff", () => {
    expect(landingSource).toContain("THE NEXT BACKEND ERA");
    expect(landingSource).toContain(">JavaScript<");
    expect(landingSource).toContain("Tokens are cheap");
    expect(landingSource).toContain("repetitive");
    expect(landingSource).toContain("Explicit systems code");
  });

  test("ships accessible navigation and reduced-motion behavior", () => {
    expect(landingSource).toContain('aria-label="Primary navigation"');
    expect(landingSource).toContain('aria-expanded={menuOpen()}');
    expect(carouselSource).toContain('aria-label="Pause carousel"');
    expect(styleSource).toContain("prefers-reduced-motion: reduce");
  });
});
