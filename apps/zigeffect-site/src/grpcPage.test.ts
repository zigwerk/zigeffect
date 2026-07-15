import { describe, expect, test } from "bun:test";

async function source(relativePath: string): Promise<string> {
  const file = Bun.file(new URL(relativePath, import.meta.url));
  return (await file.exists()) ? file.text() : "";
}

const page = await source("./GrpcPage.tsx");
const route = await source("./routes/grpc.tsx");
const chrome = await source("./MarketingChrome.tsx");
const standardLibrary = await source("./StandardLibraryPage.tsx");
const config = await source("../app.config.ts");
const sitemap = await source("../public/sitemap.xml");
const styles = await source("./styles.css");
const rootReadme = await source("../../../README.md");
const packageReadme = await source("../../../packages/zigeffect-grpc/README.md");
const cloudRunGuide = await source("../../../packages/zigeffect/docs/grpc-cloud-run.md");
const agentGuide = await source("../../../AGENTS.md");
const codexSkill = await source("../../../.agents/skills/zigeffect-development/SKILL.md");
const claudeSkill = await source("../../../.claude/skills/zigeffect-development/SKILL.md");

describe("ZigEffect gRPC product page", () => {
  test("publishes a discoverable route in the shared marketing journey", () => {
    expect(page.length).toBeGreaterThan(0);
    expect(route).toContain("<Title>");
    expect(route).toContain('name="description"');
    expect(route).toContain('rel="canonical"');
    expect(route).toContain('property="og:title"');
    expect(route).toContain('name="twitter:card"');
    expect(route).toContain("SoftwareSourceCode");
    expect(route).toContain("FAQPage");
    expect(config).toContain('"/grpc"');
    expect(sitemap).toContain("<loc>https://zigeffect.dev/grpc</loc>");
    expect(chrome).toContain('{ label: "gRPC", href: "/grpc", route: "grpc" }');
    expect(standardLibrary).toContain('href="/grpc"');
  });

  test("positions a native Zig and ZigEffect stack without claiming pure Zig", () => {
    expect(page).toContain("Native gRPC + Connect");
    expect(page).toContain("One Protobuf contract");
    expect(page).toContain("TanStack Solid Query");
    expect(page).toContain("without the gRPC C core");
    expect(page).toContain("not pure Zig");
    expect(page).toContain("nghttp2");
    expect(page).toContain("OpenSSL 3");
    expect(page).toContain("typed effects");
    expect(page).toContain("causal facts");
    expect(page).toContain("VirtualWorld");
    expect(page).toContain("Testing v2");
  });

  test("publishes exact schema-v2 optimization observations", () => {
    expect(page).toContain("11,792");
    expect(page).toContain("2.42 ms");
    expect(page).toContain("6.06 ms");
    expect(page).toContain("7.0 allocations");
    expect(page).toContain("12,206");
    expect(page).toContain("10,403");
    expect(page).toContain("96.6%");
    expect(page).toContain("13.4%");
    expect(page).toContain("1,541,632");
    expect(page).toContain("zero failures");
    expect(page).toContain("10.9 MiB");
    expect(page).toContain("ARM64 Docker loopback");
    expect(page).toContain("50,000 measured calls");
    expect(page).toContain("optimization diagnostic");
    expect(page).toContain("observations, not universal deployment guarantees");
  });

  test("answers the Go question positively without overstating the result", () => {
    expect(page).toContain("Are we faster than Go?");
    expect(page).toContain("same performance class as grpc-go");
    expect(page).toContain("grpc-go led this run by 3.4%");
    expect(page).toContain("ZigEffect led Tonic by 13.4%");
    expect(page).toContain("not provided by grpc-go alone");
    expect(page).toContain("We have not yet published an apples-to-apples Go REST benchmark");
    expect(page).not.toContain("Go cannot");
    expect(page).not.toContain("fastest gRPC");
  });

  test("explains Cloud Run deployment and the production-candidate boundary", () => {
    expect(page).toContain("global external Application Load Balancer");
    expect(page).toContain("serverless NEG");
    expect(page).toContain("0.0.0.0:$PORT");
    expect(page).toContain("h2c");
    expect(page).toContain("Production candidate");
    expect(page).toContain("native Linux amd64");
    expect(page).toContain("24-hour mixed-shape soak");
    expect(page).toContain("deployed GCP service-to-service qualification");
    expect(page).toContain("120 / 120");
    expect(page).toContain("1,000 iterations");
    expect(page).toContain("94 / 94");
  });

  test("keeps README, documentation, and agent guidance on the same evidence boundary", () => {
    for (const document of [rootReadme, packageReadme, cloudRunGuide, agentGuide, codexSkill]) {
      const normalized = document.replace(/\s+/g, " ");
      expect(normalized).toContain("11,792 RPC/s");
      expect(normalized).toContain("96.6% of grpc-go");
      expect(normalized).toContain("13.4% higher throughput than Tonic");
      expect(normalized).toContain("native Linux amd64");
      expect(normalized).toContain("24-hour");
      expect(normalized).toContain("deployed GCP");
    }
    expect(codexSkill).toBe(claudeSkill);
  });

  test("uses accessible FAQ disclosures and responsive data layouts", () => {
    expect(page).toContain("<details");
    expect(page).toContain("<summary>");
    expect(page).toContain('aria-label="gRPC performance evidence"');
    expect(styles).toContain(".grpc-channel-visual");
    expect(styles).toContain(".grpc-benchmark-table");
    expect(styles).toContain(".grpc-faq");
    expect(styles).toContain(".grpc-data-scroll { overflow-x: auto");
    expect(styles).toContain(".grpc-path { grid-template-columns: 1fr");
  });
});
