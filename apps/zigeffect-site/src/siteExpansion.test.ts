import { describe, expect, test } from "bun:test";

async function source(relativePath: string): Promise<string> {
  const file = Bun.file(new URL(relativePath, import.meta.url));
  return (await file.exists()) ? file.text() : "";
}

const routes = [
  "how-it-works",
  "why-zig",
  "runtime",
  "causal-graph",
  "testing",
  "agents",
  "standard-library",
  "grpc",
  "workflows",
  "built-with",
] as const;

const routeSources = Object.fromEntries(
  await Promise.all(routes.map(async (route) => [route, await source(`./routes/${route}.tsx`)])),
) as Record<(typeof routes)[number], string>;

const appConfig = await source("../app.config.ts");
const sitemap = await source("../public/sitemap.xml");
const chrome = await source("./MarketingChrome.tsx");
const how = await source("./HowItWorks.tsx");
const whyZig = await source("./WhyZig.tsx");
const runtime = await source("./RuntimePage.tsx");
const causal = await source("./CausalGraphPage.tsx");
const testing = await source("./TestingPage.tsx");
const agents = await source("./AgentsPage.tsx");
const standardLibrary = await source("./StandardLibraryPage.tsx");
const grpc = await source("./GrpcPage.tsx");
const workflows = await source("./WorkflowsPage.tsx");
const proof = await source("./BuiltWithPage.tsx");
const landing = await source("./ProductLanding.tsx");
const styles = await source("./styles.css");

