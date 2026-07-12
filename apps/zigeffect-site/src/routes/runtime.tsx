import { Link, Meta, Title, useHead } from "@solidjs/meta";
import { RuntimePage } from "../RuntimePage";
import { SITE_URL, SOCIAL_IMAGE_URL } from "../seo";
const title = "The ZigEffect runtime — effects, scopes, fibers, and layers";
const description = "A plain-English guide to ZigEffect's typed effects, service layers, scoped resource ownership, structured concurrency, and replaceable executors.";
const canonical = `${SITE_URL}/runtime`;
const schema = JSON.stringify({ "@context": "https://schema.org", "@type": "TechArticle", headline: title, description, about: ["Typed effects", "Structured concurrency", "Resource ownership"] });
export default function Route() { useHead({ tag: "script", id: "runtime-schema", props: { type: "application/ld+json", children: schema }, setting: { close: true } }); return <><Title>{title}</Title><Meta name="description" content={description} /><Link rel="canonical" href={canonical} /><Meta property="og:title" content={title} /><Meta property="og:description" content={description} /><Meta property="og:image" content={SOCIAL_IMAGE_URL} /><Meta name="twitter:card" content="summary_large_image" /><Meta name="twitter:title" content={title} /><RuntimePage /></>; }

