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

  test("publishes exact receipt-backed performance observations", () => {
    expect(page).toContain("4,094");
    expect(page).toContain("3.27 ms");
    expect(page).toContain("7.06 ms");
    expect(page).toContain("71.5 µs");
    expect(page).toContain("1,379");
    expect(page).toContain("17.21 ms");
    expect(page).toContain("34.67 ms");
    expect(page).toContain("1,541,632");
    expect(page).toContain("zero failures");
    expect(page).toContain("10.9 MiB");
    expect(page).toContain("ARM64 Docker loopback");
    expect(page).toContain("observations, not universal deployment guarantees");
  });

  test("answers the Go question positively without hiding the throughput result", () => {
    expect(page).toContain("Are we faster than Go?");
    expect(page).toContain("In this recorded 1 KiB unary lane, yes on latency and server CPU per RPC");
    expect(page).toContain("7,402");
    expect(page).toContain("grpc-go delivered more aggregate throughput");
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
