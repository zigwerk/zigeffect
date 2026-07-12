import { Link, Meta, Title, useHead } from "@solidjs/meta";
import { StandardLibraryPage } from "../StandardLibraryPage";
import { SITE_URL, SOCIAL_IMAGE_URL } from "../seo";

const title = "The ZigEffect standard library for agent-built systems";
const description = "Explore 40+ typed ZigEffect modules for services, schemas, HTTP, SQL, storage, queues, resilience, observability, deterministic testing, statecharts, and agent development.";
const canonical = `${SITE_URL}/standard-library`;
const schema = JSON.stringify({ "@context": "https://schema.org", "@type": "TechArticle", headline: title, description, about: ["Zig standard library", "Agentic backend development", "Typed system boundaries", "Deterministic testing"] });

export default function Route() {
  useHead({ tag: "script", id: "standard-library-schema", props: { type: "application/ld+json", children: schema }, setting: { close: true } });
  return <><Title>{title}</Title><Meta name="description" content={description} /><Link rel="canonical" href={canonical} /><Meta property="og:title" content={title} /><Meta property="og:description" content={description} /><Meta property="og:image" content={SOCIAL_IMAGE_URL} /><Meta name="twitter:card" content="summary_large_image" /><Meta name="twitter:title" content={title} /><StandardLibraryPage /></>;
}
