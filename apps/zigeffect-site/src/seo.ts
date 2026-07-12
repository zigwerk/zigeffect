const configuredSiteUrl = import.meta.env.PUBLIC_SITE_URL?.trim();

export const SITE_URL = (configuredSiteUrl || "https://zigeffect.dev").replace(/\/$/, "");
export const SITE_TITLE = "ZigEffect — the agent-verifiable application runtime";
export const SITE_DESCRIPTION =
  "Build efficient Zig backends, infrastructure, and cloud systems with typed effects, causal evidence, deterministic testing, and agent-readable runtime proof.";
export const SOCIAL_IMAGE_URL = `${SITE_URL}/assets/production-proof.png`;

export const SOFTWARE_APPLICATION_SCHEMA = JSON.stringify({
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "ZigEffect",
  applicationCategory: "DeveloperApplication",
  operatingSystem: "Linux, macOS",
  url: `${SITE_URL}/`,
  description: SITE_DESCRIPTION,
  offers: {
    "@type": "Offer",
    price: "0",
    priceCurrency: "USD",
  },
  featureList: [
    "Typed effects and structured concurrency for Zig",
    "Agent-observable causal runtime",
    "Deterministic Testing v2 receipts and replay",
    "Production HTTP, PostgreSQL, storage, transport, telemetry, Redis, and S3 adapters",
    "Durable workflows and typed statecharts",
  ],
});
