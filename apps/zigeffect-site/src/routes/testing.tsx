import { Link, Meta, Title, useHead } from "@solidjs/meta";
import { TestingPage } from "../TestingPage";
import { SITE_URL, SOCIAL_IMAGE_URL } from "../seo";
const title = "Testing v2 — deterministic proof and replay for Zig";
const description = "How ZigEffect links requirements to deterministic scenarios, semantic assertions, failure injection, complete native receipts, and exact replay.";
const canonical = `${SITE_URL}/testing`;
const schema = JSON.stringify({ "@context": "https://schema.org", "@type": "TechArticle", headline: title, description, about: ["Deterministic testing", "Fault injection", "Test receipts"] });
export default function Route() { useHead({ tag: "script", id: "testing-schema", props: { type: "application/ld+json", children: schema }, setting: { close: true } }); return <><Title>{title}</Title><Meta name="description" content={description} /><Link rel="canonical" href={canonical} /><Meta property="og:title" content={title} /><Meta property="og:description" content={description} /><Meta property="og:image" content={SOCIAL_IMAGE_URL} /><Meta name="twitter:card" content="summary_large_image" /><Meta name="twitter:title" content={title} /><TestingPage /></>; }

