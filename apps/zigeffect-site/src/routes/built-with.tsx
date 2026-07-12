import { Link, Meta, Title, useHead } from "@solidjs/meta";
import { BuiltWithPage } from "../BuiltWithPage";
import { SITE_URL, SOCIAL_IMAGE_URL } from "../seo";
const title = "Built with ZigEffect — Ziac and Yachdee";
const description = "How Ziac and Yachdee exercise ZigEffect across backend services, infrastructure, Provider RPC, CockroachDB, storage, workflows, and cloud operations.";
const canonical = `${SITE_URL}/built-with`;
const schema = JSON.stringify({ "@context": "https://schema.org", "@type": "ItemList", name: "Products built with ZigEffect", description, itemListElement: ["Ziac", "Yachdee"].map((name, index) => ({ "@type": "ListItem", position: index + 1, name })) });
export default function Route() { useHead({ tag: "script", id: "built-schema", props: { type: "application/ld+json", children: schema }, setting: { close: true } }); return <><Title>{title}</Title><Meta name="description" content={description} /><Link rel="canonical" href={canonical} /><Meta property="og:title" content={title} /><Meta property="og:description" content={description} /><Meta property="og:image" content={SOCIAL_IMAGE_URL} /><Meta name="twitter:card" content="summary_large_image" /><Meta name="twitter:title" content={title} /><BuiltWithPage /></>; }

