import { Link, Meta, Title, useHead } from "@solidjs/meta";
import { HowItWorks } from "../HowItWorks";
import { SITE_URL, SOCIAL_IMAGE_URL } from "../seo";
const title = "How ZigEffect works — from requirement to verified replay";
const description = "A plain-English walkthrough of how agents use ZigEffect to declare intent, write Zig, observe execution, inject failures, repair code, and publish proof.";
const canonical = `${SITE_URL}/how-it-works`;
const schema = JSON.stringify({ "@context": "https://schema.org", "@type": "HowTo", name: "How ZigEffect works", description, step: ["Declare intent", "Write typed Zig", "Run with causal evidence", "Inject a deterministic failure", "Repair and replay", "Publish a complete receipt"].map((name) => ({ "@type": "HowToStep", name })) });
export default function Route() { useHead({ tag: "script", id: "how-schema", props: { type: "application/ld+json", children: schema }, setting: { close: true } }); return <><Title>{title}</Title><Meta name="description" content={description} /><Link rel="canonical" href={canonical} /><Meta property="og:title" content={title} /><Meta property="og:description" content={description} /><Meta property="og:image" content={SOCIAL_IMAGE_URL} /><Meta name="twitter:card" content="summary_large_image" /><Meta name="twitter:title" content={title} /><HowItWorks /></>; }

