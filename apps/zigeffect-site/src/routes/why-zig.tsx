import { Link, Meta, Title, useHead } from "@solidjs/meta";
import { WhyZig } from "../WhyZig";
import { SITE_URL, SOCIAL_IMAGE_URL } from "../seo";
const title = "Why Zig for agentic backends — ZigEffect";
const description = "Why Zig's explicit memory, errors, dependencies, and native output become an advantage when agents absorb repetitive systems code.";
const canonical = `${SITE_URL}/why-zig`;
const schema = JSON.stringify({ "@context": "https://schema.org", "@type": "TechArticle", headline: title, description, about: ["Zig", "Agentic development", "Systems programming"] });
export default function Route() { useHead({ tag: "script", id: "why-zig-schema", props: { type: "application/ld+json", children: schema }, setting: { close: true } }); return <><Title>{title}</Title><Meta name="description" content={description} /><Link rel="canonical" href={canonical} /><Meta property="og:title" content={title} /><Meta property="og:description" content={description} /><Meta property="og:image" content={SOCIAL_IMAGE_URL} /><Meta name="twitter:card" content="summary_large_image" /><Meta name="twitter:title" content={title} /><WhyZig /></>; }

