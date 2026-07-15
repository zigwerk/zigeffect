import { describe, expect, test } from "bun:test";

async function source(relativePath: string): Promise<string> {
  const file = Bun.file(new URL(relativePath, import.meta.url));
  return (await file.exists()) ? file.text() : "";
}

const appConfig = await source("../app.config.ts");
const packageSource = await source("../package.json");
const appRoot = await source("./App.tsx");
const routeSource = await source("./routes/index.tsx");
const robotsSource = await source("../public/robots.txt");
const sitemapSource = await source("../public/sitemap.xml");

describe("ZigEffect marketing SEO contract", () => {
  test("uses SolidStart with a prerendered root route", () => {
    expect(appConfig).toContain('from "@solidjs/start/config"');
    expect(appConfig).toContain('"/",');
    expect(appConfig).toContain('"/how-it-works"');
    expect(appRoot).toContain("<FileRoutes");
    expect(appRoot).toContain("<MetaProvider");
    expect(packageSource).toContain('"build": "vinxi build"');
  });

  test("hydrates through one Solid runtime", () => {
    expect(packageSource).toContain('"solid-js": "1.9.13"');
    expect(appConfig).toContain('dedupe: ["solid-js"]');
  });

  test("ships route-owned search social and application metadata", () => {
    expect(routeSource).toContain("<Title>");
    expect(routeSource).toContain('name="description"');
    expect(routeSource).toContain('rel="canonical"');
    expect(routeSource).toContain('property="og:title"');
    expect(routeSource).toContain('name="twitter:card"');
    expect(routeSource).toContain("application/ld+json");
  });

  test("publishes explicit crawler discovery files", () => {
    expect(robotsSource).toContain("User-agent: *");
    expect(robotsSource).toContain("Sitemap: https://zigeffect.dev/sitemap.xml");
    expect(sitemapSource).toContain("<loc>https://zigeffect.dev/</loc>");
  });
});
