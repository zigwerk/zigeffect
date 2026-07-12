import { Link, Meta, Title, useHead } from "@solidjs/meta";
import { WorkflowsPage } from "../WorkflowsPage";
import { SITE_URL, SOCIAL_IMAGE_URL } from "../seo";
const title = "Durable typed workflows and statecharts — ZigEffect";
const description = "How ZigEffect makes long-lived business logic visible with typed statecharts, pure decisions, durable journals, recovery, and governed control.";
const canonical = `${SITE_URL}/workflows`;
const schema = JSON.stringify({ "@context": "https://schema.org", "@type": "TechArticle", headline: title, description, about: ["Statecharts", "Durable workflows", "Agent workflow governance"] });
export default function Route() { useHead({ tag: "script", id: "workflows-schema", props: { type: "application/ld+json", children: schema }, setting: { close: true } }); return <><Title>{title}</Title><Meta name="description" content={description} /><Link rel="canonical" href={canonical} /><Meta property="og:title" content={title} /><Meta property="og:description" content={description} /><Meta property="og:image" content={SOCIAL_IMAGE_URL} /><Meta name="twitter:card" content="summary_large_image" /><Meta name="twitter:title" content={title} /><WorkflowsPage /></>; }

