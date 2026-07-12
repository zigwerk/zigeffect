import { Link, Meta, Title, useHead } from "@solidjs/meta";
import { AgentsPage } from "../AgentsPage";
import { SITE_URL, SOCIAL_IMAGE_URL } from "../seo";
const title = "Agentic application development with ZigEffect";
const description = "The manifest-first loop agents use to specify, implement, diagnose, replay, verify, and hand off high-quality Zig backend work.";
const canonical = `${SITE_URL}/agents`;
const schema = JSON.stringify({ "@context": "https://schema.org", "@type": "TechArticle", headline: title, description, about: ["AI coding agents", "Zig development", "Evidence-backed handoff"] });
export default function Route() { useHead({ tag: "script", id: "agents-schema", props: { type: "application/ld+json", children: schema }, setting: { close: true } }); return <><Title>{title}</Title><Meta name="description" content={description} /><Link rel="canonical" href={canonical} /><Meta property="og:title" content={title} /><Meta property="og:description" content={description} /><Meta property="og:image" content={SOCIAL_IMAGE_URL} /><Meta name="twitter:card" content="summary_large_image" /><Meta name="twitter:title" content={title} /><AgentsPage /></>; }