describe("ZigEffect expanded marketing journey", () => {
  test("publishes and prerenders a complete eleven-chapter site", () => {
    for (const route of routes) {
      expect(routeSources[route].length).toBeGreaterThan(0);
      expect(appConfig).toContain(`"/${route}"`);
      expect(sitemap).toContain(`<loc>https://zigeffect.dev/${route}</loc>`);
    }
  });

  test("gives every deep route independent search and social metadata", () => {
    for (const route of routes) {
      const sourceText = routeSources[route];
      expect(sourceText).toContain("<Title>");
      expect(sourceText).toContain('name="description"');
      expect(sourceText).toContain('rel="canonical"');
      expect(sourceText).toContain('property="og:title"');
      expect(sourceText).toContain('name="twitter:card"');
      expect(sourceText).toContain("application/ld+json");
    }
  });

  test("uses shared route-aware navigation and connected chapter handoffs", () => {
    expect(chrome).toContain('aria-label="Primary navigation"');
    expect(chrome).toContain('aria-current={item.route === props.current ? "page" : undefined}');
    expect(chrome).toContain('href: "/how-it-works"');
    expect(chrome).toContain('href: "/runtime"');
    expect(chrome).toContain('href: "/testing"');
    expect(chrome).toContain('href: "/agents"');
    expect(chrome).toContain('href: "/standard-library"');
    expect(chrome).toContain('href: "/grpc"');
    expect(chrome).toContain('href: "/built-with"');
    expect(chrome).toContain("NextChapter");
  });

  test("explains the whole development loop in plain language", () => {
    expect(how).toContain("One change.");
    expect(how).toContain("Seven visible steps.");
    expect(how).toContain("Make checkout retry safely");
    expect(how).toContain("DECLARE WHAT DONE MEANS");
    expect(how).toContain("Run it with evidence");
    expect(how).toContain("Replay the exact failure");
    expect(how).toContain("No framework vocabulary required");
  });

  test("explains the foundation and runtime without hiding their boundaries", () => {
    expect(whyZig).toContain("Agents change the cost of explicit code");
    expect(whyZig).toContain("Zig does not make arbitrary programs safe");
    expect(runtime).toContain("A normal Zig function is still the center");
    expect(runtime).toContain("The scope that registers cleanup owns the resource");
    expect(runtime).toContain("deterministic, coroutine, or OS-thread executor");
  });

  test("teaches causal evidence and Testing v2 with honest completeness semantics", () => {
    expect(causal).toContain("Logs tell you what was printed");
    expect(causal).toContain("cause_event_id");
    expect(causal).toContain("finding evidence is never sampled");
    expect(testing).toContain("A green exit code");
    expect(testing).toContain("is not enough.");
    expect(testing).toContain("AssertionRecorder");
    expect(testing).toContain("VirtualWorld");
    expect(testing).toContain("incomplete is not a pass");
  });

  test("shows the agent loop, durable workflows, and real product pressure", () => {
    expect(agents).toContain("The manifest is executable intent");
    expect(agents).toContain("test affected");
    expect(agents).toContain("project check --agent");
    expect(workflows).toContain("Decisions are pure. Commands do the outside work.");
    expect(workflows).toContain("The journal is the source of truth");
    expect(workflows).toContain("Activities, timers, signals, queues and deferred values");
    expect(workflows).toContain("Hierarchical and parallel states");
    expect(workflows).toContain("Actors turn a statechart into a supervised process");
    expect(workflows).toContain("Simulation, coverage and determinism audits");
    expect(workflows).toContain("Versioning and migration are runtime concerns");
    expect(workflows).toContain("Approval is not mutation authority");
    expect(proof).toContain("Ziac");
    expect(proof).toContain("Yachdee");
    expect(proof).toContain("Provider RPC");
    expect(proof).toContain("CockroachDB");
  });

  test("presents the standard library as the practical system-building layer", () => {
    expect(standardLibrary).toContain("40+ public modules");
    expect(standardLibrary).toContain("One coherent vocabulary for a whole backend");
    expect(standardLibrary).toContain("Service");
    expect(standardLibrary).toContain("Schema");
    expect(standardLibrary).toContain("Http");
    expect(standardLibrary).toContain("Sql");
    expect(standardLibrary).toContain("ObjectStorage");
    expect(standardLibrary).toContain("Queue");
    expect(standardLibrary).toContain("PubSub");
    expect(standardLibrary).toContain("Outbox");
    expect(standardLibrary).toContain("Resilience");
    expect(standardLibrary).toContain("Observability");
    expect(standardLibrary).toContain("Testing");
    expect(standardLibrary).toContain("Agent");
    expect(standardLibrary).toContain('const zstd = @import("zigeffect_std")');
    expect(standardLibrary).toContain("Adapters declare their production posture");
    expect(standardLibrary).toContain("NATIVE GRPC + CONNECT");
    expect(standardLibrary).toContain("One Protobuf contract");
    expect(standardLibrary).toContain("TanStack Solid Query");
    expect(standardLibrary).toContain("82 discovered · 82 executed · 82 passed");
    expect(standardLibrary).toContain("Production candidate");
    expect(standardLibrary).toContain("committed-source Linux amd64");
    expect(standardLibrary).toContain("24-hour soak");
    expect(standardLibrary).toContain("deployed GCP service-to-service receipt");
  });

  test("gives native gRPC and Connect an evidence-backed product chapter", () => {
    expect(grpc).toContain("Native gRPC + Connect");
    expect(grpc).toContain("Are we faster than Go?");
    expect(grpc).toContain("grpc-go delivered more aggregate throughput");
    expect(grpc).toContain("1,541,632");
    expect(grpc).toContain("Production candidate");
  });

  test("surfaces system assembly on the homepage", () => {
    expect(landing).toContain("THE SYSTEM-BUILDING LAYER");
    expect(landing).toContain("Agents should assemble systems");
    expect(landing).toContain("not rediscover plumbing.");
    expect(landing).toContain('href="/standard-library"');
    expect(landing).toContain('href="/workflows"');
    expect(landing).toContain("DURABLE CONTROL FLOW");
    expect(landing).toContain("Generated gRPC/Connect");
    expect(landing).toContain("native Zig services on Cloud Run");
  });

  test("keeps the deep-page system responsive and horizontally safe", () => {
    expect(styles).toContain("@media (max-width: 760px)");
    expect(styles).toContain(".deep-hero { min-height: 0; grid-template-columns: 1fr");
    expect(styles).toContain(".receipt-card dl { grid-template-columns: repeat(2, 1fr)");
    expect(styles).toContain(".code-window pre { padding: 20px; font-size: 11px");
    expect(styles).toContain("overflow-x: auto");
  });
});
