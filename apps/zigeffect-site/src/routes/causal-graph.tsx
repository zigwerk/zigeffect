import { Link, Meta, Title, useHead } from "@solidjs/meta";
import { CausalGraphPage } from "../CausalGraphPage";
import { SITE_URL, SOCIAL_IMAGE_URL } from "../seo";
const title = "The agent-observable causal graph — ZigEffect";
const description = "How ZigEffect records execution as queryable causal evidence so agents can find ownership, root causes, retries, leaks, and incomplete evidence.";
const canonical = `${SITE_URL}/causal-graph`;
const schema = JSON.stringify({ "@context": "https://schema.org", "@type": "TechArticle", headline: title, description, about: ["Causal graphs", "Runtime observability", "Agent debugging"] });
export default function Route() { useHead({ tag: "script", id: "causal-schema", props: { type: "application/ld+json", children: schema }, setting: { close: true } }); return <><Title>{title}</Title><Meta name="description" content={description} /><Link rel="canonical" href={canonical} /><Meta property="og:title" content={title} /><Meta property="og:description" content={description} /><Meta property="og:image" content={SOCIAL_IMAGE_URL} /><Meta name="twitter:card" content="summary_large_image" /><Meta name="twitter:title" content={title} /><CausalGraphPage /></>; }

